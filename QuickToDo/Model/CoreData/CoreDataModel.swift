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

final class CoreDataModel: QuickToDoCoreDataProtocol, QuickToDoCoreDataInputs, QuickToDoCoreDataOutputs {
    
    
    private var itemsPrivate: PublishSubject<Item>
    
    var items: Observable<Item> {
        return itemsPrivate
    }
    
    var inputs: QuickToDoCoreDataInputs { return self }
    
    var outputs: QuickToDoCoreDataOutputs { return self }
    
    init() {
        itemsPrivate = PublishSubject()
    }
    
    // MARK: Variables
    
    lazy var applicationDocumentsDirectory: NSURL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.persukibo.QuickToDoSharingDefaults") ?? nil
        }() as NSURL?
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "QuickToDo", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
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
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    func getItems() -> (Bool, Error?) {
        
        let itemEntity = NSEntityDescription.entity(forEntityName: "Item", in: self.managedObjectContext!)
        let request: NSFetchRequest<ItemMO> = NSFetchRequest()
        request.entity = itemEntity
        
        do {
            let fetchedItems = try self.managedObjectContext!.fetch(request as! NSFetchRequest<NSFetchRequestResult>) as! [ItemMO]
            for itemMO in fetchedItems {
                let tmpItem: Item = Item(name: itemMO.word,
                                         count: itemMO.count,
                                         uploadedToICloud: itemMO.uploadedToICloud,
                                         done: itemMO.completed,
                                         shown: itemMO.used,
                                         createdAt: itemMO.lastused)
                itemsPrivate.onNext(tmpItem)
            }
        } catch {
            //fatalError("Failed to fetch profiles: \(error)")
            return(false, error)
        }
        return (true, nil)
    }
    
    func insert(_ item:Item) -> Item {
        
        let itemMO: ItemMO = ItemMO.insertIntoContext(moc: self.managedObjectContext!, item: item)

        return Item(name: itemMO.word,
                    count: itemMO.count,
                    uploadedToICloud: itemMO.uploadedToICloud,
                    done: itemMO.completed,
                    shown: itemMO.used,
                    createdAt: itemMO.lastused)
        
    }
    
    func getItemWith(_ itemWord: String) -> Item {
        let item = Item()
        let itemEntity = NSEntityDescription.entity(forEntityName: "Item", in: self.managedObjectContext!)
        let request: NSFetchRequest<ItemMO> = NSFetchRequest()
        request.entity = itemEntity
        
        let predicate: NSPredicate = NSPredicate(format: "word = \(itemWord)")
        
        request.predicate = predicate
        
        do {
            let fetchedItems = try self.managedObjectContext!.fetch(request as! NSFetchRequest<NSFetchRequestResult>) as! [ItemMO]
            for itemMO in fetchedItems {
                return Item(name: itemMO.word,
                            count: itemMO.count,
                            uploadedToICloud: itemMO.uploadedToICloud,
                            done: itemMO.completed,
                            shown: itemMO.used,
                            createdAt: itemMO.lastused)
            }
        } catch {
            fatalError("Failed to fetch profiles: \(error)")
        }
        return item
        
    }
    
    func update(_ item: Item, withItem: Item) -> Item {
        let resultValue: (ItemMO?, Bool) = ItemMO.updateIntoContext(moc: self.managedObjectContext!, item: withItem)
        if resultValue.1 == true {
            guard let itemMO = resultValue.0 else {
                return Item()
            }
            return Item(name: itemMO.word,
                        count: itemMO.count,
                        uploadedToICloud: itemMO.uploadedToICloud,
                        done: itemMO.completed,
                        shown: itemMO.used,
                        createdAt: itemMO.lastused)
        }
        return Item()
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) -> Void{
        var items: [Item] = [Item]()
        let itemEntity = NSEntityDescription.entity(forEntityName: "Item", in: self.managedObjectContext!)
        let request: NSFetchRequest<ItemMO> = NSFetchRequest()
        request.entity = itemEntity
        
        let predicate: NSPredicate = NSPredicate(format: "word beginswith \(itemName)")
        
        request.predicate = predicate
        
        do {
            let fetchedItems = try self.managedObjectContext!.fetch(request as! NSFetchRequest<NSFetchRequestResult>) as! [ItemMO]
            for itemMO in fetchedItems {
                let tmpItem: Item = Item(name: itemMO.word,
                                         count: itemMO.count,
                                         uploadedToICloud: itemMO.uploadedToICloud,
                                         done: itemMO.completed,
                                         shown: itemMO.used,
                                         createdAt: itemMO.lastused)
                items.append(tmpItem)
            }
        } catch {
            //fatalError("Failed to fetch profiles: \(error)")
            withCompletion(Item(), Item())
        }
        if(items.count > 2) {
            withCompletion(items[0], items[1])
        } else if(items.count == 1) {
            withCompletion(items[0], Item())
        } else {
            withCompletion(Item(), Item())
        }
    }
    
}

