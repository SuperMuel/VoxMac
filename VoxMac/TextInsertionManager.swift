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
    
    static func insertText(_ text: String, method: InsertionMethod) -> String {
        switch method {
        case .autoInsert:
            return insertTextWithAutoInsert(text)
        case .clipboardOnly:
            return insertTextToClipboardOnly(text)
        }
    }
    
    private static func insertTextWithAutoInsert(_ text: String) -> String {
        Log.debug("Attempting to insert text of length: \(text.count)", category: .insertion)
        let hasPermissions = hasAccessibilityPermissions()
        Log.info("Accessibility permission check: \(hasPermissions ? "Granted" : "Denied")", category: .permissions)
        
        if hasPermissions {
            Log.info("Accessibility permissions granted - using direct text insertion", category: .insertion)
            return insertTextViaAccessibilitySync(text)
        } else {
            Log.notice("Accessibility permissions not granted - falling back to clipboard", category: .insertion)
            insertTextViaClipboard(text)
            return "clipboard"
        }
    }
    
    private static func insertTextToClipboardOnly(_ text: String) -> String {
        Log.info("Copying text to clipboard (length=\(text.count))", category: .insertion)
        
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        
        return "clipboard_only"
    }
    
    private static func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private static func insertTextViaAccessibilitySync(_ text: String) -> String {
        Log.debug("Inserting text via Accessibility APIs", category: .insertion)
        
        // Perform accessibility insertion synchronously on main thread
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return insertTextViaAccessibilitySync(text)
            }
        }
        
        // Get the currently focused element
        var focusedElement: CFTypeRef?
        let systemWideElement = AXUIElementCreateSystemWide()
        
        Log.debug("Getting focused UI element...", category: .insertion)
        let focusResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        Log.debug("Focus result: \(focusResult.rawValue)", category: .insertion)
        
        if focusResult == .success, let element = focusedElement {
            let axElement = element as! AXUIElement
            Log.debug("Found focused element, attempting to insert text...", category: .insertion)
            
            // Step 1: Get current selected range
            var selectedRangeValue: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
            
            if rangeResult == .success, let rangeAXValue = selectedRangeValue, AXValueGetType(rangeAXValue as! AXValue) == .cfRange {
                var cfRange = CFRange()
                AXValueGetValue(rangeAXValue as! AXValue, .cfRange, &cfRange)
                let location = cfRange.location
                let length = cfRange.length
                Log.debug("Current selection: location=\(location), length=\(length)", category: .insertion)
                
                // Step 2: Get current text value
                var currentValue: CFTypeRef?
                let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
                
                if valueResult == .success, var currentText = currentValue as? String {
                    Log.debug("Current text length: \(currentText.count)", category: .insertion)
                    
                    // Step 3: Replace selected range with new text
                    if let startIndex = currentText.index(currentText.startIndex, offsetBy: location, limitedBy: currentText.endIndex),
                       let endIndex = currentText.index(startIndex, offsetBy: length, limitedBy: currentText.endIndex) {
                        currentText.replaceSubrange(startIndex..<endIndex, with: text)
                        
                        // Step 4: Set new text value
                        let setValueResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, currentText as CFString)
                        Log.debug("Set value result: \(setValueResult.rawValue)", category: .insertion)
                        
                        if setValueResult == .success {
                            // Step 5: Update selection range to after inserted text (cursor at end of insertion)
                            let newLocation = location + text.count
                            var newRange = CFRangeMake(newLocation, 0)
                            if let newRangeValue = AXValueCreate(.cfRange, &newRange) {
                                let setRangeResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue)
                                Log.debug("Set new selection result: \(setRangeResult.rawValue)", category: .insertion)
                                
                                if setRangeResult == .success {
                                    Log.info("Text inserted successfully via Accessibility at cursor", category: .insertion)
                                    return "accessibility"
                                }
                            }
                        }
                    }
                }
            }
            
            Log.notice("Accessibility insertion failed (unsupported element or error). Falling back to clipboard.", category: .insertion)
            insertTextViaClipboard(text)
            return "clipboard (accessibility fallback)"
        } else {
            Log.notice("Could not get focused element (error \(focusResult.rawValue)), falling back to clipboard", category: .insertion)
            insertTextViaClipboard(text)
            return "clipboard (no focus)"
        }
    }
    
    private static func insertTextViaClipboard(_ text: String) {
        Log.debug("Inserting text via clipboard fallback", category: .insertion)
        
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
