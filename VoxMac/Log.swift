//
//  Log.swift
//  VoxMac
//
//  Centralized logging utilities using Apple's Unified Logging (os.Logger).
//

import Foundation
import OSLog

enum LogCategory: String {
    case app
    case audio
    case transcription
    case history
    case database
    case permissions
    case notifications
    case ui
    case insertion
    case network
    case keychain
}

enum Log {
    private static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.voxmac.app"

    private static func logger(_ category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    // MARK: - Convenience APIs
    static func debug(_ message: String, category: LogCategory = .app) {
        logger(category).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: LogCategory = .app) {
        logger(category).info("\(message, privacy: .public)")
    }

    static func notice(_ message: String, category: LogCategory = .app) {
        logger(category).notice("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: LogCategory = .app) {
        logger(category).error("\(message, privacy: .public)")
    }

    static func fault(_ message: String, category: LogCategory = .app) {
        logger(category).fault("\(message, privacy: .public)")
    }

    static func error(_ error: Error, context: String? = nil, category: LogCategory = .app) {
        if let context = context {
            logger(category).error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger(category).error("\(error.localizedDescription, privacy: .public)")
        }
    }
}

