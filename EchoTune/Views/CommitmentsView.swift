//
//  CommitmentsView.swift
//  EchoTune
//
//  The face of Echo's offline task memory: ask whether something got done, and
//  see the receipt — the sentence you actually said, and when.
//

import SwiftUI

/// Non-blocking review surface for locally detected commitments.
struct CommitmentProposalBanner: View {
    @ObservedObject private var memory = CommitmentMemoryManager.shared

    var body: some View {
        VStack(spacing: 10) {
            ForEach(memory.pendingProposals) { proposal in
                CommitmentProposalEditor(proposal: proposal)
            }
        }
    }
}

private struct CommitmentProposalEditor: View {
    @ObservedObject private var memory = CommitmentMemoryManager.shared
    @State private var proposal: CommitmentProposal
    @State private var dueEnabled: Bool
    @State private var dueDate: Date

    init(proposal: CommitmentProposal) {
        _proposal = State(initialValue: proposal)
        _dueEnabled = State(initialValue: proposal.dueDate != nil)
        _dueDate = State(initialValue: proposal.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Possible follow-up", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button { memory.dismissProposal(id: proposal.id) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help("Dismiss")
            }
            TextField("Task", text: $proposal.task)
            HStack {
                TextField("Person (optional)", text: $proposal.person)
                TextField("Context", text: $proposal.context)
            }
            HStack {
                Picker("Priority", selection: $proposal.priority) {
                    ForEach(CommitmentPriority.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .frame(width: 130)
                Toggle("Due", isOn: $dueEnabled)
                if dueEnabled {
                    DatePicker("", selection: $dueDate, displayedComponents: [.date])
                        .labelsHidden()
                }
                Text("Confidence \(Int(proposal.confidence * 100))%")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Dismiss") { memory.dismissProposal(id: proposal.id) }
                Button("Save task") {
                    proposal.dueDate = dueEnabled ? dueDate : nil
                    _ = memory.acceptProposal(proposal)
                }
                    .buttonStyle(.borderedProminent)
            }
            Text("Source: \u{201C}\(proposal.sourceSentence)\u{201D}")
                .font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .textFieldStyle(.roundedBorder)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .frame(maxWidth: 520)
        .onChange(of: proposal) { _, updated in
            memory.updateProposal(updated)
        }
    }
}

struct CommitmentsView: View {
    /// The standalone window shows a Done button; the dashboard pane doesn't.
    var showsCloseButton: Bool = true

    @ObservedObject private var memory = CommitmentMemoryManager.shared

    @State private var query = ""
    @State private var filter: Filter = .open
    @State private var copiedList = false

    enum Filter: String, CaseIterable, Identifiable {
        case open = "Open"
        case done = "Done"
        case all = "All"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !memory.pendingProposals.isEmpty {
                CommitmentProposalBanner()
            }
            askBar
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                answerCard
            }
            filterPicker
            list
            footer
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 420)
        .background(backgroundView)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundStyle(OnboardingTheme.brandGradient)
                    Text("Tasks")
                        .font(.title2.bold())
                }
                Text("Everything you said you'd do — remembered on this Mac, never uploaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                copyList()
            } label: {
                Label(copiedList ? "Copied" : "Copy list", systemImage: copiedList ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(memory.openCommitments.isEmpty)

            if showsCloseButton {
                Button("Done") { closeWindow() }
                    .keyboardShortcut(.escape)
            }
        }
    }

    // MARK: - Ask bar

    private var askBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Ask: did I sort Nila's passport?", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var answerCard: some View {
        let answer = memory.answer(query)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: answer.verdict))
                .foregroundColor(tint(for: answer.verdict))
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(answer.headline)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let first = answer.matches.first, let sentence = first.completionSentence {
                    Text("Heard: “\(sentence)”")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let first = answer.matches.first {
                    Text("Heard: “\(first.rawSentence)”")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(tint(for: answer.verdict).opacity(0.12))
        )
    }

    private func icon(for verdict: CommitmentAnswer.Verdict) -> String {
        switch verdict {
        case .completed: return "checkmark.circle.fill"
        case .open: return "clock.badge.exclamationmark"
        case .unknown: return "questionmark.circle"
        }
    }

    private func tint(for verdict: CommitmentAnswer.Verdict) -> Color {
        switch verdict {
        case .completed: return .green
        case .open: return .orange
        case .unknown: return .secondary
        }
    }

    // MARK: - Filter + list

    private var filterPicker: some View {
        Picker("", selection: $filter) {
            ForEach(Filter.allCases) { option in
                Text(label(for: option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func label(for option: Filter) -> String {
        switch option {
        case .open: return "Open (\(memory.openCount))"
        case .done: return "Done (\(memory.completedCommitments.count))"
        case .all: return "All (\(memory.commitments.count))"
        }
    }

    private var shown: [Commitment] {
        let base: [Commitment]
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = memory.commitments
        } else {
            base = memory.search(query)
        }
        switch filter {
        case .open: return base.filter { $0.status == .open }
        case .done: return base.filter { $0.status == .completed }
        case .all: return base.filter { $0.status != .dismissed }
        }
    }

    @ViewBuilder
    private var list: some View {
        if shown.isEmpty {
            emptyState
        } else {
            ScrollView {
                // Deliberately not lazy: task lists are short, and a plain
                // stack renders predictably in every context (windows,
                // dashboard pane, offscreen previews).
                VStack(spacing: 6) {
                    ForEach(shown) { commitment in
                        CommitmentRow(
                            commitment: commitment,
                            onToggle: { toggle(commitment) },
                            onDismiss: { memory.dismiss(id: commitment.id) },
                            onDelete: { memory.delete(id: commitment.id) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: memory.commitments.isEmpty ? "waveform" : "checkmark.seal")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(memory.commitments.isEmpty ? "No tasks yet" : "Nothing here")
                .font(.headline)
            Text(memory.commitments.isEmpty
                 ? "Say something like “I need to renew the car insurance” while dictating and it lands here."
                 : "Try another filter or clear the search.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if !memory.dueToday.isEmpty {
                Label("\(memory.dueToday.count) due", systemImage: "bell.badge")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var footerText: String {
        if memory.commitments.isEmpty {
            return "Tasks are mined from your dictation, offline."
        }
        return "\(memory.openCount) open · \(memory.completedCommitments.count) done · mined offline from your dictation"
    }

    private var backgroundView: some View {
        Group {
            if showsCloseButton {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ commitment: Commitment) {
        if commitment.status == .completed {
            memory.reopen(id: commitment.id)
        } else {
            memory.markDone(id: commitment.id)
        }
    }

    private func copyList() {
        let lines = memory.openCommitments
            .sorted { $0.createdAt < $1.createdAt }
            .map { commitment -> String in
                let due = commitment.dueHint.map { " (due \(CommitmentMemoryManager.dayFormatter.string(from: $0)))" } ?? ""
                return "- [ ] \(commitment.title)\(due)"
            }
        let text = "Tasks\n" + lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedList = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copiedList = false }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Row

private struct CommitmentRow: View {
    let commitment: Commitment
    let onToggle: () -> Void
    let onDismiss: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: commitment.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(commitment.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(commitment.status == .completed ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title)
                    .font(.body)
                    .strikethrough(commitment.status == .completed, color: .secondary)
                    .foregroundColor(commitment.status == .completed ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let due = commitment.dueHint, commitment.status == .open {
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("due \(CommitmentMemoryManager.dayFormatter.string(from: due))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                if commitment.rawSentence != commitment.title {
                    Text("“\(commitment.rawSentence)”")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Menu {
                if commitment.status == .completed {
                    Button("Mark as not done", action: onToggle)
                } else {
                    Button("Mark as done", action: onToggle)
                }
                Button("Copy task") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(commitment.title, forType: .string)
                }
                Divider()
                if commitment.status != .dismissed {
                    Button("Dismiss", action: onDismiss)
                }
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
            .opacity(isHovering ? 1 : 0.45)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0.03))
        )
        .onHover { isHovering = $0 }
        .contextMenu {
            if commitment.status == .completed {
                Button("Mark as not done", action: onToggle)
            } else {
                Button("Mark as done", action: onToggle)
            }
            Button("Copy task") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commitment.title, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var statusText: String {
        switch commitment.status {
        case .open:
            return "Added \(CommitmentMemoryManager.dayFormatter.string(from: commitment.createdAt))"
        case .completed:
            if let completed = commitment.completedAt {
                return "Done \(CommitmentMemoryManager.dayFormatter.string(from: completed))"
            }
            return "Done"
        case .dismissed:
            return "Dismissed"
        }
    }
}

// MARK: - Window Controller

class CommitmentsWindowController: NSWindowController {
    convenience init() {
        let view = CommitmentsView()
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Tasks"
        window.setContentSize(NSSize(width: 560, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}
