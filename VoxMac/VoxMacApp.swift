//
//  VoxMacApp.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI

@main
struct VoxMacApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var permissionsManager = PermissionsManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showingOnboarding = false
    
    init() {
        // Setup will happen in applicationDidFinishLaunching
    }
    
    var body: some Scene {
        MenuBarExtra("VoxMac", systemImage: appViewModel.statusIcon) {
            MenuBarView()
                .environmentObject(appViewModel)
                .onAppear {
                    appDelegate.setAppViewModel(appViewModel)
                    checkForOnboarding()
                }
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            SettingsView()
        }
        
        // Onboarding window
        Window("Welcome to VoxMac", id: "onboarding") {
            OnboardingView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
    
    private func checkForOnboarding() {
        if permissionsManager.shouldShowOnboarding() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // Create and show onboarding window manually if Scene doesn't work
                    showOnboardingWindow()
                }
            }
        }
    }
    
    private func showOnboardingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to VoxMac"
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
