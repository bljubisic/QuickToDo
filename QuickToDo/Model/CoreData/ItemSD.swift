//
//  ItemSD.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 9/18/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import SwiftData

@Model
class ItemSD {

    var completed: Bool?
    var count: Int?
    var lastUsed: Date?
    var used: Bool?
    var word: String?
    var uploadedToICloud: Bool?
    var uuid: String?

    public init(
        completed: Bool = false,
        count: Int = 0,
        lastUsed: Date = Date(),
        used: Bool = false,
        word: String = "",
        uploadedToICloud: Bool = false,
        uuid: String = ""
    ) {
        self.completed = completed
        self.count = count
        self.lastUsed = lastUsed
        self.used = used
        self.word = word
        self.uploadedToICloud = uploadedToICloud
        self.uuid = uuid
    }

    public init() {
        self.completed = false
        self.count = 0
        self.lastUsed = Date()
        self.used = false
        self.word = ""
        self.uploadedToICloud = false
        self.uuid = ""
    }

    /// Safely converts this SwiftData model to an Item struct, returning nil if required fields are missing or invalid.
    func toItem() -> Item? {
        guard let uuidString = uuid,
              let id = UUID(uuidString: uuidString),
              let name = word else {
            return nil
        }
        return Item(
            id: id,
            name: name,
            count: count ?? 0,
            uploadedToICloud: uploadedToICloud ?? false,
            done: completed ?? false,
            shown: used ?? false,
            createdAt: lastUsed ?? Date(),
            lastUsedAt: lastUsed ?? Date()
        )
    }

}
