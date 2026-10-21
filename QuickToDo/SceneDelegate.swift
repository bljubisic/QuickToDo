//
//  SceneDelegate.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 5/15/25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//

import UIKit
import CloudKit

/// With the SwiftUI App lifecycle UIKit delivers CloudKit share invitations to the scene delegate,
/// never to `AppDelegate`. Installed by `AppDelegate.application(_:configurationForConnecting:options:)`.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // App was launched by tapping a share invitation
        if let metadata = connectionOptions.cloudKitShareMetadata {
            CloudKitShareManager.shared.accept(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudKitShareManager.shared.accept(cloudKitShareMetadata)
    }
}
