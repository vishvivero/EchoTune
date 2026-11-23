//
//  SettingsCompositeViews.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var dictionary = DictionaryManager.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch EchoTune at Login", isOn: $launchAtLogin.isEnabled)
                    .help("Start EchoTune automatically when you log in to your Mac.")
            }
            .padding(.bottom, 8)

            Section("Dictation Preview") {
                Picker("Preview Style", selection: $settings.recorderStyle) {
                    ForEach(RecorderStyle.userFacingOptions) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .help("How the live dictation preview appears while you speak.")
                .pickerStyle(.inline)
                Text(settings.recorderStyle.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Preview Speed", selection: $settings.previewTier) {
                    ForEach(PreviewTier.allCases) { tier in
                        Text(tier.title).tag(tier)
                    }
                }
                .help("How often the local transcription preview updates while recording.")
                .pickerStyle(.inline)
                Text(settings.previewTier.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Section("Transcription Output") {
                // Auto-Punctuation toggle removed for 4.0.0 — it never did
                // anything (punctuation is whatever the model emits).
                Toggle("Smart Capitalization", isOn: $settings.smartCapitalization)
                    .help("Capitalize the start of sentences and proper nouns automatically.")
                
                Toggle("Insert Space After Paste", isOn: $settings.insertSpaceAfterText)
                    .help("Automatically append a trailing space when pasting transcription.")
            }
            .padding(.bottom, 8)
            
            Section("Language & Translation") {
                Toggle("Auto-Detect Language", isOn: $settings.autoDetectLanguage)
                
                if !settings.autoDetectLanguage {
                    Picker("Primary Language", selection: $settings.preferredLanguage) {
                        Text("English").tag("en-US")
                        Text("Spanish").tag("es-ES")
                        Text("French").tag("fr-FR")
                        Text("German").tag("de-DE")
                    }
                }
                
                Toggle("Translate to English", isOn: $settings.translateToEnglish)
                    .help("Translate foreign speech to English on-the-fly.")
            }
            .padding(.bottom, 8)

            Section("Vocabulary") {
                Toggle("Apply my vocabulary to transcribed text", isOn: $settings.vocabularyBiasingEnabled)
                    .help("Replace dictionary entries and learned corrections in the finished transcript.")
                Text("Corrections are applied after transcription. Decoder-side biasing was removed because passing vocabulary to the local Whisper decoder made it return empty results.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Phonetic Proper-Noun Matching", isOn: $dictionary.phoneticMatchingEnabled)
                    .help("Catch misheard product names, people and jargon (\"ekotune\", \"echo tune\", \"kubernetis\") using offline sound-alike matching against your Custom Dictionary. Runs entirely on-device.")
                Text("Fuzzy sound-alike matching for names the model mishears. Ordinary words are left alone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Speech Settings
struct SpeechSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedMethod = VADManager.shared.config.method
    @State private var sileroReady = FluidVADEngine.shared.isReady
    @State private var isPreparing = false
    @State private var newFiller = ""
    @State private var customFillers = FillerWordManager.shared.customFillers

    private func addFiller() {
        if FillerWordManager.shared.addFiller(newFiller) {
            newFiller = ""
            customFillers = FillerWordManager.shared.customFillers
        }
    }

    var body: some View {
        Form {
            Section("Filler Words") {
                Toggle("Remove spoken filler words", isOn: $settings.fillerRemovalEnabled)
                    .help("Strip \"uh\", \"um\", \"erm\" and your own fillers, then repair the punctuation they leave behind.")
                Text("\"I went, uh, to the store. Erm, yes!\" becomes \"I went to the store. Yes!\"")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Add a filler word", text: $newFiller)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addFiller)
                    Button("Add", action: addFiller)
                        .disabled(newFiller.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !customFillers.isEmpty {
                    ForEach(customFillers, id: \.self) { filler in
                        HStack {
                            Text(filler)
                            Spacer()
                            Button {
                                if FillerWordManager.shared.removeFiller(filler) {
                                    customFillers = FillerWordManager.shared.customFillers
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Stop treating \"\(filler)\" as a filler.")
                        }
                    }
                }

                Text("Built in: \(FillerWordManager.builtInFillers.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Section("Speech Detection") {
                Picker("Detection Method", selection: $selectedMethod) {
                    ForEach(VADManager.DetectionMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .onChange(of: selectedMethod) { method in
                    VADManager.shared.updateMethod(method)
                }

                Text(selectedMethod.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Label(
                        sileroReady ? "Silero model ready" : "Silero model not ready",
                        systemImage: sileroReady ? "checkmark.circle.fill" : "arrow.down.circle"
                    )
                    .foregroundColor(sileroReady ? .green : .secondary)

                    Spacer()

                    if !sileroReady {
                        Button(isPreparing ? "Preparing…" : "Prepare now") {
                            isPreparing = true
                            Task {
                                try? await FluidVADEngine.shared.prepare()
                                await MainActor.run {
                                    sileroReady = FluidVADEngine.shared.isReady
                                    isPreparing = false
                                }
                            }
                        }
                        .disabled(isPreparing)
                    }
                }
            }

            Section("Fallback") {
                Text("If Silero cannot download or load, EchoTune automatically uses the energy detector. You can select Energy-based at any time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            sileroReady = FluidVADEngine.shared.isReady
        }
    }
}

// MARK: - Hotkey Settings
struct HotkeySettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 4)

            // Primary dictation trigger (owned by ShortcutManager)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictation")
                        .fontWeight(.medium)
                    Text("Hold to dictate, or press to toggle recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(coordinator.shortcutManager.getCurrentShortcutString())
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.12)))
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 4)

            // "More Actions" hotkey list removed for 4.0.0 — those bindings were
            // display-only (no delivery path existed) and misled users.
        }
        }
    }
}

// MARK: - Permissions & Privacy
struct PermissionsPrivacySettingsView: View {
    @StateObject private var permissions = PermissionsManager.shared
    
    var body: some View {
        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Permissions")
                .font(.headline)
            
            VStack(spacing: 12) {
                PermissionRow(
                    title: "Microphone Access",
                    description: "Required to record audio for transcription.",
                    hasPermission: permissions.hasMicrophonePermission,
                    action: { permissions.requestMicrophonePermission { _ in } }
                )
                
                Divider()
                
                PermissionRow(
                    title: "Accessibility API",
                    description: "Required to register hotkeys and insert text directly.",
                    hasPermission: permissions.hasAccessibilityPermission,
                    action: { permissions.requestAccessibilityPermission() }
                )
                
                Divider()
                
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required for context-aware transcription hints.",
                    hasPermission: permissions.hasScreenRecordingPermission,
                    activatesAfterRelaunch: permissions.screenCaptureActivatesAfterRelaunch,
                    action: { permissions.requestScreenRecordingPermission() }
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            
            Spacer()
        }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let hasPermission: Bool
    var activatesAfterRelaunch: Bool = false
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if hasPermission && activatesAfterRelaunch {
                    Text("Granted — takes effect next time EchoTune starts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if hasPermission {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Privacy Settings
struct PrivacySettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showEraseAllConfirmation = false
    @State private var statusBanner: String? = nil

    var body: some View {
        Form {
            Section("Audio Retention") {
                Toggle("Keep Local Audio Recordings", isOn: $settings.keepAudioHistory)
                    .help("Saves the audio files along with history recordings.")

                Picker("Retention Period", selection: $settings.audioRetentionDays) {
                    Text("1 Day").tag(1)
                    Text("7 Days").tag(7)
                    Text("30 Days").tag(30)
                    Text("Indefinitely").tag(9999)
                }
                .disabled(!settings.keepAudioHistory)
            }

            Section("Move to Another Mac") {
                HStack(spacing: 12) {
                    Button("Export Setup…") {
                        exportSettingsBackup()
                    }
                    .buttonStyle(.bordered)
                    .help("Dictionary, power modes, trigger rules, filler words and preferences as JSON. API and licence keys are never included.")

                    Button("Import Setup…") {
                        importSettingsBackup()
                    }
                    .buttonStyle(.bordered)
                    .help("Merge a setup file from another Mac. Existing entries are kept, so importing twice is safe.")
                }
                Text("Moves your configuration only — never your API keys, licence, or dictation history.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Section("Your Local Data") {
                HStack(spacing: 12) {
                    Button("Export All Local Data…") {
                        exportAllLocalData()
                    }
                    .buttonStyle(.bordered)

                    Button("Delete Cached Audio Only") {
                        let result = AudioCleanupManager.shared.deleteAllAudioFiles()
                        statusBanner = "Deleted \(result.deletedCount) cached audio file(s)."
                    }
                    .buttonStyle(.bordered)
                }

                Button("Erase All Local History, Notes, Tasks & Logs…", role: .destructive) {
                    showEraseAllConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)

                if let statusBanner {
                    Text(statusBanner)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert("Erase All Local Data?", isPresented: $showEraseAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Erase Everything", role: .destructive) {
                eraseAllLocalData()
            }
        } message: {
            Text("This permanently removes all local transcription history, Echo memory, notes, tasks, learned corrections, cached audio files, and diagnostic logs from this Mac. Your license and settings are kept.")
        }
    }

    private func exportAllLocalData() {
        struct ExportBundle: Encodable {
            let exportedAt: Date
            let appVersion: String
            let transcriptions: [TranscriptionHistoryItem]
            let notes: [Note]
            let commitments: [Commitment]
        }

        let bundle = ExportBundle(
            exportedAt: Date(),
            appVersion: Bundle.main.appVersionWithBuild,
            transcriptions: TranscriptionHistoryManager.shared.transcriptions,
            notes: NotesManager.shared.notes,
            commitments: CommitmentMemoryManager.shared.commitments
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(bundle) else {
            statusBanner = "Failed to encode export file."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "EchoTune-Export.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                statusBanner = "Exported to \(url.lastPathComponent)."
            } catch {
                statusBanner = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Setup backup (ET-764)

    private func exportSettingsBackup() {
        do {
            let data = try ConfigurationBackupManager.shared.makeBackup(
                triggerRules: AIEnhancementEngine.shared.triggerWordRules,
                fillerWords: FillerWordManager.shared.customFillers
            )

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "EchoTune-Setup.json"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url, options: .atomic)
                    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                    statusBanner = "Exported your setup to \(url.lastPathComponent)."
                } catch {
                    statusBanner = "Export failed: \(error.localizedDescription)"
                }
            }
        } catch {
            statusBanner = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importSettingsBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let result = try ConfigurationBackupManager.shared.importBackup(from: data)

                // Trigger rules live on the engine; merge them here by phrase.
                var existing = Set(AIEnhancementEngine.shared.triggerWordRules.map { $0.triggerPhrase.lowercased() })
                for rule in result.triggerRules where !existing.contains(rule.triggerPhrase.lowercased()) {
                    AIEnhancementEngine.shared.triggerWordRules.append(rule)
                    existing.insert(rule.triggerPhrase.lowercased())
                }

                let s = result.summary
                statusBanner = "Imported: \(s.powerModesAdded) power mode(s), \(s.triggerRulesAdded) trigger rule(s), \(s.fillerWordsAdded) filler word(s), \(s.dictionarySpellingsAdded) spelling(s), \(s.preferencesApplied) preference(s)."
            } catch {
                statusBanner = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func eraseAllLocalData() {
        _ = AudioCleanupManager.shared.deleteAllAudioFiles()
        TranscriptionHistoryManager.shared.clearAll()
        EchoMemoryManager.shared.clearAll()
        NotesManager.shared.clearAll()
        CommitmentMemoryManager.shared.clearAll()
        CorrectionLearner.shared.clearAll()
        ErrorLogger.shared.clearLogs()
        statusBanner = "All local transcriptions, notes, tasks, audio, and logs have been erased."
    }
}

// MARK: - About & License Settings
struct AboutLicenseSettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var updateManager = UpdateManager.shared
    
    var body: some View {
        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("EchoTune")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version \(updateManager.getCurrentVersion())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Text("EchoTune runs Whisper local transcription engines on your device, ensuring maximum privacy and instant speed.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Updates")
                    .font(.headline)
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updateManager.automaticUpdatesEnabled },
                    set: { updateManager.setAutomaticUpdates(enabled: $0) }
                ))
                HStack {
                    Button("Check for Updates…") {
                        updateManager.checkForUpdates()
                    }
                    if let lastCheckDate = updateManager.lastCheckDate {
                        Text("Last checked \(lastCheckDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Licensing")
                    .font(.headline)
                
                if coordinator.appState.isLicensed {
                    Label("Licensed Active", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                    
                    if let info = coordinator.appState.licenseInfo {
                        Text("License Type: \(info.tier.rawValue.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Running in Trial / Free mode.")
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Enter License Key") {
                            coordinator.showLicenseSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Purchase License") {
                            coordinator.presentPurchaseFlow()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(8)
            
            Spacer()
        }
        }
    }
}
