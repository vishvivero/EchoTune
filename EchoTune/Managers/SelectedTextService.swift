//
//  SelectedTextService.swift
//  EchoTune
//
//  Reads currently highlighted text in the frontmost application via
//  Accessibility (`kAXSelectedTextAttribute`), with a non-destructive
//  targeted ⌘C + full pasteboard restoration fallback for Electron/web apps.
//

import AppKit
import ApplicationServices
import Foundation

final class SelectedTextService {
    static let shared = SelectedTextService()

    private init() {}

    /// Synchronous AX read of the currently selected text (fast, side-effect free).
    func readSelectedTextViaAX() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        let axElement = unsafeBitCast(focused, to: AXUIElement.self)

        var selectedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
           let selected = selectedRef as? String {
            let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return selected
            }
        }
        return nil
    }

    /// Reads selected text via AX first, falling back to a targeted `⌘C` copy
    /// with full pasteboard restoration when Electron/Chromium returns nil on AX.
    @MainActor
    func captureSelectedText(allowCopyFallback: Bool = true) async -> String? {
        if let axText = readSelectedTextViaAX() {
            return axText
        }
        guard allowCopyFallback,
              AXIsProcessTrusted(),
              let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        let pb = NSPasteboard.general
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for t in item.types {
                if let d = item.data(forType: t) { dict[t] = d }
            }
            return dict
        }
        let beforeCount = pb.changeCount

        // Post targeted Cmd+C to the frontmost PID
        if let src = CGEventSource(stateID: .combinedSessionState),
           let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true), // 'c'
           let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.postToPid(frontApp.processIdentifier)
            up.postToPid(frontApp.processIdentifier)
        }

        // Wait up to 120ms for pasteboard change
        for _ in 0..<6 {
            try? await Task.sleep(nanoseconds: 20_000_000)
            if pb.changeCount != beforeCount { break }
        }

        var captured: String? = nil
        if pb.changeCount != beforeCount, let copied = pb.string(forType: .string) {
            let trimmed = copied.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                captured = copied
            }
        }

        // Restore user's original clipboard
        if pb.changeCount != beforeCount {
            pb.clearContents()
            let restored = savedItems.compactMap { map -> NSPasteboardItem? in
                guard !map.isEmpty else { return nil }
                let item = NSPasteboardItem()
                for (type, data) in map { item.setData(data, forType: type) }
                return item
            }
            if !restored.isEmpty {
                pb.writeObjects(restored)
            }
        }

        return captured
    }
}
