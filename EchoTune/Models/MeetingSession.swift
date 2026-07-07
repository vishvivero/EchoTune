//
//  MeetingSession.swift
//  EchoTune
//
//  Data model for meeting recordings.
//

import Foundation

/// Represents a single recorded meeting session.
struct MeetingSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }
    var transcript: String
    var summary: String?
    var actionItems: [String]
    var decisions: [String]
    var keyPoints: [String]
    var participants: [String]
    var detectedApp: String?  // "Zoom", "Teams", "Google Meet", etc.
    var templateUsed: MeetingTemplate
    var userNotes: String  // User's own notes taken during meeting
    var audioFilePath: String?  // Path to saved audio file (optional)
    var chunks: [TranscriptChunk]  // Individual transcription chunks with timestamps

    init(
        id: UUID = UUID(),
        title: String = "",
        startTime: Date = Date(),
        detectedApp: String? = nil,
        template: MeetingTemplate = .general
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = nil
        self.transcript = ""
        self.summary = nil
        self.actionItems = []
        self.decisions = []
        self.keyPoints = []
        self.participants = []
        self.detectedApp = detectedApp
        self.templateUsed = template
        self.userNotes = ""
        self.audioFilePath = nil
        self.chunks = []
    }

    /// Format duration as human-readable string
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

/// A timestamped chunk of transcript text
struct TranscriptChunk: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let offsetSeconds: TimeInterval  // seconds from meeting start
    let text: String
    var speaker: String?  // speaker label, e.g. "Speaker 1 (Me)" or "Speaker 2 (Guest)"

    init(id: UUID = UUID(), timestamp: Date = Date(), offsetSeconds: TimeInterval, text: String, speaker: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.offsetSeconds = offsetSeconds
        self.text = text
        self.speaker = speaker
    }
}

/// Meeting summary templates
enum MeetingTemplate: String, Codable, CaseIterable, Identifiable {
    case general = "General Meeting"
    case salesCall = "Sales Call"
    case oneOnOne = "1:1"
    case interview = "Interview"
    case standup = "Standup"
    case brainstorm = "Brainstorm"
    case custom = "Custom"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .general: return "📋"
        case .salesCall: return "💰"
        case .oneOnOne: return "👥"
        case .interview: return "🎤"
        case .standup: return "🏃"
        case .brainstorm: return "💡"
        case .custom: return "✏️"
        }
    }

    /// System prompt suffix for AI summary generation
    var summaryPromptContext: String {
        switch self {
        case .general:
            return "Format as structured meeting notes."
        case .salesCall:
            return "Focus on: prospect needs, objections, budget, timeline, next steps, and competitive mentions."
        case .oneOnOne:
            return "Focus on: feedback given/received, blockers, career development topics, action items for each person."
        case .interview:
            return "Focus on: candidate responses, technical assessment, culture fit signals, strengths, concerns, and hiring recommendation."
        case .standup:
            return "Format as: What was done yesterday, what's planned today, and blockers. Keep it brief."
        case .brainstorm:
            return "Capture all ideas discussed (even rejected ones), group by theme, highlight the top 3 ideas with rationale."
        case .custom:
            return "Format as structured meeting notes."
        }
    }
}
