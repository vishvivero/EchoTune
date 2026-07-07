//
//  MeetingView.swift
//  EchoTune
//
//  Created by Antigravity on 13/06/2026.
//

import SwiftUI

struct MeetingView: View {
    @ObservedObject var meetingManager = MeetingManager.shared
    @State private var meetingTitle: String = ""
    @State private var selectedTemplate: MeetingTemplate = .general
    @State private var selectedMeeting: MeetingSession? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list: meetings history / start meeting
            VStack(spacing: 0) {
                // Header / Start Meeting Button
                if meetingManager.isRecording {
                    ActiveMeetingSidebar(meetingManager: meetingManager)
                } else {
                    StartMeetingPanel(
                        title: $meetingTitle,
                        selectedTemplate: $selectedTemplate,
                        onStart: {
                            meetingManager.startMeeting(title: meetingTitle.isEmpty ? "Untitled Meeting" : meetingTitle, template: selectedTemplate)
                            meetingTitle = ""
                        }
                    )
                }
                
                Divider()
                
                // Past Meetings List
                VStack(alignment: .leading, spacing: 10) {
                    Text("PAST MEETINGS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    if meetingManager.pastMeetings.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No recorded meetings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(meetingManager.pastMeetings) { session in
                                    Button(action: { selectedMeeting = session }) {
                                        HStack {
                                            Text(session.templateUsed.emoji)
                                                .font(.title3)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(session.title.isEmpty ? "Untitled Meeting" : session.title)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(session.startTime, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text(session.formattedDuration)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(selectedMeeting?.id == session.id ? Color.blue.opacity(0.1) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 280)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Right pane: detail view or live transcription
            VStack {
                if meetingManager.isRecording {
                    LiveMeetingTranscriptionPanel(meetingManager: meetingManager)
                } else if let session = selectedMeeting {
                    MeetingDetailPanel(session: session, onDelete: {
                        meetingManager.deleteMeeting(session.id)
                        selectedMeeting = nil
                    })
                } else {
                    EmptyMeetingDetailView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Start Meeting Panel
struct StartMeetingPanel: View {
    @Binding var title: String
    @Binding var selectedTemplate: MeetingTemplate
    let onStart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Record Meeting")
                .font(.headline)
            
            TextField("Meeting Title (e.g. Weekly Standup)", text: $title)
                .textFieldStyle(.roundedBorder)
            
            Picker("AI Template", selection: $selectedTemplate) {
                ForEach(MeetingTemplate.allCases) { template in
                    Text("\(template.emoji) \(template.rawValue)").tag(template)
                }
            }
            
            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Meeting Recording")
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
    }
}

// MARK: - Active Meeting Sidebar
struct ActiveMeetingSidebar: View {
    @ObservedObject var meetingManager: MeetingManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 2) > 1 ? 0.3 : 1.0)
                
                Text("RECORDING MEETING")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(formatDuration(meetingManager.recordingDuration))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
            }
            
            if let session = meetingManager.currentSession {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Audio level indicator — bar heights follow the live audio level
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 4, height: barHeight(for: i))
                }
            }
            .frame(height: 40)
            .animation(.easeOut(duration: 0.15), value: meetingManager.systemAudioLevel)
            
            Button(action: {
                meetingManager.stopMeeting()
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop & Summarise")
                }
                .foregroundColor(.white)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.red.opacity(0.05))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration / 60)
        let secs = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", mins, secs)
    }

    /// Deterministic bar heights driven by the live audio level (no randomness).
    private func barHeight(for index: Int) -> CGFloat {
        let multipliers: [CGFloat] = [10, 16, 22, 28, 35, 35, 28, 22, 16, 10]
        let level = CGFloat(min(max(meetingManager.systemAudioLevel, 0), 1))
        let normalized = min(level * 8, 1) // typical speech RMS is ~0.02–0.1
        return max(4, normalized * multipliers[index % multipliers.count])
    }
}

// MARK: - Live Meeting Transcription Panel
struct LiveMeetingTranscriptionPanel: View {
    @ObservedObject var meetingManager: MeetingManager

    private enum ScrollAnchor {
        static let bottomID = "live-transcript-bottom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meeting Notes")
                    .font(.headline)
                Spacer()
                if meetingManager.isGeneratingSummary {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating AI Summary...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding([.top, .horizontal], 20)

            Divider()

            // Your Notes — editable during the meeting, merged into the AI summary at the end
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Your Notes")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Merged into the AI summary")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                TextEditor(text: $meetingManager.userNotes)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 120, maxHeight: 220)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)

            // Live transcript — read-only, auto-scrolls to the latest text
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Live Transcript")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(meetingManager.liveTranscript.isEmpty ? "Waiting for speech..." : meetingManager.liveTranscript)
                                .font(.body)
                                .foregroundColor(meetingManager.liveTranscript.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)

                            Color.clear
                                .frame(height: 1)
                                .id(ScrollAnchor.bottomID)
                        }
                    }
                    .onChange(of: meetingManager.liveTranscript) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(ScrollAnchor.bottomID, anchor: .bottom)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .padding([.horizontal, .bottom], 20)
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Meeting Detail Panel
struct MeetingDetailPanel: View {
    let session: MeetingSession
    let onDelete: () -> Void
    @ObservedObject private var meetingManager = MeetingManager.shared
    @State private var selectedTab = 0

    /// Always show the freshest copy of this meeting (e.g. after a summary regeneration).
    private var displaySession: MeetingSession {
        meetingManager.pastMeetings.first(where: { $0.id == session.id }) ?? session
    }

    var body: some View {
        let session = displaySession
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(session.templateUsed.emoji)
                            .font(.title2)
                        Text(session.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 12) {
                        Label(session.templateUsed.rawValue, systemImage: "tag.fill")
                        Text("•")
                        Label(session.formattedDuration, systemImage: "clock")
                        Text("•")
                        Text(session.startTime, style: .date)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: {
                    meetingManager.regenerateSummary(for: session.id)
                }) {
                    if meetingManager.isGeneratingSummary {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Regenerating...")
                        }
                    } else {
                        Label("Regenerate Summary", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(meetingManager.isGeneratingSummary || session.transcript.isEmpty)
                .help("Regenerate the AI summary from the transcript and your notes")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .help("Delete Meeting")
            }
            .padding(20)
            
            Divider()
            
            // Picker tab
            Picker("", selection: $selectedTab) {
                Text("Summary & Info").tag(0)
                Text("Full Transcript").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // Tab Contents
            if selectedTab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // AI Summary block
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                Text("AI Summary")
                                    .font(.headline)
                            }
                            Text(session.summary ?? "AI Summary has not been generated for this meeting.")
                                .lineSpacing(4)
                                .foregroundColor(.primary.opacity(0.9))
                        }
                        .padding()
                        .background(Color.purple.opacity(0.04))
                        .cornerRadius(10)
                        
                        // Key Points
                        if !session.keyPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Key Discussion Points")
                                    .font(.headline)
                                ForEach(session.keyPoints, id: \.self) { point in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•").fontWeight(.bold)
                                        Text(point)
                                    }
                                }
                            }
                        }
                        
                        // Action Items
                        if !session.actionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Action Items")
                                    .font(.headline)
                                ForEach(session.actionItems, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "square")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                            .padding(.top, 2)
                                        Text(item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if session.chunks.isEmpty {
                            Text(session.transcript)
                                .lineSpacing(4)
                        } else {
                            ForEach(session.chunks) { chunk in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(chunk.speaker ?? "Speaker")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text(formatTimeOffset(chunk.offsetSeconds))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(chunk.text)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func formatTimeOffset(_ offset: TimeInterval) -> String {
        let mins = Int(offset / 60)
        let secs = Int(offset.truncatingRemainder(dividingBy: 60))
        return String(format: "[%02d:%02d]", mins, secs)
    }
}

// MARK: - Empty Detail View
struct EmptyMeetingDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Meeting Selected")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Select a meeting from the sidebar or record a new one to see transcription details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
