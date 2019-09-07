//
//  DataStructures.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 25.09.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CodableCloudKit

enum CloudStatus {
    case allUpdated
    case updating
    case connected
    case disconnected
}

public struct Item: Codable {
    
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

extension Item {
    enum CodingKeys: String, CodingKey {
        case name
        case count
        case uploadedToICloud
        case done
        case shown
        case createdAt
        case lastUsedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.count = try container.decode(Int.self, forKey: .count)
        self.uploadedToICloud = try container.decode(Bool.self, forKey: .uploadedToICloud)
        self.done = try container.decode(Bool.self, forKey: .done)
        self.shown = try container.decode(Bool.self, forKey: .shown)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
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
