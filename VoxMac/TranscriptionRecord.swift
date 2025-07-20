//
//  TranscriptionRecord.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import GRDB

struct TranscriptionRecord: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval?
    
    init(text: String, timestamp: Date = Date(), duration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }
}

// MARK: - Database Protocol Conformance
extension TranscriptionRecord: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "transcriptions"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let text = Column(CodingKeys.text)
        static let timestamp = Column(CodingKeys.timestamp)
        static let duration = Column(CodingKeys.duration)
    }
    
    // Custom encoding for UUID to store as string
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.text] = text
        container[Columns.timestamp] = timestamp
        container[Columns.duration] = duration
    }
    
    // Custom decoding for UUID from string
    init(row: Row) {
        let idString: String = row[Columns.id]
        self.id = UUID(uuidString: idString) ?? UUID()
        self.text = row[Columns.text]
        self.timestamp = row[Columns.timestamp]
        self.duration = row[Columns.duration]
    }
}

// MARK: - Query Interface
extension TranscriptionRecord {
    static func orderedByTimestamp() -> QueryInterfaceRequest<TranscriptionRecord> {
        return TranscriptionRecord.order(Columns.timestamp.desc)
    }
    
    static func recent(limit: Int = 100) -> QueryInterfaceRequest<TranscriptionRecord> {
        return orderedByTimestamp().limit(limit)
    }
}