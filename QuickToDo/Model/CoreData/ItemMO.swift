//
//  Item.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 06.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CoreData

public final class ItemMO: ManagedObject {
    
    @NSManaged public private(set) var completed: Bool
    @NSManaged public private(set) var count: Int
    @NSManaged public private(set) var lastused: Date
    @NSManaged public private(set) var used: Bool
    @NSManaged public private(set) var word: String
    @NSManaged public private(set) var uploadedToICloud: Bool
    @NSManaged public private(set) var id: String
    
    public static func insertIntoContext(moc: NSManagedObjectContext, item: Item) -> ItemMO {
        let localItemMO: ItemMO = moc.insertObject()
        localItemMO.completed = item.done
        localItemMO.count = item.count
        localItemMO.lastused = Date()
        localItemMO.used = item.shown
        localItemMO.word = item.name
        localItemMO.uploadedToICloud = item.uploadedToICloud
        localItemMO.id = item.id.uuidString
        _ = moc.saveOrRollback()
        return localItemMO
    }
    
    public static func updateIntoContext(moc: NSManagedObjectContext, item: Item) -> (ItemMO?, Bool) {
        let predicate: NSPredicate = NSPredicate(format: "%K == %@", "id", item.id.uuidString)
        let oldItemMOWrapped: ItemMO? = ItemMO.findOrFetchInContext(moc: moc, matchingPredicate: predicate)
        guard let oldItemMO = oldItemMOWrapped else {
            let returnValue = ItemMO.insertIntoContext(moc: moc, item: item)
            return (returnValue, true)
        }
        oldItemMO.completed = item.done
        oldItemMO.count = item.count
        oldItemMO.lastused = Date()
        oldItemMO.used = item.shown
        oldItemMO.word = item.name
        oldItemMO.uploadedToICloud = item.uploadedToICloud
        oldItemMO.id = item.id.uuidString
        let returnValue = moc.saveOrRollback()
        return(oldItemMO, returnValue)
    }
}

extension ItemMO: ManagedObjectType {
    public static var entityName: String {
        return "Item"
    }
    
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: "lastused", ascending: false)]
    }
}
