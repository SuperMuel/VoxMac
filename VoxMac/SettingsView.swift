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
    @State private var apiKey: String = ""
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
            
            // API Configuration Section
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI Configuration")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key:")
                        .font(.caption)
                    
                    SecureField("Enter your OpenAI API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            loadApiKey()
                        }
                    
                    Text("Get your API key from https://platform.openai.com/api-keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button("Save API Key") {
                        saveApiKey()
                    }
                    .disabled(apiKey.isEmpty)
                    
                    Button(isTestingConnection ? "Testing..." : "Test Connection") {
                        Task {
                            await testApiConnection()
                        }
                    }
                    .disabled(apiKey.isEmpty || isTestingConnection)
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
        .frame(width: 500, height: 400)
        .alert("API Key Saved", isPresented: $showingApiKeySaved) {
            Button("OK") { }
        } message: {
            Text("Your OpenAI API key has been securely saved.")
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
    
    private func loadApiKey() {
        if let savedKey = KeychainManager.load(key: .openAIAPIKey) {
            apiKey = savedKey
        }
    }
    
    private func saveApiKey() {
        if KeychainManager.save(apiKey, for: .openAIAPIKey) {
            showingApiKeySaved = true
        } else {
            showingApiKeyError = true
        }
    }
    
    private func testApiConnection() async {
        isTestingConnection = true
        
        do {
            // Test API key by making a simple request to OpenAI models endpoint
            let url = URL(string: "https://api.openai.com/v1/models")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: 0)
            }
            
            if httpResponse.statusCode == 200 {
                connectionResultMessage = "✅ Connection successful! Your API key is working."
            } else if httpResponse.statusCode == 401 {
                connectionResultMessage = "❌ Invalid API key. Please check your OpenAI API key."
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