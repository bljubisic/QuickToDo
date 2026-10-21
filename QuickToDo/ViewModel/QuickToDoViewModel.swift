//
//  QuickToDoViewModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 17.11.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import Combine
import CloudKit
// MARK: QuickToDoViewModelProtocol
class QuickToDoViewModel: QuickToDoViewModelProtoocol, ObservableObject {
    var model: QuickToDoProtocol

    var cloudStatus: Observable<CloudStatus>

    var items: Observable<Item>

    @Published public var itemsArray: [Item]

    let disposeBag = DisposeBag()
    typealias ReturnVoid = () -> Void

    /// How long the items stream must stay quiet before a load counts as finished
    private static let itemsLoadSettleInterval: RxTimeInterval = .milliseconds(300)

    /// Called once after a burst of item changes (e.g. to reload the widget)
    private var itemsLoadedCompletion: ReturnVoid?
    private let itemsChanged = PublishSubject<Void>()

    init(_ withModel: QuickToDoProtocol = ModelMocked()) {
        self.model = withModel
        items = self.model.outputs.items
        cloudStatus = self.model.outputs.cloudStatus
        itemsArray = [Item]()
        bindItems()
    }

    /// Subscribes to the model's items exactly once for the ViewModel's lifetime.
    /// `MainScheduler.asyncInstance` always hops to a later run-loop turn, so the
    /// `@Published` writes never happen while SwiftUI is evaluating a view body.
    private func bindItems() {
        model.outputs.items
            .observe(on: MainScheduler.asyncInstance)
            .filter { !$0.name.isEmpty }
            .subscribe(onNext: { [weak self] newItem in
                self?.merge(newItem)
            }, onError: { error in
                print("Items stream failed: \(error)")
            })
            .disposed(by: disposeBag)

        itemsChanged
            .debounce(Self.itemsLoadSettleInterval, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.itemsLoadedCompletion?()
            })
            .disposed(by: disposeBag)
    }

    /// Appends a new item or replaces an existing one when the incoming copy is newer
    private func merge(_ newItem: Item) {
        guard let index = itemsArray.firstIndex(where: { $0.id == newItem.id }) else {
            itemsArray.append(newItem)
            itemsChanged.onNext(())
            return
        }
        if itemsArray[index].lastUsedAt < newItem.lastUsedAt {
            itemsArray[index] = newItem
            itemsChanged.onNext(())
        }
    }
}
// MARK: QuickToDoViewModelInputs
extension QuickToDoViewModel: QuickToDoViewModelInputs {

    func save(config: Bool) -> (Bool, Error?) {
        let config = QuickToDoConfig(showDoneItems: config)
        return self.model.inputs.save(config: config)
    }

    func getConfig() -> Bool {
        let config = self.model.inputs.getConfig()
        guard let configUnWrapped = config else {
            return false
        }
        return configUnWrapped.showDoneItems
    }

    func getZone() -> CKRecordZone? {
        return self.model.inputs.getZone()
    }

    func getCurrentShareStatus() -> CKShare? {
        return self.model.inputs.getCurrentShareStatus()
    }

    func isListCurrentlyShared() -> Bool {
        return self.model.inputs.isListCurrentlyShared()
    }

    func refreshShareStatus() async throws -> CKShare? {
        return try await self.model.inputs.refreshShareStatus()
    }

    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        self.model.inputs.prepareSharing(handler: handler)
    }

    func add(_ newItem: Item) -> (Bool, Error?) {
//        print("Calling add with: \(newItem)")
        return self.model.inputs.add(newItem, addToCloud: true)
    }

    func addToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void) {
        self.model.inputs.addToSharedZone(item) { savedItem, error in
            DispatchQueue.main.async {
                if error == nil {
                    self.itemsArray.append(savedItem)
                }
                completion(savedItem, error)
            }
        }
    }

    private func getFilteredItemsNum(filterImpl done: Bool) -> Observable<Int> {
        return Observable.create({ (observer) -> Disposable in
            self.model.outputs.items.subscribe(onNext: { (_) in
                observer.onNext(self.itemsArray.filter({ (item) -> Bool in
                    return ((done) ? (item.done == done) : true)
                }).count)
            }).disposed(by: self.disposeBag)
            return Disposables.create()
        })
    }

    private func getTotalItemNumbers() -> Observable<Int> {
        return self.model.outputs.items
                .filter { (item) -> Bool in
                    return item.shown == true
                }
                .scan(0) { (priorValue, _) -> Int in
                    return priorValue + 1
                }
    }

    private func getDoneItemNumbers() -> Observable<Int> {
        return self.model.outputs.items
                .filter { (item) -> Bool in
                    return item.shown == true && item.done == true
                }
                .scan(0) { (priorValue, _) -> Int in
                    return priorValue + 1
                }
    }

    func getItemsNumbers() -> Observable<(Int, Int)> {
        let doneItemsNum = getFilteredItemsNum(filterImpl: true)
        let remainItemsNum = getFilteredItemsNum(filterImpl: false)

        return Observable.combineLatest(doneItemsNum, remainItemsNum) { value1, value2 in
            return (value1, value2)
        }
    }

    func update(_ item: Item, withItem: Item, completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        _ = self.model.inputs.update(item, withItem: withItem)
        if let index = itemsArray.firstIndex(where: { item in
            item.id == withItem.id
        }) {
            itemsArray[index] = withItem
        }
        completionBlock()
        return (true, nil)
    }

    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        // The items subscription lives in bindItems(); this only remembers who to notify
        // and asks the model to emit its items again.
        itemsLoadedCompletion = completionBlock
        return self.model.inputs.getItems()
    }

    private func removeShownItems() {
        self.itemsArray = itemsArray.filter({item -> Bool in
            return item.shown == true
        })
    }

    func getItemsSize() -> Int {
        return self.itemsArray.count
    }

    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) {
//        var hints: [String] = Array()
//        self.model.inputs.getHints(for: itemName)
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: {item in
//                hints.append(item)
//            }, onCompleted: {
//                print("Completed!!")
//                if(hints.count > 1) {
//                    withCompletion(hints[0], hints[1])
//                } else if(hints.count == 1) {
//                    withCompletion(hints[0], "")
//                } else {
//                    withCompletion("", "")
//                }
//            })
//            .disposed(by: disposeBag)

        let items: [String] = self.itemsArray
            .filter {(item) in item.name.hasPrefix(itemName)}
            .map {(item) in item.name}
        if items.count > 1 {
            withCompletion(items[0], items[1])
        } else if items.count == 1 {
            withCompletion(items[0], "")
        } else {
            withCompletion("", "")
        }
    }

    func getItemsArray(withFilter: Bool = false) -> [Item] {
        if !withFilter {
            return self.itemsArray
        } else {
            return self.itemsArray.filter({ (item) -> Bool in
                return item.shown == true
            })
        }
    }

    func showOrHideAllDoneItems(shown: Bool) -> Bool {
        let tmpArray = self.itemsArray
                            .filter { (item) -> Bool in
                                return item.done != shown
                            }
        self.itemsArray.removeAll()
        self.itemsArray.append(contentsOf: tmpArray)
        return true
    }

    func clearList() -> Bool {
        for item in self.itemsArray {
            let updatedItem = Item.itemShownLens.set(false, item)
            _ = self.model.inputs.update(item, withItem: updatedItem)
        }
        self.itemsArray.removeAll()
        return true
    }

    func remove(updated item: Item) -> (Bool, Error?) {
        self.itemsArray = self.itemsArray.filter({$0.id != item.id})
        return (true, nil)
    }

    func uploadToCloud() -> (Bool, Error?) {
        return model.inputs.uploadToCloud(items: itemsArray.filter {item in !item.uploadedToICloud})
    }

    func fetchAllSharedItems(completion: @escaping ([Item], Error?) -> Void) -> (Bool, Error?) {
        return self.model.inputs.fetchAllSharedItems(completion: completion)
    }
}
// MARK: QuickToDoOutputs
extension QuickToDoViewModel: QuickToDoViewModelOutputs {
    var inputs: QuickToDoViewModelInputs { return self }

    var outputs: QuickToDoViewModelOutputs { return self }
    var doneItemsNum: Int {
        get {
            return self.itemsArray.filter({ (item) -> Bool in
                return item.done == true
            }).count
        }
    }

    var totalItemsNum: Int {
        get {
            return self.itemsArray.count
        }
    }
}
