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
        Item.retrieveFromCloud { (result: Result <[Item]>) in
            switch result {
            case .success(let data):
                print("\(data.count) items retrieved from Cloud")
                data.forEach({ (item) in
                    self.itemsPrivate.onNext(item)
                })
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return(true, nil)
    }
    
    func insert(_ item: Item) -> Item {
        var itemRet = item
        item.saveInCloud { (result: Result<CKRecord>) in
            switch result {
            case .success(_):
                print("\(item.name) saved in Cloud")
                itemRet = item
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return itemRet
    }
    
    func getItemWith(_ itemWord: String) -> Item {
        var retItem = Item()
        Item.retrieveFromCloud { (result: Result<[Item]>) in
            switch result {
            case .success(let value):
                retItem = value[0]
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return retItem
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
