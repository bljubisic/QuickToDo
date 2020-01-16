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
    
    func getItems() -> (Bool, Error?) {
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

            var itemRet = Item()
            return (itemRet, true)
        }
    }
    
    func update() -> itemProcessUpdate {
        return { (item, newItem) in
            return (Item(), true)
        }
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) {
        
    }
    
    var items: Observable<Item?> {
        return itemsPrivate.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
}
