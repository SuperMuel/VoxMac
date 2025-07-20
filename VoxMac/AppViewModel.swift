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
    
    private let audioRecorder = AudioRecorderManager()
    private let transcriptionService: TranscriptionService
    private var currentRecordingURL: URL?
    
    init(transcriptionService: TranscriptionService = MockTranscriptionService()) {
        self.transcriptionService = transcriptionService
    }
    
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
            Task { await startRecording() }
        case .recording:
            Task { await stopRecording() }
        case .processing:
            break
        case .error:
            status = .idle
        }
    }
    
    private func startRecording() async {
        print("Starting recording...")
        status = .recording
        
        do {
            currentRecordingURL = try await audioRecorder.startRecording()
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            status = .error(message: error.localizedDescription)
        }
    }
    
    private func stopRecording() async {
        print("Stopping recording...")
        status = .processing
        
        guard let recordingURL = audioRecorder.stopRecording() else {
            status = .error(message: "No recording to stop")
            return
        }
        
        await performTranscription(audioURL: recordingURL)
    }
    
    private func performTranscription(audioURL: URL) async {
        do {
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            print("Transcription completed: \(transcribedText)")
            
            TextInsertionManager.insertText(transcribedText)
            
            status = .idle
        } catch {
            print("Transcription failed: \(error)")
            status = .error(message: error.localizedDescription)
        }
    }
}