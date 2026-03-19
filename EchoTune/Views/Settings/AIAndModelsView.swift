//
//  AIAndModelsView.swift
//  EchoTune
//
//  Consolidated AI & Models Configuration
//  All AI-related features in one place
//

import SwiftUI

struct AIAndModelsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var cloudManager = CloudModelsManager.shared
    @ObservedObject private var aiEngine = AIEnhancementEngine.shared

    @State private var showGroqKey = false
    @State private var showOpenAIKey = false
    @State private var showClaudeKey = false
    @State private var showDeepgramKey = false
    @State private var testingKey: String?
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section A: Active Transcription Model
                modelSelectionSection

                Divider()
                    .padding(.vertical, 8)

                // Section A.5: Language Settings
                languageSection

                Divider()
                    .padding(.vertical, 8)

                // Section B: API Keys
                apiKeysSection

                Divider()
                    .padding(.vertical, 8)

                // Section C: AI Enhancement
                aiEnhancementSection

                Divider()
                    .padding(.vertical, 8)

                // Section D: Local Model Management
                localModelsSection
            }
            .padding(.vertical)
        }
    }

    // MARK: - Language Section

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

    // MARK: - Model Selection Section

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
                // Local Models
                Text("Local Models (On-Device)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                localModelsList

                // Cloud Models
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
            // Apple Speech
            ModelRowView(
                name: "Apple Speech",
                description: "Built-in, fast, multilingual",
                badge: "Built-in",
                badgeColor: .green,
                isDefault: settings.defaultTranscriptionModel == "apple-speech",
                isInstalled: true,
                onSetDefault: { settings.defaultTranscriptionModel = "apple-speech" }
            )

            // Whisper Models
            ForEach(["tiny", "base", "small", "medium", "large-v3"], id: \.self) { size in
                WhisperModelRow(size: size)
            }
        }
    }

    private var cloudModelsList: some View {
        VStack(spacing: 8) {
            // Groq
            CloudModelRow(
                name: "Groq - Whisper Large v3 Turbo",
                description: "Ultra-fast cloud transcription",
                badge: "Fastest",
                badgeColor: .orange,
                modelId: "groq-whisper-large-v3-turbo",
                requiresKey: settings.groqAPIKey.isEmpty
            )

            // Deepgram
            CloudModelRow(
                name: "Deepgram - Nova 2",
                description: "High accuracy, real-time",
                badge: "Accurate",
                badgeColor: .blue,
                modelId: "deepgram-nova-2",
                requiresKey: settings.deepgramAPIKey.isEmpty
            )
        }
    }

    // MARK: - API Keys Section

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
                // Groq
                APIKeyField(
                    title: "Groq API",
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

                // Deepgram
                APIKeyField(
                    title: "Deepgram API",
                    key: $settings.deepgramAPIKey,
                    showKey: $showDeepgramKey,
                    linkURL: "https://console.deepgram.com/signup",
                    linkText: "Get Free Credits",
                    icon: "waveform",
                    iconColor: .blue,
                    isTesting: testingKey == "deepgram",
                    testResult: testingKey == "deepgram" ? testResult : nil,
                    onTest: { testDeepgramKey() }
                )

                // OpenAI (for AI Enhancement)
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
                    onTest: { testOpenAIKey() }
                )

                // Anthropic
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
                    onTest: { testAnthropicKey() }
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - AI Enhancement Section

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

                        Text("Features:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureCheckmark(text: "Grammar correction")
                            FeatureCheckmark(text: "Punctuation improvement")
                            FeatureCheckmark(text: "Remove filler words (um, uh, like)")
                            FeatureCheckmark(text: "Professional tone")
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Local Models Management

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

            // Storage info - Commented out until storageInfo is added to ModelManager
            // if let storageInfo = modelManager.storageInfo {
            //     HStack {
            //         Image(systemName: "internaldrive")
            //             .foregroundColor(.secondary)
            //         Text("Storage Used:")
            //         Text(ByteCountFormatter.string(fromByteCount: storageInfo.usedSpace, countStyle: .file))
            //             .fontWeight(.semibold)
            //         Spacer()
            //     }
            //     .font(.caption)
            //     .foregroundColor(.secondary)
            //     .padding(.horizontal)
            // }
        }
    }

    // MARK: - Test Functions

    private func testGroqKey() {
        testingKey = "groq"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            testResult = settings.groqAPIKey.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "groq" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }

    private func testDeepgramKey() {
        testingKey = "deepgram"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testResult = settings.deepgramAPIKey.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "deepgram" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }

    private func testOpenAIKey() {
        testingKey = "openai"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testResult = settings.openaiAPIKey.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "openai" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }

    private func testAnthropicKey() {
        testingKey = "anthropic"
        testResult = "Testing..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            testResult = settings.claudeAPIKey.isEmpty ? "✗ No key" : "✓ Key set"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if testingKey == "anthropic" {
                    testingKey = nil
                    testResult = nil
                }
            }
        }
    }
}
