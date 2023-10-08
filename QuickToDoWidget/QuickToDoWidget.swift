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


struct Provider: AppIntentTimelineProvider {
    
    typealias Entry = SimpleEntry
    
    typealias Intent = QuickToDoIntent
    
    @MainActor func snapshot(for configuration: QuickToDoIntent, in context: Context) async -> SimpleEntry {
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        
        if let items = try? container.mainContext.fetch(descriptor) {
            let endIndex = (items.count > 3) ? 2 : items.count
            let subItems = items[0 ..< endIndex]
            
            let entry = SimpleEntry(date: Date(), items: subItems)
            return entry
        }
        return SimpleEntry(date: Date(), items: [ItemSD()])
    }
    
    @MainActor func timeline(for configuration: QuickToDoIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        if let items = try? container.mainContext.fetch(descriptor) {
            let endIndex = (items.count > 3) ? 2 : items.count
            let subItems = items[0 ..< endIndex]
            
            let entry = SimpleEntry(date: Date(), items: subItems)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            return timeline
        }
        return Timeline(entries: [], policy: .atEnd)
    }
    
    @Query(sort: \ItemSD.lastUsed, animation: .smooth) private var items: [ItemSD]
    private let container: ModelContainer
    
    @MainActor init() {
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
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), items: [])
    }
}

struct SimpleEntry: TimelineEntry {
    var date: Date
    let items: ArraySlice<ItemSD>
}

struct QuickToDoWidgetEntryView : View {
    @Environment(\.modelContext) private var context
    var entry: Provider.Entry
    
    var body: some View {
        ForEach(entry.items.enumerated().map({$0}), id: \.element.id) { index, item in
            let red: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (8 - (index - 8)) ) : ((index < 24) ? Double(32 * (index - 16)) : 255)) : 255
            let green: Double = (index < 8) ? Double(32 * (8 - index)) : ((index > 8) ? 0 : ((index > 24) ? Double(32 * (index - 16)) : 0 ))
            let blue: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (index - 8)) : ((index < 24) ? Double (32 * (8 - (index - 16))) : 0)) : 0
            HStack() {
                Button(intent: QuickToDoIntent(id: item.uuid), label: {
                    ZStack {
                        Circle()
                            .stroke(.black, lineWidth: 2)
                            .frame(width: 35.0, height: 35.0)
                        Circle()
                            .stroke(Color(red: red/255, green: green/255, blue: blue/255))
                            .frame(width: 25.0, height: 25.0)
                    }
                }).buttonStyle(.borderless)
                Text(item.word!)
                    .scaledToFit()
                Spacer()
            }.padding(1)
        }
        .modelContext(context)
//        .containerBackground(for: .widget) {
//            Color.white
//        }
    }
}

struct QuickToDoWidget: Widget {
    let kind: String = "QuickToDoWidget"

    @MainActor var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickToDoIntent.self, provider: Provider()) { entry in
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
    let items = [ItemSD(), ItemSD(), ItemSD(), ItemSD()]
    let endIndex = (items.count > 3) ? 2 : items.count
    let subItems = items[0 ..< endIndex]
    SimpleEntry(date: .now, items: subItems)
    SimpleEntry(date: .now, items: subItems)
}
