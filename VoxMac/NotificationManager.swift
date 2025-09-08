//
//  NotificationManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Log.error(error, context: "Notification permission error", category: .notifications)
            }
            Log.info("Notification permission granted: \(granted)", category: .notifications)
            
            // Even if permission is denied, we can still show notifications
            // They just won't appear as system notifications, but we can log them
            if !granted {
                Log.notice("Notifications not permitted - using console logging fallback", category: .notifications)
            }
        }
    }
    
    func showSuccess(title: String, message: String) {
        showNotification(title: title, message: message, type: .success)
    }
    
    func showError(title: String, message: String) {
        showNotification(title: title, message: message, type: .error)
    }
    
    func showWarning(title: String, message: String) {
        showNotification(title: title, message: message, type: .warning)
    }
    
    func showTranscriptionComplete(_ text: String, insertedVia method: String) {
        let preview = text.count > 50 ? String(text.prefix(50)) + "..." : text
        
        let (title, message) = getNotificationContent(for: method, text: preview)
        showSuccess(title: title, message: message)
    }
    
    private func getNotificationContent(for method: String, text: String) -> (title: String, message: String) {
        switch method {
        case "accessibility":
            return ("Transcription Complete", "Text inserted at cursor: \"\(text)\"")
        case "clipboard_only":
            return ("Transcription Complete", "Text copied to clipboard: \"\(text)\"")
        case "clipboard":
            return ("Transcription Complete", "Text pasted via clipboard: \"\(text)\"")
        case "clipboard (accessibility fallback)":
            return ("Transcription Complete", "Text pasted via clipboard (accessibility fallback): \"\(text)\"")
        case "clipboard (no focus)":
            return ("Transcription Complete", "Text pasted via clipboard (no focus detected): \"\(text)\"")
        default:
            return ("Transcription Complete", "Text processed via \(method): \"\(text)\"")
        }
    }
    
    func showRecordingError(_ error: Error) {
        showError(
            title: "Recording Failed",
            message: "Unable to record audio: \(error.localizedDescription)"
        )
    }
    
    func showTranscriptionError(_ error: Error) {
        let message: String
        if let transcriptionError = error as? TranscriptionError {
            switch transcriptionError {
            case .invalidAPIKey:
                message = "Please check your OpenAI API key in Settings"
            case .networkError:
                message = "Check your internet connection and try again"
            case .audioFileNotFound:
                message = "Recording file could not be found"
            case .invalidResponse:
                message = "Unexpected response from transcription service"
            case .fileTooLarge:
                message = transcriptionError.localizedDescription
            case .rateLimitExceeded:
                message = "Too many requests. Please wait and try again"
            case .serverError:
                message = "OpenAI service is temporarily unavailable"
            case .noInternetConnection:
                message = "No internet connection available"
            }
        } else {
            message = error.localizedDescription
        }
        
        showError(
            title: "Transcription Failed",
            message: message
        )
    }
    
    func showPermissionRequired(permission: String) {
        showWarning(
            title: "Permission Required",
            message: "\(permission) permission is needed for VoxMac to work properly"
        )
    }
    
    private func showNotification(title: String, message: String, type: NotificationType) {
        // Always log to unified logger first
        switch type {
        case .success:
            Log.info("\(title): \(message)", category: .notifications)
        case .warning:
            Log.notice("\(title): \(message)", category: .notifications)
        case .error:
            Log.error("\(title): \(message)", category: .notifications)
        }
        
        // Check if notifications are authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                // Fallback: nothing to show, already logged above
                Log.notice("Notification not shown (permission denied)", category: .notifications)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            // Add custom identifier for the notification type
            let identifier = "\(type.rawValue)_\(UUID().uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    Log.error(error, context: "Failed to show notification", category: .notifications)
                }
            }
        }
    }
}

enum NotificationType: String {
    case success = "success"
    case error = "error"
    case warning = "warning"
}
