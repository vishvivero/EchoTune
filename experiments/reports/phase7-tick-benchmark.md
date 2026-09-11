# Phase 7.2 — Tick/window benchmark

## Target and method

Target: arm64 MacBook Air, macOS 26.6.2. WhisperKit 0.15.0, the cached
Large v3 Turbo model, CPU+GPU compute units, and the standard synthetic speech
fixture. The benchmark used a fixed 5-second 16 kHz mono window, which matches
P7.2's proposed bounded sliding-window decode. Five warm runs were collected
for each option, alternating order to reduce thermal/order bias.

The vocabulary prompt used the four default terms plus `EchoTune`, producing
25 Whisper prompt tokens.

## Results

| Decode option | p50 | p95 | Change vs no prompt | RTFx |
|---|---:|---:|---:|---:|
| Live, no vocabulary prompt | 2.425s | 2.426s | baseline | 2.06x |
| Live, 25-token vocabulary prompt | 2.583s | 2.587s | **+6.5%** | 1.94x |
| Live, word timestamps enabled | 2.430s | 2.431s | **+0.2%** | — |

Word-timestamp alignment is therefore below the PRD's 15% overhead gate on
this fixture and is enabled for live options only. Final options retain
`wordTimestamps == false` and the existing WhisperKit defaults.

The initial attempt to benchmark 1s/2s/4s audio slices was discarded: a
1-second slice returned near-immediate no-output timings and does not represent
P7.2, whose tier changes cadence while the decode window remains bounded at
approximately 5 seconds. The fixed-window measurement above is the valid
per-tick cost. Preview-tier cadence/preview-lag measurement still requires a
runtime capture or harness that schedules the same fixed window at each tier.

## Decision

- Keep `PreviewTier.balanced` (2s) as the provisional default.
- Preserve `.classic` (4s) as rollback.
- Enable live word timestamps and feed their probabilities into
  `AgreementEngine`.
- Do not switch the shipping default to `.reactive` (1s) until cadence and
  preview-lag measurements are recorded; the current direct decode benchmark
  does not measure scheduler cadence.

The implementation now uses a bounded five-second rolling suffix for the
balanced and reactive tiers, extracts only newly arrived text at the rolling
window boundary, and keeps `.classic` on the legacy delta path. Agreement
state receives cumulative newly arrived words and their Whisper probabilities.
Stop finalization invokes the full-audio batch fallback when the agreement
engine finishes with fewer than three confirmed words; fallback timing and
choice are logged. The remaining tail now runs up to three final passes;
exact text agreement across two passes wins, otherwise the first pass is
retained because the app-level result type does not expose a comparable mean
log probability.

Each live decode now emits a `P7_TICK` record with tier, source-window
seconds, post-VAD decode-window seconds, and end-to-end tick elapsed time. The
remaining P7 acceptance work is runtime validation: record preview lag and
per-tier scheduler behavior over a real session, then compare the fixed-window
path against the classic rollback path. This direct model benchmark does not
measure scheduler cadence or first-visible-word lag.

A temporary fixture-driven app probe was attempted with the cached model and
all three tiers. Model preparation and VAD startup made the app-level decode
much slower than the isolated harness; the probe did not produce a reliable
first-update sample before its timeout and is not counted as acceptance. The
probe also exposed a safety issue where a no-text tick could advance the
committed buffer index; finalization now retains the full recording whenever no
live segment was successfully committed, preventing speech loss.
