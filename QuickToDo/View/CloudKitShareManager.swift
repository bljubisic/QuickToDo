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
/// Accepts CloudKit share invitations delivered to `SceneDelegate` and reports the result to the UI.
/// A single shared instance, because an invitation that launches the app arrives
/// before SwiftUI has created any state objects.
final class CloudKitShareManager: ObservableObject {
    static let shared = CloudKitShareManager()

    @Published var showingAlert = false
    @Published var alertMessage = ""

    private init() {}

    func accept(_ metadata: CKShare.Metadata) {
        guard metadata.containerIdentifier == Config.containerIdentifier else {
            print("Shared container identifier \(metadata.containerIdentifier) did not match known identifier.")
            return
        }

        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])

        operation.perShareResultBlock = { [weak self] _, result in
            if case let .failure(error) = result {
                print("Failed to accept share: \(error)")
                self?.showAlert("Failed to accept share: \(error.localizedDescription)")
            }
        }

        operation.acceptSharesResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.showAlert("Shared list added. You can find it in the Shared Items tab.")
                // Sync the shared database (updates its change token) and reload the Shared tab
                NotificationCenter.default.post(name: .cloudKitSharedDataChanged, object: nil)
                NotificationCenter.default.post(name: .refreshSharedItems, object: nil)
            case .failure(let error):
                print("Failed to accept shares: \(error)")
            }
        }

        operation.qualityOfService = .userInitiated
        CKContainer(identifier: Config.containerIdentifier).add(operation)
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            self.alertMessage = message
            self.showingAlert = true
        }
    }
}
