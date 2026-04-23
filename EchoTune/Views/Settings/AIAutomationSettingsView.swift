//
//  AIAutomationSettingsView.swift
//  EchoTune
//
//  AI & Automation settings tab: Groq-first enhancement, optional Gemini,
//  power modes, and trigger words.
//

import SwiftUI

struct AIAutomationSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var aiEngine = AIEnhancementEngine.shared

    @State private var showGroqKey = false
    @State private var showGeminiKey = false
    @State private var testingKey: String?
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("AI Text Enhancement") {
                Toggle("Enable AI Enhancement", isOn: $settings.aiEnhancementEnabled)

                if settings.aiEnhancementEnabled {
                    Picker("Model", selection: $settings.selectedEnhancementModel) {
                        ForEach(AIEnhancementEngine.EnhancementModel.allCases, id: \.rawValue) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Groq is the recommended default because setup is simpler. Gemini stays available as an optional secondary enhancement provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        FeatureCheckmark(text: "Grammar correction")
                        FeatureCheckmark(text: "Punctuation improvement")
                        FeatureCheckmark(text: "Remove filler words (um, uh, like)")
                        FeatureCheckmark(text: "Cleaner phrasing without changing intent")
                    }
                }
            }

            Section("AI Provider Keys") {
                VStack(spacing: 12) {
                    APIKeyField(
                        title: "Groq API (recommended)",
                        key: $settings.groqAPIKey,
                        showKey: $showGroqKey,
                        linkURL: "https://console.groq.com/keys",
                        linkText: "Get Free Key",
                        icon: "bolt.fill",
                        iconColor: .orange,
                        isTesting: testingKey == "groq",
                        testResult: testingKey == "groq" ? testResult : nil,
                        onTest: { testKey("groq") }
                    )

                    APIKeyField(
                        title: "Google Gemini API (optional)",
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
                }
            }

            Section {
                PowerModesViewContent()
            } header: {
                Text("Power Modes")
            }

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
        case "groq": key = settings.groqAPIKey
        case "gemini": key = settings.geminiAPIKey
        default: key = ""
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if provider == "groq" {
                testResult = key.hasPrefix("gsk_") ? "✓ Key looks valid" : "✗ Groq keys should usually start with gsk_"
            } else {
                testResult = key.isEmpty ? "✗ No key" : "✓ Key set"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == provider {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }
}
