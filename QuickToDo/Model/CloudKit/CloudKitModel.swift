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
        
        self.database.perform(query, inZoneWith: zone.zoneID) { (receivedRecords, receivedError) in
            guard let records = receivedRecords else {
                return
            }
            for record in records {
                self.rootRecord = record
            }
        }
    }
    
    private func findOrCreateRootRecord()  {
        let predicate = NSPredicate(format: "Name = %@", "Root")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        self.database.perform(query, inZoneWith: zone.zoneID) { (receivedRecords, receivedError) in
          if let records = receivedRecords {
            for record in records {
              self.rootRecord = record
            }
            if self.rootRecord == nil {
                let item = Item(id: UUID(), name: "Root", count: 0, uploadedToICloud: true, done: true, shown: false, createdAt: Date(), lastUsedAt: Date())
              let insertFunction = self.insert()
              _ = insertFunction(item) { (newItem, error) in
                self.findRootRecord()
              }

            }
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
        
        self.sharedDatabase.perform(query, inZoneWith: zone.zoneID) { (receivedRecords, receivedError) in
            guard let records = receivedRecords else {
                return
            }
            guard let completionUnwraped = completion else {
                return
            }
            for record in records {
                let tempItem = Item(id: UUID(uuidString: record.string(String(describing: ItemFields.id))!)!,
                                    name: record.string(String(describing: ItemFields.name))!,
                                    count: record.int(String(describing: ItemFields.count))!,
                                    uploadedToICloud: true,
                                    done: (record.int(String(describing: ItemFields.done))! == 1) ? true : false,
                                    shown: (record.int(String(describing: ItemFields.used))! == 1) ? true : false,
                                    createdAt: record.creationDate!,
                                    lastUsedAt: record.modificationDate!)
                self.itemsRecords.append(record)
                completionUnwraped(tempItem)
                self.itemsPrivate.onNext(tempItem)
            }
        }
        return(true, nil)
    }
    
    func prepareShare() async -> (CKShare?, CKContainer?) {
        do {
            let share = CKShare(rootRecord: self.rootRecord)
            
            share[CKShare.SystemFieldKey.title] = "Sharing list" as CKRecordValue?
            
            share[CKShare.SystemFieldKey.shareType] = "QuickToDo" as CKRecordValue
            
            _ =  try await self.database.modifyRecords(saving:  [self.rootRecord, share], deleting: [])
            
            return (share, container)
//            let modRecordsList = CKModifyRecordsOperation(recordsToSave: [self.rootRecord, share], recordIDsToDelete: nil)
            
        } catch {
            print(error)
            return (nil, nil)
        }
//        modRecordsList.modifyRecordsCompletionBlock = {
//            (record, recordID, error) in
//             
//            handler(share, CKContainer.default(), error)
//        }
//        CKContainer.default().privateCloudDatabase.add(modRecordsList)
    }
    

    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        let predicate = NSPredicate(format: "Used = 1")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        self.database.perform(query, inZoneWith: zone.zoneID) { (receivedRecords, receivedError) in
            guard let records = receivedRecords else {
                return
            }
            guard let completion = withCompletion else {
                return
            }
            for record in records {
                let tempItem = Item(id: UUID(uuidString: record.string(String(describing: ItemFields.id))!)!,
                                    name: record.string(String(describing: ItemFields.name))!,
                                    count: record.int(String(describing: ItemFields.count))!,
                                    uploadedToICloud: true,
                                    done: (record.int(String(describing: ItemFields.done))! == 1) ? true : false,
                                    shown: (record.int(String(describing: ItemFields.used))! == 1) ? true : false,
                                    createdAt: record.creationDate!,
                                    lastUsedAt: record.modificationDate!)
                self.itemsRecords.append(record)
                completion(tempItem)
                self.itemsPrivate.onNext(tempItem)
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
                                   createdAt: Date(), lastUsedAt: Date())
                } else {
                    itemRet = Item(id: UUID(uuidString: recordUnwrapped.string(String(describing: ItemFields.id))!)!,
                                   name: recordUnwrapped.string(String(describing: ItemFields.name))!,
                                   count: recordUnwrapped.int(String(describing: ItemFields.count))!,
                                   uploadedToICloud: false,
                                   done: (recordUnwrapped.int(String(describing: ItemFields.done)) == 0) ? false : true,
                                   shown: (recordUnwrapped.int(String(describing: ItemFields.used)) == 0) ? false : true,
                                   createdAt: Date(), lastUsedAt: Date())
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
            
            self.database.perform(query, inZoneWith: self.zone.zoneID) { (recordsRecived, error) in
                var modifiedRecords = [CKRecord]()
                guard let records = recordsRecived else {
                    return
                }
                
                for record in records {
                    record.set(int: (newItem.shown) ? 1 : 0, key: String(describing: ItemFields.used))
                    record.set(int: (newItem.done) ? 1 : 0, key: String(describing: ItemFields.done))
                    record.set(string: newItem.name, key: String(describing: ItemFields.name))
                    modifiedRecords.append(record)
                }
                let updateOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: nil)
                updateOperation.perRecordCompletionBlock = {record, errorReceived in
                    if let error = errorReceived {
                        print("Unable to modify record: \(record). Error: \(error.localizedDescription)")
                    }
                }
                self.database.add(updateOperation)
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
