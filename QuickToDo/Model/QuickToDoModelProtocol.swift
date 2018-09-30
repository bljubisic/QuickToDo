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
    func add(_ item: Item) -> (Bool, Error)
    func new(_ item: Item) -> (Bool, Error)
    func update(_ item: Item) -> (Bool, Error)
}

protocol QuickToDoOutputs {
    
}

protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }
    
}
