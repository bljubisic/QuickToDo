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
        
    }
    
    
    static let intentClassName = "QuickToDoIntent"
    
    static var title: LocalizedStringResource = "QuickToDo Intent"
    static var description = IntentDescription("Complete item in the list")
    
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
    
    init(id: String? = nil) {
        self.id = id
    }
    
    func perform() async throws -> some IntentResult {

        print("Performing an intent :)")
        let _ = await self.performDbUpdate()
//        let _ = self.performCloudKitUpdate()
        return .result()
    }
    
    @MainActor private func performDbUpdate() -> Bool {
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        let container: ModelContainer
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            fatalError("Shared file container could not be created.")
        }
        let url = appGroupContainer.appendingPathComponent("QuickToDo.sqlite")

        do {
            container = try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
        guard  let idUnwraped = id else {
            return false
        }
        let predicate = #Predicate<ItemSD> { itemFound in itemFound.uuid! == idUnwraped }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let oldItems = try? container.mainContext.fetch<ItemSD>(descriptor) {
            if let oldItem = oldItems.first {
                oldItem.completed = true
                do {
                    try container.mainContext.save()
                    return true
                } catch {
                    print(error)
                    return false
                }
            }
        }
        return false
    }
    
    private func performCloudKitUpdate() -> Bool {
        let container = CKContainer.default()
        let zone = CKRecordZone(zoneName: String(describing: RecordZones.quickToDoZone))
        let database = container.privateCloudDatabase
        
        let predicate = NSPredicate(format: "(Id == %@)", self.id!)
        let query = CKQuery(recordType: "Items", predicate: predicate)
        
        database.perform(query, inZoneWith: zone.zoneID) { (recordsRecived, error) in
            var modifiedRecords = [CKRecord]()
            guard let records = recordsRecived else {
                return
            }
            
            for record in records {
                record.setValue(1, forKey: String(describing: ItemFields.done))
//                record.set(int: 1, key: String(describing: ItemFields.done))
                modifiedRecords.append(record)
            }
            let updateOperation = CKModifyRecordsOperation(recordsToSave: modifiedRecords, recordIDsToDelete: nil)
            updateOperation.perRecordCompletionBlock = {record, errorReceived in
                if let error = errorReceived {
                    print("Unable to modify record: \(record). Error: \(error.localizedDescription)")
                }
            }
            database.add(updateOperation)
        }
        return true
    }
    
}
