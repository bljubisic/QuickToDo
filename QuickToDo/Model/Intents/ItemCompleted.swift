//
//  ItemCompleted.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 10/3/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import Foundation
import AppIntents
import SwiftData


@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ItemCompleted: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "ItemCompletedIntent"

    static var title: LocalizedStringResource = "Item Completed"
    static var description = IntentDescription("")

    @Parameter(title: "item id", optionsProvider: StringOptionsProvider())
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
                title: "",
                subtitle: ""
            )
        }
    }

    func perform() async throws -> some IntentResult {
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        let container: ModelContainer
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            fatalError("Shared file container could not be created.")
        }
        let url = appGroupContainer.appendingPathComponent("QuickToDo1.sqlite")

        do {
            container = try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
        print("Performing an intent :)")
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static func idParameterDisambiguationIntro(count: Int, id: String) -> Self {
        "There are \(count) options matching ‘\(id)’."
    }
    static func idParameterConfirmation(id: String) -> Self {
        "Just to confirm, you wanted ‘\(id)’?"
    }
}

