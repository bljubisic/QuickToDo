//
//  MainView.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 03.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import SwiftUI
import RxSwift
import CloudKit
import Combine
import WidgetKit
import UserNotifications

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


struct MainView: View {
    
    @Environment(\.scenePhase) var scenePhase
    
    @StateObject var debounceObject = DebounceObject()
    
    @ObservedObject var viewModel: QuickToDoViewModel
//    @ObservedObject var viewModel: ViewModelMocked
    @State var hint1 = ""
    @State var hint2 = ""
    
    @State private var text = ""
    @State private var shown: Bool = false
    @State private var selectedItem: Item?
    @State private var isSharing = false
    @State private var activeShare: CKShare?
    @State private var activeContainer: CKContainer?
    
    init(viewModel: QuickToDoViewModelProtoocol) {
//        self.viewModel = viewModel as! ViewModelMocked
        self.viewModel = viewModel as! QuickToDoViewModel
        shown = viewModel.inputs.getConfig()
        _ = self.viewModel.inputs.getItems {
//            print("called getItems")
        }
        
    }
    
    var body: some View {
        VStack() {
            HStack() {
                VStack() {
                    Button(action: {
                        _ = self.viewModel.inputs.getItems {
                            print("called getItems")
                        }
                    }, label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .resizable()
                            .frame(width: 20.0, height: 20.0)
                    })
                    Text("Refresh all")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.blue)
                        .font(.system(size: 12,  design: .rounded))
                        .frame(width: 70.0, height: 20.0)
                }
                VStack() {
                    Button(action: {
                        Task {
                            let shareReturn = await self.viewModel.inputs.prepareSharing()
                            if let share = shareReturn.0, let container = shareReturn.1 {
                                activeShare = share
                                activeContainer = container
                                isSharing = true
                            }
                        }
                    }, label: {
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .frame(width: 20.0, height: 20.0)
                    })
                    Text("Share all")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.blue)
                        .font(.system(size: 12,  design: .rounded))
                        .frame(width: 70.0, height: 20.0)
                }
                .sheet(isPresented: $isSharing) {
                    shareView()
                }
                VStack() {
                    Button(action: {
                        _ = self.viewModel.inputs.clearList()
                    }, label: {
                        Image(systemName: "cart.badge.minus")
                            .resizable()
                            .frame(width: 30.0, height: 20.0)
                    })
                    Text("Remove all")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.blue)
                        .font(.system(size: 12,  design: .rounded))
                        .frame(width: 70.0, height: 20.0)
                }

                VStack() {
                    Button(action: {
                        shown.toggle()
                        _ = self.viewModel.inputs.save(config: shown)
                    }, label: {
                        ((shown) ? Image(systemName: "bag") : Image(systemName: "bag.fill"))
                            .resizable()
                            .frame(width: 20.0, height: 20.0)
                    })
                    ((shown) ? Text("Remove done") : Text("Show done"))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.blue)
                        .font(.system(size: 12,  design: .rounded))
                        .frame(width: 70.0, height: 20.0)
                }

                VStack() {
                    Button(action: {
                        _ = self.viewModel.inputs.uploadToCloud()
                    }, label: {
                        Image(systemName: "arrow.clockwise.icloud")
                            .resizable()
                            .frame(width: 30.0, height: 20.0)
                    })
                    Text("Update all")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.blue)
                        .font(.system(size: 12,  design: .rounded))
                        .frame(width: 70.0, height: 20.0)
                }

            }
            .padding()
            List() {
                ForEach(self.viewModel.outputs.itemsArray.enumerated().map({$0}), id: \.element.id) { index, item in
                    let red: Double = getColorRed(index: index)
                    let green: Double = getColorGreen(index: index)
                    let blue: Double = getColorBlue(index: index)
                    if (((!shown && !item.done) || (shown)) && item.shown) {
                        HStack() {
                            Button(action: {
                                print("Tapped \(item.name): \(red) : \(green): \(blue)")
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
                    }
                }
            }
        }
    }
    
    private func getColorRed(index: Int)-> Double {
        if index > 8 {
            if index < 16 {
                return Double(32 * (8 - (index - 8)))
            } else if  index < 24 {
                return Double(32 * (index - 16))
            } else {
                return 255
            }
        } else {
            return 255
        }
    }
    
    private func getColorGreen(index: Int) -> Double {
        if index < 8 {
            return Double(32 * (8 - index))
        } else {
            if index > 8 {
                return 0
            } else if index > 24 {
                return Double (32 * (index - 16))
            } else {
                return 0
            }
        }
    }
    
    private func getColorBlue(index: Int) -> Double {
        if index > 8 {
            if index < 16 {
                return Double(32 * (index - 8))
            } else {
                if index < 24 {
                    return Double (32 * (8 - (index - 16)))
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
    
    private func shareView() -> CloudShareView? {
        guard let share = activeShare, let container = activeContainer else {
            return nil
        }

        return CloudShareView(container: container, share: share)
    }
}



struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let model = ModelMocked()
        let viewModel = ViewModelMocked(model: model)
        return MainView(viewModel: viewModel)
            .previewInterfaceOrientation(.portrait)
    }
}

final class ModelMocked: QuickToDoProtocol, QuickToDoInputs, QuickToDoOutputs {
    typealias Observable = RxSwift.Observable
    
    func save(config: QuickToDoConfig) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getConfig() -> QuickToDoConfig? {
        return QuickToDoConfig(showDoneItems: true)
    }
    
    var config: QuickToDoConfig
    
    func getZone() -> CKRecordZone? {
        return nil
    }
    
    func getRootRecord() -> CKRecord? {
        return nil
    }
    func prepareSharing() async -> (CKShare?, CKContainer?){
        return (nil, nil)
    }
    
    func uploadToCloud(items: [Item]) -> (Bool, Error?) {
        return (true, nil)
    }
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    func add(_ item: Item, addToCloud: Bool) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func update(_ item: Item, withItem: Item) -> (Bool, Error?) {
      self.itemsPrivate.onNext(withItem)
        return (true, nil)
    }
    
    func getHints(for itemName: String) -> Observable<String> {
        return Observable.create { (subscriber) -> Disposable in
            return Disposables.create()
        }
    }
    
    func getItems() -> (Bool, Error?) {
        self.itemsPrivate.onNext(Item(id: UUID(), name: "Smt2232", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()))
        return (true, nil)
    }
    
    var items: Observable<Item> {
      return itemsPrivate.compactMap{ $0 }
    }
    
    var cloudStatus: Observable<CloudStatus>
  
    private let itemsPrivate: PublishSubject<Item?> = PublishSubject()
    
    init() {
        cloudStatus = PublishSubject()
        config = QuickToDoConfig(showDoneItems: true)
    }
}

final class ViewModelMocked: QuickToDoViewModelProtoocol, QuickToDoViewModelInputs, QuickToDoViewModelOutputs, ObservableObject {
    typealias Observable = RxSwift.Observable
    
    func save(config: Bool) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func remove(updated item: Item) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getConfig() -> Bool {
        return true
    }
    
    
    func getZone() -> CKRecordZone? {
        return nil
    }
    
    func clearList() -> Bool {
        return true
    }
    
    func uploadToCloud() -> (Bool, Error?) {
        return(true, nil)
    }
    
        
    func getRootRecord() -> CKRecord? {
        return nil
    }
    func prepareSharing() async -> (CKShare?, CKContainer?) {
        return (nil, nil)
    }
    
    func add(_ newItem: Item) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func update(_ item: Item, withItem: Item, completionBlock: @escaping () -> Void) -> (Bool, Error?) {
      print("Update")
      if self.itemsArray.contains(where: { item in
        item.name == withItem.name
      }) {
        if let index = self.itemsArray.firstIndex(where: { (item) -> Bool in
          item.name == withItem.name
        }) {
          let item = self.itemsArray[index]
          if (item.lastUsedAt < withItem.lastUsedAt) {
            self.itemsArray[index] = withItem
          }
        }
      }
      completionBlock()
        return (true, nil)
    }
    
    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?) {
      self.model.outputs.items
        .observe(on: MainScheduler.instance)
        .filter{(item) -> Bool in
          return item.name != ""
        }
        .filter{(item) -> Bool in
          return item.shown
        }
        .subscribe(onNext: {(newItem) in
            if !self.itemsArray.contains(where: { (item) -> Bool in
              item.name == newItem.name
            }) {
              self.itemsArray.append(newItem)
              DispatchQueue.main.async {
                completionBlock()
              }
              
            } else {
              if let index = self.itemsArray.firstIndex(where: { (item) -> Bool in
                item.name == newItem.name
              }) {
                let item = self.itemsArray[index]
                if (item.lastUsedAt < newItem.lastUsedAt) {
                  self.itemsArray[index] = newItem
                }
              }
            }
          }, onError: { (Error) in
            print(Error)
          }, onDisposed:  {
          }).disposed(by: disposeBag)
        return (true, nil)
    }
    
    func getItemsArray(withFilter: Bool) -> [Item] {
      return itemsArray
    }
    
    func getItemsSize() -> Int {
        return 1
    }
    
    func getHints(for itemName: String, withCompletion: @escaping (String, String) -> Void) {
        
    }
    
    func getItemsNumbers() -> Observable<(Int, Int)> {
        return Observable.create { (subsriber) -> Disposable in
            return Disposables.create()
        }
    }
    
    func showOrHideAllDoneItems(shown: Bool) -> Bool {
        return true
    }
    
    var cloudStatus: Observable<CloudStatus>
    
    var items: Observable<Item>
    
    var itemsArray: [Item]
    
    var doneItemsNum: Int
    
    var totalItemsNum: Int
    
    var model: QuickToDoProtocol
    
    var inputs: QuickToDoViewModelInputs { return self }
    
    var outputs: QuickToDoViewModelOutputs { return self }
  
  let disposeBag = DisposeBag()
    
    init(model: QuickToDoProtocol) {
        self.model = model
        self.cloudStatus = PublishSubject()
        self.items = PublishSubject()
        self.doneItemsNum = 0
        self.totalItemsNum = 0
        self.itemsArray = [Item(id: UUID(), name: "Smt24232", count: 1, uploadedToICloud: false, done: true, shown: true, createdAt: Date(), lastUsedAt: Date())]
    }
}
