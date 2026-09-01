//
//  SettingsCompositeViews.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch EchoTune at Login", isOn: $launchAtLogin.isEnabled)
                    .help("Start EchoTune automatically when you log in to your Mac.")
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
        }
        .formStyle(.grouped)
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
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            Section("Local Storage") {
                Button("Delete All Cached Audio Recordings") {
                    let _ = AudioCleanupManager.shared.deleteAllAudioFiles()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About & License Settings
struct AboutLicenseSettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
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
                    Text("Version 1.4.3")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Text("EchoTune runs Whisper local transcription engines on your device, ensuring maximum privacy and instant speed.")
                .font(.body)
                .foregroundColor(.secondary)
            
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
