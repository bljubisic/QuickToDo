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
        _ = self.getItems(completionBlock: withTableUpdateCompletion)
    }
    
    func add(_ newItem: Item) -> (Bool, Error?) {
//        print("Calling add with: \(newItem)")
        return self.model.inputs.add(newItem)
    }
    
    func update(_ item: Item, withItem: Item) -> (Bool, Error?) {
        return self.model.inputs.update(item)
    }
    
    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        self.model.outputs.items.subscribe(onNext: { (newItem) in
            if !self.itemsArray.contains(where: { (item) -> Bool in
                item.name == newItem.name
            }) {
                self.itemsArray.append(newItem)
                completionBlock()
            }
        },
        onError: { (Error) in
            print(Error)
        }) {
        }.disposed(by: disposeBag)
        return (true, nil)
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
    
    var cloudStatus: Observable<CloudStatus>
    
    var items: Observable<Item>
    
    var itemsArray: [Item]
    
    let disposeBag = DisposeBag()
    
    
}
