import Foundation
import Testing
@testable import EchoTune

/// ET-767 · expanded browser URL triggers (Dia & Comet).
struct ActiveBrowserInspectorTests {

    // MARK: Acceptance criteria

    @Test func diaIsRecognisedAsABrowser() {
        #expect(ActiveBrowserInspector.isBrowser("company.thebrowser.dia"))
    }

    @Test func cometIsRecognisedAsABrowser() {
        #expect(ActiveBrowserInspector.isBrowser("ai.perplexity.comet"))
    }

    // MARK: No regressions in the existing roster

    @Test func existingBrowsersStillWork() {
        let known = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi",
            "org.mozilla.firefox"
        ]
        for bundleID in known {
            #expect(ActiveBrowserInspector.isBrowser(bundleID), "\(bundleID) must stay recognised")
        }
    }

    @Test func nonBrowsersAreRejected() {
        #expect(ActiveBrowserInspector.isBrowser("com.tinyspeck.slackmacgap") == false)
        #expect(ActiveBrowserInspector.isBrowser("com.apple.finder") == false)
        #expect(ActiveBrowserInspector.isBrowser("") == false)
        #expect(ActiveBrowserInspector.isBrowser("com.example.unknown") == false)
    }

    @Test func bundleIdentifiersAreWellFormed() {
        // A typo in a bundle id silently disables the trigger, so pin the shape.
        for bundleID in ["company.thebrowser.dia", "ai.perplexity.comet"] {
            #expect(bundleID.contains("."), "\(bundleID) must be reverse-DNS")
            #expect(!bundleID.contains(" "), "\(bundleID) must not contain spaces")
            #expect(bundleID == bundleID.lowercased(), "\(bundleID) must be lowercase")
        }
    }
}
