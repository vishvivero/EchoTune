# Changelog

All notable changes to EchoTune are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

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
