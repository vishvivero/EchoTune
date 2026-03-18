//
//  PermissionsContentView.swift
//  EchoTune
//
//  Comprehensive Permissions Management
//

import SwiftUI
import AVFoundation

struct PermissionsContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var audioManager = AudioManager.shared

    @State private var selectedMicrophoneID: String = ""
    @State private var availableAudioDevices: [AudioDevice] = []

    var body: some View {
        Form {
            Section("System Permissions") {
                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice",
                    isGranted: permissionsManager.hasMicrophonePermission,
                    onGrant: {
                        permissionsManager.requestMicrophonePermission { _ in }
                    }
                )

                PermissionCard(
                    icon: "figure.walk",
                    title: "Accessibility Access",
                    description: permissionsManager.accessibilityInlineInstructions,
                    isGranted: permissionsManager.hasAccessibilityPermission,
                    onGrant: {
                        permissionsManager.requestAccessibilityPermission()
                    }
                )

                PermissionCard(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording Access",
                    description: permissionsManager.screenRecordingInlineInstructions,
                    isGranted: permissionsManager.hasScreenRecordingPermission,
                    onGrant: {
                        permissionsManager.requestScreenRecordingPermission()
                    }
                )
            }

            if permissionsManager.hasMicrophonePermission {
                Section("Microphone Device") {
                    Picker("Select Microphone", selection: $selectedMicrophoneID) {
                        ForEach(availableAudioDevices, id: \.id) { device in
                            Text(device.isDefault ? "\(device.name) (Default)" : device.name)
                                .tag(device.id)
                        }
                    }
                    .onChange(of: selectedMicrophoneID) { _, newValue in
                        audioManager.selectAudioDevice(id: newValue)
                    }
                }
            }

            if permissionsManager.hasAccessibilityPermission {
                Section("Keyboard Shortcut") {
                    HStack(spacing: 8) {
                        Text("Current Shortcut")
                        Spacer()
                        Text(appCoordinator.shortcutManager.getCurrentShortcutString())
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
            }

            Section("Troubleshooting") {
                Button("Refresh Permissions") {
                    permissionsManager.checkAllPermissions()
                    if permissionsManager.hasAccessibilityPermission {
                        appCoordinator.refreshKeyboardShortcut()
                    }
                    loadAudioDevices()
                }

                if !permissionsManager.hasAccessibilityPermission {
                    Text("Return to EchoTune after granting access. The app refreshes permission state automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Open Accessibility Settings") {
                    permissionsManager.openAccessibilitySettings()
                }

                Button("Open Screen Recording Settings") {
                    permissionsManager.openScreenRecordingSettings()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadAudioDevices()
        }
    }

    private func loadAudioDevices() {
        availableAudioDevices = audioManager.getAvailableInputDevices()

        if let currentDevice = audioManager.currentInputDevice {
            selectedMicrophoneID = currentDevice.id
        } else if let defaultDevice = availableAudioDevices.first(where: { $0.isDefault }) {
            selectedMicrophoneID = defaultDevice.id
        }
    }
}

// MARK: - Permission Card Component

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    onGrant()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
