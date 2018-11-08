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
    func update(_ item: Item) -> (Bool, Error?)
}

protocol QuickToDoOutputs {
    var coreData: QuickToDoCoreDataProtocol { get }
    var items: Observable<Item>? { get }
    var cloudStatus: Observable<CloudStatus> { get }
}

protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }
    
}
protocol QuickToDoCoreDataInputs {
    func getItems() -> (Bool, Error?)
    func insert(_ item:Item) -> Item
    func getItemWith(_ itemWord: String) -> Item
    func update(_ item: Item, withItem: Item) -> Item
}

protocol QuickToDoCoreDataOutputs {
    var items: Observable<Item> { get }
}

protocol QuickToDoCoreDataProtocol {
    var inputs: QuickToDoCoreDataInputs { get }
    var outputs: QuickToDoCoreDataOutputs { get }
}
