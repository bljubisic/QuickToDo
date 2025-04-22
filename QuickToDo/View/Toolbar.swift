//
//  Toolbar.swift
//  QuickToDo
//
//  Created by Bratislav Ljubisic on 16.04.25.
//  Copyright © 2025 Bratislav Ljubisic. All rights reserved.
//
import SwiftUI
import WidgetKit
import CloudKit

struct Toolbar: View {
    
    @Binding var viewModel: QuickToDoViewModel
    @Binding var shown: Bool
    @Binding var isSharing: Bool
    @Binding var activeShare: CKShare?
    @Binding var activeContainer: CKContainer?
    
    
    var body: some View {
        HStack() {
            VStack() {
                Button(action: {
                    _ = self.viewModel.inputs.getItems {
                        print("called getItems")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }, label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .resizable()
                        .frame(width: 20.0, height: 20.0)
                })
                Text("Refresh")
                    .fontWeight(.semibold)
                    .foregroundColor(Color.blue)
                    .font(.system(size: 12,  design: .rounded))
                    .frame(width: 80.0, height: 20.0)
            }
            VStack() {
                Button(action: {
                    Task {
                        _ = viewModel.inputs.prepareSharing(handler: { activityItems, container, error  in
                            activeShare = activityItems
                            activeContainer = container
                            isSharing = true
                        })
                    }
                }, label: {
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .frame(width:20.0, height: 20.0)
                })
                Text("Share")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .font(.system(size: 12, design: .rounded))
                    .frame(width: 80.0, height: 20.0)
            }
            VStack() {
                Button(action: {
                    _ = self.viewModel.inputs.clearList()
                    WidgetCenter.shared.reloadAllTimelines()
                }, label: {
                    Image(systemName: "cart.badge.minus")
                        .resizable()
                        .frame(width: 30.0, height: 20.0)
                })
                Text("Remove all")
                    .fontWeight(.semibold)
                    .foregroundColor(Color.blue)
                    .font(.system(size: 12,  design: .rounded))
                    .frame(width: 80.0, height: 20.0)
            }

            VStack() {
                Button(action: {
                    shown.toggle()
                    _ = self.viewModel.inputs.save(config: shown)
                }, label: {
                    ((shown) ? Image(systemName: "bag") : Image(systemName: "bag.fill"))
                        .resizable()
                        .frame(width: 20.0, height: 20.0)
                })
                ((shown) ? Text("Remove done") : Text("Show done"))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.blue)
                    .font(.system(size: 12,  design: .rounded))
                    .frame(width: 80.0, height: 20.0)
            }

            VStack() {
                Button(action: {
                    _ = self.viewModel.inputs.uploadToCloud()
                }, label: {
                    Image(systemName: "arrow.clockwise.icloud")
                        .resizable()
                        .frame(width: 30.0, height: 20.0)
                })
                Text("Update")
                    .fontWeight(.semibold)
                    .foregroundColor(Color.blue)
                    .font(.system(size: 12,  design: .rounded))
                    .frame(width: 80.0, height: 20.0)
            }

        }
        .padding()
    }
}

#Preview {
    @Previewable @State var show: Bool = false
    @Previewable @State var viewModel: QuickToDoViewModel = QuickToDoViewModel()
    @Previewable @State var isSharing: Bool = false
    @Previewable @State var activeShare: CKShare? = nil
    @Previewable @State var activeContainer: CKContainer? = nil
    
    Toolbar(viewModel: $viewModel, shown: $show, isSharing: $isSharing, activeShare: $activeShare, activeContainer: $activeContainer)
        .padding()
        .background(Color.white)
        .environment(\.colorScheme, .light)
        
}
