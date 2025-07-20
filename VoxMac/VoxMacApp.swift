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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Setup will happen in applicationDidFinishLaunching
    }
    
    var body: some Scene {
        MenuBarExtra("VoxMac", systemImage: appViewModel.statusIcon) {
            MenuBarView()
                .environmentObject(appViewModel)
                .onAppear {
                    appDelegate.setAppViewModel(appViewModel)
                }
        }
        .menuBarExtraStyle(.menu)
    }
}
