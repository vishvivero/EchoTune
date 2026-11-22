# Changelog

All notable changes to EchoTune are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [7.6.9] — 2026-11-22

Fixes the menu bar icon taking no click at all. The app worked (dictation, hotkeys, windows) but
clicking the icon did nothing, which is what the previous two releases were chasing.

### Root cause — Control Center never forwards the click for this app

On macOS 26 the window server draws third-party status items through Control Center
(`NSSceneStatusItem` / `NSStatusItemView`, CGWindowLayer 25) and is responsible for forwarding the
click back into the owning app. Measured on macOS 26.6, that forward is simply not delivered for
EchoTune:

| Evidence | Result |
| --- | --- |
| Item registered and drawn | ✅ `Control Center` window `name=EchoTuneStatusItem`, `x=892 w=36`, layer 25 |
| `AXUIElementPerformAction(item, kAXPressAction)` | ✅ opens the menu (so the menu itself is fine) |
| `AXUIElementCopyElementAtPosition` at the icon centre | ✅ resolves to our `AXMenuBarItem` |
| **A real mouse-down, swept across 30 x-positions over the whole slot** | ❌ **never opens anything** |
| Control Center's unified log for that click | ❌ no `[Forward Event]` for us at all |
| Same click on 6 other third-party items (Tailscale, Ollama, AlDente, CopyClip, Proton VPN, SSMenuAgent) | ✅ all open |
| Same click on the Apple menu | ✅ opens |

So the click injection is sound and the fault is specific to EchoTune: a status item that is never
told about the click cannot react to it. Two different transports were tried on the previous
release — the native `statusItem.menu` and `button.action` + `NSPopover` — and both failed, because
neither is reached. Re-vending the item and restarting Control Center were tried too; both failed.
A menu-height reduction (the card was 826 pt tall, barely fitting a 956 pt screen) did not change it.

### The fix — stop depending on the forward

- The icon's own rect is watched directly by two independent detectors: an
  `NSEvent.addGlobalMonitorForEvents` for mouse-downs (which is where a menu bar click goes, because
  Control Center owns the window) and a **listen-only** `CGEvent` tap for `leftMouseDown` /
  `rightMouseDown`. The tap cannot consume or alter any event, and both funnel through one cooldown,
  so a click reported twice is still handled once.
- The two paths cannot double-fire by construction: a global monitor sees events delivered to *other*
  applications, while the button action fires only when the event is delivered to *us*. A 0.25 s
  cooldown covers the remaining case.
- A second guard stops the icon appearing dead when the user clicks it to close: the click goes to
  Control Center, the `.transient` popover dismisses itself, and the monitor then sees the same
  click. Reopening within 0.3 s of a self-dismiss is suppressed. Both rules are pinned by tests.
- The CodexBar-designed card is back in an `NSPopover` with its Model / Microphone / Language / Paste
  pickers, so the UI works in the normal run loop instead of NSMenu's modal tracking loop.
- The status item is no longer re-vended on activation-policy changes (that tore down Control
  Center's tracked scene, which broke the icon in 7.6.3–7.6.5), and the recording timer no longer
  writes a tenths-of-a-second string into `button.title` ten times a second (which forced Control
  Center to re-lay-out the status-item scene at the same rate).

### Also in this release

- Restored the "Close Dashboard Window" escape hatch, `AppDelegate.shared` lookups and the
  Space/frame repair that 7.6.8 introduced, on top of the popover UI.

### Verification

- **Menu bar, real clicks:** click → open, click → close, click �� open, click → close. 4/4, with the
  app logging `Menu bar icon click handled by monitor` + `Toggling popover` for each.
- **Window controls:** `Scripts/verify-window-space.sh check EchoTune` → **VERDICT=PASS** (frame
  drift 0.0 pt, title bar on screen, click reaches the title bar). `real-click EchoTune` → a real
  click on the red button reports `button 1 of window EchoTune` and the window count goes **1 → 0**.
- **Tests:** 182 passing, 0 failing, 2 skipped, including the new `MenuBarClickTests` (8 cases).
- **Launch surface:** the stale Debug/`7.6.7` bundles that made Spotlight offer an old copy are
  archived out of the app index, so `mdfind` resolves to `/Applications/EchoTune.app` alone.

## [7.6.8] — 2026-11-22

Fixes the report that the app *works* but cannot be closed, has no clickable buttons, and whose
menu bar icon does not respond.

### Fixed — the Dashboard could end up unreachable, and nothing in the menu bar worked

**Root cause 1 — a window ordered into another app's full-screen Space.** EchoTune is a menu-bar
(`.accessory`) app that also owns standard windows. Launching it, or opening a window, while
another app's full-screen Space was active parked the window inside that foreign Space: no menu
bar, WindowServer owning the frame, and every click landing on the app behind it. Measured live,
WindowServer had the Dashboard at Quartz `(-228, 897)` — below a 956 pt display, in Chrome's
full-screen Space — while `NSWindow.frame` still reported a healthy `(255, 54)`, so the existing
off-screen check saw nothing wrong. Promoting `.accessory` → `.regular` afterwards does not make
macOS leave that Space either.

- A deliberate launch now adopts `.regular` *before* the Dashboard is created, so macOS performs
  its normal activation and Space switch. Login launches still stay quiet in the menu bar.
- New `SpaceInspector` reads the active Space and a window's Space membership from WindowServer
  and can escort a window onto a Desktop Space (and bring that Space forward) for the cases where
  the app was already a menu-bar app.
- Standard windows are `fullScreenNone`, so EchoTune can no longer create its own full-screen
  Space, and the onboarding window's `.moveToActiveSpace` (which moved it straight into a foreign
  full-screen Space) is gone.

**Root cause 2 — `NSApp.delegate` was never EchoTune's AppDelegate.** SwiftUI owns a lifecycle
app's `NSApp.delegate` (it is SwiftUI's own wrapper), so all 40 `NSApp.delegate as? AppDelegate`
lookups in the app silently evaluated to nil. The status icon never reflected the recording state
(21 call sites) and every menu bar item and menu-card button that opens a window did nothing at
all — *Open EchoTune Dashboard*, Settings…, Echo Profile, Tasks, Notes, Dictionary, Share and the
menu card's own buttons (19 call sites). The delegate now publishes itself as
`AppDelegate.shared`; a source-level test fails the build if the cast ever comes back.

**Root cause 3 — no escape hatch.** ⌘W/⌘Q exist, but they live in the app's own menu bar, which is
exactly what you cannot reach when the window is stranded. The always-reachable menu bar card now
has **Close Dashboard Window** (enabled only while a window is on screen), and Escape closes the
Dashboard, ignored while a text field has focus because a field editor treats Escape as "revert
this field".

**Also fixed**

- `keepWindowReachable` now treats WindowServer's frame as the source of truth, adopts it when
  AppKit's model has drifted, and re-checks every managed window on Space changes, display wake
  and resolution changes (debounced, and never while a mouse button is down so a repair cannot
  fight a live drag).
- A window in the Dock counts as reachable, so the Dock icon that restores it stays, and "Close
  Dashboard Window" can close a window the user cannot reach at all.
- The "show main window" hotkey no longer guesses a window by title (which could raise *EchoTune
  Settings*) and no longer uses the deprecated `ignoringOtherApps:` flag; it asks the delegate to
  present the Dashboard.

### Verification

- `Scripts/verify-window-space.sh scenario` reproduces the original fault and asserts the fix:
  it arms a foreign full-screen Space, launches the app, then checks the window's Space, the
  agreement between WindowServer and AppKit frames, title-bar reachability and hit testing, and
  finally posts a *real* click on the red button through System Events. Before the fix the window
  landed on the full-screen Space with no usable title bar and a click resolved to the app behind;
  after it the window is on a user Space with 0.0 pt drift and the click reports
  `button 1 of window EchoTune` with the window closing (1 → 0).
- 21 new unit tests (177 total, 175 passing, 2 skipped), covering the pure frame-repair logic,
  both escape hatches driven against the live delegate, delegate reachability, and the
  window-presentation consolidation.
- The four 1470 x 33 menu-bar-sized proxy windows that the stranded state produced are gone: the
  app now registers exactly one window (the Dashboard), and its Dock lifecycle is verified live —
  the app reports policy `.regular` with the Dock tile while a window exists, and `.accessory`
  without it once the window is closed.

## [7.6.7] — 2026-11-20

Restores full interactivity: the Dashboard window can no longer be stranded off-screen, and the menu bar icon responds to the first click again.

### Fixed — window unreachable / "no close button, can't click anything"
- The Dashboard window could end up **fully below the bottom of the display** (observed live at `y = 939` on a 956 pt screen, i.e. only a ~17 pt sliver visible). With its title bar off-screen the traffic lights were invisible and every click landed on whatever app was behind EchoTune. Added `keepWindowReachable(_:)`: any managed window is re-centred inside `NSScreen.visibleFrame` before it is presented, clamped back when it is dragged past the edge (`windowDidMove`), repaired on display changes (`windowDidChangeScreen`), and sanitised at launch.
- Removed the `NSStatusItem` re-vend that ran on every `.regular` → `.accessory` transition. Re-registering the status item tore down Control Center's tracked status-item scene on macOS 26; the replacement could keep drawing while no longer forwarding clicks. The app now owns **one long-lived status item** for its whole lifetime.

### Fixed — menu bar icon needed a click that never arrived
- Restored the native `statusItem.menu` + `NSMenu` transport (the mechanism macOS handles itself, and what every other healthy menu bar app on this Mac uses) in place of the `button.action` + `NSPopover` path, which Control Center kept highlighting without forwarding the click into EchoTune.
- The recording timer no longer writes a tenths-of-a-second string into `button.title` 12×/second. On macOS 26 that resized the status item on every animation frame and forced Control Center to re-lay-out the status-item scene ~12×/sec — measured directly in Control Center's unified log as a continuous `NSSceneFenceAction` storm. The readout is now whole seconds (stable width) and the waveform animates at 10 Hz, with the button only touched when its image, title, or position actually changed.

## [7.6.1] — 2026-11-20

Fixed first-click interactivity inside the menu bar card and floating recorder panels.

### Fixed — menu bar & recorder button clicks
- Added AppKit `.eventTracking` first-mouse tap overlays (`FirstMouseMenuTapNSView` + `FirstMouseMenuHostingView`) across all buttons, tabs, segmented pills, and switches inside the `NSMenu` card so every control responds on the very first click even while EchoTune is an inactive background menu-bar app on macOS 26.
- Clicking **Dictate** inside the menu card now dismisses the menu before starting capture so focus stays in your active editor, and added native top-level **Start / Stop Dictation** and **Copy Last Dictation** rows right below the card.
- Enabled `acceptsFirstMouse` on `MiniRecorderWindow`, `RecordingIndicatorWindow`, and `NotchRecorderWindow` so clicking the floating mic/stop button always triggers on the first click.

## [7.6.0] — 2026-11-20

Major feature release adding 18 workflow, reliability, local-intelligence, and UI capabilities.

### Added — intelligence, vocabulary & voice editing
- **Offline Phonetic Vocabulary Matcher**: automatically corrects phonetically misheard proper nouns and multi-word terms from your Custom Dictionary (e.g. `"echo tune"` / `"ekotune"` → `"EchoTune"`) with zero decoder conditioning.
- **Selected-Text Voice Transform Mode**: highlight text in any Mac app and **double-tap `⌥`** to speak an editing command (*"make this shorter"*, *"fix grammar"*, *"translate to Spanish"*) and replace the selection in place.
- **Apple On-Device Intelligence Refinement (macOS 26+)**: 100% offline, zero-download, zero-API-key grammar and filler cleanup via Apple's Neural Engine `FoundationModels`.
- **Custom OpenAI-Compatible STT & Chat Endpoints**: connect LM Studio, OpenRouter, vLLM, Jan, Ollama HTTP, `faster-whisper-server`, or `whisper.cpp` server in **Settings → AI & Models**.
- **Configurable Spoken Filler Removal**: customizable filler list (`uh`, `um`, `erm`, etc.) with automatic post-removal comma, spacing, and sentence-capitalization repair.

### Added — recorder styles, quick HUDs, paste methods & automation
- **MacBook Notch Recorder Style**: Dynamic-Island-style top-center notch expansion (`Slim` · `Mini` · `Notch`), plus cursor-display locking (`RecorderScreenResolver`) across multi-monitor setups.
- **Quick History HUD (`⌘⇧H`) & Quick-Add Dictionary HUD (`⌘⇧D`)**: Spotlight-style floating panels to search/paste recent transcripts or save highlighted words in one keystroke.
- **Multi-Strategy Paste Methods & Cursor-Aware Smart Punctuation**: choose Standard `⌘V`, AppleScript, Direct Typing (no clipboard), or **Remote Desktop / VM Hardware Typing** (Citrix, RDP, RustDesk, Parsec, UTM/VMware), plus cursor-aware spacing and mid-sentence case adjustment.
- **macOS `AppIntents` & Shortcuts**: control EchoTune natively from Apple Shortcuts, Siri, Raycast, Stream Deck, and Action Button.
- **Post-Transcription Shell Command Hook**: optional `/bin/zsh` pipeline (`stdin` + `ECHOTUNE_TRANSCRIPT`) with 15s timeout, plus expanded browser URL triggers for **Dia**, **Comet**, **Firefox**, and **Zen**.

### Added — hardware reliability, backup & insights
- **CoreAudio Hardware Mute, Clamshell Mic Fallback & Display-Sleep Guard**: `<1 ms` `kAudioDevicePropertyMute` output muting, automatic external-mic routing when MacBook lid is closed, and `IOPMAssertion` display-sleep prevention during active dictation.
- **Multi-Mac Setup Backup (JSON) & History CSV Export**, plus **6-Month Consistency Heatmap & 24-Hour Peak Flow Hours** cards on the Dashboard.

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
