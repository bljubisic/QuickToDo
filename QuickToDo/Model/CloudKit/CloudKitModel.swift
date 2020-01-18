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

final class CloudKitModel: QuickToDoStorageProtocol, QuickToDoStorageInputs, QuickToDoStorageOutputs {
    
    var inputs: QuickToDoStorageInputs { return self }
    
    var outputs: QuickToDoStorageOutputs { return self }
    
    private var itemsPrivate: PublishSubject<Item?>
    private var container: CKContainer!
    private var database: CKDatabase
    
    init() {
        itemsPrivate = PublishSubject()
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }
    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        let predicate = NSPredicate(format: "Used = 1")
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        self.database.perform(query, inZoneWith: nil) { (receivedRecords, receivedError) in
            guard let records = receivedRecords else {
                return
            }
            guard let completion = withCompletion else {
                return
            }
            for record in records {
                let tempItem = Item(name: record.string("Name")!,
                                    count: record.int("Count")!,
                                    uploadedToICloud: true,
                                    done: (record.int("Done")! == 1) ? true : false,
                                    shown: (record.int("Used")! == 1) ? true : false,
                                    createdAt: record.creationDate!,
                                    lastUsedAt: record.modificationDate!)
                completion(tempItem)
                self.itemsPrivate.onNext(tempItem)
            }
        }
        return(true, nil)
    }
    
    func insert() -> itemProcess {
        return { item, completionHandler in
            let newRecord = CKRecord(recordType: "Items")
            var itemRet = Item()
            let error: Error? = nil
            newRecord.set(string: item.name, key: "Name")
            newRecord.set(int: (item.done) ? 1 : 0, key: "Done")
            newRecord.set(int: item.count, key: "Count")
            newRecord.set(int: (item.shown) ? 1 : 0, key: "Used")
            self.database.save(newRecord) { (record, errorReceived) in
                guard let recordUnwrapped = record else {
                    return
                }
                if (errorReceived == nil) {
                    itemRet = Item(name: recordUnwrapped.string("Name")!,
                                   count: recordUnwrapped.int("Count")!,
                                   uploadedToICloud: true,
                                   done: (recordUnwrapped.int("Done") == 0) ? false : true,
                                   shown: (recordUnwrapped.int("Used") == 0) ? false : true,
                                   createdAt: Date(), lastUsedAt: Date())
                } else {
                    itemRet = Item(name: recordUnwrapped.string("Name")!,
                                   count: recordUnwrapped.int("Count")!,
                                   uploadedToICloud: false,
                                   done: (recordUnwrapped.int("Done") == 0) ? false : true,
                                   shown: (recordUnwrapped.int("Used") == 0) ? false : true,
                                   createdAt: Date(), lastUsedAt: Date())
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
            
            let predicate = NSPredicate(format: "Name = %@ and Used = %d", newItem.name, (newItem.shown) ? 1 : 0)
            let query = CKQuery(recordType: "Items", predicate: predicate)
            
            self.database.perform(query, inZoneWith: nil) { (recordsRecived, error) in
                var modifiedRecords = [CKRecord]()
                guard let records = recordsRecived else {
                    return
                }
                
                for record in records {
                    record.set(int: (newItem.shown) ? 1 : 0, key: "Used")
                    record.set(int: (newItem.done) ? 1 : 0, key: "Done")
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
    
    var items: Observable<Item?> {
        return itemsPrivate.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
}
