//
//  QuickToDoModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 02.10.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import CloudKit

// MARK: QuickToDoProtocol and Variables
class QuickToDoModel: QuickToDoProtocol {
    private let itemsPrivate: PublishSubject<Item?> = PublishSubject()
    private let cloudStatusPrivate: PublishSubject<CloudStatus> = PublishSubject()
    private let itemHints: PublishSubject<String> = PublishSubject()
    private let disposeBag = DisposeBag()
    private var configPriv = QuickToDoConfig()
//    private var coreData: StorageProtocol
    private var swiftData: StorageProtocol
    private var cloudKit: StorageProtocol

    init(_ withSwiftData: StorageProtocol, _ withCloudKit: StorageProtocol) {
        swiftData = withSwiftData
        cloudKit = withCloudKit

        // Set up the merge subscription once to forward storage emissions to itemsPrivate.
        // This must not be repeated per-call to avoid duplicate subscriptions.
        Observable.merge([swiftData.outputs.items, cloudKit.outputs.items])
            .subscribe(onNext: { [weak self] item in
                self?.itemsPrivate.onNext(item)
            })
            .disposed(by: disposeBag)
    }
}
// MARK: QuickToDoOutputs
extension QuickToDoModel: QuickToDoOutputs {
    var config: QuickToDoConfig {
        get {
            return configPriv
        }
    }
    var items: Observable<Item> {
      return itemsPrivate.compactMap { $0 }
    }

    var cloudStatus: Observable<CloudStatus> {
        return cloudStatusPrivate
    }

    var inputs: QuickToDoInputs { return self }

    var outputs: QuickToDoOutputs { return self }
}

// MARK: QuickToDoInputs
extension QuickToDoModel: QuickToDoInputs {

    func save(config: QuickToDoConfig) -> (Bool, Error?) {
        configPriv = QuickToDoConfig.showDoneItemsLens.set(config.showDoneItems, configPriv)
        if let encodedConfig = try? JSONEncoder().encode(configPriv) {
           UserDefaults.standard.set(encodedConfig, forKey: "Config")
        }
        return (true, nil)
    }

    func getConfig() -> QuickToDoConfig? {
        if let decodedData = UserDefaults.standard.object(forKey: "Config") as? Data {
           if let config = try? JSONDecoder().decode(QuickToDoConfig.self, from: decodedData) {
               configPriv = config
               return config
          }
        }
        return nil
    }

    func getRootRecord() -> CKRecord? {
        return self.cloudKit.inputs.getRootRecord()
    }

    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        return self.cloudKit.inputs.getSharedItems(for: root, with: completion)
    }

    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        return self.cloudKit.inputs.fetchAllSharedItems(completion: completion)
    }

    func getZone() -> CKRecordZone? {
        return self.cloudKit.inputs.getZone()
    }

    func getCurrentShareStatus() -> CKShare? {
        return self.cloudKit.inputs.getCurrentShareStatus()
    }

    func isListCurrentlyShared() -> Bool {
        return self.cloudKit.inputs.isListCurrentlyShared()
    }

    func refreshShareStatus() async throws -> CKShare? {
        return try await self.cloudKit.inputs.refreshShareStatus()
    }

    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        Task {
            do {
                try await self.cloudKit.inputs.prepareShare(handler: handler)
            } catch {
                print("Error: \(error)")
            }
        }
    }

    func getItems() -> (Bool, Error?) {
        // Collect SwiftData items first for conflict resolution
        var localItems: [Item] = []
        _ = self.swiftData.inputs.getItems { item in
            localItems.append(item)
        }

        // Fetch CloudKit items and resolve conflicts against local data.
        // Rule: the source with the newer lastUsedAt wins.
        _ = self.cloudKit.inputs.getItems { cloudItem in
            guard let localMatch = localItems.first(where: { $0.id == cloudItem.id }) else {
                return // No local copy — CloudKit item is new, already forwarded via merge subscription
            }

            if cloudItem.lastUsedAt > localMatch.lastUsedAt {
                // CloudKit is newer — update SwiftData with CloudKit's data
                let funcUpdate = self.swiftData.inputs.update()
                _ = funcUpdate(localMatch, cloudItem)
            } else if cloudItem.lastUsedAt < localMatch.lastUsedAt {
                // SwiftData is newer — update CloudKit with SwiftData's data
                let funcUpdate = self.cloudKit.inputs.update()
                _ = funcUpdate(cloudItem, localMatch)
            } else if localMatch.done != cloudItem.done || localMatch.shown != cloudItem.shown {
                // Same timestamp but different state — prefer CloudKit (it is the shared source of truth)
                let funcUpdate = self.swiftData.inputs.update()
                _ = funcUpdate(localMatch, cloudItem)
            }
        }
        return (true, nil)
    }

    func addToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        self.cloudKit.inputs.insertToSharedZone(item, completion: completion)
    }

    func add(_ item: Item, addToCloud: Bool) -> (Bool, Error?) {
        let newInsertFunction = self.swiftData.inputs.insert()
        let ckInsertFunctiomn = self.cloudKit.inputs.insert()
        self.itemsPrivate.onNext(newInsertFunction(item, nil).0)
        if addToCloud {
            _ = ckInsertFunctiomn(item) { (newItem, _) in
                let updateFunction = self.swiftData.inputs.update()
                _ = updateFunction(item, newItem)
                self.itemsPrivate.onNext(newItem)
            }
        }
        return (true, nil)
    }

    func update(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        _ = self.updateToCloudKit(item, withItem: newItem)
        _ = self.updateToSwiftData(item, withItem: newItem)
        return (true, nil)
    }

    private func updateToCloudKit(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        let superNewItem = self.cloudKit.inputs.update()
        self.itemsPrivate.onNext(superNewItem(item, newItem).0)
        return (true, nil)
    }

    private func updateToSwiftData(_ item: Item, withItem newItem: Item) -> (Bool, Error?) {
        let superNewItem = self.swiftData.inputs.update()
        self.itemsPrivate.onNext(superNewItem(item, newItem).0)
        return(true, nil)
    }

    func getHints(for itemName: String) -> Observable<String> {
        return self.getHintsFromSwiftData(for: itemName)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .observe(on: MainScheduler.instance)
    }

    func uploadToCloud(items: [Item]) -> (Bool, Error?) {
        let ckInsertFunctiomn = self.cloudKit.inputs.insert()
        items.forEach {item in
            _ = ckInsertFunctiomn(item) {(newItem, _) in
                let updateFunction = self.swiftData.inputs.update()
                _ = updateFunction(item, newItem)
                self.itemsPrivate.onNext(newItem)
            }
        }
        return(true, nil)
    }

    private func getHintsFromCloudKit(for itemName: String) -> Observable<String> {
        return Observable.create({ (observer) -> Disposable in
            self.cloudKit.inputs.getHints(for: itemName) { (firstItem, secondItem) in
                observer.onNext(firstItem.name)
                observer.onNext(secondItem.name)
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }

    private func getHintsFromSwiftData(for itemName: String) -> Observable<String> {
        return Observable.create({ (observer) -> Disposable in
            self.swiftData.inputs.getHints(for: itemName) { (firstItem, secondItem) in
                observer.onNext(firstItem.name)
                observer.onNext(secondItem.name)
                observer.onCompleted()
            }
            return Disposables.create()
        })
    }
}
