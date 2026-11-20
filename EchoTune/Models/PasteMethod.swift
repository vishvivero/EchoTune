//
//  PasteMethod.swift
//  EchoTune
//
//  Selectable text delivery strategies including Direct Unicode Typing and
//  Remote Desktop / VM Hardware Keycode Typing (Citrix, RDP, RustDesk, VNC, VMs).
//

import CoreGraphics
import Foundation

enum PasteMethod: String, CaseIterable, Identifiable, Codable {
    case standard = "standard"
    case appleScript = "appleScript"
    case directTyping = "directTyping"
    case remoteDesktop = "remoteDesktop"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard Paste (⌘V, restores clipboard)"
        case .appleScript: return "AppleScript Paste"
        case .directTyping: return "Direct Typing (no clipboard)"
        case .remoteDesktop: return "Remote Desktop / VM Typing (hardware keys)"
        }
    }

    var shortName: String {
        switch self {
        case .standard: return "Standard (⌘V)"
        case .appleScript: return "AppleScript"
        case .directTyping: return "Direct Typing"
        case .remoteDesktop: return "Remote / VM"
        }
    }
}

/// Hardware virtual-keycode mapper for Remote Desktop / VM clients (RDP, Citrix,
/// RustDesk, Parsec, UTM, VMware) that ignore `keyboardSetUnicodeString` and `⌘V`.
enum RemoteDesktopKeyTyper {
    private struct KeyStroke {
        let keyCode: CGKeyCode
        let shift: Bool
    }

    static func type(_ text: String, interKeyDelay: TimeInterval = 0.004) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        for scalar in text.unicodeScalars {
            let ch = Character(scalar)
            if let stroke = ansiMapping[ch] {
                let flags: CGEventFlags = stroke.shift ? .maskShift : []
                if let down = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true),
                   let up = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false) {
                    down.flags = flags
                    up.flags = flags
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            } else {
                // Non-ASCII fallback via Unicode string event
                if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                   let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                    var utf16 = Array(String(ch).utf16)
                    down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                }
            }
            if interKeyDelay > 0 {
                Thread.sleep(forTimeInterval: interKeyDelay)
            }
        }
    }

    // US/UK ANSI virtual keycodes
    private static let ansiMapping: [Character: KeyStroke] = [
        "a": .init(keyCode: 0, shift: false), "A": .init(keyCode: 0, shift: true),
        "s": .init(keyCode: 1, shift: false), "S": .init(keyCode: 1, shift: true),
        "d": .init(keyCode: 2, shift: false), "D": .init(keyCode: 2, shift: true),
        "f": .init(keyCode: 3, shift: false), "F": .init(keyCode: 3, shift: true),
        "h": .init(keyCode: 4, shift: false), "H": .init(keyCode: 4, shift: true),
        "g": .init(keyCode: 5, shift: false), "G": .init(keyCode: 5, shift: true),
        "z": .init(keyCode: 6, shift: false), "Z": .init(keyCode: 6, shift: true),
        "x": .init(keyCode: 7, shift: false), "X": .init(keyCode: 7, shift: true),
        "c": .init(keyCode: 8, shift: false), "C": .init(keyCode: 8, shift: true),
        "v": .init(keyCode: 9, shift: false), "V": .init(keyCode: 9, shift: true),
        "b": .init(keyCode: 11, shift: false), "B": .init(keyCode: 11, shift: true),
        "q": .init(keyCode: 12, shift: false), "Q": .init(keyCode: 12, shift: true),
        "w": .init(keyCode: 13, shift: false), "W": .init(keyCode: 13, shift: true),
        "e": .init(keyCode: 14, shift: false), "E": .init(keyCode: 14, shift: true),
        "r": .init(keyCode: 15, shift: false), "R": .init(keyCode: 15, shift: true),
        "y": .init(keyCode: 16, shift: false), "Y": .init(keyCode: 16, shift: true),
        "t": .init(keyCode: 17, shift: false), "T": .init(keyCode: 17, shift: true),
        "1": .init(keyCode: 18, shift: false), "!": .init(keyCode: 18, shift: true),
        "2": .init(keyCode: 19, shift: false), "@": .init(keyCode: 19, shift: true),
        "3": .init(keyCode: 20, shift: false), "#": .init(keyCode: 20, shift: true),
        "4": .init(keyCode: 21, shift: false), "$": .init(keyCode: 21, shift: true),
        "6": .init(keyCode: 22, shift: false), "^": .init(keyCode: 22, shift: true),
        "5": .init(keyCode: 23, shift: false), "%": .init(keyCode: 23, shift: true),
        "=": .init(keyCode: 24, shift: false), "+": .init(keyCode: 24, shift: true),
        "9": .init(keyCode: 25, shift: false), "(": .init(keyCode: 25, shift: true),
        "7": .init(keyCode: 26, shift: false), "&": .init(keyCode: 26, shift: true),
        "-": .init(keyCode: 27, shift: false), "_": .init(keyCode: 27, shift: true),
        "8": .init(keyCode: 28, shift: false), "*": .init(keyCode: 28, shift: true),
        "0": .init(keyCode: 29, shift: false), ")": .init(keyCode: 29, shift: true),
        "]": .init(keyCode: 30, shift: false), "}": .init(keyCode: 30, shift: true),
        "o": .init(keyCode: 31, shift: false), "O": .init(keyCode: 31, shift: true),
        "u": .init(keyCode: 32, shift: false), "U": .init(keyCode: 32, shift: true),
        "[": .init(keyCode: 33, shift: false), "{": .init(keyCode: 33, shift: true),
        "i": .init(keyCode: 34, shift: false), "I": .init(keyCode: 34, shift: true),
        "p": .init(keyCode: 35, shift: false), "P": .init(keyCode: 35, shift: true),
        "\n": .init(keyCode: 36, shift: false),
        "l": .init(keyCode: 37, shift: false), "L": .init(keyCode: 37, shift: true),
        "j": .init(keyCode: 38, shift: false), "J": .init(keyCode: 38, shift: true),
        "'": .init(keyCode: 39, shift: false), "\"": .init(keyCode: 39, shift: true),
        "k": .init(keyCode: 40, shift: false), "K": .init(keyCode: 40, shift: true),
        ";": .init(keyCode: 41, shift: false), ":": .init(keyCode: 41, shift: true),
        "\\": .init(keyCode: 42, shift: false), "|": .init(keyCode: 42, shift: true),
        ",": .init(keyCode: 43, shift: false), "<": .init(keyCode: 43, shift: true),
        "/": .init(keyCode: 44, shift: false), "?": .init(keyCode: 44, shift: true),
        "n": .init(keyCode: 45, shift: false), "N": .init(keyCode: 45, shift: true),
        "m": .init(keyCode: 46, shift: false), "M": .init(keyCode: 46, shift: true),
        ".": .init(keyCode: 47, shift: false), ">": .init(keyCode: 47, shift: true),
        "\t": .init(keyCode: 48, shift: false),
        " ": .init(keyCode: 49, shift: false),
        "`": .init(keyCode: 50, shift: false), "~": .init(keyCode: 50, shift: true),
    ]
}
