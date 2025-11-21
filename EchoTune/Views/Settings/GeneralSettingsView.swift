//
//  GeneralSettingsView.swift
//  EchoTune
//
//  Phase 1: General Settings Tab
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    private let shortcutManager = ShortcutManager.shared
    @State private var showShortcutRecorder = false
    @State private var currentShortcut = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("General Settings")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Configure basic app behavior and startup options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { newValue in
                        launchAtLoginManager.setLaunchAtLogin(enabled: newValue) { result in
                            switch result {
                            case .success:
                                print("✓ Launch at login: \(newValue)")
                                settings.launchAtStartup = newValue
                            case .failure(let error):
                                print("❌ Failed to set launch at login: \(error)")
                            }
                        }
                    }
                ))

                Text("EchoTune will start automatically when you log in to your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                // Show current status
                HStack {
                    Image(systemName: launchAtLoginManager.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(launchAtLoginManager.isEnabled ? .green : .secondary)
                    Text("Status: \(launchAtLoginManager.getStatusDescription())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }

            Section("Appearance") {
                Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
                Text("Show microphone icon in the top menu bar for quick access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Show in Dock", isOn: $settings.showInDock)
                    .onChange(of: settings.showInDock) { oldValue, newValue in
                        let policy: NSApplication.ActivationPolicy = newValue ? .regular : .accessory
                        NSApp.setActivationPolicy(policy)
                    }

                Text("Show EchoTune icon in the Dock in addition to the menu bar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }

            Section("Recording Behavior") {
                Picker("Recording Mode", selection: $settings.recordingMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Text(currentShortcut.isEmpty ? shortcutManager.getShortcutString() : currentShortcut)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)

                        Button("Change") {
                            changeShortcut()
                        }
                        .buttonStyle(.bordered)

                        Button("Reset") {
                            shortcutManager.resetToDefault()
                            settings.activationShortcut = shortcutManager.getShortcutString()
                            currentShortcut = shortcutManager.getShortcutString()

                            // Unregister and re-register with default shortcut
                            shortcutManager.unregisterGlobalShortcut()
                            shortcutManager.registerGlobalShortcut()
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("The default shortcut is ⌘⇧D. Hold this key to start/stop dictation.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }

            Section("Audio Feedback") {
                Toggle("Play Sound on Start/Stop", isOn: $settings.playSoundOnStartStop)

                Text("Play a subtle beep when recording starts and stops (recommended)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle("Mute Background Audio", isOn: $settings.muteBackgroundAudio)

                Text("Automatically mute other apps' audio while recording for better transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            currentShortcut = shortcutManager.getShortcutString()
        }
        .sheet(isPresented: $showShortcutRecorder) {
            KeyboardShortcutRecorder(isPresented: $showShortcutRecorder) { keyCode, modifiers in
                // Save the new shortcut
                shortcutManager.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                settings.activationShortcut = shortcutManager.getShortcutString()
                currentShortcut = shortcutManager.getShortcutString()

                // Unregister and re-register with the new shortcut
                shortcutManager.unregisterGlobalShortcut()
                shortcutManager.registerGlobalShortcut()

                print("✓ Shortcut updated to: \(shortcutManager.getShortcutString())")
            }
        }
    }

    private func changeShortcut() {
        showShortcutRecorder = true
    }
}
