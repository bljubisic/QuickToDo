//
//  ItemCompletedIntent.swift
//  QuickToDo
//
//  Created by Claude Code
//

import Foundation
import AppIntents
import SwiftData
import WidgetKit
@testable import QuickToDo

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ItemCompleted: AppIntent, PredictableIntent {
    
    static let intentClassName = "ItemCompletedIntent"
    
    static var title: LocalizedStringResource = "Complete To-Do Item"
    static var description = IntentDescription("Mark an item as completed")
    
    @Parameter(title: "Item ID", optionsProvider: StringOptionsProvider())
    var id: String?
    
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
    
    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$id)) { id in
            DisplayRepresentation(
                title: "Complete \(id ?? "item")",
                subtitle: "Mark as done"
            )
        }
    }
    
    init() {
        self.id = nil
    }
    
    init(id: String?) {
        self.id = id
    }
    
    func perform() async throws -> some IntentResult {
        _ = await performDbUpdate()
        return .result()
    }
    
    @MainActor private func performDbUpdate() async -> Bool {
        guard let idUnwrapped = id else {
            return false
        }
        
        // Get app group container
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            print("Failed to access app group container")
            return false
        }
        
        let storeURL = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")
        
        do {
            let schema = Schema([ItemSD.self])
            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: schema, configurations: configuration)
            let modelContext = ModelContext(container)
            
            let predicate = #Predicate<ItemSD> { item in 
                item.uuid == idUnwrapped
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            
            if let item = try modelContext.fetch(descriptor).first {
                item.completed = true
                item.lastUsed = Date.now
                try modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                return true
            }
        } catch {
            print("Error updating item: \(error)")
            return false
        }
        
        return false
    }
}
