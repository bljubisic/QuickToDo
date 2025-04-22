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
    
    @Binding var viewModel: QuickToDoViewModel
    @Binding var shown: Bool
    @Binding var isSharing: Bool
    @Binding var activeShare: CKShare?
    @Binding var activeContainer: CKContainer?
    
    @StateObject var debounceObject = DebounceObject()
    
    @State private var selectedItem: Item?
    @State var hint1 = ""
    @State var hint2 = ""
    
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
    
    /// Builds a `CloudSharingView` with state after processing a share.
    private func shareView() -> CloudSharingView? {
        guard let share = activeShare, let container = activeContainer else {
            return nil
        }

        return CloudSharingView(container: container, share: share)
    }
    
    var body: some View {
        VStack {
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
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var show: Bool = false
    @Previewable @State var viewModel: QuickToDoViewModel = QuickToDoViewModel()
    @Previewable @State var isSharing: Bool = false
    @Previewable @State var activeShare: CKShare? = nil
    @Previewable @State var activeContainer: CKContainer? = nil
    @Previewable @State var selectedItem: Item? = nil
    
    
    ItemsView(viewModel: $viewModel, shown: $show, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer)
        
}

