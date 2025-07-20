//
//  TextInsertionManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import Cocoa
import ApplicationServices

class TextInsertionManager {
    
    static func insertText(_ text: String) -> String {
        print("Attempting to insert text: \(text)")
        let hasPermissions = hasAccessibilityPermissions()
        print("Accessibility permission check: \(hasPermissions ? "Granted" : "Denied")")
        
        if hasPermissions {
            print("✅ Accessibility permissions granted - using direct text insertion")
            return insertTextViaAccessibilitySync(text)
        } else {
            print("⚠️ Accessibility permissions not granted - falling back to clipboard")
            insertTextViaClipboard(text)
            return "clipboard"
        }
    }
    
    private static func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private static func insertTextViaAccessibilitySync(_ text: String) -> String {
        print("🔧 Inserting text via Accessibility APIs")
        
        // Perform accessibility insertion synchronously on main thread
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return insertTextViaAccessibilitySync(text)
            }
        }
        
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
            print("🔧 Set value result: \(result) (code: \(result.rawValue))")
            
            if result == .success {
                print("✅ Text inserted successfully via Accessibility")
                return "accessibility"
            } else {
                print("❌ Failed to set AXValue attribute: \(result). Falling back to clipboard. (Common if target app doesn't support direct insertion)")
                insertTextViaClipboard(text)
                return "clipboard (accessibility fallback)"
            }
        } else {
            print("❌ Could not get focused element (error \(focusResult.rawValue)), falling back to clipboard")
            insertTextViaClipboard(text)
            return "clipboard (no focus)"
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
            
            // Restore original clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let original = originalContent {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
            }
        }
    }
    
    static func requestAccessibilityPermissions() {
        // On modern macOS, it's more reliable and user-friendly to open
        // System Settings directly to the correct pane.
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}