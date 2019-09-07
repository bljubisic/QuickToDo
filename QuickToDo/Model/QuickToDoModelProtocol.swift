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
}

protocol QuickToDoOutputs {
    var items: Observable<Item> { get }
    var cloudStatus: Observable<CloudStatus> { get }
}

protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }
    
}
protocol QuickToDoStorageInputs {
    func getItems() -> (Bool, Error?)
    func insert(_ item:Item) -> Item
    func getItemWith(_ itemWord: String) -> Item
    func update(_ item: Item, withItem: Item) -> Item
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) -> Void
}

protocol QuickToDoStorageOutputs {
    var items: Observable<Item> { get }
}

protocol QuickToDoStorageProtocol {
    var inputs: QuickToDoStorageInputs { get }
    var outputs: QuickToDoStorageOutputs { get }
}
