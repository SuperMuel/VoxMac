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
                }
            }
            
            print("✅ Database initialized at: \(dbPath)")
        } catch {
            print("❌ Database setup failed: \(error)")
        }
    }
    
    func saveTranscription(text: String, duration: TimeInterval? = nil) {
        guard let dbQueue = dbQueue else {
            print("❌ Database not available")
            return
        }
        
        var record = TranscriptionRecord(text: text, duration: duration)
        
        do {
            _ = try dbQueue.write { db in
                try record.insert(db)
            }
            
            // Reload from database to ensure consistency
            loadTranscriptions()
            
            // Force UI update
            objectWillChange.send()
            
            print("✅ Transcription saved to history")
        } catch {
            print("❌ Failed to save transcription: \(error)")
        }
    }
    
    func loadTranscriptions() {
        guard let dbQueue = dbQueue else { return }
        
        do {
            let records = try dbQueue.read { db in
                try TranscriptionRecord.recent(limit: 100).fetchAll(db)
            }
            
            transcriptions = records
            print("✅ Loaded \(records.count) transcriptions from history")
        } catch {
            print("❌ Failed to load transcriptions: \(error)")
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
            
            print("✅ Transcription deleted from history")
        } catch {
            print("❌ Failed to delete transcription: \(error)")
        }
    }
    
    func deleteAllTranscriptions() {
        guard let dbQueue = dbQueue else { return }
        
        do {
            _ = try dbQueue.write { db in
                try TranscriptionRecord.deleteAll(db)
            }
            
            transcriptions.removeAll()
            print("✅ All transcriptions deleted from history")
        } catch {
            print("❌ Failed to delete all transcriptions: \(error)")
        }
    }
    
    func searchTranscriptions(query: String) -> [TranscriptionRecord] {
        guard !query.isEmpty else { return transcriptions }
        
        return transcriptions.filter { record in
            record.text.localizedCaseInsensitiveContains(query)
        }
    }
}