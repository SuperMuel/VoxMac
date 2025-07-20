//
//  TranscriptionService.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation

struct OpenAITranscriptionResponse: Codable {
    let text: String
}

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
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        // Check file size (OpenAI has a 25MB limit)
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0
        let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB
        guard fileSize <= maxFileSize else {
            throw TranscriptionError.fileTooLarge(fileSize, maxFileSize)
        }
        
        let url = URL(string: apiURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createMultipartBody(boundary: boundary, audioURL: audioURL)
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let transcriptionResponse = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
                print("OpenAI transcription completed: \(transcriptionResponse.text)")
                return transcriptionResponse.text
            case 401:
                throw TranscriptionError.invalidAPIKey
            case 413:
                throw TranscriptionError.fileTooLarge(fileSize, maxFileSize)
            case 429:
                throw TranscriptionError.rateLimitExceeded
            case 500...599:
                throw TranscriptionError.serverError(httpResponse.statusCode)
            default:
                throw TranscriptionError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
        } catch let error as TranscriptionError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw TranscriptionError.noInternetConnection
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
    
    private func createMultipartBody(boundary: String, audioURL: URL) -> Data {
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        if let audioData = try? Data(contentsOf: audioURL) {
            body.append(audioData)
        }
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
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
    case fileTooLarge(Int64, Int64)
    case rateLimitExceeded
    case serverError(Int)
    case noInternetConnection
    
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
        case .fileTooLarge(let size, let maxSize):
            let sizeMB = Double(size) / (1024 * 1024)
            let maxSizeMB = Double(maxSize) / (1024 * 1024)
            return "Audio file too large (\(String(format: "%.1f", sizeMB))MB). Maximum size is \(String(format: "%.0f", maxSizeMB))MB"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .serverError(let code):
            return "Server error (code \(code)). Please try again later"
        case .noInternetConnection:
            return "No internet connection available"
        }
    }
}