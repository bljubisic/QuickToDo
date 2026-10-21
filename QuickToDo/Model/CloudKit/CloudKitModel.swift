//
//  CloudKitModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 26.06.19.
//  Copyright © 2019 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import SwiftyCloudKit
import CloudKit
// MARK: StorageProtocol
final class CloudKitModel: StorageProtocol, @unchecked Sendable {

    private var itemsPrivate: PublishSubject<Item?>
    private var container: CKContainer!
    private var database: CKDatabase
    private var sharedDatabase: CKDatabase
    private var zone: CKRecordZone
    private static let legacyZoneID = CKRecordZone.ID(zoneName: String(describing: RecordZones.quickToDoZone))
    private let zoneMigrator: CloudKitZoneMigrator
    private var _cachedShare: CKShare?
    private var _sharePreparationInProgress: Bool = false
    private let synchronizationQueue = DispatchQueue(label: "com.quicktodo.cloudkit.sync", attributes: .concurrent)

    private var cachedShare: CKShare? {
        get {
            synchronizationQueue.sync { _cachedShare }
        }
        set {
            synchronizationQueue.async(flags: .barrier) {
                self._cachedShare = newValue
            }
        }
    }

    private var sharePreparationInProgress: Bool {
        get {
            synchronizationQueue.sync { _sharePreparationInProgress }
        }
        set {
            synchronizationQueue.async(flags: .barrier) {
                self._sharePreparationInProgress = newValue
            }
        }
    }

    var items: Observable<Item?> {
        return itemsPrivate.subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    init() {
        itemsPrivate = PublishSubject()
        container = CKContainer.default()
        zone = CKRecordZone(zoneName: String(describing: RecordZones.quickToDoListZone))
        database = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        zoneMigrator = CloudKitZoneMigrator(database: database, legacyZoneID: Self.legacyZoneID, targetZone: zone)

        // One database subscription per database: it covers custom zones (QuickToDoListZone) and,
        // for the shared database, every zone shared with us
        setupDatabaseSubscription(in: database,
                                  subscriptionID: "private-database-changes",
                                  alertBody: "ToDo list has been changed")
        setupDatabaseSubscription(in: sharedDatabase,
                                  subscriptionID: "shared-database-changes",
                                  alertBody: "Shared list has been updated")
        registerForCloudKitNotifications()

        Task {
            await self.prepareZone()
        }
    }

    /// Creates the list zone, migrates the legacy items into it, and loads the share status
    private func prepareZone() async {
        let wasMigrated = CloudKitZoneMigrator.isCompleted
        do {
            zone = try await zoneMigrator.prepareTargetZone()
        } catch {
            print("Zone not ready: \(error)")
            return
        }
        if !wasMigrated {
            // Reload the Items tab from the new zone (also syncs it via handlePrivateDataChanged)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cloudKitPrivateDataChanged, object: nil)
            }
        }
        do {
            _ = try await refreshShareStatus()
        } catch {
            print("Failed to load zone share status: \(error)")
        }
    }

    /// Zone that private items are read from and written to. Until this device migrated, that is
    /// still the legacy zone, so edits made before the migration are copied along with it.
    private var privateItemsZoneID: CKRecordZone.ID {
        CloudKitZoneMigrator.isCompleted ? zone.zoneID : Self.legacyZoneID
    }

    /// Maps a stored record reference to the record it now lives in. Migrated records keep their
    /// record name, so a reference into the legacy zone points to the same name in the list zone.
    private func recordID(for ref: CloudRecordRef, scope: ItemScope) -> CKRecord.ID {
        let recordID = CKRecord.ID(ref)
        guard scope == .private, recordID.zoneID == Self.legacyZoneID else {
            return recordID
        }
        return CKRecord.ID(recordName: ref.recordName, zoneID: privateItemsZoneID)
    }

    /// Record ID of the zone-wide share for `QuickToDoListZone`
    private var zoneShareID: CKRecord.ID {
        CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)
    }

    /// Ensures `database` has exactly one database subscription with the fixed `subscriptionID`.
    /// Older builds created a query subscription (private) or randomly named subscriptions (shared);
    /// those are deleted so each change produces a single push.
    private func setupDatabaseSubscription(in database: CKDatabase, subscriptionID: CKSubscription.ID, alertBody: String) {
        database.fetchAllSubscriptions { subscriptions, error in
            if let error = error {
                print("Error fetching subscriptions for \(subscriptionID): \(error)")
                return
            }

            let existing = subscriptions ?? []
            let legacyIDs = existing.map(\.subscriptionID).filter { $0 != subscriptionID }
            let needsSubscription = !existing.contains { $0.subscriptionID == subscriptionID }
            guard needsSubscription || !legacyIDs.isEmpty else {
                return
            }

            let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.alertBody = alertBody
            subscription.notificationInfo = notificationInfo

            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: needsSubscription ? [subscription] : [],
                                                           subscriptionIDsToDelete: legacyIDs)
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    print("Subscription \(subscriptionID) ready, removed \(legacyIDs.count) legacy subscription(s)")
                case .failure(let error):
                    print("Error saving subscription \(subscriptionID): \(error)")
                }
            }
            database.add(operation)
        }
    }

    private func registerForCloudKitNotifications() {
        // Listen for private database changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrivateDataChanged(_:)),
            name: .cloudKitPrivateDataChanged,
            object: nil
        )

        // Listen for shared database changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSharedDataChanged(_:)),
            name: .cloudKitSharedDataChanged,
            object: nil
        )
    }

    @objc private func handlePrivateDataChanged(_ notification: Notification) {
        sync(isShared: false, reportingTo: RemoteSyncCompletion.from(notification))
    }

    @objc private func handleSharedDataChanged(_ notification: Notification) {
        sync(isShared: true, reportingTo: RemoteSyncCompletion.from(notification))
    }

    private func sync(isShared: Bool, reportingTo completion: RemoteSyncCompletion?) {
        Task {
            do {
                let changed = try await self.syncChanges(isShared: isShared)
                completion?.finish(changed ? .newData : .noData)
            } catch {
                print("Error syncing \(isShared ? "shared" : "private") database: \(error)")
                completion?.finish(.failed)
            }
        }
    }

    /// Deletes record-level shares created by the old root-record sharing in the legacy zone,
    /// so earlier participants stop seeing the old copy of the list once it is shared again.
    /// Only the shares are deleted: the root record is kept because items reference it with `.deleteSelf`.
    private func removeLegacyRecordShares() async throws {
        let legacyShareIDs: [CKRecord.ID]
        do {
            legacyShareIDs = try await fetchRecordShareIDs(in: Self.legacyZoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            return
        }
        guard !legacyShareIDs.isEmpty else {
            return
        }

        let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: legacyShareIDs)
        for (_, result) in deleteResults {
            try result.get()
        }
        print("Removed \(legacyShareIDs.count) legacy record share(s)")
    }

    /// Reads every record in the zone (no change token) and returns the IDs of record-level shares.
    /// A full zone read is used instead of a query so it works without queryable indexes.
    private func fetchRecordShareIDs(in zoneID: CKRecordZone.ID) async throws -> [CKRecord.ID] {
        var shareIDs = Set<CKRecord.ID>()
        var token: CKServerChangeToken?
        var moreComing = true

        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (recordID, result) in changes.modificationResultsByID {
                guard let record = try? result.get().record else { continue }
                if record is CKShare {
                    shareIDs.insert(recordID)
                } else if let shareID = record.share?.recordID {
                    shareIDs.insert(shareID)
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return Array(shareIDs)
    }

    // MARK: - Change Token Management
    // Tokens live only in UserDefaults (no in-memory copy), so concurrent syncs share no mutable state.

    private func changeToken(forKey key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveChangeToken(_ token: CKServerChangeToken?, forKey key: String) {
        guard let token = token,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func databaseTokenKey(isShared: Bool) -> String {
        return isShared ? "sharedChangeToken" : "privateChangeToken"
    }

    private func zoneTokenKey(_ zoneID: CKRecordZone.ID, isShared: Bool) -> String {
        return "zoneChangeToken-\(isShared ? "shared" : "private")-\(zoneID.ownerName)-\(zoneID.zoneName)"
    }

    // MARK: - Efficient Sync with Change Tokens

    /// Fetches everything that changed in the private or shared database since the last sync.
    /// Changed private items are emitted on `items`; any shared change posts `.refreshSharedItems` once.
    /// The database token is only advanced after every changed zone was fetched, so a failed
    /// zone fetch is retried on the next sync instead of being skipped.
    /// - Returns: true if anything changed
    func syncChanges(isShared: Bool) async throws -> Bool {
        let database = isShared ? sharedDatabase : self.database
        let tokenKey = databaseTokenKey(isShared: isShared)
        var changed = false
        var moreComing = true

        while moreComing {
            let changes: (modifications: [CKDatabase.DatabaseChange.Modification],
                          deletions: [CKDatabase.DatabaseChange.Deletion],
                          changeToken: CKServerChangeToken,
                          moreComing: Bool)
            do {
                changes = try await database.databaseChanges(since: changeToken(forKey: tokenKey))
            } catch let error as CKError where error.code == .changeTokenExpired && changeToken(forKey: tokenKey) != nil {
                saveChangeToken(nil, forKey: tokenKey)
                continue
            }

            for deletion in changes.deletions {
                // Shared database: the owner stopped sharing or we left the list.
                // Private database: QuickToDoListZone was deleted or reset; it is recreated on the next launch.
                print("Zone \(deletion.zoneID.zoneName) was removed (\(deletion.reason))")
                saveChangeToken(nil, forKey: zoneTokenKey(deletion.zoneID, isShared: isShared))
                changed = true
            }

            for modification in changes.modifications {
                // Old app versions may still write the legacy zone; once migrated, its items are not shown
                if !isShared && modification.zoneID == Self.legacyZoneID && CloudKitZoneMigrator.isCompleted {
                    continue
                }
                if try await syncZone(modification.zoneID, in: database, isShared: isShared) {
                    changed = true
                }
            }

            saveChangeToken(changes.changeToken, forKey: tokenKey)
            moreComing = changes.moreComing
        }

        if isShared && changed {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshSharedItems, object: nil)
            }
        }
        return changed
    }

    /// Fetches the changes of one zone since its own change token.
    /// - Returns: true if any record changed or was deleted
    private func syncZone(_ zoneID: CKRecordZone.ID, in database: CKDatabase, isShared: Bool) async throws -> Bool {
        let tokenKey = zoneTokenKey(zoneID, isShared: isShared)
        var changed = false
        var moreComing = true

        while moreComing {
            let changes: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                          deletions: [CKDatabase.RecordZoneChange.Deletion],
                          changeToken: CKServerChangeToken,
                          moreComing: Bool)
            do {
                changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: changeToken(forKey: tokenKey))
            } catch let error as CKError where error.code == .changeTokenExpired && changeToken(forKey: tokenKey) != nil {
                saveChangeToken(nil, forKey: tokenKey)
                continue
            }

            for (recordID, result) in changes.modificationResultsByID {
                switch result {
                case .success(let modification):
                    changed = true
                    // Shared items are reloaded by the Shared tab after the sync
                    if !isShared, let item = Item(record: modification.record, scope: .private) {
                        itemsPrivate.onNext(item)
                    }
                case .failure(let error):
                    print("Error fetching changed record \(recordID.recordName): \(error)")
                }
            }

            // The app never deletes item records itself (removing an item only hides it), so
            // deletions come from another client; the Shared tab reloads, the private list keeps its copy.
            if !changes.deletions.isEmpty {
                print("\(changes.deletions.count) record(s) deleted in zone \(zoneID.zoneName)")
                changed = true
            }

            saveChangeToken(changes.changeToken, forKey: tokenKey)
            moreComing = changes.moreComing
        }
        return changed
    }
}
// MARK: StorageInputs extension
extension CloudKitModel: StorageInputs {
    func getCurrentShareStatus() -> CKShare? {
        return self.cachedShare
    }

    func isListCurrentlyShared() -> Bool {
        return cachedShare != nil
    }

    func invalidateShareCache() {
        cachedShare = nil
    }

    /// Fetches the zone-wide share from the server and updates the cache.
    /// Returns nil when the zone is not shared (or there is no iCloud account, so it cannot be).
    func refreshShareStatus() async throws -> CKShare? {
        do {
            let record = try await database.record(for: zoneShareID)
            guard let share = record as? CKShare else {
                throw NSError(domain: "CloudKitModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare."])
            }
            cachedShare = share
            return share
        } catch let error as CKError where [.unknownItem, .zoneNotFound, .notAuthenticated].contains(error.code) {
            cachedShare = nil
            return nil
        }
    }

    func getItemWithId() -> ItemProcessFindWithID {
        return { _ in

            let itemRet = Item()
            return (itemRet, true)
        }
    }

    func getZone() -> CKRecordZone? {
        return self.zone
    }

    /// Fetches the shown items of every list shared with us. Calls `completion` once, with all items.
    /// A zone that fails (e.g. it was just unshared) is skipped instead of failing the whole fetch.
    func fetchAllSharedItems(completion: @escaping ([Item], Error?) -> Void) -> (Bool, Error?) {
        let sharedDatabase = self.sharedDatabase

        Task {
            let zones: [CKRecordZone]
            do {
                zones = try await sharedDatabase.allRecordZones()
            } catch {
                print("Error fetching shared zones: \(error)")
                completion([], error)
                return
            }

            print("Shared database has \(zones.count) zone(s): \(zones.map { "\($0.zoneID.zoneName) (owner \($0.zoneID.ownerName))" })")
            var items: [Item] = []
            // The default zone never holds shared data
            for zone in zones where zone.zoneID != CKRecordZone.default().zoneID {
                do {
                    // Read the zone's records directly instead of querying: it needs no queryable
                    // index, and a query returned no records for the zone-wide shared zone
                    let records = try await allRecords(in: zone.zoneID, from: sharedDatabase)
                    let zoneItems = records
                        .filter { $0.recordType == "Items" }
                        .filter { $0.string(String(describing: ItemFields.name)) != "Root" } // legacy root record
                        .compactMap { Item(record: $0, scope: .shared) }
                        .filter(\.shown)
                    print("Shared zone \(zone.zoneID.zoneName): \(records.count) record(s), \(zoneItems.count) shown item(s)")
                    items += zoneItems
                } catch {
                    print("Error fetching shared items from zone \(zone.zoneID.zoneName): \(error)")
                }
            }
            completion(items, nil)
        }

        return (true, nil)
    }

    /// Reads every record of a zone without a change token. Records that fail to load are logged and skipped.
    private func allRecords(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var token: CKServerChangeToken?
        var moreComing = true

        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (recordID, result) in changes.modificationResultsByID {
                switch result {
                case .success(let modification):
                    records.append(modification.record)
                case .failure(let error):
                    print("Error fetching record \(recordID.recordName) in zone \(zoneID.zoneName): \(error)")
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return records
    }

    /// Saves a new item into the list shared with us. Fails if the user joined no shared list,
    /// or several (the UI cannot pick a list yet).
    func insertToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        let sharedDatabase = self.sharedDatabase

        let save: (CKRecordZone.ID) -> Void = { zoneID in
            let newRecord = CKRecord(recordType: "Items", recordID: CKRecord.ID(zoneID: zoneID))
            newRecord.apply(item)

            sharedDatabase.save(newRecord) { savedRecord, saveError in
                if let saveError = saveError {
                    print("Error saving to shared zone: \(saveError)")
                    completion(item, saveError)
                    return
                }
                let savedItem = savedRecord.flatMap { Item(record: $0, scope: .shared) } ?? item
                completion(savedItem, nil)
            }
        }

        sharedDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                print("Error fetching shared zones for insert: \(error)")
                completion(item, error)
                return
            }

            let sharedZones = (zones ?? []).filter { $0.zoneID != CKRecordZone.default().zoneID }
            switch sharedZones.count {
            case 0:
                let noZoneError = NSError(domain: "CloudKitModel", code: -7, userInfo: [NSLocalizedDescriptionKey: "No shared list available"])
                completion(item, noZoneError)
            case 1:
                save(sharedZones[0].zoneID)
            default:
                let ambiguousError = NSError(domain: "CloudKitModel", code: -8, userInfo: [NSLocalizedDescriptionKey: "You joined several shared lists - choose which list to add the item to"])
                completion(item, ambiguousError)
            }
        }
    }

    /**
     Returns the zone-wide share for `QuickToDoListZone`, creating it if the zone is not shared yet.
     Sharing the whole zone means every item in it is shared, without parent/root bookkeeping.
     Calls the handler with the CKShare, CKContainer, and any error.
     */
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async throws {
        // Prevent multiple simultaneous share preparation requests
        if sharePreparationInProgress {
            let error = NSError(domain: "CloudKitModel", code: -5, userInfo: [NSLocalizedDescriptionKey: "Share preparation already in progress"])
            handler(nil, self.container, error)
            return
        }

        sharePreparationInProgress = true
        defer { sharePreparationInProgress = false }

        do {
            if let existingShare = try await refreshShareStatus() {
                handler(existingShare, self.container, nil)
                return
            }

            // The zone is prepared asynchronously in init; sharing needs the migrated list zone
            self.zone = try await zoneMigrator.prepareTargetZone()
            try await removeLegacyRecordShares()

            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "QuickToDo Share"
            share.publicPermission = .none

            let savedShare = try await database.save(share) as? CKShare ?? share
            cachedShare = savedShare
            handler(savedShare, self.container, nil)
        } catch {
            handler(nil, self.container, error)
        }
    }

    func publishLocalItems(_ items: [Item]) async throws -> Int {
        return try await zoneMigrator.publishLocalItems(items)
    }

    func removeShare() async throws {
        let shareID = zoneShareID
        let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: [shareID])
        do {
            try deleteResults[shareID]?.get()
        } catch let error as CKError where error.code == .unknownItem {
            // Zone was not shared - nothing to remove
        }
        cachedShare = nil
    }

    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        let predicate = NSPredicate(format: "Used = 1")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        let database = self.database
        let zoneID = privateItemsZoneID

        database.fetch(withQuery: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                guard let completion = withCompletion else { return }
                for (_, matchResult) in matchResults {
                    if case let .success(record) = matchResult,
                       let item = Item(record: record, scope: .private) {
                        completion(item)
                        self.itemsPrivate.onNext(item)
                    }
                }
            case .failure(let error):
                print("getItems fetch error: \(error)")
            }
        }
        return(true, nil)
    }

    func insert() -> ItemProcess {
        return { item, completionHandler in
            let newRecord = CKRecord(recordType: "Items", recordID: CKRecord.ID(zoneID: self.privateItemsZoneID))
            newRecord.apply(item)

            // No parent record needed: the whole zone is shared
            Task {
                do {
                    let savedRecord = try await self.database.save(newRecord)
                    let savedItem = Item(record: savedRecord, scope: .private) ?? item

                    print("Record created!! \(savedItem.name)")
                    completionHandler?(savedItem, nil)

                } catch {
                    print("Failed to save record: \(error)")
                    completionHandler?(Item.itemUploadedToICloudLens.set(false, item), error)
                }
            }

            // Return a placeholder - actual result is handled via completion handler
            return (Item(), true)
        }
    }

    func getItemWith() -> ItemProcessFind {
        return { _ in

            let itemRet = Item()
            return (itemRet, true)
        }
    }

    /// Updates the record backing `item` in the database matching its scope (private or shared).
    /// Items saved before record references were stored are looked up by their `Id` field in the private zone.
    func update() -> ItemProcessUpdate {
        return { (item, newItem) in
            let database = (item.scope == .shared) ? self.sharedDatabase : self.database

            guard let ref = newItem.cloudRecord ?? item.cloudRecord else {
                self.updateByQuery(item, with: newItem)
                return (Item(), true)
            }

            database.fetch(withRecordID: self.recordID(for: ref, scope: item.scope)) { record, error in
                guard let record = record else {
                    print("update fetch error: \(String(describing: error))")
                    return
                }
                record.apply(newItem)
                self.save([record], to: database)
            }
            return (Item(), true)
        }
    }

    private func updateByQuery(_ item: Item, with newItem: Item) {
        let predicate = NSPredicate(format: "(Id == %@)", item.id.uuidString)
        let query = CKQuery(recordType: "Items", predicate: predicate)
        let database = self.database

        database.fetch(withQuery: query, inZoneWith: privateItemsZoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                let modifiedRecords = matchResults.compactMap { _, matchResult in try? matchResult.get() }
                modifiedRecords.forEach { $0.apply(newItem) }
                if !modifiedRecords.isEmpty {
                    self.save(modifiedRecords, to: database)
                }
            case .failure(let error):
                print("update fetch error: \(error)")
            }
        }
    }

    private func save(_ records: [CKRecord], to database: CKDatabase) {
        let updateOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        updateOperation.perRecordSaveBlock = { recordID, result in
            if case let .failure(error) = result {
                print("Unable to modify record: \(recordID). Error: \(error.localizedDescription)")
            }
        }
        database.add(updateOperation)
    }

    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) {

    }

}
// MARK: StorageOutputs
extension CloudKitModel: StorageOutputs {
    var inputs: StorageInputs { return self }

    var outputs: StorageOutputs { return self }
}

// MARK: Item <-> CKRecord mapping
extension CloudRecordRef {
    init(_ recordID: CKRecord.ID) {
        self.init(recordName: recordID.recordName,
                  zoneName: recordID.zoneID.zoneName,
                  zoneOwnerName: recordID.zoneID.ownerName)
    }
}

extension CKRecord.ID {
    convenience init(_ ref: CloudRecordRef) {
        self.init(recordName: ref.recordName,
                  zoneID: CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.zoneOwnerName))
    }
}

extension Item {
    /// Builds an item from an `Items` record; nil if a required field is missing
    init?(record: CKRecord, scope: ItemScope) {
        guard let idString = record.string(String(describing: ItemFields.id)),
              let uuid = UUID(uuidString: idString),
              let name = record.string(String(describing: ItemFields.name)),
              let count = record.int(String(describing: ItemFields.count)),
              let doneInt = record.int(String(describing: ItemFields.done)),
              let usedInt = record.int(String(describing: ItemFields.used)) else {
            return nil
        }
        self.init(id: uuid,
                  name: name,
                  count: count,
                  uploadedToICloud: true,
                  done: doneInt == 1,
                  shown: usedInt == 1,
                  createdAt: record.creationDate ?? Date(),
                  lastUsedAt: record.modificationDate ?? Date(),
                  scope: scope,
                  cloudRecord: CloudRecordRef(record.recordID))
    }
}

extension CKRecord {
    /// Writes the item's fields into this `Items` record
    func apply(_ item: Item) {
        set(string: item.id.uuidString, key: String(describing: ItemFields.id))
        set(string: item.name, key: String(describing: ItemFields.name))
        set(int: item.done ? 1 : 0, key: String(describing: ItemFields.done))
        set(int: item.count, key: String(describing: ItemFields.count))
        set(int: item.shown ? 1 : 0, key: String(describing: ItemFields.used))
    }
}
