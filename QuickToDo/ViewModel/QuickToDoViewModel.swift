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
//MARK: QuickToDoViewModelProtocol
class QuickToDoViewModel: QuickToDoViewModelProtoocol, ObservableObject {
    var model: QuickToDoProtocol
    
    var cloudStatus: Observable<CloudStatus>
    
    var items: Observable<Item>
    
    @Published var itemsArray: [Item]
    
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
            .filter({ (item) -> Bool in
                print(item)
                return item.shown
            })
            .subscribe(onNext: { (newItem) in
                if !self.itemsArray.contains(where: { (item) -> Bool in
                    item.name == newItem.name
                }) {
                    self.itemsArray.append(newItem)
                    DispatchQueue.main.async {
                        completionBlock()
                    }
                    
                } else {
                    if let index = self.itemsArray.firstIndex(where: { (item) -> Bool in
                        item.name == newItem.name
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
        return self.model.inputs.getItems()
    }
    
    func getItemsSize() -> Int {
        return self.itemsArray.count
    }
    
    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) -> Void {
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
                return item.done == true
            })
        }
    }
    

    
    func hideAllDoneItems() -> Bool {
        let updatedItems = self.itemsArray
                            .filter { (item) -> Bool in
                                return item.done == true
                            }
                            .map { (item) -> Item in
                                return Item.itemShownLens.set(!item.shown, item)
                            }
        updatedItems.forEach { (item) in
            _ = self.model.inputs.update(item, withItem: item)
        }
        self.itemsArray = self.itemsArray.filter({ (item) -> Bool in
            return item.shown == true
        })
        return true
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
