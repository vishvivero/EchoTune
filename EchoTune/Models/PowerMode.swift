//
//  PowerMode.swift
//  EchoTune
//
//  Phase 6B: Power Modes - Context-Aware Configurations
//  Automatically switches settings based on active app/website
//

import Foundation
import SwiftUI

struct PowerMode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var isEnabled: Bool

    // Trigger conditions (at least one must be specified)
    var appBundleIdentifiers: [String]      // e.g., ["com.tinyspeck.slackmacgap"]
    var websitePatterns: [String]            // e.g., ["*.slack.com", "*.github.com"]

    // Transcription settings
    var useWhisper: Bool
    var whisperModelSize: String?            // "tiny", "base", "small", "medium", "large-v3"
    var cloudModelId: String?                // "groq-whisper-large-v3-turbo"
    var preferredLanguage: String?           // "en-US"

    // AI Enhancement settings
    var aiEnhancementEnabled: Bool
    var enhancementModel: String?            // "gpt-4o-mini", "claude-3-5-sonnet-20241022"
    var customEnhancementPrompt: String?

    // Behavior settings
    var autoSendEnabled: Bool
    var useShiftReturn: Bool                 // If true, sends Shift+Return instead of Return

    // Metadata
    var dateCreated: Date
    var dateModified: Date
    var useCount: Int                        // Track how often this mode is triggered

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         isEnabled: Bool = true,
         appBundleIdentifiers: [String] = [],
         websitePatterns: [String] = [],
         useWhisper: Bool = true,
         whisperModelSize: String? = nil,
         cloudModelId: String? = nil,
         preferredLanguage: String? = nil,
         aiEnhancementEnabled: Bool = false,
         enhancementModel: String? = nil,
         customEnhancementPrompt: String? = nil,
         autoSendEnabled: Bool = false,
         useShiftReturn: Bool = false) {

        self.id = id
        self.name = name
        self.emoji = emoji
        self.isEnabled = isEnabled
        self.appBundleIdentifiers = appBundleIdentifiers
        self.websitePatterns = websitePatterns
        self.useWhisper = useWhisper
        self.whisperModelSize = whisperModelSize
        self.cloudModelId = cloudModelId
        self.preferredLanguage = preferredLanguage
        self.aiEnhancementEnabled = aiEnhancementEnabled
        self.enhancementModel = enhancementModel
        self.customEnhancementPrompt = customEnhancementPrompt
        self.autoSendEnabled = autoSendEnabled
        self.useShiftReturn = useShiftReturn
        self.dateCreated = Date()
        self.dateModified = Date()
        self.useCount = 0
    }

    // Check if this Power Mode matches the current context
    func matches(appIdentifier: String?, websiteURL: String?) -> Bool {
        guard isEnabled else { return false }

        // Check app identifier match
        if let appId = appIdentifier, !appBundleIdentifiers.isEmpty {
            if appBundleIdentifiers.contains(appId) {
                return true
            }
        }

        // Check website pattern match
        if let url = websiteURL, !websitePatterns.isEmpty {
            for pattern in websitePatterns {
                if matchesPattern(url: url, pattern: pattern) {
                    return true
                }
            }
        }

        return false
    }

    private func matchesPattern(url: String, pattern: String) -> Bool {
        // Simple wildcard matching
        // Pattern: "*.slack.com" matches "app.slack.com", "myworkspace.slack.com"
        // Pattern: "github.com/*" matches "github.com/user/repo"

        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(url.startIndex..., in: url)
        return regex.firstMatch(in: url, options: [], range: range) != nil
    }

    mutating func incrementUseCount() {
        useCount += 1
        dateModified = Date()
    }
}

// MARK: - Predefined Power Modes

extension PowerMode {
    static let defaultModes: [PowerMode] = [
        // Slack - Fast, auto-send
        PowerMode(
            name: "Slack Messages",
            emoji: "💬",
            appBundleIdentifiers: ["com.tinyspeck.slackmacgap"],
            websitePatterns: ["*.slack.com"],
            cloudModelId: "groq-whisper-large-v3-turbo",
            aiEnhancementEnabled: true,
            enhancementModel: "gpt-4o-mini",
            customEnhancementPrompt: "Format like a casual chat message. Keep it conversational and concise.",
            autoSendEnabled: true
        ),

        // Code/Technical - Precise, no auto-send
        PowerMode(
            name: "Code & Technical",
            emoji: "💻",
            appBundleIdentifiers: [
                "com.microsoft.VSCode",
                "com.apple.dt.Xcode",
                "com.jetbrains.intellij",
                "com.sublimetext.4"
            ],
            websitePatterns: ["*.github.com", "*.stackoverflow.com"],
            cloudModelId: "groq-whisper-large-v3-turbo",
            aiEnhancementEnabled: true,
            enhancementModel: "gpt-4o",
            customEnhancementPrompt: "Maintain technical accuracy. Preserve code-related terms, variable names, and technical jargon exactly as spoken. Format code blocks with proper syntax.",
            autoSendEnabled: false
        ),

        // Email - Professional tone
        PowerMode(
            name: "Email & Docs",
            emoji: "📧",
            appBundleIdentifiers: [
                "com.apple.mail",
                "com.microsoft.Outlook",
                "com.google.Chrome.app.Gmail"
            ],
            websitePatterns: ["mail.google.com", "outlook.com", "*.notion.so"],
            useWhisper: true,
            whisperModelSize: "base",
            aiEnhancementEnabled: true,
            enhancementModel: "gpt-4o",
            customEnhancementPrompt: "Use professional, formal tone. Proper grammar, complete sentences. Format as clear paragraphs suitable for business communication.",
            autoSendEnabled: false
        ),

        // Quick Notes - Fast, minimal processing
        PowerMode(
            name: "Quick Notes",
            emoji: "📝",
            appBundleIdentifiers: ["com.apple.Notes", "md.obsidian", "com.bear-writer.Bear"],
            useWhisper: true,
            whisperModelSize: "tiny",
            aiEnhancementEnabled: false,
            autoSendEnabled: false
        ),

        // Meetings - Long-form, accurate
        PowerMode(
            name: "Meetings & Calls",
            emoji: "🎙️",
            appBundleIdentifiers: [
                "us.zoom.xos",
                "com.microsoft.teams2",
                "com.google.Chrome.app.Meet"
            ],
            cloudModelId: "groq-whisper-large-v3-turbo",
            aiEnhancementEnabled: true,
            enhancementModel: "gpt-4o",
            customEnhancementPrompt: "Format as meeting notes. Use bullet points for action items. Preserve names, dates, and key decisions.",
            autoSendEnabled: false
        ),

        // Social Media - Casual, emoji-friendly
        PowerMode(
            name: "Social Media",
            emoji: "🌟",
            appBundleIdentifiers: ["com.electron.whatsapp", "com.telegram.desktop"],
            websitePatterns: ["*.twitter.com", "*.x.com", "*.linkedin.com", "*.facebook.com"],
            cloudModelId: "groq-whisper-large-v3-turbo",
            aiEnhancementEnabled: true,
            enhancementModel: "gpt-4o-mini",
            customEnhancementPrompt: "Format like a modern social media post. Short lines, natural breaks, emoji-friendly. Casual and engaging tone.",
            autoSendEnabled: true
        )
    ]
}
