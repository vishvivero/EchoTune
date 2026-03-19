//
//  MeetingSettingsView.swift
//  EchoTune
//
//  Settings panel for Meeting Mode configuration.
//

import SwiftUI

struct MeetingSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Meeting Mode", isOn: $settings.meetingModeEnabled)
                    .help("Adds a Meetings tab for recording and transcribing calls")

                if settings.meetingModeEnabled {
                    Toggle("Auto-detect meeting apps", isOn: $settings.meetingAutoDetect)
                        .help("Automatically offer to record when Zoom, Teams, or Meet is detected")

                    Toggle("Auto-summarise when meeting ends", isOn: $settings.meetingAutoSummarise)
                        .help("Generate AI summary automatically when you stop recording")

                    Toggle("Include microphone audio", isOn: $settings.meetingIncludeMicAudio)
                        .help("Capture your own voice alongside system audio")

                    Picker("Default template", selection: $settings.meetingDefaultTemplate) {
                        ForEach(MeetingTemplate.allCases) { template in
                            Text("\(template.emoji) \(template.rawValue)")
                                .tag(template)
                        }
                    }
                }
            } header: {
                Label("Meeting Recording", systemImage: "video")
            } footer: {
                Text("Meeting mode captures system audio from Zoom, Teams, Google Meet, and other apps. Requires Screen Recording permission.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if settings.meetingModeEnabled {
                Section {
                    HStack {
                        Image(systemName: SystemAudioCapture.hasPermission() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(SystemAudioCapture.hasPermission() ? .green : .red)
                        Text("Screen Recording")
                        Spacer()
                        if !SystemAudioCapture.hasPermission() {
                            Button("Grant") {
                                SystemAudioCapture.requestPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Text("Granted")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                } header: {
                    Label("Permissions", systemImage: "lock.shield")
                }

                Section {
                    Text("Supported apps: Zoom, Microsoft Teams, Google Meet, FaceTime, Slack Huddles, Webex, Discord")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label("Supported Platforms", systemImage: "app.badge")
                }
            }
        }
        .formStyle(.grouped)
    }
}
