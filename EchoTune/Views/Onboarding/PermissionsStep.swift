//
//  PermissionsStep.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct PermissionsStep: View {
    @ObservedObject private var pm = PermissionsManager.shared
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                OnboardingTheme.HeaderIconChip(systemName: "lock.shield.fill")

                Text("Enable Required Permissions")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("onboarding.permissions.title")

                Text("EchoTune needs microphone and accessibility access to record audio and insert text. Screen recording is optional but enables contextual AI features.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)

            VStack(spacing: 12) {
                // Card 1: Microphone (Core)
                permissionCard(
                    title: "Microphone Access",
                    description: "Required to record speech. EchoTune does all audio capture locally.",
                    isGranted: pm.hasMicrophonePermission,
                    grantAction: {
                        pm.requestMicrophonePermission { _ in
                            pm.checkMicrophonePermission()
                        }
                    },
                    grantBtnId: "onboarding.permissions.microphone.grantButton",
                    grantedLblId: "onboarding.permissions.microphone.grantedLabel"
                )

                // Card 2: Accessibility (Core)
                permissionCard(
                    title: "Accessibility API Access",
                    description: "Required to simulate keystrokes and insert text directly into other active apps.",
                    isGranted: pm.hasAccessibilityPermission,
                    grantAction: {
                        pm.requestAccessibilityPermission()
                    },
                    grantBtnId: "onboarding.permissions.accessibility.grantButton",
                    grantedLblId: "onboarding.permissions.accessibility.grantedLabel"
                )

                // Card 3: Screen Recording (Optional)
                permissionCard(
                    title: "Screen Context (Optional)",
                    description: "Allows analyzing active window contents to provide smart, context-aware transcriptions.",
                    isGranted: pm.hasScreenRecordingPermission,
                    grantAction: {
                        pm.requestScreenRecordingPermission()
                    },
                    grantBtnId: "onboarding.permissions.screenRecording.grantButton",
                    grantedLblId: "onboarding.permissions.screenRecording.grantedLabel"
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            // Continue Button
            Button(action: onNext) {
                Text("Continue")
                    .frame(width: 200)
            }
            .buttonStyle(GradientProminentButtonStyle())
            .controlSize(.large)
            .disabled(!canContinue)
            .accessibilityIdentifier("onboarding.permissions.continueButton")
            .padding(.bottom, 20)
        }
        .onAppear {
            pm.checkAllPermissions()
        }
    }

    private var canContinue: Bool {
        pm.hasMicrophonePermission && pm.hasAccessibilityPermission
    }

    @ViewBuilder
    private func permissionCard(
        title: String,
        description: String,
        isGranted: Bool,
        grantAction: @escaping () -> Void,
        grantBtnId: String,
        grantedLblId: String
    ) -> some View {
        OnboardingCardView {
            HStack(spacing: 16) {
                // Icon chip — matches the dashboard sidebar's rounded icon chips
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            isGranted
                                ? AnyShapeStyle(OnboardingTheme.successGradient)
                                : AnyShapeStyle(OnboardingTheme.brandGradient)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(
                            color: (isGranted ? Color.green : OnboardingTheme.accent).opacity(0.3),
                            radius: 6, x: 0, y: 3
                        )

                    Image(systemName: isGranted ? "checkmark" : "shield.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isGranted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Granted")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.green)
                    .accessibilityIdentifier(grantedLblId)
                } else {
                    Button(action: grantAction) {
                        Text("Grant")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(OnboardingTheme.brandGradient)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(grantBtnId)
                }
            }
        }
    }
}
