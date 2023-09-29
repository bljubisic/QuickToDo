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
import RxSwift
import Combine

public final class DebounceObject: ObservableObject {
    @Published var text: String = ""
    @Published var debouncedText: String = ""
    private var bag = Set<AnyCancellable>()

    public init(dueTime: TimeInterval = 0.5) {
        $text
            .removeDuplicates()
            .debounce(for: .seconds(dueTime), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.debouncedText = value
            })
            .store(in: &bag)
    }
}

struct Provider: TimelineProvider {
    @Query(sort: \ItemSD.lastUsed, animation: .smooth) private var items: [ItemSD]
    private let viewModel: QuickToDoViewModel
    
    @MainActor init() {
        let swiftData = SwiftDataModel()
        let cloudKit = CloudKitModel()
        let model = QuickToDoModel(swiftData, cloudKit)
        viewModel = QuickToDoViewModel(model)
        _ = viewModel.inputs.getItems {
//            print("called getItems")
        }
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), items: [], viewModel: self.viewModel)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let endIndex = (self.viewModel.outputs.itemsArray.count > 3) ? 2 : self.viewModel.outputs.itemsArray.count
        let subItems = self.viewModel.outputs.itemsArray[0 ..< endIndex]
        
        let entry = SimpleEntry(date: Date(), items: subItems, viewModel: self.viewModel)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
        Task { @MainActor in
            let now = Date.now
            let endIndex = (self.viewModel.outputs.itemsArray.count > 3) ? 2 : self.viewModel.outputs.itemsArray.count
            let subItems = self.viewModel.outputs.itemsArray[0 ..< endIndex]
            
            let entry = SimpleEntry(date: now, items: subItems, viewModel: self.viewModel)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
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
    let items: ArraySlice<Item>
    let viewModel: QuickToDoViewModel
}

struct QuickToDoWidgetEntryView : View {
    @Environment(\.modelContext) private var context
    var entry: Provider.Entry
    @StateObject var debounceObject = DebounceObject()
    @State private var selectedItem: Item?
    

    var body: some View {
        ForEach(entry.items.enumerated().map({$0}), id: \.element.id) { index, item in
            let red: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (8 - (index - 8)) ) : ((index < 24) ? Double(32 * (index - 16)) : 255)) : 255
            let green: Double = (index < 8) ? Double(32 * (8 - index)) : ((index > 8) ? 0 : ((index > 24) ? Double(32 * (index - 16)) : 0 ))
            let blue: Double = (index > 8 ) ? ((index < 16) ? Double(32 * (index - 8)) : ((index < 24) ? Double (32 * (8 - (index - 16))) : 0)) : 0
            HStack() {
                Button(action: {
                    let newItem = Item.itemDoneLens.set(!item.done, item)
                    _ = entry.viewModel.update(item, withItem: newItem, completionBlock: {
                        print("Done")
                    })
                }, label: {
                    if item.done {
                        ZStack {
                            Circle()
                                .stroke(Color(red: red/255, green: green/255, blue: blue/255), lineWidth: 2)
                                .frame(width: 35.0, height: 35.0)
                            Circle()
                                .fill()
                                .foregroundColor(Color(red: red/255, green: green/255, blue: blue/255))
                                .frame(width: 25.0, height: 25.0)
                        }
                    }
                    else {
                        ZStack {
                            Circle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: 35.0, height: 35.0)
                            Circle()
                                .stroke(Color(red: red/255, green: green/255, blue: blue/255))
                                .frame(width: 25.0, height: 25.0)
                        }
                    }
                }).buttonStyle(.borderless)
                Text(item.name)
                    .scaledToFit()
                Spacer()
                ((item.uploadedToICloud) ? Image("Cloud") : Image("NoCloud"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 30, maxHeight: 30, alignment: .trailing)
            }
            .onTapGesture {
                selectedItem = item
                debounceObject.text = selectedItem!.name
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: {
                    let newItem = Item.itemShownLens.set(!item.shown, item)
                    _ = entry.viewModel.update(item, withItem: newItem, completionBlock: {
                        print("Done")
                    })
                }) {Label("Delete", systemImage: "trash")}
            }
        }.modelContext(context)
    }
}

struct QuickToDoWidget: Widget {
    let kind: String = "QuickToDoWidget"

    @MainActor var body: some WidgetConfiguration {
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

//#Preview(as: .systemSmall) {
//    QuickToDoWidget()
//} timeline: {
//    SimpleEntry(date: .now, numOfItems: 0)
//    SimpleEntry(date: .now, numOfItems: 1)
//}
