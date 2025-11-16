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
//MARK: StorageProtocol
final class CloudKitModel: StorageProtocol, @unchecked Sendable {
    
    private var itemsPrivate: PublishSubject<Item?>
    private var itemsRecords: [CKRecord]
    private var container: CKContainer!
    private var database: CKDatabase
    private var sharedDatabase: CKDatabase
    private var zone: CKRecordZone
    private var _rootRecord: CKRecord?
    private var _cachedShare: CKShare?
    private var _sharePreparationInProgress: Bool = false
    private let synchronizationQueue = DispatchQueue(label: "com.quicktodo.cloudkit.sync", attributes: .concurrent)
    
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
        itemsRecords = []
        
        database.fetchAllSubscriptions{ (subscriptions, error) in
            guard let subscriptionsUnwrapped = subscriptions  else {
                return
            }
            if(subscriptionsUnwrapped.isEmpty) {
                let subscriptionID = "Items-subscription-\(UUID().uuidString)"
                let newSubscription = CKQuerySubscription(recordType: "Items", predicate: NSPredicate(value: true), subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
                let notification = CKSubscription.NotificationInfo()
                notification.shouldSendContentAvailable = true
                notification.alertBody = "ToDo list has been changed"
                newSubscription.notificationInfo = notification
                self.database.save(newSubscription) { (subscription, error) in
                    if let error = error {
                         print(error)
                         return
                    }

                    if let _ = subscription {
                         print("Hurrah! We have a subscription")
                    }
                }
            }
        }
        
        self.database.save(zone) { newZone, error in
            if let err = error {
                print("Zone not created: \(err)")
            } else {
                self.zone = newZone!
                // Initialize root record asynchronously
                Task {
                    do {
                        let rootRecord = try await self.findOrCreateRootRecord()
                        self.rootRecord = rootRecord
                    } catch {
                        print("Failed to initialize root record: \(error)")
                    }
                }
            }
        }
    }
    
    private func findRootRecord()  {
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
    
    private func findOrCreateRootRecord() async throws -> CKRecord {
        // If we already have a root record, return it
        if let existingRoot = self.rootRecord {
            return existingRoot
        }
        
        // First, try to find existing root record
        let predicate = NSPredicate(format: "Name = %@", "Root")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let database = self.database
            let zone = self.zone
            
            database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .success(let (matchResults, _)):
                    // Look for existing root record
                    for (_, matchResult) in matchResults {
                        if case let .success(record) = matchResult {
                            self.rootRecord = record
                            continuation.resume(returning: record)
                            return
                        }
                    }
                    
                    // No root record found, create one
                    self.createRootRecord { record, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let record = record {
                            self.rootRecord = record
                            continuation.resume(returning: record)
                        } else {
                            let createError = NSError(domain: "CloudKitModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create root record"])
                            continuation.resume(throwing: createError)
                        }
                    }
                    
                case .failure(let error):
                    print("findOrCreateRootRecord fetch error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createRootRecord(completion: @escaping (CKRecord?, Error?) -> Void) {
        let newRecord = CKRecord(recordType: "Items", recordID: CKRecord.ID(zoneID: self.zone.zoneID))
        let rootItem = Item(id: UUID(), name: "Root", count: 0, uploadedToICloud: true, done: true, shown: false, createdAt: Date(), lastUsedAt: Date())
        
        newRecord.set(string: rootItem.id.uuidString, key: String(describing: ItemFields.id))
        newRecord.set(string: rootItem.name, key: String(describing: ItemFields.name))
        newRecord.set(int: rootItem.done ? 1 : 0, key: String(describing: ItemFields.done))
        newRecord.set(int: rootItem.count, key: String(describing: ItemFields.count))
        newRecord.set(int: rootItem.shown ? 1 : 0, key: String(describing: ItemFields.used))
        
        self.database.save(newRecord) { record, error in
            completion(record, error)
        }
    }
}
//MARK: StorageInputs extension
extension CloudKitModel: StorageInputs {
    func getCurrentShareStatus() -> CKShare? {
        guard self.rootRecord != nil else {
            return nil
        }
        
        // The share reference points to a CKShare, but we need to fetch it to get the actual CKShare object
        // For now, we'll return nil and let the prepareShare method handle the full fetch
        // This method is primarily used for checking if sharing is available
        return nil
    }
    
    func isListCurrentlyShared() -> Bool {
        return rootRecord?.share != nil
    }
    
    func invalidateShareCache() {
        cachedShare = nil
    }
    
    func refreshShareStatus() async throws -> CKShare? {
        guard let rootRecord = self.rootRecord,
              let shareRef = rootRecord.share else {
            return nil
        }
        
        let database = self.database
        
        return try await withCheckedThrowingContinuation { continuation in
            let fetchOp = CKFetchRecordsOperation(recordIDs: [shareRef.recordID])
            fetchOp.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let shareRecord):
                    if let fetchedShare = shareRecord as? CKShare {
                        self.cachedShare = fetchedShare
                        continuation.resume(returning: fetchedShare)
                    } else {
                        let error = NSError(domain: "CloudKitModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare."])
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            fetchOp.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    break // Success handled in perRecordResultBlock
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(fetchOp)
        }
    }
    
    
    func getItemWithId() -> itemProcessFindWithID {
        return { id in

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
                    switch matchResult {
                    case .success(let record):
                        if let idString = record.string(String(describing: ItemFields.id)),
                           let uuid = UUID(uuidString: idString),
                           let name = record.string(String(describing: ItemFields.name)),
                           let count = record.int(String(describing: ItemFields.count)),
                           let doneInt = record.int(String(describing: ItemFields.done)),
                           let usedInt = record.int(String(describing: ItemFields.used)),
                           let creationDate = record.creationDate,
                           let modificationDate = record.modificationDate {
                            
                            let tempItem = Item(id: uuid,
                                                name: name,
                                                count: count,
                                                uploadedToICloud: true,
                                                done: (doneInt == 1),
                                                shown: (usedInt == 1),
                                                createdAt: creationDate,
                                                lastUsedAt: modificationDate)
                            self.itemsRecords.append(record)
                            completionUnwraped(tempItem)
                            self.itemsPrivate.onNext(tempItem)
                        }
                    case .failure:
                        break
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
                
                // Query for all Items in this zone
                let predicate = NSPredicate(value: true)
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
                                
                                if let idString = record.string(String(describing: ItemFields.id)),
                                   let uuid = UUID(uuidString: idString),
                                   let name = record.string(String(describing: ItemFields.name)),
                                   let count = record.int(String(describing: ItemFields.count)),
                                   let doneInt = record.int(String(describing: ItemFields.done)),
                                   let usedInt = record.int(String(describing: ItemFields.used)),
                                   let creationDate = record.creationDate,
                                   let modificationDate = record.modificationDate {
                                    
                                    let tempItem = Item(id: uuid,
                                                        name: name,
                                                        count: count,
                                                        uploadedToICloud: true,
                                                        done: (doneInt == 1),
                                                        shown: (usedInt == 1),
                                                        createdAt: creationDate,
                                                        lastUsedAt: modificationDate)
                                    completion(tempItem)
                                    self.itemsPrivate.onNext(tempItem)
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
    
    /**
     Prepares a CKShare for the root record (creating the root record if needed),
     then saves both the root record and the share together as required by CloudKit.
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
            // Ensure the root record exists with proper async handling
            let rootRecord = try await findOrCreateRootRecord()
            self.rootRecord = rootRecord
            
            // Check if we have a cached share that's still valid
            if let cachedShare = self.cachedShare,
               let shareRef = rootRecord.share,
               cachedShare.recordID == shareRef.recordID {
                handler(cachedShare, self.container, nil)
                return
            }
            
            // Try to find existing share
            if let shareRef = rootRecord.share {
                await fetchExistingShare(shareRef: shareRef, handler: handler)
                return
            }
            
            // Create new share
            await createNewShare(rootRecord: rootRecord, handler: handler)
            
        } catch {
            handler(nil, self.container, error)
        }
    }
    
    private func fetchExistingShare(shareRef: CKRecord.Reference, handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async {
        let fetchOp = CKFetchRecordsOperation(recordIDs: [shareRef.recordID])
        let database = self.database
        let container = self.container
        
        fetchOp.perRecordResultBlock = { recordID, result in
            switch result {
            case .success(let shareRecord):
                if let fetchedShare = shareRecord as? CKShare {
                    self.cachedShare = fetchedShare
                    handler(fetchedShare, container, nil)
                } else {
                    let error = NSError(domain: "CloudKitModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare."])
                    handler(nil, container, error)
                }
            case .failure(let error):
                handler(nil, container, error)
            }
        }
        
        fetchOp.fetchRecordsResultBlock = { result in
            switch result {
            case .success:
                break // Success handled in perRecordResultBlock
            case .failure(let error):
                handler(nil, container, error)
            }
        }
        
        database.add(fetchOp)
    }
    
    private func createNewShare(rootRecord: CKRecord, handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async {
        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "QuickToDo Share"
        
        // Configure share permissions
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.shareType] = "com.bratislavljubisic.QuickToDo.share"
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [rootRecord, share], recordIDsToDelete: nil)
        let database = self.database
        let container = self.container
        
        modifyOp.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                self.cachedShare = share
                handler(share, container, nil)
            case .failure(let error):
                handler(nil, container, error)
            }
        }
        
        modifyOp.perRecordSaveBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                if let share = record as? CKShare {
                    self.cachedShare = share
                }
            case .failure(let error):
                print("Error saving record \(recordID): \(error.localizedDescription)")
            }
        }
        
        database.add(modifyOp)
    }
    
    func removeShare() async throws {
        guard let rootRecord = self.rootRecord,
              let shareRef = rootRecord.share else {
            return // No share to remove
        }
        
        let deleteOp = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [shareRef.recordID])
        let database = self.database
        
        return try await withCheckedThrowingContinuation { continuation in
            deleteOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    self.cachedShare = nil
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(deleteOp)
        }
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
                    switch matchResult {
                    case .success(let record):
                        if let idString = record.string(String(describing: ItemFields.id)),
                           let uuid = UUID(uuidString: idString),
                           let name = record.string(String(describing: ItemFields.name)),
                           let count = record.int(String(describing: ItemFields.count)),
                           let doneInt = record.int(String(describing: ItemFields.done)),
                           let usedInt = record.int(String(describing: ItemFields.used)),
                           let creationDate = record.creationDate,
                           let modificationDate = record.modificationDate {
                            
                            let tempItem = Item(id: uuid,
                                                name: name,
                                                count: count,
                                                uploadedToICloud: true,
                                                done: (doneInt == 1),
                                                shown: (usedInt == 1),
                                                createdAt: creationDate,
                                                lastUsedAt: modificationDate)
                            self.itemsRecords.append(record)
                            completion(tempItem)
                            self.itemsPrivate.onNext(tempItem)
                        }
                    case .failure:
                        break
                    }
                }
            case .failure(let error):
                print("getItems fetch error: \(error)")
            }
        }
        return(true, nil)
    }
    
    func insert() -> itemProcess {
        return { item, completionHandler in
            let newRecord = CKRecord(recordType: "Items", recordID:  CKRecord.ID(zoneID: self.zone.zoneID))
            var itemRet = Item()
            
            // Use async task to ensure root record exists
            Task {
                do {
                    if item.name != "Root" {
                        let rootRecord = try await self.findOrCreateRootRecord()
                        let rootReference = CKRecord.Reference(recordID: rootRecord.recordID, action: .deleteSelf)
                        newRecord.setObject(rootReference, forKey: "Root")
                        newRecord.setParent(rootRecord)
                    }
                    
                    newRecord.set(string: item.id.uuidString, key: String(describing: ItemFields.id))
                    newRecord.set(string: item.name, key: String(describing: ItemFields.name))
                    newRecord.set(int: (item.done) ? 1 : 0, key: String(describing: ItemFields.done))
                    newRecord.set(int: item.count, key: String(describing: ItemFields.count))
                    newRecord.set(int: (item.shown) ? 1 : 0, key: String(describing: ItemFields.used))
                    
                    // Use async/await instead of callback-based save
                    let recordUnwrapped = try await self.database.save(newRecord)
                    
                    itemRet = Item(id: UUID(uuidString: recordUnwrapped.string(String(describing: ItemFields.id))!)!,
                                   name: recordUnwrapped.string(String(describing: ItemFields.name))!,
                                   count: recordUnwrapped.int(String(describing: ItemFields.count))!,
                                   uploadedToICloud: true,
                                   done: (recordUnwrapped.int(String(describing: ItemFields.done)) == 0) ? false : true,
                                   shown: (recordUnwrapped.int(String(describing: ItemFields.used)) == 0) ? false : true,
                                   createdAt: Date.now, lastUsedAt: Date.now)
                    
                    print("Record created!! \(itemRet.name)")
                    if itemRet.name == "Root" {
                        self.rootRecord = recordUnwrapped
                    }
                    self.itemsRecords.append(recordUnwrapped)
                    completionHandler?(itemRet, nil)
                    
                } catch {
                    print("Failed to save record: \(error)")
                    // Create item with uploadedToICloud set to false on error
                    itemRet = Item(id: item.id,
                                   name: item.name,
                                   count: item.count,
                                   uploadedToICloud: false,
                                   done: item.done,
                                   shown: item.shown,
                                   createdAt: Date.now,
                                   lastUsedAt: Date.now)
                    completionHandler?(itemRet, error)
                }
            }
            
            // Return a placeholder - actual result is handled via completion handler
            return (itemRet, true)
        }
    }
    
    func getItemWith() -> itemProcessFind {
        return { itemWord in

            let itemRet = Item()
            return (itemRet, true)
        }
    }
    
    func update() -> itemProcessUpdate {
        return { (item, newItem) in
            
            let predicate = NSPredicate(format: "(Id == %@)", item.id.uuidString)
            let query = CKQuery(recordType: "Items", predicate: predicate)
            let database = self.database
            let zone = self.zone
            
            database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                var modifiedRecords = [CKRecord]()
                switch result {
                case .success(let (matchResults, _)):
                    for (_, matchResult) in matchResults {
                        switch matchResult {
                        case .success(let record):
                            record.set(int: (newItem.shown) ? 1 : 0, key: String(describing: ItemFields.used))
                            record.set(int: (newItem.done) ? 1 : 0, key: String(describing: ItemFields.done))
                            record.set(string: newItem.name, key: String(describing: ItemFields.name))
                            modifiedRecords.append(record)
                        case .failure:
                            break
                        }
                    }
                    if !modifiedRecords.isEmpty {
                        let updateOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: nil)
                        updateOperation.perRecordSaveBlock = { recordID, result in
                            switch result {
                            case .success:
                                // Record updated successfully
                                break
                            case .failure(let error):
                                print("Unable to modify record: \(recordID). Error: \(error.localizedDescription)")
                            }
                        }
                        database.add(updateOperation)
                    }
                case .failure(let error):
                    print("update fetch error: \(error)")
                }
            }
            return (Item(), true)
        }
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) {
        
    }
    

}
//MARK: StorageOutputs
extension CloudKitModel: StorageOutputs {
    var inputs: StorageInputs { return self }
    
    var outputs: StorageOutputs { return self }
}
