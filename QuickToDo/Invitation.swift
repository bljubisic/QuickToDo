//
//  Invitation.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 5/26/15.
//  Copyright (c) 2015 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CoreData

@objc(Invitation)

class Invitation: NSManagedObject {

    @NSManaged var receiver: String
    @NSManaged var sender: String
    @NSManaged var confirmed: NSNumber
    @NSManaged var sendername: String
    @NSManaged var receivername: String
    
}
