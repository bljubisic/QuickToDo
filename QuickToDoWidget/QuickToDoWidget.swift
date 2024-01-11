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
        var entries: [ItemUD] = []
        let userDefaultsOpt = UserDefaults(suiteName: "ENT89NLKC9.group.QuickToDoSharingDefaults")
        if let userDefaults = userDefaultsOpt {
            let items: Dictionary<String, Data> = (userDefaults.object(forKey: "com.persukibo.items") as? Dictionary<String, Data>)!
            items.forEach({(key: String, value: Any) in
                do {
                    let itemWrapped = try NSKeyedUnarchiver.unarchivedObject(ofClass: ItemUD.self, from: value as! Data)
                    if let item = itemWrapped {
                        if(!item.done) {
                            entries.append(item)
                        }
                    }
                } catch {
                    print(error)
                }
            })
        }
        let endIndex = (entries.count > 3) ? 2 : entries.count
        let subItems = entries[0 ..< endIndex]
            
        let entry = SimpleEntry(date: Date(), items: subItems)
        return entry
    }
    
    @MainActor func timeline(for configuration: QuickToDoIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [ItemUD] = []
        let userDefaultsOpt = UserDefaults(suiteName: "group.QuickToDoSharingDefaults")
        if let userDefaults = userDefaultsOpt {
            let itemsWrapped: Dictionary<String, Data>? = (userDefaults.object(forKey: "com.persukibo.items") as? Dictionary<String, Data>)
            if let items = itemsWrapped {
                items.forEach({(key: String, value: Any) in
                    do {
                        let itemWrapped = try NSKeyedUnarchiver.unarchivedObject(ofClass: ItemUD.self, from: value as! Data)
                        if let item = itemWrapped {
                            if(!item.done) {
                                entries.append(item)
                            }
                        }
                    } catch {
                        print(error)
                    }
                })
            }

        }
        let endIndex = (entries.count > 3) ? 2 : entries.count
        let subItems = entries[0 ..< endIndex]
            
        let entry = SimpleEntry(date: Date(), items: subItems)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        return timeline
    }
    
    @Query(sort: \ItemSD.lastUsed, animation: .smooth) private var items: [ItemSD]
    let container: ModelContainer
    
    @MainActor init(container: ModelContainer) {
        self.container = container
        let descriptor = FetchDescriptor(sortBy: [SortDescriptor(\ItemSD.lastUsed, order: .forward)])
        if let items = try? container.mainContext.fetch(descriptor) {
            let itemsExcluded = items.filter{(item) in item.completed != true}
            var itemsDict = Dictionary<String, Data>()
            itemsExcluded.forEach{(item) in
                do {
                    let tmpItem = ItemUD(id: item.uuid!, word: item.word!, done: item.completed!)
                    let encodedData = try NSKeyedArchiver.archivedData(withRootObject: tmpItem, requiringSecureCoding: false)
                    itemsDict[item.uuid!] = encodedData
//                    UserDefaults.standard.set(encodedData, forKey: item.uuid!)
                } catch {
                    fatalError("Failed to create the model container: \(error)")
                }
            }
            let userDefaultsOpt = UserDefaults(suiteName: "group.QuickToDoSharingDefaults")
            if let userDefaults = userDefaultsOpt {
                userDefaults.set(itemsDict, forKey: "com.persukibo.items")
            }
            
        }
    }
    
    @MainActor func placeholder(in context: Context) -> SimpleEntry {
        var entries: [ItemUD] = []
        let userDefaultsOpt = UserDefaults(suiteName: "group.QuickToDoSharingDefaults")
        if let userDefaults = userDefaultsOpt {
            let items: Dictionary<String, Data> = (userDefaults.object(forKey: "com.persukibo.items") as? Dictionary<String, Data>)!
            items.forEach({(key: String, value: Any) in
                do {
                    let itemWrapped = try NSKeyedUnarchiver.unarchivedObject(ofClass: ItemUD.self, from: value as! Data)
                    if let item = itemWrapped {
                        if(!item.done) {
                            entries.append(item)
                        }
                    }
                } catch {
                    print(error)
                }
            })
        }
        let endIndex = (entries.count > 3) ? 2 : entries.count
        let subItems = entries[0 ..< endIndex]
            
        let entry = SimpleEntry(date: Date(), items: subItems)
        return entry
    }
}



struct SimpleEntry: TimelineEntry {
    var date: Date
    let items: ArraySlice<ItemUD>
}

struct QuickToDoWidgetEntryView : View {
    @Environment(\.modelContext) private var context
    var entry: Provider.Entry
    var container: ModelContainer
    
    var body: some View {
        ForEach(entry.items.enumerated().map({$0}), id: \.element.id) { index, item in
            let red: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (8 - (index - 8)) ) : ((index < 24) ? Double(32 * (index - 16)) : 255)) : 255
            let green: Double = (index < 8) ? Double(32 * (8 - index)) : ((index > 8) ? 0 : ((index > 24) ? Double(32 * (index - 16)) : 0 ))
            let blue: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (index - 8)) : ((index < 24) ? Double (32 * (8 - (index - 16))) : 0)) : 0
            HStack() {
                Button(intent: QuickToDoIntent(id: item.id, container: container), label: {
                    ZStack {
                        Circle()
                            .stroke(.black, lineWidth: 2)
                            .frame(width: 35.0, height: 35.0)
                        Circle()
                            .stroke(Color(red: red/255, green: green/255, blue: blue/255))
                            .frame(width: 25.0, height: 25.0)
                    }
                }).buttonStyle(.borderless)
                Text(item.word)
                    .scaledToFit()
                Spacer()
            }.padding(1)
        }
        .modelContext(context)
        .modelContainer(for: ItemSD.self)
        .containerBackground(for: .widget) {
            Color.white
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
        AppIntentConfiguration(kind: kind, intent: QuickToDoIntent.self, provider: Provider(container: self.container)) { entry in
            if #available(iOS 17.0, *) {
                QuickToDoWidgetEntryView(entry: entry, container: self.container)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuickToDoWidgetEntryView(entry: entry, container: self.container)
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
    let items = [ItemUD(), ItemUD(), ItemUD(), ItemUD()]
    let endIndex = (items.count > 3) ? 2 : items.count
    let subItems = items[0 ..< endIndex]
    SimpleEntry(date: .now, items: subItems)
    SimpleEntry(date: .now, items: subItems)
}
