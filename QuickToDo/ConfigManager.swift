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
    var keyStore: NSUbiquitousKeyValueStore = NSUbiquitousKeyValueStore.defaultStore()
    
    var plistItems: NSMutableDictionary = NSMutableDictionary()
    
    
    class var sharedInstance: ConfigManager {
        
        
        return sharedInstanceConfigManager
    }
    
    override init() {
        
        
    }
    
    func readKeyStore() -> [String: Int] {
        
        sharingEnabled = keyStore.objectForKey("sharingEnabled") as! Int
        selfRecordId = String()
        
        if(keyStore.objectForKey("selfRecordId") != nil) {
            selfRecordId = keyStore.objectForKey("selfRecordId") as! String
        }
        
        
        //(keyStore.objectForKey("selfRecordId")) ? (keyStore.objectForKey("selfRecordId") as! String) : :
        
        var tmpDict: [String: Int] = ["sharingEnabled": sharingEnabled]
        return tmpDict
        
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
        let path = documentsDirectory.stringByAppendingPathComponent("Config.plist")
        let fileManager = NSFileManager.defaultManager()
        //check if file exists
        if(!fileManager.fileExistsAtPath(path)) {
            // If it doesn't, copy it from the default file in the Bundle
            if let bundlePath = NSBundle.mainBundle().pathForResource("Config", ofType: "plist") {
                let resultDictionary = NSMutableDictionary(contentsOfFile: bundlePath)
                println("Bundle Config.plist file is --> \(resultDictionary?.description)")
                fileManager.copyItemAtPath(bundlePath, toPath: path, error: nil)
                println("copy")
            } else {
                println("Config.plist not found. Please, make sure it is part of the bundle.")
            }
        } else {
            println("Config.plist already exits at path.")
            // use this to delete file from documents directory
            //fileManager.removeItemAtPath(path, error: nil)
        }
        let resultDictionary = NSMutableDictionary(contentsOfFile: path)
        println("Loaded Config.plist file is --> \(resultDictionary?.description)")
        var myDict = NSMutableDictionary(contentsOfFile: path)
        plistItems = myDict!
        
        if let dict = myDict {
            //loading values
            sharingEnabled = dict.objectForKey("sharingEnabled")! as! Int
            
            selfRecordId = String()
            
            if(dict.objectForKey("selfRecordId") != nil) {
                selfRecordId = dict.objectForKey("selfRecordId") as! String
            }
                
                //dict.objectForKey("selfRecordId")! as! String
            
            //sharingList = (dict["sharingList"] as? [String])!
            //...
        } else {
            println("WARNING: Couldn't create dictionary from GameData.plist! Default values will be used!")
        }
        
    }
    
    func writeConfigPlist() {
        
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true) as NSArray
        let documentsDirectory = paths.objectAtIndex(0) as! NSString
        let path = documentsDirectory.stringByAppendingPathComponent("Config.plist")
        var dict: NSMutableDictionary = ["XInitializerItem": "DoNotEverChangeMe"]
        //saving values
        dict.setObject(sharingEnabled, forKey: "sharingEnabled")
        dict.setObject(self.selfRecordId, forKey: "selfRecordId")
        
        //dict.setObject(bedroomWallID, forKey: BedroomWallKey)
        //...
        //writing to GameData.plist
        dict.writeToFile(path, atomically: false)
        let resultDictionary = NSMutableDictionary(contentsOfFile: path)
        println("Saved Config.plist file is --> \(resultDictionary?.description)")

        
    }
    
    
}