//
//  QuickToDoIntent.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 9/29/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import AppIntents
import SwiftData
import CloudKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct QuickToDoIntent: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    init() {
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            fatalError("Shared file container could not be created.")
        }
        let url = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")

        do {
            container = try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
    }
    
    
    static let intentClassName = "QuickToDoIntent"
    
    static var title: LocalizedStringResource = "QuickToDo Intent"
    static var description = IntentDescription("Complete item in the list")
    
    @Parameter(title: "item id", optionsProvider: StringOptionsProvider())
    var id: String?
    
    var container: ModelContainer?

    struct StringOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [String] {
            // TODO: Return possible options here.
            return []
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$id
        }
    }
    
    init(id: String? = nil, container: ModelContainer?) {
        self.container = container
        self.id = id
    }
    
    func perform() async throws -> some IntentResult {

        print("Performing an intent :)")
        let _ = await self.performDbUpdate()
//        let _ = self.performCloudKitUpdate()
        return .result()
    }
    
    @MainActor private func performDbUpdate() -> Bool {
        guard  let idUnwraped = id else {
            return false
        }
        let userDefaultsOpt = UserDefaults(suiteName: "group.QuickToDoSharingDefaults")
        if let userDefaults = userDefaultsOpt {
            var itemsOpt: Dictionary<String, Data>? = (userDefaults.object(forKey: "com.persukibo.items") as? Dictionary<String, Data>)
            if var items = itemsOpt {
                if let data = items[idUnwraped]{
                    let item = NSKeyedUnarchiver.unarchiveObject(with: data as! Data) as! ItemUD
                    item.done = true
                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: item)
                    items[idUnwraped] = encodedData
                    userDefaults.set(items, forKey: "com.persukibo.items")
                    userDefaults.synchronize()
                }else{
                    print("There is an issue")
                }
            }
        }
        return true
    }
    
}
