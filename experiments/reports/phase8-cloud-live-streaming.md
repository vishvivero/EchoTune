# Phase 8 — Cloud live streaming status

Date: 2026-09-11
Branch: `phase/8-cloud-live-streaming`

## Implemented

- `CloudStreamingSession` protocol and `CloudStreamingConfig`.
- Local `UsageMeter` with JSON persistence, 500-record rotation, backup-before-rotation, corrupt-file parking, and local cost estimates.
- Deepgram WebSocket session using the documented live-listen shape:
  `encoding=linear16`, `sample_rate=16000`, `channels=1`, `interim_results=true`, `punctuate=true`, `smart_format=true`, and `endpointing=300`.
- Float32-to-Int16 PCM framing.
- Deepgram Results parser and offline fixtures.
- Two reconnect attempts followed by degraded state and batch fallback.
- Opt-in `deepgramLiveEnabled` setting, default off.
- Deepgram live audio wiring in `AppCoordinator`; stream failures and empty results use the existing REST batch service.
- Usage records for streamed and batch-fallback Deepgram sessions.
- Groq decision: remain batch-only because a stable documented realtime STT contract was not established. See `experiments/2026-09-11-groq-streaming-decision.md`.

## Validation

- Debug build: passed.
- Full EchoTune unit suite with `-parallel-testing-enabled NO`: passed.
- `UsageMeterTests`: passed.
- `DeepgramMessageTests`: passed.
- No provider key was used in tests; no live network benchmark has been claimed.

## Remaining P8 acceptance

1. Run a real Deepgram session with a configured key and measure interim p50 lag,
   finalization latency, reconnect behavior, and usage records.
2. Verify the stream receives the intended 16 kHz audio from a physical mic.
3. Confirm no key material appears in captured logs.
4. Review the Deepgram query/model pricing against current provider docs before
   release; local price values are estimates only.

The benchmark attempt on 2026-09-11 was blocked before making any network
request: the macOS Keychain has no `deepgramAPIKey` entry. No credential was
printed or requested through the shared activity layer. Add the key through
EchoTune Settings → Cloud API Keys, then rerun the benchmark; the live toggle
remains off by default until that manual check is complete.
