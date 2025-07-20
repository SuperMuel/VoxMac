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
    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?
    private let errorHandler = ErrorHandler.shared
    private let notificationManager = NotificationManager.shared
    private var isCleaningUp = false
    
    init() {
        // No longer store transcription service as instance variable
        // It will be created fresh for each transcription
    }
    
    private static func createTranscriptionService() throws -> TranscriptionService {
        let selectedService = UserDefaultsManager.shared.transcriptionService
        
        switch selectedService {
        case "mistral":
            guard let apiKey = KeychainManager.load(key: .mistralAPIKey), !apiKey.isEmpty else {
                throw TranscriptionError.invalidAPIKey
            }
            return MistralTranscriptionService(apiKey: apiKey)
        case "openai":
            guard let apiKey = KeychainManager.load(key: .openAIAPIKey), !apiKey.isEmpty else {
                throw TranscriptionError.invalidAPIKey
            }
            return OpenAITranscriptionService(apiKey: apiKey)
        default:
            throw TranscriptionError.invalidAPIKey
        }
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
        guard !isCleaningUp else {
            print("Ignoring shortcut - app is cleaning up")
            return
        }
        
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
        
        // Check network connectivity for transcription services
        if !errorHandler.validateNetworkConnectivity() {
            notificationManager.showWarning(
                title: "No Internet Connection",
                message: "Recording will work, but transcription requires internet"
            )
        }
        
        status = .recording
        recordingStartTime = Date()
        
        do {
            currentRecordingURL = try await audioRecorder.startRecording()
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            status = .error(message: error.localizedDescription)
            recordingStartTime = nil
            errorHandler.handleRecordingError(error)
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
        guard !isCleaningUp else {
            print("Skipping transcription - app is cleaning up")
            return
        }
        
        do {
            // Create transcription service dynamically to pick up current settings
            let transcriptionService = try Self.createTranscriptionService()
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            print("Transcription completed: \(transcribedText)")
            
            // Check again after async operation
            guard !isCleaningUp else {
                print("Skipping text insertion - app is cleaning up")
                return
            }
            
            // Calculate recording duration
            let duration: TimeInterval?
            if let startTime = recordingStartTime {
                duration = Date().timeIntervalSince(startTime)
                recordingStartTime = nil
            } else {
                duration = nil
            }
            
            // Insert text into active application
            let selectedInsertionMethod = InsertionMethod(rawValue: UserDefaultsManager.shared.insertionMethod) ?? .autoInsert
            let insertionResult = TextInsertionManager.insertText(transcribedText, method: selectedInsertionMethod)
            
            // Save transcription to history with provider/model info
            HistoryManager.shared.saveTranscription(text: transcribedText, duration: duration, provider: transcriptionService.provider, model: transcriptionService.model)
            
            // Show success notification
            notificationManager.showTranscriptionComplete(transcribedText, insertedVia: insertionResult)
            
            status = .idle
        } catch {
            guard !isCleaningUp else {
                print("Skipping error handling - app is cleaning up")
                return
            }
            
            print("Transcription failed: \(error)")
            status = .error(message: error.localizedDescription)
            recordingStartTime = nil
            await errorHandler.handleTranscriptionError(error, audioURL: audioURL)
        }
    }
    
    func cleanup() {
        isCleaningUp = true
        // Stop any ongoing recording
        if case .recording = status {
            _ = audioRecorder.stopRecording()
        }
        status = .idle
    }
}