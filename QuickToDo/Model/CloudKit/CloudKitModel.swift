//
//  CloudKitModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 26.06.19.
//  Copyright © 2019 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import CodableCloudKit

final class CloudKitModel: QuickToDoStorageProtocol, QuickToDoStorageInputs, QuickToDoStorageOutputs {
    
    var inputs: QuickToDoStorageInputs { return self }
    
    var outputs: QuickToDoStorageOutputs { return self }
    
    private var itemsPrivate: PublishSubject<Item>
    
    init() {
        itemsPrivate = PublishSubject()
        
    }
    
    func getItems() -> (Bool, Error?) {
        ItemCK.retrieveFromCloud { (result: Result <[ItemCK]>) in
            switch result {
            case .success(let data):
                print("\(data.count) items retrieved from Cloud")
                data.forEach({ (itemck) in
                    let item = Item(name: itemck.name,
                                    count: itemck.count,
                                    uploadedToICloud: itemck.uploadedToICloud,
                                    done: itemck.done,
                                    shown: itemck.shown,
                                    createdAt: itemck.createdAt,
                                    lastUsedAt: itemck.lastUsedAt)
                    self.itemsPrivate.onNext(item)
                })
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return(true, nil)
    }
    
    func insert(_ item: Item) -> Item {
        let itemck = ItemCK(name: item.name,
                            count: item.count,
                            uploadedToICloud: item.uploadedToICloud,
                            done: item.done,
                            shown: item.shown,
                            createdAt: item.createdAt,
                            lastUsedAt: item.lastUsedAt)
        var itemRet = Item()
        itemck.saveInCloud { (result: Result<CKRecord>) in
            switch result {
            case .success(_):
                print("\(itemck.name) saved in Cloud")
                itemRet = Item(name: itemck.name,
                                count: itemck.count,
                                uploadedToICloud: itemck.uploadedToICloud,
                                done: itemck.done,
                                shown: itemck.shown,
                                createdAt: itemck.createdAt,
                                lastUsedAt: itemck.lastUsedAt)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return itemRet
    }
    
    func getItemWith(_ itemWord: String) -> Item {
        var itemRet = Item()
        ItemCK.retrieveFromCloud { (result: Result<[ItemCK]>) in
            switch result {
            case .success(let value):
                itemRet = Item(name: value[0].name,
                               count: value[0].count,
                               uploadedToICloud: value[0].uploadedToICloud,
                               done: value[0].done,
                               shown: value[0].shown,
                               createdAt: value[0].createdAt,
                               lastUsedAt: value[0].lastUsedAt)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return itemRet
    }
    
    func update(_ item: Item, withItem: Item) -> Item {
        return Item()
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) {
        
    }
    
    var items: Observable<Item> {
        return itemsPrivate.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
}
