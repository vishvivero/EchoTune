//
//  ScreenContextService.swift
//  EchoTune
//
//  Phase 6B+: Enhanced Screen Context Awareness
//  Captures screen content, clipboard, selected text, and browser URL
//  to provide rich context for AI-enhanced transcription
//

import Foundation
import AppKit
import CoreGraphics
import Vision
import ScreenCaptureKit
import Combine

class ScreenContextService: ObservableObject {
    static let shared = ScreenContextService()

    @Published var isEnabled: Bool = false
    @Published var lastCapturedContext: ScreenContext?

    private let maxTextLength = 2000  // Limit context size for AI
    private let maxOCRTextLength = 1500  // OCR portion limit

    private init() {
        loadEnabledState()
        print("✅ ScreenContextService initialized")
    }

    // MARK: - Screen Context Capture (Enhanced)

    /// Captures full context: OCR screen text, clipboard, selected text, active app, browser URL
    func captureCurrentContext() -> ScreenContext? {
        guard isEnabled else {
            print("⚠️ Screen context disabled")
            return nil
        }

        print("📸 Capturing enhanced screen context...")

        let appIdentifier = getFrontmostAppIdentifier()
        let appName = getFrontmostAppName()

        // 1. Capture clipboard text (fast, no permissions needed)
        let clipboardText = captureClipboardText()

        // 2. Capture selected text via Accessibility API
        let selectedText = captureSelectedText()

        // 3. Capture browser URL if in a browser
        var browserURL: String? = nil
        var browserTitle: String? = nil
        if let appId = appIdentifier, isBrowser(appId) {
            let browserContext = BrowserContextDetector.shared.detectContext()
            browserURL = browserContext?.url
            browserTitle = browserContext?.title
        }

        // 4. Capture screen OCR (uses ScreenCaptureKit for frontmost window)
        var extractedText: String? = nil
        if checkScreenRecordingPermission() {
            extractedText = captureAndOCRFrontmostWindow()
        }

        let context = ScreenContext(
            appIdentifier: appIdentifier,
            appName: appName,
            extractedText: extractedText,
            clipboardText: clipboardText,
            selectedText: selectedText,
            browserURL: browserURL,
            browserTitle: browserTitle,
            timestamp: Date()
        )

        lastCapturedContext = context

        // Debug logging
        if let text = extractedText {
            print("   ✅ OCR: \(text.count) chars")
        }
        if let clip = clipboardText {
            print("   ✅ Clipboard: \(clip.count) chars")
        }
        if let sel = selectedText {
            print("   ✅ Selected text: \(sel.count) chars")
        }
        if let url = browserURL {
            print("   ✅ Browser URL: \(url)")
        }

        return context
    }

    // MARK: - Clipboard Text Capture

    private func captureClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Limit to reasonable size
        return String(trimmed.prefix(500))
    }

    // MARK: - Selected Text via Accessibility API

    private func captureSelectedText() -> String? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        // Get the focused application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Get the focused UI element
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        // Try to get selected text
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)

        guard textResult == .success, let text = selectedTextValue as? String else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(500))
    }

    // MARK: - ScreenCaptureKit: Frontmost Window OCR

    /// Captures the frontmost window using ScreenCaptureKit and runs OCR via Vision
    private func captureAndOCRFrontmostWindow() -> String? {
        // Use synchronous CGWindowList approach (SCShareableContent is async and complex for this use case)
        // This captures just the frontmost window, not the full screen
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return captureFullScreenOCR() // Fallback
        }

        let pid = frontApp.processIdentifier

        // Get window list for the frontmost app
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return captureFullScreenOCR()
        }

        // Find the frontmost window for this app
        let appWindows = windowList.filter { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return ownerPID == pid
        }

        guard let firstWindow = appWindows.first,
              let windowID = firstWindow[kCGWindowNumber as String] as? CGWindowID else {
            return captureFullScreenOCR()
        }

        // Capture just this window
        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return captureFullScreenOCR()
        }

        return extractTextFromImage(windowImage)
    }

    /// Fallback: capture the full main display
    private func captureFullScreenOCR() -> String? {
        guard let screenshot = CGDisplayCreateImage(CGMainDisplayID()) else {
            print("   ❌ Failed to capture screenshot")
            return nil
        }
        return extractTextFromImage(screenshot)
    }

    private func extractTextFromImage(_ image: CGImage) -> String? {
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast  // Fast for real-time use
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])

            guard let observations = request.results else {
                return nil
            }

            var allText: [String] = []
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                allText.append(topCandidate.string)
            }

            let combinedText = allText.joined(separator: " ")
            let truncated = String(combinedText.prefix(maxOCRTextLength))
            return truncated.isEmpty ? nil : truncated

        } catch {
            print("   ❌ Text recognition failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Permission Management

    func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 15.0, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            // Fallback: check via PermissionsManager (which uses non-intrusive check)
            return PermissionsManager.shared.hasScreenRecordingPermission
        }
    }

    func requestScreenRecordingPermission() {
        print("🔐 Requesting screen recording permission...")

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            EchoTune needs screen recording permission to capture context from your screen for improved transcription accuracy.

            This helps the AI understand what you're working on (e.g., code, emails, documents) and provide better results.

            Please grant permission in System Preferences > Privacy & Security > Screen Recording.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Context Analysis (Enhanced)

    func analyzeContext(_ context: ScreenContext) -> ContextAnalysis {
        // Combine all available text sources for analysis
        var combinedText = ""

        if let text = context.extractedText {
            combinedText += text
        }
        if let selected = context.selectedText {
            combinedText += " " + selected
        }
        if let clip = context.clipboardText {
            combinedText += " " + clip
        }

        guard !combinedText.isEmpty else {
            return ContextAnalysis(type: .unknown, keywords: [], suggestedPrompt: nil)
        }

        let type = detectContextType(text: combinedText, appIdentifier: context.appIdentifier, browserURL: context.browserURL)
        let keywords = extractKeywords(from: combinedText)
        let suggestedPrompt = generatePromptSuggestion(for: type, keywords: keywords, context: context)

        return ContextAnalysis(
            type: type,
            keywords: keywords,
            suggestedPrompt: suggestedPrompt
        )
    }

    private func detectContextType(text: String, appIdentifier: String?, browserURL: String?) -> ContextType {
        // App-based detection (most reliable)
        if let appId = appIdentifier {
            let codeApps = ["com.microsoft.VSCode", "com.apple.dt.Xcode", "com.jetbrains.intellij",
                            "com.sublimetext.4", "com.github.atom", "com.panic.Nova"]
            let emailApps = ["com.apple.mail", "com.microsoft.Outlook"]
            let chatApps = ["com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.electron.whatsapp",
                            "com.telegram.desktop"]
            let noteApps = ["com.apple.Notes", "md.obsidian", "com.bear-writer.Bear"]

            if codeApps.contains(appId) { return .code }
            if emailApps.contains(appId) { return .email }
            if chatApps.contains(appId) { return .chat }
            if noteApps.contains(appId) { return .document }
        }

        // URL-based detection
        if let url = browserURL?.lowercased() {
            if url.contains("github.com") || url.contains("stackoverflow.com") || url.contains("developer.apple.com") {
                return .code
            }
            if url.contains("mail.google.com") || url.contains("outlook.com") {
                return .email
            }
            if url.contains("slack.com") || url.contains("discord.com") || url.contains("web.whatsapp.com") {
                return .chat
            }
            if url.contains("docs.google.com") || url.contains("notion.so") {
                return .document
            }
        }

        // Text-based detection (fallback)
        let lowercased = text.lowercased()

        if lowercased.contains("func ") || lowercased.contains("class ") || lowercased.contains("def ") ||
           lowercased.contains("import ") || lowercased.contains("const ") ||
           (lowercased.contains("{") && lowercased.contains("}")) {
            return .code
        }

        if lowercased.contains("subject:") || lowercased.contains("dear ") || lowercased.contains("sincerely") {
            return .email
        }

        if text.split(separator: " ").count > 50 {
            return .document
        }

        if lowercased.contains("send message") || lowercased.contains("type a message") {
            return .chat
        }

        return .unknown
    }

    private func extractKeywords(from text: String) -> [String] {
        let words = text.split(separator: " ")
        var keywords: Set<String> = []

        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if cleaned.first?.isUppercase == true && cleaned.count > 2 {
                keywords.insert(String(cleaned))
            }
            if cleaned.contains("_") || cleaned.contains("-") || cleaned.contains(".") {
                keywords.insert(String(cleaned))
            }
        }

        return Array(keywords.prefix(20))
    }

    private func generatePromptSuggestion(for type: ContextType, keywords: [String], context: ScreenContext) -> String {
        var prompt = "SCREEN CONTEXT:\n"

        // App name
        if let appName = context.appName {
            prompt += "Active App: \(appName)\n"
        }

        // Browser URL
        if let url = context.browserURL {
            prompt += "Website: \(url)\n"
        }

        // Browser page title
        if let title = context.browserTitle {
            prompt += "Page Title: \(title)\n"
        }

        // Context type
        switch type {
        case .code:
            prompt += "Context: User is working with code/technical content. Preserve technical terminology, function names, variable names, and code-related jargon.\n"
        case .email:
            prompt += "Context: User is composing an email. Use professional, formal tone with proper grammar.\n"
        case .document:
            prompt += "Context: User is writing a document. Use clear, well-structured prose.\n"
        case .chat:
            prompt += "Context: User is in a messaging/chat app. Use casual, conversational tone. Keep it concise.\n"
        case .unknown:
            prompt += "Context: General usage.\n"
        }

        // Selected text (what user is actively working with)
        if let selected = context.selectedText {
            prompt += "Selected text (user's focus): \(String(selected.prefix(300)))\n"
        }

        // Clipboard (recent copy/paste)
        if let clip = context.clipboardText {
            prompt += "Recent clipboard: \(String(clip.prefix(200)))\n"
        }

        // Keywords from screen
        if !keywords.isEmpty {
            prompt += "Visible terms: \(keywords.prefix(10).joined(separator: ", "))\n"
        }

        // OCR text snippet
        if let screenText = context.extractedText {
            let snippet = String(screenText.prefix(300))
            prompt += "Screen text snippet: \(snippet)\n"
        }

        return prompt
    }

    // MARK: - Helper Methods

    private func getFrontmostAppIdentifier() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func getFrontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    private func isBrowser(_ bundleIdentifier: String) -> Bool {
        let browsers: Set<String> = [
            "com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox",
            "com.microsoft.edgemac", "company.thebrowser.Browser", "com.brave.Browser",
            "com.operasoftware.Opera", "com.vivaldi.Vivaldi"
        ]
        return browsers.contains(bundleIdentifier)
    }

    // MARK: - Settings

    private func loadEnabledState() {
        isEnabled = UserDefaults.standard.bool(forKey: "screenContextEnabled")
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "screenContextEnabled")

        if enabled && !checkScreenRecordingPermission() {
            requestScreenRecordingPermission()
        }

        print(enabled ? "✅ Screen context enabled" : "❌ Screen context disabled")
    }
}

// MARK: - Enhanced Supporting Types

struct ScreenContext {
    let appIdentifier: String?
    let appName: String?
    let extractedText: String?          // OCR from screen
    let clipboardText: String?          // Last clipboard content
    let selectedText: String?           // Currently selected text (Accessibility API)
    let browserURL: String?             // Current browser URL
    let browserTitle: String?           // Current browser page title
    let timestamp: Date

    /// Convenience initializer for backward compatibility
    init(appIdentifier: String?, appName: String?, extractedText: String?, timestamp: Date) {
        self.appIdentifier = appIdentifier
        self.appName = appName
        self.extractedText = extractedText
        self.clipboardText = nil
        self.selectedText = nil
        self.browserURL = nil
        self.browserTitle = nil
        self.timestamp = timestamp
    }

    /// Full initializer with all context sources
    init(appIdentifier: String?, appName: String?, extractedText: String?,
         clipboardText: String?, selectedText: String?,
         browserURL: String?, browserTitle: String?,
         timestamp: Date) {
        self.appIdentifier = appIdentifier
        self.appName = appName
        self.extractedText = extractedText
        self.clipboardText = clipboardText
        self.selectedText = selectedText
        self.browserURL = browserURL
        self.browserTitle = browserTitle
        self.timestamp = timestamp
    }

    /// Returns true if any meaningful context was captured
    var hasContext: Bool {
        return extractedText != nil || clipboardText != nil || selectedText != nil || browserURL != nil
    }
}

struct ContextAnalysis {
    let type: ContextType
    let keywords: [String]
    let suggestedPrompt: String?
}

enum ContextType {
    case code
    case email
    case document
    case chat
    case unknown
}
