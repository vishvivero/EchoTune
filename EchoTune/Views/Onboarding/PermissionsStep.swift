//
//  PermissionsStep.swift
//  EchoTune
//
//  Onboarding Step 2: Permissions (Guided Setup)
//

import SwiftUI

struct PermissionsStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @StateObject private var permissions = PermissionsManager.shared

    @State private var appeared = false
    @State private var pollTimer: Timer?

    private var requiredPermissionsGranted: Bool {
        permissions.hasMicrophonePermission && permissions.hasAccessibilityPermission
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("A few quick permissions")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)

            Spacer().frame(height: 6)

            Text("Each button opens the exact macOS privacy pane. Enable EchoTune there, then come back here.")
                .font(.system(size: 14))
                .foregroundColor(.echoTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 72)

            Spacer().frame(height: 32)

            // Permission cards
            VStack(spacing: 14) {
                OnboardingPermissionCard(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    subtitle: "Approve the system prompt so EchoTune can hear your voice",
                    isGranted: permissions.hasMicrophonePermission,
                    isRequired: true,
                    onGrant: {
                        permissions.requestMicrophonePermission { _ in
                            permissions.checkMicrophonePermission()
                        }
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                OnboardingPermissionCard(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    subtitle: permissions.accessibilityInlineInstructions,
                    isGranted: permissions.hasAccessibilityPermission,
                    isRequired: true,
                    onGrant: {
                        permissions.requestAccessibilityPermission()
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                OnboardingPermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    subtitle: permissions.screenRecordingInlineInstructions,
                    isGranted: permissions.hasScreenRecordingPermission,
                    isRequired: false,
                    onGrant: {
                        OnboardingStateStore.shared.setCurrentStep(1)
                        permissions.requestScreenRecordingPermission()
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 48)

            if !permissions.hasAccessibilityPermission || !permissions.hasScreenRecordingPermission {
                PermissionReturnHint(
                    showAccessibilityHint: !permissions.hasAccessibilityPermission,
                    showScreenRecordingHint: !permissions.hasScreenRecordingPermission
                )
                .padding(.horizontal, 48)
                .padding(.top, 14)
            }

            Spacer()

            // Continue
            PrimaryButton(
                title: "Continue",
                action: onNext,
                disabled: !requiredPermissionsGranted
            )

            if !requiredPermissionsGranted {
                Text("Grant microphone & accessibility to continue")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 48)
        }
        .onAppear {
            appeared = true
            permissions.checkAllPermissions()
            startPolling()
        }
        .onChange(of: requiredPermissionsGranted) { _, granted in
            if granted {
                stopPolling()
            } else {
                startPolling()
            }
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            permissions.checkAllPermissions()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - Permission Return Hint

struct PermissionReturnHint: View {
    let showAccessibilityHint: Bool
    let showScreenRecordingHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When System Settings opens:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.echoTextPrimary)

            if showAccessibilityHint {
                Text("1. In Accessibility, turn on EchoTune.")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextSecondary)
            }

            if showScreenRecordingHint {
                Text(showAccessibilityHint ? "2. In Screen Recording, enable EchoTune for richer app-aware context." : "1. In Screen Recording, enable EchoTune for richer app-aware context.")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextSecondary)
            }

            Text("Return to EchoTune afterward. Permission status refreshes automatically when the app becomes active again.")
                .font(.system(size: 11))
                .foregroundColor(.echoTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.echoSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.echoBorder, lineWidth: 1)
        )
    }
}

// MARK: - Onboarding Permission Card

struct OnboardingPermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let isRequired: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isGranted ? Color.green.opacity(0.12) : Color.echoPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 17))
                    .foregroundColor(isGranted ? .green : .echoPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.echoTextPrimary)

                    if !isRequired {
                        Text("Optional")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.echoTextTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.echoSurfaceHover)
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
            }

            Spacer()

            if isGranted {
                Text("Granted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button(action: onGrant) {
                    Text("Grant")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.echoPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.echoBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}
