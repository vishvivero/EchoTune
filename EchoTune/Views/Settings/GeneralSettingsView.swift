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

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { newValue in
                        launchAtLoginManager.setLaunchAtLogin(enabled: newValue) { result in
                            switch result {
                            case .success:
                                debugLog("✓ Launch at login: \(newValue)")
                                settings.launchAtStartup = newValue
                            case .failure(let error):
                                debugLog("❌ Failed to set launch at login: \(error)")
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
            }

            Section("Recorder UI Style") {
                Picker("Recording Indicator", selection: $settings.recorderStyle) {
                    ForEach(RecorderStyle.allCases) { style in
                        VStack(alignment: .leading) {
                            Text(style.rawValue)
                            Text(style.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Choose how the recording indicator appears while transcribing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
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
    }
}
