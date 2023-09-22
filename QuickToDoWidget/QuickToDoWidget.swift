//
//  QuickToDoWidget.swift
//  QuickToDoWidget
//
//  Created by Bratislav Ljubisic Home  on 7/30/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    @Query(sort: \ItemSD.lastUsed, animation: .smooth) private var items: [ItemSD]
    private let container: ModelContainer
    
    init() {
        let appGroupContainerID = "group.QuickToDoSharingDefaults"
        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupContainerID) else {
            fatalError("Shared file container could not be created.")
        }
        let url = appGroupContainer.appendingPathComponent("QuickToDo1.sqlite")

        do {
            container = try ModelContainer(for: ItemSD.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
        
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), numOfItems: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), numOfItems: items.count)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
        Task { @MainActor in
            var descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
            let now = Date.now
            
            if let items = try? container.mainContext.fetch(descriptor) {
                let entry = SimpleEntry(date: now, numOfItems: items.count)
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
                return
            }
            /**
             Return "No Trips" entry with .never policy when there is no upcoming trip.
             The main app triggers a widget update when adding a new trip.
             */
            let newEntry = SimpleEntry(date: .now, numOfItems: 0)
            let timeline = Timeline(entries: [newEntry], policy: .never)
            completion(timeline)
        }
//        var entries: [SimpleEntry] = []
//        
//        var descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
//        var items: [ItemSD]? = nil
//        do {
//            items = try container!.mainContext.fetch(descriptor)
//        }
//        catch {
//            print(error.localizedDescription)
//        }
//        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
//        let currentDate = Date()
//        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: currentDate))
//
//        let entryDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: currentDate)!
//        let entry = SimpleEntry(date: entryDate, numOfItems: ((items != nil) ? items!.count : 0))
//        entries.append(entry)
//
//        let timeline = Timeline(entries: entries, policy: .atEnd)
//        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    var date: Date
    let numOfItems: Int
}

struct QuickToDoWidgetEntryView : View {
    @Environment(\.modelContext) private var context
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("QuickToDo")
            Text("\(entry.numOfItems)")
            
        }.modelContext(context)
    }
}

struct QuickToDoWidget: Widget {
    let kind: String = "QuickToDoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                QuickToDoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuickToDoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemSmall) {
    QuickToDoWidget()
} timeline: {
    SimpleEntry(date: .now, numOfItems: 0)
    SimpleEntry(date: .now, numOfItems: 1)
}
