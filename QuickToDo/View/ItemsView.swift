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

struct ItemsView: View {
    
    @Environment(\.scenePhase) var scenePhase
    
    @ObservedObject var viewModel: QuickToDoViewModel
    @Binding var shown: Bool
    @Binding var isSharing: Bool
    @Binding var activeShare: CKShare?
    @Binding var activeContainer: CKContainer?
    
    @StateObject var debounceObject = DebounceObject()
    
    @State private var selectedItem: Item?
    @State var hint1 = ""
    @State var hint2 = ""
    @State private var sharingError: String?
    @State private var showingSharingError = false
    
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
        _ = self.viewModel.inputs.add(Item(
            id: UUID(),
            name: sender,
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date())
        )
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
            // Sharing status indicator
            if activeShare != nil {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    Text("List is shared with others")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Manage Share") {
                        isSharing = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            List() {
                ForEach(self.viewModel.outputs.itemsArray.enumerated().map({$0}), id: \.element.id) { index, item in
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
                            ((item.uploadedToICloud) ? Image("Cloud") : Image("NoCloud"))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                  .frame(maxWidth: 30, maxHeight: 30, alignment: .trailing)
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
                    TextField("Add new item", text: $debounceObject.text)
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
            .navigationTitle("Quick ToDo List!!!")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                _ = self.viewModel.inputs.getItems {
                    print("called getItems")
                    WidgetCenter.shared.reloadAllTimelines()
                }
           }
            .onChange(of: scenePhase) { oldState, newState in
                if newState == .background {
                    print("Entered background")
                } else if newState == .inactive {
                    print("Became inactive")
                } else if newState == .active {
                    _ = self.viewModel.inputs.getItems {
            //            print("called getItems")
                        WidgetCenter.shared.reloadAllTimelines()
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
    
    
    ItemsView(viewModel: viewModel, shown: $show, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer)
        .onAppear() {
            _ = viewModel.inputs.getItems {
                print("called getItems")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
}
