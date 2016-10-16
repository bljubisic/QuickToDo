//
//  SignalManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/3/16.
//  Copyright © 2016 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import CloudKit

class CloudKitManager: NSObject {
    
    var ckItemsObservable: Observable<String>!
    var publicDB: CKDatabase!
    var container: CKContainer!
    let configManager: ConfigManager = ConfigManager.sharedInstance
    
    override init() {
        super.init()
        
        container = CKContainer(identifier: "iCloud.QuickToDo")
        publicDB = container.publicCloudDatabase
        
        
    }
    
    
    func getAllSubscribersObservable() -> Observable<String> {
        return Observable.create({observer in
            
            //var tmpRecord: CKRecord = CKRecord(recordType: "Invitations")
            
            //let compoundPredicate: NSCompoundPredicate = NSCompoundPredicate(type: .OrPredicateType, subpredicates: [NSPredicate(format: "receiver = %@", configManager.selfRecordId)])
            
            let predicate = NSPredicate(format:"receiver = %@", self.configManager.selfRecordId)
            
            let query: CKQuery = CKQuery(recordType: "Invitations", predicate: predicate)
        
            self.publicDB.perform(query, inZoneWith: nil, completionHandler: { results, error in
                guard let foundRecords = results, error == nil else {
                    observer.onError(error!)
                    return
                }
                for result in foundRecords {
                    let record: CKRecord = result as CKRecord
                    let name: String = record.object(forKey: "sendername") as! String
                    observer.onNext(name)
                }
            })
        
            return Disposables.create {
                
            }
        })
    }
    
    private func getAllItemsForSubscriberObservable(subscriber: String) -> Observable<CKRecord> {
        return Observable.create({observer in
            let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@ AND used = 1", subscriber)
            
            let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
            
            self.publicDB.perform(query, inZoneWith: nil, completionHandler: { results, error in
                guard let foundRecords = results, error == nil else {
                    observer.onError(error!)
                    return
                }
                for foundRecord in foundRecords {
                    observer.onNext(foundRecord)
                }
                observer.onCompleted()
            })
            return Disposables.create {
                
            }
        })
    }
    
    private func getAllItemsForSelfObservable() -> Observable<CKRecord> {
        return Observable.create({ observer in

            return Disposables.create {
                
            }
        })
        
    }
    
    func getAllItemsObservable(cloudId: String) -> Observable<CKRecord> {
        return Observable.create({ observer in
            let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@ AND used = 1", self.configManager.selfRecordId)
            
            let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
            
            self.publicDB.perform(query, inZoneWith: nil, completionHandler: { results, error in
                guard let foundRecords = results, error == nil else {
                    observer.onError(error!)
                    return
                }
                for foundRecord in foundRecords {
                    observer.onNext(foundRecord)
                }
                observer.onCompleted()
            })
            return Disposables.create {
                
            }
        })

    }

    /*
    private func getAllItems(observer: ObserverOf<CKRecordID>) {
        
        let predicate: NSPredicate = NSPredicate(format: "icloudmail = %@ AND used = 1", self.configManager.selfRecordId)
        
        let query: CKQuery = CKQuery(recordType: "Items", predicate: predicate)
        
        publicDB.perform(query, inZoneWith: nil, completionHandler: { results, error in
            
            guard let foundRecords = results , error == nil else  {
        
            }
            /*
            if(error == nil) {
                let records: [CKRecord] = (results as [CKRecord]?)!
                //var modifiedRecords: [CKRecord] = [CKRecord]()
                
                for record in records {
                    let tmpItem: ItemObject = ItemObject()
                    
                    tmpItem.word = record.object(forKey: "name") as! String as NSString
                    tmpItem.completed = record.object(forKey: "completed") as! Int
                    tmpItem.used = record.object(forKey: "used") as! Int
                    
                    result[tmpItem.word as String] = tmpItem
                    
                }
                let localItems = self.getItems()
                for itemKey in localItems.keys {
                    result.removeValue(forKey: itemKey)
                    
                }
                
                self.ckReceivedItems(result, completion: completion)
            }
            */
            
        } )
        
    }
    */
    

}
