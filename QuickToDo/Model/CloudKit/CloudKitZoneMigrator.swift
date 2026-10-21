//
//  CloudKitZoneMigrator.swift
//  QuickToDo
//
//  Copies the private items from the legacy `QuickToDoZone` into `QuickToDoListZone`.
//  `QuickToDoZone` was created before iOS 15 and lacks the `.zoneWideSharing` capability,
//  which a zone cannot gain later, so the list moves to a zone created with it.
//

import Foundation
import CloudKit

enum ZoneMigrationError: LocalizedError {
    case zoneWideSharingUnsupported(zoneName: String)

    var errorDescription: String? {
        switch self {
        case .zoneWideSharingUnsupported(let zoneName):
            return "The iCloud zone \(zoneName) does not support sharing the whole list."
        }
    }
}

/// Serializes the migration so the launch path and the Share button never copy at the same time.
/// The legacy zone is never modified, so it stays as a backup.
actor CloudKitZoneMigrator {

    /// CloudKit accepts at most 400 records per modify request
    private static let maxRecordsPerRequest = 400
    private static let completedKey = "zoneMigrationCompleted-QuickToDoListZone"
    private static let publishedKey = "localItemsPublished-QuickToDoListZone"
    private static let itemRecordType = "Items"
    private static let legacyRootName = "Root"
    private static let copiedFields: [ItemFields] = [.id, .name, .count, .done, .used]

    private let database: CKDatabase
    private let legacyZoneID: CKRecordZone.ID
    private let targetZone: CKRecordZone
    private var runningMigration: Task<CKRecordZone, Error>?
    private var runningPublish: Task<Int, Error>?

    init(database: CKDatabase, legacyZoneID: CKRecordZone.ID, targetZone: CKRecordZone) {
        self.database = database
        self.legacyZoneID = legacyZoneID
        self.targetZone = targetZone
    }

    /// True once this device copied the legacy items; read from any thread
    nonisolated static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    /// Creates the target zone (if needed), copies the legacy items once, and returns the server zone.
    func prepareTargetZone() async throws -> CKRecordZone {
        if let runningMigration {
            return try await runningMigration.value
        }
        let task = Task { try await self.runMigration() }
        runningMigration = task
        defer { runningMigration = nil }
        return try await task.value
    }

    /// Writes the local items into the list zone once per device. The legacy zone often holds stale
    /// state (edits that never reached iCloud), and the copied records all carry the migration time,
    /// so "newer wins" cannot repair them: for this one step the local store is the source of truth.
    func publishLocalItems(_ items: [Item]) async throws -> Int {
        if let runningPublish {
            return try await runningPublish.value
        }
        let task = Task { try await self.runPublish(items) }
        runningPublish = task
        defer { runningPublish = nil }
        return try await task.value
    }

    private func runPublish(_ items: [Item]) async throws -> Int {
        let zoneID = try await prepareTargetZone().zoneID
        guard !UserDefaults.standard.bool(forKey: Self.publishedKey) else {
            return 0
        }

        let recordsByItemID = Dictionary(
            try await allRecords(in: zoneID)
                .filter(isMigratableItem)
                .compactMap { record in (record[String(describing: ItemFields.id)] as? String).map { ($0, record) } },
            uniquingKeysWith: { first, _ in first })

        let changedRecords = items
            .filter { $0.scope == .private }
            .compactMap { item in record(for: item, existing: recordsByItemID[item.id.uuidString], in: zoneID) }
        try await save(changedRecords)

        UserDefaults.standard.set(true, forKey: Self.publishedKey)
        print("Published \(changedRecords.count) local item(s) to \(zoneID.zoneName)")
        return changedRecords.count
    }

    /// The record to save so the cloud matches `item`, or nil if it already does.
    /// Hidden items without a cloud record are not created.
    private func record(for item: Item, existing: CKRecord?, in zoneID: CKRecordZone.ID) -> CKRecord? {
        if let existing {
            guard !matches(existing, item) else { return nil }
            existing.apply(item)
            return existing
        }
        guard item.shown else { return nil }
        // Reuse a stored record name, so the item's CloudRecordRef maps to this record
        let recordID = item.cloudRecord.map { CKRecord.ID(recordName: $0.recordName, zoneID: zoneID) } ?? CKRecord.ID(zoneID: zoneID)
        let record = CKRecord(recordType: Self.itemRecordType, recordID: recordID)
        record.apply(item)
        return record
    }

    private func matches(_ record: CKRecord, _ item: Item) -> Bool {
        record.string(String(describing: ItemFields.name)) == item.name
            && record.int(String(describing: ItemFields.count)) == item.count
            && record.int(String(describing: ItemFields.done)) == (item.done ? 1 : 0)
            && record.int(String(describing: ItemFields.used)) == (item.shown ? 1 : 0)
    }

    private func save(_ records: [CKRecord]) async throws {
        for start in stride(from: 0, to: records.count, by: Self.maxRecordsPerRequest) {
            let batch = Array(records[start..<min(start + Self.maxRecordsPerRequest, records.count)])
            let (saveResults, _) = try await database.modifyRecords(saving: batch, deleting: [], atomically: true)
            for (_, result) in saveResults {
                _ = try result.get()
            }
        }
    }

    private func runMigration() async throws -> CKRecordZone {
        let savedZone = try await database.save(targetZone)
        guard savedZone.capabilities.contains(.zoneWideSharing) else {
            throw ZoneMigrationError.zoneWideSharingUnsupported(zoneName: savedZone.zoneID.zoneName)
        }
        guard !Self.isCompleted else {
            return savedZone
        }

        let copiedCount = try await copyLegacyItems(into: savedZone.zoneID)
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        print("Zone migration finished: copied \(copiedCount) item(s) to \(savedZone.zoneID.zoneName)")
        return savedZone
    }

    /// Copies legacy items that the target zone does not have yet (another device may have copied
    /// them, or edited them there since), so a repeated run never overwrites newer data.
    private func copyLegacyItems(into targetZoneID: CKRecordZone.ID) async throws -> Int {
        let legacyRecords: [CKRecord]
        do {
            legacyRecords = try await allRecords(in: legacyZoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            return 0 // Fresh installation: nothing to migrate
        }

        let existingNames = Set(try await allRecords(in: targetZoneID).map(\.recordID.recordName))
        let copies = legacyRecords
            .filter(isMigratableItem)
            .filter { !existingNames.contains($0.recordID.recordName) }
            .map { copy(of: $0, into: targetZoneID) }

        try await save(copies)
        return copies.count
    }

    private func isMigratableItem(_ record: CKRecord) -> Bool {
        guard !(record is CKShare), record.recordType == Self.itemRecordType else {
            return false
        }
        return record[String(describing: ItemFields.name)] as? String != Self.legacyRootName
    }

    /// Keeps the record name so stored `CloudRecordRef`s can be mapped to the new zone by name.
    /// Only item fields are copied; the legacy reference to the Root record is dropped.
    private func copy(of record: CKRecord, into zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: record.recordID.recordName, zoneID: zoneID)
        let copy = CKRecord(recordType: Self.itemRecordType, recordID: recordID)
        for field in Self.copiedFields {
            let key = String(describing: field)
            copy[key] = record[key]
        }
        return copy
    }

    /// Reads every record of a zone without a change token, so nothing is skipped.
    /// Any record that fails to load fails the migration, which is then retried on the next launch.
    private func allRecords(in zoneID: CKRecordZone.ID) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var moreComing = true

        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            records += try changes.modificationResultsByID.values.map { try $0.get().record }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return records
    }
}
