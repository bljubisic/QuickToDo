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

struct MainView: View {
    
    @ObservedObject var viewModel: ViewModelMocked
    
//    init(viewModel: QuickToDoViewModelProtoocol) {
////        self.viewModel = viewModel as! ViewModelMocked
//    }
    @State private var text = ""
    var body: some View {
        List() {
            VStack() {
                TextField("Add new item", text: $text)
                HStack() {
                    Button(action: {}) {
                        Text("First Hint")
                            .padding()
                    }
                    Button(action: {}) {
                        Text("Second Hint")
                            .padding()
                    }
                }
            }
            ForEach(self.viewModel.inputs.getItemsArray(withFilter: false)) {item in
                HStack() {
                    if item.done {
                      Image("selected").onTapGesture {
                        let newItem = Item.itemDoneLens.set(!item.done, item)
                        _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
                          print("Done")
                        })
                      }
                    } else {
                      Image("select").onTapGesture {
                        let newItem = Item.itemDoneLens.set(!item.done, item)
                        _ = self.viewModel.update(item, withItem: newItem, completionBlock: {
                          print("Done")
                        })
                      }
                    }
                    Text(item.name)
                    if item.uploadedToICloud {
                        Image("Cloud")
                          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    } else {
                        Image("NoCloud")
                          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let model = ModelMocked()
        let viewModel = ViewModelMocked(model: model)
        return MainView(viewModel: viewModel)
    }
}

final class ModelMocked: QuickToDoProtocol, QuickToDoInputs, QuickToDoOutputs {
    func getRootRecord() -> CKRecord? {
        return nil
    }
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        
    }
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    func add(_ item: Item) -> (Bool, Error?) {
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
    
    func hideAllDoneItems() -> Bool {
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
        self.itemsArray = [Item(name: "Smt24232", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())]
    }
}
