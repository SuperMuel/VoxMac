//
//  ErrorHandler.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import Network

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    private let notificationManager = NotificationManager.shared
    private let networkMonitor = NWPathMonitor()
    
    @Published var isNetworkAvailable = true
    
    private init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = (path.status == .satisfied)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    func handleRecordingError(_ error: Error) {
        print("Recording error: \(error)")
        notificationManager.showRecordingError(error)
    }
    
    func handleTranscriptionError(_ error: Error, audioURL: URL? = nil) async {
        print("Transcription error: \(error)")
        
        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .networkError:
                if !isNetworkAvailable {
                    notificationManager.showError(
                        title: "No Internet Connection",
                        message: "Please check your internet connection and try again"
                    )
                } else if let audioURL = audioURL {
                    await attemptRetry(audioURL: audioURL)
                } else {
                    notificationManager.showTranscriptionError(error)
                }
            case .invalidAPIKey:
                let selectedService = KeychainManager.load(key: .transcriptionService) ?? "openai"
                let serviceName = selectedService == "openai" ? "OpenAI" : "Mistral"
                notificationManager.showError(
                    title: "Invalid API Key",
                    message: "Please check your \(serviceName) API key in Settings"
                )
            case .noInternetConnection:
                notificationManager.showError(
                    title: "No Internet Connection",
                    message: "Please check your internet connection and try again"
                )
            case .fileTooLarge:
                notificationManager.showError(
                    title: "File Too Large",
                    message: error.localizedDescription
                )
            case .rateLimitExceeded:
                notificationManager.showError(
                    title: "Rate Limit Exceeded",
                    message: "Too many requests. Please wait a moment and try again"
                )
            case .serverError:
                if let audioURL = audioURL {
                    await attemptRetry(audioURL: audioURL)
                } else {
                    let selectedService = KeychainManager.load(key: .transcriptionService) ?? "openai"
                    let serviceName = selectedService == "openai" ? "OpenAI" : "Mistral"
                    notificationManager.showError(
                        title: "Server Error",
                        message: "\(serviceName) service is temporarily unavailable. Please try again later"
                    )
                }
            default:
                notificationManager.showTranscriptionError(error)
            }
        } else {
            notificationManager.showTranscriptionError(error)
        }
    }
    
    private func attemptRetry(audioURL: URL, attempt: Int = 1) async {
        let maxRetries = 3
        
        guard attempt <= maxRetries else {
            notificationManager.showError(
                title: "Transcription Failed",
                message: "Failed after \(maxRetries) attempts. Please try again later."
            )
            return
        }
        
        // Wait before retrying (exponential backoff)
        let delay = Double(attempt * 2)
        try? await Task.sleep(for: .seconds(delay))
        
        // Check network status before retry
        guard isNetworkAvailable else {
            notificationManager.showError(
                title: "No Internet Connection",
                message: "Please check your internet connection"
            )
            return
        }
        
        notificationManager.showWarning(
            title: "Retrying Transcription",
            message: "Attempt \(attempt) of \(maxRetries)..."
        )
        
        do {
            let transcriptionService = createTranscriptionService()
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            
            // Success - insert text and save to history
            _ = TextInsertionManager.insertText(transcribedText)
            HistoryManager.shared.saveTranscription(text: transcribedText, provider: transcriptionService.provider, model: transcriptionService.model)
            
            notificationManager.showSuccess(
                title: "Transcription Complete",
                message: "Successfully transcribed after \(attempt) attempt(s)"
            )
            
        } catch {
            await handleTranscriptionError(error, audioURL: audioURL)
        }
    }
    
    private func createTranscriptionService() -> TranscriptionService {
        let selectedService = KeychainManager.load(key: .transcriptionService) ?? "openai"
        
        switch selectedService {
        case "mistral":
            if let apiKey = KeychainManager.load(key: .mistralAPIKey), !apiKey.isEmpty {
                return MistralTranscriptionService(apiKey: apiKey)
            } else {
                return MockTranscriptionService()
            }
        case "openai":
            if let apiKey = KeychainManager.load(key: .openAIAPIKey), !apiKey.isEmpty {
                return OpenAITranscriptionService(apiKey: apiKey)
            } else {
                return MockTranscriptionService()
            }
        default:
            return MockTranscriptionService()
        }
    }
    
    func handlePermissionError(permission: String) {
        notificationManager.showPermissionRequired(permission: permission)
    }
    
    func validateNetworkConnectivity() -> Bool {
        return isNetworkAvailable
    }
}