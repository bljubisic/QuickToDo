//
//  SwiftDataModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 7/23/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//
import RxSwift
import SwiftData
import Foundation
import CloudKit

@MainActor
final class SwiftDataModel: StorageProtocol {
    
    private var itemsPrivate: PublishSubject<Item?>
    private let container: ModelContainer
    
    init() {
        itemsPrivate = PublishSubject()
        
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            fatalError("Shared file container could not be created.")
        }
        let url = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")

        do {
            container = try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
    }
    
}

extension SwiftDataModel: StorageInputs {
    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        var descriptor = FetchDescriptor<ItemSD>(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        let item = Item()
        
        if let items = try? self.container.mainContext.fetch<ItemSD>(descriptor) {
            for item in items {
                let tmpItem = Item(id: UUID(uuidString: item.uuid!)!,
                                   name: item.word!,
                                   count: item.count!,
                                   uploadedToICloud: item.uploadedToICloud!,
                                   done: item.completed!,
                                   shown: item.used!,
                                   createdAt: item.lastUsed!,
                                   lastUsedAt: item.lastUsed!)
                itemsPrivate.onNext(tmpItem)
            }
        }
        return (true, nil)
    }
    
    func insert() -> itemProcess {
        return { item, completionHandler  in
            let itemSD: ItemSD = ItemSD(
                completed: item.done,
                count: item.count,
                lastUsed: item.lastUsedAt,
                used: item.shown,
                word: item.name,
                uploadedToICloud: item.uploadedToICloud,
                uuid: item.id.uuidString
            )
            self.container.mainContext.insert(itemSD)
            return (Item(id: UUID(uuidString: itemSD.uuid!)!,
                         name: itemSD.word!,
                        count: itemSD.count!,
                        uploadedToICloud: itemSD.uploadedToICloud!,
                        done: itemSD.completed!,
                        shown: itemSD.used!,
                        createdAt: itemSD.lastUsed!,
                        lastUsedAt: itemSD.lastUsed!), true)
        }
    }
    
    func getItemWith() -> itemProcessFind {
        return { itemWord in
            let item = Item()
            
            let predicate = #Predicate<ItemSD> {item in item.word == itemWord}
            var descriptor = FetchDescriptor(predicate: predicate)

            if let fetchedItems =  try? self.container.mainContext.fetch<ItemSD>(descriptor) {
                if let itemSD = fetchedItems.first {
                    return (Item(id: UUID(uuidString: itemSD.uuid!)!,
                                name: itemSD.word!,
                                count: itemSD.count!,
                                uploadedToICloud: itemSD.uploadedToICloud!,
                                done: itemSD.completed!,
                                shown: itemSD.used!,
                                createdAt: itemSD.lastUsed!,
                                lastUsedAt: itemSD.lastUsed!), true)
                }
            }

            return (item, false)
        }
    }
    
    private func updateIntoContext(withItem item: Item, itemID: String) -> (ItemSD?, Bool) {
        let predicate = #Predicate<ItemSD> { itemFound in itemFound.uuid == itemID }
        var descriptor = FetchDescriptor(predicate: predicate)
        if let oldItems = try? self.container.mainContext.fetch<ItemSD>(descriptor) {
            if let oldItem = oldItems.first {
                oldItem.completed = item.done
                oldItem.count = item.count
                oldItem.lastUsed = Date()
                oldItem.used = item.shown
                oldItem.word = item.name
                oldItem.uploadedToICloud = item.uploadedToICloud
                oldItem.uuid = item.id.uuidString
                self.container.mainContext.insert(oldItem)
                return (oldItem, true)
            }
        }
        return (nil, false)
    }
    
    func update() -> itemProcessUpdate {
        return { (item, withItem) in
            let resultValue: (ItemSD?, Bool) = self.updateIntoContext(withItem: withItem, itemID: withItem.id.uuidString)
            if resultValue.1 == true {
                guard let itemMO = resultValue.0 else {
                    return (Item(), false)
                }
                return (Item(id: UUID(uuidString: itemMO.uuid!)!,
                            name: itemMO.word!,
                            count: itemMO.count!,
                            uploadedToICloud: itemMO.uploadedToICloud!,
                            done: itemMO.completed!,
                            shown: itemMO.used!,
                            createdAt: itemMO.lastUsed!,
                            lastUsedAt: itemMO.lastUsed!), true)
            }
            return (Item(), false)
        }
    }
    
    func getItemWithId() -> itemProcessFindWithID {
        return { id in
            let predicate = #Predicate<ItemSD> {item in item.uuid! == id.uuidString}
            let descriptor = FetchDescriptor(predicate: predicate)
            let item = Item()
            
            if let items = try? self.container.mainContext.fetch<ItemSD>(descriptor) {
                if let item = items.first {
                    return (Item(id: UUID(uuidString: item.uuid!)!,
                                 name: item.word!,
                                 count: item.count!,
                                 uploadedToICloud: item.uploadedToICloud!,
                                 done: item.completed!,
                                 shown: item.used!,
                                 createdAt: item.lastUsed!,
                                 lastUsedAt: item.lastUsed!), true)
                }
                return (item, false)
            }
            return (item, false)
        }
        
    }
    
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) {
        var items: [Item] = [Item]()
        
        let predicate = #Predicate<ItemSD> {item in item.word!.starts(with: itemName)}
        let descriptor = FetchDescriptor(predicate: predicate)
        

        if let fetchedItems = try? self.container.mainContext.fetch<ItemSD>(descriptor) {
            for itemMO in fetchedItems.filter({(item) in item === ItemSD.self}) {
                let tmpItem: Item = Item(id: UUID(uuidString: itemMO.uuid!)!,
                                         name: itemMO.word!,
                                         count: itemMO.count!,
                                         uploadedToICloud: itemMO.uploadedToICloud!,
                                         done: itemMO.completed!,
                                         shown: itemMO.used!,
                                         createdAt: itemMO.lastUsed!,
                                         lastUsedAt: itemMO.lastUsed!)
                items.append(tmpItem)
            }
        }
        if(items.count > 1) {
            withCompletion(items[0], items[1])
        } else if(items.count == 1) {
            withCompletion(items[0], Item())
        } else {
            withCompletion(Item(), Item())
        }

    }
    
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        
    }
    
    func getRootRecord() -> CKRecord? {
        return nil
    }
    
    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        return(true, nil)
    }
    
    func getZone() -> CKRecordZone? {
        return nil
    }
    
    
}

extension SwiftDataModel: StorageOutputs {
    var items: RxSwift.Observable<Item?> {
        return itemsPrivate.subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    var inputs: StorageInputs { return self }
    
    var outputs: StorageOutputs { return self }
    
}
