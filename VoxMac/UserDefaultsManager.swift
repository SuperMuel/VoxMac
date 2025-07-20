import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Keys
    private struct Keys {
        static let transcriptionService = "transcription_service"
        static let insertionMethod = "insertion_method"
    }
    
    // MARK: - Transcription Service
    var transcriptionService: String {
        get {
            return userDefaults.string(forKey: Keys.transcriptionService) ?? "openai"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.transcriptionService)
        }
    }
    
    // MARK: - Text Insertion Method
    var insertionMethod: String {
        get {
            return userDefaults.string(forKey: Keys.insertionMethod) ?? "auto_insert"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.insertionMethod)
        }
    }
}