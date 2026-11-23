//
//  DashboardNavigationRouter.swift
//  EchoTune
//
//  Holds "open the dashboard on X" until a dashboard view is actually there to
//  receive it.
//
//  WHY THIS EXISTS
//  ---------------
//  `showDashboard(item:)` used to raise the window and then post a notification.
//  A notification is fire-and-forget: if the SwiftUI view had not mounted yet
//  (fresh window, or the WindowGroup window SwiftUI creates itself and which we
//  cannot give an init parameter), the message was simply lost and the user landed
//  on Home. That is the same bug "Manage AI Models & Keys…" had in Settings.
//
//  The router stores the destination, so delivery no longer depends on timing:
//  whichever happens last — the request or the view appearing — completes it.
//

import Foundation

final class DashboardNavigationRouter {

    static let shared = DashboardNavigationRouter()

    static let notificationName = Notification.Name("NavigateDashboardToItem")

    private let lock = NSLock()
    private var pending: NavigationItem?

    /// Internal so tests can use a private instance: the test host is the real app,
    /// whose live dashboard drains `.shared` the moment a request arrives.
    init() {}

    /// Records the destination and tells any mounted dashboard to go there.
    func request(_ item: NavigationItem) {
        lock.lock()
        pending = item
        lock.unlock()

        NotificationCenter.default.post(
            name: Self.notificationName,
            object: nil,
            userInfo: ["item": item.rawValue]
        )
    }

    /// Returns the waiting destination, if any, and clears it. A view calls this
    /// when it appears and whenever the notification arrives, so a destination is
    /// delivered exactly once.
    func consume() -> NavigationItem? {
        lock.lock()
        defer { lock.unlock() }
        let item = pending
        pending = nil
        return item
    }

    /// Non-destructive peek, for tests.
    var pendingItem: NavigationItem? {
        lock.lock()
        defer { lock.unlock() }
        return pending
    }
}
