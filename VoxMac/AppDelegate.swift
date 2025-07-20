//
//  AppDelegate.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Cocoa
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appViewModel: AppViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDefaultShortcut()
        setupKeyboardShortcuts()
    }
    
    private func setupDefaultShortcut() {
        // Set a default shortcut if none exists
        if KeyboardShortcuts.getShortcut(for: .toggleRecording) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.control, .option]), for: .toggleRecording)
        }
    }
    
    func setAppViewModel(_ viewModel: AppViewModel) {
        self.appViewModel = viewModel
    }
    
    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                self?.appViewModel?.handleShortcutPressed()
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}