//
//  CoreDataModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 05.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CoreData
import RxSwift
import CloudKit
//MARK: StorageProtocol
final class CoreDataModel: StorageProtocol {

    private var itemsPrivate: PublishSubject<Item?>
    
    // MARK: CoreData Variables
    
    lazy private var applicationDocumentsDirectory: NSURL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.QuickToDoSharingDefaults") ?? nil
        }() as NSURL?
    
    lazy private var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "QuickToDo", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy private var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory!.appendingPathComponent("QuickToDo.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            
            try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            
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
    
    lazy private var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    init() {
        itemsPrivate = PublishSubject()
    }
}
//MARK: StorageInputs
extension CoreDataModel: StorageInputs {
    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getRootRecord() -> CKRecord? {
        return nil
    }
    func getZone() -> CKRecordZone? {
        return nil
    }
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        
    }
    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        guard let moc = self.managedObjectContext else {
            return (false, nil)
        }
        let fetchedItems =  ItemMO.fetchInContext(context: moc) { request in
            request.returnsObjectsAsFaults = false
        }
        for itemMO in fetchedItems {
            let tmpItem: Item = Item(name: itemMO.word,
                                     count: itemMO.count,
                                     uploadedToICloud: itemMO.uploadedToICloud,
                                     done: itemMO.completed,
                                     shown: itemMO.used,
                                     createdAt: itemMO.lastused,
                                     lastUsedAt: itemMO.lastused)
            itemsPrivate.onNext(tmpItem)
        }
        return (true, nil)
    }
    
    func insert() -> itemProcess {
        return { item, completionHandler  in
            let itemMO: ItemMO = ItemMO.insertIntoContext(moc: self.managedObjectContext!, item: item)
            return (Item(name: itemMO.word,
                        count: itemMO.count,
                        uploadedToICloud: itemMO.uploadedToICloud,
                        done: itemMO.completed,
                        shown: itemMO.used,
                        createdAt: itemMO.lastused,
                        lastUsedAt: itemMO.lastused), true)
        }
    }
    
    func getItemWith() -> itemProcessFind {
        return { itemWord in
            let item = Item()
            
            let predicate: NSPredicate = NSPredicate(format: "word = \"\(itemWord)\"")
            
            guard let moc = self.managedObjectContext else {
                return (item, false)
            }
            let fetchedItems =  ItemMO.fetchInContext(context: moc) { request in
                request.predicate = predicate
                request.returnsObjectsAsFaults = false
            }
            for itemMO in fetchedItems {
                return (Item(name: itemMO.word,
                            count: itemMO.count,
                            uploadedToICloud: itemMO.uploadedToICloud,
                            done: itemMO.completed,
                            shown: itemMO.used,
                            createdAt: itemMO.lastused,
                            lastUsedAt: itemMO.lastused), true)
            }
            return (item, false)
        }
    }
    
    func update() -> itemProcessUpdate {
        return { (item, withItem) in
            let resultValue: (ItemMO?, Bool) = ItemMO.updateIntoContext(moc: self.managedObjectContext!, item: withItem)
            if resultValue.1 == true {
                guard let itemMO = resultValue.0 else {
                    return (Item(), false)
                }
                return (Item(name: itemMO.word,
                            count: itemMO.count,
                            uploadedToICloud: itemMO.uploadedToICloud,
                            done: itemMO.completed,
                            shown: itemMO.used,
                            createdAt: itemMO.lastused,
                            lastUsedAt: itemMO.lastused), true)
            }
            return (Item(), false)
        }
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) -> Void {
        var items: [Item] = [Item]()
        
        let predicate: NSPredicate = NSPredicate(format: "word beginswith \"\(itemName)\"")
        
        guard let moc = self.managedObjectContext else {
            return
        }
        let fetchedItems = ItemMO.fetchInContext(context: moc) { request in
            request.predicate = predicate
            request.returnsObjectsAsFaults = false
        }
        for itemMO in fetchedItems.filter({(item) in item === ItemMO.self}) {
            let tmpItem: Item = Item(name: itemMO.word,
                                     count: itemMO.count,
                                     uploadedToICloud: itemMO.uploadedToICloud,
                                     done: itemMO.completed,
                                     shown: itemMO.used,
                                     createdAt: itemMO.lastused,
                                     lastUsedAt: itemMO.lastused)
            items.append(tmpItem)
        }
        if(items.count > 1) {
            withCompletion(items[0], items[1])
        } else if(items.count == 1) {
            withCompletion(items[0], Item())
        } else {
            withCompletion(Item(), Item())
        }
    }
}

extension CoreDataModel: StorageOutputs {
    var items: Observable<Item?> {
        return itemsPrivate.subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    var inputs: StorageInputs { return self }
    
    var outputs: StorageOutputs { return self }
}
