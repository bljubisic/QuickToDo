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

//MARK: QuickToDoProtocol and Variables
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
      return itemsPrivate.compactMap{ $0 }
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
    
    func getZone() -> CKRecordZone? {
        return self.cloudKit.inputs.getZone()
    }
    
    func prepareSharing() async -> (CKShare?, CKContainer?) {
        return await self.cloudKit.inputs.prepareShare()
    }
    
    func getItems() -> (Bool, Error?){
        Observable.merge([self.swiftData.outputs.items, self.cloudKit.outputs.items])
            .subscribe({(item) in
                if let itemElement = item.element {
                    self.itemsPrivate.onNext(itemElement)
                }
            }).disposed(by: disposeBag)
        _ = self.swiftData.inputs.getItems(withCompletion: nil)
        _ = self.cloudKit.inputs.getItems() { item in
            _ = self.items.filter{itemFiltered in itemFiltered.id == item.id}.map{itemMapped in
                if (itemMapped.done != item.done || itemMapped.shown != item.shown) {
                    let funcUpdate = self.swiftData.inputs.update()
                    _ = funcUpdate(item, item)
                }
            }
        }
        return (true, nil)
    }
    
    func add(_ item: Item, addToCloud: Bool) -> (Bool, Error?) {
        let newInsertFunction = self.swiftData.inputs.insert()
        let ckInsertFunctiomn = self.cloudKit.inputs.insert()
        self.itemsPrivate.onNext(newInsertFunction(item, nil).0)
        if addToCloud {
            _ = ckInsertFunctiomn(item) { (newItem, error) in
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
        items.forEach{item in
            _ = ckInsertFunctiomn(item){(newItem, error) in
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

