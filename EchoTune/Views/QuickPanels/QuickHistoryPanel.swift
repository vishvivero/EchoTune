//
//  QuickHistoryPanel.swift
//  EchoTune
//
//  Spotlight-style floating Quick History HUD (⌘⇧H).
//  Search recent transcriptions and click/press Return to paste directly into
//  the previously active application, or Copy to clipboard.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class QuickHistoryPanelController {
    static let shared = QuickHistoryPanelController()

    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    private init() {}

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        if panel == nil {
            let content = QuickHistoryHUDView(
                onPaste: { [weak self] text in
                    self?.pasteIntoPreviousApp(text)
                },
                onClose: { [weak self] in
                    self?.close()
                }
            )
            let hosting = NSHostingController(rootView: content)
            let p = NSPanel(contentViewController: hosting)
            p.title = "Quick History"
            p.styleMask = [.titled, .closable, .fullSizeContentView, .hudWindow]
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.level = .floating
            p.isFloatingPanel = true
            p.hidesOnDeactivate = true
            p.setContentSize(NSSize(width: 520, height: 380))
            self.panel = p
        }

        if let screen = RecorderScreenResolver.resolveForShow() {
            let f = screen.visibleFrame
            let x = f.midX - 260
            let y = f.midY - 140
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
            RecorderScreenResolver.releaseLock()
        } else {
            panel?.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        if let prev = previousApp, !prev.isTerminated {
            prev.activate()
        }
    }

    private func pasteIntoPreviousApp(_ text: String) {
        panel?.orderOut(nil)
        if let prev = previousApp, !prev.isTerminated {
            prev.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            TextInsertionManager.shared.insertText(text) { _ in }
        }
    }
}

struct QuickHistoryHUDView: View {
    let onPaste: (String) -> Void
    let onClose: () -> Void

    @ObservedObject private var history = TranscriptionHistoryManager.shared
    @State private var query: String = ""
    @State private var copiedID: UUID? = nil

    private var filtered: [TranscriptionHistoryItem] {
        let items = Array(history.transcriptions.prefix(40))
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search recent dictations… (Click Paste to insert)", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit {
                        if let first = filtered.first {
                            onPaste(first.text)
                        }
                    }

                Button(action: onClose) {
                    Text("ESC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(history.transcriptions.isEmpty ? "No transcriptions recorded yet" : "No matching transcriptions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { item in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                HStack(spacing: 6) {
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(item.text, forType: .string)
                                        copiedID = item.id
                                    } label: {
                                        Image(systemName: copiedID == item.id ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button("Paste") {
                                        onPaste(item.text)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 520, height: 380)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}
