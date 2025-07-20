//
//  OnboardingView.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var currentStep = 0
    @State private var isRequestingMicrophone = false
    @State private var accessibilityMonitoringTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to VoxMac",
            description: "A powerful speech-to-text app that works system-wide with global keyboard shortcuts.",
            icon: "mic.fill",
            action: .next
        ),
        OnboardingStep(
            title: "Microphone Access",
            description: "VoxMac needs microphone access to record your voice for transcription.",
            icon: "mic.circle",
            action: .requestMicrophone
        ),
        OnboardingStep(
            title: "Accessibility Access",
            description: "VoxMac needs accessibility permissions to automatically insert transcribed text into any application.",
            icon: "accessibility",
            action: .requestAccessibility
        ),
        OnboardingStep(
            title: "You're All Set!",
            description: "Use your keyboard shortcut to start recording. The transcribed text will be automatically inserted where your cursor is.",
            icon: "checkmark.circle.fill",
            action: .finish
        )
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress indicator
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Current step content
            VStack(spacing: 20) {
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(steps[currentStep].title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(steps[currentStep].description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                
                // Step-specific content
                stepSpecificContent
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(buttonText) {
                    handlePrimaryAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionDisabled)
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(width: 600, height: 500)
        .onAppear {
            permissionsManager.refreshPermissionStatuses()
        }
        .onDisappear {
            stopAccessibilityMonitoring()
        }
    }
    
    @ViewBuilder
    private var stepSpecificContent: some View {
        switch currentStep {
        case 1: // Microphone step
            VStack(spacing: 10) {
                HStack {
                    Text("Status:")
                    Text(permissionsManager.microphoneStatus.displayText)
                        .foregroundColor(Color(permissionsManager.microphoneStatus.displayColor))
                        .fontWeight(.medium)
                }
                .font(.caption)
                
                if permissionsManager.microphoneStatus == .denied {
                    Button("Open System Settings") {
                        permissionsManager.openMicrophoneSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            
        case 2: // Accessibility step
            VStack(spacing: 10) {
                HStack {
                    Text("Status:")
                    Text(permissionsManager.accessibilityStatus.displayText)
                        .foregroundColor(Color(permissionsManager.accessibilityStatus.displayColor))
                        .fontWeight(.medium)
                }
                .font(.caption)
                
                if permissionsManager.accessibilityStatus == .denied {
                    Button("Open System Settings") {
                        permissionsManager.openAccessibilitySettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    private var buttonText: String {
        switch steps[currentStep].action {
        case .next:
            return "Get Started"
        case .requestMicrophone:
            if isRequestingMicrophone {
                return "Requesting..."
            } else if permissionsManager.microphoneStatus.isGranted {
                return "Continue"
            } else {
                return "Grant Permission"
            }
        case .requestAccessibility:
            if permissionsManager.accessibilityStatus.isGranted {
                return "Continue"
            } else {
                return "Grant Permission"
            }
        case .finish:
            return "Start Using VoxMac"
        }
    }
    
    private var isActionDisabled: Bool {
        switch steps[currentStep].action {
        case .requestMicrophone:
            return isRequestingMicrophone
        default:
            return false
        }
    }
    
    private func handlePrimaryAction() {
        switch steps[currentStep].action {
        case .next:
            withAnimation {
                currentStep += 1
            }
            
        case .requestMicrophone:
            if permissionsManager.microphoneStatus.isGranted {
                withAnimation {
                    currentStep += 1
                }
            } else {
                Task {
                    isRequestingMicrophone = true
                    await permissionsManager.requestMicrophonePermission()
                    isRequestingMicrophone = false
                    
                    if permissionsManager.microphoneStatus.isGranted {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
            }
            
        case .requestAccessibility:
            if permissionsManager.accessibilityStatus.isGranted {
                withAnimation {
                    currentStep += 1
                }
            } else {
                permissionsManager.requestAccessibilityPermission()
                
                // Start periodic checking for accessibility permissions
                startAccessibilityPermissionMonitoring()
            }
            
        case .finish:
            stopAccessibilityMonitoring()
            dismiss()
        }
    }
    
    private func startAccessibilityPermissionMonitoring() {
        // Stop any existing timer
        accessibilityMonitoringTimer?.invalidate()
        
        // Start checking every 2 seconds
        accessibilityMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            permissionsManager.refreshPermissionStatuses()
            
            // If permissions are granted, advance to next step
            if permissionsManager.accessibilityStatus.isGranted {
                stopAccessibilityMonitoring()
                withAnimation {
                    currentStep += 1
                }
            }
        }
    }
    
    private func stopAccessibilityMonitoring() {
        accessibilityMonitoringTimer?.invalidate()
        accessibilityMonitoringTimer = nil
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let action: OnboardingAction
}

enum OnboardingAction {
    case next
    case requestMicrophone
    case requestAccessibility
    case finish
}

#Preview {
    OnboardingView()
}