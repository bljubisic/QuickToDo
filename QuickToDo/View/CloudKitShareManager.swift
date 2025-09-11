//
//  CloudKitShareManager.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic Home  on 6/8/25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//

import CloudKit

// MARK: - CloudKit Share Manager
class CloudKitShareManager: ObservableObject {
    @Published var pendingShare: CKShare?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
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
            }
        }
    }
    
    // Accept the share
    func acceptShare(_ share: CKShare) {
        guard let metadata = shareMetadata else {
            showAlert("No share metadata available")
            return
        }
        
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        
        operation.acceptSharesResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showAlert("Share accepted successfully!")
                    self?.clearPendingShare()
                case .failure(let error):
                    self?.showAlert("Failed to accept share: \(error.localizedDescription)")
                }
            }
        }
        
        operation.perShareResultBlock = { metadata, result in
            switch result {
            case .success(let share):
                print("Successfully accepted share: \(share)")
            case .failure(let error):
                print("Failed to accept share for metadata \(metadata): \(error)")
            }
        }
        
        container.add(operation)
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
    
    // Simulate incoming share for demo purposes
    func simulateIncomingShare() {
        // Create a mock share for demonstration
        let recordZone = CKRecordZone(zoneName: "SharedZone")
        let share = CKShare(recordZoneID: recordZone.zoneID)
        
        // In a real app, this would come from an actual CloudKit share URL
        pendingShare = share
        showAlert("Simulated share invitation received!")
    }
}
