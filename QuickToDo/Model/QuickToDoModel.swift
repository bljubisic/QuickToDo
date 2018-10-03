//
//  QuickToDoModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 02.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift

class QuickToDoModel: QuickToDoOutputs, QuickToDoInputs, QuickToDoProtocol {
    var items: Observable<Item>?
    
    func add(_ item: Item) -> (Bool, Error?) {
        return(true, nil)
    }
    
    func update(_ item: Item) -> (Bool, Error?) {
        return(true, nil)
    }
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    
}
