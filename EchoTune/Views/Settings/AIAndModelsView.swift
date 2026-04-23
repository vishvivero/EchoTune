//
//  AIAndModelsView.swift
//  EchoTune
//
//  Consolidated AI & Models Configuration
//  Groq-first onboarding with optional Gemini enhancement.
//

import SwiftUI

struct AIAndModelsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var aiEngine = AIEnhancementEngine.shared

    @State private var showGroqKey = false
    @State private var showGeminiKey = false
    @State private var testingKey: String?
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                modelSelectionSection

                Divider()
                    .padding(.vertical, 8)

                languageSection

                Divider()
                    .padding(.vertical, 8)

                apiKeysSection

                Divider()
                    .padding(.vertical, 8)

                aiEnhancementSection

                Divider()
                    .padding(.vertical, 8)

                localModelsSection
            }
            .padding(.vertical)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.teal)
                Text("Language")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Auto-detect language", isOn: $settings.autoDetectLanguage)
                    .padding(.horizontal)

                Picker("Language", selection: $settings.preferredLanguage) {
                    Text("English").tag("en")
                    Text("Hindi").tag("hi")
                    Text("Malayalam").tag("ml")
                    Text("Tamil").tag("ta")
                    Text("Telugu").tag("te")
                    Text("Bengali").tag("bn")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Japanese").tag("ja")
                    Text("Chinese").tag("zh")
                    Text("Korean").tag("ko")
                    Text("Arabic").tag("ar")
                    Text("Portuguese").tag("pt")
                    Text("Russian").tag("ru")
                    Text("Italian").tag("it")
                }
                .pickerStyle(.menu)
                .disabled(settings.autoDetectLanguage)
                .padding(.horizontal)

                Toggle("Translate to English", isOn: $settings.translateToEnglish)
                    .padding(.horizontal)

                Text("When enabled, speech in any language will be automatically translated to English. Uses Whisper's built-in translation — no extra API calls.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Active Transcription Model")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Local Models (On-Device)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                localModelsList

                Text("Cloud Models (Requires API Key)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)

                cloudModelsList
            }
        }
    }

    private var localModelsList: some View {
        VStack(spacing: 8) {
            ModelRowView(
                name: "Apple Speech",
                description: "Built-in, fast, multilingual",
                badge: "Built-in",
                badgeColor: .green,
                isDefault: settings.defaultTranscriptionModel == "apple-speech",
                isInstalled: true,
                onSetDefault: { settings.defaultTranscriptionModel = "apple-speech" }
            )

            ForEach(["tiny", "base", "small", "medium", "large-v3"], id: \.self) { size in
                WhisperModelRow(size: size)
            }
        }
    }

    private var cloudModelsList: some View {
        VStack(spacing: 8) {
            CloudModelRow(
                name: "Groq - Whisper Large v3 Turbo",
                description: "Recommended cloud transcription. Simple key flow and very fast results.",
                badge: "Recommended",
                badgeColor: .orange,
                modelId: "groq-whisper-large-v3-turbo",
                requiresKey: settings.groqAPIKey.isEmpty
            )
        }
    }

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("API Keys")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 16) {
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
                    onTest: { testGroqKey() }
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
                    onTest: { testGeminiKey() }
                )
            }
            .padding(.horizontal)
        }
    }

    private var aiEnhancementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("AI Text Enhancement")
                    .font(.headline)
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable AI Enhancement", isOn: $settings.aiEnhancementEnabled)
                    .padding(.horizontal)

                if settings.aiEnhancementEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Model", selection: $settings.selectedEnhancementModel) {
                            ForEach(AIEnhancementEngine.EnhancementModel.allCases, id: \.rawValue) { model in
                                Text(model.displayName).tag(model.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)

                        Text("Groq is the easiest setup. Gemini stays available as an optional secondary provider for enhancement.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Text("Features:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureCheckmark(text: "Grammar correction")
                            FeatureCheckmark(text: "Punctuation improvement")
                            FeatureCheckmark(text: "Remove filler words (um, uh, like)")
                            FeatureCheckmark(text: "Safer fallback to original transcript on error")
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var localModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                Text("Manage Local Models")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(modelManager.availableModels.filter { $0.category == .local && $0.id != "apple-speech" }) { model in
                    LocalModelManagementRow(model: model)
                }
            }
            .padding(.horizontal)
        }
    }

    private func testGroqKey() {
        testingKey = "groq"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = settings.groqAPIKey.hasPrefix("gsk_") ? "✓ Key looks valid" : "✗ Groq keys should usually start with gsk_"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "groq" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }

    private func testGeminiKey() {
        testingKey = "gemini"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = settings.geminiAPIKey.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "gemini" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }
}
