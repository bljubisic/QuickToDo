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
    var itemsMap: [String: ItemObject] = [String: ItemObject]()
    
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        itemsMap = dataManager.getNotCompletedItems()
        let itemsAll: [String: ItemObject] = dataManager.getItems()
        //let itemsAll: [ItemObject] = [ItemObject](itemsAllMap.values)
        
        configManager.readKeyStore()
        //configManager.readConfigPlist()
        
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

    @IBAction func completeItem(_ sender: UIButton) {
        
        let buttonPosition: CGPoint = sender.convert(CGPoint.zero, to: self.itemsTable)
        let indexPath: IndexPath = self.itemsTable.indexPathForRow(at: buttonPosition)!
        
        let row: Int = (indexPath as NSIndexPath).row
        
        if(row <= items.count-1) {
            //var tmpCell: TodayTableViewCellSum = itemsTable.cellForRowAtIndexPath(indexPath) as! TodayTableViewCellSum
            let item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                //tmpCell.completedButton.selected = false
            } else {
                item.completed = 1
                //tmpCell.completedButton.selected = true
            }
            self.items.remove(at: row)
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            let itemsAll: [String: ItemObject] = dataManager.getItems()
            
            self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        }
        
        
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData

        itemsMap = dataManager.getNotCompletedItems()
        items = [ItemObject](itemsMap.values)
        
        let itemsAll: [String: ItemObject] = dataManager.getItems()
        
        self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        self.itemsTable.reloadData()
        
        completionHandler(NCUpdateResult.newData)
        updatePreferredContentSize()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row: Int = (indexPath as NSIndexPath).row
        
        if(row <= items.count-1) {
            //var tmpCell: TodayTableViewCellSum = tableView.cellForRowAtIndexPath(indexPath) as! TodayTableViewCellSum
            let item: ItemObject = items[row]
            if(item.completed == 1) {
                item.completed = 0
                //tmpCell.completedButton.selected = false
            } else {
                item.completed = 1
                //tmpCell.completedButton.selected = true
            }
            self.items.remove(at: row)
            self.itemsTable.reloadData()
            dataManager.updateItem(item)
            let itemsAll: [String: ItemObject] = dataManager.getItems()
            
            self.widgetLabel.text = "All: \(itemsAll.count), to do:\(items.count)"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let row: Int = (indexPath as NSIndexPath).row
        
        let tmpCell: TodayTableViewCellSum = tableView.dequeueReusableCell(withIdentifier: "TodayCell") as! TodayTableViewCellSum
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let itemsCount: Int = self.items.count
        
        if(itemsCount > 3) {
            return 3
        } else {
            return itemsCount
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 50.0
        
    }
    
    func updatePreferredContentSize() {
        preferredContentSize = CGSize(width: CGFloat(0), height: CGFloat(tableView(self.itemsTable, numberOfRowsInSection: 0)) * CGFloat(self.itemsTable.rowHeight) + self.itemsTable.sectionFooterHeight + self.widgetLabel.frame.size.height)
    }
    
}
