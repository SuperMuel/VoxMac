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
    @State private var historyWindow: NSWindow?
    
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
            }
            
            Divider()
            
            // Menu items
            Button("History...") {
                openHistoryWindow()
            }
            
            SettingsLink {
                Text("Settings...")
            }
            
            Button("Quit VoxMac") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 8)
        .frame(minWidth: 200)
    }
    
    private func openHistoryWindow() {
        // Close existing window if open
        historyWindow?.close()
        
        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "VoxMac History"
        window.contentView = NSHostingView(rootView: HistoryView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Keep reference to prevent deallocation
        historyWindow = window
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