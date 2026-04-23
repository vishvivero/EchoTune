//
//  AIAutomationSettingsView.swift
//  EchoTune
//
//  Extracted from SettingsView.swift
//  AI & Automation settings tab: AI text enhancement, API keys,
//  Power Modes, and Trigger Words.
//

import SwiftUI

// MARK: - AI & Automation Settings (Composite View)

/// Combines AI enhancement, Power Modes, and Trigger Words.
struct AIAutomationSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var aiEngine = AIEnhancementEngine.shared

    @State private var showOpenAIKey = false
    @State private var showClaudeKey = false
    @State private var showGeminiKey = false
    @State private var testingKey: String?
    @State private var testResult: String?

    var body: some View {
        Form {
            // MARK: AI Enhancement (from AIAndModelsView)
            Section("AI Text Enhancement") {
                Toggle("Enable AI Enhancement", isOn: $settings.aiEnhancementEnabled)

                if settings.aiEnhancementEnabled {
                    Picker("Model", selection: $settings.selectedEnhancementModel) {
                        ForEach(AIEnhancementEngine.EnhancementModel.allCases, id: \.rawValue) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureCheckmark(text: "Grammar correction")
                        FeatureCheckmark(text: "Punctuation improvement")
                        FeatureCheckmark(text: "Remove filler words (um, uh, like)")
                        FeatureCheckmark(text: "Professional tone")
                    }
                }
            }

            // MARK: AI API Keys (OpenAI & Anthropic for enhancement)
            Section("AI Enhancement API Keys") {
                VStack(spacing: 12) {
                    APIKeyField(
                        title: "Google Gemini API (recommended free)",
                        key: $settings.geminiAPIKey,
                        showKey: $showGeminiKey,
                        linkURL: "https://aistudio.google.com/app/apikey",
                        linkText: "Get Free Key",
                        icon: "sparkles.rectangle.stack",
                        iconColor: .blue,
                        isTesting: testingKey == "gemini",
                        testResult: testingKey == "gemini" ? testResult : nil,
                        onTest: { testKey("gemini") }
                    )

                    APIKeyField(
                        title: "OpenAI API (for AI Enhancement)",
                        key: $settings.openaiAPIKey,
                        showKey: $showOpenAIKey,
                        linkURL: "https://platform.openai.com/api-keys",
                        linkText: "Get Key",
                        icon: "sparkles",
                        iconColor: .green,
                        isTesting: testingKey == "openai",
                        testResult: testingKey == "openai" ? testResult : nil,
                        onTest: { testKey("openai") }
                    )

                    APIKeyField(
                        title: "Anthropic API (for AI Enhancement)",
                        key: $settings.claudeAPIKey,
                        showKey: $showClaudeKey,
                        linkURL: "https://console.anthropic.com/",
                        linkText: "Get Key",
                        icon: "brain",
                        iconColor: .purple,
                        isTesting: testingKey == "anthropic",
                        testResult: testingKey == "anthropic" ? testResult : nil,
                        onTest: { testKey("anthropic") }
                    )
                }
            }

            // MARK: Power Modes
            Section {
                PowerModesViewContent()
            } header: {
                Text("Power Modes")
            }

            // MARK: Trigger Words
            Section {
                TriggerWordsViewContent()
            } header: {
                Text("Trigger Words")
            }
        }
        .formStyle(.grouped)
    }

    private func testKey(_ provider: String) {
        testingKey = provider
        testResult = "Testing..."
        let key: String
        switch provider {
        case "gemini": key = settings.geminiAPIKey
        case "openai": key = settings.openaiAPIKey
        case "anthropic": key = settings.claudeAPIKey
        default: key = ""
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = key.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == provider {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }
}
