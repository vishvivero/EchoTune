//
//  MenuBarContentView.swift
//  EchoTune
//
//  Phase 1: Menu Bar Popover Content
//

import SwiftUI

struct MenuBarContentView: View {
    @State private var appState = AppState.shared
    @State private var settings = AppSettings.shared
    @State private var coordinator = AppCoordinator.shared
    @State private var audioManager = AudioManager.shared
    @State private var permissionsWindow: NSWindow?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Status Information
            statusSection

            Divider()

            // Action Buttons
            actionsSection

            Divider()

            // License/Trial Info
            licenseSection

            Spacer()

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 320, height: 480)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoTune")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Voice Dictation")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(appState.recordingState.color)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            StatusRow(
                icon: appState.recordingState.iconName,
                label: "Status",
                value: appState.recordingState.description,
                color: appState.recordingState.color
            )

            StatusRow(
                icon: "cpu",
                label: "Model",
                value: settings.selectedModelSize.rawValue,
                color: .primary
            )

            StatusRow(
                icon: "keyboard",
                label: "Shortcut",
                value: settings.activationShortcut,
                color: .primary
            )

            if !appState.isLicensed {
                StatusRow(
                    icon: "calendar",
                    label: "Trial",
                    value: "\(appState.trialDaysRemaining) days left",
                    color: appState.trialDaysRemaining < 3 ? .orange : .primary
                )
            }
        }
        .padding()
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Audio Visualizer (when recording)
            if appState.recordingState == .recording {
                AudioVisualizerView(
                    audioLevel: audioManager.audioLevel,
                    isRecording: true
                )
                .frame(height: 40)
                .padding(.vertical, 4)
            }

            // Start/Stop Dictation Button
            Button(action: {
                coordinator.toggleDictation()
            }) {
                HStack {
                    Image(systemName: appState.recordingState == .recording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title3)
                    Text(appState.recordingState == .recording ? "Stop Dictation" : "Start Dictation")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.recordingState == .recording ? .red : .blue)
            .disabled(appState.recordingState == .processing)

            HStack(spacing: 10) {
                // Settings Button
                Button(action: {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showSettings()
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Permissions Button
                Button(action: {
                    showPermissions()
                }) {
                    HStack {
                        Image(systemName: appState.hasMicrophonePermission ? "checkmark.shield.fill" : "exclamationmark.shield")
                        Text("Permissions")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(appState.hasMicrophonePermission && appState.hasAccessibilityPermission ? .green : .orange)
            }

            // Statistics
            if appState.totalTranscriptions > 0 {
                VStack(spacing: 4) {
                    Text("Statistics")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Label("\(appState.totalTranscriptions)", systemImage: "text.bubble")
                        Spacer()
                        Label("\(appState.totalWordsTranscribed)", systemImage: "character.cursor.ibeam")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
    }

    // MARK: - License Section

    private var licenseSection: some View {
        Group {
            if !appState.isLicensed {
                VStack(spacing: 8) {
                    if appState.isTrialExpired {
                        Label("Trial Expired", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Button(action: {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.showSettings()
                        }
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text(appState.isTrialExpired ? "Enter License to Continue" : "Enter License Key")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: {
                        if let url = URL(string: "https://echotune.app/purchase") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Purchase License →")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding()
            } else {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Licensed")
                            .fontWeight(.medium)
                        Spacer()
                        if let tier = appState.licenseInfo?.tier {
                            Text(tier.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .font(.caption)
                }
                .padding()
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Text("Quit EchoTune")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Text("v1.0.0 • Made with ❤️")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func showPermissions() {
        if permissionsWindow == nil {
            let permissionsView = PermissionsView()
            let hostingController = NSHostingController(rootView: permissionsView)

            permissionsWindow = NSWindow(contentViewController: hostingController)
            permissionsWindow?.title = "Permissions"
            permissionsWindow?.styleMask = [.titled, .closable]
            permissionsWindow?.setContentSize(NSSize(width: 500, height: 450))
            permissionsWindow?.center()
            permissionsWindow?.isReleasedWhenClosed = false
        }

        permissionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Status Row Component

struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView()
        .frame(width: 320, height: 480)
}
