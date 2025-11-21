//
//  MicrophoneSelectionView.swift
//  EchoTune
//
//  Let user select their default microphone
//

import SwiftUI
import AVFoundation

struct MicrophoneSelectionView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var availableMicrophones: [AudioDevice] = []
    @State private var selectedMicrophoneID: String?
    @State private var isTestingMicrophone = false
    @State private var inputLevel: Float = 0.0
    @State private var audioLevelTimer: Timer?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "waveform")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
            }

            VStack(spacing: 16) {
                Text("Select Your Microphone")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Choose the microphone you'd like to use for voice transcription.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Microphone list
            VStack(spacing: 12) {
                ForEach(availableMicrophones) { microphone in
                    MicrophoneRow(
                        microphone: microphone,
                        isSelected: selectedMicrophoneID == microphone.id,
                        inputLevel: isTestingMicrophone && selectedMicrophoneID == microphone.id ? inputLevel : 0.0,
                        action: {
                            selectedMicrophoneID = microphone.id
                            coordinator.selectedMicrophone = microphone.name
                        }
                    )
                }
            }
            .frame(maxWidth: 500)

            // Test microphone button
            if selectedMicrophoneID != nil {
                Button(action: toggleMicrophoneTest) {
                    HStack(spacing: 8) {
                        Image(systemName: isTestingMicrophone ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 16))

                        Text(isTestingMicrophone ? "Stop Testing" : "Test Microphone")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(isTestingMicrophone ? .red : .blue)
                }
                .buttonStyle(.plain)
            }

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
                .background(selectedMicrophoneID != nil ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(selectedMicrophoneID == nil)
        }
        .padding(40)
        .onAppear {
            loadAvailableMicrophones()
        }
        .onDisappear {
            stopMicrophoneTest()
        }
    }

    private func loadAvailableMicrophones() {
        // Get available audio input devices from AudioManager
        availableMicrophones = AudioManager.shared.getAvailableInputDevices()

        // Select the default device
        if let defaultDevice = availableMicrophones.first(where: { $0.isDefault }) ?? availableMicrophones.first {
            selectedMicrophoneID = defaultDevice.id
            coordinator.selectedMicrophone = defaultDevice.name
        }
    }

    private func toggleMicrophoneTest() {
        if isTestingMicrophone {
            stopMicrophoneTest()
        } else {
            startMicrophoneTest()
        }
    }

    private func startMicrophoneTest() {
        isTestingMicrophone = true

        // Start monitoring audio input levels
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Simulate audio level (replace with actual audio monitoring)
            inputLevel = Float.random(in: 0...1.0) * 0.5
        }
    }

    private func stopMicrophoneTest() {
        isTestingMicrophone = false
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        inputLevel = 0.0
    }
}

struct MicrophoneRow: View {
    let microphone: AudioDevice
    let isSelected: Bool
    let inputLevel: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                // Microphone icon
                Image(systemName: microphone.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 30)

                // Microphone name
                VStack(alignment: .leading, spacing: 4) {
                    Text(microphone.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Text(microphone.type)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Audio level indicator
                if inputLevel > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<10) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(index < Int(inputLevel * 10) ? Color.green : Color.gray.opacity(0.2))
                                .frame(width: 3, height: CGFloat(8 + index * 2))
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MicrophoneSelectionView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
