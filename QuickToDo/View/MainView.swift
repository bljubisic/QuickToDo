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
    
    @StateObject var debounceObject = DebounceObject()
    
    @ObservedObject var viewModel: QuickToDoViewModel
//    @ObservedObject var viewModel: ViewModelMocked
    @State var hint1 = ""
    @State var hint2 = ""
    
    init(viewModel: QuickToDoViewModelProtoocol) {
//        self.viewModel = viewModel as! ViewModelMocked
        self.viewModel = viewModel as! QuickToDoViewModel
        _ = self.viewModel.inputs.getItems {
//            print("called getItems")
        }
    }
    
    @State private var text = ""
    @State private var shown = true

    var body: some View {
        VStack() {
            HStack() {
                Button(action: {
                    _ = self.viewModel.inputs.getItems {
                        print("called getItems")
                    }
                }, label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .resizable()
                        .frame(width: 40.0, height: 40.0)
                })
                Spacer()
                Button(action: {
                    _ = self.viewModel.inputs.clearList()
                }, label: {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .frame(width: 40.0, height: 40.0)
                        .padding()
                })
                Button(action: {
                    shown = !shown
                    _ = self.viewModel.inputs.showOrHideAllDoneItems(shown: shown)
//                    _ = self.viewModel.inputs.getItems {
//                        print("getting new items")
//                    }
                }, label: {
                    Image(systemName: "xmark.bin")
                        .resizable()
                        .frame(width: 40.0, height: 40.0)
                        .padding()
                })
                Button(action: {
                    _ = self.viewModel.inputs.uploadToCloud()
                }, label: {
                    Image(systemName: "arrow.clockwise.icloud")
                        .resizable()
                        .frame(width: 40.0, height: 30.0)
                        .padding()
                })
            }
            .padding()
            List() {
                ForEach(self.viewModel.outputs.itemsArray) { item in
                    if (item.shown == true) {
                        HStack() {
                            Button(action: {
                                print("Tapped \(item.name)")
                                let newItem = Item.itemDoneLens.set(!item.done, item)
                                _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
                                        print("Done")
                                    })
                            }, label: {
                                if item.done {
                                    Image("selected")
                                }
                                else {
                                    Image("select")
                                }
                            })
                            Text(item.name)
                                .scaledToFit()
                            Spacer()
                            if item.uploadedToICloud {
                                Image("Cloud")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                  .frame(maxWidth: 50, maxHeight: 50, alignment: .trailing)
                            } else {
                                Image("NoCloud")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 50, maxHeight: 50, alignment: .trailing)
                            }
                        }
                    }
                }
                VStack() {
                    TextField("Add new item", text: $debounceObject.text)
                        .onChange(of: debounceObject.debouncedText) { text in
                            self.viewModel.inputs.getHints(for: debounceObject.debouncedText, withCompletion: {name1, name2 in
                                hint1 = name1
                                hint2 = name2
                            })
                        }
                        .onSubmit {
                            self.addItem(debounceObject.text)
                        }
                    HStack() {
                        Button(action: {
                            debounceObject.text = hint1
                        }) {
                            Text(hint1)
                                .padding()
                        }
                        Spacer()
                        Button(action: {
                            debounceObject.text = hint2
                        }) {
                            Text(hint2)
                                .padding()
                        }
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
        }
    }
    
    func addItem(_ sender: String) {
        _ = self.viewModel.inputs.add(Item(
            name: sender,
            count: 1,
            uploadedToICloud: false,
            done: false,
            shown: true,
            createdAt: Date(),
            lastUsedAt: Date())
        )
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
    func getZone() -> CKRecordZone? {
        return nil
    }
    
    func getRootRecord() -> CKRecord? {
        return nil
    }
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        
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
      self.itemsPrivate.onNext(Item(name: "Smt2232", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()))
        return (true, nil)
    }
    
    var items: Observable<Item> {
      return itemsPrivate.compactMap{ $0 }
    }
    
    var cloudStatus: Observable<CloudStatus>
  
    private let itemsPrivate: PublishSubject<Item?> = PublishSubject()
    
    init() {
        cloudStatus = PublishSubject()
    }
}

final class ViewModelMocked: QuickToDoViewModelProtoocol, QuickToDoViewModelInputs, QuickToDoViewModelOutputs, ObservableObject {
    
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
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        
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
        self.itemsArray = [Item(name: "Smt24232", count: 1, uploadedToICloud: false, done: true, shown: true, createdAt: Date(), lastUsedAt: Date())]
    }
}
