import Foundation
import Testing
@testable import EchoTune

/// P1 · a dashboard destination must survive the view not being mounted yet.
@Suite(.serialized)
struct DashboardNavigationRouterTests {


    @Test func aRequestIsHeldUntilSomeoneConsumesIt() {
        let router = DashboardNavigationRouter()
        router.request(.history)

        // Nobody was listening, yet the destination is still there.
        #expect(router.pendingItem == .history)
        #expect(router.consume() == .history)
    }

    @Test func aDestinationIsDeliveredExactlyOnce() {
        let router = DashboardNavigationRouter()
        router.request(.dictionary)
        #expect(router.consume() == .dictionary)
        #expect(router.consume() == nil, "a second consume must find nothing")
    }

    @Test func theLatestRequestWins() {
        let router = DashboardNavigationRouter()
        router.request(.notes)
        router.request(.share)
        #expect(router.consume() == .share)
    }

    @Test func consumingWithNothingPendingIsSafe() {
        #expect(DashboardNavigationRouter().consume() == nil)
    }

    @Test func aMountedViewIsToldViaNotification() {
        let router = DashboardNavigationRouter()
        let received = Box()
        let token = NotificationCenter.default.addObserver(
            forName: DashboardNavigationRouter.notificationName, object: nil, queue: nil
        ) { note in received.value = note.userInfo?["item"] as? String }
        defer { NotificationCenter.default.removeObserver(token) }

        router.request(.tasks)
        #expect(received.value == NavigationItem.tasks.rawValue)
    }

    private final class Box: @unchecked Sendable { var value: String? }

    // MARK: Wiring

    @Test func dashboardViewDrainsTheRouterOnAppearAndOnNotification() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Views/MainDashboardView.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        #expect(source.contains(".onAppear"))
        #expect(source.contains("DashboardNavigationRouter.shared.consume()"))
        #expect(source.components(separatedBy: "DashboardNavigationRouter.shared.consume()").count - 1 >= 2,
                "both onAppear and the notification handler must drain the router")
        #expect(source.contains("init(initialItem:"))
    }

    @Test func showDashboardGoesThroughTheRouterAndTheSharedFocusPath() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        root.appendPathComponent("EchoTune/App/AppDelegate.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        #expect(source.contains("DashboardNavigationRouter.shared.request(item)"))
        #expect(source.contains("MainDashboardView(initialItem: initialItem)"))
        #expect(!source.contains("name: NSNotification.Name(\"NavigateDashboardToItem\")"),
                "the raw fire-and-forget notification must not be posted directly any more")
    }
}
