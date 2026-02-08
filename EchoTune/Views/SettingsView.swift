//
//  SettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//  Redesigned with macOS Ventura-style sidebar navigation
//  Streamlined from 9 tabs to 6 tabs
//

import SwiftUI

// MARK: - Settings Tab Definition

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case aiModels = "AI Models"
    case aiAutomation = "AI & Automation"
    case hotkeys = "Hotkeys"
    case permissionsPrivacy = "Permissions & Privacy"
    case aboutLicense = "About & License"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .aiModels: return "cpu"
        case .aiAutomation: return "sparkles"
        case .hotkeys: return "keyboard"
        case .permissionsPrivacy: return "lock.shield"
        case .aboutLicense: return "key.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .aiModels: return .blue
        case .aiAutomation: return .purple
        case .hotkeys: return .orange
        case .permissionsPrivacy: return .red
        case .aboutLicense: return .teal
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar navigation
            settingsSidebar

            // Divider
            Divider()

            // Right content area
            settingsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Content

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .aiModels:
                    AIModelsSettingsView()
                case .aiAutomation:
                    AIAutomationSettingsView()
                case .hotkeys:
                    HotkeysView()
                case .permissionsPrivacy:
                    PermissionsPrivacySettingsView()
                case .aboutLicense:
                    AboutLicenseSettingsView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

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

// MARK: - AI & Automation Settings (Composite View)

/// Combines AI enhancement, Power Modes, and Trigger Words.
struct AIAutomationSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var aiEngine = AIEnhancementEngine.shared

    @State private var showOpenAIKey = false
    @State private var showClaudeKey = false
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

// MARK: - Permissions & Privacy Settings (Composite View)

/// Merges Permissions and Privacy into one tab.
struct PermissionsPrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                PermissionsContentView()
            } header: {
                Text("Permissions")
            }

            Section {
                PrivacySettingsView()
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About & License Settings (Composite View)

/// Combines License activation, updates, and reset.
struct AboutLicenseSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LicenseSettingsView()
            } header: {
                Text("License")
            }

            Section("Updates") {
                Toggle("Automatic Updates", isOn: $settings.automaticUpdatesEnabled)

                Text("Automatically download and install updates in the background")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if settings.automaticUpdatesEnabled {
                    Toggle("Include Beta Updates", isOn: $settings.checkForBetaUpdates)
                        .padding(.leading, 20)

                    Text("Beta updates include experimental features and may be less stable")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.leading, 40)
                }

                Button("Check for Updates Now") {
                    checkForUpdates()
                }
                .buttonStyle(.bordered)
                .padding(.leading, 20)
            }

            Section("Reset") {
                Button("Reset All Settings") {
                    resetAllSettings()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)

                Text("This will reset all settings to their default values. This action cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .formStyle(.grouped)
    }

    private func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "You are running the latest version of EchoTune.\n\nVersion: 1.0.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all EchoTune settings to their default values. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            settings.resetToDefaults()
            debugLog("✓ Settings reset to defaults")
        }
    }
}

// MARK: - Sidebar Row

struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : tab.iconColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? tab.iconColor : tab.iconColor.opacity(0.15))
                )

            Text(tab.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
