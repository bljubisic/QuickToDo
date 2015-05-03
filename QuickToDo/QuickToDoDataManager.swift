//
//  QuickToDoDataManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 12/1/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

protocol InviteProtocol {
    
    func openAlertView(record: CKRecord)
    
}


private var sharedInstanceDataManager: QuickToDoDataManager = QuickToDoDataManager()

class QuickToDoDataManager: NSObject {
    
    //var context: NSManagedObjectContext!
    
    var delegate: InviteProtocol?
    
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
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
    
    func ckFetchRecord(recordID: CKRecordID) {

        let container: CKContainer = CKContainer.defaultContainer()
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        //let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        //publicDatabase.fetchRecordWithID(, completionHandler: <#((CKRecord!, NSError!) -> Void)!##(CKRecord!, NSError!) -> Void#>)
        
        publicDatabase.fetchRecordWithID(recordID, completionHandler: { result, error in
            if(error == nil) {
                let record: CKRecord = result as CKRecord
                
                if(record.recordType == "Items") {

                    let word: String = record.objectForKey("name") as! String
                
                    var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
                
                    var request: NSFetchRequest = NSFetchRequest()
                    request.entity = entity
                
                    var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
                    var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
                
                    var predicate: NSPredicate = NSPredicate(format: "word = %@", word)
                    request.predicate = predicate
                
                    var mutableFetchResults: [Entity] = self.managedObjectContext!.executeFetchRequest(request, error: nil) as! [Entity]
                
                    if mutableFetchResults.count > 0 {
                        var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
                    
                        item = mutableFetchResults.last!
                    
                    
                        item.word = word
                        item.used = record.objectForKey("used") as! Int
                        item.completed = record.objectForKey("completed") as! Int
                    
                    
                        if(self.managedObjectContext!.save(nil)) {
                        
                        }
                    
                    } else {
                        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
                    
                        var addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
                    
                        addItem.word = word as String
                        addItem.used = record.objectForKey("used") as! Int
                        addItem.completed = record.objectForKey("completed") as! Int
                        addItem.lastused = record.objectForKey("lastUsed") as! NSDate
                    
                        // if configManager have sharingEnabled add this item to public database as well.
                    
                        if(self.managedObjectContext!.save(nil)) {
                        
                        }
                    
                    }
                }
                else if(record.recordType == "Invitations") {
                    
                    self.delegate?.openAlertView(record)
                    
                }
                
                
            }
            
        })
        
    }
    
    func inviteToShare(receiverICloud: String) {
        
        var container: CKContainer = CKContainer.defaultContainer()
        //var record: CKRecord = CKRecord(recordType: "Invitations")
        var publicDatabase: CKDatabase = container.publicCloudDatabase
        
        var newRecord: CKRecord = CKRecord(recordType: "Invitations")
        newRecord.setObject(receiverICloud, forKey: "receiver")
        newRecord.setObject(0, forKey: "completed")
        newRecord.setObject(configManager.selfRecordId, forKey: "sender")
        
        publicDatabase.saveRecord(newRecord, completionHandler:
            ({returnRecord, error in
                if let err = error {
                    println(err)
                } else {
                    println("Saved record \(index)")
                    
                }
            }))
        
    }
    
    func subscribeOnResponse() {
        
        let container: CKContainer = CKContainer.defaultContainer()
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "sender = %@", configManager.selfRecordId)
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options: CKSubscriptionOptions.FiresOnRecordCreation | CKSubscriptionOptions.FiresOnRecordUpdate)
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "A response on invitation has been received"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase?.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    println("subscription failed %@",
                        err.localizedDescription)
                } else {
                    println("Success!!!")
                }
            }))
        
    }
    
    func subscribeOnInvitations() {
        
        let container: CKContainer = CKContainer.defaultContainer()
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "receiver = %@", configManager.selfRecordId)
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options: CKSubscriptionOptions.FiresOnRecordCreation | CKSubscriptionOptions.FiresOnRecordUpdate)
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "A new invitation was received"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase?.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    println("subscription failed %@",
                        err.localizedDescription)
                } else {
                    println("Success!!!")
                }
            }))
        
    }
    
    func subscribeOnItems(icloudmail: String) {
        
        let container: CKContainer = CKContainer.defaultContainer()
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "icloudmail = %@", icloudmail)
        
        let subscription = CKSubscription(recordType: "Items",
            predicate: predicate,
            options: CKSubscriptionOptions.FiresOnRecordCreation | CKSubscriptionOptions.FiresOnRecordUpdate)
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "A new Item was added"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase?.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    println("subscription failed %@",
                        err.localizedDescription)
                } else {
                    println("Success!!!")
                }
            }))
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
        
        var mutableFetchResults: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as! [Entity]
        
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
        
        var mutableFetchResult: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as! [Entity]
        if(mutableFetchResult.count > 0) {
            var len: Int = (mutableFetchResult.count > 2) ? 2 : mutableFetchResult.count
            
            for var i = 0; i < len; i++ {
                var item: Entity = mutableFetchResult[i]
                result.append(item.word)
            }
        }
        
        return result
        
    }
    
    func ckRemoveAllRecords(recordId: String) {
        
        let container: CKContainer = CKContainer.defaultContainer()
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@", recordId)
        let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = results as! [CKRecord]
                var recordsForDelete: [CKRecordID] = [CKRecordID]()
                
                for record in records {
                    recordsForDelete.insert(record.recordID, atIndex: 0)
                }
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsForDelete)
                deleteOperation.perRecordCompletionBlock = { record, error in
                    if error != nil {
                        println("Unable to delete record: \(record). Error: \(error)")
                    }
                }
                deleteOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                    if error != nil {
                        if error.code == CKErrorCode.PartialFailure.rawValue {
                            println("There was a problem completing the operation. The following records had problems: \(error.userInfo?[CKPartialErrorsByItemIDKey])")
                        }
                        //callback?(success: false)
                    }
                    //callback?(success: true)
                }
                publicDatabase.addOperation(deleteOperation)
                
            }
            
        })
        
    }
    
    func shareEverythingForRecordId(recordId: String) {
        
        var items: [ItemObject] = self.getItems()
        var container: CKContainer = CKContainer.defaultContainer()
        var record: CKRecord = CKRecord(recordType: "Items")
        var publicDatabase: CKDatabase = container.publicCloudDatabase
        
        var itemsForSaving: [CKRecord] = [CKRecord]()
        
        for item in items {
            var newRecord: CKRecord = CKRecord(recordType: "Items")
            newRecord.setObject(item.word, forKey: "name")
            newRecord.setObject(item.completed, forKey: "completed")
            newRecord.setObject(recordId, forKey: "icloudmail")
            newRecord.setObject(item.used, forKey: "used")
            itemsForSaving.append(newRecord)
            
        }
        self.saveRecursively(itemsForSaving.count, itemsForSaving: itemsForSaving, publicDatabase: publicDatabase)
        
    }
    
    private func saveRecursively(index: Int, itemsForSaving: [CKRecord], publicDatabase: CKDatabase) {
        if (index > 0) {
            var tmpRecord: CKRecord = itemsForSaving[index-1]
            var name: String = tmpRecord.objectForKey("name") as! String
            println("name: \(name) for index: \(index)")
            publicDatabase.saveRecord(tmpRecord, completionHandler:
                ({returnRecord, error in
                    if let err = error {
                        println(err)
                    } else {
                        println("Saved record \(index)")

                    }
                    var tmpIndex = index - 1
                    self.saveRecursively(tmpIndex, itemsForSaving: itemsForSaving, publicDatabase: publicDatabase)
                }))
            
        } else if (index == 0) {
            println("Finished saving!")
        }
    }
    
    func updateItem(itemObject: ItemObject) {

        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        var predicate: NSPredicate = NSPredicate(format: "word = \"\(itemObject.word)\"")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as! [Entity]
        
        if mutableFetchResults.count > 0 {
            var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext) as! Entity
            
            item = mutableFetchResults.last!
            
            item.word = itemObject.word as String
            item.used = itemObject.used
            item.completed = itemObject.completed
        
            
            if(managedObjectContext!.save(nil)) {
                
            }
            
        }
        
        if(configManager.sharingEnabled > 0) {
            ckFindItem(itemObject)
        }
        
    }
    
    func ckFindItem(itemObject: ItemObject) {
        
        
        
        let container: CKContainer = CKContainer.defaultContainer()
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@ and completed = %d and name = %@ and used = %d", configManager.selfRecordId, ((itemObject.completed == 0) ? 1:0), itemObject.word, itemObject.used)
        
        let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = results as! [CKRecord]
                var modifiedRecords: [CKRecord] = [CKRecord]()
                
                for record in records {
                    record.setObject(itemObject.word, forKey:"name")
                    record.setObject(itemObject.used, forKey:"used")
                    record.setObject(itemObject.completed, forKey:"completed")
                    record.setObject(self.configManager.selfRecordId, forKey:"icloudmail")
                    modifiedRecords.append(record)
                }
                let updateOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: nil)
                updateOperation.perRecordCompletionBlock = { record, error in
                    if error != nil {
                        println("Unable to delete record: \(record). Error: \(error)")
                    }
                }
                updateOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                    if error != nil {
                        if error.code == CKErrorCode.PartialFailure.rawValue {
                            println("There was a problem completing the operation. The following records had problems: \(error.userInfo?[CKPartialErrorsByItemIDKey])")
                        }
                        //callback?(success: false)
                    }
                    //callback?(success: true)
                }
                publicDatabase.addOperation(updateOperation)
                
                
            }
            
        })
    }
    
    func addItem(item: ItemObject) {
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        var entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        var addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
        
        addItem.word = item.word as String
        addItem.used = item.used
        addItem.completed = item.completed
        addItem.lastused = item.lasUsed
        
        // if configManager have sharingEnabled add this item to public database as well.
        
        if (configManager.sharingEnabled == 1) {
            var container: CKContainer = CKContainer.defaultContainer()
            var record: CKRecord = CKRecord(recordType: "Items")
            var publicDatabase: CKDatabase = container.publicCloudDatabase
            
            var newRecord: CKRecord = CKRecord(recordType: "Items")
            newRecord.setObject(item.word, forKey: "name")
            newRecord.setObject(item.completed, forKey: "completed")
            newRecord.setObject(configManager.selfRecordId, forKey: "icloudmail")
            newRecord.setObject(item.used, forKey: "used")
            
            publicDatabase.saveRecord(newRecord, completionHandler:
                ({returnRecord, error in
                    if let err = error {
                        println(err)
                    } else {
                        println("Saved record \(index)")
                        
                    }
            }))
        
        }
        
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
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as! [Entity]
        
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
        
        var mutableFetchResults: [Entity] = managedObjectContext!.executeFetchRequest(request, error: nil) as! [Entity]
        
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
        var mutableFetchResults: [Entity] = managedObjectContext?.executeFetchRequest(request, error: nil) as! [Entity]
        
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
