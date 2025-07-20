//
//  TextInsertionManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import AppKit
import ApplicationServices

class TextInsertionManager {
    
    static func insertText(_ text: String) {
        print("Attempting to insert text: \(text)")
        
        if hasAccessibilityPermissions() {
            print("✅ Accessibility permissions granted - using direct text insertion")
            insertTextViaAccessibility(text)
        } else {
            print("⚠️ Accessibility permissions not granted - falling back to clipboard")
            insertTextViaClipboard(text)
        }
    }
    
    private static func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private static func insertTextViaAccessibility(_ text: String) {
        print("🔧 Inserting text via Accessibility APIs")
        
        DispatchQueue.main.async {
            // Get the currently focused element
            var focusedElement: CFTypeRef?
            let systemWideElement = AXUIElementCreateSystemWide()
            
            print("🔍 Getting focused UI element...")
            let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            print("🔍 Focus result: \(focusResult.rawValue)")
            
            if focusResult == .success, let element = focusedElement {
                print("✅ Found focused element, attempting to set text...")
                
                // Try to set the value directly
                let textCFString = text as CFString
                let result = AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, textCFString)
                print("🔧 Set value result: \(result.rawValue)")
                
                if result == .success {
                    print("✅ Text inserted successfully via Accessibility")
                } else {
                    print("❌ Failed to insert text via Accessibility (error \(result.rawValue)), falling back to clipboard")
                    insertTextViaClipboard(text)
                }
            } else {
                print("❌ Could not get focused element (error \(focusResult.rawValue)), falling back to clipboard")
                insertTextViaClipboard(text)
            }
        }
    }
    
    private static func insertTextViaClipboard(_ text: String) {
        print("Inserting text via clipboard fallback")
        
        DispatchQueue.main.async {
            // Save current clipboard content
            let pasteboard = NSPasteboard.general
            let originalContent = pasteboard.string(forType: .string)
            
            // Set new content
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            // Simulate Cmd+V
            let source = CGEventSource(stateID: .hidSystemState)
            let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
            let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            cmdVDown?.flags = .maskCommand
            cmdVUp?.flags = .maskCommand
            
            cmdVDown?.post(tap: .cghidEventTap)
            cmdVUp?.post(tap: .cghidEventTap)
            
            // Show notification to user
            showClipboardNotification()
            
            // Restore original clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let original = originalContent {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }
    
    private static func showClipboardNotification() {
        let notification = NSUserNotification()
        notification.title = "VoxMac"
        notification.informativeText = "Transcription copied to clipboard and pasted"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    static func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
}