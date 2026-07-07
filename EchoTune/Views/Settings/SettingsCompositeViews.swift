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
                Toggle("Auto-Punctuation", isOn: $settings.autoPunctuation)
                    .help("Automatically format punctuation in transcription output.")
                
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
    @StateObject private var hotkeyManager = MultiHotkeyManager.shared
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
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

            Text("More Actions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            List {
                ForEach(hotkeyManager.hotkeyBindings) { binding in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(binding.action.rawValue)
                                .fontWeight(.medium)
                            if let desc = binding.action.defaultShortcut {
                                Text("Default: \(desc)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if binding.isModifierOnlyBinding, let trigger = binding.modifierTrigger {
                            Text("Modifier: \(trigger.displayName)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                                .foregroundColor(.accentColor)
                        } else if let display = binding.displayString {
                            Text(display)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
                        } else {
                            Text("Not Configured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Toggle("", isOn: Binding(
                            get: { binding.isEnabled },
                            set: { hotkeyManager.enableBinding(for: binding.action, enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .cornerRadius(8)
            
            Button("Reset to Defaults") {
                hotkeyManager.resetToDefaults()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Meetings Settings
struct MeetingsSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section("Meeting Mode") {
                Toggle("Enable Meeting Mode", isOn: $settings.meetingModeEnabled)
                    .help("Enables meeting recording and transcription features.")

                Toggle("Auto-detect meetings", isOn: $settings.meetingAutoDetect)
                    .help("Detects when a meeting app (Zoom, Teams, Meet, etc.) is active.")
                    .disabled(!settings.meetingModeEnabled)

                Toggle("Auto-start recording on detected meetings", isOn: $settings.meetingAutoStartDetectedApps)
                    .help("Automatically starts recording when a meeting is detected.")
                    .disabled(!settings.meetingModeEnabled || !settings.meetingAutoDetect)
            }

            Section("Meeting Capture") {
                Toggle("Include microphone audio", isOn: $settings.meetingIncludeMicAudio)
                    .help("Records your own voice alongside system audio during meetings.")

                Toggle("Auto-generate summary when meeting ends", isOn: $settings.meetingAutoSummarise)
                    .help("Generates AI meeting notes automatically when the recording stops.")

                Picker("Default AI Template", selection: $settings.meetingDefaultTemplate) {
                    ForEach(MeetingTemplate.allCases) { template in
                        Text("\(template.emoji) \(template.rawValue)").tag(template)
                    }
                }
                .help("Template used for auto-detected and scheduled meetings.")
            }
            
            Section("History Retention") {
                Toggle("Keep Local Audio Retention Archive", isOn: $settings.keepAudioHistory)
                    .help("Saves the audio files along with history recordings.")
                
                Picker("Retention Period", selection: $settings.audioRetentionDays) {
                    Text("1 Day").tag(1)
                    Text("7 Days").tag(7)
                    Text("30 Days").tag(30)
                    Text("Indefinitely").tag(9999)
                }
                .disabled(!settings.keepAudioHistory)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Permissions & Privacy
struct PermissionsPrivacySettingsView: View {
    @StateObject private var permissions = PermissionsManager.shared
    
    var body: some View {
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
            Section("Data Sharing") {
                Toggle("Share Anonymous Usage Analytics", isOn: $settings.shareAnalytics)
                    .help("Help us improve EchoTune by sending anonymous diagnostic data.")
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
