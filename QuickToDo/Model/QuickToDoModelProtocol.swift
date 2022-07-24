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
    func update(_ item: Item, withItem: Item) -> (Bool, Error?)
    func getHints(for itemName: String) -> Observable<String>
    func getItems() -> (Bool, Error?)
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void
    func getRootRecord() -> CKRecord?
    func getZone() -> CKRecordZone?
}

protocol QuickToDoOutputs {
    var items: Observable<Item> { get }
    var cloudStatus: Observable<CloudStatus> { get }
}

public protocol QuickToDoProtocol {
    var inputs: QuickToDoInputs { get }
    var outputs: QuickToDoOutputs { get }
    
}
protocol StorageInputs {
    
    typealias itemProcess = (Item, ((Item, Error?) -> Void)?) -> (Item?, Bool)
    typealias itemProcessUpdate = (Item, Item) -> (Item?, Bool)
    typealias itemProcessFind = (String) -> (Item?, Bool)
    
    func getItems(withCompletion: ((Item) -> Void)?) -> (Bool, Error?)
    func insert() -> itemProcess
    func getItemWith() -> itemProcessFind
    func update() -> itemProcessUpdate
    func getHints(for itemName: String, withCompletion: (Item, Item) -> Void) -> Void
    func prepareShare(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) -> Void
    func getRootRecord() -> CKRecord?
    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?)
    func getZone() -> CKRecordZone?
}

protocol StorageOutputs {
    var items: Observable<Item?> { get }
}

protocol StorageProtocol {
    var inputs: StorageInputs { get }
    var outputs: StorageOutputs { get }
}
