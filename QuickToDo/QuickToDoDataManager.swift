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
    func tableReload()
    
    
}


private var sharedInstanceDataManager: QuickToDoDataManager = QuickToDoDataManager()

class QuickToDoDataManager: NSObject {
    
    //var context: NSManagedObjectContext!
    
    var delegate: InviteProtocol?
    
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    var returnRecords: [CKRecord] = [CKRecord]()
    
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
        do {
            
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)

            //error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict as! [NSObject : AnyObject])
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //NSLog("Unresolved error \(error), \(error!.userInfo)")
            //abort()
        }
        catch _ {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
        }
        return coordinator
        }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
        }()
    
    class var sharedInstance: QuickToDoDataManager {
        
        return sharedInstanceDataManager
    }
    
    
    var items: NSMutableArray = NSMutableArray()
    
    var itemsMap: [String: ItemObject] = [String: ItemObject]()

    
    func removeItems() {
        
       
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate? as AppDelegate
        
        //var context: NSManagedObjectContext? = delegate.managedObjectContext
        
        let entityName: String = "Entity"
        
        let item = NSEntityDescription.entityForName(entityName, inManagedObjectContext: self.managedObjectContext!)
        let request:NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format:"used = 1")
        request.predicate = predicate
        var mutableFetchResults: [AnyObject]
        
        //var error: NSError? = NSError()
        do {
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request)
            while(mutableFetchResults.count > 0) {
                let item: Entity? = mutableFetchResults.removeLast() as? Entity
                print("item removed : \(item?.word)")
                managedObjectContext?.deleteObject(item!)
            
            }
        } catch _ {
            
        }
        
        //Entity(entity: item!, insertIntoManagedObjectContext: managedObjectContext!)
        
    }
    
    func ckFetchRecord(queryNotification: CKQueryNotification) {

        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        let recordID = queryNotification.recordID
        
        //let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        //publicDatabase.fetchRecordWithID(, completionHandler: <#((CKRecord!, NSError!) -> Void)!##(CKRecord!, NSError!) -> Void#>)
        
        publicDatabase.fetchRecordWithID(recordID!, completionHandler: { result, error in
            if(error == nil) {
                let record: CKRecord = (result as CKRecord?)!
                
                if(record.recordType == "Items") {

                    let word: String = record.objectForKey("name") as! String
                
                    let entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
                
                    let request: NSFetchRequest = NSFetchRequest()
                    request.entity = entity
                
                    //let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
                    //var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
                
                    let predicate: NSPredicate = NSPredicate(format: "word = %@", word)
                    request.predicate = predicate
                    var mutableFetchResults: [Entity]
                    
                    do {
                        mutableFetchResults = try self.managedObjectContext!.executeFetchRequest(request) as! [Entity]
                    
                        if mutableFetchResults.count > 0 {
                            var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
                    
                            item = mutableFetchResults.last!
                    
                    
                            item.word = word
                            item.used = record.objectForKey("used") as! Int
                            item.completed = record.objectForKey("completed") as! Int
                    
                    
                            try self.managedObjectContext!.save()
                        
                            
                        
                        
                    
                        } else {
                            let entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
                    
                            let
                            addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
                    
                            addItem.word = word as String
                            addItem.used = record.objectForKey("used") as! Int
                            addItem.completed = record.objectForKey("completed") as! Int
                            //addItem.lastused = record.objectForKey("lastUsed") as! NSDate
                    
                            // if configManager have sharingEnabled add this item to public database as well.
                    
                            try self.managedObjectContext!.save()
                        
                        
                    
                        }
                    
                        self.delegate?.tableReload()
                    } catch _ {
                        
                    }
                
                }
                else if(record.recordType == "Invitations") {
                    
                    if(queryNotification.queryNotificationReason == CKQueryNotificationReason.RecordDeleted) {
                        // remove invitation fro core data
                        // remove invitation from cloudkit
                        // remove notifications
                        
                        let invitation = self.cdGetConfirmedInvitation()
                        
                        self.cdRemoveInvitation()
                        
                        self.ckRemoveInvitationSubscription(invitation.sender, receiver: invitation.receiver)
                        
                    } else {
                        self.delegate?.openAlertView(record)
                    }
                }
                
                
            }
            
        })
        
    }
    
    func ckFetchInvitations(show: String -> Void) {
        
        let container = CKContainer(identifier: "iCloud.QuickToDo")
        
        //var tmpRecord: CKRecord = CKRecord(recordType: "Invitations")
        
        //let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(type: .OrPredicateType, subpredicates: [NSPredicate(format: "receiver = %@", configManager.selfRecordId)])
        
        let predicate = NSPredicate(format:"receiver = %@", configManager.selfRecordId)
        
        let query: CKQuery = CKQuery(recordType: "Invitations", predicate: predicate)
        
        let publicDatabase = container.publicCloudDatabase
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                if(results!.count > 0) {
                    let record: CKRecord = (results?.first as CKRecord?)!
                    let name: String = record.objectForKey("sendername") as! String
                    show(name)
                }
                else {
                    show("")
                }
            }
            //var tmpIndex = index - 1
            //self.ckCheckRecord(tmpIndex, itemsToCheck: itemsToCheck, publicDatabase: publicDatabase)
        })
        
    }
    
    func inviteToShare(receiverICloud: String, receiverName: String) {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Invitations")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        let newRecord: CKRecord = CKRecord(recordType: "Invitations")
        newRecord.setObject(receiverICloud, forKey: "receiver")
        newRecord.setObject(0, forKey: "confirmed")
        newRecord.setObject(configManager.selfRecordId, forKey: "sender")
        newRecord.setObject(configManager.selfName, forKey: "sendername")
        newRecord.setObject(receiverName, forKey: "receivername")
        
        publicDatabase.saveRecord(newRecord, completionHandler:
            ({returnRecord, error in
                if let err = error {
                    print(err)
                } else {
                    print("Saved record \(index)")
                    
                }
            }))
        
    }
    
    func subscribeOnResponse() {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "sender = %@", configManager.selfRecordId)
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options: [CKSubscriptionOptions.FiresOnRecordUpdate])
        
        
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "A response on invitation has been received"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@",
                        err.localizedDescription)
                } else {
                    print("Success!!!")
                }
            }))
        
    }
    
    func subscribeOnInvitations() {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "receiver = %@", configManager.selfRecordId)
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options:[ CKSubscriptionOptions.FiresOnRecordCreation, CKSubscriptionOptions.FiresOnRecordUpdate])
        
        
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "A new invitation was received"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@",
                        err.localizedDescription)
                } else {
                    print("Success!!!")
                }
            }))
        
    }
    
    
    func subscribeOnItems(icloudmail: String) {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "icloudmail = %@", icloudmail)
        
        let subscription = CKSubscription(recordType: "Items",
            predicate: predicate,
            options:[ CKSubscriptionOptions.FiresOnRecordCreation, CKSubscriptionOptions.FiresOnRecordUpdate])
        
        let notificationInfo = CKNotificationInfo()
        
        
        notificationInfo.alertBody = "A new Item was added"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@",
                        err.localizedDescription)
                } else {
                    print("Success!!!")
                }
            }))
    }
    
    
    func removeUsedItems() {
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        let request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format:"used = 1 and completed = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext?.executeFetchRequest(request) as! [Entity]
        
            if(mutableFetchResults.count > 0) {
                for result in mutableFetchResults {
                    result.used = 0
                
                    let itemObject: ItemObject = ItemObject()
                    itemObject.word = result.word
                    itemObject.completed = Int(result.completed)
                    itemObject.used = Int(result.used)
                    itemObject.count = Int(result.count)
                    print("item removed : \(itemObject.word)")
                    try managedObjectContext?.save()
                
                    if(configManager.sharingEnabled > 0) {
                        self.ckFindItem(itemObject, operation: "remove")
                    }
                }
            }
        } catch _ {
            print("Error")
        }
        

        
    }
    
    func getHints(text: String) -> [String] {
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context = delegate.managedObjectContext
        
        var result: [String] = [String]()
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        let request: NSFetchRequest = NSFetchRequest()
        
        request.entity = item
        
        let sortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        let sortDescriptorNew = NSSortDescriptor(key: "count", ascending: false)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor, sortDescriptorNew]
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format: "word beginswith \"\(text)\"")
        request.predicate = predicate
        
        var mutableFetchResult: [Entity]
        
        do {
            
            mutableFetchResult = try managedObjectContext?.executeFetchRequest(request) as! [Entity]
            if(mutableFetchResult.count > 0) {
                let len: Int = (mutableFetchResult.count > 2) ? 2 : mutableFetchResult.count
            
                for i in 0 ..< len {
                    let item: Entity = mutableFetchResult[i]
                    result.append(item.word)
                }
            }
        } catch _ {
            
        }
        
        return result
        
    }
    
    func ckRemoveAllRecords(recordId: String) {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@", recordId)
        let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
                var recordsForDelete: [CKRecordID] = [CKRecordID]()
                
                for record in records {
                    recordsForDelete.insert(record.recordID, atIndex: 0)
                }
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordsForDelete)
                deleteOperation.perRecordCompletionBlock = { record, error in
                    if error != nil {
                        print("Unable to delete record: \(record). Error: \(error)")
                    }
                }
                deleteOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                    if error != nil {
                        if error!.code == CKErrorCode.PartialFailure.rawValue {
                            print("There was a problem completing the operation")
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
        
        let items: [String: ItemObject] = self.getItems()
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //let record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        var itemsForSaving: [CKRecord] = [CKRecord]()
        
        for item in items.values {
            let newRecord: CKRecord = CKRecord(recordType: "Items")
            newRecord.setObject(item.word, forKey: "name")
            newRecord.setObject(item.completed, forKey: "completed")
            newRecord.setObject(recordId, forKey: "icloudmail")
            newRecord.setObject(item.used, forKey: "used")
            itemsForSaving.append(newRecord)
            
        }
        //let returnRecords: [CKRecord] = [CKRecord]()
        
        self.ckCheckRecord(itemsForSaving.count, itemsToCheck: itemsForSaving, publicDatabase: publicDatabase)
        //self.saveRecursively(itemsForSaving.count, itemsForSaving: itemsForSaving, publicDatabase: publicDatabase)
        
    }
    
    private func ckAddRecord(record: CKRecord) {
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        let record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        publicDatabase.saveRecord(record, completionHandler: ({returnRecord, error in
            if let err = error {
                print(err)
            } else {
                print("Saved record \(index)")
                
            }
        }))
        
    }
    
    private func ckCheckRecord(index: Int, itemsToCheck: [CKRecord], publicDatabase: CKDatabase) {
        
        
        if (index > 0) {
            let tmpRecord: CKRecord = itemsToCheck[index-1]
            let predicate: NSPredicate = NSPredicate(format: "name = %@ and icloudmail = %@ and used = 1", tmpRecord.objectForKey("name") as! String, configManager.selfRecordId)
            let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
            publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
                if(error == nil) {
                    if results!.count == 0 {
                        self.returnRecords.append(tmpRecord)
                    }
                }
                let tmpIndex = index - 1
                self.ckCheckRecord(tmpIndex, itemsToCheck: itemsToCheck, publicDatabase: publicDatabase)
                })
            
        } else if (index == 0) {
            print("Finished checking!")
            self.saveRecursively(returnRecords.count, itemsForSaving: self.returnRecords, publicDatabase: publicDatabase)
        }
        
    }
    
    private func saveRecursively(index: Int, itemsForSaving: [CKRecord], publicDatabase: CKDatabase) {
        if (index > 0) {
            let tmpRecord: CKRecord = itemsForSaving[index-1]
            let name: String = tmpRecord.objectForKey("name") as! String
            print("name: \(name) for index: \(index)")
            publicDatabase.saveRecord(tmpRecord, completionHandler:
                ({returnRecord, error in
                    if let err = error {
                        print(err)
                    } else {
                        print("Saved record \(index)")

                    }
                    let tmpIndex = index - 1
                    self.saveRecursively(tmpIndex, itemsForSaving: itemsForSaving, publicDatabase: publicDatabase)
                }))
            
        } else if (index == 0) {
            print("Finished saving!")
        }
    }
    
    func updateItem(itemObject: ItemObject) {

        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context:NSManagedObjectContext = delegate.managedObjectContext!
        
        let entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        //var sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: false)
        //var sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        
        let predicate: NSPredicate = NSPredicate(format: "word = \"\(itemObject.word)\"")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Entity]
        
            if mutableFetchResults.count > 0 {
                var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext) as! Entity
            
                item = mutableFetchResults.last!
            
                item.word = itemObject.word as String
                item.used = itemObject.used
                item.completed = itemObject.completed
        
            
                try managedObjectContext!.save()
            
            }
        
            //if(configManager.sharingEnabled > 0) {
            ckFindItem(itemObject, operation: "complete")
            //}
        } catch _ {
            
        }
        
    }
    
    func ckFindItem(itemObject: ItemObject, operation: String) {
        
        
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        var completed = 0
        if(itemObject.completed == 0 && operation == "complete") {
            completed = 1
        }
        else if(itemObject.completed > 0 && operation == "complete") {
            completed = 0
        }
        else {
            completed = itemObject.completed
        }
        
        let icloudids = self.cdGetConfirmedInvitation()
        var senderVar = ""
        var receiverVar = ""
        
        
        switch (icloudids.sender, icloudids.receiver) {
        case let (.Some(sender), .Some(receiver)):
            senderVar = sender
            receiverVar = receiver
        case let (.Some(sender), .None):
            senderVar = sender
        case let (.None, .Some(receiver)):
            receiverVar = receiver
        case (.None, .None):
            print("No invitation")
        }
        
        var predicateFirst: NSPredicate = NSPredicate()
        var predicateSecond: NSPredicate = NSPredicate()
        
        if(senderVar != "" && receiverVar != "") {
            predicateFirst = NSPredicate(format: "icloudmail = %@ and completed = %d and name = %@ and used = 1", senderVar, completed, itemObject.word)
            predicateSecond = NSPredicate(format: "icloudmail = %@ and completed = %d and name = %@ and used = 1", receiverVar, completed, itemObject.word)
        } else {
            predicateFirst = NSPredicate(format: "icloudmail = %@ and completed = %d and name = %@ and used = 1", configManager.selfRecordId, completed, itemObject.word)
        }
        
        var query: CKQuery = CKQuery(recordType: "Items", predicate: predicateFirst)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
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
                        print("Unable to delete record: \(record). Error: \(error)")
                    }
                }
                updateOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                    if error != nil {
                        if error!.code == CKErrorCode.PartialFailure.rawValue {
                            print("There was a problem completing the operation")
                        }
                        //callback?(success: false)
                    }
                    //callback?(success: true)
                }
                publicDatabase.addOperation(updateOperation)
                
                
            }
            
        })
        
        if(receiverVar != "") {
            query = CKQuery(recordType: "Items", predicate: predicateSecond)
        
            publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
                if(error == nil) {
                    let records: [CKRecord] = (results as [CKRecord]?)!
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
                            print("Unable to delete record: \(record). Error: \(error)")
                        }
                    }
                    updateOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                        if error != nil {
                            if error!.code == CKErrorCode.PartialFailure.rawValue {
                                print("There was a problem completing the operation.")
                            }
                            //callback?(success: false)
                        }
                        //callback?(success: true)
                    }
                    publicDatabase.addOperation(updateOperation)
                
                
                }
            
            })
        }
    }
    
    func ckUpdateInvitation(updatedInvitation: InvitationObject) {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        let predicate: NSPredicate = NSPredicate(format: "sender = %@ and receiver = %@", updatedInvitation.sender, updatedInvitation.receiver)
        
        let query: CKQuery = CKQuery(recordType: "Invitations", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
                var modifiedRecords: [CKRecord] = [CKRecord]()
                
                for record in records {
                    record.setObject(updatedInvitation.sender, forKey:"sender")
                    record.setObject(updatedInvitation.receiver, forKey:"receiver")
                    record.setObject(updatedInvitation.confirmed, forKey:"confirmed")
                    record.setObject(updatedInvitation.sendername, forKey:"sendername")
                    record.setObject(updatedInvitation.receivername, forKey:"receivername")
                    
                    modifiedRecords.append(record)
                }
                let updateOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: nil)
                updateOperation.perRecordCompletionBlock = { record, error in
                    if error != nil {
                        print("Unable to delete record: \(record). Error: \(error)")
                    }
                }
                updateOperation.modifyRecordsCompletionBlock = { _, deleted, error in
                    if error != nil {
                        if error!.code == CKErrorCode.PartialFailure.rawValue {
                            print("There was a problem completing the operation.")
                        }
                        //callback?(success: false)
                    }
                    //callback?(success: true)
                }
                publicDatabase.addOperation(updateOperation)
                
                
            }
            
        })
        
    }
    
    func addItemOnlyCoreData(item: ItemObject) {
        objc_sync_enter(item)
        
        let entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
        
        addItem.word = item.word as String
        addItem.used = item.used
        addItem.completed = item.completed
        addItem.lastused = item.lasUsed
        
        do {
            
            try managedObjectContext!.save()
        } catch _ {
            
        }
        objc_sync_exit(item)
    }
    
    func addItem(item: ItemObject) {
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        let entity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let addItem = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext) as! Entity
        
        addItem.word = item.word as String
        addItem.used = item.used
        addItem.completed = item.completed
        addItem.lastused = item.lasUsed
        
        // if configManager have sharingEnabled add this item to public database as well.
        
        if (configManager.sharingEnabled == 1) {
            let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
            //var record: CKRecord = CKRecord(recordType: "Items")
            let publicDatabase: CKDatabase = container.publicCloudDatabase
            
            let newRecord: CKRecord = CKRecord(recordType: "Items")
            newRecord.setObject(item.word, forKey: "name")
            newRecord.setObject(item.completed, forKey: "completed")
            newRecord.setObject(configManager.selfRecordId, forKey: "icloudmail")
            newRecord.setObject(item.used, forKey: "used")
            
            publicDatabase.saveRecord(newRecord, completionHandler:
                ({returnRecord, error in
                    if let err = error {
                        print(err)
                    } else {
                        print("Saved record \(index)")
                        
                    }
            }))
        
        }
        
        do {
            
            try managedObjectContext!.save()
        } catch _ {
            
        }
        
    }
    
    func getNotCompletedItems() -> [String: ItemObject] {
        var result: [String: ItemObject] = [String: ItemObject]()
        
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format: "used = 1 and completed = 0")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Entity]
        
            if mutableFetchResults.count > 0 {
                for i in 0 ..< mutableFetchResults.count {
                    let item: Entity = mutableFetchResults[i]
                    let itemObject: ItemObject = ItemObject()
                    itemObject.word = item.word
                    itemObject.used = item.used.integerValue
                    itemObject.completed = item.completed.integerValue
                    itemObject.lasUsed = item.lastused
                    itemObject.count = item.count.integerValue
                
                    result[itemObject.word as String] = itemObject
                }
            }
        
            
        } catch _ {
            
        }
        return result
    }
    
    func getItems() -> [String: ItemObject] {
        var result: [String: ItemObject] = [String: ItemObject]()

        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format: "used = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Entity]
        
            if mutableFetchResults.count > 0 {
                for i in 0 ..< mutableFetchResults.count {
                    let item: Entity = mutableFetchResults[i]
                    let itemObject: ItemObject = ItemObject()
                    itemObject.word = item.word
                    itemObject.used = item.used.integerValue
                    itemObject.completed = item.completed.integerValue
                    itemObject.lasUsed = item.lastused
                    itemObject.count = item.count.integerValue
                
                    result[itemObject.word as String] = itemObject
                }
            }
        
            
        } catch _ {
            
        }
        return result
    }
    
    func getItem(text: String) -> ItemObject {
        let result: ItemObject = ItemObject()
        
        //var delegate: AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context = delegate.managedObjectContext
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        let request = NSFetchRequest()
        
        request.entity = item
        //let sortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        
        
        let predicate = NSPredicate(format: "used = 0 and word = \"\(text)\"")
        request.predicate = predicate
        
        //var itemObject: ItemObject = ItemObject()
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext?.executeFetchRequest(request) as! [Entity]
        
            if(mutableFetchResults.count > 0) {
                let item: Entity = mutableFetchResults[0]
            
                result.word = item.word
                result.used = item.used.integerValue
                result.completed = item.completed.integerValue
                result.lasUsed = item.lastused
                result.count = item.count.integerValue
            
            }
        
            
        } catch _ {
            
        }
        return result
    }
    
    func cdAddInvitation(newInvitation: InvitationObject) {
        
        let invitation = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        
        let addItem = NSManagedObject(entity: invitation!, insertIntoManagedObjectContext: self.managedObjectContext) as! Invitation
        
        addItem.receiver = newInvitation.receiver as String
        addItem.sender = newInvitation.sender as String
        addItem.confirmed = newInvitation.confirmed
        addItem.sendername = newInvitation.sendername as String
        addItem.receivername = newInvitation.receivername as String
        
        do {
            
            try managedObjectContext!.save()
        } catch _ {
            print("Error saving invitation")
        }
        
    }
    
    
    func cdGetInvitationFake() -> InvitationObject {
        
        let result: InvitationObject = InvitationObject()
        
        let item = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        let request = NSFetchRequest()
        
        request.entity = item
        
        //var itemObject: ItemObject = ItemObject()
        let predicate = NSPredicate(format: "sender = %@ or receiver = %@", self.configManager.selfRecordId, self.configManager.selfRecordId)
        request.predicate = predicate
        
        let invitations: [NSManagedObject]
        
        do {
            
            invitations = try managedObjectContext?.executeFetchRequest(request) as! [NSManagedObject]
            print("number of invitations found: \(invitations.count)")
            for invitation in invitations {
                if let item = invitation as? Invitation {
                    result.sender = item.sender
                    result.receiver = item.receiver
                    result.confirmed = item.confirmed.integerValue
                    result.sendername = item.sendername
                }
            }
            
        } catch _ {
            
        }
        return result
        
    }
    
    
    func cdGetInvitation(show: InvitationObject -> Void) {
        
        let result: InvitationObject = InvitationObject()
        
        let item = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        let request = NSFetchRequest()
        
        request.entity = item
        
        //var itemObject: ItemObject = ItemObject()
        let predicate = NSPredicate(format: "sender = %@ or receiver = %@", self.configManager.selfRecordId, self.configManager.selfRecordId)
        request.predicate = predicate
        
        let invitations: [NSManagedObject]
        
        do {
            
            invitations = try managedObjectContext?.executeFetchRequest(request) as! [NSManagedObject]
            print("number of invitations found: \(invitations.count)")
            for invitation in invitations {
                if let item = invitation as? Invitation {
                    result.sender = item.sender
                    result.receiver = item.receiver
                    result.confirmed = item.confirmed.integerValue
                    result.sendername = item.sendername
                }
            }
            
        } catch _ {
            
        }
        show(result)
        
    }
    
    func cdUpdateInvitation(updatedInvitation: InvitationObject) {
        
        let entity = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        let predicate: NSPredicate = NSPredicate(value: true)
        request.predicate = predicate
        
        var mutableFetchResults: [Invitation]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Invitation]
        
            if mutableFetchResults.count > 0 {
                var item = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: managedObjectContext) as! Invitation
            
                item = mutableFetchResults.last!
            
                item.sender = updatedInvitation.sender
                item.receiver = updatedInvitation.receiver
                item.confirmed = updatedInvitation.confirmed
                item.sendername = updatedInvitation.sendername
            
            
                try managedObjectContext!.save()
            
            }
        } catch _ {
            
        }
        
    }
    
    func cdGetConfirmedInvitation() -> (sender: String?, receiver: String?) {
        
        let entity = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        let predicate: NSPredicate = NSPredicate(format: "confirmed = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Invitation]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Invitation]
            //var results: [String] = [String]()
        
            if mutableFetchResults.count > 0 {
                let invitation: Invitation = mutableFetchResults[0] as Invitation
            
                return (invitation.sender, invitation.receiver)
            
            
            }
        } catch _ {
            
        }
        return(nil, nil)
    }
    
    func cdRemoveInvitation() {
        let entity = NSEntityDescription.entityForName("Invitation", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = entity
        
        //let predicate: NSPredicate = NSPredicate(format: "confirmed = 1")
        //request.predicate = predicate
        
        var mutableFetchResults: [Invitation]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Invitation]
            //var results: [String] = [String]()
        
            while(mutableFetchResults.count > 0) {
                let item = mutableFetchResults.last
                mutableFetchResults.removeLast()
                managedObjectContext?.deleteObject(item!)
            
            }
        } catch _ {
            
        }
        
    }
    
    func ckRemoveInvitation(sender: String?, receiver: String?) {
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        let predicate: NSPredicate
        
        if let unwrapedSender = sender {
            predicate = NSPredicate(format: "sender = %@", unwrapedSender)
        } else {
            predicate = NSPredicate(value: false)
        }
        
        let query = CKQuery(recordType: "Invitations", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
                //var modifiedRecords: [CKRecord] = [CKRecord]()
                
                for record in records {
                    //let recordId = record.recordID
                    
                    publicDatabase.deleteRecordWithID(record.recordID,
                        completionHandler: ({returnRecord, error in
                            if let err = error {
                                print("Error deleting \(err.description)")
                            } else {
                                print("Success delete")
                                //remove subscription
                                publicDatabase.fetchAllSubscriptionsWithCompletionHandler({subscriptions, error in
                                    var subscriptionsIdsToDelete: [String] = [String]()
                                    for subscriptionObject in subscriptions! {
                                        let subscription: CKSubscription = subscriptionObject as CKSubscription
                                        if(subscription.recordType == "Items") {
                                            subscriptionsIdsToDelete.append(subscription.subscriptionID)
                                        }
                                    }
                                    let subscriptionDeleteOperation = CKModifySubscriptionsOperation(subscriptionsToSave: nil, subscriptionIDsToDelete: subscriptionsIdsToDelete)
                                    subscriptionDeleteOperation.modifySubscriptionsCompletionBlock = { _, deleted, error in
                                        if error != nil {
                                            if error!.code == CKErrorCode.PartialFailure.rawValue {
                                                print("There was a problem completing the operation.")
                                            }
                                            //callback?(success: false)
                                        } else {
                                            self.subscribeOnItems(self.configManager.selfRecordId)
                                        }
                                        //callback?(success: true)
                                    }
                                    publicDatabase.addOperation(subscriptionDeleteOperation)
                                    
                                })
                            }
                        }))
                }
                
                
            }
            
        })
        
    }
    
    func ckRemoveInvitationSubscription(sender: String?, receiver: String?) {
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        publicDatabase.fetchAllSubscriptionsWithCompletionHandler({subscriptions, error in
            var subscriptionsIdsToDelete: [String] = [String]()
            for subscriptionObject in subscriptions! {
                let subscription: CKSubscription = subscriptionObject as CKSubscription
                if(subscription.recordType == "Items") {
                    subscriptionsIdsToDelete.append(subscription.subscriptionID)
                }
            }
            let subscriptionDeleteOperation = CKModifySubscriptionsOperation(subscriptionsToSave: nil, subscriptionIDsToDelete: subscriptionsIdsToDelete)
            subscriptionDeleteOperation.modifySubscriptionsCompletionBlock = { _, deleted, error in
                if error != nil {
                    if error!.code == CKErrorCode.PartialFailure.rawValue {
                        print("There was a problem completing the operation.")
                    }
                    //callback?(success: false)
                } else {
                    self.subscribeOnItems(self.configManager.selfRecordId)
                }
                //callback?(success: true)
            }
            publicDatabase.addOperation(subscriptionDeleteOperation)
            
        })
        
    }
    
    func cdGetItems() -> [String: ItemObject] {
        var result = [String: ItemObject]()
        
        
        //var delegate = UIApplication.sharedApplication().delegate as AppDelegate
        //var context: NSManagedObjectContext = delegate.managedObjectContext!
        
        let item = NSEntityDescription.entityForName("Entity", inManagedObjectContext: self.managedObjectContext!)
        
        let request: NSFetchRequest = NSFetchRequest()
        request.entity = item
        
        let sortDescriptor: NSSortDescriptor = NSSortDescriptor(key: "lastused", ascending: true)
        let sortDescriptors: [NSSortDescriptor] = [sortDescriptor]
        request.sortDescriptors = sortDescriptors
        
        let predicate: NSPredicate? = NSPredicate(format: "used = 1")
        request.predicate = predicate
        
        var mutableFetchResults: [Entity]
        
        do {
            
            mutableFetchResults = try managedObjectContext!.executeFetchRequest(request) as! [Entity]
            
            if mutableFetchResults.count > 0 {
                for i in 0 ..< mutableFetchResults.count {
                    let item: Entity = mutableFetchResults[i]
                    let itemObject: ItemObject = ItemObject()
                    itemObject.word = item.word
                    itemObject.used = item.used.integerValue
                    itemObject.completed = item.completed.integerValue
                    itemObject.lasUsed = item.lastused
                    itemObject.count = item.count.integerValue
                    
                    result[item.word] = itemObject
                    
                }
            }
            
            
        } catch _ {
            
        }
        return result
        
    }
    
    func getAllItemsFromCloud(updateTable: [String: ItemObject] -> Void) {
        
        //var newSelfItems: [ItemObject] = [ItemObject]()
        //var newSubItems: [ItemObject] = [ItemObject]()
        //var newItems: [ItemObject] = [ItemObject]()
        
        // get self cloud id
        //let selfCloudId: String = self.configManager.selfRecordId
        
        let icloudids = self.cdGetConfirmedInvitation()
        var senderVar = ""
        var receiverVar = ""
        
        
        switch (icloudids.sender, icloudids.receiver) {
        case let (.Some(sender), .Some(receiver)):
            senderVar = sender
            receiverVar = receiver
            ckGetAllItems(senderVar, completion: updateTable)
            ckGetAllItems(receiverVar, completion: updateTable)
        case let (.Some(sender), .None):
            senderVar = sender
        case let (.None, .Some(receiver)):
            receiverVar = receiver
        case (.None, .None):
            print("No invitation")
        }
        
        
        
        // get all items from that cloud id
        // get shared cloud id
        // get all items for that cloud id
        // merge two arrays
        // call updateTable
        
    }
    
    func ckGetAllItems(cloudID: String, completion: [String: ItemObject] -> Void) -> Void {
        var result: [String: ItemObject] = [String: ItemObject]()
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        //var record: CKRecord = CKRecord(recordType: "Items")
        let publicDatabase: CKDatabase = container.publicCloudDatabase
        
        let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@ AND used = 1", cloudID)
        
        let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        publicDatabase.performQuery(query, inZoneWithID: nil, completionHandler: { results, error in
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
                //var modifiedRecords: [CKRecord] = [CKRecord]()
                
                for record in records {
                    let tmpItem: ItemObject = ItemObject()
                    
                    tmpItem.word = record.objectForKey("name") as! String
                    tmpItem.completed = record.objectForKey("completed") as! Int
                    tmpItem.used = record.objectForKey("used") as! Int
                    
                    result[tmpItem.word as String] = tmpItem
                    
                }
                let localItems = self.getItems()
                for itemKey in localItems.keys {
                    result.removeValueForKey(itemKey)
                    
                }
                
                self.ckReceivedItems(result, completion: completion)
            }
        
        } )
    }
    
    func ckReceivedItems(items: [String: ItemObject], completion: [String: ItemObject] -> Void) -> Void {
        objc_sync_enter(itemsMap)
        for item in items.keys {
            itemsMap[item] = items[item]
            if let tmpItem = items[item] {
                self.addItemOnlyCoreData(tmpItem)
            }
        }
        objc_sync_exit(itemsMap)
        completion(itemsMap)
        
    }

   
}
