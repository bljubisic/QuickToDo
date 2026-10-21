//
//  ItemsView.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 4/21/25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//

import SwiftUI
import CloudKit
import WidgetKit
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

enum ItemsViewMode {
    case regular
    case shared
}

// swiftlint:disable type_body_length
struct ItemsView: View {

    @Environment(\.scenePhase) var scenePhase

    @ObservedObject var viewModel: QuickToDoViewModel
    @Binding var shown: Bool
    /// The zone share of the user's own list, if it is shared (owned by MainView)
    let activeShare: CKShare?
    /// Opens the share sheet for the user's own list (MainView owns the sheet)
    let onShare: () -> Void

    let mode: ItemsViewMode

    @StateObject var debounceObject = DebounceObject()
    @State private var sharedItems: [Item] = []
    @State private var isLoadingSharedItems = false

    @State private var selectedItem: Item?
    @State var hint1 = ""
    @State var hint2 = ""
    @State private var addItemError: String?
    @State private var showingAddItemError = false

    // Notification observers
    @State private var refreshSharedItemsObserver: NSObjectProtocol?
    @State private var privateDataChangedObserver: NSObjectProtocol?

    private func getColorRed(index: Int) -> Double {
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
            return 0
        }
    }

    private func getColorBlue(index: Int) -> Double {
        let indexUsed = (index > 24) ? (index % (24 * (index / 24))) : index
        if  indexUsed > 8 {
            if indexUsed < 16 {
                return Double(32 * (indexUsed - 8))
            } else {
                if indexUsed < 24 {
                    return Double(32 * (8 - (indexUsed - 16)))
                } else {
                    return 0
                }
            }
        } else {
            return 0
        }
    }

    func addItem(_ sender: String) {
        let newItem = Item(
            id: UUID(),
            name: sender,
            count: 1,
            uploadedToICloud: mode == .shared,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )
        if mode == .shared {
            viewModel.inputs.addToSharedZone(newItem) { savedItem, error in
                if let error = error {
                    print("Error adding to shared zone: \(error.localizedDescription)")
                    addItemError = error.localizedDescription
                    showingAddItemError = true
                    return
                }
                if !self.sharedItems.contains(where: { $0.id == savedItem.id }) {
                    self.sharedItems.append(savedItem)
                }
            }
        } else {
            _ = self.viewModel.inputs.add(newItem)
        }
    }

    private func loadSharedItems() {
        guard mode == .shared else { return }

        isLoadingSharedItems = true
        _ = viewModel.inputs.fetchAllSharedItems { items, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load shared items: \(error)")
                } else {
                    self.sharedItems = items
                }
                self.isLoadingSharedItems = false
            }
        }
    }

    /// Saves an edit; in the Shared tab also reflects it in the locally held shared items
    private func update(_ item: Item, to newItem: Item, completionBlock: @escaping () -> Void) {
        _ = viewModel.update(item, withItem: newItem, completionBlock: completionBlock)
        guard mode == .shared, let index = sharedItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        if newItem.shown {
            sharedItems[index] = newItem
        } else {
            sharedItems.remove(at: index)
        }
    }

    private func currentItems() -> [Item] {
        switch mode {
        case .regular:
            return viewModel.outputs.itemsArray
        case .shared:
            return sharedItems
        }
    }

    private func navigationTitle() -> String {
        switch mode {
        case .regular:
            return "Quick ToDo List!!!"
        case .shared:
            return "Shared Items"
        }
    }

    private func addItemPlaceholder() -> String {
        switch mode {
        case .regular:
            return "Add new item"
        case .shared:
            return "Add new shared item"
        }
    }


    var body: some View {
        VStack {
            if mode == .shared && isLoadingSharedItems {
                VStack {
                    ProgressView("Loading shared items...")
                        .padding()
                    Text("Fetching items from shared lists")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == .shared && sharedItems.isEmpty && activeShare == nil {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("No Shared Lists")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Share your main list or join a shared list to see items here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Share Current List", action: onShare)
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == .shared && sharedItems.isEmpty {
                VStack {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("No Shared Items")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Items from shared lists will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            List {
                ForEach(self.currentItems().enumerated().map({$0}), id: \.element.id) { index, item in
                    let red: Double = getColorRed(index: index)
                    let green: Double = getColorGreen(index: index)
                    let blue: Double = getColorBlue(index: index)
                    if ((!shown && !item.done) || (shown)) && item.shown {
                        HStack {
                            Button(action: {
//                                print("Tapped \(item.name) : \(index) \((index % (24 * (index / 24)))) : \(red) : \(green): \(blue)")
                                let newItem = Item.itemDoneLens.set(!item.done, item)
                                self.update(item, to: newItem, completionBlock: {
                                        print("Done")
                                        WidgetCenter.shared.reloadAllTimelines()
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
                                } else {
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
                            if mode == .shared {
                                Image(systemName: "person.2.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 30, maxHeight: 30, alignment: .trailing)
                                    .foregroundColor(.green)
                            } else {
                                ((item.uploadedToICloud) ? Image("Cloud") : Image("NoCloud"))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                      .frame(maxWidth: 30, maxHeight: 30, alignment: .trailing)
                            }
                        }
                        .onTapGesture {
                            selectedItem = item
                            debounceObject.text = item.name
                        }
                        .contextMenu {
                            Button(action: {
                                selectedItem = item
                                debounceObject.text = item.name
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(action: {
                                let newItem = Item.itemDoneLens.set(!item.done, item)
                                self.update(item, to: newItem, completionBlock: {
                                    print("Done")
                                    WidgetCenter.shared.reloadAllTimelines()
                                })
                            }) {
                                Label(item.done ? "Mark as Undone" : "Mark as Done",
                                      systemImage: item.done ? "circle" : "checkmark.circle")
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                let newItem = Item.itemShownLens.set(!item.shown, item)
                                self.update(item, to: newItem, completionBlock: {
                                    print("Done")
                                    WidgetCenter.shared.reloadAllTimelines()
                                })
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive, action: {
                                let newItem = Item.itemShownLens.set(!item.shown, item)
                                self.update(item, to: newItem, completionBlock: {
                                    print("Done")
                                    WidgetCenter.shared.reloadAllTimelines()
                                })
                            }) {Label("Delete", systemImage: "trash")}
                        }
                    }
                }
                VStack {
                    TextField(addItemPlaceholder(), text: $debounceObject.text)
                        .onAppear {
                            guard let selItem = selectedItem else {
                                return
                            }
                            debounceObject.text = selItem.name
                        }
                        .onChange(of: debounceObject.debouncedText) {
                            self.viewModel.inputs.getHints(for: debounceObject.debouncedText, withCompletion: {name1, name2 in
                                hint1 = name1
                                hint2 = name2
                            })
                        }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if let selItem = selectedItem {
                                let newItem = Item.itemNameLens.set(debounceObject.text, selItem)
                                self.update(selItem, to: newItem, completionBlock: {
                                    print("Done!")
                                    self.selectedItem = nil
                                })
                            } else {
                                self.addItem(debounceObject.text)
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                            debounceObject.text = ""
                        }
                    HStack {
                        Button(action: {
                            debounceObject.text = hint1
                        }) {
                            Text(hint1)
                                .padding()
                        }.buttonStyle(.borderless)
                        Spacer()
                        Button(action: {
                            debounceObject.text = hint2
                        }) {
                            Text(hint2)
                                .padding()
                        }.buttonStyle(.borderless)
                    }
                }
            }
            .refreshable {
                print("start refresh")
                if mode == .shared {
                    loadSharedItems()
                } else {
                    _ = self.viewModel.inputs.getItems {
                        print("called getItems")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
           }
            }
        }
        // Lifecycle modifiers sit on the VStack, not the List: the List is not created while a
        // placeholder is shown, so onAppear (loading items, registering observers) would never run.
        .navigationTitle(navigationTitle())
        .toolbar {
            // Sharing status and the Share button live in MainView's toolbar and banner.
            // The Shared tab keeps Refresh: its empty placeholder cannot be pulled to refresh.
            if mode == .shared {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadSharedItems()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newState in
            if newState == .background {
                print("Entered background")
            } else if newState == .inactive {
                print("Became inactive")
            } else if newState == .active {
                if mode == .shared {
                    loadSharedItems()
                } else {
                    _ = self.viewModel.inputs.getItems {
            //            print("called getItems")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
        .alert("Could Not Add Item", isPresented: $showingAddItemError) {
            Button("OK") { }
        } message: {
            Text(addItemError ?? "An unknown error occurred.")
        }
        .onAppear {
            if mode == .shared {
                // Set up notification observer for shared items refresh
                loadSharedItems()
                refreshSharedItemsObserver = NotificationCenter.default.addObserver(
                    forName: .refreshSharedItems,
                    object: nil,
                    queue: .main
                ) { _ in
                    loadSharedItems()
                }
            } else {
                // Set up observer for private database changes (remote sync)
                privateDataChangedObserver = NotificationCenter.default.addObserver(
                    forName: .cloudKitPrivateDataChanged,
                    object: nil,
                    queue: .main
                ) { _ in
                    _ = self.viewModel.inputs.getItems {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
        .onDisappear {
            // Remove observers when view disappears
            if let observer = refreshSharedItemsObserver {
                NotificationCenter.default.removeObserver(observer)
                refreshSharedItemsObserver = nil
            }
            if let observer = privateDataChangedObserver {
                NotificationCenter.default.removeObserver(observer)
                privateDataChangedObserver = nil
            }
        }
    }
}

#Preview {
    @Previewable @State var show: Bool = false
    @Previewable var viewModel: QuickToDoViewModel = QuickToDoViewModel()
    @Previewable @State var selectedItem: Item?

    ItemsView(viewModel: viewModel, shown: $show, activeShare: nil, onShare: {}, mode: .regular)
        .onAppear {
            _ = viewModel.inputs.getItems {
                print("called getItems")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }

}
