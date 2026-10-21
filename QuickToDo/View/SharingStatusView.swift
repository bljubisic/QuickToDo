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
    let isShared: Bool
    let onManageShare: () -> Void

    var body: some View {
        if isShared {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("List is shared with others")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Manage Share", action: onManageShare)
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
    @Previewable @State var isShared: Bool = true

    VStack(spacing: 20) {
        SharingStatusView(isShared: isShared, onManageShare: {})

        Button("Toggle Share State") {
            isShared.toggle()
        }
    }
    .padding()
}
