//
//  ItemCK.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 13.09.19.
//  Copyright © 2019 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import CodableCloudKit


public final class ItemCK: CodableCloud {
    
    let name: String
    let count: Int
    let uploadedToICloud: Bool
    let done: Bool
    let shown: Bool
    let createdAt: Date
    let lastUsedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case name
        case count
        case uploadedToICloud
        case done
        case shown
        case createdAt
        case lastUsedAt
    }
    
    init(name: String, count: Int, uploadedToICloud: Bool, done: Bool, shown: Bool, createdAt: Date, lastUsedAt: Date) {
        self.name = name
        self.count = count
        self.done = done
        self.shown = shown
        self.uploadedToICloud = uploadedToICloud
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        super.init()
    }
    
    required override public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.count = try container.decode(Int.self, forKey: .count)
        self.uploadedToICloud = try container.decode(Bool.self, forKey: .uploadedToICloud)
        self.done = try container.decode(Bool.self, forKey: .done)
        self.shown = try container.decode(Bool.self, forKey: .shown)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
        try super.init(from: decoder)
    }
}
