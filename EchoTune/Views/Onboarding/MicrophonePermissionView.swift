//
//  MicrophonePermissionView.swift
//  EchoTune
//
//  Request microphone permission
//

import SwiftUI
import AVFoundation

enum MicrophonePermissionStatus {
    case notDetermined
    case granted
    case denied
}

struct MicrophonePermissionView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var permissionStatus: MicrophonePermissionStatus = .notDetermined
    @State private var isCheckingPermission = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 120, height: 120)

                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 16) {
                Text("Microphone Access")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("EchoTune needs access to your microphone to transcribe your voice into text.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Status-specific content
            Group {
                switch permissionStatus {
                case .notDetermined:
                    undeterminedView
                case .granted:
                    grantedView
                case .denied:
                    deniedView
                }
            }

            Spacer()
        }
        .padding(40)
        .onAppear {
            checkPermissionStatus()
        }
    }

    private var undeterminedView: some View {
        VStack(spacing: 24) {
            Button(action: requestMicrophonePermission) {
                HStack(spacing: 12) {
                    if isCheckingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                    }

                    Text(isCheckingPermission ? "Requesting..." : "Grant Microphone Access")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(isCheckingPermission)
        }
    }

    private var grantedView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)

                Text("Microphone access granted!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)

            Button(action: {
                coordinator.hasMicrophonePermission = true
                coordinator.nextStep()
            }) {
                HStack(spacing: 12) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)

                    Text("Microphone access denied")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }

                Text("Please enable microphone access in System Settings to continue.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)

            Button(action: openSystemSettings) {
                HStack(spacing: 12) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))

                    Text("Open System Settings")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button(action: checkPermissionStatus) {
                Text("I've Enabled Access")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // Computed properties for icons
    private var iconName: String {
        switch permissionStatus {
        case .granted:
            return "mic.fill"
        case .denied:
            return "mic.slash.fill"
        default:
            return "mic.circle"
        }
    }

    private var iconColor: Color {
        switch permissionStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        default:
            return .blue
        }
    }

    private var iconBackgroundColor: Color {
        switch permissionStatus {
        case .granted:
            return .green.opacity(0.2)
        case .denied:
            return .red.opacity(0.2)
        default:
            return .blue.opacity(0.2)
        }
    }

    // Methods
    private func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            permissionStatus = .granted
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .notDetermined
        }
    }

    private func requestMicrophonePermission() {
        isCheckingPermission = true

        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                isCheckingPermission = false
                permissionStatus = granted ? .granted : .denied

                if granted {
                    // Auto-proceed after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        coordinator.hasMicrophonePermission = true
                        coordinator.nextStep()
                    }
                }
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    MicrophonePermissionView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
