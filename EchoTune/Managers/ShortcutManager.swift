//
//  ShortcutManager.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Cocoa
import Carbon

class ShortcutManager: NSObject {
    static let shared = ShortcutManager()

    // Callback for when shortcut is triggered
    var onShortcutTriggered: (() -> Void)?
    
    // Default shortcut: Cmd+Shift+D
    private var shortcutKeyCode: UInt32 = 2 // 'D' key
    private var shortcutModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

    // Event tap for global shortcut monitoring
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Flag to track if shortcut is currently pressed
    private var isShortcutPressed = false

    override init() {
        super.init()
        loadCustomShortcut()
        registerGlobalShortcut()

        // Listen for accessibility permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAccessibilityPermissionGranted),
            name: NSNotification.Name("AccessibilityPermissionGranted"),
            object: nil
        )

        print("✓ ShortcutManager initialized and listening for permission changes")
    }

    @objc private func onAccessibilityPermissionGranted() {
        print("🔔 Received AccessibilityPermissionGranted notification")
        print("   Re-registering global shortcuts...")

        // Re-register shortcuts now that we have permission
        DispatchQueue.main.async {
            self.unregisterGlobalShortcut()
            self.registerGlobalShortcut()
        }
    }

    private func loadCustomShortcut() {
        // Load custom shortcut from UserDefaults if available
        if let savedKeyCode = UserDefaults.standard.object(forKey: "customShortcutKeyCode") as? UInt32,
           let savedModifiers = UserDefaults.standard.object(forKey: "customShortcutModifiers") as? UInt32 {
            shortcutKeyCode = savedKeyCode
            shortcutModifiers = savedModifiers
            print("✓ Loaded custom shortcut: \(getCurrentShortcutString())")
        }
    }

    private func saveCustomShortcut() {
        UserDefaults.standard.set(shortcutKeyCode, forKey: "customShortcutKeyCode")
        UserDefaults.standard.set(shortcutModifiers, forKey: "customShortcutModifiers")
        print("✓ Saved custom shortcut: \(getCurrentShortcutString())")
    }
    
    deinit {
        unregisterGlobalShortcut()
        NotificationCenter.default.removeObserver(self)
    }
    
    func registerGlobalShortcut() {
        print("🔧 Attempting to register global shortcut...")

        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        print("🔐 Accessibility permission status: \(accessibilityEnabled)")

        if !accessibilityEnabled {
            print("❌ Global shortcuts DISABLED - Accessibility permissions NOT granted")
            print("   Please go to System Settings → Privacy & Security → Accessibility")
            print("   and enable EchoTune")

            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "EchoTune needs Accessibility permission to use global keyboard shortcuts.\n\nPlease enable it in:\nSystem Settings → Privacy & Security → Accessibility"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return
        }

        print("✅ Accessibility permission granted")
        print("🎹 Current shortcut: \(getCurrentShortcutString())")
        print("   KeyCode: \(shortcutKeyCode), Modifiers: \(shortcutModifiers)")

        // Create event tap for global keyboard monitoring
        // Include flagsChanged for single modifier key shortcuts
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue |
                                    1 << CGEventType.keyUp.rawValue |
                                    1 << CGEventType.flagsChanged.rawValue)

        print("📡 Creating event tap with mask: \(eventMask)")

        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("❌ FAILED to create event tap!")
            print("   This usually means Accessibility permissions are not properly granted")
            print("   or there's a system restriction")
            return
        }

        print("✅ Event tap created successfully")
        self.eventTap = tap

        // Create run loop source
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        print("✅ Run loop source created")

        // Add to current run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        print("✅ Added to run loop")

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
        print("✅ Event tap enabled")

        print("🎉 Global keyboard shortcut SUCCESSFULLY registered: \(getCurrentShortcutString())")
        print("   Monitoring for: KeyCode=\(shortcutKeyCode), Modifiers=\(shortcutModifiers)")
    }
    
    func unregisterGlobalShortcut() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }
    
    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
        saveCustomShortcut()
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Special handling for single modifier keys (Control=59, Option=58)
        let isSingleModifierShortcut = (shortcutKeyCode == 59 || shortcutKeyCode == 58)

        if isSingleModifierShortcut {
            // Handle flags changed events for single modifiers
            if type == .flagsChanged {
                let currentModifiers = UInt32(event.flags.rawValue) & (UInt32(NSEvent.ModifierFlags.control.rawValue) |
                                                                        UInt32(NSEvent.ModifierFlags.option.rawValue))

                // Check if the correct single modifier is pressed
                if currentModifiers == shortcutModifiers && !isShortcutPressed {
                    isShortcutPressed = true
                    print("🎯 Single modifier shortcut triggered: \(getCurrentShortcutString())")

                    // Trigger callback on main thread
                    DispatchQueue.main.async { [weak self] in
                        print("📞 Calling shortcut callback...")
                        self?.onShortcutTriggered?()
                    }

                    return Unmanaged.passRetained(event) // Don't consume modifier events
                } else if currentModifiers == 0 && isShortcutPressed {
                    isShortcutPressed = false
                    print("🎯 Single modifier shortcut released")
                    return Unmanaged.passRetained(event)
                }
            }
        } else {
            // Normal key handling (function keys or key combinations)
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let modifiers = UInt32(event.flags.rawValue) & (UInt32(NSEvent.ModifierFlags.command.rawValue) |
                                                            UInt32(NSEvent.ModifierFlags.shift.rawValue) |
                                                            UInt32(NSEvent.ModifierFlags.control.rawValue) |
                                                            UInt32(NSEvent.ModifierFlags.option.rawValue))

            // Check if this is our shortcut
            if keyCode == shortcutKeyCode && modifiers == shortcutModifiers {
                if type == .keyDown && !isShortcutPressed {
                    isShortcutPressed = true
                    print("🎯 Shortcut triggered: \(getCurrentShortcutString())")

                    // Trigger callback on main thread
                    DispatchQueue.main.async { [weak self] in
                        print("📞 Calling shortcut callback...")
                        self?.onShortcutTriggered?()
                    }

                    // Consume the event
                    return nil
                } else if type == .keyUp && isShortcutPressed {
                    isShortcutPressed = false
                    print("🎯 Shortcut released")

                    // Consume the event
                    return nil
                }
            }
        }

        // Pass through other events
        return Unmanaged.passRetained(event)
    }
    
    // Helper to convert string representation to key code
    func keyCodeFromString(_ string: String) -> UInt32? {
        let uppercased = string.uppercased()

        // Handle special multi-character keys
        switch uppercased {
        case "TAB": return 48
        case "SPACE": return 49
        case "DELETE": return 51
        case "ESCAPE": return 53
        case "RETURN": return 36
        default: break
        }

        guard string.count == 1 else { return nil }

        let char = uppercased.first!

        // Map common keys to key codes
        let keyCodes: [Character: UInt32] = [
            "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
            "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16,
            "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24,
            "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "O": 31, "U": 32,
            "[": 33, "I": 34, "P": 35, "L": 37, "J": 38, "'": 39, "K": 40, ";": 41,
            "\\": 42, ",": 43, "/": 44, "N": 45, "M": 46, ".": 47,
            "`": 50
        ]

        return keyCodes[char]
    }
    
    // Helper to convert modifier flags to string
    func modifierFlagsToString(_ flags: UInt32) -> String {
        var result = ""
        
        if flags & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            result += "⌘"
        }
        
        if flags & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            result += "⇧"
        }
        
        if flags & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            result += "⌃"
        }
        
        if flags & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            result += "⌥"
        }
        
        return result
    }
    
    // Get current shortcut as string
    func getCurrentShortcutString() -> String {
        // Special handling for single modifier keys
        if shortcutKeyCode == 59 {
            return "⌃ Control"
        } else if shortcutKeyCode == 58 {
            return "⌥ Option"
        }

        let modifierString = modifierFlagsToString(shortcutModifiers)

        // Map key code to character
        let keyChar: String
        switch shortcutKeyCode {
        case 0: keyChar = "A"
        case 1: keyChar = "S"
        case 2: keyChar = "D"
        case 3: keyChar = "F"
        case 4: keyChar = "H"
        case 5: keyChar = "G"
        case 6: keyChar = "Z"
        case 7: keyChar = "X"
        case 8: keyChar = "C"
        case 9: keyChar = "V"
        case 11: keyChar = "B"
        case 12: keyChar = "Q"
        case 13: keyChar = "W"
        case 14: keyChar = "E"
        case 15: keyChar = "R"
        case 16: keyChar = "Y"
        case 17: keyChar = "T"
        case 31: keyChar = "O"
        case 32: keyChar = "U"
        case 34: keyChar = "I"
        case 35: keyChar = "P"
        case 37: keyChar = "L"
        case 38: keyChar = "J"
        case 40: keyChar = "K"
        case 45: keyChar = "N"
        case 46: keyChar = "M"
        // Function keys
        case 122: keyChar = "F1"
        case 120: keyChar = "F2"
        case 99: keyChar = "F3"
        case 118: keyChar = "F4"
        case 96: keyChar = "F5"
        case 97: keyChar = "F6"
        case 98: keyChar = "F7"
        case 100: keyChar = "F8"
        case 101: keyChar = "F9"
        case 109: keyChar = "F10"
        case 103: keyChar = "F11"
        case 111: keyChar = "F12"
        default: keyChar = "?"
        }

        return modifierString + keyChar
    }

    // Convenience method - alias for getCurrentShortcutString
    func getShortcutString() -> String {
        return getCurrentShortcutString()
    }

    // Reset shortcut to default (Cmd+Shift+D)
    func resetToDefault() {
        shortcutKeyCode = 2 // 'D' key
        shortcutModifiers = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)

        // Clear saved custom shortcut
        UserDefaults.standard.removeObject(forKey: "customShortcutKeyCode")
        UserDefaults.standard.removeObject(forKey: "customShortcutModifiers")
        print("✓ Reset to default shortcut: \(getCurrentShortcutString())")
    }
}