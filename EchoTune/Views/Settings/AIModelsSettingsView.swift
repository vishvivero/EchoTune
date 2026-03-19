//
//  AIModelsSettingsView.swift
//  EchoTune
//
//  Extracted from SettingsView.swift
//  AI Models settings tab: model selection, management, API keys,
//  language, text processing, and VAD configuration.
//

import SwiftUI

// MARK: - AI Models Settings (Composite View)

/// Combines model selection, management, API keys, text processing, and VAD into one tab.
struct AIModelsSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared

    @State private var showGroqKey = false
    @State private var showDeepgramKey = false
    @State private var testingKey: String?
    @State private var testResult: String?

    // Computed property for VAD sensitivity description
    private var sensitivityDescription: String {
        switch VADManager.shared.config.sensitivity {
        case .low:
            return "Best for quiet environments and soft speech. May detect more background noise."
        case .medium:
            return "Balanced detection for normal speaking volume. Recommended for most users."
        case .high:
            return "Only detects loud, clear speech. Use in noisy environments to avoid false positives."
        }
    }

    /// Only installed models should be selectable as default
    private var installedModelChoices: [AIModel] {
        modelManager.installedModels
    }

    /// Available models that are NOT yet installed (download candidates)
    private var notInstalledModels: [AIModel] {
        modelManager.availableModels.filter { model in
            !model.isInstalled && model.category != .comingSoon
        }
    }

    var body: some View {
        Form {
            // MARK: - Default Model
            Section("Default Model") {
                if let current = modelManager.currentModel {
                    HStack(spacing: 10) {
                        Image(systemName: current.category == .cloud ? "cloud.fill" : "desktopcomputer")
                            .foregroundColor(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.name)
                                .font(.headline)
                            Text(current.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(current.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                } else {
                    Text("No model selected")
                        .foregroundColor(.secondary)
                }

                if !installedModelChoices.isEmpty {
                    Picker("Switch default model", selection: Binding(
                        get: { modelManager.currentModel?.id ?? "" },
                        set: { newId in
                            if let model = modelManager.installedModels.first(where: { $0.id == newId }) {
                                _ = modelManager.setCurrentModel(model)
                            }
                        }
                    )) {
                        ForEach(installedModelChoices) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // MARK: - Installed Models
            Section("Installed Models") {
                if modelManager.installedModels.isEmpty {
                    Text("No models installed yet. Download one below.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(modelManager.installedModels) { model in
                        InstalledModelRow(model: model)
                    }
                }
            }

            // MARK: - Available Models (not installed)
            Section("Available Models") {
                if notInstalledModels.isEmpty {
                    Text("All available models are installed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(notInstalledModels) { model in
                        AvailableModelRow(model: model)
                    }
                }
            }

            // MARK: - API Keys (Groq & Deepgram only)
            Section("API Keys") {
                VStack(spacing: 12) {
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
                        onTest: { testKey("groq") }
                    )

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
                        onTest: { testKey("deepgram") }
                    )
                }
            }

            // MARK: - Language
            Section {
                Toggle("Auto-detect language", isOn: $settings.autoDetectLanguage)
                    .toggleStyle(.switch)

                if !settings.autoDetectLanguage {
                    Picker("Language", selection: $settings.preferredLanguage) {
                        Text("English").tag("en-US")
                        Text("Hindi — हिन्दी").tag("hi")
                        Text("Malayalam — മലയാളം").tag("ml")
                        Text("Tamil — தமிழ்").tag("ta")
                        Text("Telugu — తెలుగు").tag("te")
                        Text("Bengali — বাংলা").tag("bn")
                        Text("Spanish — Español").tag("es")
                        Text("French — Français").tag("fr")
                        Text("German — Deutsch").tag("de")
                        Text("Japanese — 日本語").tag("ja")
                        Text("Chinese — 中文").tag("zh")
                        Text("Korean — 한국어").tag("ko")
                        Text("Arabic — العربية").tag("ar")
                        Text("Portuguese — Português").tag("pt")
                        Text("Russian — Русский").tag("ru")
                        Text("Italian — Italiano").tag("it")
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Translate to English", isOn: $settings.translateToEnglish)
                    .toggleStyle(.switch)
            } header: {
                Text("Language")
            } footer: {
                if settings.translateToEnglish {
                    Text("Speech in any language will be translated to English. Uses Whisper's built-in translation — no extra API calls.")
                } else if settings.autoDetectLanguage {
                    Text("Whisper will automatically detect the spoken language and transcribe in that language.")
                } else {
                    Text("Transcription will be in the selected language.")
                }
            }

            // MARK: - Text Processing
            Section("Text Processing") {
                Toggle("Auto-Punctuation", isOn: $settings.autoPunctuation)

                Text("Automatically add periods, commas, and question marks based on speech patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Smart Capitalization", isOn: $settings.smartCapitalization)

                Text("Automatically capitalize the first word of sentences and proper nouns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Insert Space After Text", isOn: $settings.insertSpaceAfterText)

                Text("Add a space after inserted text for easier continuous dictation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Auto-Correct In-Speech Corrections", isOn: $settings.autoCorrection)

                Text("Automatically correct utterances like 'Sorry, I meant 8am' and clean up your final transcript.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            // MARK: - Voice Activity Detection (VAD)
            Section("Voice Activity Detection (VAD)") {
                Toggle("Enable Voice Detection", isOn: Binding(
                    get: { VADManager.shared.config.enabled },
                    set: { VADManager.shared.setEnabled($0) }
                ))

                Text("Automatically detect speech vs silence to skip transcription on non-speech audio.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if VADManager.shared.config.enabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detection Sensitivity")
                                .font(.caption)
                                .fontWeight(.medium)

                            Picker("Sensitivity", selection: Binding(
                                get: { VADManager.shared.config.sensitivity },
                                set: { VADManager.shared.updateSensitivity($0) }
                            )) {
                                Text("Low").tag(VADManager.Sensitivity.low)
                                Text("Medium").tag(VADManager.Sensitivity.medium)
                                Text("High").tag(VADManager.Sensitivity.high)
                            }
                            .pickerStyle(.segmented)

                            Text(sensitivityDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Detection Method:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("Energy-Based")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }

                            Text("Ultra-fast speech detection using audio energy analysis.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func testKey(_ provider: String) {
        testingKey = provider
        testResult = "Testing..."
        let key: String
        switch provider {
        case "groq": key = settings.groqAPIKey
        case "deepgram": key = settings.deepgramAPIKey
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

// MARK: - Installed Model Row

/// Shows an installed model with name, size, category badge, default checkmark, and actions.
struct InstalledModelRow: View {
    let model: AIModel
    @ObservedObject private var modelManager = ModelManager.shared

    private var isDefault: Bool {
        modelManager.currentModel?.id == model.id
    }

    private var categoryLabel: String {
        switch model.category {
        case .local: return "Local"
        case .cloud: return "Cloud"
        default: return model.category.rawValue
        }
    }

    private var categoryColor: Color {
        model.category == .cloud ? .blue : .green
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(model.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary)
                        .cornerRadius(4)

                    Text(categoryLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(categoryColor)
                        .cornerRadius(4)
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
            } else {
                Button("Set Default") {
                    _ = modelManager.setCurrentModel(model)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Delete button for local non-built-in models that aren't current default
            if model.category == .local && !model.isBuiltIn && !isDefault {
                Button(role: .destructive) {
                    _ = modelManager.deleteModel(model)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete this model")
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Available Model Row (not installed)

/// Shows a model available for download with a download button and size.
struct AvailableModelRow: View {
    let model: AIModel
    @ObservedObject private var modelManager = ModelManager.shared

    private var isDownloading: Bool {
        modelManager.isDownloading && modelManager.currentDownloadModel?.id == model.id
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(model.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary)
                        .cornerRadius(4)

                    Text(model.language)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isDownloading {
                ProgressView(value: modelManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                Text("\(Int(modelManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 35)
            } else if modelManager.canDownload(model) {
                Button {
                    modelManager.downloadModel(model) { _ in }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(modelManager.isDownloading)
            } else {
                Text("Not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
