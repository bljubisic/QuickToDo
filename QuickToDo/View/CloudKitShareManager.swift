//
//  CloudKitShareManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 6/8/25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//

import CloudKit
import Combine

// MARK: - CloudKit Share Manager
class CloudKitShareManager: ObservableObject {
    @Published var pendingShare: CKShare?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var shareAccepted = false

    private let container = CKContainer.default()
    private var shareMetadata: CKShare.Metadata?

    // Handle incoming URL (from share invitation)
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "https" && url.host?.contains("icloud.com") == true else {
            return
        }

        fetchShareMetadata(from: url)
    }

    // Fetch share metadata from URL
    private func fetchShareMetadata(from url: URL) {
        container.fetchShareMetadata(with: url) { [weak self] metadata, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert("Failed to fetch share metadata: \(error.localizedDescription)")
                    return
                }

                guard let metadata = metadata else {
                    self?.showAlert("No share metadata found")
                    return
                }

                self?.shareMetadata = metadata
                self?.pendingShare = metadata.share

                // Automatically accept the share
                self?.acceptShareWithMetadata(metadata)
            }
        }
    }

    // Accept the share using metadata directly
    private func acceptShareWithMetadata(_ metadata: CKShare.Metadata) {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])

        operation.perShareResultBlock = { [weak self] metadata, result in
            DispatchQueue.main.async {
                switch result {
                case .success(let share):
                    print("Successfully accepted share: \(share)")
                    self?.showAlert("Share accepted successfully! Pull to refresh to see shared items.")
                    self?.shareAccepted = true
                case .failure(let error):
                    print("Failed to accept share for metadata \(metadata): \(error)")
                    self?.showAlert("Failed to accept share: \(error.localizedDescription)")
                }
            }
        }

        operation.acceptSharesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.clearPendingShare()
                    // Post notification to refresh shared items
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshSharedItems"), object: nil)
                case .failure(let error):
                    self?.showAlert("Failed to accept share: \(error.localizedDescription)")
                }
            }
        }

        container.add(operation)
    }

    // Accept the share (legacy - kept for compatibility)
    func acceptShare(_ share: CKShare) {
        guard let metadata = shareMetadata else {
            showAlert("No share metadata available")
            return
        }

        acceptShareWithMetadata(metadata)
    }

    // Decline the share
    func declineShare() {
        clearPendingShare()
        showAlert("Share declined")
    }

    // Clear pending share
    private func clearPendingShare() {
        pendingShare = nil
        shareMetadata = nil
    }

    // Show alert with message
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    // Reset share accepted flag
    func resetShareAccepted() {
        shareAccepted = false
    }
}
