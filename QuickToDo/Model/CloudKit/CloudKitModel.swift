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
    
    init() {
        itemsPrivate = PublishSubject()
        
    }
    
    func getItems() -> (Bool, Error?) {
        return(true, nil)
    }
    
    func insert() -> itemProcess {
        return { item in
            let itemRet = Item()
            return (itemRet, true)
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
