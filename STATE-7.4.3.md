# EchoTune 7.4.3 — State (compact)

*Written 2026-09-13. Compact handoff; replaces verbose session history.*

## LIVE
**EchoTune 7.4.3 (build 103)** deployed and verified.
- appcast `https://echotune.app/appcast.xml` → 200, `sparkle:version=103`, Ed25519 signed
- archive `https://echotune.app/downloads/EchoTune-7.4.3.zip` → 200, 9,681,338 bytes
- SHA256 `cde1d5becc01e753bbcb3487f8de35d873eee4a33b35a97b9f39bd9657b30a8c` (live == local)
- Notarized (submission `eee237b0`), stapled, Gatekeeper accepted
- Tests: 130 passed / 0 failed / 2 skipped (full EchoTuneTests, xcresult `result: Passed`)

## SOURCE
- Repo `/Users/zac/.openclaw/workspace/EchoTune`
- Worktree `/Users/zac/.openclaw/workspace/worktrees/echotune-7.4.3`
- Branch `phase/11-hardening-7.4.3` (pushed), 7 commits off `phase/10-enhancement-telemetry`

## SHIPPED IN 7.4.3
- VAD `frameLength` regression (was rejecting every VAD-enabled recording)
- Clipboard all-items backup + `changeCount` handshake
- `finish_reason` truncation guard (OpenAI/Groq/Gemini) + empty-output reject
- 30-min recording cap enforced
- Oversized cloud upload fails cleanly
- Storage-aware model download guard
- AX element casts CFTypeID-checked
- perf: RMS single-pass + live timer off main run loop

## PENDING — Bucket A (architecture, high risk)
- (2) Immutable engine/model capture at recording start — NEXT
- (1) Coordinator-level session generation token (residual)
- (3) Transactional recording start
- (4) Apple Speech lifecycle cleanup
- (5) Apple Speech stop queue drain
- Whisper streaming speculative commit
- Cloud backpressure; CorrectionLearner index; Power Mode state

## PENDING — Bucket B
- Real Groq container-aware chunking (only fails cleanly now)
- Audio cleanup sync; license/trial to Keychain; Swift 6 warnings
- Dictation/insertion/download integration tests
- Sparkle release automation

## RELEASE PROCEDURE (learned)
1. `xcodebuild archive -configuration Release -destination 'generic/platform=macOS' SPARKLE_PUBLIC_ED_KEY=<key>`
2. `xcodebuild -exportArchive -exportOptionsPlist Scripts/ExportOptions_Direct.plist`
3. zip via `ditto`, `notarytool submit --keychain-profile "EchoTune Notary 2"`, `stapler staple`
4. `generate_appcast --account echotune --download-url-prefix https://echotune.app/downloads/`
5. Copy appcast→`public/appcast.xml`, zip→`public/downloads/`, then
   `netlify deploy --prod --build` (do NOT pass `--dir .`; it 404s the static files)
6. EchoTune must be QUIT before `xcodebuild test`, or the test host dies on the single-instance guard.
