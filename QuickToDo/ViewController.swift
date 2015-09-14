//
//  ViewController.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/10/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CloudKit




class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, InviteProtocol {

    
    @IBOutlet weak var itemsTable: UITableView!
    var items: [ItemObject] = [ItemObject]()

    var textView: UITextField?
    var hintButton1: UIButton?
    var hintButton2: UIButton?
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    var iCloudIdVar: String = String()
    
    

    @IBAction func removeUsed(sender: UIButton) {
        dataManager.removeUsedItems()
        var deleteIndexPath: [NSIndexPath] = [NSIndexPath]()
        //println(self.items.count)
        var i = items.count
        repeat {
            let tmpItem: ItemObject = items[i-1]
            
            if(tmpItem.completed > 0) {
                self.items.removeAtIndex(i-1)
                //println(self.items.count)
                deleteIndexPath.append(NSIndexPath(forRow: i, inSection: 0))
            }
            i--
        } while(i > 0)
        items = dataManager.getItems()
        itemsTable.deleteRowsAtIndexPaths(deleteIndexPath, withRowAnimation: UITableViewRowAnimation.Fade)
        itemsTable.reloadData()
    }
    
    @IBAction func selectedItem(sender: AnyObject) {
        
        let buttonPosition: CGPoint = sender.convertPoint(CGPoint.zero, toView: self.itemsTable)
        let indexPath: NSIndexPath = self.itemsTable.indexPathForRowAtPoint(buttonPosition)!
        
        let row: Int = indexPath.row
        
        if(row <= items.count-1) {
            let tmpCell: ViewTableViewCell = itemsTable.cellForRowAtIndexPath(indexPath) as! ViewTableViewCell
            let item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                tmpCell.usedButton.selected = false
            } else {
                item.completed = 1
                tmpCell.usedButton.selected = true
            }
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            let usedItems: [ItemObject] = dataManager.getNotCompletedItems()
            
            UIApplication.sharedApplication().applicationIconBadgeNumber = usedItems.count
        }
    }
    
    func tableReload() {
        items = dataManager.getItems()
        self.itemsTable.reloadData()
        
    }
    
    func openAlertView(record: CKRecord) {
        
        let sender = record.objectForKey("sender") as! String
        
        if(sender == configManager.selfRecordId) {
            let sendername = record.objectForKey("sendername") as! String
            
            let message = "Your invitation has been accepted!"
            
            let alertController = UIAlertController(title: "Invitation", message: message, preferredStyle: .Alert)
            
            let destroyAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default) { (action) in
                let invitation = InvitationObject()
                
                invitation.sender = sender
                invitation.receiver = record.objectForKey("receiver") as! String
                invitation.confirmed = 1
                invitation.sendername = sendername
                invitation.receivername = record.objectForKey("receivername") as! String
                
                self.dataManager.cdAddInvitation(invitation)
                
                // update invitation on CloudKit
                self.dataManager.ckUpdateInvitation(invitation)
                
                self.dataManager.subscribeOnItems(invitation.receiver)
                
                // add subscription on items with sender id
                
                
            }
            alertController.addAction(destroyAction)
            
            self.presentViewController(alertController, animated: true) {
                // ...
            }
        }
        else {
            let sendername = record.objectForKey("sendername") as! String
            
            let message = "\(sendername) has invited you to share a list"
            
            let alertController = UIAlertController(title: "Invitation", message: message, preferredStyle: .Alert)
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
                print(action)
            }
            alertController.addAction(cancelAction)
            
            let destroyAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default) { (action) in
                let invitation = InvitationObject()
                
                invitation.sender = sender
                invitation.receiver = record.objectForKey("receiver") as! String
                invitation.confirmed = 1
                invitation.sendername = sendername
                invitation.receivername = record.objectForKey("receivername") as! String
                
                self.dataManager.cdAddInvitation(invitation)
                
                // update invitation on CloudKit
                self.dataManager.ckUpdateInvitation(invitation)
                
                self.dataManager.subscribeOnItems(sender)
                
                // add subscription on items with sender id
                
                
            }
            alertController.addAction(destroyAction)
            
            self.presentViewController(alertController, animated: true) {
                // ...
            }
            
        }
        

        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //dataManager.removeItems()
        
        let container: CKContainer = CKContainer.defaultContainer()
        
        items = dataManager.getItems()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationBecameActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        if(configManager.sharingEnabled > 0) {
            container.requestApplicationPermission(CKApplicationPermissions.UserDiscoverability, completionHandler: {status, error in
                
            })
            container.fetchUserRecordIDWithCompletionHandler({recordID, error in
                if let unwrappedRecordId = recordID {
                    self.registerForInvitations(unwrappedRecordId)
                } else {
                    print("The optional is nil!")
                }
                
            })
            
        }
        
        let numberOfSections = self.itemsTable.numberOfSections
        let numberOfRows = self.itemsTable.numberOfRowsInSection(numberOfSections-1)
        
        if numberOfRows > 0 {
            print(numberOfSections)
            let indexPath = NSIndexPath(forRow: numberOfRows-1, inSection: (numberOfSections-1))
            self.itemsTable.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
        
        let tblView =  UIView(frame: CGRectZero)
        self.itemsTable.tableFooterView = tblView
        self.itemsTable.backgroundColor = UIColor.clearColor()
        
        let usedItems: [ItemObject] = dataManager.getNotCompletedItems()
        
        UIApplication.sharedApplication().applicationIconBadgeNumber = usedItems.count
        
        dataManager.delegate = self

    }
    
    func registerForInvitations(recordID: CKRecordID) {
        
        let container: CKContainer = CKContainer.defaultContainer()
        
        let publicDatabase = container.publicCloudDatabase
        
        let predicate = NSPredicate(format: "receiver = '\(recordID.recordName)'")
        
        let subscription = CKSubscription(recordType: "Invitations",
            predicate: predicate,
            options: .FiresOnRecordCreation)
        
        let notificationInfo = CKNotificationInfo()
        
        notificationInfo.alertBody = "Invitation received!!"
        notificationInfo.shouldBadge = true
        
        subscription.notificationInfo = notificationInfo
        
        publicDatabase.saveSubscription(subscription,
            completionHandler: ({returnRecord, error in
                if let err = error {
                    print("subscription failed %@",
                        err.localizedDescription)
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.notifyUser("Success",
                            message: "Subscription set up successfully")
                    }
                }
            }))
    }
    
    func notifyUser(title: String, message: String) -> Void
    {
        let alert = UIAlertController(title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.Alert)
        
        let cancelAction = UIAlertAction(title: "OK",
            style: .Cancel, handler: nil)
        
        alert.addAction(cancelAction)
        self.presentViewController(alert, animated: true,
            completion: nil)
    }
    
    func applicationBecameActive(notification: NSNotification) {
        
        let usedItems: [ItemObject] = dataManager.getNotCompletedItems()
        
        UIApplication.sharedApplication().applicationIconBadgeNumber = usedItems.count
        
        self.items = dataManager.getItems()
        
        self.itemsTable.reloadData()
    }
    
    func keyboardWillShow(notification: NSNotification) {
        
        var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            if(UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation)) {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height + 30, 0.0)
            } else {
                contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.width, 0.0)
            }
        }

        
        self.itemsTable.contentInset = contentInsets
        
        let index: NSIndexPath = NSIndexPath(forRow: items.count, inSection: 0)
        
        self.itemsTable.scrollToRowAtIndexPath(index, atScrollPosition: UITableViewScrollPosition.Top, animated: true)

        
    }
    
    func keyboardWillHide(notification: NSNotification ) {
        self.itemsTable.contentInset = UIEdgeInsetsZero;
        self.itemsTable.scrollIndicatorInsets = UIEdgeInsetsZero;
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let row: Int = indexPath.row
        
        if(row <= items.count-1) {
            let tmpCell: ViewTableViewCell = itemsTable.cellForRowAtIndexPath(indexPath) as! ViewTableViewCell
            let item: ItemObject = items[row]
            var badgeNumber: Int = UIApplication.sharedApplication().applicationIconBadgeNumber
            if(item.completed == 1) {
                item.completed = 0
                tmpCell.usedButton.selected = false
                badgeNumber++
            } else {
                item.completed = 1
                tmpCell.usedButton.selected = true
                badgeNumber--
            }
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            UIApplication.sharedApplication().applicationIconBadgeNumber = badgeNumber
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        
        let row: Int = indexPath.row
        
        if(self.items.count == 0 || row > self.items.count - 1) {
            let tmpCell: InputTableViewCell = tableView.dequeueReusableCellWithIdentifier("EnterCell")as! InputTableViewCell
            textView = tmpCell.inputTextField
            hintButton1 = tmpCell.addButton1
            hintButton2 = tmpCell.addButton2
            hintButton1?.setTitle("", forState: UIControlState.Normal)
            hintButton2?.setTitle("", forState: UIControlState.Normal)
            hintButton1?.enabled = false
            hintButton2?.enabled = false
            
            hintButton1?.addTarget(self, action: "hintButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
            hintButton2?.addTarget(self, action: "hintButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
            
            //textView?.backgroundColor = UIColor.orangeColor()
            textView?.layer.cornerRadius=8.0
            textView?.layer.masksToBounds=true
            textView?.layer.borderColor = UIColor.redColor().CGColor
            
            textView?.layer.borderWidth = 1.0
            
            textView?.addTarget(self, action: "textFieldDidChange:", forControlEvents: UIControlEvents.EditingChanged)
            
            textView?.addTarget(self, action: "textFieldDone:", forControlEvents: UIControlEvents.EditingDidEndOnExit)
            textView?.delegate = self
            
            cell = tmpCell
            
        }
        else {
            let tmpCell: ViewTableViewCell = tableView.dequeueReusableCellWithIdentifier("ViewCell") as! ViewTableViewCell
            tmpCell.listItem.text = self.items[row].word as String
            if(self.items[row].completed == 1) {
                tmpCell.usedButton.selected = true
            }
            else {
                tmpCell.usedButton.selected = false
            }
            cell = tmpCell
        }
        return cell
        
    }
    
    func hintButtonTapped(buttonTapped: UIButton) {
        let text: String? = buttonTapped.titleLabel?.text
        
        textView?.text = text
    }
    
    func textFieldDidChange(textFieldSender: UITextField) {
        
        let text: String = textFieldSender.text!
        var hints: [String] = [String]()
        
        if(text != "") {
            hints = dataManager.getHints(text)
        }
        
        if(hints.count > 1) {
            hintButton1?.setTitle(hints[0], forState: UIControlState.Normal)
            hintButton2?.setTitle(hints[1], forState: UIControlState.Normal)
            hintButton1?.enabled = true
            hintButton2?.enabled = true
        }
        else if (hints.count == 1) {
            hintButton1?.setTitle(hints[0], forState: UIControlState.Normal)
            hintButton2?.setTitle("", forState: UIControlState.Normal)
            hintButton1?.enabled = true
        }
        else if(hints.count == 0) {
            hintButton1?.setTitle("", forState: UIControlState.Normal)
            hintButton2?.setTitle("", forState: UIControlState.Normal)
            hintButton1?.enabled = false
            hintButton2?.enabled = false
        }
        
    }
    
    func textFieldDone(textFieldSender: UITextField) {
        let item: String = textFieldSender.text!
        
        let itemObject: ItemObject = ItemObject()
        itemObject.word = item
        itemObject.used = 1
        itemObject.count = 1
        itemObject.lasUsed = NSDate()
        
        dataManager.addItem(itemObject)
        
        
        
        items.append(itemObject)
        
        
        self.itemsTable.reloadData()
        
        let numberOfSections = self.itemsTable.numberOfSections
        let numberOfRows = self.itemsTable.numberOfRowsInSection(numberOfSections-1)
        
        if numberOfRows > 0 {
            print(numberOfSections)
            let indexPath = NSIndexPath(forRow: numberOfRows-1, inSection: (numberOfSections-1))
            self.itemsTable.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
        
        let usedItems: [ItemObject] = dataManager.getNotCompletedItems()
        
        UIApplication.sharedApplication().applicationIconBadgeNumber = usedItems.count
        
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let itemsCount: Int = self.items.count
        
        return itemsCount + 1
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        let row: Int = indexPath.row
        
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
    
    @IBAction func prepareForUnwind(segue: UIStoryboardSegue) {
        
        let configViewController: ConfigViewController = segue.sourceViewController as! ConfigViewController
        
        self.iCloudIdVar = configViewController.iCloudIdVar
        
        //move all items to CloudKit
        
    }
    
    /*
    -(IBAction)prepareForUnwind:(UIStoryboardSegue *)segue {
    } */
    
    
    


}

