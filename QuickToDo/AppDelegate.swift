//
//  AppDelegate.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 10/10/14.
//  Copyright (c) 2014 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CloudKit
import SwiftUI
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        guard cloudKitShareMetadata.containerIdentifier == Config.containerIdentifier else {
            print("Shared container identifier \(cloudKitShareMetadata.containerIdentifier) did not match known identifier.")
            return
        }

        let container = CKContainer(identifier: Config.containerIdentifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])

        operation.perShareResultBlock = { metadata, result in
            let shareRecordType = metadata.share.recordType
            switch result {
            case .failure(let error):
                print("Error accepting share: \(error)")
            case .success:
                print("Accepted CloudKit share with type: \(shareRecordType)")
            }
        }

        operation.acceptSharesResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    NotificationCenter.default.post(name: .refreshSharedItems, object: nil)
                case .failure(let error):
                    print("Error accepting CloudKit Share: \(error)")
                }
            }
        }

        operation.qualityOfService = .utility
        container.add(operation)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            print("CloudKit database changed - Notification type: \(notification.notificationType)")
            
            // Post notification for different types of CloudKit changes
            switch notification.notificationType {
            case .query:
                // Handle query subscription notifications (private database changes)
                NotificationCenter.default.post(name: .cloudKitPrivateDataChanged, object: notification)
            case .database:
                // Handle database subscription notifications (shared database changes)
                NotificationCenter.default.post(name: .cloudKitSharedDataChanged, object: notification)
            case .recordZone:
                // Handle record zone subscription notifications
                NotificationCenter.default.post(name: .cloudKitRecordZoneChanged, object: notification)
            default:
                break
            }
            
            // Also post the generic notification for backward compatibility
            NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
            completionHandler(.newData)
            return
        }
        completionHandler(.noData)
    }
}

@main
struct QuickToDoApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var shareManager = CloudKitShareManager()
    @StateObject private var viewModel = QuickToDoViewModel(
        QuickToDoModel(SwiftDataModel(), CloudKitModel())
    )

    var body: some Scene {
        WindowGroup {
            NavigationView {
                MainView(viewModel: viewModel)
            }
            .environmentObject(shareManager)
            .onOpenURL { url in
                shareManager.handleIncomingURL(url)
            }
        }
    }
}
