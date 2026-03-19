//
//  MeetingView.swift
//  EchoTune
//
//  Main meeting mode tab — record, transcribe, and summarise meetings.
//

import SwiftUI

@available(macOS 13.0, *)
struct MeetingView: View {
    @ObservedObject private var meetingManager = MeetingManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var meetingTitle = ""
    @State private var selectedTemplate: MeetingTemplate = .general
    @State private var selectedMeeting: MeetingSession?
    @State private var showDeleteConfirmation = false
    @State private var meetingToDelete: UUID?

    var body: some View {
        HSplitView {
            // Left: Meeting list
            meetingListPanel
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            // Right: Detail/Recording panel
            detailPanel
                .frame(minWidth: 400)
        }
    }

    // MARK: - Meeting List Panel

    private var meetingListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Meetings")
                    .font(.headline)
                Spacer()
                if !meetingManager.isRecording {
                    Button(action: { startNewMeeting() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Start new meeting")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Current recording indicator
            if meetingManager.isRecording {
                currentRecordingBanner
            }

            // Past meetings list
            if meetingManager.pastMeetings.isEmpty && !meetingManager.isRecording {
                emptyState
            } else {
                List(selection: Binding(
                    get: { selectedMeeting?.id },
                    set: { id in selectedMeeting = meetingManager.pastMeetings.first { $0.id == id } }
                )) {
                    ForEach(meetingManager.pastMeetings) { meeting in
                        meetingRow(meeting)
                            .tag(meeting.id)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    meetingToDelete = meeting.id
                                    showDeleteConfirmation = true
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .alert("Delete Meeting?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let id = meetingToDelete {
                    meetingManager.deleteMeeting(id)
                    if selectedMeeting?.id == id { selectedMeeting = nil }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the meeting recording and notes.")
        }
    }

    private var currentRecordingBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(meetingManager.isRecording ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: meetingManager.isRecording)

            Text("Recording...")
                .font(.caption)
                .foregroundColor(.red)

            Spacer()

            Text(formatDuration(meetingManager.recordingDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }

    private func meetingRow(_ meeting: MeetingSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.templateUsed.emoji)
                    .font(.caption)
                Text(meeting.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            HStack {
                Text(meeting.startTime, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("·")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(meeting.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if let app = meeting.detectedApp {
                    Text("· \(app)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No meetings yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Start a meeting recording to capture and summarise your calls.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        Group {
            if meetingManager.isRecording {
                activeRecordingView
            } else if let meeting = selectedMeeting {
                MeetingDetailView(meeting: meeting)
            } else {
                newMeetingPrompt
            }
        }
    }

    private var newMeetingPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.accentColor.opacity(0.6))

            Text("Start a Meeting")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                TextField("Meeting title (optional)", text: $meetingTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Picker("Template", selection: $selectedTemplate) {
                    ForEach(MeetingTemplate.allCases) { template in
                        Label(template.rawValue, systemImage: "doc.text")
                            .tag(template)
                    }
                }
                .frame(maxWidth: 300)

                Button(action: { startNewMeeting() }) {
                    Label("Start Recording", systemImage: "record.circle")
                        .font(.headline)
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }

            if !SystemAudioCapture.hasPermission() {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Screen Recording permission required")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Grant Access") {
                        SystemAudioCapture.requestPermission()
                    }
                    .font(.caption)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Active Recording View

    private var activeRecordingView: some View {
        VStack(spacing: 0) {
            // Recording header
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)

                Text(meetingManager.currentSession?.title ?? "Recording")
                    .font(.headline)

                Spacer()

                Text(formatDuration(meetingManager.recordingDuration))
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.secondary)

                Button(action: { meetingManager.stopMeeting() }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .background(Color.red.opacity(0.05))

            Divider()

            // Audio level indicator
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(min(meetingManager.systemAudioLevel * 10, 1.0)))
                    }
                }
                .frame(height: 4)
                Text("System Audio")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Live transcript
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        if meetingManager.liveTranscript.isEmpty {
                            Text("Listening for audio...")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                        } else {
                            Text(meetingManager.liveTranscript)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding()
                                .id("transcript-bottom")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: meetingManager.liveTranscript) { _ in
                    withAnimation {
                        proxy.scrollTo("transcript-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func startNewMeeting() {
        let detectedApp = MeetingManager.detectMeetingApp()
        meetingManager.startMeeting(
            title: meetingTitle.isEmpty ? (detectedApp.map { "\($0) Meeting" } ?? "") : meetingTitle,
            template: selectedTemplate,
            detectedApp: detectedApp
        )
        meetingTitle = ""
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
