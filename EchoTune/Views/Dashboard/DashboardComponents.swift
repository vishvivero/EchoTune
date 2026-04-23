//
//  DashboardComponents.swift
//  EchoTune
//

import SwiftUI

// MARK: - Compact Transcription Row

struct CompactTranscriptionRow: View {
    let item: TranscriptionHistoryItem
    let onDelete: (() -> Void)?
    var onTap: (() -> Void)? = nil
    @ObservedObject private var settings = AppSettings.shared
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Text content
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isHovering ? nil : 3)
                        .animation(.easeInOut, value: isHovering)

                    if item.transcriptionProviderLabel != nil || item.hasEnhancement || item.usedFallback {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if let provider = item.transcriptionProviderLabel {
                                    HistoryMetadataBadge(title: provider, color: .blue, icon: "waveform.badge.mic")
                                }
                                if let model = item.transcriptionModelLabel {
                                    HistoryMetadataBadge(title: model, color: .secondary, icon: "cpu")
                                }
                                if let enhancementProvider = item.enhancementProviderLabel {
                                    HistoryMetadataBadge(title: "Enhanced • \(enhancementProvider)", color: .purple, icon: "sparkles")
                                }
                                if item.usedFallback {
                                    HistoryMetadataBadge(title: "Fallback", color: .orange, icon: "arrow.uturn.backward.circle")
                                }
                            }
                        }
                    }

                    // Time and word count
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatTime(item.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "text.word.spacing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(item.wordCount) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(item.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if settings.showTranscriptionDiagnostics, let diagnosticsLine = item.diagnosticsLine {
                        Text(diagnosticsLine)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Actions on hover
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: { copyToClipboard() }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")

                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}

// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Recording Toggle Button

struct RecordingToggleButton: View {
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        let isRecording = appCoordinator.appState.recordingState == .recording
        let isProcessing = appCoordinator.appState.recordingState == .processing

        Button(action: {
            if isRecording {
                appCoordinator.stopDictation()
            } else if !isProcessing {
                appCoordinator.startDictation()
            }
        }) {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title3)
                }

                Text(isProcessing ? "Processing..." : (isRecording ? "Stop & Transcribe" : "Start Recording"))
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isProcessing ? Color.gray : (isRecording ? Color.red : Color.blue))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Content Views

struct SettingsContentView: View {
    var body: some View {
        SettingsView()
            .padding()
    }
}

struct AboutContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("EchoTune")
                .font(.system(size: 36, weight: .bold))

            Text("Version 1.0.0")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("AI-powered voice dictation for Mac")
                .font(.body)
                .foregroundColor(.secondary)

            Text("100% private, all processing on your device")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Divider()
                .padding(.vertical)

            Text("\u{00A9} \(Calendar.current.component(.year, from: Date())) EchoTune")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: 600)
    }
}
