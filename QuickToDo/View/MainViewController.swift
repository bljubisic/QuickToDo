//
//  MainViewController.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 27.09.18.
//  Copyright © 2018 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

class MainViewController: UIViewController {
    
    var viewModel: QuickToDoViewModelProtoocol!
    
    var itemsTableView: UITableView!
    
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)
        itemsTableView = UITableView();
        self.view.addSubview(self.itemsTableView)
        self.itemsTableView.dataSource = self
        self.itemsTableView.delegate = self
        self.itemsTableView.register(ItemTableViewCell.self, forCellReuseIdentifier: "itemCell")
        self.itemsTableView.register(AddItemTableViewCell.self, forCellReuseIdentifier: "addItemCell")
        self.itemsTableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view).inset(UIEdgeInsets(top: 20, left: 5, bottom: 5, right: 0))
        }

        
    }
    
    func insert(withModel: QuickToDoProtocol) {
        let viewModel = QuickToDoViewModel(withModel) {
                self.itemsTableView.reloadData()
            }
        self.viewModel = viewModel
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.viewModel.inputs.getItemsSize() + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        
        if (self.viewModel.inputs.getItemsSize() == 0 || row > self.viewModel.inputs.getItemsSize() - 1) {
            let cellIdentifier = "addItemCell"
            let cell: AddItemTableViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! AddItemTableViewCell
            cell.addItemTextBox
                .rx
                .text
                .filter { text in
                    return (text != nil)
                }
                .subscribe(onNext: { item in
                    if let itemUnwrapped = item {
                        self.viewModel.inputs.getHints(for: itemUnwrapped, withCompletion: { (nameOne, nameTwo) in
                            cell.firstItemSuggestion.setTitle(nameOne, for: .normal)
                            cell.seccondItemSuggestion.setTitle(nameTwo, for: .normal)
                        })
                    }
                },
                    onError: { (Error) in
                    print(Error)
                }) {
            }.disposed(by: disposeBag)
            cell.addItemTextBox
                .rx
                .controlEvent([.editingDidEndOnExit])   
                .filter({ text -> Bool in
                    return !self.viewModel.outputs.itemsArray.contains(where: { (item) -> Bool in
                        return (item.name == cell.addItemTextBox.text || cell.addItemTextBox.text == "")
                    })
                })
                .subscribe{ text in
                    if let word = cell.addItemTextBox.text {
                        _  = self.viewModel.inputs.add(Item(
                            name: word,
                            count: 1,
                            uploadedToICloud: false,
                            done: false,
                            shown: true,
                            createdAt: Date()
                        ))
                        cell.addItemTextBox.text = ""
                    }
                }.disposed(by: disposeBag)
            return cell
        }
        else {
            let cellIdentifier = "itemCell"
            let cell: ItemTableViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! ItemTableViewCell
            cell.itemName.text = self.viewModel.outputs.itemsArray[row].name
            let item = self.viewModel.outputs.itemsArray[row]
//            print("\(item) : \(indexPath.row)" )
            var imageName = "select"
            if item.done {
                imageName = "selected"
            }
            if let imageSelected = UIImage(named: imageName) {
                cell.used.setImage(imageSelected, for: UIControl.State.normal)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        
        if (row == 0 && row > self.viewModel.inputs.getItemsSize() - 1) {
            return 78.0
        }
        else if(row > self.viewModel.inputs.getItemsSize() - 1){
            return 78.0
        }
        else {
            return 61.0
        }
    }
}

extension MainViewController: UITableViewDelegate {

}
