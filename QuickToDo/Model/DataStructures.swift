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

extension Notification.Name {
    static let cloudKitPrivateDataChanged = Notification.Name("CloudKitPrivateDataChanged")
    static let cloudKitSharedDataChanged = Notification.Name("CloudKitSharedDataChanged")
    static let cloudKitRecordZoneChanged = Notification.Name("CloudKitRecordZoneChanged")
    static let refreshSharedItems = Notification.Name("RefreshSharedItems")
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
    static let showDoneItemsLens = Lens<QuickToDoConfig, Bool>(
        get: { $0.showDoneItems },
        set: {(showDoneItems, _) in QuickToDoConfig(showDoneItems: showDoneItems) }
    )
}

public class ItemUD: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool = true

    let id: String
    let word: String
    var done: Bool

    public init(id: String, word: String, done: Bool) {
        self.id = id
        self.word = word
        self.done = done
    }

    public override init() {
        self.done = false
        self.word = ""
        self.id = ""
    }
    required public init(coder decoder: NSCoder) {
        self.id = decoder.decodeObject(forKey: "id") as? String ?? ""
        self.word = decoder.decodeObject(forKey: "word") as? String ?? ""
        self.done = decoder.decodeBool(forKey: "done")
    }
    public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(word, forKey: "word")
        coder.encode(done, forKey: "done")
    }
}

/// Which CloudKit database an item lives in
enum ItemScope: String {
    /// The user's own list (private database, `QuickToDoZone`)
    case `private`
    /// A list another user shared with us (shared database, owner's zone)
    case shared
}

/// Identifies the CloudKit record backing an item. Kept as plain strings so the
/// Widget, which compiles this file, does not need CloudKit.
struct CloudRecordRef: Equatable {
    let recordName: String
    let zoneName: String
    let zoneOwnerName: String
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
    var scope: ItemScope = .private
    var cloudRecord: CloudRecordRef?

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

    /// Copies the item, replacing only the given fields. Scope and CloudKit record are always preserved.
    private func copy(name: String? = nil,
                      count: Int? = nil,
                      uploadedToICloud: Bool? = nil,
                      done: Bool? = nil,
                      shown: Bool? = nil) -> Item {
        return Item(id: id,
                    name: name ?? self.name,
                    count: count ?? self.count,
                    uploadedToICloud: uploadedToICloud ?? self.uploadedToICloud,
                    done: done ?? self.done,
                    shown: shown ?? self.shown,
                    createdAt: createdAt,
                    lastUsedAt: lastUsedAt,
                    scope: scope,
                    cloudRecord: cloudRecord)
    }

    static let itemNameLens = Lens<Item, String>(
        get: { $0.name },
        set: { (name, oldItem) in oldItem.copy(name: name) }
    )

    static let itemUploadedToICloudLens = Lens<Item, Bool>(
        get: { $0.uploadedToICloud },
        set: { (uploadedToICloud, oldItem) in oldItem.copy(uploadedToICloud: uploadedToICloud) }
    )
    static let itemDoneLens = Lens<Item, Bool>(
        get: { $0.done },
        set: { (done, oldItem) in oldItem.copy(done: done) }
    )
    static let itemShownLens = Lens<Item, Bool>(
        get: { $0.shown },
        set: { (shown, oldItem) in oldItem.copy(shown: shown) }
    )
    static let itemCountLens = Lens<Item, Int>(
        get: { $0.count },
        set: { (count, oldItem) in oldItem.copy(count: count) }
    )
}

extension Item: Identifiable {

}
