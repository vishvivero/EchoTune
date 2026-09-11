# Phase 4 Silero VAD benchmark

**Date:** 2026-09-11
**Branch:** `phase/4-silero-vad`
**Host:** Apple M4, 16 GB, macOS 26.6.2
**WhisperKit:** 0.15.0 exact
**FluidAudio:** 0.15.5 exact
**Model:** `openai_whisper-large-v3-v20240930_turbo_632MB`

## Model preparation

FluidAudio's `VadManager` successfully downloaded and loaded the Silero
CoreML model through its supported model hub path:

`~/Library/Application Support/FluidAudio/Models/silero-vad/silero-vad-unified-256ms-v6.2.1.mlmodelc`

The cache occupied approximately 1.0 MB on disk. The probe reported
`available=true` after preparation. FluidAudio's model uses 4096-sample
chunks at 16 kHz (256 ms) and `.all` compute units, as configured by
`FluidVADEngine`.

## Decode benchmark

The benchmark used the existing 12.124 s 16 kHz synthetic-speech fixture. A
1.0 s silent prefix and suffix were added to produce a 14.124 s decode window.
The trimmed comparison decoded the original 12.124 s speech fixture. Both
paths used the same WhisperKit GPU configuration and greedy Phase 2 decode
options. Five measured runs followed one warmup run per path.

| Window | Runs (seconds) | Median |
|---|---|---:|
| Full window with 2.0 s total silence | 5.300, 5.269, 5.234, 5.227, 5.243 | **5.243 s** |
| VAD-trimmed window | 3.375, 3.349, 3.362, 3.355, 3.346 | **3.355 s** |

The trimmed path reduced the measured decode wall time by **36.0%** on this
fixture, while removing 2.0 s of non-speech from the encoder input. This is a
controlled silence-window comparison, not a claim about speech recognition
accuracy.

## Unit and runtime validation

- Pure silence trimming, padding, merging, minimum-length, and ordering tests
  pass.
- Synthetic 1 s silence + 3 s speech + 1 s silence span mapping passes within
  150 ms tolerance.
- FluidAudio model preparation and in-memory segmentation completed on the
  host. The real synthetic-speech fixture produced 48 model chunks with 46
  active chunks and one segment spanning 0.000–12.122 s.
- The actual Silero model does not classify a pure 220 Hz tone as three seconds
  of human speech; the synthetic boundary test therefore uses a deterministic
  VAD-result stub, as specified by the packet, while the runtime probe verifies
  the real model path.
