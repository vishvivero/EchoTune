# Phase 5 — Parakeet batch engine

## Scope

Phase 5 adds a first-class FluidAudio Parakeet backend for finalized/batch
transcription. The implementation uses the pinned FluidAudio 0.15.5
`AsrModels` + `AsrManager` APIs. FluidAudio owns model download, cache layout,
CoreML loading, and long-audio chunk processing.

## Implemented

- `AIModelBackend` routing enum covering Apple Speech, Whisper, Parakeet,
  SenseVoice, Paraformer, Groq, Deepgram, and OpenAI.
- Catalog entries for Parakeet TDT v2, TDT v3, and the unified model ID.
  The pinned FluidAudio API exposes TDT v2/v3 as `AsrModelVersion`; the unified
  catalog entry remains `comingSoon` until a compatible batch API is exposed.
- `ParakeetEngine` model-version mapping, download/load state, same-model load
  de-duplication, 16 kHz mono conversion, batch transcription, and explicit
  batch-only streaming behavior.
- Long audio is delegated to FluidAudio's batch manager, which selects its
  disk-backed path above the configured threshold.
- Recording and re-transcription routing now uses `AIModel.backend`, not model
  name/ID substring matching.
- Parakeet load/transcription failures fall back to an installed Whisper model
  when one is available.
- Whisper pending load completions are keyed by requested model ID, so a
  concurrent request for another model cannot receive the active model's
  success callback.

## Validation

| Gate | Result |
|---|---:|
| Debug Xcode build (`CODE_SIGNING_ALLOWED=NO`) | PASS |
| Unit tests (`-only-testing:EchoTuneTests`) | PASS |
| Unit test count | 68 passed |
| Backend/catalog mapping tests | 3 passed |
| Parakeet model load/transcription benchmark | PASS |

The unit test run completed with `** TEST SUCCEEDED **` in
`/tmp/echotune-phase5-tests/Logs/Test/`.

## Runtime benchmark

Target: MacBook Air, arm64, macOS 26.6.2. Model: Parakeet TDT v3, FluidAudio
0.15.5, cached model size approximately 469 MB. Fixture:
`experiments/fixtures/synthetic-speech-12s.aiff` (12.122 seconds, 22.05 kHz
AIFF; synthetic speech).

| Measurement | Result |
|---|---:|
| First-use end-to-end preparation + three decodes | 74.684s |
| Subsequent cached engine preparation | 0.376s |
| Decode run 1 | 0.242s |
| Decode run 2 | 0.111s |
| Decode run 3 | 0.113s |
| Warm median decode | 0.113s |
| Warm RTFx | 107.28x |

The first-use figure includes FluidAudio model acquisition/loading and the
three benchmark decodes; it is intentionally reported as an end-to-end
number rather than falsely presented as isolated load time.

Reference transcript WER against `synthetic-speech-12s.txt` was approximately
13.6% (3 word edits over 22 reference words). The output preserved the full
utterance but normalized `EchoTune` to `Echo to` and `five` to `5`, so this
small synthetic fixture is useful for latency smoke testing, not a quality
acceptance corpus.

## Remaining benchmark work

This establishes the Phase 5 baseline. A broader acceptance pass should add
multiple natural-speech fixtures and a Whisper comparison using the same
post-processing settings. Phase 6 should rerun the warm decode and parity
subset after vocabulary handling lands.
