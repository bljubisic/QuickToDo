//
//  MainView.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 03.02.20.
//  Copyright © 2020 Bratislav Ljubisic. All rights reserved.
//

import SwiftUI
import RxSwift

struct MainView: View {
    
    @ObservedObject var viewModel: ViewModelMocked
    
    init(viewModel: QuickToDoViewModelProtoocol) {
        self.viewModel = viewModel as! ViewModelMocked
    }
    
    var body: some View {
        List(self.viewModel.inputs.getItemsArray(withFilter: false)) { item in
            Image("selected")
            HStack() {
                Text(item.name)
                if item.uploadedToICloud {
                    Image("Cloud")
                } else {
                    Image("NoCloud")
                        .padding(.trailing, 100.0)
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
    func prepareSharing() {
        
    }
    
    var inputs: QuickToDoInputs { return self }
    
    var outputs: QuickToDoOutputs { return self }
    
    func add(_ item: Item) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func update(_ item: Item, withItem: Item) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getHints(for itemName: String) -> Observable<String> {
        return Observable.create { (subscriber) -> Disposable in
            return Disposables.create()
        }
    }
    
    func getItems() -> (Bool, Error?) {
        return (true, nil)
    }
    
    var items: Observable<Item?>
    
    var cloudStatus: Observable<CloudStatus>
    
    init() {
        items = PublishSubject()
        cloudStatus = PublishSubject()
    }
}

final class ViewModelMocked: QuickToDoViewModelProtoocol, QuickToDoViewModelInputs, QuickToDoViewModelOutputs, ObservableObject {
    func prepareSharing() {
        
    }
    
    func add(_ newItem: Item) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func update(_ item: Item, withItem: Item, completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getItems(completionBlock: @escaping () -> Void) -> (Bool, Error?) {
        return (true, nil)
    }
    
    func getItemsArray(withFilter: Bool) -> [Item] {
        return [Item(name: "Smt", count: 1, uploadedToICloud: false, done: false, shown: true, createdAt: Date(), lastUsedAt: Date())]
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
    
    var items: Observable<Item?>
    
    var itemsArray: [Item]
    
    var doneItemsNum: Int
    
    var totalItemsNum: Int
    
    var model: QuickToDoProtocol
    
    var inputs: QuickToDoViewModelInputs { return self }
    
    var outputs: QuickToDoViewModelOutputs { return self }
    
    init(model: QuickToDoProtocol) {
        self.model = model
        self.cloudStatus = PublishSubject()
        self.items = PublishSubject()
        self.doneItemsNum = 0
        self.totalItemsNum = 0
        self.itemsArray = []
    }
}
