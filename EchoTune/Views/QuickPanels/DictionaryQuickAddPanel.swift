//
//  DictionaryQuickAddPanel.swift
//  EchoTune
//
//  Floating Quick-Add to Dictionary HUD (⌘⇧D).
//  Captures any highlighted word/phrase in the active app so users can teach
//  EchoTune a custom spelling or spoken replacement in one keystroke.
//

import AppKit
import SwiftUI

@MainActor
final class DictionaryQuickAddPanelController {
    static let shared = DictionaryQuickAddPanelController()

    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    private init() {}

    func show() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }

        let initialWord = SelectedTextService.shared.readSelectedTextViaAX()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let content = DictionaryQuickAddView(
            initialWord: initialWord,
            onClose: { [weak self] in self?.close() }
        )
        let hosting = NSHostingController(rootView: content)
        let p = panel ?? {
            let win = NSPanel(contentViewController: hosting)
            win.title = "Quick Add to Dictionary"
            win.styleMask = [.titled, .closable, .fullSizeContentView, .hudWindow]
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.level = .floating
            win.isFloatingPanel = true
            win.hidesOnDeactivate = true
            return win
        }()
        p.contentViewController = hosting
        p.setContentSize(NSSize(width: 420, height: 220))
        self.panel = p

        if let screen = RecorderScreenResolver.resolveForShow() {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - 210, y: f.midY - 80))
            RecorderScreenResolver.releaseLock()
        } else {
            p.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        if let prev = previousApp, !prev.isTerminated {
            prev.activate()
        }
    }
}

struct DictionaryQuickAddView: View {
    let onClose: () -> Void

    @State private var mode: Int = 0 // 0 = Custom Spelling, 1 = Spoken Replacement
    @State private var canonicalWord: String
    @State private var spokenVariant: String = ""

    init(initialWord: String, onClose: @escaping () -> Void) {
        self._canonicalWord = State(initialValue: initialWord)
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Add to EchoTune Dictionary", systemImage: "character.book.closed.fill")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onClose)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            Picker("", selection: $mode) {
                Text("Custom Spelling (Phonetic)").tag(0)
                Text("Spoken → Written Rule").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == 0 {
                TextField("Correct word or name (e.g. EchoTune, Kubernetes)", text: $canonicalWord)
                    .textFieldStyle(.roundedBorder)
                TextField("Optional misheard variations, comma-separated", text: $spokenVariant)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("When I say… (e.g. my email)", text: $spokenVariant)
                    .textFieldStyle(.roundedBorder)
                TextField("Type instead… (e.g. name@domain.com)", text: $canonicalWord)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Save to Dictionary") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(canonicalWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || (mode == 1 && spokenVariant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(18)
        .frame(width: 420, height: 220)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    private func saveAndClose() {
        let word = canonicalWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }

        if mode == 0 {
            let vars = spokenVariant
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            DictionaryManager.shared.addSpelling(CorrectSpelling(word: word, variations: vars))
        } else {
            let spoken = spokenVariant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !spoken.isEmpty else { return }
            DictionaryManager.shared.addReplacement(WordReplacement(spokenForm: spoken, writtenForm: word))
        }
        onClose()
    }
}
