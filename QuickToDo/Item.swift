//
//  Item.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 12/5/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CoreData

class Item: NSManagedObject {

    @NSManaged var completed: NSNumber
    @NSManaged var count: NSNumber
    @NSManaged var lastused: NSDate
    @NSManaged var used: NSNumber
    @NSManaged var word: String

}
