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
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permissions")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Manage app permissions and audio settings")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)

                // Permissions List
                VStack(alignment: .leading, spacing: 20) {
                    // Microphone Permission
                    PermissionCard(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "Required to record your voice",
                        isGranted: permissionsManager.hasMicrophonePermission,
                        onGrant: {
                            permissionsManager.requestMicrophonePermission { _ in }
                        }
                    )

                    // Microphone device selection (when permission granted)
                    if permissionsManager.hasMicrophonePermission {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Microphone Device")
                                .font(.headline)

                            Picker("Select Microphone", selection: $selectedMicrophoneID) {
                                ForEach(availableAudioDevices, id: \.id) { device in
                                    HStack {
                                        if device.isDefault {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                        Text(device.name)
                                    }
                                    .tag(device.id)
                                }
                            }
                            .onChange(of: selectedMicrophoneID) { oldValue, newValue in
                                audioManager.selectAudioDevice(id: newValue)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    }

                    // Accessibility Permission
                    VStack(alignment: .leading, spacing: 12) {
                        PermissionCard(
                            icon: "figure.walk",
                            title: "Accessibility Access",
                            description: "Required for keyboard shortcuts and text insertion",
                            isGranted: permissionsManager.hasAccessibilityPermission,
                            onGrant: {
                                permissionsManager.requestAccessibilityPermission()
                            }
                        )

                        if !permissionsManager.hasAccessibilityPermission {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Troubleshooting Accessibility")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("1.")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Click \"Grant\" button above")
                                                .font(.caption)
                                            Text("This triggers system dialog to open Settings")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    HStack(alignment: .top, spacing: 8) {
                                        Text("2.")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("In System Settings → Privacy & Security → Accessibility")
                                                .font(.caption)
                                            Text("Look for \"EchoTune\" in the list and toggle it ON")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    HStack(alignment: .top, spacing: 8) {
                                        Text("3.")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Click \"Restart EchoTune\" button below")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                            Text("macOS REQUIRES a full restart for accessibility to work")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Button(action: {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Accessibility Settings")
                                    }
                                    .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    if permissionsManager.hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)
                                Text("Current Shortcut:")
                                    .font(.subheadline)
                                Text(appCoordinator.shortcutManager.getCurrentShortcutString())
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(10)
                    }

                    // Screen Recording Permission
                    VStack(alignment: .leading, spacing: 12) {
                        PermissionCard(
                            icon: "rectangle.on.rectangle",
                            title: "Screen Recording Access",
                            description: "Recommended for better browser compatibility (Chrome, Safari, etc.)",
                            isGranted: permissionsManager.hasScreenRecordingPermission,
                            onGrant: {
                                permissionsManager.requestScreenRecordingPermission()
                            }
                        )

                        if !permissionsManager.hasScreenRecordingPermission {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Why Screen Recording?")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                Text("Screen Recording permission helps EchoTune work better with web browsers:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.blue)
                                        Text("Better text insertion in Gmail, Google Docs")
                                            .font(.caption)
                                    }
                                    HStack(spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.blue)
                                        Text("Improved Chrome and Safari compatibility")
                                            .font(.caption)
                                    }
                                    HStack(spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.blue)
                                        Text("Context-aware transcription")
                                            .font(.caption)
                                    }
                                }

                                Text("Note: Your screen content is NEVER stored or transmitted.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }

                // Refresh and Restart Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        permissionsManager.checkAllPermissions()
                        if permissionsManager.hasAccessibilityPermission {
                            appCoordinator.refreshKeyboardShortcut()
                        }
                        loadAudioDevices()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Permissions")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)

                    Button(action: restartApp) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Restart EchoTune")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Only show restart warning if accessibility is NOT granted
                if !permissionsManager.hasAccessibilityPermission {
                    Text("⚠️ After granting Accessibility permission, you MUST restart EchoTune")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }

                // Help Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Need Help?")
                        .font(.headline)

                    Text("If permissions aren't working:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1.")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Try \"Refresh All Permissions\" above")
                                .font(.subheadline)
                        }
                        HStack {
                            Text("2.")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Restart EchoTune after granting permissions")
                                .font(.subheadline)
                        }
                        HStack {
                            Text("3.")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Check System Settings → Privacy & Security")
                                .font(.subheadline)
                        }
                    }

                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open System Settings")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(32)
        }
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
            // Get the path to the app bundle
            let appPath = Bundle.main.bundlePath
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [appPath]

            // Schedule app relaunch and terminate
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
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
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
        .padding()
        .background(isGranted ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
