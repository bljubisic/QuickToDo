//
//  QuickToDoModelProtocol.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 25.09.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import RxSwift
import CloudKit

protocol QuickToDoInputs {
    func add(_ item: Item, addToCloud: Bool) -> (Bool, Error?)
    func addToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void)
    func update(_ item: Item, withItem: Item) -> (Bool, Error?)
    func getHints(for itemName: String) -> Observable<String>
    func getItems() -> (Bool, Error?)
    func fetchAllSharedItems(completion: @escaping ([Item], Error?) -> Void) -> (Bool, Error?)
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void)
    func getZone() -> CKRecordZone?
    func getCurrentShareStatus() -> CKShare?
    func isListCurrentlyShared() -> Bool
    func refreshShareStatus() async throws -> CKShare?
    func uploadToCloud(items: [Item]) -> (Bool, Error?)
    func save(config: QuickToDoConfig) -> (Bool, Error?)
    func getConfig() -> QuickToDoConfig?
}

protocol QuickToDoOutputs {
    var items: Observable<Item> { get }
    var cloudStatus: Observable<CloudStatus> { get }
    var config: QuickToDoConfig { get }
}

protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }

}
protocol StorageInputs {

    typealias ItemProcess = (Item, ((Item, Error?) -> Void)?) -> (Item?, Bool)
    typealias ItemProcessUpdate = (Item, Item) -> (Item?, Bool)
    typealias ItemProcessFind = (String) -> (Item?, Bool)
    typealias ItemProcessFindWithID = (UUID) -> (Item?, Bool)

    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?)
    func insert() -> ItemProcess
    func insertToSharedZone(_ item: Item, completion: @escaping (Item, Error?) -> Void)
    func getItemWith() -> ItemProcessFind
    func update() -> ItemProcessUpdate
    func getItemWithId() -> ItemProcessFindWithID
    func getHints(for itemName: String, withCompletion: @escaping (Item, Item) -> Void)
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) async throws
    func fetchAllSharedItems(completion: @escaping ([Item], Error?) -> Void) -> (Bool, Error?)
    func getZone() -> CKRecordZone?
    func getCurrentShareStatus() -> CKShare?
    func isListCurrentlyShared() -> Bool
    func refreshShareStatus() async throws -> CKShare?
    /// Writes the local items into the cloud list once per device, overwriting stale cloud copies.
    /// Returns the number of records written (0 when already done or not supported).
    func publishLocalItems(_ items: [Item]) async throws -> Int
}

protocol StorageOutputs {
    var items: Observable<Item?> { get }
}

protocol StorageProtocol {
    var inputs: StorageInputs { get }
    var outputs: StorageOutputs { get }
}
