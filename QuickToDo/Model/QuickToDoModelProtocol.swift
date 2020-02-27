//
//  QuickToDoModelProtocol.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 25.09.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

protocol QuickToDoInputs {
    func add(_ item: Item) -> (Bool, Error?)
    func update(_ item: Item, withItem: Item) -> (Bool, Error?)
    func getHints(for itemName: String) -> Observable<String>
    func getItems() -> (Bool, Error?)
    func prepareSharing() -> Void
}

protocol QuickToDoOutputs {
    var items: Observable<Item?> { get }
    var cloudStatus: Observable<CloudStatus> { get }
}

protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }
    
}
protocol StorageInputs {
    
    typealias itemProcess = (Item, ((Item, Error?) -> Void)?) -> (Item?, Bool)
    typealias itemProcessUpdate = (Item, Item) -> (Item?, Bool)
    typealias itemProcessFind = (String) -> (Item?, Bool)
    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?)
    func insert() -> itemProcess
    func getItemWith() -> itemProcessFind
    func update() -> itemProcessUpdate
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) -> Void
}

protocol StorageOutputs {
    var items: Observable<Item?> { get }
}

protocol StorageProtocol {
    var inputs: StorageInputs { get }
    var outputs: StorageOutputs { get }
}
