//
//  Entity.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/19/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CoreData

@objc(Entity)


class Entity: NSManagedObject {

    @NSManaged var completed: NSNumber
    @NSManaged var count: NSNumber
    @NSManaged var lastused: NSDate
    @NSManaged var used: NSNumber
    @NSManaged var word: String

}
