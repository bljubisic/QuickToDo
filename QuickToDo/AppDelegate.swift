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

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // SceneDelegate receives CloudKit share invitations
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.noData)
            return
        }
        print("CloudKit database changed - Notification type: \(notification.notificationType)")

        // CloudKitModel finishes this once its sync is done, so iOS keeps the app running until then
        let completion = RemoteSyncCompletion(completionHandler)
        let syncInfo = [RemoteSyncCompletion.userInfoKey: completion]

        switch notification {
        case let databaseNotification as CKDatabaseNotification:
            let name: Notification.Name = databaseNotification.databaseScope == .shared
                ? .cloudKitSharedDataChanged
                : .cloudKitPrivateDataChanged
            NotificationCenter.default.post(name: name, object: notification, userInfo: syncInfo)
        case is CKQueryNotification:
            // Legacy private query subscription - deleted on the next launch
            NotificationCenter.default.post(name: .cloudKitPrivateDataChanged, object: notification, userInfo: syncInfo)
        case is CKRecordZoneNotification:
            NotificationCenter.default.post(name: .cloudKitRecordZoneChanged, object: notification)
            completion.finish(.noData)
        default:
            completion.finish(.noData)
        }

        // iOS allows about 30 seconds. Finish before that even if no sync ran (e.g. the model is not loaded yet).
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            completion.finish(.noData)
        }
    }
}

/// Hands the background-fetch completion handler of a CloudKit push to the code that performs the sync.
/// The handler is called exactly once: when the sync finishes, or by the push handler's fallback timer.
final class RemoteSyncCompletion {
    static let userInfoKey = "RemoteSyncCompletion"

    private let queue = DispatchQueue(label: "com.quicktodo.remote-sync-completion")
    private var handler: ((UIBackgroundFetchResult) -> Void)?

    init(_ handler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.handler = handler
    }

    func finish(_ result: UIBackgroundFetchResult) {
        let pendingHandler: ((UIBackgroundFetchResult) -> Void)? = queue.sync {
            defer { handler = nil }
            return handler
        }
        pendingHandler?(result)
    }

    static func from(_ notification: Notification) -> RemoteSyncCompletion? {
        return notification.userInfo?[userInfoKey] as? RemoteSyncCompletion
    }
}

@main
struct QuickToDoApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var shareManager = CloudKitShareManager.shared
    @StateObject private var viewModel = QuickToDoViewModel(
        QuickToDoModel(SwiftDataModel(), CloudKitModel())
    )

    var body: some Scene {
        WindowGroup {
            NavigationView {
                MainView(viewModel: viewModel)
            }
            .environmentObject(shareManager)
        }
    }
}
