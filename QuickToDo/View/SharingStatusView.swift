//
//  SharingStatusView.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 02.11.25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//

import SwiftUI
import CloudKit

struct SharingStatusView: View {
    @Binding var activeShare: CKShare?
    @Binding var isSharing: Bool
    
    var body: some View {
        if activeShare != nil {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("List is shared with others")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Manage Share") {
                    isSharing = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}

#Preview {
    @Previewable @State var hasActiveShare: Bool = true
    @Previewable @State var isSharing: Bool = false
    
    VStack(spacing: 20) {
        // Simulate shared state by using a mock CKShare (we'll use nil and show manually)
        if hasActiveShare {
            // Manual recreation of the shared state UI for preview
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("List is shared with others")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Manage Share") {
                    isSharing = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        
        // Show the actual component with no active share
        SharingStatusView(activeShare: .constant(nil), isSharing: $isSharing)
        
        Button("Toggle Share State") {
            hasActiveShare.toggle()
        }
    }
    .padding()
}