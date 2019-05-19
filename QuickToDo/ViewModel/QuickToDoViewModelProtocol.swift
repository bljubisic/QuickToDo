//
//  QuickToDoViewModelProtocol.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 13.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

protocol QuickToDoViewModelInputs {
    func add(_ newItem: Item) -> (Bool, Error?)
    func update(_ item: Item, withItem: Item) -> (Bool, Error?)
    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?)
    func getItemsSize() -> Int
    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) -> Void
}

protocol QuickToDoViewModelOutputs {
    var cloudStatus: Observable<CloudStatus> { get }
    var items: Observable<Item> { get }
    var itemsArray: [Item] { get }
}

protocol QuickToDoViewModelProtoocol {
    var model: QuickToDoProtocol { get }
    var inputs: QuickToDoViewModelInputs { get }
    var outputs: QuickToDoViewModelOutputs { get }
}
