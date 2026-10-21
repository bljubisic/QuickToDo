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
    /// Called after the share was saved (participants or permissions changed)
    var onSaveShare: () -> Void = {}
    /// Called after the owner stopped sharing (or a participant left)
    var onStopSharing: () -> Void = {}

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
        Coordinator(onSaveShare: onSaveShare, onStopSharing: onStopSharing)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let onSaveShare: () -> Void
        private let onStopSharing: () -> Void

        init(onSaveShare: @escaping () -> Void, onStopSharing: @escaping () -> Void) {
            self.onSaveShare = onSaveShare
            self.onStopSharing = onStopSharing
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error.localizedDescription)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onSaveShare()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStopSharing()
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
