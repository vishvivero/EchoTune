//
//  PermissionsView.swift
//  EchoTune
//
//  Phase 2: Permissions Status Window
//

import SwiftUI

struct PermissionsView: View {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Permissions")
                    .font(.title)
                    .fontWeight(.bold)

                Text("EchoTune needs these permissions to work")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            Divider()

            // Permissions List
            VStack(spacing: 16) {
                PermissionRowView(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice for transcription",
                    status: permissionsManager.microphoneStatus,
                    action: {
                        requestMicrophonePermission()
                    }
                )

                PermissionRowView(
                    icon: "keyboard.fill",
                    title: "Accessibility Access",
                    description: permissionsManager.accessibilityInlineInstructions,
                    status: permissionsManager.accessibilityStatus,
                    action: {
                        requestAccessibilityPermission()
                    }
                )

                PermissionRowView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording Access",
                    description: permissionsManager.screenRecordingInlineInstructions,
                    status: permissionsManager.screenRecordingStatus,
                    action: {
                        permissionsManager.requestScreenRecordingPermission()
                    }
                )
            }
            .padding(.horizontal)

            Spacer()

            // Status Summary
            if permissionsManager.allPermissionsGranted() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All permissions granted")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Some permissions are missing")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Refresh Status") {
                    refreshPermissions()
                }
                .buttonStyle(.bordered)

                Button("Open Accessibility Settings") {
                    permissionsManager.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)

                Button("Open Screen Recording Settings") {
                    permissionsManager.openScreenRecordingSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
        .frame(width: 500, height: 450)
        .onAppear {
            permissionsManager.checkAllPermissions()
        }
    }

    // MARK: - Actions

    private func requestMicrophonePermission() {
        isChecking = true
        permissionsManager.requestMicrophonePermission { _ in
            isChecking = false
        }
    }

    private func requestAccessibilityPermission() {
        permissionsManager.requestAccessibilityPermission()
    }

    private func refreshPermissions() {
        permissionsManager.checkAllPermissions()
    }
}

// MARK: - Permission Row View

struct PermissionRowView: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(status.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Status / Action
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: status.iconName)
                    Text(status.description)
                }
                .font(.caption)
                .foregroundColor(status.color)

                if status != .granted {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    PermissionsView()
}
