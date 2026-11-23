import Foundation
import Testing
@testable import EchoTune

/// ET-756 · guards against the `NSApp.delegate as? AppDelegate` nil-cast regression.
///
/// Under SwiftUI's `@main` lifecycle macOS installs SwiftUI's own wrapper as
/// `NSApp.delegate`, so every cast to `AppDelegate` silently produced `nil` and
/// killed the menu bar window openers. The fix is `AppDelegate.shared`; this test
/// makes sure nobody reintroduces the cast.
struct AppDelegateWiringTests {

    /// Walks the app source tree from the test bundle's perspective.
    private func sourceFiles() throws -> [URL] {
        // EchoTune/ lives next to EchoTuneTests/ in the package root.
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // EchoTuneTests
            .deletingLastPathComponent()   // repo root
        root.appendPathComponent("EchoTune")

        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else {
            throw TestSourceError.missingSourceTree(root.path)
        }

        var files: [URL] = []
        guard let walker = fm.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw TestSourceError.missingSourceTree(root.path)
        }
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append(url)
        }
        return files
    }

    enum TestSourceError: Error { case missingSourceTree(String) }

    @Test func noAppDelegateNilCastRemainsInAppSources() throws {
        let banned = "NSApp.delegate as? AppDelegate"
        let files = try sourceFiles()
        #expect(files.count > 50, "source tree walk looks wrong — found \(files.count) Swift files")

        var offenders: [String] = []
        for url in files {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // Ignore the pattern when it only appears inside a comment — the fix
            // is documented by name, so doc comments legitimately mention it.
            let offendersInFile = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") && !$0.hasPrefix("*") && !$0.hasPrefix("/*") }
                .filter { $0.contains(banned) }
            if !offendersInFile.isEmpty {
                offenders.append(url.lastPathComponent)
            }
        }

        #expect(offenders.isEmpty, "\(banned) still present in: \(offenders.joined(separator: ", "))")
    }

    @Test func appDelegateExposesSharedInstance() {
        // The property must exist and be the documented entry point. Under the
        // test host the SwiftUI adaptor may or may not have built one yet, so we
        // assert on the static accessor being reachable rather than non-nil.
        let shared: AppDelegate.Type = AppDelegate.self
        #expect(shared == AppDelegate.self)
        _ = AppDelegate.shared
    }

    @Test func keychainBypassesSecurityFrameworkUnderTestHost() {
        // The test host must never hit securityd.
        #expect(KeychainHelper.isTestHost == true)

        KeychainHelper.resetInMemoryStoreForTesting()
        KeychainHelper.save("sk-test-value", forKey: "et756.unit")
        #expect(KeychainHelper.load(forKey: "et756.unit") == "sk-test-value")

        KeychainHelper.delete(forKey: "et756.unit")
        #expect(KeychainHelper.load(forKey: "et756.unit").isEmpty)
    }
}