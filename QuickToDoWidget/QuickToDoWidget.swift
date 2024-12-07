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
        let entry = SimpleEntry(date: Date(), items: [])
        return entry
    }
    
    @MainActor func timeline(for configuration: QuickToDoIntent, in context: Context) async -> Timeline<SimpleEntry> {
        
        let predicate = #Predicate<ItemSD> {item in item.completed == false}
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        if let items = try? sharedModelContainer.mainContext.fetch(descriptor) {
            let endIndex = (items.count > 3) ? 2 : items.count
            let subItems = items[0 ..< endIndex]
            
            let entry = SimpleEntry(date: Date.now, items: subItems)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            return timeline
        }
        return Timeline(entries: [], policy: .atEnd)
    }
    
    
    @Query(sort: \ItemSD.lastUsed, animation: .smooth) private var items: [ItemSD]
    
    @MainActor init() {
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        if let items = try? sharedModelContainer.mainContext.fetch(descriptor) {
            let endIndex = (items.count > 3) ? 2 : items.count
            let subItems = items[0 ..< endIndex]
            
            let entry = SimpleEntry(date: Date(), items: subItems)
        }
    }
    
    @MainActor func placeholder(in context: Context) -> SimpleEntry {
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        
        if let items = try? sharedModelContainer.mainContext.fetch(descriptor) {
            let endIndex = (items.count > 3) ? 2 : items.count
            let subItems = items[0 ..< endIndex]
            
            let entry = SimpleEntry(date: Date(), items: subItems)
            return entry
        }
        return SimpleEntry(date: Date(), items: [ItemSD()])
    }
}



struct SimpleEntry: TimelineEntry {
    var date: Date
    let items: ArraySlice<ItemSD>
}

struct QuickToDoWidgetEntryView : View {
    var entry: Provider.Entry
    
    private func getColorRed(index: Int)-> Double {
        let indexUsed = (index > 24) ? (index % (24 * (index / 24))) : index
        if indexUsed > 8 {
            if indexUsed < 16 {
                return Double(32 * (8 - (indexUsed - 8)))
            } else if  indexUsed < 24 {
                return Double(32 * (indexUsed - 16))
            } else {
                return 255
            }
        } else {
            return 255
        }
    }
    
    private func getColorGreen(index: Int) -> Double {
        let indexUsed = (index > 24) ? (index % (24 * (index / 24))) : index
        if indexUsed < 8 {
            return Double(32 * (8 - indexUsed))
        } else {
            if indexUsed > 8 {
                return 0
            } else if indexUsed > 24 {
                return Double (32 * (indexUsed  - 16))
            } else {
                return 0
            }
        }
    }
    
    private func getColorBlue(index: Int) -> Double {
        let indexUsed = (index > 24) ? (index % (24 * (index / 24))) : index
        if  indexUsed > 8 {
            if indexUsed < 16 {
                return Double(32 * (indexUsed - 8))
            } else {
                if indexUsed < 24 {
                    return Double (32 * (8 - (indexUsed - 16)))
                } else {
                    return 0
                }
            }
        } else {
            return 0
        }
    }
    
    var body: some View {
        if(entry.items.count > 0) {
            ForEach(0 ..< entry.items.count) { index in
                let red: Double = getColorRed(index: index)
                let green: Double = getColorGreen(index: index)
                let blue: Double = getColorBlue(index: index)
                HStack() {
                    Button(intent: QuickToDoIntent(id: entry.items[index].uuid), label: {
                        ZStack {
                            Circle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: 35.0, height: 35.0)
                            Circle()
                                .stroke(Color(red: red/255, green: green/255, blue: blue/255))
                                .frame(width: 25.0, height: 25.0)
                        }
                    }).buttonStyle(.borderless)
                    Text(entry.items[index].word!)
                        .scaledToFit()
                    Spacer()
                }.padding(1)
            }
            .containerBackground(for: .widget) {
                Color.white
            }
            .modelContainer(sharedModelContainer)
        }
        else {
            Text("No more Items")
                .containerBackground(for: .widget) {
                    Color.white
                }
                .modelContainer(sharedModelContainer)
        }
    }
}

struct QuickToDoWidget: Widget {
    let kind: String = "QuickToDoWidget"
    
    private let container: ModelContainer
    
    var families: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, watchOS 9.0, *) {
            return [.accessoryCircular, .accessoryInline, .systemSmall]
        } else {
            return [.systemSmall]
        }
    }
    
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
