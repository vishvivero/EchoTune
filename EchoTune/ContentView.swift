//
//  ContentView.swift
//  EchoTune
//
//  Simple, Fast Main View
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("EchoTune")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Voice Dictation for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            Divider()
                .padding(.horizontal, 40)

            // Status
            VStack(spacing: 12) {
                ContentStatusRow(
                    icon: appState.recordingState.iconName,
                    title: "Status",
                    value: appState.recordingState.description,
                    color: appState.recordingState.color
                )

                ContentStatusRow(
                    icon: "cpu",
                    title: "Engine",
                    value: "On-Device Whisper",
                    color: .blue
                )

                ContentStatusRow(
                    icon: "keyboard",
                    title: "Hotkey",
                    value: "⌃ Control (Press to Record)",
                    color: .orange
                )
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            // Quick Actions
            VStack(spacing: 12) {
                Text("Quick Start")
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Press ⌘, to open Settings")
                    }
                    HStack {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Grant Microphone & Accessibility permissions")
                    }
                    HStack {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Press Control (⌃) to start/stop recording")
                    }
                    HStack {
                        Text("4.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Speak, then release to transcribe")
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Settings Button
            Button(action: {
                // Open settings with CMD+,
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Open Settings")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(",", modifiers: .command)

            Text("Press ⌘, anytime to open Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

struct ContentStatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.body)
                .fontWeight(.medium)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
