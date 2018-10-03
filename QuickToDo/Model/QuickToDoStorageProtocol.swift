//
//  QuickToDoStorageProtocol.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 02.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

protocol QuickToDoStorageInputs {
    func add(_ item: Item) -> (Bool, Error?)
    func update(_ item: Item) -> (Bool, Error?)
}

protocol QuickToDoStorageOutputs {
    var items: Observable<Item>? { get }
}

protocol QuickToDoStorageProtocol {
    var inputs: QuickToDoStorageInputs { get }
    var outputs: QuickToDoStorageOutputs { get }
}
