//
//  DataStructures.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 25.09.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation

enum CloudStatus {
    case allUpdated
    case updating
    case connected
    case disconnected
}

public struct QuickToDoError: Error {
    
}

public struct Item {
    
    let name: String
    let count: Int
    let uploadedToICloud: Bool
    let done: Bool
    let shown: Bool
    let createdAt: Date
    let lastUsedAt: Date
    
}

extension Item {
    public init() {
        name = ""
        count = 0
        uploadedToICloud = false
        done = false
        shown = false
        createdAt = Date()
        lastUsedAt = Date()
    }
}

struct Lens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
}

extension Item {
    
    static let itemNameLens = Lens<Item, String> (
        get: { $0.name },
        set: { (name, oldItem) in Item(name: name,
                                       count: oldItem.count,
                                       uploadedToICloud:oldItem.uploadedToICloud,
                                       done: oldItem.done,
                                       shown: oldItem.shown,
                                       createdAt:oldItem.createdAt,
                                       lastUsedAt: oldItem.lastUsedAt) }
    )
    
    static let itemUploadedToICloudLens = Lens<Item, Bool> (
        get: { $0.uploadedToICloud },
        set: { (uploadedToICloud, oldItem) in Item(name: oldItem.name,
                                                   count: oldItem.count,
                                                   uploadedToICloud: uploadedToICloud,
                                                   done: oldItem.done,
                                                   shown: oldItem.shown,
                                                   createdAt: oldItem.createdAt,
                                                   lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemDoneLens = Lens<Item, Bool> (
        get: { $0.done },
        set: { (done, oldItem) in Item(name: oldItem.name,
                                       count: oldItem.count,
                                       uploadedToICloud: oldItem.uploadedToICloud,
                                       done: done,
                                       shown: oldItem.shown,
                                       createdAt: oldItem.createdAt,
                                       lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemShownLens = Lens<Item, Bool> (
        get: { $0.shown },
        set: { (shown, oldItem) in Item(name: oldItem.name,
                                        count: oldItem.count,
                                        uploadedToICloud: oldItem.uploadedToICloud,
                                        done: oldItem.done,
                                        shown: shown,
                                        createdAt: oldItem.createdAt,
                                        lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemCountLens = Lens<Item, Int> (
        get: { $0.count },
        set: { (count, oldItem) in Item(name: oldItem.name,
                                        count: count,
                                        uploadedToICloud: oldItem.uploadedToICloud,
                                        done: oldItem.done,
                                        shown: oldItem.shown,
                                        createdAt: oldItem.createdAt,
                                        lastUsedAt: oldItem.lastUsedAt)}
    )
}

extension Item: Identifiable {
    public var id: String {
        return name
    }
    
    
}
