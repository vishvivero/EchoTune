//
//  AccessibilityPermissionView.swift
//  EchoTune
//
//  Request accessibility permission for system-wide typing
//

import SwiftUI
import ApplicationServices

struct AccessibilityPermissionView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var hasPermission = false
    @State private var isChecking = false

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
                Text("Accessibility Access")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("EchoTune needs accessibility permission to insert transcribed text into any app on your Mac.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            if !hasPermission {
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    AccessibilityInstructionStep(number: 1, text: "Click \"Open System Settings\" below")
                    AccessibilityInstructionStep(number: 2, text: "Find \"EchoTune\" in the list")
                    AccessibilityInstructionStep(number: 3, text: "Toggle the switch to ON")
                    AccessibilityInstructionStep(number: 4, text: "Come back to this window")
                }
                .padding(24)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .frame(maxWidth: 500)

                VStack(spacing: 16) {
                    Button(action: openAccessibilitySettings) {
                        HStack(spacing: 12) {
                            Image(systemName: "gear")
                                .font(.system(size: 18))

                            Text("Open System Settings")
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

                    Button(action: checkAccessibilityPermission) {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }

                            Text(isChecking ? "Checking..." : "I've Enabled Access")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking)
                }
            } else {
                // Permission granted
                VStack(spacing: 24) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)

                        Text("Accessibility access granted!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)

                    Text("⚠️ Please restart EchoTune for changes to take effect")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)

                    Button(action: {
                        coordinator.hasAccessibilityPermission = true
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

            Spacer()
        }
        .padding(40)
        .onAppear {
            checkAccessibilityPermission()
        }
    }

    private var iconName: String {
        hasPermission ? "hand.tap.fill" : "hand.raised.fill"
    }

    private var iconColor: Color {
        hasPermission ? .green : .blue
    }

    private var iconBackgroundColor: Color {
        hasPermission ? .green.opacity(0.2) : .blue.opacity(0.2)
    }

    private func checkAccessibilityPermission() {
        isChecking = true

        // Check if we have accessibility permissions
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: false] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isChecking = false
            hasPermission = accessEnabled
        }
    }

    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility > Privacy
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        // Start periodic checking
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            let accessEnabled = AXIsProcessTrusted()
            if accessEnabled {
                hasPermission = true
                timer.invalidate()
            }
        }
    }
}

struct AccessibilityInstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    AccessibilityPermissionView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
