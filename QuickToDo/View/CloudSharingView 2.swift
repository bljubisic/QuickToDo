//
//  CloudSharingView.swift
//  QuickToDo
//
//  Created for CloudKit sharing support
//

import SwiftUI
import CloudKit
import UIKit

/// A UIViewControllerRepresentable that wraps UICloudSharingController for sharing CloudKit records
struct CloudSharingView: UIViewControllerRepresentable {
    let container: CKContainer
    let share: CKShare
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error.localizedDescription)")
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "QuickToDo List"
        }
        
        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            // Return thumbnail data if needed
            return nil
        }
        
        func itemType(for csc: UICloudSharingController) -> String? {
            return "QuickToDo Shared List"
        }
    }
}
