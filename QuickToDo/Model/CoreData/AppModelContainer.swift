//
//  AppModelContainer.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 5/20/24.
//  Copyright © 2024 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import SwiftData

var sharedModelContainer: ModelContainer = {
    let appGroupContainerID = "group.QuickToDoSharingDefaults"
    guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
        fatalError("Shared file container could not be created.")
    }
    let url = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")

    do {
        return try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
    } catch {
        fatalError("Failed to create the model container: \(error)")
    }
}()
