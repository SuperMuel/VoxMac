//
//  MenuBarView.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status section
            HStack {
                Image(systemName: appViewModel.statusIcon)
                    .foregroundColor(statusColor)
                Text(appViewModel.statusText)
                    .font(.headline)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Recording shortcut info
            VStack(alignment: .leading, spacing: 4) {
                Text("Recording Shortcut:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Current: ")
                        .font(.caption)
                    if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
                        Text("\(shortcut)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    } else {
                        Text("Not set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Button("Set Shortcut...") {
                    // This will open settings when implemented
                    print("Set shortcut clicked")
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Menu items
            Button("Settings...") {
                // TODO: Open settings window
                print("Settings clicked")
            }
            
            Button("Quit VoxMac") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 8)
        .frame(minWidth: 200)
    }
    
    private var statusColor: Color {
        switch appViewModel.status {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .error:
            return .red
        }
    }
}