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

final class SwiftDataModel: StorageProtocol {

    var modelContext: ModelContext

    private var itemsPrivate: PublishSubject<Item?>

    init() {
        itemsPrivate = PublishSubject()
        modelContext = ModelContext(sharedModelContainer)
    }

}

extension SwiftDataModel: StorageInputs {

    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?) {
        let descriptor = FetchDescriptor<ItemSD>(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])

        if let items = try? self.modelContext.fetch(descriptor) {
            for item in items {
                guard let tmpItem = item.toItem() else { continue }
                itemsPrivate.onNext(tmpItem)
                withCompletion?(tmpItem)
            }
        }
        return (true, nil)
    }

    func insert() -> ItemProcess {
        return { item, _  in
            let itemSD: ItemSD = ItemSD(
                completed: item.done,
                count: item.count,
                lastUsed: item.lastUsedAt,
                used: item.shown,
                word: item.name,
                uploadedToICloud: item.uploadedToICloud,
                uuid: item.id.uuidString
            )
            self.modelContext.insert(itemSD)
            try? self.modelContext.save()
            guard let savedItem = itemSD.toItem() else {
                return (item, true)
            }
            return (savedItem, true)
        }
    }

    func getItemWith() -> ItemProcessFind {
        return { itemWord in
            let predicate = #Predicate<ItemSD> {item in item.word == itemWord}
            let descriptor = FetchDescriptor(predicate: predicate)

            if let fetchedItems = try? self.modelContext.fetch(descriptor),
               let itemSD = fetchedItems.first,
               let foundItem = itemSD.toItem() {
                return (foundItem, true)
            }

            return (Item(), false)
        }
    }

    private func updateIntoContext(withItem item: Item, itemID: String) -> (ItemSD?, Bool) {
        let predicate = #Predicate<ItemSD> { itemFound in itemFound.uuid == itemID }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let oldItems = try? self.modelContext.fetch(descriptor) {
            if let oldItem = oldItems.first {
                oldItem.completed = item.done
                oldItem.count = item.count
                oldItem.lastUsed = Date.now
                oldItem.used = item.shown
                oldItem.word = item.name
                oldItem.uploadedToICloud = item.uploadedToICloud
                oldItem.uuid = item.id.uuidString
                try? self.modelContext.save()
                return (oldItem, true)
            }
        }
        return (nil, false)
    }

    func update() -> ItemProcessUpdate {
        return { (_, withItem) in
            let resultValue: (ItemSD?, Bool) = self.updateIntoContext(withItem: withItem, itemID: withItem.id.uuidString)
            if resultValue.1,
               let itemSD = resultValue.0,
               let updatedItem = itemSD.toItem() {
                return (updatedItem, true)
            }
            return (Item(), false)
        }
    }

    func getItemWithId() -> ItemProcessFindWithID {
        return { id in
            let idString = id.uuidString
            let predicate = #Predicate<ItemSD> { item in item.uuid == idString }
            let descriptor = FetchDescriptor(predicate: predicate)

            if let items = try? self.modelContext.fetch(descriptor),
               let itemSD = items.first,
               let foundItem = itemSD.toItem() {
                return (foundItem, true)
            }
            return (Item(), false)
        }
    }

    func getHints(for itemName: String, withCompletion: @escaping (Item, Item) -> Void) {
        var items: [Item] = []

        let predicate = #Predicate<ItemSD> { item in item.word?.starts(with: itemName) ?? false }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let fetchedItems = try? self.modelContext.fetch(descriptor) {
            for itemSD in fetchedItems {
                guard let tmpItem = itemSD.toItem() else { continue }
                items.append(tmpItem)
            }
        }
        if items.count > 1 {
            withCompletion(items[0], items[1])
        } else if items.count == 1 {
            withCompletion(items[0], Item())
        } else {
            withCompletion(Item(), Item())
        }
    }

    /// This method is unimplemented here. Actual iCloud sharing is provided in CloudKitModel.
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async throws {
        let error = NSError(domain: "SwiftDataModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud sharing not supported in local model."])
        handler(nil, nil, error)
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

    func getCurrentShareStatus() -> CKShare? {
        return nil
    }

    func isListCurrentlyShared() -> Bool {
        return false
    }

    func refreshShareStatus() async throws -> CKShare? {
        return nil
    }

    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        // SwiftData doesn't handle CloudKit shares directly, so return empty
        return (true, nil)
    }

    func insertToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        // SwiftData doesn't handle CloudKit shared zones directly
        let error = NSError(domain: "SwiftDataModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Shared zone insert not supported in local model."])
        completion(item, error)
    }

}

extension SwiftDataModel: StorageOutputs {

    var items: RxSwift.Observable<Item?> {
        return itemsPrivate.subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    var inputs: StorageInputs { return self }

    var outputs: StorageOutputs { return self }

}
