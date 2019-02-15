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
        if self.viewModel.inputs.getItemsSize() > 0 {
            return self.viewModel.inputs.getItemsSize() + 1
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.row > self.viewModel.inputs.getItemsSize()) || self.viewModel.inputs.getItemsSize() == 0 {
            let cellIdentifier = "addItemCell"
            let cell: AddItemTableViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! AddItemTableViewCell
            cell.addItemTextBox.rx.text.subscribe(onNext: { (item) in
                viewModel.inputs.getHints(for: item, withCompletion: { (nameOne, nameTwo) in
                    cell.firstItemSuggestion.setTitle(nameOne, for: UIControlState.normal)
                })
            },
            onError: { (Error) in
                print(Error)
            }) {
                print("Completed")
                }.disposed(by: disposeBag)
            return cell
        }
        else {
            let cellIdentifier = "itemCell"
            let cell: ItemTableViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! ItemTableViewCell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 98.0
    }
}

extension MainViewController: UITableViewDelegate {

}
