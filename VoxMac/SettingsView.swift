//
//  SettingsView.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI
import KeyboardShortcuts
import AVFoundation

struct SettingsView: View {
    @State private var openAIApiKey: String = ""
    @State private var mistralApiKey: String = ""
    @State private var selectedService: String = "openai"
    @State private var showingApiKeySaved = false
    @State private var showingApiKeyError = false
    @State private var showingConnectionResult = false
    @State private var connectionResultMessage = ""
    @State private var isTestingConnection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("VoxMac Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            Divider()
            
            // Keyboard Shortcut Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut")
                    .font(.headline)
                
                HStack {
                    Text("Recording Toggle:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                        .frame(width: 150)
                }
            }
            
            Divider()
            
            // Transcription Service Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription Service")
                    .font(.headline)
                
                Picker("Service:", selection: $selectedService) {
                    Text("OpenAI Whisper").tag("openai")
                    Text("Mistral Voxtral").tag("mistral")
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedService) { _, newValue in
                    saveSelectedService(newValue)
                }
            }
            
            Divider()
            
            // API Configuration Section
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedService == "openai" ? "OpenAI Configuration" : "Mistral Configuration")
                    .font(.headline)
                
                if selectedService == "openai" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI API Key:")
                            .font(.caption)
                        
                        SecureField("Enter your OpenAI API key", text: $openAIApiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Get your API key from https://platform.openai.com/api-keys")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mistral API Key:")
                            .font(.caption)
                        
                        SecureField("Enter your Mistral API key", text: $mistralApiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Get your API key from https://console.mistral.ai/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Button("Save API Key") {
                        saveApiKey()
                    }
                    .disabled(currentApiKey.isEmpty)
                    
                    Button(isTestingConnection ? "Testing..." : "Test Connection") {
                        Task {
                            await testApiConnection()
                        }
                    }
                    .disabled(currentApiKey.isEmpty || isTestingConnection)
                }
            }
            
            Divider()
            
            // Permissions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)
                
                HStack {
                    Text("Microphone Access:")
                    Spacer()
                    Text(microphonePermissionStatus)
                        .foregroundColor(microphonePermissionColor)
                }
                
                HStack {
                    Text("Accessibility Access:")
                    Spacer()
                    Text(accessibilityPermissionStatus)
                        .foregroundColor(accessibilityPermissionColor)
                }
                
                Button("Request Accessibility Permissions") {
                    TextInsertionManager.requestAccessibilityPermissions()
                }
                .disabled(hasAccessibilityPermissions)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 500, height: 450)
        .onAppear {
            loadApiKeys()
            loadSelectedService()
        }
        .alert("API Key Saved", isPresented: $showingApiKeySaved) {
            Button("OK") { }
        } message: {
            Text("Your \(selectedService == "openai" ? "OpenAI" : "Mistral") API key has been securely saved.")
        }
        .alert("Error", isPresented: $showingApiKeyError) {
            Button("OK") { }
        } message: {
            Text("Failed to save API key. Please try again.")
        }
        .alert("Connection Test", isPresented: $showingConnectionResult) {
            Button("OK") { }
        } message: {
            Text(connectionResultMessage)
        }
    }
    
    private func loadApiKeys() {
        if let savedKey = KeychainManager.load(key: .openAIAPIKey) {
            openAIApiKey = savedKey
        }
        if let savedKey = KeychainManager.load(key: .mistralAPIKey) {
            mistralApiKey = savedKey
        }
    }
    
    private func loadSelectedService() {
        selectedService = KeychainManager.load(key: .transcriptionService) ?? "openai"
    }
    
    private func saveSelectedService(_ service: String) {
        _ = KeychainManager.save(service, for: .transcriptionService)
    }
    
    private var currentApiKey: String {
        selectedService == "openai" ? openAIApiKey : mistralApiKey
    }
    
    private func saveApiKey() {
        let success: Bool
        if selectedService == "openai" {
            success = KeychainManager.save(openAIApiKey, for: .openAIAPIKey)
        } else {
            success = KeychainManager.save(mistralApiKey, for: .mistralAPIKey)
        }
        
        if success {
            showingApiKeySaved = true
        } else {
            showingApiKeyError = true
        }
    }
    
    private func testApiConnection() async {
        isTestingConnection = true
        
        do {
            let url: URL
            var request: URLRequest
            
            if selectedService == "openai" {
                url = URL(string: "https://api.openai.com/v1/models")!
                request = URLRequest(url: url)
                request.setValue("Bearer \(currentApiKey)", forHTTPHeaderField: "Authorization")
            } else {
                url = URL(string: "https://api.mistral.ai/v1/models")!
                request = URLRequest(url: url)
                request.setValue(currentApiKey, forHTTPHeaderField: "x-api-key")
            }
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: 0)
            }
            
            if httpResponse.statusCode == 200 {
                connectionResultMessage = "✅ Connection successful! Your \(selectedService == "openai" ? "OpenAI" : "Mistral") API key is working."
            } else if httpResponse.statusCode == 401 {
                connectionResultMessage = "❌ Invalid API key. Please check your \(selectedService == "openai" ? "OpenAI" : "Mistral") API key."
            } else {
                connectionResultMessage = "❌ API error: HTTP \(httpResponse.statusCode)"
            }
            
        } catch {
            connectionResultMessage = "❌ Connection failed: \(error.localizedDescription)"
        }
        
        isTestingConnection = false
        showingConnectionResult = true
    }
    
    private var microphonePermissionStatus: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "Granted"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var microphonePermissionColor: Color {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var hasAccessibilityPermissions: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private var accessibilityPermissionStatus: String {
        hasAccessibilityPermissions ? "Granted" : "Denied"
    }
    
    private var accessibilityPermissionColor: Color {
        hasAccessibilityPermissions ? .green : .red
    }
}

#Preview {
    SettingsView()
}