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
    private var _rootRecord: CKRecord?
    private var _cachedShare: CKShare?
    private var _sharePreparationInProgress: Bool = false
    private let synchronizationQueue = DispatchQueue(label: "com.quicktodo.cloudkit.sync", attributes: .concurrent)
    private var privateChangeToken: CKServerChangeToken?
    private var sharedChangeToken: CKServerChangeToken?

    private var rootRecord: CKRecord? {
        get {
            synchronizationQueue.sync { _rootRecord }
        }
        set {
            synchronizationQueue.async(flags: .barrier) {
                self._rootRecord = newValue
            }
        }
    }

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
        zone = CKRecordZone(zoneName: String(describing: RecordZones.quickToDoZone))
        database = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        // Load saved change tokens
        loadChangeTokens()

        // One database subscription per database: it covers custom zones (QuickToDoZone) and,
        // for the shared database, every zone shared with us
        setupDatabaseSubscription(in: database,
                                  subscriptionID: "private-database-changes",
                                  alertBody: "ToDo list has been changed")
        setupDatabaseSubscription(in: sharedDatabase,
                                  subscriptionID: "shared-database-changes",
                                  alertBody: "Shared list has been updated")
        registerForCloudKitNotifications()

        self.database.save(zone) { newZone, error in
            if let err = error {
                print("Zone not created: \(err)")
            } else {
                self.zone = newZone!
                // Legacy root record is only looked up (never created) - the whole zone is shared now
                self.findRootRecord()
                Task {
                    do {
                        _ = try await self.refreshShareStatus()
                    } catch {
                        print("Failed to load zone share status: \(error)")
                    }
                }
            }
        }
    }

    /// Record ID of the zone-wide share for `QuickToDoZone`
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
        print("Private database changed - using change tokens for efficient sync")
        // Use change tokens for efficient sync instead of fetching all items
        self.fetchDatabaseChanges(for: database, isShared: false)
    }

    @objc private func handleSharedDataChanged(_ notification: Notification) {
        print("Shared database changed - using change tokens for efficient sync")
        // Use change tokens for efficient sync
        self.fetchDatabaseChanges(for: sharedDatabase, isShared: true)
    }

    private func findRootRecord() {
        let predicate = NSPredicate(format: "Name = %@", "Root")
        let query = CKQuery(recordType: "Items", predicate: predicate)

        self.database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                for (_, matchResult) in matchResults {
                    switch matchResult {
                    case .success(let record):
                        self.rootRecord = record
                    case .failure:
                        break
                    }
                }
            case .failure(let error):
                print("findRootRecord fetch error: \(error)")
            }
        }
    }

    /// Deletes record-level shares created by the old root-record sharing.
    /// A zone-wide share cannot be saved while the zone still contains a record-level share.
    /// The root record itself is kept: items reference it with `.deleteSelf`, so deleting it would delete them.
    private func removeLegacyRootShare() async throws {
        let query = CKQuery(recordType: "Items", predicate: NSPredicate(format: "Name = %@", "Root"))
        guard let result = try? await database.records(matching: query, inZoneWith: zone.zoneID) else {
            return
        }

        let legacyShareIDs = result.matchResults.compactMap { try? $0.1.get().share?.recordID }
        guard !legacyShareIDs.isEmpty else {
            return
        }

        let (_, deleteResults) = try await database.modifyRecords(saving: [], deleting: legacyShareIDs)
        for (_, result) in deleteResults {
            try result.get()
        }
        print("Removed \(legacyShareIDs.count) legacy root record share(s)")
    }

    // MARK: - Change Token Management
    
    private func loadChangeTokens() {
        // Load private database change token
        if let tokenData = UserDefaults.standard.data(forKey: "privateChangeToken") {
            do {
                if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData) {
                    self.privateChangeToken = token
                    print("Loaded private change token")
                }
            } catch {
                print("Failed to load private change token: \(error)")
            }
        }
        
        // Load shared database change token
        if let tokenData = UserDefaults.standard.data(forKey: "sharedChangeToken") {
            do {
                if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData) {
                    self.sharedChangeToken = token
                    print("Loaded shared change token")
                }
            } catch {
                print("Failed to load shared change token: \(error)")
            }
        }
    }
    
    private func savePrivateChangeToken(_ token: CKServerChangeToken?) {
        guard let token = token else {
            UserDefaults.standard.removeObject(forKey: "privateChangeToken")
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: "privateChangeToken")
            self.privateChangeToken = token
            print("Saved private change token")
        } catch {
            print("Failed to save private change token: \(error)")
        }
    }
    
    private func saveSharedChangeToken(_ token: CKServerChangeToken?) {
        guard let token = token else {
            UserDefaults.standard.removeObject(forKey: "sharedChangeToken")
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: "sharedChangeToken")
            self.sharedChangeToken = token
            print("Saved shared change token")
        } catch {
            print("Failed to save shared change token: \(error)")
        }
    }
    
    // MARK: - Efficient Sync with Change Tokens
    
    func fetchDatabaseChanges(for database: CKDatabase, isShared: Bool) {
        let changeToken = isShared ? sharedChangeToken : privateChangeToken
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
        
        var changedRecordZoneIDs: [CKRecordZone.ID] = []
        
        operation.recordZoneWithIDChangedBlock = { zoneID in
            changedRecordZoneIDs.append(zoneID)
        }
        
        operation.recordZoneWithIDWasDeletedBlock = { zoneID in
            print("Record zone deleted: \(zoneID)")
        }
        
        operation.recordZoneWithIDWasDeletedDueToUserEncryptedDataResetBlock = { zoneID in
            print("Record zone deleted due to encrypted data reset: \(zoneID)")
        }
        
        operation.recordZoneWithIDWasPurgedBlock = { zoneID in
            print("Record zone purged: \(zoneID)")
        }
        
        operation.changeTokenUpdatedBlock = { token in
            if isShared {
                self.saveSharedChangeToken(token)
            } else {
                self.savePrivateChangeToken(token)
            }
        }
        
        operation.fetchDatabaseChangesResultBlock = { result in
            switch result {
            case .success(let (serverChangeToken, _)):
                if isShared {
                    self.saveSharedChangeToken(serverChangeToken)
                } else {
                    self.savePrivateChangeToken(serverChangeToken)
                }
                
                // Fetch changes for each changed zone
                for zoneID in changedRecordZoneIDs {
                    self.fetchZoneChanges(for: zoneID, in: database)
                }
                
            case .failure(let error):
                print("Error fetching database changes: \(error)")
                
                // If token expired, reset and try again
                if let ckError = error as? CKError,
                   ckError.code == .changeTokenExpired {
                    if isShared {
                        self.saveSharedChangeToken(nil)
                    } else {
                        self.savePrivateChangeToken(nil)
                    }
                    // Retry without token
                    self.fetchDatabaseChanges(for: database, isShared: isShared)
                }
            }
        }
        
        database.add(operation)
    }
    
    private func fetchZoneChanges(for zoneID: CKRecordZone.ID, in database: CKDatabase) {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = nil // Could store per-zone tokens if needed
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
        
        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                // Process changed record
                if record.recordType == "Items" {
                    self.processItemRecord(record, from: database)
                }
            case .failure(let error):
                print("Error processing record change: \(error)")
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            print("Record deleted: \(recordID) of type: \(recordType)")
            // Handle deletion if needed
        }
        
        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success(let (serverChangeToken, _, _)):
                print("Successfully fetched changes for zone: \(zoneID)")
                // Could save per-zone change token here if needed
            case .failure(let error):
                print("Error fetching zone changes: \(error)")
            }
        }
        
        database.add(operation)
    }
    
    private func processItemRecord(_ record: CKRecord, from database: CKDatabase) {
        if database == self.sharedDatabase {
            // Shared items must not reach the private items stream - the Shared tab reloads them itself
            NotificationCenter.default.post(name: .refreshSharedItems, object: nil)
        } else if let item = Item(record: record, scope: .private) {
            self.itemsPrivate.onNext(item)
        }
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

    func getRootRecord() -> CKRecord? {
        return self.rootRecord
    }

    func getZone() -> CKRecordZone? {
        return self.zone
    }

    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        let predicate = NSPredicate(format: "Root = %@", root.recordID)
        let query = CKQuery(recordType: "Items", predicate: predicate)
        let sharedDatabase = self.sharedDatabase

        // Important: Use the zone from the root record, not our local zone
        let sharedZoneID = root.recordID.zoneID

        sharedDatabase.fetch(withQuery: query, inZoneWith: sharedZoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                guard let completionUnwraped = completion else { return }
                for (_, matchResult) in matchResults {
                    if case let .success(record) = matchResult,
                       let item = Item(record: record, scope: .shared) {
                        completionUnwraped(item)
                    }
                }
            case .failure(let error):
                print("getSharedItems fetch error: \(error)")
            }
        }
        return(true, nil)
    }

    /// Fetches all shared items from all accepted shares
    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        let sharedDatabase = self.sharedDatabase

        // First, fetch all zones in the shared database to find accepted shares
        sharedDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                print("Error fetching shared zones: \(error)")
                return
            }

            guard let zones = zones else {
                print("No shared zones found")
                return
            }

            // For each zone, query for items
            for zone in zones {
                // Skip default zone as it won't contain our shared data
                if zone.zoneID == CKRecordZone.default().zoneID {
                    continue
                }

                // Query for shown Items in this zone
                let predicate = NSPredicate(format: "Used = 1")
                let query = CKQuery(recordType: "Items", predicate: predicate)

                sharedDatabase.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .success(let (matchResults, _)):
                        for (_, matchResult) in matchResults {
                            if case let .success(record) = matchResult {
                                // Skip the root record itself
                                if record.string(String(describing: ItemFields.name)) == "Root" {
                                    continue
                                }

                                if let item = Item(record: record, scope: .shared) {
                                    completion(item)
                                }
                            }
                        }
                    case .failure(let error):
                        print("Error fetching shared items from zone \(zone.zoneID): \(error)")
                    }
                }
            }
        }

        return (true, nil)
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
     Returns the zone-wide share for `QuickToDoZone`, creating it if the zone is not shared yet.
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

            // The zone is created asynchronously in init, so make sure it exists before sharing it
            self.zone = try await database.save(zone)
            try await removeLegacyRootShare()

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
        let zone = self.zone

        database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
            let newRecord = CKRecord(recordType: "Items", recordID: CKRecord.ID(zoneID: self.zone.zoneID))
            newRecord.apply(item)

            // No parent record needed: the whole zone is shared
            Task {
                do {
                    let savedRecord = try await self.database.save(newRecord)
                    let savedItem = Item(record: savedRecord, scope: .private) ?? item

                    print("Record created!! \(savedItem.name)")
                    if savedItem.name == "Root" {
                        self.rootRecord = savedRecord
                    }
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

            database.fetch(withRecordID: CKRecord.ID(ref)) { record, error in
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

        database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
