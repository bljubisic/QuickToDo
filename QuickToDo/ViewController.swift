//
//  ViewController.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/10/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CloudKit
import RxCocoa
import RxSwift

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, InviteProtocol {

    
    @IBOutlet weak var itemsTable: UITableView!
    var items: [ItemObject] = [ItemObject]()
    var itemsMap: [String: ItemObject] = [String: ItemObject]()

    var textView: UITextField?
    var hintButton1: UIButton?
    var hintButton2: UIButton?
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    var iCloudIdVar: String = String()
    
    

    @IBAction func removeUsed(_ sender: UIButton) {
        dataManager.removeUsedItems()
        var deleteIndexPath: [IndexPath] = [IndexPath]()
        //println(self.items.count)
        var i = items.count
        repeat {
            if(items.count > 0) {
                let tmpItem: ItemObject = items[i-1]
            
                if(tmpItem.completed > 0) {
                    self.items.remove(at: i-1)
                    self.itemsMap.removeValue(forKey: tmpItem.word as String)
                    //println(self.items.count)
                    deleteIndexPath.append(IndexPath(row: i, section: 0))
                }
                i -= 1
            }
        } while(i > 0)
        itemsMap = dataManager.getItems()
        items = [ItemObject](itemsMap.values)
        itemsTable.deleteRows(at: deleteIndexPath, with: UITableViewRowAnimation.fade)
        itemsTable.reloadData()
    }
    
    @IBAction func selectedItem(_ sender: AnyObject) {
        
        let buttonPosition: CGPoint = sender.convert(CGPoint.zero, to: self.itemsTable)
        let indexPath: IndexPath = self.itemsTable.indexPathForRow(at: buttonPosition)!
        
        let row: Int = (indexPath as NSIndexPath).row
        
        if(row <= items.count-1) {
            let tmpCell: ViewTableViewCell = itemsTable.cellForRow(at: indexPath) as! ViewTableViewCell
            let item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                tmpCell.usedButton.isSelected = false
            } else {
                item.completed = 1
                tmpCell.usedButton.isSelected = true
            }
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            let usedItems: [String: ItemObject] = dataManager.getNotCompletedItems()
            
            UIApplication.shared.applicationIconBadgeNumber = usedItems.count
        }
    }
    
    func tableReload() {
        itemsMap = dataManager.getItems()
        items = [ItemObject](itemsMap.values)
        self.itemsTable.reloadData()
        
    }
    
    func openAlertView(_ record: CKRecord) {
        
        let sender = record.object(forKey: "sender") as! String
        
        if(sender == configManager.selfRecordId) {
            let sendername = record.object(forKey: "sendername") as! String
            
            let message = "Your invitation has been accepted!"
            
            let alertController = UIAlertController(title: "Invitation", message: message, preferredStyle: .alert)
            
            let destroyAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (action) in
                let invitation = InvitationObject()
                
                invitation.sender = sender
                invitation.receiver = record.object(forKey: "receiver") as! String
                invitation.confirmed = 1
                invitation.sendername = sendername
                invitation.receivername = record.object(forKey: "receivername") as! String
                
                self.dataManager.cdAddInvitation(invitation)
                
                // update invitation on CloudKit
                self.dataManager.ckUpdateInvitation(invitation)
                
                self.dataManager.subscribeOnItems(invitation.receiver)
                
                // add subscription on items with sender id
                
                
            }
            alertController.addAction(destroyAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
        }
        else {
            let sendername = record.object(forKey: "sendername") as! String
            
            let message = "\(sendername) has invited you to share a list"
            
            let alertController = UIAlertController(title: "Invitation", message: message, preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                print(action)
            }
            alertController.addAction(cancelAction)
            
            let destroyAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (action) in
                let invitation = InvitationObject()
                
                invitation.sender = sender
                invitation.receiver = record.object(forKey: "receiver") as! String
                invitation.confirmed = 1
                invitation.sendername = sendername
                invitation.receivername = record.object(forKey: "receivername") as! String
                
                self.dataManager.cdAddInvitation(invitation)
                
                // update invitation on CloudKit
                self.dataManager.ckUpdateInvitation(invitation)
                
                self.dataManager.subscribeOnItems(sender)
                
                // add subscription on items with sender id
                
                
            }
            alertController.addAction(destroyAction)
            
            self.present(alertController, animated: true) {
                // ...
            }
            
        }
        

        
    }
    
    func updateTableView(_ newItems: [String: ItemObject]) -> Void {
        items = [ItemObject]()
        
        for key in newItems.keys {
            if let itemObject = newItems[key] {
                items.append(itemObject)
            }
        }
        self.itemsTable.reloadData()
        
        
    }
    /*
    override func viewWillAppear(animated: Bool) {
        self.dataManager.getAllItemsFromCloud(updateTableView)
        
    }
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //dataManager.removeItems()
        
        let container: CKContainer = CKContainer.default()
        
        itemsMap = dataManager.getItems()
        items = [ItemObject](itemsMap.values)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.applicationBecameActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        if(configManager.sharingEnabled > 0) {
            container.requestApplicationPermission(CKApplicationPermissions.userDiscoverability, completionHandler: {status, error in
                
            })
            container.fetchUserRecordID(completionHandler: {recordID, error in
                if let unwrappedRecordId = recordID {
                    self.registerForInvitations(unwrappedRecordId)
                } else {
                    print("The optional is nil!")
                }
                
            })
            
        }
        
        let numberOfSections = self.itemsTable.numberOfSections
        let numberOfRows = self.itemsTable.numberOfRows(inSection: numberOfSections-1)
        
        if numberOfRows > 0 {
            print(numberOfSections)
            let indexPath = IndexPath(row: numberOfRows-1, section: (numberOfSections-1))
            self.itemsTable.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
        }
        
        let tblView =  UIView(frame: CGRect.zero)
        self.itemsTable.tableFooterView = tblView
        self.itemsTable.backgroundColor = UIColor.clear
        
        let usedItems: [String: ItemObject] = dataManager.getNotCompletedItems()
        
        UIApplication.shared.applicationIconBadgeNumber = usedItems.count
        
        dataManager.delegate = self

    }
    
    func registerForInvitations(_ recordID: CKRecordID) {
        
        let container: CKContainer = CKContainer.default()
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "receiver = '\(recordID.recordName)'")
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options: .firesOnRecordCreation)
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "Invitation received!!"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.save(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@",
                        err.localizedDescription)
                } else {
                    DispatchQueue.main.async {
                        self.notifyUser("Success",
                            message: "Subscription set up successfully")
                    }
                }
            }))
    }
    
    func notifyUser(_ title: String, message: String) -> Void
    {
        let alert = UIAlertController(title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert)
        
        let cancelAction = UIAlertAction(title: "OK",
            style: .cancel, handler: nil)
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true,
            completion: nil)
    }
    
    func applicationBecameActive(_ notification: Notification) {
        
        let usedItems: [String: ItemObject] = dataManager.getNotCompletedItems()
        
        UIApplication.shared.applicationIconBadgeNumber = usedItems.count
        
        self.itemsMap = dataManager.getItems()
        self.items = [ItemObject](itemsMap.values)
        
        self.itemsTable.reloadData()
    }
    
    func keyboardWillShow(_ notification: Notification) {
        
        var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        if let keyboardSize = ((notification as NSNotification).userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if(UIInterfaceOrientationIsPortrait(UIApplication.shared.statusBarOrientation)) {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height + 30, 0.0)
            } else {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.width, 0.0)
            }
        }

        
        self.itemsTable.contentInset = contentInsets
        
        let index: IndexPath = IndexPath(row: items.count, section: 0)
        
        self.itemsTable.scrollToRow(at: index, at: UITableViewScrollPosition.top, animated: true)

        
    }
    
    func keyboardWillHide(_ notification: Notification ) {
        self.itemsTable.contentInset = UIEdgeInsets.zero;
        self.itemsTable.scrollIndicatorInsets = UIEdgeInsets.zero;
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row: Int = (indexPath as NSIndexPath).row
        
        if(row <= items.count-1) {
            let tmpCell: ViewTableViewCell = itemsTable.cellForRow(at: indexPath) as! ViewTableViewCell
            let item: ItemObject = items[row]
            var badgeNumber: Int = UIApplication.shared.applicationIconBadgeNumber
            if(item.completed == 1) {
                item.completed = 0
                tmpCell.usedButton.isSelected = false
                badgeNumber += 1
            } else {
                item.completed = 1
                tmpCell.usedButton.isSelected = true
                badgeNumber -= 1
            }
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            UIApplication.shared.applicationIconBadgeNumber = badgeNumber
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        
        let row: Int = (indexPath as NSIndexPath).row
        
        if(self.items.count == 0 || row > self.items.count - 1) {
            let tmpCell: InputTableViewCell = tableView.dequeueReusableCell(withIdentifier: "EnterCell")as! InputTableViewCell
            textView = tmpCell.inputTextField
            hintButton1 = tmpCell.addButton1
            hintButton2 = tmpCell.addButton2
            hintButton1?.setTitle("", for: UIControlState())
            hintButton2?.setTitle("", for: UIControlState())
            hintButton1?.isEnabled = false
            hintButton2?.isEnabled = false
            
            hintButton1?.addTarget(self, action: #selector(ViewController.hintButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            hintButton2?.addTarget(self, action: #selector(ViewController.hintButtonTapped(_:)), for: UIControlEvents.touchUpInside)
            
            //textView?.backgroundColor = UIColor.orangeColor()
            textView?.layer.cornerRadius=8.0
            textView?.layer.masksToBounds=true
            textView?.layer.borderColor = UIColor.red.cgColor
            
            textView?.layer.borderWidth = 1.0
            
            //textView?.addTarget(self, action: #selector(ViewController.textFieldDidChange(_:)), forControlEvents: UIControlEvents.EditingChanged)
            
            textView?.addTarget(self, action: #selector(ViewController.textFieldDone(_:)), for: UIControlEvents.editingDidEndOnExit)
            textView?.delegate = self
            
            let textSignal = textView?.rx.textInput.text.map({ (value: String) -> AnyObject in
                let hints = QuickToDoDataManager.sharedInstance.getHints(value)
                if(hints.count == 2 && hints[0] == hints[1]) {
                    return [hints[0]] as AnyObject
                }
                else {
                    return hints as AnyObject
                }
            })
            
            textSignal?.subscribe(onNext: { [unowned self] (hints) in
                let hintsArray = hints as! [String]
                
                if(hintsArray.count > 1) {
                    self.hintButton1?.setTitle(hintsArray[0], for: UIControlState.normal)
                    self.hintButton2?.setTitle(hintsArray[1], for: UIControlState.normal)
                    self.hintButton1?.isEnabled = true
                    self.hintButton2?.isEnabled = true
                }
                else if (hintsArray.count == 1) {
                    self.hintButton1?.setTitle(hintsArray[0], for: UIControlState.normal)
                    self.hintButton2?.setTitle("", for: UIControlState.normal)
                    self.hintButton1?.isEnabled = true
                }
                else if(hintsArray.count == 0) {
                    self.hintButton1?.setTitle("", for: UIControlState.normal)
                    self.hintButton2?.setTitle("", for: UIControlState.normal)
                    self.hintButton1?.isEnabled = false
                    self.hintButton2?.isEnabled = false
                }
            })
            
            
            /*
            let textSignal = textView?.rx_text.map{ (value: AnyObject!) -> AnyObject in
                if let text: String = (value as! String) {
                    let hints = QuickToDoDataManager.sharedInstance.getHints(text)
                    if(hints.count == 2 && hints[0] == hints[1]) {
                        return [hints[0]]
                    }
                    else {
                        return hints
                    }
                }
            }
 
            textSignal?.subscribeNext{ [unowned self] (hints) in
                if let hintsArray: [String] = (hints as! [String]) {
                    if(hintsArray.count > 1) {
                        self.hintButton1?.setTitle(hintsArray[0], forState: UIControlState.Normal)
                        self.hintButton2?.setTitle(hintsArray[1], forState: UIControlState.Normal)
                        self.hintButton1?.enabled = true
                        self.hintButton2?.enabled = true
                    }
                    else if (hintsArray.count == 1) {
                        self.hintButton1?.setTitle(hintsArray[0], forState: UIControlState.Normal)
                        self.hintButton2?.setTitle("", forState: UIControlState.Normal)
                        self.hintButton1?.enabled = true
                    }
                    else if(hintsArray.count == 0) {
                        self.hintButton1?.setTitle("", forState: UIControlState.Normal)
                        self.hintButton2?.setTitle("", forState: UIControlState.Normal)
                        self.hintButton1?.enabled = false
                        self.hintButton2?.enabled = false
                    }
                }
            }
            */
            cell = tmpCell
            
        }
        else {
            let tmpCell: ViewTableViewCell = tableView.dequeueReusableCell(withIdentifier: "ViewCell") as! ViewTableViewCell
            tmpCell.listItem.text = self.items[row].word as String
            if(self.items[row].completed == 1) {
                tmpCell.usedButton.isSelected = true
            }
            else {
                tmpCell.usedButton.isSelected = false
            }
            cell = tmpCell
        }
        return cell
        
    }
    
    func hintButtonTapped(_ buttonTapped: UIButton) {
        let text: String? = buttonTapped.titleLabel?.text
        
        textView?.text = text
    }
    
    func textFieldDone(_ textFieldSender: UITextField) {
        
        if let textFieldText = textFieldSender.text {
            if(textFieldText != "") {
                let item: String = textFieldText
            
                let itemObject: ItemObject = ItemObject()
                itemObject.word = item as NSString
                itemObject.used = 1
                itemObject.count = 1
                itemObject.lasUsed = Date()
        
                dataManager.addItem(itemObject)
        
        
        
                items.append(itemObject)
        
        
                self.itemsTable.reloadData()
        
                let numberOfSections = self.itemsTable.numberOfSections
                let numberOfRows = self.itemsTable.numberOfRows(inSection: numberOfSections-1)
        
                if numberOfRows > 0 {
                    print(numberOfSections)
                    let indexPath = IndexPath(row: numberOfRows-1, section: (numberOfSections-1))
                    self.itemsTable.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
                }
        
                let usedItems: [String: ItemObject] = dataManager.getNotCompletedItems()
        
                UIApplication.shared.applicationIconBadgeNumber = usedItems.count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let itemsCount: Int = self.items.count
        
        print("Number of items: \(itemsCount + 1)")
        
        return itemsCount + 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let row: Int = (indexPath as NSIndexPath).row
        
        if (row == 0 && row > self.items.count - 1) {
            return 108.0
        }
        else if(row > self.items.count - 1){
            return 108.0
        }
        else {
            return 61.0
        }
        
    }
    
    @IBAction func prepareForUnwind(_ segue: UIStoryboardSegue) {
        
        let configViewController: ConfigViewController = segue.source as! ConfigViewController
        
        self.iCloudIdVar = configViewController.iCloudIdVar
        
        //move all items to CloudKit
        
    }
    
    /*
    -(IBAction)prepareForUnwind:(UIStoryboardSegue *)segue {
    } */
    
    
    


}

