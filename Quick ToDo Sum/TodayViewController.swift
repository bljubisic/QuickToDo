//
//  TodayViewController.swift
//  Quick ToDo Sum
//
//  Created by Bratislav Ljubisic on 2/21/15.
//  Copyright (c) 2015 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var widgetLabel: UILabel!
    @IBOutlet weak var itemsTable: UITableView!
    
    var items: [ItemObject] = [ItemObject]()
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        items = dataManager.getNotCompletedItems()
        var itemsAll: [ItemObject] = dataManager.getItems()
        
        
        self.itemsTable.dataSource = self
        self.itemsTable.delegate = self
        
        self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        
        self.itemsTable.reloadData()
        updatePreferredContentSize()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func completeItem(sender: UIButton) {
        
        var buttonPosition: CGPoint = sender.convertPoint(CGPoint.zeroPoint, toView: self.itemsTable)
        var indexPath: NSIndexPath = self.itemsTable.indexPathForRowAtPoint(buttonPosition)!
        
        var row: Int = indexPath.row
        
        if(row <= items.count-1) {
            var tmpCell: TodayTableViewCellSum = itemsTable.cellForRowAtIndexPath(indexPath) as TodayTableViewCellSum
            var item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                //tmpCell.completedButton.selected = false
            } else {
                item.completed = 1
                //tmpCell.completedButton.selected = true
            }
            self.items.removeAtIndex(row)
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            var itemsAll: [ItemObject] = dataManager.getItems()
            
            self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        }
        
        
    }
    
    func widgetPerformUpdateWithCompletionHandler(completionHandler: ((NCUpdateResult) -> Void)!) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        items = dataManager.getNotCompletedItems()
        var itemsAll: [ItemObject] = dataManager.getItems()
        
        self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        self.itemsTable.reloadData()
        
        completionHandler(NCUpdateResult.NewData)
        updatePreferredContentSize()
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var row: Int = indexPath.row
        
        if(row <= items.count-1) {
            var tmpCell: TodayTableViewCellSum = tableView.cellForRowAtIndexPath(indexPath) as TodayTableViewCellSum
            var item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                //tmpCell.completedButton.selected = false
            } else {
                item.completed = 1
                //tmpCell.completedButton.selected = true
            }
            self.items.removeAtIndex(row)
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            var itemsAll: [ItemObject] = dataManager.getItems()
            
            self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var row: Int = indexPath.row
        
        var tmpCell: TodayTableViewCellSum = tableView.dequeueReusableCellWithIdentifier("TodayCell") as TodayTableViewCellSum
        tmpCell.itemName.text = self.items[row].word as String
        /*
        if(self.items[row].completed == 1) {
            tmpCell.completedButton.selected = true
        }
        else {
            tmpCell.completedButton.selected = false
        }
        */
        return tmpCell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var itemsCount: Int = self.items.count
        
        if(itemsCount > 3) {
            return 3
        } else {
            return itemsCount
        }
    }
    
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        
        return 50.0
        
    }
    
    func updatePreferredContentSize() {
        preferredContentSize = CGSizeMake(CGFloat(0), CGFloat(tableView(self.itemsTable, numberOfRowsInSection: 0)) * CGFloat(self.itemsTable.rowHeight) + self.itemsTable.sectionFooterHeight + self.widgetLabel.frame.size.height)
    }
    
}
