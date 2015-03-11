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
    
    //var context: NSManagedObjectContext!
    
    lazy var applicationDocumentsDirectory: NSURL? = {
        return NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.persukibo.QuickToDoSharingDefaults") ?? nil
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("QuickToDo", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory!.URLByAppendingPathComponent("QuickToDo.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            //error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict as! [NSObject : AnyObject])
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
        }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    class var sharedInstance: QuickToDoDataManager {
        
        return sharedInstanceDataManager
    }
    
    
    var items: NSMutableArray = NSMutableArray()
    
    func removeItems() {
        
       
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate? as AppDelegate
        
        //var context: NSManagedObjectContext? = delegate.managedObjectContext
        
        var entityName: String = "Entity"
        
        var item = NSEntityDescription.entityForName(entityName, inManagedObjectContext: self.managedObjectContext!)
        var request:NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format:"used = 1")
        request.predicate = predicate
        
        var error: NSError? = NSError()
        
        var mutableFetchResults = managedObjectContext!.executeFetchRequest(request, error: &error)
        
        while(mutableFetchResults?.count > 0) {
            var item: Entity? = mutableFetchResults?.last as? Entity
            mutableFetchResults?.removeLast()
            managedObjectContext?.deleteObject(item!)
            
        }
        
        Entity(entity: item!, insertIntoManagedObjectContext: managedObjectContext!)
        
    }
    
    func removeUsedItems() {
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        var request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format:"used = 1 and completed = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as [Entity]
        
        if(mutableFetchResults.count > 0) {
            for result in mutableFetchResults {
                result.used = 0
                if((managedObjectContext?.save(nil)) != nil) {
                    
                }
            }
        }
        
    }
    
    func getHints(text: String) -> [String] {
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context = delegate.managedObjectContext
        
        var result: [String] = [String]()
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        var request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        var sortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptorNew = NSSortDescriptor(key: "count", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor, sortDescriptorNew]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format: "word beginswith \"\(text)\"")
        request.predicate = predicate
        
        var mutableFetchResult: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as [Entity]
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

        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        var predicate: NSPredicate = NSPredicate(format: "word = \"\(itemObject.word)\"")!
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as [Entity]
        
        if mutableFetchResults.count > 0 {
            var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext) as Entity
            
            item = mutableFetchResults.last!
            
            
            item.word = itemObject.word as String
            item.used = itemObject.used
            item.completed = itemObject.completed
        
            
            if(managedObjectContext!.save(nil)) {
                
            }
            
        }
        
    }
    
    func addItem(item: ItemObject) {
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as Entity
        
        addItem.word = item.word as String
        addItem.used = item.used
        addItem.completed = item.completed
        addItem.lastused = item.lasUsed
        
        if(managedObjectContext!.save(nil)) {
            
        }
        
    }
    
    func getNotCompletedItems() -> [ItemObject] {
        var result: [ItemObject] = [ItemObject]()
        
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format: "used = 1 and completed = 0")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as [Entity]
        
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
    
    func getItems() -> [ItemObject] {
        var result: [ItemObject] = [ItemObject]()

        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        var predicate: NSPredicate? = NSPredicate(format: "used = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as [Entity]
        
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
    
    func getItem(text: String) -> ItemObject {
        var result: ItemObject = ItemObject()
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context = delegate.managedObjectContext
        
        var item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        var request = NSFetchRequest()
        
        request.entity = item
        var sortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        var predicate = NSPredicate(format: "used = 0 and word = \"\(text)\"")
        request.predicate = predicate
        
        //var itemObject: ItemObject = ItemObject()
        var mutableFetchResults: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as [Entity]
        
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
