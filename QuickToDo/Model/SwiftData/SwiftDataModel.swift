//
//  SwiftDataModel.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 7/23/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import SwiftData

@Model
class ItemSD {
    var completed: Bool
    var count: Int
    var lastUsed: Date
    var used: Bool
    var word: String
    var uploadedToICloud: Bool
    var id: String
    
    public init(completed: Bool, count: Int, lastUsed: Date, used: Bool, word: String, uploadedToICloud: Bool, id: String) {
        self.completed = completed
        self.count = count
        self.lastUsed = lastUsed
        self.used = used
        self.word = word
        self.uploadedToICloud = uploadedToICloud
        self.id = id
    }
}
