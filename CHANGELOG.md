# Changelog

All notable changes to EchoTune are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [7.7.14] — Menu bar action fixes

### Fixed — “Manage AI Models & Keys…” did nothing
- Clicking **Transcription Model → Manage AI Models & Keys…** raised the Settings window but did not reliably land on **AI & Models**, and from an `.accessory` app the window often stayed behind the previously frontmost app, so the click looked like a no-op.
- Three causes, all fixed:
  1. The navigation notification was posted *before* the window was raised, and into a view that may not have mounted yet.
  2. An existing window ignored the tab: the notification fired, but the raise immediately after cleared focus.
  3. `.accessory` apps are not activated by `makeKeyAndOrderFront` alone.
- `AppDelegate.focusForMenuBarPresentation(_:)` now activates the app then raises the window, and is shared by **Settings**, **Echo Profile** and **Tasks & Commitments**.
- `SettingsView(initialTab:)` builds a fresh Settings window already on the requested tab, so the tab no longer depends on a notification arriving at the right moment.

### Added — wiring coverage
- `MenuBarWiringTests` asserts that every `#selector` in the menu has a matching `@objc` implementation, that every `showSettings(tab:)` names a real case, and that the raise-then-navigate order is preserved.

## [7.7.13] — ET-769 · Native macOS App Intents (Shortcuts & Siri)

### Added
- Four App Intents, all with `openAppWhenRun = false` so dictation never brings a window forward:
  - **Toggle Dictation** — start if idle, finish if recording
  - **Start Dictation** — begin listening
  - **Stop Dictation** — finish and insert the transcription
  - **Copy Last Transcript** — your most recent transcript to the clipboard
- `EchoTuneShortcuts` registers Siri phrases for each, grouped under EchoTune in the Shortcuts app.
- The actions are now visible in **macOS Shortcuts** and can be chained into any automation.

### Behaviour
- All intents operate on `AppCoordinator` from the main actor; no window is created or activated.
- **Copy Last Transcript** reports a clear dialog when there is nothing to copy yet instead of failing silently.

### Verified
- 7 `EchoTuneAppIntentsTests` cases: the `openAppWhenRun = false` contract, non-empty titles, shortcut registration, newest-entry selection, whitespace handling, clipboard write, and coordinator wiring.

## [7.7.12] — ET-768 · Post-transcription shell command hook

### Added
- Each Power Mode can run a shell command after every transcription (`PowerMode.postTranscriptionCommand`), so a dictation can feed your own workflow: append to a note, POST to a webhook, file a task.
- New `CustomCommandRunner` runs `/bin/zsh -lc <command>` fully detached. The transcript is available **both** on stdin and as `$ECHOTUNE_TRANSCRIPT`.
- Hard **15-second timeout**: SIGTERM, then SIGKILL one second later, so a wedged script cannot accumulate one process per dictation. A `ECHOTUNE_HOOK=post-transcription` marker is set in the child environment.

### Behaviour
- Dictation never waits on the hook — `run()` returns the process immediately.
- A non-zero exit and its stderr are logged; nothing is surfaced as a blocking alert.
- Empty transcripts and empty commands are ignored.

### Verified
- 8 `CustomCommandRunnerTests` cases, including stdin delivery, environment delivery, immediate hand-off, timeout behaviour, and non-zero exit reporting.

## [7.7.11] — ET-767 · Expanded browser URL triggers

### Added
- Power Modes now recognise **Dia** (`company.thebrowser.dia`) and **Comet** (`ai.perplexity.comet`) as scriptable browsers, so site-based Power Mode triggers fire in them like they do in Chrome, Brave, Edge, Arc, Opera, Vivaldi and Safari.
- Both use the Chromium AppleScript dialect (`URL of active tab of front window`) — no accessibility tree walking.

### Test hardening
- Several tests asserted on process-global state (the live `pmset` assertion, live audio-device mute flags) that the running host app legitimately mutates during a test run. Those assertions are now about EchoTune's own bookkeeping, so the full suite is deterministic across consecutive runs (250/250, three runs in a row).

## [7.7.10] — ET-766 · Custom OpenAI-compatible STT & chat endpoints

### Added — Settings → Automation → Custom endpoint
- Connect **LM Studio**, **Ollama (HTTP)**, **vLLM**, **faster-whisper-server**, **OpenRouter** or any other server that speaks the OpenAI wire format, for both `/v1/audio/transcriptions` and `/v1/chat/completions`.
- One-click presets, plus a **Test Connection** button that reports the server's actual reply (or the HTTP error verbatim) instead of failing silently.
- Separate speech-to-text and chat model names, since local servers name their models differently.

### Endpoint handling
- Base-URL normalisation copes with what people actually paste: `localhost:1234`, `…/v1`, a trailing slash, query noise, or a full `…/v1/chat/completions` path.
- Local hosts (`localhost`, `127.0.0.1`, `192.168.*`, `10.*`, `*.local`) default to `http` and need **no API key**; remote hosts default to `https` and require one.
- `Authorization: Bearer …` is only attached when a key exists, so local servers are never sent a header they may reject.

### Verified
- 17 `CustomOpenAICompatibleServiceTests` cases covering URL normalisation, endpoint path building, key-requirement rules, multipart and JSON request shapes, response parsing for both endpoint kinds, and preset validity.

## [7.7.9] — ET-765 · Multi-monitor cursor screen placement

### Fixed — recorders on the wrong display
- The Mini/Slim recorder used `NSScreen.screens.first(where: origin == .zero)` and the recording indicator used `NSScreen.main` (the screen holding the *key window*, not the pointer). On a multi-monitor desk the recorder could open on a display you were not typing on.
- New `RecorderScreenResolver` picks the screen whose frame contains `NSEvent.mouseLocation`, with a nearest-screen fallback for the dead zone between displays and for clamshell/display-reconfiguration cases.
- `RecorderScreenLock` captures that screen when a recording starts and holds it until the panels hide, so the recorder cannot hop displays mid-dictation.

### Verified
- 8 `RecorderScreenResolverTests` cases: cursor hit-testing on both displays, gap handling, bottom/top frame centring inside `visibleFrame`, no-screen safety, lock stability, and a source check that neither view still calls `NSScreen.screens.first` or `NSScreen.main`.

## [7.7.8] — ET-764 · Multi-Mac setup backup & history CSV export

### Added — Settings → General → Move to Another Mac
- **Export Setup…** writes a JSON backup of the Custom Dictionary, Power Modes, Trigger Rules, Filler Words and preferences.
- **Import Setup…** merges that file into this Mac. Existing entries win, so importing the same file twice adds nothing the second time.
- Unsupported future schema versions are rejected with a clear message instead of being misread.

### Security
- API keys and the licence key live in the Keychain and are **never** written to a backup. The preference list is allow-listed, and forbidden keys are stripped defensively even if a caller passes them in.
- Exported files are written with `0600` permissions.

### Added — History → Export CSV
- RFC 4180 compliant transcript export (comma, quote and newline escaping, CRLF line endings, ISO-8601 timestamps, word count derived from the inserted text).

### Verified
- 9 `ConfigurationBackupManagerTests` cases: round-trip, secret exclusion, double-import idempotency, schema rejection, and CSV escaping.

## [7.7.7] — ET-763 · Dashboard consistency heatmap & speaking rhythm

### Added — Dashboard
- **Consistency card**: a 26-week × 7-day GitHub-style heatmap of daily word counts, Sunday-first columns, five intensity bands scaled to your busiest day, plus a hover readout showing the date, word count and session count for that day.
- **When you dictate card**: a 24-hour bar chart of your speaking rhythm derived from history timestamps, with the busiest hours highlighted and the top three peak hours listed as chips.
- Both cards sit below the usage graph and stack vertically when the Dashboard window is narrower than ~820 pt, so the 960×720 default renders cleanly.
- Everything is derived from data already on disk (`AnalyticsManager.dailyStats` and history timestamps) — no new persistence.

### Verified
- 13 `DashboardInsightsTests` cases cover grid shape (26×7), Sunday-first columns, today's position, future-day suppression, word/session mapping, intensity buckets, hour bucketing with and without word counts, peak-hour ordering, and hour label wrapping.

## [7.7.6] — ET-762 · Apple on-device intelligence cleanup (macOS 26+)

### Added — an enhancement provider that never leaves the Mac
- New `OnDeviceRefinementProvider` wraps Apple's `FoundationModels` (`SystemLanguageModel` / `LanguageModelSession`) behind `#if canImport(FoundationModels)` + `@available(macOS 26.0, *)`.
- New enhancement model **“On-device · Apple Intelligence (no network, macOS 26+)”** in **Settings → Automation → Enhancement Model**, routed through `ProviderKind.onDevice`.
- Zero network calls, nothing to download, no API key — the polish happens in-process.

### Guardrails
- The option only appears when the model is actually usable, so the picker never lists a provider that would immediately error.
- When unavailable, the settings row states the exact reason (“This Mac is not eligible”, “Turn on Apple Intelligence”, “still preparing”, or “needs macOS 26”).
- A previously-selected `apple-on-device` migrates back to the default provider if Apple Intelligence is later switched off, so dictation cannot start failing silently.
- All other providers are untouched and keep their existing behaviour.

## [7.7.5] — ET-761 · Closed-lid microphone auto-fallback

### Fixed — dictation with the lid shut
- With an external display in clamshell mode the internal microphone is physically muffled, but CoreAudio kept it as the default input, so dictation captured a dull nothing.
- New `ClamshellStateMonitor` reads `IOPMrootDevice` → `AppleClamshellState`, and `AudioManager.applyClamshellInputFallback()` runs **before** the audio engine is built.
- Lid open: the microphone is never touched. Lid closed with an already-external default: untouched. Lid closed with no external mic available: stays on internal and logs why.

### Behaviour
- Internal-microphone detection covers `Built-in`, `Internal`, `MacBook`, `iMac` device names (case-insensitive) so AirPods, USB interfaces and display microphones are correctly treated as external.
- The read is a single IOKit property lookup per recording start — no polling, no run-loop source, and an IOKit failure can never reroute away from a working mic.

## [7.7.4] — ET-760 · Display-sleep prevention while dictating

### Added
- New `ScreenSleepPreventer` takes a single `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion named **“EchoTune is dictating”** while a recording is live, and releases it the moment recording stops.
- Wired into `AudioManager`: `begin()` right after the engine starts, `end()` in both `stopRecording()` and `teardownAfterFailedStart()`, so a failed start can never leak the assertion.
- Only the **display** is kept awake — the Mac can still idle down — and no other assertion types are touched.

### Verified
- `pmset -g assertions` shows `PreventUserIdleDisplaySleep named: "EchoTune is dictating"` while recording and no EchoTune assertion immediately after stopping (asserted in `ScreenSleepPreventerTests`).
- `begin()` is idempotent, so a double-start cannot leak a second assertion.

## [7.7.3] — ET-759 · Instant CoreAudio hardware mute

### Changed — muting during dictation
- `SystemAudioManager` no longer shells out to `NSAppleScript` (`set volume output volume 0`). Muting now writes `kAudioDevicePropertyMute` directly on each `AudioDeviceID`, and restoring clears it again — two `AudioObjectSetPropertyData` calls instead of a 50–300 ms AppleScript round trip.
- The user's volume level is never modified, so nothing has to be "put back".
- **Never unmutes a device the user muted themselves**: a device that is already muted when dictation starts is left alone and stays muted afterwards. Only devices EchoTune muted are restored.
- Devices without a hardware mute property fall back to the CoreAudio volume scalar — still no AppleScript, still no TCC prompt.

### Verified
- Zero `NSAppleScript` / `set volume` occurrences in app sources (regression-tested).
- Mute + restore completes well under 250 ms including device enumeration (asserted in `SystemAudioManagerTests`), typically sub-millisecond.

## [7.7.2] — ET-758 · Spoken filler removal & punctuation repair

### Added — cleaner transcripts
- New `FillerWordManager`: strips **uh, um, erm, ah, hmm, er, mm** (and variants) from finished transcripts, plus anything you add in **Settings → Speech → Filler Words**.
- Punctuation repair after removal: orphaned commas, doubled punctuation, double spaces, and a capital letter at the start of every sentence.
  - `"I went, uh, to the store. Erm, yes!"` → `"I went to the store. Yes!"`
- New **Settings → Speech → Filler Words** section with a master toggle, an add/remove list for your own fillers, and the built-in list shown for reference.
- `AppSettings.fillerRemovalEnabled` (default on) drives the pipeline from `AppCoordinator.processTranscription`.

### Safety
- Word-boundary matching only: `umbrella`, `humming`, `furious` and similar are never touched.
- A transcript that *is* just a filler (`"Uh."`) is preserved rather than emptied.
- A comma is only dropped when filler removal is what left it dangling, so genuine lists (`"eggs, milk and bread"`) survive.
- Covered by 11 `FillerWordManagerTests` cases.

## [7.7.1] — ET-757 · Offline phonetic vocabulary matcher

### Added — dictation accuracy
- New `PhoneticVocabularyMatcher`: consonant-skeleton encoding (`ech`→`ek`, `ph`→`f`, `ck`→`k`), character-trigram Jaccard similarity, normalized Levenshtein distance, and 1–3 word contiguous span matching — all offline, zero network calls.
- Custom Dictionary entries are now matched phonetically after transcription, so ASR mishearings and split compounds are repaired: `"echo tune"` / `"ekotune"` → **EchoTune**, `"whisper kit"` → **WhisperKit**, `"kubernetis"` → **Kubernetes**.
- English stopword guard: a span may never begin or end on a stopword and stopword-only spans are never rewritten, so ordinary prose is left untouched.
- `DictionaryManager` gains `phoneticMatchingEnabled` (persisted, default on) and seeds **EchoTune**, **WhisperKit** and **Parakeet** on fresh install.
- New **Settings → General → Vocabulary → Phonetic Proper-Noun Matching** toggle.

### Notes
- Dictionary processing order is unchanged in spirit: exact/variation spellings → phonetic spans → spoken-form abbreviations.
- Covered by 12 new `PhoneticVocabularyMatcherTests` cases including idempotency, punctuation preservation and prose-safety.

## [7.7.0] — ET-756 · Fix `NSApp.delegate as? AppDelegate` nil-cast

### Fixed — menu bar window openers
- Under SwiftUI's `@main` lifecycle macOS installs SwiftUI's own wrapper as `NSApp.delegate`, so every `NSApp.delegate as? AppDelegate` cast evaluated to `nil`. That silently broke **Open EchoTune Dashboard**, **Echo Profile**, **Tasks & Commitments**, **Settings…** and status-bar icon updates from the menu bar.
- `AppDelegate` now publishes `static private(set) weak var shared: AppDelegate?`, assigned in `override init()`. All 36 casts across `StatusBarController`, `EchoTuneMenuCardView`, `AppCoordinator+Recording` and `AppCoordinator+Transcription` now use `AppDelegate.shared`.
- Zero remaining occurrences of `NSApp.delegate as? AppDelegate` in app sources (enforced by a new regression test).

### Changed — test reliability
- `KeychainHelper` and `LicenseManager` now use an in-memory store when running in a test host (`XCTestConfigurationFilePath` / `XCTestSessionIdentifier`), so `xcodebuild test` no longer blocks on `securityd`.
- Added `AppDelegateWiringTests` covering the nil-cast regression, the `shared` accessor, and the Keychain test-host bypass.

## [7.5.5] — 2026-11-20

Complete menu bar redesign inspired by CodexBar.

### Changed — menu bar experience
- Replaced the legacy `NSPopover` panel with a native `NSMenu` hosting a rich CodexBar-style card at the top (`Overview`, `Controls`, `Recent` pill tabs) paired with full native AppKit submenus and keyboard shortcuts below.
- Added single-Canvas daily progress bar, 7-day dictation activity sparkline strip with per-day hover readouts, inset pipeline summary card, tactile `Dictate` / `Copy Last` bar, and inline vocabulary-learning and commitment-review cards.
- Added live native submenus for **Transcription Model**, **Microphone Input**, **Dictation Language**, **AI Cleanup & Shortcuts**, and **Recent Dictations**, plus direct openers for **Dashboard**, **Echo Profile**, **Tasks & Commitments**, **Voice Notes**, **Custom Dictionary**, **Share Progress Card**, **Check for Updates…**, **Settings (`⌘,`)**, **About EchoTune**, and **Quit (`⌘Q`)**.
- Added a crisp 1:1 Retina CoreGraphics status-bar waveform renderer (`MenuBarIconRenderer`) with live audio-level bars and monospaced recording timer while dictating, smooth wave animation while transcribing, and a 2pt bottom progress track while downloading/loading models.

## [7.5.4] — 2026-11-19

Production hardening, privacy protection, and commercial rollout fixes.

### Fixed — onboarding, relaunch & dictation reliability
- Fixed a single-instance race when clicking **Move to Applications** or relaunching EchoTune, where the newly spawned app exited on seeing the terminating instance.
- Global dictation shortcuts now stay disarmed until onboarding completes, so testing or rebinding your shortcut on the Hotkey step no longer triggers background dictation.
- Short accidental push-to-talk taps (`<300ms`) and double-tap gestures now discard audio immediately without running VAD, inference, or inserting stray text.
- Onboarding Live Demo now reports background model download progress and includes a **Skip for now** option so first-run setup never blocks on large downloads.
- Recording sessions now freeze Whisper-to-Apple-Speech fallback and cloud/FluidAudio model choices at start, preventing mid-session settings changes from misrouting audio at stop.

### Security & privacy
- Removed all transcript text bodies from macOS Unified Logging (`os_log`); release logs record lengths and timing only.
- Added **Export All Local Data…** (JSON) and **Erase All Local History, Notes, Tasks & Logs…** to **Settings → Privacy**, and restricted saved audio recordings to owner-only (`0600`) file permissions.
- Added Apple `PrivacyInfo.xcprivacy` manifest, updated permission usage descriptions to accurately distinguish on-device vs. optional cloud processing, and purged legacy `UserDefaults` license-key residue.

### Licensing & purchase
- Unified all purchase CTAs onto `https://echotune.app/buy` and added Polar per-device activation & deactivation (`Deactivate This Mac`) with explicit Keychain persistence verification and post-onboarding 7-day trial start.
- Added StoreKit product-load error and retry state for App Store builds, and gated unconfigured referral backend calls.

## [7.5.3] — 2026-11-01

Screen context no longer asks you to quit and reopen.

### Changed — screen context permission
- Removed the "Restart EchoTune" banner and button from onboarding and
  Settings. Persistent restart prompts are gone.
- Screen Recording is now requested through ScreenCaptureKit only; the
  legacy CGRequestScreenCaptureAccess path (the one that makes macOS
  show its own "Quit & Reopen" dialog) is no longer used.
- After a grant, EchoTune retries a live capture probe (immediately,
  then 2s, 5s, 10s, 20s). If it becomes usable, screen context turns on
  right away; if not, it simply activates on the next natural launch,
  with a passive note in Settings and no prompt.

### Added — install location guard
- Running EchoTune from the mounted DMG now shows a "Move to
  Applications" banner. macOS ties Screen Recording grants to the
  app's location, so a DMG copy re-prompts forever; moving to
  Applications removes the loop. Relaunch actions also prefer the
  installed copy.

## [7.5.2] — 2026-11-01

Screen Recording now activates correctly after it is granted.

### Fixed — screen recording permission
- The permissions card used to flip to "Granted" the moment the toggle
  was flipped, but macOS only honors the grant for the running process
  after a relaunch — so screen context silently stayed broken.
- On grant, EchoTune now probes ScreenCaptureKit live: if the grant
  works without a restart (recent macOS builds), the card goes green
  immediately. If not, it says "Granted — macOS applies it after
  EchoTune restarts" with a one-click Restart EchoTune button (mirrors
  superwhisper's restart-capture-pipeline behavior, better than its
  manual-restart copy).
- The grant is now caught without refocusing the app (2s watch while
  ungranted, same pattern as the accessibility watch), and the Settings
  permissions row shows the same restart affordance.

## [7.5.1] — 2026-10-31

Onboarding rebuilt around the superwhisper / Speakly playbooks: fewer
questions, permission guidance that speaks System Settings' language,
a press-to-test hotkey step, and a branded DMG install experience.

### Added — onboarding
- New hotkey step: the dictation key (default ⌥ Option) shows as a large
  keycap that lights up violet while held, with a live "Change key"
  capture that rebinds and saves immediately.
- Branded onboarding sound design: soft intro chime when onboarding opens,
  a subtle pop on step transitions, and a confirm tick when a permission
  flips to granted or a shortcut is saved (custom-synthesized, bundled
  in-app).
- Animated aurora backdrop behind onboarding (single-pass Canvas, no
  real blur, stays cheap on the GPU).
- DMG now opens to a branded drag-to-Applications window (background,
  icon layout, Applications symlink) via Scripts/build_dmg.sh.

### Changed — onboarding flow
- Model selection is gone from onboarding. The curated default
  (Parakeet TDT v3, multi-language) now downloads silently in the
  background while the user walks through the remaining steps.
- Order is now: Welcome → Permissions → Live dictation → Hotkey →
  Purchase/trial → home.
- Live demo step redesigned as a message field with the text on top and
  the live waveform directly below the record control.
- Permissions step guidance now mirrors the System Settings copy
  ("find EchoTune in the list and turn on its switch…"), and Continue
  pulses once both core permissions are granted.

## [7.4.8] — 2026-09-16

Curated the model roster and made the default recommendation consistent
everywhere.

### Changed — model roster
- The app now offers five local models plus the built-in fallback:
  Parakeet TDT v3, Small (English), Large v3 Turbo (slim),
  Paraformer Large (中文) and Parakeet 0.6B (日本語), then Apple Speech.
- Removed: Distil Large v3, Distil Large v3 Turbo, Large v3 Turbo (full),
  Base, Parakeet TDT v2, SenseVoice Small, Parakeet TDT-CTC 110M and the
  never-shown "Coming soon" Parakeet Unified entry.
- Existing installs pointing at a removed model are migrated to the
  recommended default instead of falling through to nothing.

### Changed — Parakeet TDT v3 is the default
- One source of truth, `AIModel.recommendedModelID`, drives onboarding, the
  fit badge, `getRecommendedModel()` and the fallback default. It is offered
  first in the catalog and carries a **Recommended** badge.

### Changed — choosing a model
- Onboarding: the chosen model is promoted into the top card (titled "Your
  selection"), so the header always reflects what you picked.
- Settings: tapping a row is now the primary action. Installed models switch
  immediately; a model that is not downloaded starts downloading and then
  switches automatically. The row stays highlighted while that happens, with
  **Recommended** / **Selected** / **Active** chips.

### Tests
- Added `testCatalogIsTheCuratedRoster` (pins the exact roster and asserts the
  removed models stay gone) and `testParakeetTDTv3IsTheRecommendedDefault`.

## [7.4.7] — 2026-09-16

Critical fix: local Whisper transcription returned **empty text for every
recording** on 7.4.4 / 7.4.5 / 7.4.6.

### Fixed
- Stopped passing `promptTokens` to WhisperKit. With the local CoreML Whisper
  models, WhisperKit 0.15.0 returns an empty transcription whenever
  `promptTokens` is non-nil — the identical audio transcribes correctly with no
  conditioning and returns nothing with a prompt of any length. EchoTune built
  that prompt from the vocabulary list, which always contained the app term
  `EchoTune`, so **every** local decode was conditioned and every result was
  blank. Sending the same terms as `prefixTokens` is equally unsafe: the decoder
  treats them as already-produced text, echoes them and drops real audio.
- Vocabulary is now applied to the finished transcript instead, where it always
  worked. "Apply my vocabulary to transcribed text" gates that pass
  (`AppCoordinator.processTranscription` and
  `TextInsertionManager.processTextReplacements`).
- Added `optionsNeverCarryDecoderConditioning` to lock the decoder input against
  prompt/prefix regression.

### Notes
- Cloud (Groq/Deepgram) and Apple Speech paths were never affected.
- `VocabularyBiasing` remains in the tree but is no longer wired to the decoder.

## [7.4.6] — 2026-09-16

Emergency fix for a microphone permission regression introduced in 7.4.5.

### Fixed
- Restored `com.apple.security.device.audio-input` (and the rest of the
  hardened-runtime entitlements) that were dropped when the 7.4.5 artifact was
  re-signed. Without the entitlement, macOS refused to show the microphone
  prompt and denied `kTCCServiceMicrophone`, so dictation could not start.
- Release signing now goes through `Scripts/release_direct.sh`, which always
  passes `--entitlements EchoTune/EchoTune.entitlements` and verifies the
  entitlements are present before the build is accepted as shippable.

### Notes
- No source behaviour changes relative to 7.4.5.

## [7.4.5] — 2026-09-14

A privacy-first agentic follow-up feature layered onto finalized local dictation.

### Added — Local Commitment and Follow-Up Agent
- Detects explicit commitment language only after finalized local transcription.
- Shows a non-blocking, editable proposal with task, person, context, due date,
  priority, confidence and the exact source sentence.
- Persists only user-accepted proposals; dismissal and pending edits remain
  transient and local.
- Suppresses duplicate pending/open commitments and preserves the source
  transcription identifier when available.
- Historical transcript backfill remains side-effect free; existing records are
  never silently converted into tasks.
- Cloud and unknown transcription providers fail closed for commitment mining.

### Validation
- EchoTuneTests: 135 passed, 0 failed, 2 skipped.
- Release build: passed on macOS 26.6.2 / Apple Silicon.

## [7.4.4] — 2026-09-13

Hardening pass over 7.4.2/7.4.3. Correctness fixes across the dictation
pipeline, cloud paths, and licensing. No new features.

### Fixed — Dictation reliability
- **VAD no longer rejects every recording.** `SpeechProbability.frameLength`
  was never populated, so `analyzeSpeechSegments` summed zero frames, computed
  `0/0`, and classified every VAD-enabled recording as "No Speech Detected".
  Frame length is now carried on every detector result and a zero-frame guard
  prevents NaN. VAD is on by default, so this affected most users.
- **Engine selection is frozen at recording start.** Stop paths re-derived the
  engine from mutable settings, so changing the selected model mid-recording
  could finalise audio through the wrong engine — cloud audio treated as local,
  or a local capture uploaded to a different provider than the one chosen at
  start.
- **Recording start is transactional.** `AudioManager.startRecording()` returns
  a typed result and tears down the engine and tap on failure. Previously a
  failed start left the app in `.recording` with no audio captured.
- **Streaming no longer drops speech it failed to decode.** A live tick that
  returned empty or hallucinated text still marked its buffers as covered, so
  that speech was excluded from the final tail decode and lost.
- **Apple Speech recovers from a failed start.** Failure paths left
  `isTranscribing` set, so every later attempt was rejected and the microphone
  appeared dead until relaunch.
- **Apple Speech drains its conversion queue before ending.** The converter was
  nilled while queued buffers were still converting, dropping the tail.

### Fixed — Cloud
- **Truncated enhancement output is rejected.** OpenAI/Groq `finish_reason:
  "length"` and Gemini `MAX_TOKENS` now raise an error and fall back to the
  original transcript instead of inserting a half-finished rewrite. Empty
  output is rejected too.
- **Oversized cloud uploads fail cleanly** with an actionable message instead
  of attempting a doomed single upload (container-aware chunking was never
  implemented).

### Fixed — Privacy, licensing, storage
- **Clipboard paste no longer clobbers the user's copy.** All pasteboard items
  are backed up, and the pasteboard is only restored while its `changeCount`
  still matches the one EchoTune created.
- **Trial counter moved to the Keychain** so deleting the preferences plist can
  no longer reset the 50-use trial. Existing counts migrate on first read.
- **Retention sweep is main-thread safe.** It snapshots history before deleting
  files on its utility queue instead of iterating a `@Published` array that UI
  mutations can change underneath it.
- **Model downloads check free space first** and report required vs available
  instead of stalling mid-download.
- **30-minute recording cap is enforced** with a notification, instead of being
  declared and only logged.

### Fixed — Performance
- Live preview timer moved off the main run loop to a `DispatchSourceTimer` on
  a private queue, so a busy UI no longer delays ticks.
- Per-tick RMS uses a single-pass accumulation instead of allocating a
  temporary array every tick.

### Fixed — Crashes
- Accessibility element casts are guarded by a `CFTypeID` check before casting,
  so an unexpected element type degrades to a fallback instead of terminating.

## [5.0.0] — 2026-07-26

A reliability, correctness, and privacy pass over 4.0.0, driven by a full
pre-release bug audit. ~24 bugs fixed across the license/revenue path, the
dictation pipeline, the meeting mode, and privacy.

### Fixed — Revenue / License
- **Licenses now persist across launches.** A date-encoding mismatch (ISO-8601
  on write, default on read) silently discarded every paying customer's
  license at every relaunch. Activated keys now survive restart.
- **Trial is no longer resettable by deleting a UserDefaults key.** The trial
  anchor now lives in the Keychain; the per-version trial reset that re-trialled
  the entire user base on every bump has been removed.
- **Revoked / refunded Polar keys now clear the cached license** instead of
  being treated as a transient network error.

### Fixed — Dictation
- **Cloud dictation no longer truncates to ~0.7 s.** The audio converter
  returned `.endOfStream` after the first chunk, finalizing the converter and
  silently dropping every later chunk. Groq/Deepgram dictations now upload the
  full recording.
- **No crash when no microphone is connected.** A force-unwrapped audio format
  on a 0 Hz / 0 channel input device now bails with a "No Microphone Available"
  notification.
- **Transcripts are no longer written to the system log.** Five logging sites
  marked transcript payloads `%{public}`, defeating `os_log` privacy redaction.
- **System audio is always restored after a failed cloud stop** (was left
  permanently muted).
- **Global hotkey self-recovers after a tap timeout.** macOS disables slow
  CGEvent taps; the tap is now re-enabled on `.tapDisabledByTimeout` /
  `.tapDisabledByUserInput` instead of dying until relaunch.
- **VAD no longer rejects 100 % of recordings for upgraders.** The record tap
  computed VAD results but never recorded them, so `hasSignificantSpeech()`
  was always false for anyone with `vadEnabled` carried over from 3.x.
- **No surprise hot-mic after a slow model load.** Push-to-talk now requires
  the shortcut still be held when a cold model load finishes; toggle mode only
  auto-starts if the load took under 10 s, otherwise a "Model ready — press to
  dictate" notification is shown.
- **Audio is archived only when the user opts in.** Dictation audio was written
  unconditionally, and the privacy toggle's "off" state also disabled the
  cleanup sweep — the exact opposite of the setting. Now honours
  `keepAudioHistory`; the sweep always prunes leftovers.
- **Apple Speech dictation no longer adds a hard 3 s latency** and no longer
  discards the recognizer's final corrections. Completion now fires from the
  recognition handler on `isFinal`/error (3 s retained as a fallback), reading
  live state.
- **Smart Capitalization toggle now works** (previously always on regardless of
  the setting).

### Fixed — Meetings
- **Meetings no longer auto-stop when the user multitasks.** Auto-stop was
  triggered purely by the meeting app losing frontmost status; it now requires
  the app to actually quit OR sustained silence on both audio sources.
- **Manual meetings never auto-stop.** A manually started session no longer
  inherits a detection context.
- **Whisper-unavailable during a meeting no longer destroys audio chunks.**
  Model availability is checked at meeting start (blocking with an actionable
  error if unusable); mid-meeting transcription failures re-queue instead of
  dropping the buffer.
- **Summary failures are surfaced, not faked.** HTTP status is now checked on
  all three providers; parse failures and missing-key degradation are
  distinguishable from genuine success; MeetingView shows errors with a retry
  affordance.
- **Regenerating an old summary during a new recording no longer cross-corrupts
  both sessions.** `currentSession` is only touched when it matches the session
  being summarized.
- **Screen-Recording permission denial no longer hard-blocks meetings.** The
  app proceeds mic-only with a banner and offers a deep link to System Settings
  instead of a dead Start button.
- **Session JSON saves are atomic** — a crash mid-write can no longer corrupt
  the previous good snapshot.

### Removed
- `SpeakerDiarizer.swift` — dead "fake diarization" code, zero references.
- Dead auxiliary-hotkey registration (`⌘⇧T` / `⌘⇧E`) that could never fire and
  would crash if it did; the misleading Settings entries removed.
- Non-functional Auto-Punctuation toggle.

### Notes / known gaps
- Meeting **audio** is still not continuously spooled to disk; only the
  transcript JSON is saved (now atomically). A full crash-safe audio spool is
  planned. The 10 s transcript save limits loss to a few seconds of transcript.
- Model corruption recovery (delete + re-download) is wired into onboarding
  but not yet into the main app's load-failure path.
- The project is configured for direct-sale (notarized) distribution;
  `ENABLE_APP_SANDBOX` is off. Sandboxed App-Store builds are not part of this
  release.

---

## [4.0.0] — 2026-07-07

First public open-source release under GPL-3.0. A large cleanup, security, and
reliability pass over the previous private builds.

### Added
- Open-source release: GPL-3.0 `LICENSE`, `NOTICE.md`, `CONTRIBUTING.md`,
  `SECURITY.md`.
- Meeting mode rework: type your own notes alongside a live transcript, then
  generate structured notes that merge your notes with the transcript.
- Crash-safe meeting **transcript** persistence: the in-progress session is
  saved every ~10 s so a crash mid-meeting loses at most a few seconds of
  transcript.
- Launch-at-login toggle in General settings.
- Deepgram Nova as a selectable cloud transcription model.
- Notes tab is now reachable from the sidebar.

### Changed
- Default dictation shortcut is the **Option** key.
- Onboarding restyled to match the app, with a hardware-aware model
  recommendation and a leaner alternative model.
- Menu-bar icon and onboarding use the real EchoTune logo.
- "Private" wording clarified to distinguish local from optional cloud features.

### Fixed
- **Direct-sale (non-App-Store) builds now compile** — the Release
  configuration previously produced an App Store build and had never built a
  sellable binary; also fixed a Swift optimizer crash that blocked Release.
- Eliminated a duplicate-hotkey double-trigger where one key press started and
  stopped dictation twice.
- Large-model download and the "large v3 turbo" model id are resolved correctly.
- Corrupted/partial model downloads are detected and re-fetched instead of
  failing forever (onboarding path).
- Crash reporting is now strictly opt-in with no PII.

### Removed
- Third-party reference source trees and dead code (~15+ unused files).
- A non-functional "NVIDIA Parakeet" model entry that silently fell back to
  Apple Speech.
- Misleading settings toggles that did nothing.

### Security
- Referral backend access hardened (server-side change required — see
  deployment notes).
- Deep-link referral codes are now validated before use.
- Unused entitlements removed.
