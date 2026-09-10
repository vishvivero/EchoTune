# Phase 2 (7.2.1) — live-tick hot path benchmark

**Branch:** `phase/2-live-tick-hot-path` @ `91095e3` (off tag `v7.1.0`)
**Harness:** `/Users/yashna/echotune-bench/Sources/echotune-bench/main.swift` (SwiftPM, WhisperKit 0.15.0 exact)
**Host:** Apple M4 (Mac16,12), 16 GB, macOS 26.6.2
**Model:** `openai_whisper-large-v3-v20240930_turbo_632MB` (the model EchoTune ships, `cpuAndGPU` compute)
**Audio:** `experiments/fixtures/synthetic-speech-12s.aiff`, resampled to 16 kHz mono (what the app feeds WhisperKit), looped 3× → 10 slices of 4 s, 9 measured per config (tick 1 used as warmup)

## What was measured

The repo's own harness (`Scripts/phase2_runtime_inventory.sh`) only measures model load and whole-clip batch decode, which Phase 2 did not change. This benchmark drives the two `DecodingOptions` the live-tick path constructs, so the delta is exactly the Phase 2 change:

- **PRE Phase 2** — `detectLanguage: true` on every tick + WhisperKit default `temperatureFallbackCount: 5`.
- **POST Phase 2** — `detectLanguage: false` (language pinned after tick 1) + `temperatureFallbackCount: 0` (greedy).

Both configs use the real model and the same 4 s tick the live timer decodes.

## Results (per-tick wall time, seconds)

| Chunks | Config | p50 | p90 | max |
|---|---|---|---|---|
| normal speech | pre | 3.06 | 4.85 | 4.85 |
| normal speech | post | 1.98 | 2.52 | 2.52 |
| quiet (RMS 0.0048) | pre | 3.02 | 4.52 | 4.52 |
| quiet (RMS 0.0048) | post | 1.97 | 2.56 | 2.56 |

**Median improvement: +35.3% faster per tick on normal chunks, +34.7% on quiet chunks.** The tail (p90/max) improves more sharply — the pre-change config occasionally paid the full fallback chain, spiking to ~4.5–4.9 s, while post-change stays under ~2.6 s.

An earlier run at the fixture's native 22.05 kHz (n=3) showed the same direction (+15.8% normal, +36.9% quiet), so the signal is not sample-rate-specific. The 16 kHz run above is the one to cite: correct input format, 9 measured ticks per config.

## Caveats

- Synthetic speech-like fixture, not human dictation; it stresses the decode path but not real language detection accuracy.
- Single warm model, single host, one process. Not a multi-run median-of-medians.
- `quiet` = speech scaled to 0.06 (RMS 0.0048), still above the app's 0.001 live-tick gate, so it exercises the path rather than being skipped by RMS.
- Model load (~10 s warm, ~30 s cold) is separate and unaffected by Phase 2.

## Reproduce

```bash
cd /Users/yashna/echotune-bench
swift build -c release
./.build/release/echotune-bench 2>&1 | grep -v '^\[' | tail -12
```