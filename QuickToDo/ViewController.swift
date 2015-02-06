//
//  ViewController.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/10/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    
    @IBOutlet weak var itemsTable: UITableView!
    var items: [ItemObject] = [ItemObject]()

    var textView: UITextField?
    var hintButton1: UIButton?
    var hintButton2: UIButton?
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance

    @IBAction func removeUsed(sender: UIButton) {
        dataManager.removeUsedItems()
        var deleteIndexPath: [NSIndexPath] = [NSIndexPath]()
        println(self.items.count)
        for(var i = 0; i < items.count; i++) {
            let tmpItem: ItemObject = items[i]
            
            if(tmpItem.completed > 0) {
                self.items.removeAtIndex(i)
                println(self.items.count)
                deleteIndexPath.append(NSIndexPath(forRow: i, inSection: 0))
            }
        }
        items = dataManager.getItems()
        itemsTable.deleteRowsAtIndexPaths(deleteIndexPath, withRowAnimation: UITableViewRowAnimation.Fade)
        itemsTable.reloadData()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataManager.removeItems()
        
        items = dataManager.getItems()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        let numberOfSections = self.itemsTable.numberOfSections()
        let numberOfRows = self.itemsTable.numberOfRowsInSection(numberOfSections-1)
        
        if numberOfRows > 0 {
            println(numberOfSections)
            let indexPath = NSIndexPath(forRow: numberOfRows-1, inSection: (numberOfSections-1))
            self.itemsTable.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
        
        var tblView =  UIView(frame: CGRectZero)
        self.itemsTable.tableFooterView = tblView
        self.itemsTable.backgroundColor = UIColor.clearColor()
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
        
        var index: NSIndexPath = NSIndexPath(forRow: items.count, inSection: 0)
        
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
        var row: Int = indexPath.row
        
        if(row <= items.count-1) {
            var tmpCell: ViewTableViewCell = itemsTable.cellForRowAtIndexPath(indexPath) as ViewTableViewCell
            var item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                tmpCell.usedButton.selected = false
            } else {
                item.completed = 1
                tmpCell.usedButton.selected = true
            }
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell!
        
        var row: Int = indexPath.row
        
        if(self.items.count == 0 || row > self.items.count - 1) {
            var tmpCell: InputTableViewCell = tableView.dequeueReusableCellWithIdentifier("EnterCell") as InputTableViewCell
            textView = tmpCell.inputTextField
            hintButton1 = tmpCell.addButton1
            hintButton2 = tmpCell.addButton2
            hintButton1?.titleLabel?.text = ""
            hintButton2?.titleLabel?.text = ""
            textView?.backgroundColor = UIColor.orangeColor()
            
            textView?.addTarget(self, action: "textFieldDidChange:", forControlEvents: UIControlEvents.EditingChanged)
            
            
             //   [textField addTarget:self action:@selector(textFieldDone:) forControlEvents:UIControlEventEditingDidEndOnExit];
            
            textView?.addTarget(self, action: "textFieldDone:", forControlEvents: UIControlEvents.EditingDidEndOnExit)
            textView?.delegate = self
            
            cell = tmpCell
            
        }
        else {
            var tmpCell: ViewTableViewCell = tableView.dequeueReusableCellWithIdentifier("ViewCell") as ViewTableViewCell
            tmpCell.listItem.text = self.items[row].word
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
    
    func textFieldDidChange(textFieldSender: UITextField) {
        var text: String = textFieldSender.text
        var hints: [String] = dataManager.getHints(text)
        
        if(hints.count > 1) {
            hintButton1?.titleLabel?.text = hints[0]
            hintButton2?.titleLabel?.text = hints[1]
            
        }
        else if(hints.count > 0) {
            hintButton1?.titleLabel?.text = hints[0]
        }
        
    }
    
    func textFieldDone(textFieldSender: UITextField) {
        var item: String = textFieldSender.text
        
        var itemObject: ItemObject = ItemObject()
        itemObject.word = item
        itemObject.used = 0
        itemObject.count = 1
        itemObject.lasUsed = NSDate()
        
        dataManager.addItem(itemObject)
        
        items.append(itemObject)
        
        
        self.itemsTable.reloadData()
        
        let numberOfSections = self.itemsTable.numberOfSections()
        let numberOfRows = self.itemsTable.numberOfRowsInSection(numberOfSections-1)
        
        if numberOfRows > 0 {
            println(numberOfSections)
            let indexPath = NSIndexPath(forRow: numberOfRows-1, inSection: (numberOfSections-1))
            self.itemsTable.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
        
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var itemsCount: Int = self.items.count
        
        return itemsCount + 1
    }
    
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        
        var row: Int = indexPath.row
        
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
    
    
    


}

