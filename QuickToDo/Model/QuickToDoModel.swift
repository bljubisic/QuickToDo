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
    
    private let itemsPrivate: PublishSubject<Item?> = PublishSubject()
    private let cloudStatusPrivate: PublishSubject<CloudStatus> = PublishSubject()
    private let itemHints: PublishSubject<String> = PublishSubject()
    private let disposeBag = DisposeBag()
    
    var items: Observable<Item?> {
        return itemsPrivate
    }
    
    var cloudStatus: Observable<CloudStatus> {
        return cloudStatusPrivate
    }
    
    private var coreData: QuickToDoStorageProtocol
    private var cloudKit: QuickToDoStorageProtocol
    
    init(_ withCoreData: QuickToDoStorageProtocol, _ withCloudKit: QuickToDoStorageProtocol) {
        coreData = withCoreData
        cloudKit = withCloudKit
    }
    
    func getItems() -> (Bool, Error?) {
        Observable.merge([self.coreData.outputs.items, self.cloudKit.outputs.items])
            .subscribe({(item) in
                if let itemElement = item.element {
                    self.itemsPrivate.onNext(itemElement)
                }
            }).disposed(by: disposeBag)
        _ = self.coreData.inputs.getItems()
        _ = self.cloudKit.inputs.getItems()
        
        return (true, nil)
    }
    
    func add(_ item: Item) -> (Bool, Error?) {
        let newItem = self.coreData.inputs.insert()
        _ = self.cloudKit.inputs.insert()(item)
        self.itemsPrivate.onNext(newItem(item).0)
        return (true, nil)
    }
    
    func update(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        _ = self.updateToCloudKit(item, withItem: newItem)
        _ = self.updateToCoreData(item, withItem: newItem)
        return (true, nil)
    }
    
    private func updateToCloudKit(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        let superNewItem = self.cloudKit.inputs.update()
        self.itemsPrivate.onNext(superNewItem(item, newItem).0)
        return (true, nil)
    }
    
    private func updateToCoreData(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        let superNewItem = self.coreData.inputs.update()
        self.itemsPrivate.onNext(superNewItem(item, newItem).0)
        return(true, nil)
    }
    
    func getHints(for itemName: String) -> Observable<String> {
        return Observable.merge([self.getHintsFromCoreData(for: itemName), self.getHintsFromCloudKit(for: itemName)])
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .observeOn(MainScheduler.instance)
    }
    
    private func getHintsFromCloudKit(for itemName: String) -> Observable<String> {
        return Observable.create({ (observer) -> Disposable in
            self.cloudKit.inputs.getHints(for: itemName) { (firstItem, secondItem) in
                observer.onNext(firstItem.name)
                observer.onNext(secondItem.name)
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
    
    private func getHintsFromCoreData(for itemName: String) -> Observable<String> {
        return Observable.create({ (observer) -> Disposable in
            self.coreData.inputs.getHints(for: itemName) { (firstItem, secondItem) in
                observer.onNext(firstItem.name)
                observer.onNext(secondItem.name)
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    
}
