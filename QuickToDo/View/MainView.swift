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

struct MainView: View {

    @EnvironmentObject var shareManager: CloudKitShareManager
    @StateObject var viewModel: QuickToDoViewModel
//    @ObservedObject var viewModel: ViewModelMocked

    @State private var text = ""
    @State private var shown: Bool = false

    @State private var isSharing = false

    @State private var activeShare: CKShare?
    @State private var activeContainer: CKContainer?

    init(viewModel: QuickToDoViewModelProtoocol) {
//        self.viewModel = viewModel as! ViewModelMocked
        guard let concreteViewModel = viewModel as? QuickToDoViewModel else {
            fatalError("Expected QuickToDoViewModel")
        }
        _viewModel = StateObject(wrappedValue: concreteViewModel)
        shown = viewModel.inputs.getConfig()
        _ = concreteViewModel.inputs.getItems {
//            print("called getItems")
            WidgetCenter.shared.reloadAllTimelines()
        }

    }

    /// Builds a `CloudSharingView` with state after processing a share.
    private func shareView() -> CloudSharingView? {

        guard let share = activeShare, let container = activeContainer else {
            return nil
        }
        print("Displaying sheet")
        return CloudSharingView(container: container, share: share)
    }

    var body: some View {
        VStack {
            Toolbar(viewModel: viewModel, shown: $shown, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer)
            SharingStatusView(activeShare: $activeShare, isSharing: $isSharing)
            TabView {
                NavigationStack {
                    ItemsView(viewModel: viewModel, shown: $shown, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer, mode: .regular)
                        .onAppear {
                            _ = self.viewModel.inputs.getItems {
                                print("called getItems")
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        }
                        .sheet(isPresented: $isSharing, content: { shareView() })
                }
                .tabItem {
                    Label("Items", systemImage: "list.bullet")
                }
                NavigationStack {
                    ItemsView(viewModel: viewModel, shown: $shown, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer, mode: .shared)
                        .onAppear {
                            // Refresh share status when shared items tab appears
                            Task {
                                do {
                                    _ = try await self.viewModel.inputs.refreshShareStatus()
                                } catch {
                                    print("Failed to refresh share status: \(error)")
                                }
                            }
                        }
                        .sheet(isPresented: $isSharing, content: { shareView() })
                }
                .tabItem {
                    Label("Shared Items", systemImage: viewModel.inputs.isListCurrentlyShared() ? "person.2.fill" : "person.crop.circle")
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = QuickToDoViewModel()
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

    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        handler(nil, nil, nil)
    }

    func getCurrentShareStatus() -> CKShare? {
        return nil
    }

    func isListCurrentlyShared() -> Bool {
        return false
    }

    func refreshShareStatus() async throws -> CKShare? {
        return nil
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
        return Observable.create { (_) -> Disposable in
            return Disposables.create()
        }
    }

    func getItems() -> (Bool, Error?) {
        self.itemsPrivate.onNext(Item(id: UUID(), name: "Smt2232", count: 1, uploadedToICloud: true, done: false, shown: true, createdAt: Date(), lastUsedAt: Date()))
        return (true, nil)
    }

    func getSharedItems(for root: CKRecord, with completion: ((Item) -> Void)?) -> (Bool, Error?) {
        return (true, nil)
    }

    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        return (true, nil)
    }

    var items: Observable<Item> {
      return itemsPrivate.compactMap { $0 }
    }

    var cloudStatus: Observable<CloudStatus>

    private let itemsPrivate: PublishSubject<Item?> = PublishSubject()

    init() {
        cloudStatus = PublishSubject()
        config = QuickToDoConfig(showDoneItems: true)
    }
}

final class ViewModelMocked: QuickToDoViewModelProtoocol, QuickToDoViewModelInputs, QuickToDoViewModelOutputs, ObservableObject {
    func getCurrentShareStatus() -> CKShare? {
        return nil
    }

    func isListCurrentlyShared() -> Bool {
        return false
    }

    func refreshShareStatus() async throws -> CKShare? {
        return nil
    }

    func fetchAllSharedItems(completion: @escaping (Item) -> Void) -> (Bool, Error?) {
        return (true, nil)
    }

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
    func prepareSharing(handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        handler(nil, nil, nil)
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
          if item.lastUsedAt < withItem.lastUsedAt {
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
        .filter {(item) -> Bool in
          return item.name != ""
        }
        .filter {(item) -> Bool in
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
                if item.lastUsedAt < newItem.lastUsedAt {
                  self.itemsArray[index] = newItem
                }
              }
            }
          }, onError: { (error) in
            print(error)
          }, onDisposed: {
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
        return Observable.create { (_) -> Disposable in
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
