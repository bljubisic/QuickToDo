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

enum RecordZones: CustomStringConvertible {

    
    case quickToDoZone
    case sharedZone
    
    var description: String {
        switch self {
        case .quickToDoZone: return "QuickToDoZone"
        case .sharedZone: return "SharedZone"
        }
        
    }
}

enum Config {
    static let containerIdentifier = "iCloud.Persukibo.QuickToDo"
}

enum ItemFields: CustomStringConvertible {
    
    case name
    case count
    case done
    case used
    case id
    
    var description: String {
        switch self {
        case .name: return "Name"
        case .count: return "Count"
        case .done: return "Done"
        case .used: return "Used"
        case .id: return "Id"
        }
    }
}

public struct QuickToDoError: Error {
    
}

public struct QuickToDoConfig: Codable {
    let showDoneItems: Bool
}

extension QuickToDoConfig {
    public init() {
        showDoneItems = true
    }
}

extension QuickToDoConfig {
    static let showDoneItemsLens = Lens<QuickToDoConfig, Bool> (
        get: { $0.showDoneItems },
        set: {(showDoneItems, oldConfig) in QuickToDoConfig(showDoneItems: showDoneItems) }
    )
}

public struct Item {
    
    public let id: UUID
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
        id = UUID()
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
        set: { (name, oldItem) in Item(id: oldItem.id,
                                       name: name,
                                       count: oldItem.count,
                                       uploadedToICloud:oldItem.uploadedToICloud,
                                       done: oldItem.done,
                                       shown: oldItem.shown,
                                       createdAt:oldItem.createdAt,
                                       lastUsedAt: oldItem.lastUsedAt) }
    )
    
    static let itemUploadedToICloudLens = Lens<Item, Bool> (
        get: { $0.uploadedToICloud },
        set: { (uploadedToICloud, oldItem) in Item(id: oldItem.id,
                                                   name: oldItem.name,
                                                   count: oldItem.count,
                                                   uploadedToICloud: uploadedToICloud,
                                                   done: oldItem.done,
                                                   shown: oldItem.shown,
                                                   createdAt: oldItem.createdAt,
                                                   lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemDoneLens = Lens<Item, Bool> (
        get: { $0.done },
        set: { (done, oldItem) in Item(id: oldItem.id,
                                       name: oldItem.name,
                                       count: oldItem.count,
                                       uploadedToICloud: oldItem.uploadedToICloud,
                                       done: done,
                                       shown: oldItem.shown,
                                       createdAt: oldItem.createdAt,
                                       lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemShownLens = Lens<Item, Bool> (
        get: { $0.shown },
        set: { (shown, oldItem) in Item(id: oldItem.id,
                                        name: oldItem.name,
                                        count: oldItem.count,
                                        uploadedToICloud: oldItem.uploadedToICloud,
                                        done: oldItem.done,
                                        shown: shown,
                                        createdAt: oldItem.createdAt,
                                        lastUsedAt: oldItem.lastUsedAt)}
    )
    static let itemCountLens = Lens<Item, Int> (
        get: { $0.count },
        set: { (count, oldItem) in Item(id: oldItem.id,
                                        name: oldItem.name,
                                        count: count,
                                        uploadedToICloud: oldItem.uploadedToICloud,
                                        done: oldItem.done,
                                        shown: oldItem.shown,
                                        createdAt: oldItem.createdAt,
                                        lastUsedAt: oldItem.lastUsedAt)}
    )
}

extension Item: Identifiable {

}
