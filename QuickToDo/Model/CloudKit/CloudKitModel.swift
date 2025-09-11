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
final class CloudKitModel: StorageProtocol {
    
    private var itemsPrivate: PublishSubject<Item?>
    private var itemsRecords: [CKRecord]
    private var container: CKContainer!
    private var database: CKDatabase
    private var sharedDatabase: CKDatabase
    private var zone: CKRecordZone
    private var rootRecord: CKRecord!
    
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
                let newSubscription = CKQuerySubscription(recordType: "Items", predicate: NSPredicate(value: true), options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
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
                self.findOrCreateRootRecord()
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
    
    private func findOrCreateRootRecord()  {
        let predicate = NSPredicate(format: "Name = %@", "Root")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        self.database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
            switch result {
            case .success(let (matchResults, _)):
                for (_, matchResult) in matchResults {
                    if case let .success(record) = matchResult {
                        self.rootRecord = record
                    }
                }
                if self.rootRecord == nil {
                    let item = Item(id: UUID(), name: "Root", count: 0, uploadedToICloud: true, done: true, shown: false, createdAt: Date(), lastUsedAt: Date())
                    let insertFunction = self.insert()
                    _ = insertFunction(item) { (newItem, error) in
                        self.findRootRecord()
                    }
                }
            case .failure(let error):
                print("findOrCreateRootRecord fetch error: \(error)")
            }
        }
    }
}
//MARK: StorageInputs extension
extension CloudKitModel: StorageInputs {
    
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
        
        self.sharedDatabase.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
    
    /**
     Prepares a CKShare for the root record (creating the root record if needed),
     then saves both the root record and the share together as required by CloudKit.
     Calls the handler with the CKShare, CKContainer, and any error.
     */
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async throws {
        // Ensure the root record exists or is created.
        if self.rootRecord == nil {
            self.findOrCreateRootRecord()
            // Wait briefly for rootRecord to be created, real code should await completion.
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s, adjust as needed
            if self.rootRecord == nil {
                let error = NSError(domain: "CloudKitModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Root record not available."])
                handler(nil, nil, error)
                return
            }
        }

        // Try to find or create a CKShare for the root record.
        if let shareRef = self.rootRecord.share {
            // Fetch existing share
            let fetchOp = CKFetchRecordsOperation(recordIDs: [shareRef.recordID])
            fetchOp.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let shareRecord):
                    if let fetchedShare = shareRecord as? CKShare {
                        handler(fetchedShare, self.container, nil)
                    } else {
                        handler(nil, self.container, NSError(domain: "CloudKitModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare."]))
                    }
                case .failure(let error):
                    handler(nil, self.container, error)
                }
            }
            self.database.add(fetchOp)
            return
        }
        // Create new share
        let share = CKShare(rootRecord: self.rootRecord)
        share[CKShare.SystemFieldKey.title] = "QuickToDo Share"
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [self.rootRecord, share], recordIDsToDelete: nil)
        // iOS 15+: use modifyRecordsResultBlock instead of the deprecated modifyRecordsCompletionBlock
        modifyOp.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                handler(share, self.container, nil)
            case .failure(let error):
                handler(nil, self.container, error)
            }
        }
        self.database.add(modifyOp)
    }
    

    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        let predicate = NSPredicate(format: "Used = 1")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        self.database.fetch(withQuery: query, inZoneWith: zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
            let error: Error? = nil
            self.findRootRecord()
            if self.rootRecord != nil {
                let rootReference = CKRecord.Reference(recordID: self.rootRecord.recordID, action: .deleteSelf)
                newRecord.setObject(rootReference, forKey: "Root")
                newRecord.setParent(self.rootRecord)
            }
            newRecord.set(string: item.id.uuidString, key: String(describing: ItemFields.id))
            newRecord.set(string: item.name, key: String(describing: ItemFields.name))
            newRecord.set(int: (item.done) ? 1 : 0, key: String(describing: ItemFields.done))
            newRecord.set(int: item.count, key: String(describing: ItemFields.count))
            newRecord.set(int: (item.shown) ? 1 : 0, key: String(describing: ItemFields.used))
            self.database.save(newRecord) { (record, errorReceived) in
                guard let recordUnwrapped = record else {
                    return
                }
                if (errorReceived == nil) {
                    itemRet = Item(id: UUID(uuidString: recordUnwrapped.string(String(describing: ItemFields.id))!)!,
                                   name: recordUnwrapped.string(String(describing: ItemFields.name))!,
                                   count: recordUnwrapped.int(String(describing: ItemFields.count))!,
                                   uploadedToICloud: true,
                                   done: (recordUnwrapped.int(String(describing: ItemFields.done)) == 0) ? false : true,
                                   shown: (recordUnwrapped.int(String(describing: ItemFields.used)) == 0) ? false : true,
                                   createdAt: Date.now, lastUsedAt: Date.now)
                } else {
                    itemRet = Item(id: UUID(uuidString: recordUnwrapped.string(String(describing: ItemFields.id))!)!,
                                   name: recordUnwrapped.string(String(describing: ItemFields.name))!,
                                   count: recordUnwrapped.int(String(describing: ItemFields.count))!,
                                   uploadedToICloud: false,
                                   done: (recordUnwrapped.int(String(describing: ItemFields.done)) == 0) ? false : true,
                                   shown: (recordUnwrapped.int(String(describing: ItemFields.used)) == 0) ? false : true,
                                   createdAt: Date.now, lastUsedAt: Date.now)
                }
                print("Record created!! \(itemRet.name)")
                if itemRet.name == "Root" {
                    self.rootRecord = record!
                }
                completionHandler?(itemRet, error)
               
            }
            if error == nil {
                return (itemRet, true)
            } else {
                return (nil, false)
            }
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
            
            self.database.fetch(withQuery: query, inZoneWith: self.zone.zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
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
                        updateOperation.perRecordCompletionBlock = {record, errorReceived in
                            if let error = errorReceived {
                                print("Unable to modify record: \(record). Error: \(error.localizedDescription)")
                            }
                        }
                        self.database.add(updateOperation)
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
