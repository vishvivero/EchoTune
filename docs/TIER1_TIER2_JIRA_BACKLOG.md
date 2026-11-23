# EchoTune — Incremental Release Backlog (Tier 1 & Tier 2)

**Baseline:** `v7.5.5` (commit `fc2a6f5`, build `114` — verified working golden baseline)
**Reference implementation commit (for cherry-picking):** `052e05d` (`v7.6.0`) and `ece9063` (`AppDelegate.shared`)
**Release discipline:** **1 ticket = 1 version bump = 1 build & live smoke test.** Never batch two tickets into one version.

---

## Global Guardrails for Every Ticket (Mandatory for LLM Builder)

1. **DO NOT TOUCH Window Lifecycle or Menu Bar Transport:**
   - Never remove or replace `WindowGroup` in `EchoTune/EchoTuneApp.swift`.
   - Never add `NSApp.setActivationPolicy(...)` transitions when opening/closing windows.
   - Never add `NSPanel` windows at `statusWindow` level (`layer >= 24`).
   - Never add `NSEvent.addLocalMonitorForEvents` or `NSEvent.addGlobalMonitorForEvents` for `.keyDown` in `MultiHotkeyManager`.
   - Keep `EchoTune/Views/MenuBar/StatusBarController.swift` and `MenuBarIconRenderer.swift` on their exact `7.5.5` (`fc2a6f5`) transport.
2. **Test-Host Keychain Isolation (Required on first ticket so `xcodebuild test` never hangs):**
   - In `EchoTune/Utilities/KeychainHelper.swift` and `EchoTune/Managers/LicenseManager.swift`, bypass `SecItemCopyMatching` / `SecItemAdd` with an in-memory dictionary when `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil`.
3. **Per-Ticket Definition of Done (DoD) Gate:**
   - Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `EchoTune.xcodeproj/project.pbxproj`.
   - Add entry to `CHANGELOG.md`.
   - Run `xcodebuild test -project EchoTune.xcodeproj -scheme EchoTune -destination 'platform=macOS' -only-testing:EchoTuneTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` → **0 failures**.
   - Build & sign via `Scripts/release_direct.sh <version>`, install to `/Applications/EchoTune.app`, launch, and **verify manually that (a) the top menu bar icon opens on click and (b) the Dashboard red Close (`✕`) button works** before starting the next ticket.

---

## TIER 1 — Pure Backend & Reliability (Zero UI/Window/Event Risk)

---

### ET-756 · Fix `NSApp.delegate as? AppDelegate` Nil-Cast Across App
- **Target Version:** `7.5.6` (Build `115`)
- **Type:** Bug Fix / Core Wiring
- **Estimate:** 15 mins
- **Reference Commit:** `ece9063`

#### Problem Statement
Under SwiftUI’s `@main App` lifecycle (`EchoTuneApp`), macOS sets `NSApp.delegate` to SwiftUI’s internal wrapper (`SwiftUI.AppDelegate`), **not** our `AppDelegate` instance. Consequently, all `NSApp.delegate as? AppDelegate` casts across `StatusBarController`, `EchoTuneMenuCardView`, and `AppCoordinator` evaluate to `nil`, causing menu bar window openers (*Open EchoTune Dashboard*, *Echo Profile*, *Tasks*, *Settings…*) and status-bar icon updates to silently no-op.

#### Scope & Files to Modify
- `EchoTune/App/AppDelegate.swift`: Add `static private(set) weak var shared: AppDelegate?` and assign `AppDelegate.shared = self` in `override init()`.
- `EchoTune/Views/MenuBar/StatusBarController.swift`: Replace `(NSApp.delegate as? AppDelegate)` with `AppDelegate.shared`.
- `EchoTune/Views/MenuBar/EchoTuneMenuCardView.swift`: Replace `(NSApp.delegate as? AppDelegate)` with `AppDelegate.shared`.
- `EchoTune/AppCoordinator+Recording.swift` & `EchoTune/AppCoordinator+Transcription.swift`: Replace `NSApp.delegate as? AppDelegate` with `AppDelegate.shared`.
- `EchoTune/Utilities/KeychainHelper.swift` & `EchoTune/Managers/LicenseManager.swift`: Add `isTestHost` in-memory Keychain bypass so unit tests never block on `securityd`.

#### Out of Scope
- Do **not** alter `EchoTuneApp.swift` `WindowGroup`, `setActivationPolicy`, or `StatusBarController`’s menu/icon architecture from `7.5.5`.

#### Acceptance Criteria & Verification
1. `AppDelegate.shared` is non-nil at runtime immediately after launch.
2. Zero occurrences of `NSApp.delegate as? AppDelegate` remain in `EchoTune/`.
3. Clicking **Open EchoTune Dashboard**, **Settings…**, **Echo Profile**, and **Tasks & Commitments** from the menu bar opens each window.
4. Unit test asserts no file in `EchoTune/` contains `NSApp.delegate as? AppDelegate`.

---

### ET-757 · Offline Phonetic Vocabulary Matcher
- **Target Version:** `7.5.7` (Build `116`)
- **Type:** Feature (ASR Accuracy)
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Users add custom product names, people, and technical jargon (e.g., `EchoTune`, `WhisperKit`, `Kubernetes`) to Custom Dictionary, but exact-string replacement misses phonetic ASR mishearings or split compounds (e.g., *"echo tune"*, *"ekotune"*, *"whisper kit"*, *"kubernetis"*). Passing vocabulary into WhisperKit’s decoder `promptTokens` is forbidden (causes empty output bug fixed in `7.4.7`), so phonetic matching must run post-transcription.

#### Scope & Files to Modify
- **New File:** `EchoTune/Managers/PhoneticVocabularyMatcher.swift`
  - Implement `PhoneticVocabularyMatcher` with consonant-skeleton phonetic encoding (`ech`→`ek`, `ph`→`f`, `ck`→`k`, etc.), character trigram Jaccard similarity, normalized Levenshtein edit distance, 1–3 word contiguous span matching, and a protected common-English stopword set.
- **Modify:** `EchoTune/Managers/DictionaryManager.swift`
  - Add `@Published var phoneticMatchingEnabled: Bool` (default `true`, persisted in `UserDefaults`).
  - Rebuild `PhoneticVocabularyMatcher` whenever `correctSpellings` changes.
  - Seed default spellings (`EchoTune`, `WhisperKit`, `Parakeet`) on fresh install and invoke `phoneticMatcher.apply(to:)` inside `DictionaryManager.process(text:)`.
- **Modify:** `EchoTune/Views/Settings/SettingsCompositeViews.swift`
  - Add `"Phonetic Proper-Noun Matching"` toggle in **Settings → General → Vocabulary**.

#### Acceptance Criteria & Verification
1. `"Open echo tune now."` → `"Open EchoTune now."`
2. `"Check ekotune settings."` → `"Check EchoTune settings."`
3. `"Deploy to kubernetis cluster."` → `"Deploy to Kubernetes cluster."`
4. Ordinary English prose (`"People around the world think about other things every morning."`) is 100% unchanged.

---

### ET-758 · Configurable Spoken Filler Word Removal & Punctuation Repair
- **Target Version:** `7.5.8` (Build `117`)
- **Type:** Feature (Transcript Cleanliness)
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
When dictating in raw local mode (with AI Enhancement off), spoken hesitations (`uh`, `um`, `erm`, `ah`, `hmm`) remain in the transcript, and naive word deletion leaves broken punctuation like `"I went, , to the store"` or lowercase sentence starts (`"Um, hello"` → `"hello"`).

#### Scope & Files to Modify
- **New File:** `EchoTune/Managers/FillerWordManager.swift`
  - Singleton `@Published var isEnabled: Bool` (default `true`) and `@Published var fillerWords: [String]` (default `["uh", "um", "umm", "uhh", "erm", "er", "ah", "hmm", "mhm"]`).
  - Strip parenthetical comma-wrapped fillers (`, uh,`) and standalone fillers, then run `repairPunctuationAndCapitalization` to collapse spaces before punctuation, remove leading commas, and re-capitalize sentence starts.
- **Modify:** `EchoTune/AppCoordinator+Transcription.swift`
  - Run `FillerWordManager.shared.clean(text)` at the start of `processTranscription(_:)`.
- **Modify:** `EchoTune/Views/Settings/SettingsCompositeViews.swift`
  - Add `"Spoken Filler Word Removal"` section in **Settings → Speech** with enable toggle, add-word field, and Reset button.

#### Acceptance Criteria & Verification
1. `"Um, hello world."` → `"Hello world."`
2. `"I went, uh, to the store. Erm, yes!"` → `"I went to the store. Yes!"`
3. Words containing filler substrings (`"umbrella"`, `"human"`, `"term"`) are never modified.

---

### ET-759 · Instant CoreAudio Hardware Output Mute During Dictation
- **Target Version:** `7.5.9` (Build `118`)
- **Type:** Performance & Reliability
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
`SystemAudioManager` currently spawns `NSAppleScript` (`set volume output volume 0`) on every dictation start and stop. That takes 50–150 ms on the main thread, triggers AppleEvents/osax loading, overwrites the user's volume slider if the app crashes, and unmutes audio even if the user had already muted their Mac manually.

#### Scope & Files to Modify
- **Modify:** `EchoTune/Utilities/SystemAudioManager.swift`
  - Replace `NSAppleScript` implementation with direct `CoreAudio` `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` using `kAudioHardwarePropertyDefaultOutputDevice` and `kAudioDevicePropertyMute`.
  - If the default output device is already muted by the user, do not take ownership and do not unmute on stop.
  - Track muted `AudioDeviceID`s in a `Set<AudioDeviceID>` so if output switches (e.g. AirPods disconnect mid-recording), the exact device we muted is restored.
  - Fall back to `kAudioDevicePropertyVolumeScalar` only on HDMI/DisplayPort devices that lack a hardware mute property.

#### Acceptance Criteria & Verification
1. Zero `NSAppleScript` calls in `SystemAudioManager.swift`.
2. Muting and restoring completes in `<1 ms` on the main thread.
3. If the Mac is already muted before dictation starts, it remains muted after dictation stops.

---

### ET-760 · Prevent Display Sleep During Active Dictation
- **Target Version:** `7.6.0` (Build `119`)
- **Type:** Reliability
- **Estimate:** 10 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
During longer voice notes or thoughts (>2 minutes without touching the trackpad/keyboard), macOS dims the display or activates the screen saver/lock screen mid-recording, causing Accessibility text insertion at stop time to fail.

#### Scope & Files to Modify
- **New File:** `EchoTune/Utilities/ScreenSleepPreventer.swift`
  - `@MainActor final class ScreenSleepPreventer` using `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, kIOPMAssertionLevelOn, "EchoTune Active Voice Dictation", &assertionID)` and `IOPMAssertionRelease`.
  - Unconditionally clear `assertionID = 0` before calling `IOPMAssertionRelease` so a failed release can never wedge future recordings.
- **Modify:** `EchoTune/Managers/AudioManager.swift`
  - Call `ScreenSleepPreventer.shared.beginPreventingDisplaySleep()` in `startRecording()`.
  - Call `ScreenSleepPreventer.shared.endPreventingDisplaySleep()` in `stopRecording()` and `teardownAfterFailedStart()`.

#### Acceptance Criteria & Verification
1. While recording is active, `pmset -g assertions` shows `PreventUserIdleDisplaySleep` held by `EchoTune`.
2. Immediately after stopping (or failed start), the assertion is released (`assertionID == 0`).

---

### ET-761 · Clamshell (Closed-Lid) Microphone Auto-Fallback
- **Target Version:** `7.6.1` (Build `120`)
- **Type:** Hardware Reliability
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
When a MacBook is used in closed-display (clamshell) mode with an external monitor, macOS's internal microphone is physically muffled/muted by the closed lid, producing blank or near-silent audio if the Built-in Microphone is still selected as default.

#### Scope & Files to Modify
- **New File:** `EchoTune/Utilities/ClamshellStateMonitor.swift`
  - Query IOKit `IOPMrootDomain` property `"AppleClamshellState"` (`var isLidClosed: Bool`).
- **Modify:** `EchoTune/Managers/AudioManager+DeviceSelection.swift` & `EchoTune/Managers/AudioManager.swift`
  - Add `ensureClamshellSafeInputDevice()`: when `ClamshellStateMonitor.shared.isLidClosed == true` and the current default input device has `type == "Internal"`, automatically select the first available non-internal input device (USB, Display, Bluetooth/AirPods).
  - Invoke `ensureClamshellSafeInputDevice()` at the top of `startRecording()`.

#### Acceptance Criteria & Verification
1. With lid open (`isLidClosed == false`), input device selection is untouched.
2. With lid closed and Built-in Mic selected alongside an external/AirPods mic, `ensureClamshellSafeInputDevice()` switches to the external mic before `AVAudioEngine` starts.

---

### ET-762 · Apple On-Device Intelligence Refinement (`FoundationModels`, macOS 26+)
- **Target Version:** `7.6.2` (Build `121`)
- **Type:** Feature (100% Offline AI Cleanup)
- **Estimate:** 20 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Users who want 100% offline AI grammar/filler cleanup currently have to install the external `Ollama` CLI and download a multi-GB model manually. On macOS 26+ Apple Silicon Macs, Apple ships a built-in Neural Engine LLM via the `FoundationModels` framework (`SystemLanguageModel.default`) requiring zero download and zero API key.

#### Scope & Files to Modify
- **New File:** `EchoTune/Managers/OnDeviceRefinementProvider.swift`
  - Guarded with `#if canImport(FoundationModels)` and `if #available(macOS 26.0, *)`.
  - Check `SystemLanguageModel.default.availability == .available` and run `LanguageModelSession(instructions:).respond(to:)` on `<DICTATION>...</DICTATION>`.
- **Modify:** `EchoTune/Managers/AIEnhancementEngine.swift`, `EchoTune/Models/AppSettings.swift`, `EchoTune/Views/Settings/AIAutomationSettingsView.swift`
  - Add `.appleOnDevice = "apple-on-device"` (`"Apple Intelligence · 100% On-Device (macOS 26+)"`) to `EnhancementModel` and `ProviderKind`.
  - Show `.appleOnDevice` in the Enhancement Model picker whenever `OnDeviceRefinementProvider.shared.isSupportedAndAvailable` is true.

#### Acceptance Criteria & Verification
1. Project still compiles and runs on macOS 14.0+ deployment target.
2. On macOS 26 with Apple Intelligence enabled, `"Apple Intelligence · 100% On-Device"` appears in Settings → Automation → Enhancement Model and polishes transcripts with zero network requests.

---

## TIER 2 — UI Polish, Multi-Mac Backup, Endpoints & Integrations (Low Risk)

---

### ET-763 · Dashboard 6-Month Consistency Heatmap & Peak Flow Hours Cards
- **Target Version:** `7.6.3` (Build `122`)
- **Type:** Feature (Dashboard Insights)
- **Estimate:** 20 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
The Dashboard Home tab shows summary counters and a basic chart, but lacks a visual consistency streak grid (like GitHub's contribution graph) and time-of-day speaking insights.

#### Scope & Files to Modify
- **New File:** `EchoTune/Views/Dashboard/DashboardInsightsCards.swift`
  - `DashboardInsightsCardsView` with two side-by-side cards:
    1. **Dictation Consistency:** 26-week × 7-day heatmap grid colored by daily word volume, with hover readout (`"20 Nov: 1,240 words (8 sessions)"`).
    2. **Peak Flow Hours:** 24-hour vertical bar chart aggregating word counts by hour of day (`0h..23h`) and highlighting the user's peak speaking window.
- **Modify:** `EchoTune/Views/Dashboard/HomeContentView.swift`
  - Insert `DashboardInsightsCardsView()` directly below `UsageGraphView(stats: stats)`.

#### Acceptance Criteria & Verification
1. Dashboard Home renders both cards cleanly at default `960×720` window size without horizontal overflow.
2. Hovering any heatmap square updates the date/word/session subtitle.

---

### ET-764 · Multi-Mac Setup Backup (JSON Import/Export) & History CSV Export
- **Target Version:** `7.6.4` (Build `123`)
- **Type:** Feature (Portability & Pro 3-Mac Sync)
- **Estimate:** 20 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Pro license buyers (up to 3 Macs) have no 1-click way to transfer their Custom Dictionary, Power Modes, Trigger Word Rules, Filler Words, and Preferences to a second Mac, nor a way to export their transcription history as a spreadsheet-ready `.csv`.

#### Scope & Files to Modify
- **New File:** `EchoTune/Managers/ConfigurationBackupManager.swift`
  - `exportBackupData() -> Data` and `importBackupData(_:) -> String` (merges non-duplicate Dictionary entries, Power Modes, Trigger Rules, Filler Words, and non-secret Preferences; never exports API keys or license keys).
  - `buildHistoryCSV(items:)` (RFC-4180 compliant CSV escaping quotes, commas, and newlines) + `presentHistoryCSVSavePanel()`.
- **Modify:** `EchoTune/Views/Settings/SettingsCompositeViews.swift` (`GeneralSettingsView`)
  - Add `"Setup Backup & Sync (Multi-Mac)"` section with **Export Setup Backup…** and **Import Setup Backup…** buttons.
- **Modify:** `EchoTune/Views/HistoryView.swift`
  - Add **Export CSV** button in the History header bar next to *Clear All*.

#### Acceptance Criteria & Verification
1. Round-trip unit test: `exportBackupData()` → `importBackupData()` decodes cleanly without duplicating existing entries.
2. CSV unit test: transcripts containing quotes, commas, and multiline text produce valid RFC-4180 CSV rows.

---

### ET-765 · Multi-Monitor Cursor Screen Placement for Floating Recorders
- **Target Version:** `7.6.5` (Build `124`)
- **Type:** UX Polish (Multi-Display)
- **Estimate:** 10 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
On dual/triple monitor setups, `MiniRecorderWindow` and `RecordingIndicatorWindow` (`Slim Bar`) always position themselves on the primary display (`NSScreen.screens.first` / `NSScreen.main`) rather than the display where the user's cursor is currently working.

#### Scope & Files to Modify
- **New File:** `EchoTune/Utilities/RecorderScreenResolver.swift`
  - `resolveForShow() -> NSScreen?`: finds `NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }` and locks that screen until `releaseLock()` is called on `hide()`.
- **Modify:** `EchoTune/Views/MiniRecorderView.swift` & `EchoTune/Views/RecordingIndicatorWindow.swift`
  - Use `RecorderScreenResolver.resolveForShow()` in `show()` and call `RecorderScreenResolver.releaseLock()` in `hide()`.

#### Acceptance Criteria & Verification
1. Floating recorder appears centered on the screen containing the mouse cursor and stays on that screen until recording finishes.

---

### ET-766 · Custom OpenAI-Compatible STT & Chat Endpoints
- **Target Version:** `7.6.6` (Build `125`)
- **Type:** Feature (Self-Hosted / OpenRouter / LM Studio)
- **Estimate:** 25 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Advanced and privacy-conscious users running local LLM/ASR servers (`LM Studio`, `Ollama` HTTP, `vLLM`, `faster-whisper-server`, `whisper.cpp` server) or `OpenRouter` cannot connect custom `/v1/audio/transcriptions` or `/v1/chat/completions` endpoints.

#### Scope & Files to Modify
- **New File:** `EchoTune/Managers/CustomOpenAICompatibleService.swift`
  - `normalizedEndpoint(baseURL:suffix:)` (handles trailing slashes and avoids `/v1/v1` duplication).
  - `completeChat(...)` (`POST /v1/chat/completions`) and `transcribeAudio(...)` (multipart `POST /v1/audio/transcriptions`).
- **Modify:** `EchoTune/Models/AppSettings.swift`, `EchoTune/Managers/ModelManager+ModelCatalog.swift`, `EchoTune/Managers/ModelManager+CloudAPI.swift`, `EchoTune/Managers/TranscriptionEngine.swift`, `EchoTune/Managers/TranscriptionEngine+Routing.swift`, `EchoTune/AppCoordinator+Recording.swift`, `EchoTune/Managers/AIEnhancementEngine.swift`, `EchoTune/Views/Settings/AIModelsSettingsView.swift`, `EchoTuneTests/ParakeetBackendTests.swift`
  - Add `customOpenAIBaseURL`, `customOpenAIModelID`, `customOpenAISTTModelID`, and Keychain-backed `customOpenAIAPIKey` (optional for localhost).
  - Add `"custom-openai-stt"` cloud model and `.customOpenAI` enhancement provider, plus configuration card in **Settings → AI & Models**.

#### Acceptance Criteria & Verification
1. URL normalization unit tests pass (`http://localhost:1234/v1` + `/v1/chat/completions` → `http://localhost:1234/v1/chat/completions`).
2. `ParakeetBackendTests.testCatalogIsTheCuratedRoster` updated and passing.

---

### ET-767 · Expanded Browser URL Triggers (`Dia` & `Comet`)
- **Target Version:** `7.6.7` (Build `126`)
- **Type:** Feature (Power Modes)
- **Estimate:** 10 mins
- **Reference Commit:** `052e05d` (AppleScript portion only)

#### Problem Statement
Power Modes auto-switch based on the active browser tab URL (`ActiveBrowserInspector`), but newer Chromium browsers **Dia** (`company.thebrowser.dia`) and **Perplexity Comet** (`ai.perplexity.comet`) are missing from `knownBrowsers`.

#### Scope & Files to Modify
- **Modify:** `EchoTune/Utilities/ActiveBrowserInspector.swift`
  - Add `"company.thebrowser.dia": .chromium(scriptName: "Dia")` and `"ai.perplexity.comet": .chromium(scriptName: "Comet")` to `knownBrowsers`.
  - *(Guardrail: Do **not** add synchronous AX tree-walking loops for Firefox/Zen.)*

#### Acceptance Criteria & Verification
1. `ActiveBrowserInspector.isBrowser("company.thebrowser.dia") == true` and `isBrowser("ai.perplexity.comet") == true`.

---

### ET-768 · Post-Transcription Shell Command Hook
- **Target Version:** `7.6.8` (Build `127`)
- **Type:** Feature (Developer / Obsidian Automation)
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Power users want an optional post-transcription hook to pipe finalized dictated text into a shell script or CLI tool (e.g., appending to an Obsidian daily note or triggering a local workflow).

#### Scope & Files to Modify
- **New File:** `EchoTune/Utilities/CustomCommandRunner.swift`
  - Runs `/bin/zsh -lc <command>` on a detached background task (`Task.detached(priority: .utility)`), passing the transcript via `stdin` and `$ECHOTUNE_TRANSCRIPT`, `$ECHOTUNE_RAW_TRANSCRIPT`, `$ECHOTUNE_APP_BUNDLE_ID` with a hard 15-second timeout.
- **Modify:** `EchoTune/Models/PowerMode.swift`, `EchoTune/AppCoordinator+Transcription.swift`, `EchoTune/Views/Settings/AIAutomationSettingsView.swift`
  - Add optional command field in **Settings → Automation** (and `PowerMode.customShellCommand`), invoked asynchronously after history recording.

#### Acceptance Criteria & Verification
1. Never blocks the main thread or delays text insertion.
2. A hanging command is terminated automatically after 15 seconds.

---

### ET-769 · Native macOS `AppIntents` (Apple Shortcuts, Siri & Raycast)
- **Target Version:** `7.6.9` (Build `128`)
- **Type:** Feature (System Automation)
- **Estimate:** 15 mins
- **Reference Commit:** `052e05d`

#### Problem Statement
Users with Stream Deck, Raycast, Action Button, or Apple Shortcuts workflows want native macOS `AppIntents` actions to Start, Stop, or Toggle EchoTune dictation and Copy the Last Transcript without simulating global keystrokes.

#### Scope & Files to Modify
- **New File:** `EchoTune/App/EchoTuneAppIntents.swift`
  - Implement `ToggleDictationIntent`, `StartDictationIntent`, `StopDictationIntent`, and `CopyLastTranscriptIntent` (`openAppWhenRun = false`), plus `EchoTuneShortcutsProvider: AppShortcutsProvider`.
  - *(Guardrail: Do not reference `QuickHistoryPanelController`.)*

#### Acceptance Criteria & Verification
1. Intents compile cleanly and appear in the macOS **Shortcuts** app under EchoTune.
2. Running `Toggle EchoTune Dictation` from Shortcuts starts/stops recording without opening a window.

---

## Execution Order Summary

| Order | Ticket | Version | Build | Category | Est. Time |
|---:|---|---|---|---|---:|
| 1 | **ET-756** · `AppDelegate.shared` Nil-Cast Fix + Test Keychain Guard | **`7.5.6`** | `115` | Tier 1 (Core Bug Fix) | 15m |
| 2 | **ET-757** · Offline Phonetic Vocabulary Matcher | **`7.5.7`** | `116` | Tier 1 (Accuracy) | 15m |
| 3 | **ET-758** · Configurable Spoken Filler Word Removal | **`7.5.8`** | `117` | Tier 1 (Cleanliness) | 15m |
| 4 | **ET-759** · CoreAudio `<1 ms` Hardware Output Mute | **`7.5.9`** | `118` | Tier 1 (Performance) | 15m |
| 5 | **ET-760** · Display-Sleep Prevention (`IOPMAssertion`) | **`7.6.0`** | `119` | Tier 1 (Reliability) | 10m |
| 6 | **ET-761** · Clamshell Closed-Lid Mic Auto-Fallback | **`7.6.1`** | `120` | Tier 1 (Hardware) | 15m |
| 7 | **ET-762** · Apple On-Device Intelligence Cleanup (`FoundationModels`) | **`7.6.2`** | `121` | Tier 1 (Offline AI) | 20m |
| 8 | **ET-763** · Dashboard 6-Month Heatmap & Peak Flow Hours | **`7.6.3`** | `122` | Tier 2 (Dashboard UI) | 20m |
| 9 | **ET-764** · Multi-Mac Setup Backup (JSON) & History CSV Export | **`7.6.4`** | `123` | Tier 2 (Backup/CSV) | 20m |
| 10 | **ET-765** · Multi-Monitor Cursor Screen Placement | **`7.6.5`** | `124` | Tier 2 (Multi-Display) | 10m |
| 11 | **ET-766** · Custom OpenAI-Compatible STT & Chat Endpoints | **`7.6.6`** | `125` | Tier 2 (Custom API) | 25m |
| 12 | **ET-767** · Expanded Browser URL Triggers (`Dia` & `Comet`) | **`7.6.7`** | `126` | Tier 2 (Power Modes) | 10m |
| 13 | **ET-768** · Post-Transcription Shell Command Hook | **`7.6.8`** | `127` | Tier 2 (Automation) | 15m |
| 14 | **ET-769** · Native macOS `AppIntents` (Apple Shortcuts) | **`7.6.9`** | `128` | Tier 2 (Shortcuts) | 15m |
