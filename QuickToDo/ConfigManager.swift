//
//  ConfigManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 3/31/15.
//  Copyright (c) 2015 Bratislav Ljubisic. All rights reserved.
//

import CoreData
import CloudKit

private var sharedInstanceConfigManager: ConfigManager = ConfigManager()


class ConfigManager: NSObject {
    
    var sharingEnabled: Int = 0
    var sharingList: [String] = [String] ()
    var selfRecordId: String = String()
    var selfName: String = String()
    var configDictionary: [String: Int] = [String: Int]()
    
    var keyStore: NSUbiquitousKeyValueStore = NSUbiquitousKeyValueStore.defaultStore()
    
    var plistItems: NSMutableDictionary = NSMutableDictionary()
    
    
    class var sharedInstance: ConfigManager {
        
        
        return sharedInstanceConfigManager
    }
    
    func readKeyStore() {
        
        let container: CKContainer = CKContainer(identifier: "iCloud.QuickToDo")
        
        container.accountStatusWithCompletionHandler({accountStatus, error in
            
            if(accountStatus == CKAccountStatus.Available) {
                if(self.keyStore.objectForKey("sharingEnabled") != nil) {
                    self.sharingEnabled = self.keyStore.objectForKey("sharingEnabled") as! Int
                }
                self.selfRecordId = String()
                do {
                    
                    container.fetchUserRecordIDWithCompletionHandler({ (recordId: CKRecordID?, error: NSError?) -> Void in
                    
                        if let unwrappedRecordId = recordId {
                            self.selfRecordId = unwrappedRecordId.recordName
                            container.discoverUserInfoWithUserRecordID(unwrappedRecordId, completionHandler: { (userInfo: CKDiscoveredUserInfo? , error: NSError? ) -> Void in
                                if let unwrappedUserInfo = userInfo {
                                    self.selfName = unwrappedUserInfo.displayContact!.givenName + " " + unwrappedUserInfo.displayContact!.familyName
                                } else {
                                    self.selfName = "Not Found"
                                }
                            })
                        } else {
                            print("The optional is nil!")
                        }
                        //self.selfRecordId = recordId.recordName
                    
                    })
                }
                
                
                //(keyStore.objectForKey("selfRecordId")) ? (keyStore.objectForKey("selfRecordId") as! String) : :
                
                self.configDictionary = ["sharingEnabled": self.sharingEnabled]
                //return tmpDict
            }
            else {
                self.sharingEnabled = 0
            }
            
        })
        

        
    }
    
    func writeKeyStore() {
        let tmpNum: Int = sharingEnabled
        
        //keyStore.setValue(tmpNum, forKey: "sharingEnabled")
        keyStore.setObject(tmpNum, forKey: "sharingEnabled")
        keyStore.setObject(selfRecordId, forKey: "selfRecordId")
        keyStore.synchronize()
        
    }

    func readConfigPlist() {
        // getting path to GameData.plist
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths[0] as! String
        let path = documentsDirectory.stringByAppendingString("Config.plist")
        let fileManager = NSFileManager.defaultManager()
        //check if file exists
        if(!fileManager.fileExistsAtPath(path)) {
            // If it doesn't, copy it from the default file in the Bundle
            if let bundlePath = NSBundle.mainBundle().pathForResource("Config", ofType: "plist") {
                let resultDictionary = NSMutableDictionary(contentsOfFile: bundlePath)
                print("Bundle Config.plist file is --> \(resultDictionary?.description)")
                do {
                    
                    try fileManager.copyItemAtPath(bundlePath, toPath: path)
                } catch _ {
                    
                }
                print("copy")
            } else {
                print("Config.plist not found. Please, make sure it is part of the bundle.")
            }
        } else {
            print("Config.plist already exits at path.")
            // use this to delete file from documents directory
            //fileManager.removeItemAtPath(path, error: nil)
        }
        let resultDictionary = NSMutableDictionary(contentsOfFile: path)
        print("Loaded Config.plist file is --> \(resultDictionary?.description)")
        let myDict = NSMutableDictionary(contentsOfFile: path)
        //plistItems = myDict!
        
        if let dict = myDict {
            //loading values
            plistItems = dict
            sharingEnabled = dict.objectForKey("sharingEnabled")! as! Int
            
            selfRecordId = String()
            
            if(dict.objectForKey("selfRecordId") != nil) {
                selfRecordId = dict.objectForKey("selfRecordId") as! String
            }
                
                //dict.objectForKey("selfRecordId")! as! String
            
            //sharingList = (dict["sharingList"] as? [String])!
            //...
        } else {
            print("WARNING: Couldn't create dictionary from GameData.plist! Default values will be used!")
        }
        
    }
    
    func writeConfigPlist() {
        
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths.objectAtIndex(0) as! NSString
        let path = documentsDirectory.stringByAppendingPathComponent("Config.plist")
        let dict: NSMutableDictionary = ["XInitializerItem": "DoNotEverChangeMe"]
        //saving values
        dict.setObject(sharingEnabled, forKey: "sharingEnabled")
        dict.setObject(self.selfRecordId, forKey: "selfRecordId")
        
        //dict.setObject(bedroomWallID, forKey: BedroomWallKey)
        //...
        //writing to GameData.plist
        dict.writeToFile(path, atomically: false)
        let resultDictionary = NSMutableDictionary(contentsOfFile: path)
        print("Saved Config.plist file is --> \(resultDictionary?.description)")

        
    }
    
    
}