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

// MARK: - Supporting Views

struct ModelRowView: View {
    let name: String
    let description: String
    let badge: String
    let badgeColor: Color
    let isDefault: Bool
    let isInstalled: Bool
    let onSetDefault: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)

                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else if isInstalled {
                Button("Set as Default") {
                    onSetDefault()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct WhisperModelRow: View {
    let size: String
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared

    var modelId: String { "whisper-\(size)" }
    var displayName: String {
        "Whisper " + size.capitalized
    }
    var sizeText: String {
        switch size {
        case "tiny": return "74 MB"
        case "base": return "142 MB"
        case "small": return "466 MB"
        case "medium": return "1.5 GB"
        case "large-v3": return "2.9 GB"
        default: return ""
        }
    }
    var badge: String {
        switch size {
        case "tiny": return "Fastest"
        case "medium": return "Recommended"
        case "large-v3": return "Most Accurate"
        default: return ""
        }
    }

    var isInstalled: Bool {
        modelManager.installedModels.contains(where: { $0.id == modelId })
    }

    var body: some View {
        ModelRowView(
            name: "\(displayName) (\(sizeText))",
            description: isInstalled ? "Downloaded" : "Not downloaded",
            badge: badge,
            badgeColor: size == "medium" ? .blue : .gray,
            isDefault: settings.defaultTranscriptionModel == modelId,
            isInstalled: isInstalled,
            onSetDefault: { settings.defaultTranscriptionModel = modelId }
        )
    }
}

struct CloudModelRow: View {
    let name: String
    let description: String
    let badge: String
    let badgeColor: Color
    let modelId: String
    let requiresKey: Bool
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)

                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if requiresKey {
                    Text("⚠️ API key required")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if settings.defaultTranscriptionModel == modelId {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Default")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else if !requiresKey {
                Button("Set as Default") {
                    settings.defaultTranscriptionModel = modelId
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Add API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct APIKeyField: View {
    let title: String
    @Binding var key: String
    @Binding var showKey: Bool
    let linkURL: String
    let linkText: String
    let icon: String
    let iconColor: Color
    let isTesting: Bool
    let testResult: String?
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Link(linkText, destination: URL(string: linkURL)!)
                    .font(.caption)
            }

            HStack {
                if showKey {
                    TextField("Enter API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Enter API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)

                Button(action: onTest) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(key.isEmpty || isTesting)
            }

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(result.contains("✓") ? .green : .red)
            }
        }
        .padding(12)
        .background(Color(.textBackgroundColor).opacity(0.2))
        .cornerRadius(8)
    }
}

struct FeatureCheckmark: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}

struct LocalModelManagementRow: View {
    let model: AIModel
    @ObservedObject private var modelManager = ModelManager.shared

    var isDownloaded: Bool {
        modelManager.installedModels.contains(where: { $0.id == model.id })
    }

    var body: some View {
        HStack {
            Text(model.name)
                .font(.subheadline)

            Spacer()

            if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Downloaded")
                        .font(.caption)
                }
            } else {
                Button("Download") {
                    downloadModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(ByteCountFormatter.string(fromByteCount: Int64(model.size), countStyle: .file))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func downloadModel() {
        modelManager.downloadModel(model) { result in
            switch result {
            case .success:
                debugLog("Model downloaded successfully")
            case .failure(let error):
                debugLog("Failed to download model: \(error)")
            }
        }
    }
}

#Preview {
    AIAndModelsView()
}
