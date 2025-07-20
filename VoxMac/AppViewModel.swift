//
//  AppViewModel.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI
import Foundation

enum AppStatus {
    case idle
    case recording
    case processing
    case error(message: String)
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var status: AppStatus = .idle
    
    var isRecording: Bool {
        if case .recording = status {
            return true
        }
        return false
    }
    
    var statusIcon: String {
        switch status {
        case .idle:
            return "mic.slash"
        case .recording:
            return "mic.fill"
        case .processing:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    var statusText: String {
        switch status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    func handleShortcutPressed() {
        print("Shortcut pressed - Current status: \(status)")
        
        switch status {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .processing:
            break
        case .error:
            status = .idle
        }
    }
    
    private func startRecording() {
        print("Recording started")
        status = .recording
    }
    
    private func stopRecording() {
        print("Recording stopped")
        status = .processing
        
        Task {
            try await Task.sleep(for: .seconds(2))
            status = .idle
        }
    }
}