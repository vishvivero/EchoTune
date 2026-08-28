//
//  ScreenContextManager.swift
//  EchoTune
//
//  Created by pi on 28/08/2026.
//
//  Gathers lightweight "screen context" — the frontmost app name and window
//  title — via ScreenCaptureKit, so the AI enhancement prompt can resolve
//  ambiguous references ("this file", "that bug").
//
//  Privacy: only the frontmost app's NAME and the window TITLE are read.
//  No pixels are captured, nothing is stored, nothing leaves the device
//  except as part of the (user-configured) AI enhancement request.
//
//  Side benefit: performing a real SCShareableContent query is what makes
//  macOS list EchoTune in the Screen Recording pane at all.
//

import Foundation
import Combine
import AppKit
import SwiftUI
import ScreenCaptureKit

@available(macOS 14.0, *)
final class ScreenContextManager: ObservableObject {
    static let shared = ScreenContextManager()

    @Published private(set) var currentContext: ScreenContext?

    private let refreshInterval: TimeInterval = 5
    private var pendingRefresh: Task<Void, Never>?
    private var lastRefresh: Date?

    struct ScreenContext {
        let appName: String
        let windowTitle: String?
        let browserURL: String?

        /// Compact one-liner for the enhancement prompt.
        var promptFragment: String {
            var parts = ["app: \(appName)"]
            if let t = windowTitle, !t.isEmpty { parts.append("window: \(t)") }
            if let u = browserURL, !u.isEmpty { parts.append("url: \(u)") }
            return parts.joined(separator: "; ")
        }
    }

    private init() {}

    // MARK: - Public

    /// One-line context hint for the enhancement prompt, or nil.
    func promptHint() async -> String? {
        guard let ctx = await currentContextIfAvailable() else { return nil }
        return ctx.promptFragment
    }

    /// Performs one ScreenCaptureKit content query. The first successful call
    /// is what registers EchoTune in System Settings' Screen Recording pane.
    func refresh() async {
        if let pending = pendingRefresh {
            await pending.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        pendingRefresh = task
        await task.value
        pendingRefresh = nil
    }

    // MARK: - Internals

    private func currentContextIfAvailable() async -> ScreenContext? {
        guard CGPreflightScreenCaptureAccess() else {
            // Not granted — never nag; Settings/Onboarding drive the grant.
            return nil
        }

        if let last = lastRefresh,
           Date().timeIntervalSince(last) < refreshInterval,
           let cached = currentContext {
            return cached
        }

        await refresh()
        return currentContext
    }

    private func performRefresh() async {
        do {
            // This call is the TCC trigger: it asks WindowServer for
            // shareable content, which requires Screen Recording permission.
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let bundleID = frontApp.bundleIdentifier else { return }

            let windowTitle = content.windows
                .filter { $0.owningApplication?.bundleIdentifier == bundleID }
                .filter { $0.isOnScreen }
                .compactMap { window in window.title }
                .first

            var browserURL: String? = nil
            if ActiveBrowserInspector.isBrowser(bundleID) {
                browserURL = ActiveBrowserInspector.frontmostTabURL()?.absoluteString
            }

            let context = ScreenContext(
                appName: frontApp.localizedName ?? "an app",
                windowTitle: windowTitle,
                browserURL: browserURL
            )

            await MainActor.run {
                self.currentContext = context
                self.lastRefresh = Date()
            }

            debugLog("🖥️ Screen context: \(context.promptFragment)")
        } catch {
            // Permission denied mid-flight, or no windows — degrade quietly.
            debugLog("🖥️ Screen context unavailable: \(error.localizedDescription)")
            await MainActor.run {
                self.lastRefresh = Date()
            }
        }
    }
}
