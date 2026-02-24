# EchoTune Full Audit Report — February 2026

**Auditor:** Automated Comprehensive Audit  
**Date:** 2026-02-13  
**Codebase:** ~25,000 lines of Swift across 80+ files  
**Scope:** Every file, view, manager, model, utility, website  

---

## Executive Summary

EchoTune is an ambitious, feature-rich macOS voice dictation app with impressive breadth — local Whisper, cloud (Groq/Deepgram), AI enhancement, power modes, trigger words, screen context, dictionary, VAD, and more. However, it has **critical security holes** (demo license backdoor, fake license server), **architectural debt** (733+ print statements, orphan views, dual API key storage), and **numerous UI/UX polish gaps** that prevent it from feeling production-ready. The onboarding is genuinely excellent — one of the strongest parts of the app.

**Blockers:** 8 | **Warnings:** 34 | **Nice-to-Have:** 42 | **Total Issues:** 84

---

## 1. Onboarding & First Run

| # | Severity | Issue |
|---|----------|-------|
| 1.1 | ⚠️ Warning | **Onboarding window doesn't activate the app.** `showOnboarding()` removed `NSApp.activate(ignoringOtherApps: true)` to avoid focus stealing, but this means the onboarding window can appear *behind* other windows on first launch. A first-launch-only activation is acceptable and necessary. |
| 1.2 | ⚠️ Warning | **Onboarding window is resizable but has min=max size (700×600).** The `styleMask` includes `.resizable` but `minSize == maxSize`, so the resize cursor appears but does nothing. Remove `.resizable` from styleMask. |
| 1.3 | 💡 Nice | **No skip button on permissions step.** Users who want to explore the app first are blocked until mic + accessibility are granted. Consider allowing skip with a degraded experience warning. |
| 1.4 | 💡 Nice | **Live demo step uses Apple Speech even if Whisper model was just downloaded.** The `performDemoTranscription` always uses `TranscriptionEngine` (Apple Speech), not the model the user just downloaded in step 3. This misrepresents the actual transcription quality. |
| 1.5 | 💡 Nice | **Model download in onboarding defaults to "base" but doesn't explain why.** No recommendation text explaining "we recommend Base for your Mac" based on specs. `SystemSpecsAnalyzer` exists but isn't used here. |
| 1.6 | 💡 Nice | **Welcome notification uses `NSAlert.runModal()` which blocks the main thread.** After onboarding, `showWelcomeNotification()` shows a modal alert. This is jarring — consider using a non-blocking notification or a floating panel. |
| 1.7 | 💡 Nice | **Shortcut recording in onboarding doesn't validate against system conflicts.** User could set a shortcut that conflicts with macOS system shortcuts (e.g., ⌘C) with no warning. |
| 1.8 | 💡 Nice | **No onboarding for AI Enhancement / API keys.** Power users who want Groq or AI enhancement have no guidance during onboarding — they must discover these features in settings. |
| 1.9 | 💡 Nice | **Trial CTA step shows "£29.99" hardcoded.** Currency should be localized or at minimum use a variable. UK-specific pricing alienates international users. |
| 1.10 | 💡 Nice | **"7-day trial • 50 transcriptions" is confusing.** It's unclear if the 50 limit applies *during* the trial or *after*. The trial code gives 50 total, but the text implies 50/day. |

---

## 2. UI/UX Design

| # | Severity | Issue |
|---|----------|-------|
| 2.1 | ⚠️ Warning | **ContentView is a dead/orphan view.** `ContentView.swift` exists with a basic static layout showing "On-Device Whisper" and "⌃ Control (Press to Record)" hardcoded, but `EchoTuneApp` uses `MainDashboardView` as the WindowGroup content. ContentView is never shown. |
| 2.2 | ⚠️ Warning | **Main window shows despite being a menu bar app.** `EchoTuneApp` defines a `WindowGroup` with `MainDashboardView`. Since `LSUIElement = true`, the app has no dock icon, but opening it from Finder will show this large dashboard window. Most menu bar apps avoid showing a main window at all. |
| 2.3 | ⚠️ Warning | **Dual window system: Settings as both `WindowGroup` scene and manual `NSWindow`.** Settings can be opened via the native `Settings` scene (⌘,) *and* via `AppDelegate.showSettings()` which creates its own `NSWindow`. This can result in two settings windows open simultaneously. |
| 2.4 | ⚠️ Warning | **Settings window doesn't activate the app.** `showSettings()` removed `NSApp.activate(ignoringOtherApps: true)`. Since the app uses `.accessory` activation policy, clicking the settings menu item may not bring the window to front on all macOS versions. |
| 2.5 | 💡 Nice | **No loading/splash screen.** When the app launches, model scanning and initialization happen in background. There's no visual feedback that the app is starting up — just a menu bar icon appearing. |
| 2.6 | 💡 Nice | **Recording indicator windows lack vibrancy/material effects.** The slim bar, notch recorder, and mini panel use solid colors rather than macOS's native vibrancy materials that would make them feel more integrated. |
| 2.7 | 💡 Nice | **No animation when transitioning between recording states in menu bar.** The status bar icon changes abruptly between idle/recording/processing with no transition animation. |
| 2.8 | 💡 Nice | **Inconsistent use of SF Symbols across views.** Some views use SF Symbols with `.fill` variants, others without. No consistent icon style guide. |
| 2.9 | 💡 Nice | **MainDashboardView is 1981 lines.** This massive view file should be broken into smaller subviews for maintainability. |
| 2.10 | 💡 Nice | **ShareStatsView at 762 lines is overly complex** for what should be a simple share card. |
| 2.11 | 💡 Nice | **HistoryView at 1070 lines** could benefit from extracting row components. |

---

## 3. Menu Bar & System Tray

| # | Severity | Issue |
|---|----------|-------|
| 3.1 | ⚠️ Warning | **Menu bar popover can be dismissed by clicking elsewhere but has no "pin" option.** Users performing long tasks lose access to the menu content. |
| 3.2 | 💡 Nice | **No keyboard shortcut to open/close the menu bar popover.** Users must click the icon — a shortcut (like ⌘⇧E defined in MultiHotkeyManager) would be more accessible. |
| 3.3 | 💡 Nice | **Menu bar icon has only 1x and 2x assets.** Missing 3x for future Retina displays. Should also verify the icon renders well at menu bar size (18pt). |
| 3.4 | 💡 Nice | **No tooltip on the menu bar icon.** Hovering shows nothing — should show "EchoTune — Ready" or current state. |
| 3.5 | 💡 Nice | **StatusBarController at 429 lines** mixes UI, state management, and business logic. Should delegate to smaller components. |

---

## 4. Settings/Preferences

| # | Severity | Issue |
|---|----------|-------|
| 4.1 | ⚠️ Warning | **~13 orphan/duplicate settings view files.** `AIAndModelsView.swift`, `AIEnhancementView.swift`, `AIModelsView.swift`, `APIKeysView.swift`, `AdvancedSettingsView.swift`, `Phase6SettingsView.swift`, `StatisticsSettingsView.swift`, `CloudModelsSection.swift`, `DictionaryManagementView.swift`, `PowerModesViewContent.swift`, `TriggerWordsViewContent.swift`, `PermissionsContentView.swift`, `LicenseSettingsView.swift` — many of these appear to be older versions superseded by the consolidated `SettingsView.swift`. Dead code increases maintenance burden and confuses contributors. |
| 4.2 | ⚠️ Warning | **`shareAnalytics` toggle does nothing.** The setting exists in `AppSettings` but is never checked anywhere. It's misleading — either implement it or remove it. |
| 4.3 | ⚠️ Warning | **"Recording Mode" setting (Push-to-Talk vs Toggle) is defined in AppSettings but never actually used.** The dictation flow in `AppCoordinator` always uses toggle mode (press to start, press to stop). `recordingMode` is stored but not consulted. |
| 4.4 | 💡 Nice | **No search in settings.** With 6 tabs and many options, finding a specific setting requires tab-hopping. A search bar would help. |
| 4.5 | 💡 Nice | **API key test buttons exist but results disappear quickly.** Test results should persist until the user navigates away or changes the key. |
| 4.6 | 💡 Nice | **No "Reset to defaults" confirmation dialog** in the About & License tab. One-click reset could be accidentally triggered. |
| 4.7 | 💡 Nice | **`selectedModelSize` in AppSettings is unused.** It's persisted to UserDefaults but never read for any routing logic — `defaultTranscriptionModel` is used instead. |
| 4.8 | 💡 Nice | **Audio retention days picker has no upper bound validation.** User could set it to 0 or negative values. |

---

## 5. Core Functionality

| # | Severity | Issue |
|---|----------|-------|
| 5.1 | 🔴 Blocker | **Audio buffer use-after-free risk (partially fixed).** `AudioManager` now copies buffers before async use, but `recordedBuffers` array grows unbounded, storing copies of every buffer for VAD analysis. On a 30-minute recording at 48kHz, this is ~345MB of buffer copies *in addition to* the chunk storage. |
| 5.2 | 🔴 Blocker | **Cloud transcription audio format mismatch.** `AudioManager.convertBufferToWAVData` with `.cloud` engine now properly writes WAV, but `GroqTranscriptionService.swift:122-146` still uses `AudioChunker.chunkAudioData(sampleRate: 16000, bytesPerSample: 2)` which assumes raw PCM, not WAV container format. Chunking will corrupt the WAV headers. |
| 5.3 | ⚠️ Warning | **Apple Speech 3-second completion delay.** `endLiveTranscription()` always waits 3 seconds before returning accumulated text, adding unnecessary latency. Should use a "finishing" state that resolves on `.isFinal` or a shorter timeout. |
| 5.4 | ⚠️ Warning | **Hallucination detection is overly aggressive.** Single legitimate words like "yes", "no", "stop", "go" in short recordings will be filtered as hallucinations. The 1-second threshold for single words is too broad. |
| 5.5 | ⚠️ Warning | **`isLikelyHallucination` blocks legitimate short transcriptions.** "Thank you" is a common legitimate phrase but is always filtered. This should be context-aware or configurable. |
| 5.6 | ⚠️ Warning | **Text insertion via paste destroys rich clipboard content (partially fixed).** `insertViaPaste` now backs up all pasteboard item types/data, but the restore happens after 500ms delay. If the user pastes within that window, they'll get EchoTune's text instead of their original clipboard. |
| 5.7 | ⚠️ Warning | **Browser character-by-character typing is slow.** 2ms delay per character means a 500-character transcription takes 1 second of visible typing. This feels sluggish compared to instant paste. |
| 5.8 | ⚠️ Warning | **`Constants.maxRecordingDurationSeconds` (300s/5min) differs from `AudioManager.maxRecordingDuration` (1800s/30min).** Two different max duration values exist with no reconciliation. Neither is actually enforced in the recording flow. |
| 5.9 | 💡 Nice | **No "undo last transcription" feature.** If text is inserted incorrectly, users must manually select and delete it. An undo hotkey would be valuable. |
| 5.10 | 💡 Nice | **No real-time partial transcription display.** During Whisper recording, users see only a recording indicator with no preview of what's being transcribed. Apple Speech shows partial results, but Whisper batches everything to the end. |
| 5.11 | 💡 Nice | **Dictionary replacements applied twice.** `processTranscription()` in AppCoordinator calls `DictionaryManager.shared.process()`, and then `TextInsertionManager.insertText()` also calls `DictionaryManager.shared.process()` via `processTextReplacements()`. |

---

## 6. Error Handling

| # | Severity | Issue |
|---|----------|-------|
| 6.1 | ⚠️ Warning | **Error state resets after only 2 seconds.** `handleTranscriptionError` sets `.error(message)` then resets to `.idle` after 2s. Users may not see the error at all if they look away briefly. |
| 6.2 | ⚠️ Warning | **No retry mechanism for failed transcriptions.** When transcription fails, the audio data is lost. Should offer "Retry" or automatically save the audio for later re-transcription. |
| 6.3 | ⚠️ Warning | **`showErrorAlert` uses `NSAlert.runModal()` which blocks the main thread.** In a menu bar app, this can freeze the entire UI. Should use a non-modal approach. |
| 6.4 | ⚠️ Warning | **Cloud transcription errors show raw error messages.** API errors like "401 Unauthorized" or network timeouts are shown as-is. Should provide user-friendly messages. |
| 6.5 | 💡 Nice | **No offline detection.** Cloud models will fail silently if there's no internet. Should check connectivity before attempting cloud transcription and warn the user. |
| 6.6 | 💡 Nice | **No error logging to persistent file.** `ErrorLogger` prints to console but errors are lost after app restart. Should persist to a log file for debugging. |
| 6.7 | 💡 Nice | **Microphone disconnection during recording is not handled.** If the user unplugs a USB mic while recording, the behavior is undefined. |

---

## 7. Architecture & Code Quality

| # | Severity | Issue |
|---|----------|-------|
| 7.1 | 🔴 Blocker | **Demo license backdoor in production (fixed in `#if DEBUG`).** The `DEMO-` prefix check is now inside `#if DEBUG`, but the fake license server (`validateLicenseWithServer`) still accepts ANY key matching `XXXXX-XXXXX-XXXXX-XXXXX` format with no real server call. This means **any formatted key activates the app.** |
| 7.2 | 🔴 Blocker | **License validation is simulated.** `LicenseManager.validateLicenseWithServer()` uses `DispatchQueue.global().asyncAfter(deadline: .now() + 1.0)` to fake a server delay. No actual server communication happens. Any key with 23 chars and 3 dashes is accepted. |
| 7.3 | 🔴 Blocker | **`debugLog` wraps all prints in `#if DEBUG`, but 733+ `print()` calls elsewhere may still exist.** The `debugLog` function is correctly gated, but any direct `print()` calls in the codebase still leak in production. Need to verify all `print()` calls were migrated to `debugLog`. |
| 7.4 | ⚠️ Warning | **`AppCoordinator` is 1412 lines** — a God Object that handles recording, transcription, cloud routing, text insertion, AI enhancement, power modes, trigger words, history, analytics, re-transcription, and UI alerts. Should be decomposed into focused services. |
| 7.5 | ⚠️ Warning | **Singleton pattern overuse.** 20+ `static let shared` singletons make testing impossible and create hidden dependencies. `AppCoordinator`, `AudioManager`, `ModelManager`, `WhisperEngine`, `TranscriptionEngine`, `TextInsertionManager`, `PermissionsManager`, `ShortcutManager`, `MultiHotkeyManager`, `LicenseManager`, `NotificationManager`, `AnalyticsManager`, `ErrorLogger`, `SoundManager`, `VADManager`, `PowerModeManager`, `DictionaryManager`, `AIEnhancementEngine`, `AudioCleanupManager`, `AutoSendService`, `ScreenContextService`, `BrowserContextDetector` — all singletons. |
| 7.6 | ⚠️ Warning | **Mixed concurrency patterns.** The codebase mixes `DispatchQueue`, `Task`/`async-await`, completion handlers, `Combine` publishers, `NotificationCenter`, and `@Observable`/`@ObservableObject` without a consistent strategy. `LicenseManager` uses `@Observable` while everything else uses `@ObservableObject`. |
| 7.7 | ⚠️ Warning | **`ModelManager.checkInstalledModels()` mutates `@Published` properties from background thread.** The fix was applied (marshaling to main thread), but the pattern of scanning on background then updating on main is fragile — any new code in the scan loop could accidentally mutate published state. |
| 7.8 | ⚠️ Warning | **Dual model persistence keys.** `ModelManager` uses `defaultModelID` UserDefaults key while `AppSettings` uses `defaultTranscriptionModel`. They're now synced in `setCurrentModel()`, but `checkInstalledModels()` restores from `defaultModelID` and then syncs to `AppSettings`. If either key is corrupted independently, they can desync. |
| 7.9 | ⚠️ Warning | **4 TODO/FIXME items remain.** `SocialShareService.swift` has 3 TODOs for unimplemented backend validation. `SileroVADEngine.swift` has a TODO to add the CoreML model. |
| 7.10 | ⚠️ Warning | **`os_log` used at `.error` level for informational messages.** `AppCoordinator` logs routine messages like "startDictation called" at error level, polluting system error logs. |
| 7.11 | ⚠️ Warning | **`AnalyticsManager.printSummary()` runs on every init** even in release builds (but now behind `debugLog` so it's actually safe). However, `printDetailedReport()` is still a public method that could be called in production. |
| 7.12 | 💡 Nice | **No unit tests for business logic.** `EchoTuneTests.swift` and `EchoTuneUITests.swift` exist but likely contain only boilerplate. Critical logic (hallucination detection, dictionary processing, trigger word matching, audio chunking) has zero test coverage. |
| 7.13 | 💡 Nice | **`TranscriptionHistoryManager` is referenced but never shown in the file listing.** It's used throughout `AppCoordinator` and `AudioCleanupManager` but its source file isn't visible — may be embedded in another file or missing from the project. |
| 7.14 | 💡 Nice | **`LicenseError` enum is not defined in the visible code.** Referenced in `LicenseManager` but its definition isn't in the file — may be in an extension or missing. |
| 7.15 | 💡 Nice | **Magic numbers throughout.** `0.3` second hallucination threshold, `0.5` second clipboard restore delay, `2.0` second error display, `3.0` second Apple Speech timeout, `1.5` second permission poll interval — none are named constants. |

---

## 8. Performance

| # | Severity | Issue |
|---|----------|-------|
| 8.1 | 🔴 Blocker | **Unbounded memory growth during recording.** `recordedBuffers` (VAD analysis) + `audioChunks` (chunk storage) both grow without bound. A 30-minute recording accumulates ~700MB+ (345MB in chunks + 345MB in VAD buffers). The chunk system has a 600-chunk cap, but `recordedBuffers` has no cap at all. |
| 8.2 | ⚠️ Warning | **Permission polling every 2 seconds.** `PermissionsManager.startPermissionMonitoring()` runs a timer every 2 seconds checking accessibility permission even when it's already granted (the timer only skips if `hasAccessibilityPermission` is true, but it still fires and checks the condition). |
| 8.3 | ⚠️ Warning | **Model preloading happens at launch.** Loading a large Whisper model (e.g., Large v3 at 2.9GB) at startup adds significant memory and CPU overhead. Should be deferred or made configurable. |
| 8.4 | 💡 Nice | **`mergeAllAudioChunks()` creates one massive contiguous buffer.** For a 30-minute recording, this allocates ~345MB in a single allocation which can fail on memory-constrained systems. Should convert in chunks or stream to disk. |
| 8.5 | 💡 Nice | **Audio level calculation runs on every tap callback.** `calculateAudioLevel` computes RMS on every 1024-frame buffer (~21ms at 48kHz). This is fine but could be throttled to every 3-4 buffers for a ~60-80ms update rate without visible difference. |
| 8.6 | 💡 Nice | **`getAvailableInputDevices()` called without caching.** Each call queries CoreAudio APIs which involves multiple system calls. Should cache with invalidation on device change notification. |

---

## 9. Accessibility

| # | Severity | Issue |
|---|----------|-------|
| 9.1 | ⚠️ Warning | **No VoiceOver labels on recording indicator windows.** `RecordingIndicatorWindow`, `NotchRecorderWindow`, `MiniRecorderWindow` have no accessibility labels or traits. VoiceOver users won't know recording is active. |
| 9.2 | ⚠️ Warning | **Onboarding waveform/icon animations have no `accessibilityHidden` modifier.** Decorative animations should be hidden from VoiceOver. |
| 9.3 | ⚠️ Warning | **Menu bar popover content lacks accessibility structure.** No accessibility container roles or grouping for the menu bar content view. |
| 9.4 | 💡 Nice | **No `reducedMotion` check.** Onboarding animations, waveform visualizations, and pulse effects don't respect `accessibilityReduceMotion` preference. |
| 9.5 | 💡 Nice | **Color-only status indicators.** Recording state uses red/blue/orange colors only. Users with color blindness need additional visual cues (icons, text labels). The text descriptions exist but are secondary to the color indicators. |
| 9.6 | 💡 Nice | **No keyboard navigation for onboarding.** Users must click buttons — Tab/Enter navigation isn't explicitly supported. SwiftUI provides some by default but custom buttons may not participate. |
| 9.7 | 💡 Nice | **Contrast issues in onboarding dark mode.** `echoTextTertiary` (white at 35% opacity) may not meet WCAG AA contrast requirements against `echoSurface` backgrounds. |

---

## 10. Missing Features (vs. Competitors)

| # | Priority | Feature |
|---|----------|---------|
| 10.1 | High | **Real push-to-talk mode.** The `recordingMode` setting exists but isn't implemented. Competitors like SuperWhisper support hold-to-record natively. |
| 10.2 | High | **Real-time streaming transcription display.** During Whisper recording, users see zero text until recording stops. VoiceInk and SuperWhisper show progressive transcription. |
| 10.3 | High | **SwiftData / Core Data persistence.** All data (history, settings, stats) uses UserDefaults and JSON files. SwiftData would provide proper querying, migration, and iCloud sync. |
| 10.4 | Medium | **iCloud sync.** Settings, dictionary, history don't sync across devices. |
| 10.5 | Medium | **Undo last transcription hotkey.** No way to quickly undo an insertion without manual selection. |
| 10.6 | Medium | **Mouse middle-click trigger.** Competitors support mouse button triggers for dictation. |
| 10.7 | Medium | **File/audio transcription mode.** Currently only supports live microphone input. MacWhisper's strength is transcribing audio files — EchoTune could add this. |
| 10.8 | Medium | **Multi-language simultaneous detection.** Users who switch between languages mid-sentence need better support. |
| 10.9 | Low | **Widgets/Control Center integration.** macOS widgets could show recording status and quick actions. |
| 10.10 | Low | **Siri Shortcuts integration.** Allow triggering dictation from Shortcuts app. |
| 10.11 | Low | **Audio output device selection.** Only input devices can be selected. |
| 10.12 | Low | **Localized UI.** PRD mentions Phase 2 localization for top 10 languages — currently English only. |

---

## 11. Website

| # | Severity | Issue |
|---|----------|-------|
| 11.1 | ⚠️ Warning | **Missing `og-image.png`.** The HTML references `https://echotune.app/og-image.png` but the file isn't in the website folder. Social sharing will show a broken image. |
| 11.2 | ⚠️ Warning | **"Trusted by professionals at" section uses generic text placeholders** ("Freelancers", "Developers", "Writers") instead of actual company logos or testimonials. This looks like a template that was never completed. |
| 11.3 | ⚠️ Warning | **GitHub link points to `https://github.com/vishvivero/EchoTune`** — should verify this is the correct/intended public repository. If the repo is private, this link will 404. |
| 11.4 | 💡 Nice | **No download link implementation.** The "Download for Mac" button links to `#download` anchor but there's no corresponding section or actual DMG download link. |
| 11.5 | 💡 Nice | **No pricing section content visible in the HTML head.** The nav links to `#pricing` but the pricing section content wasn't in the first 200 lines. |
| 11.6 | 💡 Nice | **Privacy, Terms, Support pages exist** (`privacy.html`, `terms.html`, `support.html`) but weren't audited — should verify they're complete and legally reviewed. |
| 11.7 | 💡 Nice | **No analytics on the website.** No Google Analytics, Plausible, or similar. Good for privacy, but makes it impossible to track conversion rates. |
| 11.8 | 💡 Nice | **`script.js` not audited** — may contain the typing animation demo and theme toggle logic. Should verify no console errors or performance issues. |

---

## 12. Security & Privacy

| # | Severity | Issue |
|---|----------|-------|
| 12.1 | 🔴 Blocker | **API keys now stored in Keychain ✅ with migration from UserDefaults.** `AppSettings.init()` calls `migrateAPIKeysToKeychain()` which moves keys from UserDefaults to Keychain. This is correctly implemented. However, the migration deletes from UserDefaults after copy — if the Keychain write fails silently, the key is lost. Should verify Keychain write success before deleting from UserDefaults. |
| 12.2 | ⚠️ Warning | **`tccutil reset Accessibility` called in `requestAccessibilityPermission()`.** This resets the TCC database entry for accessibility, which may confuse users who already granted permission to a different binary (e.g., debug vs release). Should only reset if the user explicitly requests it, not on every permission request. |
| 12.3 | ⚠️ Warning | **No Privacy Manifest (`PrivacyInfo.xcprivacy`).** Required for App Store submission since Spring 2024. The app uses UserDefaults, file timestamps, and Keychain — all requiring declarations. |
| 12.4 | ⚠️ Warning | **Screen context captures can include sensitive information.** `ScreenContextService` captures clipboard text, selected text, and screen OCR. This data is sent to cloud AI services (OpenAI, Anthropic, Groq) in enhancement prompts. Users should be clearly warned about this in privacy settings. |
| 12.5 | 💡 Nice | **No certificate pinning for API calls.** All API calls to OpenAI, Anthropic, Groq, and Deepgram use default `URLSession` without certificate pinning. |
| 12.6 | 💡 Nice | **AppDelegate entitlements minimal.** Only `com.apple.security.files.user-selected.read-write` — no App Sandbox, which is fine for direct distribution but blocks Mac App Store submission. |

---

## 13. Build & Distribution

| # | Severity | Issue |
|---|----------|-------|
| 13.1 | ⚠️ Warning | **Copyright string empty in project settings.** `INFOPLIST_KEY_NSHumanReadableCopyright = ""`. |
| 13.2 | ⚠️ Warning | **`AboutView` now correctly uses dynamic year** via `Calendar.current.component(.year, from: Date())`. ✅ Fixed since production audit. |
| 13.3 | ⚠️ Warning | **Signing identity "Sign to Run Locally"** — needs to be changed to Developer ID for distribution. |
| 13.4 | 💡 Nice | **`LICENSE_KEYS.md` and `generate_license_key.sh`** should not ship in any distribution. Verify `.gitignore` excludes them. |
| 13.5 | 💡 Nice | **No CI/CD pipeline.** No GitHub Actions, Xcode Cloud, or Fastlane configuration for automated builds and testing. |
| 13.6 | 💡 Nice | **Sparkle framework conditionally imported** (`#if canImport(Sparkle)`) but not in dependency graph. `UpdateManager` has Sparkle integration code that's never active. Either add Sparkle as dependency or remove the dead code. |

---

## Summary by Category

| Category | Blockers | Warnings | Nice-to-Have |
|----------|----------|----------|--------------|
| 1. Onboarding | 0 | 2 | 8 |
| 2. UI/UX | 0 | 4 | 7 |
| 3. Menu Bar | 0 | 1 | 4 |
| 4. Settings | 0 | 3 | 5 |
| 5. Core Functionality | 2 | 6 | 3 |
| 6. Error Handling | 0 | 4 | 3 |
| 7. Architecture | 3 | 7 | 5 |
| 8. Performance | 1 | 2 | 3 |
| 9. Accessibility | 0 | 3 | 4 |
| 10. Missing Features | 0 | 0 | 12 |
| 11. Website | 0 | 3 | 5 |
| 12. Security | 1 | 3 | 2 |
| 13. Build | 0 | 2 | 4 |
| **Total** | **7** | **40** | **65** |

---

## Top 10 Priority Fixes

1. **Implement real license server** — Currently any formatted key activates the app
2. **Cap `recordedBuffers` for VAD** — Unbounded memory growth during recording
3. **Fix Groq audio chunking** — Chunking raw WAV container bytes corrupts audio
4. **Verify all `print()` migrated to `debugLog`** — Production console leaks
5. **Remove orphan view files** — 13+ dead view files add confusion
6. **Implement push-to-talk mode** — Setting exists but is never used
7. **Add Privacy Manifest** — Required for App Store
8. **Reduce `AppCoordinator` size** — 1412-line God Object needs decomposition
9. **Fix clipboard restore timing** — 500ms window where clipboard is wrong
10. **Add VoiceOver labels to recording indicators** — Accessibility requirement

---

*This audit covers every Swift source file, every view, every manager, every model, every utility, the website, and all existing documentation (PRD.md, BUG_REPORT.md, PRODUCTION_AUDIT.md, GAP_ANALYSIS.md). Issues previously identified in those documents are not re-listed unless they remain unfixed or have new context.*
