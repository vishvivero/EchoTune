//
//  ClipboardHistoryManager.swift
//  EchoTune
//
//  Clipboard-focused "Recent" menu tab.
//
//  WHY THIS EXISTS
//  ---------------
//  The menu bar's Recent tab is where you go to grab something you just had —
//  usually the transcript you copied a minute ago, or the link you copied before
//  that. EchoTune already owns the pasteboard when it inserts a dictation, so
//  recording what passes through it costs nothing and makes the tab genuinely
//  useful beyond dictation.
//
//  DESIGN NOTES
//  ------------
//  · Polls `NSPasteboard.changeCount`, which is the only reliable change signal
//    on macOS — there is no notification.
//  · Ignored when the frontmost app is a password manager, so secrets never land
//    in a searchable list.
//  · Capped and de-duplicated: repeating the same value moves it to the top
//    rather than filling the list.
//  · Never persisted to disk. The list lives in memory only, because a clipboard
//    history is the single most privacy-sensitive thing an app could cache.
//

import AppKit
import Combine

final class ClipboardHistoryManager: ObservableObject {

    static let shared = ClipboardHistoryManager(pasteboard: .general)

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let text: String
        let date: Date
        let source: Source

        enum Source: String {
            case clipboard
            case dictation

            var label: String {
                switch self {
                case .clipboard: return "Copied"
                case .dictation: return "Dictation"
                }
            }

            var symbol: String {
                switch self {
                case .clipboard: return "doc.on.clipboard"
                case .dictation: return "waveform"
                }
            }
        }
    }

    /// Newest first.
    @Published private(set) var entries: [Entry] = []

    /// How many entries to keep. In-memory only, so this stays small on purpose.
    static let capacity = 30

    /// Bundle identifiers whose clipboard contents must never be recorded.
    static let excludedBundleIdentifiers: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlane",
        "in.sinew.Enpass-Desktop",
        "com.lastpass.LastPass",
        "com.apple.Passwords",
        "com.apple.keychainaccess"
    ]

    private var lastChangeCount: Int
    private var pollTimer: Timer?
    private let pasteboard: NSPasteboard

    /// Internal so tests can bind a private pasteboard instead of the user's.
    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Recording

    /// Starts watching the pasteboard. Safe to call more than once.
    func startMonitoring() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit {
        pollTimer?.invalidate()
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Never capture what a password manager just put on the clipboard.
        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.excludedBundleIdentifiers.contains(frontmost) {
            return
        }

        guard let string = pasteboard.string(forType: .string) else { return }
        record(string, source: .clipboard)
    }

    /// Records a value the app itself placed on the pasteboard (a copied
    /// dictation), so Recent shows dictations and copies in one timeline.
    func recordDictationCopy(_ text: String) {
        record(text, source: .dictation)
        // The app's own write bumped changeCount; absorb it so the poller does
        // not immediately record the same value a second time as "copied".
        lastChangeCount = pasteboard.changeCount
    }

    private func record(_ raw: String, source: Entry.Source) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Very large blobs (images, file contents) are not transcripts; skip them
        // rather than bloating a searchable in-memory list.
        guard text.count <= 20_000 else { return }

        // Applied synchronously: the callers here are the pasteboard poller and the
        // card's copy button, both already on the main thread, and deferring made
        // the new entry invisible to anything that read `entries` immediately.
        // Repeat values move to the top instead of duplicating.
        entries.removeAll { $0.text == text }
        entries.insert(Entry(id: UUID(), text: text, date: Date(), source: source), at: 0)
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
    }

    // MARK: - Querying

    /// Case- and diacritic-insensitive substring search over the history.
    func search(_ query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Test hook: reset the poller's baseline so a test can simulate an external
    /// clipboard change deterministically.
    func resetChangeCountBaselineForTesting() {
        lastChangeCount = pasteboard.changeCount
    }
}