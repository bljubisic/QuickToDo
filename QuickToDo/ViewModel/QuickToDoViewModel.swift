//
//  QuickToDoViewModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 17.11.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import Combine
import CloudKit
import CoreMedia
//MARK: QuickToDoViewModelProtocol
class QuickToDoViewModel: QuickToDoViewModelProtoocol, ObservableObject {
    var model: QuickToDoProtocol
    
    var cloudStatus: Observable<CloudStatus>
    
    var items: Observable<Item>
    
    @Published public var itemsArray: [Item]
    
    let disposeBag = DisposeBag()
    typealias returnVoid = () -> Void
    
    init(_ withModel: QuickToDoProtocol) {
        self.model = withModel
        items = self.model.outputs.items
        cloudStatus = self.model.outputs.cloudStatus
        itemsArray = [Item]()
    }
}
//MARK: QuickToDoViewModelInputs
extension QuickToDoViewModel: QuickToDoViewModelInputs {
    func save(config: Bool) -> (Bool, Error?) {
        let config = QuickToDoConfig(showDoneItems: config)
        return self.model.inputs.save(config: config)
    }
    
    func getConfig() -> Bool {
        let config = self.model.inputs.getConfig()
        guard let configUnWrapped = config else {
            return false
        }
        return configUnWrapped.showDoneItems
    }
    
    
    func getRootRecord() -> CKRecord? {
        return self.model.inputs.getRootRecord()
    }
    
    func getZone() -> CKRecordZone? {
        return self.model.inputs.getZone()
    }
    
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        self.model.inputs.prepareSharing(handler: handler)
    }
    
    func add(_ newItem: Item) -> (Bool, Error?) {
//        print("Calling add with: \(newItem)")
        return self.model.inputs.add(newItem, addToCloud: true)
    }
    
    private func getFilteredItemsNum(filterImpl done: Bool) -> Observable<Int> {
        return Observable.create({ (observer) -> Disposable in
            self.model.outputs.items.subscribe(onNext: { (count) in
                observer.onNext(self.itemsArray.filter({ (item) -> Bool in
                    return ((done) ? (item.done == done) : true)
                }).count)
            }).disposed(by: self.disposeBag)
            return Disposables.create()
        })
    }
    
    private func getTotalItemNumbers() -> Observable<Int> {
        return self.model.outputs.items
                .filter { (item) -> Bool in
                    return item.shown == true
                }
                .scan(0) { (priorValue, _) -> Int in
                    return priorValue + 1
                }
    }
    
    private func getDoneItemNumbers() -> Observable<Int> {
        return self.model.outputs.items
                .filter { (item) -> Bool in
                    return item.shown == true && item.done == true
                }
                .scan(0) { (priorValue, _) -> Int in
                    return priorValue + 1
                }
    }
    
    func getItemsNumbers() -> Observable<(Int, Int)> {
        let doneItemsNum = getFilteredItemsNum(filterImpl: true)
        let remainItemsNum = getFilteredItemsNum(filterImpl: false)
        
        return Observable.combineLatest(doneItemsNum, remainItemsNum) { value1, value2 in
            return (value1, value2)
        }
    }
    
    func update(_ item: Item, withItem: Item, completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        _ = self.model.inputs.update(item, withItem: withItem)
        completionBlock()
        return (true, nil)
    }
    
    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        self.model.outputs.items
            .observe(on: MainScheduler.instance)
            .filter({ (item) -> Bool in
                return item.name != ""
            })
            .subscribe(onNext: { (newItem) in
                if !self.itemsArray.contains(where: { (item) -> Bool in
                    item.id == newItem.id
                }) {
                    self.itemsArray.append(newItem)
                    DispatchQueue.main.async {
                        completionBlock()
                    }
                    
                } else {
                    if let index = self.itemsArray.firstIndex(where: { (item) -> Bool in
                        item.id == newItem.id
                    }) {
                        let item = self.itemsArray[index]
                        if (item.lastUsedAt < newItem.lastUsedAt) {
                            self.itemsArray[index] = newItem
                        }
                    }
                }
            }, onError: { (Error) in
                print(Error)
            }, onDisposed:  {
            }).disposed(by: disposeBag)
//        self.removeShownItems()
        return self.model.inputs.getItems()
    }
    
    private func removeShownItems() {
        self.itemsArray = itemsArray.filter({item -> Bool in
            return item.shown == true
        })
    }
    
    func getItemsSize() -> Int {
        return self.itemsArray.count
    }
    
    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) -> Void {
//        var hints: [String] = Array()
//        self.model.inputs.getHints(for: itemName)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: {item in
//                hints.append(item)
//            }, onCompleted: {
//                print("Completed!!")
//                if(hints.count > 1) {
//                    withCompletion(hints[0], hints[1])
//                } else if(hints.count == 1) {
//                    withCompletion(hints[0], "")
//                } else {
//                    withCompletion("", "")
//                }
//            })
//            .disposed(by: disposeBag)
        
        let items: [String] = self.itemsArray
            .filter{(item) in item.name.hasPrefix(itemName)}
            .map{(item) in item.name}
        if(items.count > 1) {
            withCompletion(items[0], items[1])
        } else if(items.count == 1) {
            withCompletion(items[0], "")
        } else {
            withCompletion("", "")
        }
    }
    
    func getItemsArray(withFilter: Bool = false) -> [Item] {
        if !withFilter {
            return self.itemsArray
        } else {
            return self.itemsArray.filter({ (item) -> Bool in
                return item.shown == true
            })
        }
    }
    
    func showOrHideAllDoneItems(shown: Bool) -> Bool {
        let tmpArray = self.itemsArray
                            .filter { (item) -> Bool in
                                return item.done != shown
                            }
        self.itemsArray.removeAll()
        self.itemsArray.append(contentsOf: tmpArray)
        return true
    }
    
    func clearList() -> Bool {
        let updatedList = self.itemsArray.map({(item) -> Item in
            return Item.itemShownLens.set(false, item)
        })
        updatedList.forEach({item in
            _ = self.model.inputs.update(item, withItem: item)
        })
        self.itemsArray.removeAll()
        return true
    }
    
    func remove(updated item: Item) -> (Bool, Error?) {
        self.itemsArray = self.itemsArray.filter({$0.id != item.id})
        return (true, nil)
    }
    
    func uploadToCloud() -> (Bool, Error?) {
        return model.inputs.uploadToCloud(items: itemsArray.filter{item in !item.uploadedToICloud})
    }
}
//MARK: QuickToDoOutputs
extension QuickToDoViewModel: QuickToDoViewModelOutputs {
    var inputs: QuickToDoViewModelInputs { return self }
    
    var outputs: QuickToDoViewModelOutputs { return self }
    var doneItemsNum: Int {
        get {
            return self.itemsArray.filter({ (item) -> Bool in
                return item.done == true
            }).count
        }
    }
    
    var totalItemsNum: Int {
        get {
            return self.itemsArray.count
        }
    }
}
