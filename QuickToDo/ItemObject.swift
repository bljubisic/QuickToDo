//
//  ItemObject.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 12/5/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import Foundation

class ItemObject: NSObject {
    
    var word: NSString = ""
    var count: Int = 0
    var completed: Int = 0
    var used: Int = 0
    var lasUsed: NSDate = NSDate()
    
}
