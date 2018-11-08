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
}

protocol QuickToDoViewModelOutputs {
    var cloudStatus: Observable<CloudStatus> { get }
}

protocol QuickToDoViewModelProtoocol {
    var inputs: QuickToDoViewModelInputs { get }
    var outputs: QuickToDoViewModelOutputs { get }
}
