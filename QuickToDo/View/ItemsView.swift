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

struct ItemsView: View {
    
    @Environment(\.scenePhase) var scenePhase
    
    @ObservedObject var viewModel: QuickToDoViewModel
    @Binding var shown: Bool
    @Binding var isSharing: Bool
    @Binding var activeShare: CKShare?
    @Binding var activeContainer: CKContainer?
    
    let mode: ItemsViewMode
    
    @StateObject var debounceObject = DebounceObject()
    @State private var sharedItems: [Item] = []
    @State private var isLoadingSharedItems = false
    
    @State private var selectedItem: Item?
    @State var hint1 = ""
    @State var hint2 = ""
    @State private var sharingError: String?
    @State private var showingSharingError = false
    
    // Notification observer
    @State private var refreshSharedItemsObserver: NSObjectProtocol?
    
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
    
    func addItem(_ sender: String) {
        let newItem = Item(
            id: UUID(),
            name: sender,
            count: 1,
            uploadedToICloud: mode == .shared, // Shared items should be uploaded to cloud
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date()
        )
        _ = self.viewModel.inputs.add(newItem)
    }
    
    private func loadSharedItems() {
        guard mode == .shared else { return }
        
        isLoadingSharedItems = true
        sharedItems = []
        
        // Fetch all shared items from the shared database
        _ = viewModel.inputs.fetchAllSharedItems { item in
            DispatchQueue.main.async {
                // Avoid duplicates
                if !self.sharedItems.contains(where: { $0.id == item.id }) {
                    self.sharedItems.append(item)
                }
            }
        }
        
        // Allow a short delay for items to be fetched
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoadingSharedItems = false
            print("Loaded \(self.sharedItems.count) shared items")
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
    
    private func isListShared() -> Bool {
        return viewModel.inputs.isListCurrentlyShared()
    }
    
    private func shareButtonTitle() -> String {
        if isListShared() {
            return "Manage Share"
        } else {
            return "Share List"
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
            } else if mode == .shared && sharedItems.isEmpty && !viewModel.inputs.isListCurrentlyShared() {
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
                    
                    Button("Share Current List") {
                        Task {
                            viewModel.inputs.prepareSharing(handler: { share, container, error in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        print("Error preparing share: \(error.localizedDescription)")
                                        sharingError = error.localizedDescription
                                        showingSharingError = true
                                        return
                                    }
                                    activeShare = share
                                    activeContainer = container
                                    isSharing = true
                                }
                            })
                        }
                    }
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
            List() {
                ForEach(self.currentItems().enumerated().map({$0}), id: \.element.id) { index, item in
                    let red: Double = getColorRed(index: index)
                    let green: Double = getColorGreen(index: index)
                    let blue: Double = getColorBlue(index: index)
                    if (((!shown && !item.done) || (shown)) && item.shown) {
                        HStack() {
                            Button(action: {
//                                print("Tapped \(item.name) : \(index) \((index % (24 * (index / 24)))) : \(red) : \(green): \(blue)")
                                let newItem = Item.itemDoneLens.set(!item.done, item)
                                _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
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
                            debounceObject.text = selectedItem!.name
                        }
                        .contextMenu {
                            Button(action: {
                                selectedItem = item
                                debounceObject.text = selectedItem!.name
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                let newItem = Item.itemDoneLens.set(!item.done, item)
                                _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
                                    print("Done")
                                    WidgetCenter.shared.reloadAllTimelines()
                                })
                            }) {
                                Label(item.done ? "Mark as Undone" : "Mark as Done",
                                      systemImage: item.done ? "circle" : "checkmark.circle")
                            }
                            
                            Divider()
                            
                            Button(action: {
                                Task {
                                    _ = viewModel.inputs.prepareSharing(handler: { share, container, error in
                                        DispatchQueue.main.async {
                                            if let error = error {
                                                print("Error preparing share: \(error.localizedDescription)")
                                                sharingError = error.localizedDescription
                                                showingSharingError = true
                                                return
                                            }
                                            activeShare = share
                                            activeContainer = container
                                            isSharing = true
                                        }
                                    })
                                }
                            }) {
                                Label(shareButtonTitle(), systemImage: isListShared() ? "person.2.fill" : "square.and.arrow.up")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                let newItem = Item.itemShownLens.set(!item.shown, item)
                                _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
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
                                _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
                                    print("Done")
                                    WidgetCenter.shared.reloadAllTimelines()
                                })
                            }) {Label("Delete", systemImage: "trash")}
                        }
                    }
                }
                VStack() {
                    TextField(addItemPlaceholder(), text: $debounceObject.text)
                        .onAppear() {
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
                                _ = self.viewModel.update(selItem, withItem: newItem, completionBlock: {
                                    print("Done!")
                                    self.selectedItem = nil
                                })
                            } else {
                                self.addItem(debounceObject.text)
                            }
                            WidgetCenter.shared.reloadAllTimelines()
                            debounceObject.text = ""
                        }
                    HStack() {
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
            .navigationTitle(navigationTitle())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if mode == .shared {
                        Button("Refresh") {
                            loadSharedItems()
                        }
                    } else {
                        Button(action: {
                            Task {
                                print("Called Share from ItemsView")
                                _ = viewModel.inputs.prepareSharing(handler: { share, container, error in
                                    DispatchQueue.main.async {
                                        if let error = error {
                                            print("Error preparing share: \(error.localizedDescription)")
                                            sharingError = error.localizedDescription
                                            showingSharingError = true
                                            return
                                        }
                                        activeShare = share
                                        activeContainer = container
                                        isSharing = true
                                        print("Sharing prepared successfully")
                                    }
                                })
                            }
                        }) {
                            Image(systemName: isListShared() ? "person.2.fill" : "square.and.arrow.up")
                                .foregroundColor(isListShared() ? .green : .blue)
                        }
                        .disabled(viewModel.outputs.itemsArray.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        if isSharing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if activeShare != nil {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let share = activeShare, let container = activeContainer {
                    NavigationView {
                        CloudSharingView(container: container, share: share)
                            .navigationTitle("Share Todo List")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        isSharing = false
                                    }
                                }
                            }
                        }
                } else {
                    VStack {
                        ProgressView("Preparing share...")
                            .padding()
                        Button("Cancel") {
                            isSharing = false
                        }
                        .padding()
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
            .onChange(of: scenePhase) { oldState, newState in
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
                    
                    // Refresh sharing status when app becomes active
                    Task {
                        do {
                            _ = try await self.viewModel.inputs.refreshShareStatus()
                        } catch {
                            print("Failed to refresh share status: \(error)")
                        }
                    }
                }
            }
            .alert("Sharing Error", isPresented: $showingSharingError) {
                Button("OK") { }
            } message: {
                Text(sharingError ?? "An unknown error occurred while preparing to share.")
            }
            .onAppear {
                // Set up notification observer for shared items refresh
                if mode == .shared {
                    loadSharedItems()
                    refreshSharedItemsObserver = NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("RefreshSharedItems"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        loadSharedItems()
                    }
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                if let observer = refreshSharedItemsObserver {
                    NotificationCenter.default.removeObserver(observer)
                    refreshSharedItemsObserver = nil
                }
            }
            }
        }
    }
}

#Preview {
    @Previewable @State var show: Bool = false
    @Previewable var viewModel: QuickToDoViewModel = QuickToDoViewModel()
    @Previewable @State var isSharing: Bool = false
    @Previewable @State var activeShare: CKShare? = nil
    @Previewable @State var activeContainer: CKContainer? = nil
    @Previewable @State var selectedItem: Item? = nil
    
    
    ItemsView(viewModel: viewModel, shown: $show, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer, mode: .regular)
        .onAppear() {
            _ = viewModel.inputs.getItems {
                print("called getItems")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
}
