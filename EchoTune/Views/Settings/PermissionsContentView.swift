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
                    description: "Required for keyboard shortcuts and text insertion",
                    isGranted: permissionsManager.hasAccessibilityPermission,
                    onGrant: {
                        permissionsManager.requestAccessibilityPermission()
                    }
                )

                PermissionCard(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording Access",
                    description: "Recommended for better browser compatibility",
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

                Button("Restart EchoTune") {
                    restartApp()
                }

                if !permissionsManager.hasAccessibilityPermission {
                    Text("After granting Accessibility permission, you must restart EchoTune.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        NSWorkspace.shared.open(url)
                    }
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

    private func restartApp() {
        let alert = NSAlert()
        alert.messageText = "Restart EchoTune?"
        alert.informativeText = "This will quit and relaunch the app to apply permission changes."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let appPath = Bundle.main.bundlePath
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [appPath]

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                task.launch()
                NSApplication.shared.terminate(nil)
            }
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
