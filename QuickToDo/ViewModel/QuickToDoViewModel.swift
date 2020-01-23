//
//  QuickToDoViewModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 17.11.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

class QuickToDoViewModel: QuickToDoViewModelProtoocol, QuickToDoViewModelInputs, QuickToDoViewModelOutputs {
    
    var model: QuickToDoProtocol
    
    var inputs: QuickToDoViewModelInputs { return self }
    
    var outputs: QuickToDoViewModelOutputs { return self }
    
    init(_ withModel: QuickToDoProtocol, withTableUpdateCompletion: @escaping () -> Void) {
        self.model = withModel
        items = self.model.outputs.items
        cloudStatus = self.model.outputs.cloudStatus
        itemsArray = [Item]()
    }
    
    func add(_ newItem: Item) -> (Bool, Error?) {
//        print("Calling add with: \(newItem)")
        return self.model.inputs.add(newItem)
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
                .filter { (itemReceived) -> Bool in
                    guard let item = itemReceived else {
                        return false
                    }
                    return item.shown == true
                }
                .scan(0) { (priorValue, _) -> Int in
                    return priorValue + 1
                }
    }
    
    private func getDoneItemNumbers() -> Observable<Int> {
        return self.model.outputs.items
                .filter { (itemReceived) -> Bool in
                    guard let item = itemReceived else {
                        return false
                    }
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
            .observeOn(MainScheduler.instance)
            .filter({ (itemRec) -> Bool in
                guard let item = itemRec else {
                    return false
                }
                return item.name != ""
            })
            .subscribe(onNext: { (newItem) in
                if !self.itemsArray.contains(where: { (item) -> Bool in
                    item.name == newItem?.name
                }) {
                    self.itemsArray.append(newItem ?? Item())
                    DispatchQueue.main.async {
                        completionBlock()
                    }
                    
                } else {
                    if let index = self.itemsArray.firstIndex(where: { (item) -> Bool in
                        item.name == newItem?.name
                    }) {
                        self.itemsArray[index] = newItem ?? Item()
                    }
                }
            }, onError: { (Error) in
                print(Error)
            }) {
        }.disposed(by: disposeBag)
        return self.model.inputs.getItems()
    }
    
    func getItemsSize() -> Int {
        return self.itemsArray.count
    }
    
    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) -> Void {
        var items: [String] = [String]()
        self.model.inputs.getHints(for: itemName)
            .subscribe(onNext: { (name) in
                items.append(name)
        }, onError: { (Error) in
            print(Error)
        }, onCompleted: {
            if(items.count > 1) {
                withCompletion(items[0], items[1])
            }
        }) {
            if(items.count > 1) {
                withCompletion(items[0], items[1])
            }
        }.disposed(by: disposeBag)
        
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
    
    var cloudStatus: Observable<CloudStatus>
    
    var items: Observable<Item?>
    
    var itemsArray: [Item]
    
    let disposeBag = DisposeBag()
    
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
