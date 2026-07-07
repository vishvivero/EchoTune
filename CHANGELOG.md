# Changelog

All notable changes to EchoTune are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [4.0.0] — 2026-07-07

First public open-source release under GPL-3.0. A large cleanup, security, and
reliability pass over the previous private builds.

### Added
- Open-source release: GPL-3.0 `LICENSE`, `NOTICE.md`, `CONTRIBUTING.md`,
  `SECURITY.md`.
- Meeting mode rework: type your own notes alongside a live transcript, then
  generate structured notes that merge your notes with the transcript.
- Crash-safe meetings: audio and transcript are saved incrementally, so a
  crash mid-meeting no longer loses the session.
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
  failing forever.
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
- App sandbox/hardened-runtime configured for notarized distribution; unused
  entitlements removed.
