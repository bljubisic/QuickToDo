//
//  AppDelegate.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/10/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CoreData
import CloudKit
import SwiftUI

//@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
//        // Override point for customization after application launch.
//        window = UIWindow(frame: UIScreen.main.bounds)
//        let coreData = CoreDataModel()
//        let cloudKit = CloudKitModel()
//        let model = QuickToDoModel(coreData, cloudKit)
//
//
//        let viewController: MainViewController = MainViewController()
//        viewController.insert(withModel: model)
//        window?.rootViewController = viewController
//        window?.makeKeyAndVisible()
//        return true
//    }
    
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        
        guard cloudKitShareMetadata.containerIdentifier == Config.containerIdentifier else {
            print("Shared container identifier \(cloudKitShareMetadata.containerIdentifier) did not match known identifier.")
            return
        }
        let container = CKContainer(identifier: Config.containerIdentifier)
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        
        window = UIWindow(frame: UIScreen.main.bounds)
        let coreData = CoreDataModel()
        let cloudKit = CloudKitModel()
        let model = QuickToDoModel(coreData, cloudKit)

        
        let viewController: MainViewController = MainViewController()
        viewController.insert(withModel: model)
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        
        acceptSharesOperation.perShareResultBlock = {metadata, result in
            let shareRecordType = metadata.share.recordType

            switch result {
            case .failure(let error):
                debugPrint("Error accepting share: \(error)")

            case .success:
                debugPrint("Accepted CloudKit share with type: \(shareRecordType)")
            }
        }
        
        acceptSharesOperation.acceptSharesResultBlock = { result in
            if case .failure(let error) = result {
                debugPrint("Error accepting CloudKit Share: \(error)")
            }
        }
        
        acceptSharesOperation.qualityOfService = .utility
        container.add(acceptSharesOperation)
        
//        acceptSharesOperation.perShareResultBlock = {
//            metadata, share, error in
//            if error != nil {
//                print(error?.localizedDescription ?? "")
//            } else {
//
//                let operation = CKFetchRecordsOperation(
//                    recordIDs: [cloudKitShareMetadata.rootRecordID])
//
//                operation.perRecordCompletionBlock = { record, _, error in
//
//                    if error != nil {
//                        print(error?.localizedDescription ?? "")
//                    }
//
//                    if let shareRecord = record {
//                        DispatchQueue.main.async() {
//                            // Shared record successfully fetched. Update user
//                            // interface here to present to user.
//                            print("Shared record successfully fetched")
//                            let tempItem = Item(name: shareRecord.string(String(describing: ItemFields.name))!,
//                                                count: shareRecord.int(String(describing: ItemFields.count))!,
//                                                uploadedToICloud: true,
//                                                done: (shareRecord.int(String(describing: ItemFields.done))! == 1) ? true : false,
//                                                shown: (shareRecord.int(String(describing: ItemFields.used))! == 1) ? true : false,
//                                                createdAt: shareRecord.creationDate!,
//                                                lastUsedAt: shareRecord.modificationDate!)
//                            _ = model.add(tempItem, addToCloud: false)
//                            _ = cloudKit.inputs.getSharedItems(for: shareRecord, with: {(item) in
//                                _ = model.add(item, addToCloud: false);
//                            })
//                        }
//
//                    }
//                }
//
//                operation.fetchRecordsCompletionBlock = { (recordsWithRecordIDs,error) in
//                    if error != nil {
//                        print(error?.localizedDescription ?? "")
//                    }else {
//                        if let recordsWithRecordIDs = recordsWithRecordIDs {
//                            print("Count \(recordsWithRecordIDs.count)")
//                        }
//                    }
//                }
//                CKContainer.default().sharedCloudDatabase.add(operation)
//            }
//        }
//
//        CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
//            .add(acceptSharesOperation)
    }
    
    func showAlertInvitationOnMainViewController(record: CKRecord) {
        
    }
    
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        saveContext()
    }
    
    var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "QuickToDo")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
}

@main
struct AppyApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                let coreData = CoreDataModel()
                let cloudKit = CloudKitModel()
                let model = QuickToDoModel(coreData, cloudKit)
                let viewModel = QuickToDoViewModel(model)
                MainView(viewModel: viewModel)
            }
        }
    }
}

