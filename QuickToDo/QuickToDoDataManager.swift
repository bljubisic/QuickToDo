//
//  QuickToDoDataManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 12/1/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CoreData

private var sharedInstanceDataManager: QuickToDoDataManager = QuickToDoDataManager()

class QuickToDoDataManager: NSObject {
    
    
    class var sharedInstance: QuickToDoDataManager {
        return sharedInstanceDataManager
    }
    
    
    var items: NSMutableArray = NSMutableArray()
    
    func removeItems() {
        
        var delegate: AppDelegate = UIApplication.sharedApplication().delegate? as AppDelegate
        
        var context: NSManagedObjectContext? = delegate.managedObjectContext
        
        var entityName: String = "Entity"
        
        var item = NSEntityDescription.entityForName(entityName, inManagedObjectContext: context!)
        var request:NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format:"used = 1")
        request.predicate = predicate
        
        var error: NSError? = NSError()
        
        var mutableFetchResults = context!.executeFetchRequest(request, error: &error)
        
        while(mutableFetchResults?.count > 0) {
            var item: Entity? = mutableFetchResults?.last as? Entity
            mutableFetchResults?.removeLast()
            context?.deleteObject(item!)
            
        }
        
        Entity(entity: item!, insertIntoManagedObjectContext: context!)
        
    }
    
    func removeUsedItems() {
        
        var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context)
        var request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format:"used = 1 and completed = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = context.executeFetchRequest(request, error: nil) as [Entity]
        
        if(mutableFetchResults.count > 0) {
            for result in mutableFetchResults {
                result.used = 0
                if(context.save(nil)) {
                    
                }
            }
        }
        
    }
    
    func getHints(text: String) -> [String] {
        
        var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context = delegate.managedObjectContext
        
        var result: [String] = [String]()
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context!)
        var request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        var sortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptorNew = NSSortDescriptor(key: "count", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor, sortDescriptorNew]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format: "word beginswith \"\(text)\"")
        request.predicate = predicate
        
        var mutableFetchResult: [Entity] = context?.executeFetchRequest(request, error: nil) as [Entity]
        if(mutableFetchResult.count > 0) {
            var len: Int = (mutableFetchResult.count > 2) ? 2 : mutableFetchResult.count
            
            for var i = 0; i < len; i++ {
                var item: Entity = mutableFetchResult[i]
                result.append(item.word)
            }
        }
        
        return result
        
    }
    
    func updateItem(itemObject: ItemObject) {

        var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        var predicate: NSPredicate = NSPredicate(format: "word = \"\(itemObject.word)\"")!
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = context.executeFetchRequest(request, error: nil) as [Entity]
        
        if mutableFetchResults.count > 0 {
            var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: context) as Entity
            
            item = mutableFetchResults.last!
            
            
            item.word = itemObject.word
            item.used = itemObject.used
            item.completed = itemObject.completed
        
            
            if(context.save(nil)) {
                
            }
            
        }
        
    }
    
    func addItem(item: ItemObject) {
        
        var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context)
        
        var addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: context) as Entity
        
        addItem.word = item.word
        addItem.used = item.used
        addItem.completed = item.completed
        addItem.lastused = item.lasUsed
        
        if(context.save(nil)) {
            
        }
        
    }
    
    func getItems() -> [ItemObject] {
        var result: [ItemObject] = [ItemObject]()

        
        var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format: "used = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = context.executeFetchRequest(request, error: nil) as [Entity]
        
        if mutableFetchResults.count > 0 {
            for(var i = 0; i < mutableFetchResults.count; i++) {
                var item: Entity = mutableFetchResults[i]
                var itemObject: ItemObject = ItemObject()
                itemObject.word = item.word
                itemObject.used = item.used.integerValue
                itemObject.completed = item.completed.integerValue
                itemObject.lasUsed = item.lastused
                itemObject.count = item.count.integerValue
                
                result.append(itemObject)
            }
        }
        
        return result
    }
    
    func getUsedItems() -> NSMutableArray {
        var result: NSMutableArray = NSMutableArray()
        
        return result
    }
    
    func getItem(text: String) -> ItemObject {
        var result: ItemObject = ItemObject()
        
        var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        var context = delegate.managedObjectContext
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: context!)
        var request = NSFetchRequest()
        
        request.entity = item
        var sortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        var predicate = NSPredicate(format: "used = 0 and word = \"\(text)\"")
        request.predicate = predicate
        
        //var itemObject: ItemObject = ItemObject()
        var mutableFetchResults: [Entity] = context?.executeFetchRequest(request, error: nil) as [Entity]
        
        if(mutableFetchResults.count > 0) {
            var item: Entity = mutableFetchResults[0]
            
            result.word = item.word
            result.used = item.used.integerValue
            result.completed = item.completed.integerValue
            result.lasUsed = item.lastused
            result.count = item.count.integerValue
            
        }
        
        return result
    }
    
    
   
}
