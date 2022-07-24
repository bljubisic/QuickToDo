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
import CloudKit

class MainViewController: UIViewController {
    
    var viewModel: QuickToDoViewModelProtoocol!
    
    var itemsTableView: UITableView!
    var topBar: UIView!
    var actionButton: UIButton!
    var selectionButton: UIButton!
    var itemsNumber: UILabel!
    var selectorItems: UIButton!
    
    lazy var refreshControl = UIRefreshControl()
    
    let disposeBag = DisposeBag()
    
    private var filterDone = false
    
    private func configureScreen() {
        itemsTableView = UITableView()
        self.view.addSubview(self.itemsTableView)
        self.itemsTableView.dataSource = self
        self.itemsTableView.delegate = self
        self.itemsTableView.register(ItemTableViewCell.self, forCellReuseIdentifier: "itemCell")
        self.itemsTableView.register(AddItemTableViewCell.self, forCellReuseIdentifier: "addItemCell")
        self.itemsTableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view).inset(UIEdgeInsets(top: 105, left: 5, bottom: 5, right: -5))
        }
        _ = self.viewModel.inputs.getItems() {
            self.itemsTableView.reloadData()
        }
        
        self.topBar = UIView()
    //        self.topBar.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        self.view.addSubview(self.topBar)
        self.topBar.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.snp.top).inset(35)
            make.bottom.equalTo(self.itemsTableView.snp.top).inset(-1)
            make.left.equalTo(self.view.snp.left)
            make.right.equalTo(self.view.snp.right)
        }
        
        self.actionButton = UIButton()
        self.actionButton.setImage(UIImage(systemName: "arrow.clockwise.icloud", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
        self.topBar.addSubview(self.actionButton)
        self.actionButton.snp.makeConstraints { (make) in
            make.top.equalTo(self.topBar.snp.top).inset(10)
            make.bottom.equalTo(self.topBar.snp.bottom).inset(-10)
            make.left.equalTo(self.topBar.snp.left).inset(10)
        }
        self.itemsNumber = UILabel()
        self.topBar.addSubview(self.itemsNumber)
        self.itemsNumber.snp.makeConstraints { (make) in
            make.top.equalTo(self.topBar.snp.top).inset(10)
            make.bottom.equalTo(self.topBar.snp.bottom).inset(-10)
            make.centerX.equalTo(self.topBar.snp.centerX)
        }
        self.itemsNumber.text = "\(self.viewModel.outputs.doneItemsNum)/\(self.viewModel.outputs.totalItemsNum)"
        self.selectorItems = UIButton()
    //        self.selectorItems.setTitleColor(UIColor.blue, for: .normal)
        self.selectorItems.setImage(UIImage(systemName: "xmark.bin", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)), for: .normal)
    //        self.selectorItems.setTitle("Show only remaining", for: .normal)
    //        self.selectorItems.setTitle("Show all", for: .selected)
        self.selectorItems.isEnabled = false
        self.selectorItems.isUserInteractionEnabled = false
        self.topBar.addSubview(self.selectorItems)
        self.selectorItems.snp.makeConstraints { (make) in
            make.top.equalTo(self.topBar.snp.top).inset(10)
            make.bottom.equalTo(self.topBar.snp.bottom).inset(-10)
            make.right.equalTo(self.topBar.snp.right).inset(10)
        }
        self.selectorItems.rx.tap
            .debug()
            .subscribe(onNext: { _ in
                _ = self.viewModel.inputs.hideAllDoneItems()
                self.itemsTableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        self.actionButton.rx.tap
            .debug()
            .subscribe(onNext: { _ in
                let share = CKShare(recordZoneID: self.viewModel.inputs.getZone()!.zoneID)
                share[CKShare.SystemFieldKey.title] = "Sharing list" as CKRecordValue?
                share[CKShare.SystemFieldKey.shareType] = "QuickToDo" as CKRecordValue
                let sharingViewController = UICloudSharingController(preparationHandler: {(UICloudSharingController, handler: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
                   let modRecordsList = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
                   modRecordsList.modifyRecordsResultBlock = { (result) in
                       switch result{
                       case .success():
                           handler(share, CKContainer.default(), nil)
                       case .failure(let error):
                           handler(share, CKContainer.default(), error)
                       }
                   }
                   CKContainer.default().privateCloudDatabase.add(modRecordsList)
                })
                sharingViewController.delegate = self
                sharingViewController.availablePermissions = [.allowPublic, .allowReadOnly]
//                sharingViewController.popoverPresentationController?.barButtonItem = self.actionButton as? UIBarButtonItem
                self.present(sharingViewController, animated:true, completion:nil)
            })
            .disposed(by: disposeBag)
    
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        self.itemsTableView.refreshControl = refreshControl

    }
    
    @objc func refresh(_ sender: AnyObject) {
        print("Activated refresh!!!")
        self.viewModel.inputs.getItems {
            self.itemsTableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
//        self.view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        
        self.configureScreen()
        
        self.viewModel.inputs.getItemsNumbers()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { (arg0) in
                let (total, done) = arg0
                self.itemsNumber.text = "\(total)/\(done)"
                if (done > 0) {
                    self.selectorItems.isEnabled = true
                    self.selectorItems.isUserInteractionEnabled = true
                }
            })
            .disposed(by: disposeBag)
    }
    
    func insert(withModel: QuickToDoProtocol) {
        let viewModel = QuickToDoViewModel(withModel)
        self.viewModel = viewModel
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        
        var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if(UIInterfaceOrientation.portrait.isPortrait) {
                contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height + 30, right: 0.0)
            } else {
                contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.width, right: 0.0)
            }
        }
        
        
        self.itemsTableView.contentInset = contentInsets
        
        let index: IndexPath = IndexPath(row: self.viewModel.inputs.getItemsSize(), section: 0)
        
        self.itemsTableView.scrollToRow(at: index, at: UITableView.ScrollPosition.top, animated: true)
        
        
    }
    
    @objc func keyboardWillHide(notification: NSNotification ) {
        self.itemsTableView.contentInset = UIEdgeInsets.zero;
        self.itemsTableView.scrollIndicatorInsets = UIEdgeInsets.zero;
        
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
                            cell.firstItemSuggestion
                                .rx
                                .tap
                                .subscribe(onNext: { item in
                                    self.addItem(nameOne)
                                    cell.addItemTextBox.text = ""
                                }, onError: {(Error) in print(Error)}, onDisposed:  {}).disposed(by: self.disposeBag)
                            cell.seccondItemSuggestion.setTitle(nameTwo, for: .normal)
                            cell.seccondItemSuggestion
                                .rx
                                .tap
                                .subscribe(onNext: { item in
                                    self.addItem(nameTwo)
                                    cell.addItemTextBox.text = ""
                                }, onError: {(Error) in print(Error)}, onDisposed:  {}).disposed(by: self.disposeBag)
                        })
                    }
                },
                    onError: { (Error) in
                    print(Error)
                }, onDisposed:  {
                }).disposed(by: disposeBag)
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
                            createdAt: Date(),
                            lastUsedAt: Date()
                        ))
                        cell.addItemTextBox.text = ""
                    }
                }.disposed(by: disposeBag)
            return cell
        }
        else {
            let cellIdentifier = "itemCell"
            let cell: ItemTableViewCell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! ItemTableViewCell
            cell.itemName.text = self.viewModel.inputs.getItemsArray(withFilter: filterDone)[row].name
            let item = self.viewModel.outputs.itemsArray[row]
//            print("\(item) : \(indexPath.row)" )
            var imageName = "select"
            if item.done {
                imageName = "selected"
            }
            if let imageSelected = UIImage(named: imageName) {
                cell.used.setImage(imageSelected, for: UIControl.State.normal)
            }
            cell.used.addTarget(self, action: #selector(updateItem), for: .touchUpInside)
            if item.uploadedToICloud {
                cell.cloud.image = UIImage(named: "Cloud")
            } else {
                cell.cloud.image = UIImage(named: "NoCloud")
            }
            return cell
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
    
    @objc func updateItem(sender: AnyObject) {
        let buttonPosition: CGPoint = sender.convert(CGPoint.zero, to: self.itemsTableView)
        let indexPath: NSIndexPath = self.itemsTableView.indexPathForRow(at: buttonPosition)! as NSIndexPath
        
        let row: Int = indexPath.row
        
        if (row <= self.viewModel.outputs.itemsArray.count - 1) {
            let item = self.viewModel.outputs.itemsArray[row]
            
            let newItem: Item = Item.itemDoneLens.set(!item.done, item)
            _ = self.viewModel.inputs.update(item, withItem: newItem) {
                self.itemsTableView.reloadData()
            }
        }
    }
}

extension MainViewController: UITableViewDelegate {

}

extension MainViewController: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("failed to save: \(error.localizedDescription)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "QuickToDo Item"
    }
    
    
}
