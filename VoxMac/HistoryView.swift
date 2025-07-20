//
//  HistoryView.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var searchText = ""
    @State private var showingDeleteAllAlert = false
    
    private var filteredTranscriptions: [TranscriptionRecord] {
        if searchText.isEmpty {
            return historyManager.transcriptions
        } else {
            return historyManager.searchTranscriptions(query: searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Transcription History")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Clear All") {
                    showingDeleteAllAlert = true
                }
                .disabled(historyManager.transcriptions.isEmpty)
            }
            .padding()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // Transcriptions list
            if filteredTranscriptions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No transcriptions yet" : "No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Text("Start recording to see your transcriptions here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredTranscriptions, id: \.id) { transcription in
                        TranscriptionRowView(transcription: transcription)
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 600, height: 500)
        .alert("Delete All Transcriptions", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                historyManager.deleteAllTranscriptions()
            }
        } message: {
            Text("This action cannot be undone. All transcription history will be permanently deleted.")
        }
    }
}

struct TranscriptionRowView: View {
    let transcription: TranscriptionRecord
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showingDeleteAlert = false
    @State private var showingCopiedAlert = false
    
    private var providerDisplayName: String {
        switch transcription.provider {
        case "openai":
            return "OpenAI"
        case "mistral":
            return "Mistral"
        default:
            return transcription.provider.capitalized
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with timestamp and actions
            HStack {
                Text(relativeTimeString(from: transcription.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let duration = transcription.duration {
                    Text("• \(String(format: "%.1fs", duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("• \(providerDisplayName) \(transcription.model)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                    
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete transcription")
                }
            }
            
            // Transcription text
            Text(transcription.text)
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .alert("Delete Transcription", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                historyManager.deleteTranscription(transcription)
            }
        } message: {
            Text("This transcription will be permanently deleted.")
        }
        .alert("Copied!", isPresented: $showingCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("Transcription copied to clipboard")
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcription.text, forType: .string)
        showingCopiedAlert = true
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        
        // For very recent timestamps (< 60 seconds), show more precision
        if timeInterval < 60 {
            let seconds = Int(timeInterval)
            if seconds < 1 {
                return "now"
            } else if seconds == 1 {
                return "1s ago"
            } else {
                return "\(seconds)s ago"
            }
        }
        
        // For older timestamps, use the standard formatter
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    HistoryView()
}