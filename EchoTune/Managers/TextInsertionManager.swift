//
//  TextInsertionManager.swift
//  EchoTune
//
//  Phase 4: Direct Text Insertion using Accessibility API
//

import AppKit
import ApplicationServices
import UserNotifications

class TextInsertionManager {
    static let shared = TextInsertionManager()

    private init() {
        debugLog("✓ TextInsertionManager initialized")
    }

    // MARK: - Permission Check

    func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Text Insertion

    func insertText(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        debugLog("📝 TEXT INSERTION START")
        debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        debugLog("   Original text: \(text.prefix(100))")

        // Process text through dictionary replacements FIRST
        let processedText = processTextReplacements(text)
        debugLog("   Processed text: \(processedText.prefix(100))")

        // Check permission
        guard hasAccessibilityPermission() else {
            debugLog("❌ No accessibility permission - falling back to clipboard")
            insertViaClipboard(processedText)
            completion(.failure(TextInsertionError.noPermission))
            return
        }
        debugLog("✅ Accessibility permission: OK")

        // Check if we're in a browser or web app
        if let appName = getFrontmostApplication() {
            debugLog("🔍 Frontmost app: '\(appName)'")

            // Use character-by-character typing for browsers
            if isBrowserApp(appName) {
                debugLog("🌐 Browser detected! Using character-by-character typing")
                debugLog("   Text length: \(processedText.count) characters")
                debugLog("   Starting typing now...")

                typeTextAsync(processedText) {
                    debugLog("✅ Browser typing completed successfully")
                    debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    completion(.success(()))
                }
                return
            } else {
                debugLog("ℹ️ Not a browser app - using paste method")
            }
        } else {
            debugLog("⚠️ Could not detect frontmost application!")
        }

        // Try direct insertion first for native apps
        debugLog("   Attempting direct paste insertion...")
        if insertViaPaste(processedText) {
            debugLog("✅ Text inserted successfully via paste")
            debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            completion(.success(()))
        } else {
            debugLog("⚠️ Direct insertion failed - using clipboard fallback")
            insertViaClipboard(processedText)
            debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            completion(.success(()))
        }
    }

    // MARK: - Browser Detection

    private func isBrowserApp(_ appName: String) -> Bool {
        let browsers = [
            "Google Chrome",
            "Chrome",
            "Safari",
            "Firefox",
            "Microsoft Edge",
            "Edge",
            "Opera",
            "Brave Browser",
            "Brave",
            "Arc",
            "Vivaldi"
        ]
        return browsers.contains { appName.contains($0) }
    }

    // MARK: - Text Processing

    private func processTextReplacements(_ text: String) -> String {
        var processedText = text

        // Step 1: Apply custom dictionary replacements (from EchoTune)
        processedText = DictionaryManager.shared.process(text: processedText)

        // Step 2: Apply macOS system text replacements
        processedText = applySystemTextReplacements(processedText)

        return processedText
    }

    private func applySystemTextReplacements(_ text: String) -> String {
        // Access macOS text replacements from NSUserDefaults
        // These are stored in the user's preferences
        guard let replacements = UserDefaults.standard.dictionary(forKey: "NSUserDictionaryReplacementItems") as? [[String: Any]] else {
            // Try alternative key for text replacements
            return applySystemTextReplacementsAlternative(text)
        }

        var result = text

        for replacement in replacements {
            guard let shortcut = replacement["replace"] as? String,
                  let phrase = replacement["with"] as? String else {
                continue
            }

            // Case-insensitive replacement for phrases
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: shortcut))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: phrase)
                debugLog("✓ Applied system text replacement: '\(shortcut)' → '\(phrase)'")
            }
        }

        return result
    }

    private func applySystemTextReplacementsAlternative(_ text: String) -> String {
        // Try to read from the text replacements plist file directly
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let textReplacementsPath = homeDir.appendingPathComponent("Library/KeyBindings/NSTextReplacements.plist")

        guard FileManager.default.fileExists(atPath: textReplacementsPath.path),
              let data = try? Data(contentsOf: textReplacementsPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
            debugLog("ℹ️ No system text replacements found")
            return text
        }

        var result = text

        for replacement in plist {
            guard let shortcut = replacement["replace"] as? String,
                  let phrase = replacement["with"] as? String else {
                continue
            }

            // Case-insensitive replacement
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: shortcut))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: phrase)
                debugLog("✓ Applied system text replacement: '\(shortcut)' → '\(phrase)'")
            }
        }

        return result
    }

    // MARK: - Direct Insertion via Paste

    private func insertViaPaste(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general

        // Save all pasteboard items with their data for each type
        struct PasteboardBackup {
            let types: [NSPasteboard.PasteboardType]
            let dataByType: [NSPasteboard.PasteboardType: Data]
        }
        var backup: PasteboardBackup? = nil
        if let items = pasteboard.pasteboardItems, let firstItem = items.first {
            let types = firstItem.types
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in types {
                if let data = firstItem.data(forType: type) {
                    dataByType[type] = data
                }
            }
            if !dataByType.isEmpty {
                backup = PasteboardBackup(types: types, dataByType: dataByType)
            }
        }

        // Set our text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is set
        Thread.sleep(forTimeInterval: 0.05)

        // Simulate Cmd+V
        let success = simulateKeyPress(keyCode: 0x09, modifiers: .maskCommand) // V key

        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let backup = backup {
                let item = NSPasteboardItem()
                for type in backup.types {
                    if let data = backup.dataByType[type] {
                        item.setData(data, forType: type)
                    }
                }
                pasteboard.writeObjects([item])
            }
        }

        return success
    }

    // MARK: - Clipboard Fallback

    private func insertViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        debugLog("📋 Text copied to clipboard")

        // Show notification
        showNotification(
            title: "Text Copied to Clipboard",
            body: "Press ⌘V to paste: \(text.prefix(30))..."
        )
    }

    // MARK: - Keyboard Simulation

    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) -> Bool {
        let eventSource = CGEventSource(stateID: .combinedSessionState)

        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else {
            return false
        }
        keyDown.flags = modifiers

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        keyUp.flags = modifiers

        // Post events
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        return true
    }

    // MARK: - Alternative: Direct AX Text Insertion

    private func insertViaAccessibilityAPI(_ text: String) -> Bool {
        // Get the system-wide element
        let systemWideElement = AXUIElementCreateSystemWide()

        // Get the focused element
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success, let element = focusedElement else {
            debugLog("❌ Failed to get focused element")
            return false
        }

        // Try to set the value
        let axElement = element as! AXUIElement
        let setValue = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )

        if setValue == .success {
            debugLog("✓ Text inserted via AX API")
            return true
        }

        // Try insertion via focused element
        let insertResult = AXUIElementSetAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            text as CFString
        )

        if insertResult == .success {
            debugLog("✓ Text set via AX value attribute")
            return true
        }

        debugLog("⚠️ AX API insertion failed")
        return false
    }

    // MARK: - Typing Simulation

    func typeText(_ text: String) {
        // Alternative method: simulate typing each character
        let eventSource = CGEventSource(stateID: .combinedSessionState)

        for char in text.unicodeScalars {
            let keyCode: CGKeyCode = 0 // Not used for unicode events

            // Key down
            if let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) {
                keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.value)])
                keyDown.post(tap: .cgAnnotatedSessionEventTap)
            }

            // Key up
            if let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) {
                keyUp.post(tap: .cgAnnotatedSessionEventTap)
            }

            // Small delay between characters
            Thread.sleep(forTimeInterval: 0.001)
        }

        debugLog("✓ Text typed character by character")
    }

    func typeTextAsync(_ text: String, completion: @escaping () -> Void) {
        debugLog("   ⌨️  typeTextAsync called with \(text.count) characters")

        // Run typing in background to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            let eventSource = CGEventSource(stateID: .combinedSessionState)

            if eventSource == nil {
                debugLog("   ❌ Failed to create CGEventSource!")
                DispatchQueue.main.async {
                    completion()
                }
                return
            }

            debugLog("   ✓ CGEventSource created successfully")
            var charCount = 0

            for char in text.unicodeScalars {
                charCount += 1
                let keyCode: CGKeyCode = 0 // Not used for unicode events

                // Key down
                if let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) {
                    keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.value)])
                    keyDown.post(tap: .cgAnnotatedSessionEventTap)
                } else {
                    debugLog("   ❌ Failed to create keyDown event for char #\(charCount)")
                }

                // Key up
                if let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) {
                    keyUp.post(tap: .cgAnnotatedSessionEventTap)
                } else {
                    debugLog("   ❌ Failed to create keyUp event for char #\(charCount)")
                }

                // Show progress every 10 characters
                if charCount % 10 == 0 {
                    debugLog("   ... typed \(charCount)/\(text.count) characters")
                }

                // Small delay between characters (faster for browsers)
                Thread.sleep(forTimeInterval: 0.002)
            }

            debugLog("   ✓ Finished typing all \(charCount) characters")

            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // MARK: - Application Detection

    func getFrontmostApplication() -> String? {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            return frontApp.localizedName
        }
        return nil
    }

    func isTextFieldFocused() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?

        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        return result == .success && focusedElement != nil
    }

    // MARK: - Notifications

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌ Notification error: \(error)")
            }
        }
    }
}

// MARK: - Text Insertion Error

enum TextInsertionError: LocalizedError {
    case noPermission
    case insertionFailed
    case noTargetApplication

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "Accessibility permission required to insert text directly. Using clipboard instead."
        case .insertionFailed:
            return "Failed to insert text. Please paste manually with ⌘V."
        case .noTargetApplication:
            return "No text field is focused. Please click in a text field and try again."
        }
    }
}
