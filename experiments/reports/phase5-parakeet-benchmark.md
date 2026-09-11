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
| Parakeet model load/transcription benchmark | Not run — no Parakeet model was downloaded during this validation pass |

The unit test run completed with `** TEST SUCCEEDED **` in
`/tmp/echotune-phase5-tests/Logs/Test/`.

## Benchmark limitation

A real RTFx/WER benchmark requires downloading the selected Parakeet CoreML
repository and running the supplied speech fixture on the target Mac. No
network/model acquisition was performed as part of this code-only validation,
so no fabricated latency or parity number is reported. The next acceptance
step is to prepare `parakeet-tdt-0.6b-v3`, transcribe the shared fixture with
both Parakeet and Whisper, and record wall time, RTFx, and transcript parity.
