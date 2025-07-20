//
//  PermissionsManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import AVFoundation
import ApplicationServices
import AppKit

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var accessibilityStatus: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted
        
        var isGranted: Bool {
            return self == .granted
        }
        
        var displayText: String {
            switch self {
            case .notDetermined:
                return "Not Requested"
            case .granted:
                return "Granted"
            case .denied:
                return "Denied"
            case .restricted:
                return "Restricted"
            }
        }
        
        var displayColor: NSColor {
            switch self {
            case .notDetermined:
                return .systemOrange
            case .granted:
                return .systemGreen
            case .denied, .restricted:
                return .systemRed
            }
        }
    }
    
    private init() {
        refreshPermissionStatuses()
    }
    
    func refreshPermissionStatuses() {
        microphoneStatus = getMicrophonePermissionStatus()
        accessibilityStatus = getAccessibilityPermissionStatus()
    }
    
    var allPermissionsGranted: Bool {
        return microphoneStatus.isGranted && accessibilityStatus.isGranted
    }
    
    var hasRequestedAnyPermissions: Bool {
        return microphoneStatus != .notDetermined || accessibilityStatus != .notDetermined
    }
    
    // MARK: - Microphone Permission
    
    private func getMicrophonePermissionStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                DispatchQueue.main.async {
                    self.microphoneStatus = .granted
                }
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        self.microphoneStatus = granted ? .granted : .denied
                    }
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.microphoneStatus = self.getMicrophonePermissionStatus()
                }
                continuation.resume(returning: false)
            @unknown default:
                DispatchQueue.main.async {
                    self.microphoneStatus = .notDetermined
                }
                continuation.resume(returning: false)
            }
        }
    }
    
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Accessibility Permission
    
    private func getAccessibilityPermissionStatus() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        // On macOS, accessibility permissions are either granted or denied
        // There's no "not determined" state for accessibility
        return isTrusted ? .granted : .denied
    }
    
    func requestAccessibilityPermission() {
        // This will prompt the user if they haven't been asked before
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        accessibilityStatus = isTrusted ? .granted : .denied
        
        // If not trusted, also open System Settings for better UX
        if !isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openAccessibilitySettings()
            }
        }
    }
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - First Launch Detection
    
    func isFirstLaunch() -> Bool {
        let hasLaunchedKey = "VoxMac_HasLaunched"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            return true
        }
        
        return false
    }
    
    func shouldShowOnboarding() -> Bool {
        return isFirstLaunch() || !allPermissionsGranted
    }
}