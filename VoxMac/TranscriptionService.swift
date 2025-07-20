//
//  TranscriptionService.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation

protocol TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String
}

class OpenAITranscriptionService: TranscriptionService {
    private let apiKey: String
    private let apiURL = "https://api.openai.com/v1/audio/transcriptions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        print("Starting OpenAI transcription for: \(audioURL.path)")
        
        // For now, return a mock response to test the flow
        // We'll implement the real API call in Phase 3
        try await Task.sleep(for: .seconds(2))
        return "This is a mock transcription from OpenAI Whisper API. The audio file was processed successfully."
    }
}

class MockTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        try await Task.sleep(for: .seconds(1))
        return "Mock transcription: Hello, this is a test transcription from the mock service."
    }
}

enum TranscriptionError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case audioFileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from transcription service"
        case .audioFileNotFound:
            return "Audio file not found"
        }
    }
}