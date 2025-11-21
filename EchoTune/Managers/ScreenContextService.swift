//
//  ScreenContextService.swift
//  EchoTune
//
//  Phase 6B: Screen Context Awareness
//  Captures screen content to improve transcription accuracy
//

import Foundation
import AppKit
import CoreGraphics
import Vision
import Combine

class ScreenContextService: ObservableObject {
    static let shared = ScreenContextService()

    @Published var isEnabled: Bool = false
    @Published var lastCapturedContext: ScreenContext?

    private let maxTextLength = 2000  // Limit context size for AI

    private init() {
        loadEnabledState()
        print("✅ ScreenContextService initialized")
    }

    // MARK: - Screen Context Capture

    func captureCurrentContext() -> ScreenContext? {
        guard isEnabled else {
            print("⚠️ Screen context disabled")
            return nil
        }

        guard checkScreenRecordingPermission() else {
            print("⚠️ Screen recording permission not granted")
            return nil
        }

        print("📸 Capturing screen context...")

        let appIdentifier = getFrontmostAppIdentifier()
        let appName = getFrontmostAppName()
        let screenshot = captureScreenshot()
        let extractedText = screenshot.flatMap { extractTextFromImage($0) }

        let context = ScreenContext(
            appIdentifier: appIdentifier,
            appName: appName,
            extractedText: extractedText,
            timestamp: Date()
        )

        lastCapturedContext = context

        if let text = extractedText {
            print("   ✅ Captured \(text.count) characters of context")
            print("   Preview: \(text.prefix(100))...")
        } else {
            print("   ℹ️ No text extracted from screen")
        }

        return context
    }

    private func captureScreenshot() -> CGImage? {
        // Get the main display
        guard let displayID = CGMainDisplayID() as CGDirectDisplayID? else {
            print("   ❌ Failed to get main display")
            return nil
        }

        // Capture screenshot
        guard let screenshot = CGDisplayCreateImage(displayID) else {
            print("   ❌ Failed to capture screenshot")
            return nil
        }

        return screenshot
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

            // Extract all recognized text
            var allText: [String] = []

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                allText.append(topCandidate.string)
            }

            let combinedText = allText.joined(separator: " ")

            // Limit text length
            let truncated = String(combinedText.prefix(maxTextLength))

            return truncated.isEmpty ? nil : truncated

        } catch {
            print("   ❌ Text recognition failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Permission Management

    func checkScreenRecordingPermission() -> Bool {
        // Check if we have screen recording permission
        // This is a runtime check - user must grant permission in System Preferences

        if #available(macOS 10.15, *) {
            // Try to capture a small screenshot to test permission
            let testImage = CGDisplayCreateImage(CGMainDisplayID())
            return testImage != nil
        }

        return false
    }

    func requestScreenRecordingPermission() {
        print("🔐 Requesting screen recording permission...")

        // Show alert to user
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
                // Open System Preferences
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Context Analysis

    func analyzeContext(_ context: ScreenContext) -> ContextAnalysis {
        guard let text = context.extractedText else {
            return ContextAnalysis(type: .unknown, keywords: [], suggestedPrompt: nil)
        }

        // Detect context type
        let type = detectContextType(text: text)

        // Extract keywords
        let keywords = extractKeywords(from: text)

        // Generate AI prompt suggestion
        let suggestedPrompt = generatePromptSuggestion(for: type, keywords: keywords)

        return ContextAnalysis(
            type: type,
            keywords: keywords,
            suggestedPrompt: suggestedPrompt
        )
    }

    private func detectContextType(text: String) -> ContextType {
        let lowercased = text.lowercased()

        // Code detection
        if lowercased.contains("func ") ||
           lowercased.contains("class ") ||
           lowercased.contains("def ") ||
           lowercased.contains("import ") ||
           lowercased.contains("const ") ||
           lowercased.contains("var ") ||
           lowercased.contains("{") && lowercased.contains("}") {
            return .code
        }

        // Email detection
        if lowercased.contains("@") && lowercased.contains(".com") ||
           lowercased.contains("subject:") ||
           lowercased.contains("dear ") ||
           lowercased.contains("sincerely") {
            return .email
        }

        // Document/Writing
        if text.split(separator: " ").count > 50 {
            return .document
        }

        // Chat/Messaging
        if lowercased.contains("send message") ||
           lowercased.contains("type a message") {
            return .chat
        }

        return .unknown
    }

    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - get capitalized words and technical terms
        let words = text.split(separator: " ")

        var keywords: Set<String> = []

        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)

            // Capitalized words (likely proper nouns)
            if cleaned.first?.isUppercase == true && cleaned.count > 2 {
                keywords.insert(String(cleaned))
            }

            // Technical terms (contains special characters)
            if cleaned.contains("_") || cleaned.contains("-") || cleaned.contains(".") {
                keywords.insert(String(cleaned))
            }
        }

        return Array(keywords.prefix(20))  // Limit to 20 keywords
    }

    private func generatePromptSuggestion(for type: ContextType, keywords: [String]) -> String {
        var prompt = "Context: "

        switch type {
        case .code:
            prompt += "You're writing code. "
            if !keywords.isEmpty {
                prompt += "Relevant terms: \(keywords.joined(separator: ", ")). "
            }
            prompt += "Preserve technical terminology, function names, and code structure."

        case .email:
            prompt += "You're writing an email. "
            prompt += "Use professional, formal tone with proper grammar."

        case .document:
            prompt += "You're writing a document. "
            prompt += "Use clear, well-structured prose."

        case .chat:
            prompt += "You're in a chat/messaging app. "
            prompt += "Use casual, conversational tone. Keep it concise."

        case .unknown:
            if !keywords.isEmpty {
                prompt += "Detected terms: \(keywords.joined(separator: ", ")). "
            }
            prompt += "Adapt tone based on content."
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

// MARK: - Supporting Types

struct ScreenContext {
    let appIdentifier: String?
    let appName: String?
    let extractedText: String?
    let timestamp: Date
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
