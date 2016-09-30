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
    @IBOutlet weak var showInviteList: UIView!
    @IBOutlet weak var cancelSubscription: UIButton!
    @IBOutlet weak var nameSubscription: UILabel!
    @IBOutlet weak var receiverSubscription: UILabel!
    
    
    var iCloudIdVar: String = String()
    var myICloudVar: String = String()
    var iCloudNameVar: String = String()
    
    var shareSwitchVar: Bool = false
    let dataManager: QuickToDoDataManager = QuickToDoDataManager.sharedInstance
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configManager.readConfigPlist()
        
        if (configManager.sharingEnabled == 1) {
            shareSwitchVar = true
            self.findView.isHidden = false
            dataManager.cdGetInvitation(showInviteList)
        }
        else {
            shareSwitchVar = false
            self.findView.isHidden = true
        }
        
        shareSwitch.setOn(shareSwitchVar, animated: true)
        
        // find self recordId
        
        
        let container: CKContainer = CKContainer.default()
        
        
        
        container.fetchUserRecordID(completionHandler: { (recordId: CKRecordID?, error: Error?) in
            if let unwrappedRecordId = recordId {
                self.myICloudVar = unwrappedRecordId.recordName
                self.configManager.selfRecordId = unwrappedRecordId.recordName
            } else {
                print("The optional is nil!")
            }
            
            
        })
        

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changeShareSwitch(_ sender: AnyObject) {
        
        if(shareSwitchVar) {
            self.findView.alpha = 1.0
            findView.isHidden = true
            self.showInviteList.isHidden = true
            UIView.animate(withDuration: 0.25, animations: {
                self.findView.alpha = 0.0
                }, completion: {
                    (value: Bool) in
                    print(">>> Animation done.")
            })
            shareSwitchVar = false
        }
        else {
            
            
            
            self.findView.alpha = 0.0
            findView.isHidden = false
            UIView.animate(withDuration: 0.25, animations: {
                self.findView.alpha = 1.0
                }, completion: {
                    (value: Bool) in
                    print(">>> Animation done.")
            })
            shareSwitchVar = true
        }
        
        
    }
    
    
    @IBAction func sendInvitation(_ sender: AnyObject) {
        
        
        
        if(self.iCloudIdVar != "") {
            let invitation = InvitationObject()
            
            invitation.sender = self.myICloudVar
            invitation.receiver = self.iCloudId.text!
            invitation.confirmed = 0
            invitation.sendername = self.configManager.selfName
            invitation.receivername = self.iCloudName.text!
            
            dataManager.cdAddInvitation(invitation)
            
            dataManager.inviteToShare(self.iCloudIdVar, receiverName: self.iCloudNameVar)
            
            dataManager.subscribeOnResponse()
            dataManager.subscribeOnInvitations()
            
        }
        if(shareSwitchVar) {
            configManager.plistItems.setValue(1, forKey: "sharingEnabled")
            configManager.sharingEnabled = 1
            dataManager.shareEverythingForRecordId(self.myICloudVar)
            dataManager.subscribeOnInvitations()
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
            
        self.performSegue(withIdentifier: "unwindFromConfig", sender: self)
        
        
    }
    
    func showNothing(_ : InvitationObject) {
        
    }
    
    func showInviteList(_ invitation: InvitationObject) {
        
        if(invitation.sendername != "") {
            _ = DispatchQueue.GlobalQueuePriority.default
            DispatchQueue.main.async(execute: {
                //self.showInviteList.frame.origin.y = 97
                self.showInviteList.isHidden = false
                self.findView.isHidden = true 
                self.nameSubscription.text = invitation.sendername
                if(invitation.confirmed > 0) {
                    self.cancelSubscription.setImage(UIImage(named: "shareConfirmedButton"), for: UIControlState())
                }
            
            
            })
        } else {
            dataManager.ckFetchInvitations(showInviteListFromCloudKit)
            //self.showInviteList.hidden = true
        }
        
        
        
    }
    
    func showInviteListFromCloudKit(_ sender: String) -> Void {
        
        if(sender != "") {
            _ = DispatchQueue.GlobalQueuePriority.default
            DispatchQueue.main.async(execute: {
                
                self.showInviteList.isHidden = false
                self.findView.isHidden = true
                self.nameSubscription.text = sender

                
                
            })
        } else {
            self.showInviteList.isHidden = true
        }
        
    }
    
    @IBAction func findICloudContact(_ sender: AnyObject) {
        
        let iCloudName: String = iCloudEmail.text!
        let container: CKContainer = CKContainer.default()
        
        let spinner: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        
        iCloudEmail.leftView = spinner
        spinner.startAnimating()

        container.discoverUserInfo(withEmailAddress: iCloudName, completionHandler:{ (userInfo: CKDiscoveredUserInfo?, error: NSError?) -> Void in
            
            if(userInfo != nil) {
                let priority = DispatchQueue.GlobalQueuePriority.default
                DispatchQueue.global(priority: priority).async {
                    // do some task
                    DispatchQueue.main.async {
                        if let tmpUserInfo = userInfo {
                            self.iCloudId.text = tmpUserInfo.userRecordID!.recordName
                            self.iCloudIdVar = tmpUserInfo.userRecordID!.recordName
                            self.iCloudName.text = tmpUserInfo.displayContact?.givenName
                            self.iCloudLastname.text = tmpUserInfo.displayContact?.familyName
                            self.iCloudNameVar = (tmpUserInfo.displayContact?.givenName)! + " " + (tmpUserInfo.displayContact?.familyName)!
                            spinner.stopAnimating()
                            self.iCloudEmail.leftView = nil
                        
                            self.sendInvitationButton.isEnabled = true
                        }
                    }
                }

            }
            else {
                self.iCloudName.text = "Nothing found"
            }
        } as! (CKDiscoveredUserInfo?, Error?) -> Void)
        
        
    }

    @IBAction func cancelSubscriptionAction(_ sender: AnyObject) {
        
        let invitation = dataManager.cdGetInvitationFake()
        
        dataManager.cdRemoveInvitation()
        
        dataManager.ckRemoveInvitation(invitation.sender, receiver: invitation.receiver)
        
        dataManager.ckRemoveInvitationSubscription(invitation.sender, receiver: invitation.receiver)
        
        self.showInviteList.alpha = 1.0
        //findView.hidden = true
        UIView.animate(withDuration: 0.25, animations: {
            self.showInviteList.alpha = 0.0
            }, completion: {
                (value: Bool) in
                print(">>> Animation done.")
        })
        showInviteList.isHidden = true
        
        self.findView.alpha = 0.0
        
        UIView.animate(withDuration: 0.25, animations: {
            self.findView.alpha = 1.0
            }, completion: {
                (value: Bool) in
                print(">>> Animation done.")
        })
        findView.isHidden = false
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
