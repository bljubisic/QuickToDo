//
//  QuickToDoModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 02.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

class QuickToDoModel: QuickToDoOutputs, QuickToDoInputs, QuickToDoProtocol {
    
    private let itemsPrivate: PublishSubject<Item> = PublishSubject()
    private let cloudStatusPrivate: PublishSubject<CloudStatus> = PublishSubject()
    private let itemHints: PublishSubject<String> = PublishSubject()
    
    var items: Observable<Item> {
        return itemsPrivate
    }
    
    var cloudStatus: Observable<CloudStatus> {
        _ = self.coreData.inputs.getItems()
        return cloudStatusPrivate
    }
    
    var coreData: QuickToDoCoreDataProtocol
    
    init(_ withCoreData: QuickToDoCoreDataProtocol) {
        coreData = withCoreData
    }
    
    func add(_ item: Item) -> (Bool, Error?) {
//        print("calling insert with: \(item)")
        let newItem = self.coreData.inputs.insert(item)
        self.itemsPrivate.onNext(newItem)
        return (true, nil)
    }
    
    func update(_ item: Item) -> (Bool, Error?) {
        let oldItem = self.coreData.inputs.getItemWith(item.name)
        let newItem = self.coreData.inputs.update(oldItem, withItem: item)
        self.itemsPrivate.onNext(newItem)
        return(true, nil)
    }
    
    func getHints(for itemName: String) -> Observable<String> {
        
        return Observable.create({ (observer) -> Disposable in
            self.coreData.inputs.getHints(for: itemName) { (firstItem, secondItem) in
                print(firstItem, secondItem)
                observer.onNext(firstItem.name)
                observer.onNext(secondItem.name)
                observer.onCompleted()
            }
            return Disposables.create()
        })
        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        .observeOn(MainScheduler.instance)

            //itemHints.onCompleted()
    }
    
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    
}
