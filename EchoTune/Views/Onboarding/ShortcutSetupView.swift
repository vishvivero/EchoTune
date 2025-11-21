//
//  ShortcutSetupView.swift
//  EchoTune
//
//  Set up keyboard shortcut for recording
//

import SwiftUI

struct ShortcutSetupView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var isRecording = false
    @State private var pressedKeys: Set<String> = []

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "command.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 16) {
                Text("Set Your Shortcut")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Press the Function (fn) key to start and stop recording anywhere on your Mac.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Shortcut display
            VStack(spacing: 24) {
                // Current shortcut - Function key
                KeyCapView(key: "fn", isActive: false, isLarge: true)

                // Recommended label
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)

                    Text("Recommended")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )

            // Instruction
            Text("This shortcut works globally in any app")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            // Custom shortcut option (future feature)
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14))

                    Text("Customize Shortcut")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(true) // Coming soon

            Spacer()

            // Continue button
            Button(action: {
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
        .padding(40)
    }
}

struct KeyCapView: View {
    let key: String
    let isActive: Bool
    var isLarge: Bool = false

    var body: some View {
        Text(key)
            .font(.system(size: isLarge ? 32 : 24, weight: .medium, design: .rounded))
            .foregroundColor(isActive ? .white : .primary)
            .frame(width: isLarge ? 100 : 60, height: isLarge ? 80 : 60)
            .background(
                RoundedRectangle(cornerRadius: isLarge ? 12 : 8)
                    .fill(isActive ? Color.blue : Color.gray.opacity(0.1))
                    .shadow(color: .black.opacity(0.1), radius: isLarge ? 4 : 2, y: isLarge ? 4 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isLarge ? 12 : 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    ShortcutSetupView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
