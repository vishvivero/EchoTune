//
//  MeetingDetailView.swift
//  EchoTune
//
//  Shows the full detail of a completed meeting — summary, action items, transcript.
//

import SwiftUI

@available(macOS 13.0, *)
struct MeetingDetailView: View {
    let meeting: MeetingSession
    @ObservedObject private var meetingManager = MeetingManager.shared
    @State private var selectedTab: MeetingDetailTab = .summary
    @State private var showRegenerateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            Divider()

            // Tab bar
            tabBar
            Divider()

            // Content
            ScrollView {
                switch selectedTab {
                case .summary:
                    summaryContent
                case .transcript:
                    transcriptContent
                case .actionItems:
                    actionItemsContent
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(meeting.templateUsed.emoji)
                    Text(meeting.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 8) {
                    Label(meeting.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Label(meeting.formattedDuration, systemImage: "clock")
                    if let app = meeting.detectedApp {
                        Label(app, systemImage: "app")
                    }
                    if !meeting.participants.isEmpty {
                        Label("\(meeting.participants.count) participants", systemImage: "person.2")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { copyToClipboard() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help("Copy summary to clipboard")

                Menu {
                    Button("Regenerate Summary") { regenerateSummary() }
                    ForEach(MeetingTemplate.allCases) { template in
                        Button("Re-summarise as \(template.rawValue)") {
                            meetingManager.regenerateSummary(for: meeting.id, template: template)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MeetingDetailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                            Text(tab.title)
                            if tab == .actionItems && !meeting.actionItems.isEmpty {
                                Text("\(meeting.actionItems.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: - Summary Content

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if meetingManager.isGeneratingSummary {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating summary...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            if let summary = meeting.summary, !summary.isEmpty {
                sectionCard(title: "Summary", icon: "text.alignleft") {
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            if !meeting.keyPoints.isEmpty {
                sectionCard(title: "Key Points", icon: "star") {
                    ForEach(meeting.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundColor(.accentColor)
                                .padding(.top, 6)
                            Text(point)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !meeting.decisions.isEmpty {
                sectionCard(title: "Decisions", icon: "checkmark.seal") {
                    ForEach(meeting.decisions, id: \.self) { decision in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(decision)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !meeting.participants.isEmpty {
                sectionCard(title: "Participants", icon: "person.2") {
                    FlowLayout(spacing: 6) {
                        ForEach(meeting.participants, id: \.self) { participant in
                            Text(participant)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Transcript Content

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if meeting.chunks.isEmpty {
                Text(meeting.transcript)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
            } else {
                ForEach(meeting.chunks) { chunk in
                    HStack(alignment: .top, spacing: 12) {
                        Text(formatChunkOffset(chunk.offsetSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.accentColor)
                            .frame(width: 50, alignment: .trailing)

                        Text(chunk.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
                .padding()
            }
        }
    }

    // MARK: - Action Items Content

    private var actionItemsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if meeting.actionItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No action items found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(meeting.actionItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "square")
                            .foregroundColor(.accentColor)
                        Text(item)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func copyToClipboard() {
        var text = "# \(meeting.title)\n\n"
        if let summary = meeting.summary {
            text += "## Summary\n\(summary)\n\n"
        }
        if !meeting.keyPoints.isEmpty {
            text += "## Key Points\n"
            meeting.keyPoints.forEach { text += "• \($0)\n" }
            text += "\n"
        }
        if !meeting.actionItems.isEmpty {
            text += "## Action Items\n"
            meeting.actionItems.forEach { text += "☐ \($0)\n" }
            text += "\n"
        }
        if !meeting.decisions.isEmpty {
            text += "## Decisions\n"
            meeting.decisions.forEach { text += "✓ \($0)\n" }
            text += "\n"
        }
        text += "## Transcript\n\(meeting.transcript)"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func regenerateSummary() {
        meetingManager.regenerateSummary(for: meeting.id)
    }

    private func formatChunkOffset(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Supporting Types

enum MeetingDetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
    case actionItems = "Action Items"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .summary: return "doc.text"
        case .transcript: return "text.quote"
        case .actionItems: return "checklist"
        }
    }
}

// Simple flow layout for participant tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxHeight = max(maxHeight, y + rowHeight)
        }

        return (CGSize(width: maxWidth, height: maxHeight), positions)
    }
}
