import XCTest
import Foundation

final class OnboardingPhase1UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
        }
    }

    @MainActor
    func testPermissionsStepLoads() throws {
        prepareOnboarding(step: 1)

        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-force-onboarding", "--ui-test-onboarding-step", "1"]
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.permissions.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.permissions.continueButton"].waitForExistence(timeout: 5))

        let micCardVisible = app.buttons["onboarding.permissions.microphone.grantButton"].exists ||
            app.staticTexts["onboarding.permissions.microphone.grantedLabel"].exists
        let accessibilityCardVisible = app.buttons["onboarding.permissions.accessibility.grantButton"].exists ||
            app.staticTexts["onboarding.permissions.accessibility.grantedLabel"].exists
        let screenCardVisible = app.buttons["onboarding.permissions.screenRecording.grantButton"].exists ||
            app.staticTexts["onboarding.permissions.screenRecording.grantedLabel"].exists

        XCTAssertTrue(micCardVisible)
        XCTAssertTrue(accessibilityCardVisible)
        XCTAssertTrue(screenCardVisible)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Permissions Step"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLiveDemoProducesResult() throws {
        prepareOnboarding(step: 3)

        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-force-onboarding", "--ui-test-onboarding-step", "3"]
        addUIInterruptionMonitor(withDescription: "System Permission Alerts") { alert in
            for label in ["Allow", "OK", "Open System Settings", "Continue"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.click()
                    return true
                }
            }
            return false
        }

        app.launch()

        let recordButton = app.buttons["onboarding.liveDemo.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 12), "Expected the live demo record button to load")

        sleep(2) // Give ModelManager a moment to settle on the saved local model
        recordButton.click()

        // Play a phrase through the Mac speakers so the mic can pick it up during the demo.
        try playDemoPhrase()

        // The demo auto-stops after 15s, then renders the transcription result.
        let resultText = app.staticTexts["onboarding.liveDemo.resultText"]
        XCTAssertTrue(resultText.waitForExistence(timeout: 60), "Expected the live demo to render a result")

        let caption = app.staticTexts["onboarding.liveDemo.resultCaption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "Expected the live demo to render a caption")

        print("DEBUG: resultText exists: \(resultText.exists)")
        print("DEBUG: resultText label: '\(resultText.label)'")
        print("DEBUG: resultText value: '\(String(describing: resultText.value))'")
        print("DEBUG: resultText debugDescription: \(resultText.debugDescription)")
        let nonEmptyResultPredicate = NSPredicate(format: "label.length > 0 OR (value != nil AND value != '')")
        let nonEmptyResultExpectation = expectation(for: nonEmptyResultPredicate, evaluatedWith: resultText)
        wait(for: [nonEmptyResultExpectation], timeout: 5)

        let captionValue = caption.textValue
        XCTAssertFalse(captionValue.contains("failed"), "Live demo reported a failure: \(captionValue)")
        XCTAssertFalse(captionValue.contains("Permission"), "Live demo hit a permission problem: \(captionValue)")
        XCTAssertFalse(captionValue.contains("required"), "Live demo still needs a permission/model setup: \(captionValue)")

        let resultValue = resultText.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(resultValue.isEmpty, "Live demo result text was empty")
        XCTAssertFalse(resultValue.contains("No words were detected"), "Live demo did not hear the playback phrase")
        XCTAssertFalse(resultValue.contains("No audio was captured"), "Live demo failed to record audio")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live Demo Result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Helpers

    private func prepareOnboarding(step: Int) {
        runShell("killall EchoTune >/dev/null 2>&1 || true")
        runShell("defaults write com.echotune.EchoTune hasCompletedOnboarding -bool false")
        runShell("defaults write com.echotune.EchoTune currentOnboardingStep -int \(step)")
        runShell("defaults write com.echotune.EchoTune defaultModelID -string distil-whisper_distil-large-v3_turbo")
        runShell("defaults write com.echotune.EchoTune defaultTranscriptionModel -string distil-whisper_distil-large-v3_turbo")
    }

    private func playDemoPhrase() throws {
        let phrase = "hello from echotune onboarding test"
        runShell("say '\(phrase)'")
    }

    private func runShell(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            XCTFail("Shell command failed to launch: \(command) — \(error.localizedDescription)")
        }
    }
}

extension XCUIElement {
    var textValue: String {
        if let str = value as? String, !str.isEmpty {
            return str
        }
        return label
    }
}
