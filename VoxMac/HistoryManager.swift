//
//  HistoryManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import GRDB

@MainActor
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var transcriptions: [TranscriptionRecord] = []
    
    private var dbQueue: DatabaseQueue?
    
    private init() {
        setupDatabase()
        loadTranscriptions()
    }
    
    private func setupDatabase() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsPath.appendingPathComponent("VoxMac.sqlite").path
            
            dbQueue = try DatabaseQueue(path: dbPath)
            
            try dbQueue?.write { db in
                try db.create(table: "transcriptions", ifNotExists: true) { t in
                    t.column("id", .text).primaryKey()
                    t.column("text", .text).notNull()
                    t.column("timestamp", .datetime).notNull()
                    t.column("duration", .double)
                    t.column("provider", .text).notNull()
                    t.column("model", .text).notNull()
                }
            }
            
            Log.info("Database initialized at: \(dbPath)", category: .database)
        } catch {
            Log.error(error, context: "Database setup failed", category: .database)
        }
    }
    
    func saveTranscription(text: String, duration: TimeInterval? = nil, provider: String, model: String) {
        guard let dbQueue = dbQueue else {
            Log.error("Database not available", category: .database)
            return
        }
        
        var record = TranscriptionRecord(text: text, duration: duration, provider: provider, model: model)
        
        do {
            _ = try dbQueue.write { db in
                try record.insert(db)
            }
            
            // Reload from database to ensure consistency
            loadTranscriptions()
            
            // Force UI update
            objectWillChange.send()
            
            Log.info("Transcription saved to history", category: .history)
        } catch {
            Log.error(error, context: "Failed to save transcription", category: .history)
        }
    }
    
    func loadTranscriptions() {
        guard let dbQueue = dbQueue else { return }
        
        do {
            let records = try dbQueue.read { db in
                try TranscriptionRecord.recent(limit: 100).fetchAll(db)
            }
            
            transcriptions = records
            Log.info("Loaded \(records.count) transcriptions from history", category: .history)
        } catch {
            Log.error(error, context: "Failed to load transcriptions", category: .history)
            transcriptions = []
        }
    }
    
    func deleteTranscription(_ record: TranscriptionRecord) {
        guard let dbQueue = dbQueue else { return }
        
        do {
            _ = try dbQueue.write { db in
                try TranscriptionRecord.deleteOne(db, key: record.id)
            }
            
            // Update local array
            transcriptions.removeAll { $0.id == record.id }
            
            Log.info("Transcription deleted from history", category: .history)
        } catch {
            Log.error(error, context: "Failed to delete transcription", category: .history)
        }
    }
    
    func deleteAllTranscriptions() {
        guard let dbQueue = dbQueue else { return }
        
        do {
            _ = try dbQueue.write { db in
                try TranscriptionRecord.deleteAll(db)
            }
            
            transcriptions.removeAll()
            Log.notice("All transcriptions deleted from history", category: .history)
        } catch {
            Log.error(error, context: "Failed to delete all transcriptions", category: .history)
        }
    }
    
    func searchTranscriptions(query: String) -> [TranscriptionRecord] {
        guard !query.isEmpty else { return transcriptions }
        
        return transcriptions.filter { record in
            record.text.localizedCaseInsensitiveContains(query)
        }
    }
}
