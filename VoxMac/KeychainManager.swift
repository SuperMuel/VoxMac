//
//  KeychainManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import Security

enum InsertionMethod: String, CaseIterable {
    case autoInsert = "auto_insert"
    case clipboardOnly = "clipboard_only"
    
    var displayName: String {
        switch self {
        case .autoInsert:
            return "Auto-insert text"
        case .clipboardOnly:
            return "Copy to clipboard only"
        }
    }
    
    var description: String {
        switch self {
        case .autoInsert:
            return "Automatically insert transcribed text at cursor position"
        case .clipboardOnly:
            return "Copy transcribed text to clipboard for manual pasting"
        }
    }
}

class KeychainManager {
    private static let service = "com.voxmac.app"
    
    enum Key: String {
        case openAIAPIKey = "openai_api_key"
        case mistralAPIKey = "mistral_api_key"
        case transcriptionService = "transcription_service"
        case insertionMethod = "insertion_method"
    }
    
    static func save(_ value: String, for key: Key) -> Bool {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func load(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    static func delete(key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    static func getInsertionMethod() -> InsertionMethod {
        guard let value = load(key: .insertionMethod),
              let method = InsertionMethod(rawValue: value) else {
            return .autoInsert // Default to auto-insert
        }
        return method
    }
    
    static func setInsertionMethod(_ method: InsertionMethod) -> Bool {
        return save(method.rawValue, for: .insertionMethod)
    }
}