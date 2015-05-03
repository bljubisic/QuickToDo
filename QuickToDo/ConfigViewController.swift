//
//  ConfigViewController.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 3/15/15.
//  Copyright (c) 2015 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CloudKit

class ConfigViewController: UIViewController {

    @IBOutlet weak var iCloudEmail: UITextField!
    @IBOutlet weak var iCloudId: UILabel!
    @IBOutlet weak var iCloudName: UILabel!
    @IBOutlet weak var iCloudLastname: UILabel!
    @IBOutlet weak var sendInvitationButton: UIButton!
    @IBOutlet weak var shareSwitch: UISwitch!
    @IBOutlet weak var findView: UIView!
    
    var iCloudIdVar: String = String()
    var myICloudVar: String = String()
    var shareSwitchVar: Bool = false
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configManager.readConfigPlist()
        
        if (configManager.sharingEnabled == 1) {
            shareSwitchVar = true
        }
        else {
            shareSwitchVar = false
        }
        
        shareSwitch.setOn(shareSwitchVar, animated: true)
        
        // find self recordId
        
        var container: CKContainer = CKContainer.defaultContainer()
        container.fetchUserRecordIDWithCompletionHandler({ (recordId: CKRecordID!, error: NSError!) -> Void in
            self.myICloudVar = recordId.recordName
            self.configManager.selfRecordId = recordId.recordName
            
        })

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changeShareSwitch(sender: AnyObject) {
        
        if(shareSwitchVar) {
            self.findView.alpha = 1.0
            findView.hidden = true
            UIView.animateWithDuration(0.25, animations: {
                self.findView.alpha = 0.0
                }, completion: {
                    (value: Bool) in
                    println(">>> Animation done.")
            })
            shareSwitchVar = false
        }
        else {
            
            
            
            self.findView.alpha = 0.0
            findView.hidden = false
            UIView.animateWithDuration(0.25, animations: {
                self.findView.alpha = 1.0
                }, completion: {
                    (value: Bool) in
                    println(">>> Animation done.")
            })
            shareSwitchVar = true
        }
        
        
    }
    
    
    @IBAction func sendInvitation(sender: AnyObject) {
        
        
        
        if(self.iCloudIdVar != "") {
            dataManager.inviteToShare(self.iCloudIdVar)
            dataManager.subscribeOnResponse()
            
        }
        if(shareSwitchVar) {
            configManager.plistItems.setValue(1, forKey: "sharingEnabled")
            configManager.sharingEnabled = 1
            dataManager.shareEverythingForRecordId(self.myICloudVar)
            dataManager.subscribeOnItems(self.myICloudVar)
        }
        else {
            configManager.plistItems.setValue(0, forKey: "sharingEnabled")
            configManager.sharingEnabled = 0
            dataManager.ckRemoveAllRecords(self.myICloudVar)
        }
        configManager.writeConfigPlist()
        configManager.writeKeyStore()
        //dataManager.shareEverythingForRecordId(self.myICloudVar)
            
        
        
        
    }
    
    @IBAction func findICloudContact(sender: AnyObject) {
        
        var iCloudName: String = iCloudEmail.text
        var container: CKContainer = CKContainer.defaultContainer()
        
        var spinner: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        
        iCloudEmail.leftView = spinner
        spinner.startAnimating()

        container.discoverUserInfoWithEmailAddress(iCloudName, completionHandler:{ (userInfo: CKDiscoveredUserInfo!, error: NSError!) -> Void in
            
            self.iCloudId.text = userInfo.userRecordID.recordName
            self.iCloudIdVar = userInfo.userRecordID.recordName
            self.iCloudName.text = userInfo.firstName
            self.iCloudLastname.text = userInfo.lastName
            spinner.stopAnimating()
            self.iCloudEmail.leftView = nil
            
            self.sendInvitationButton.enabled = true
            
        })
        
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
