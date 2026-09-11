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
seconds, post-VAD decode-window seconds, and end-to-end tick elapsed time.
Stop now emits `P7_DISPOSITION` with `streamed`, `batchFallback`, or
`noSpeech`, confirmed-word count, and captured duration. Batch fallback is
bounded to five minutes; longer low-agreement sessions retain the streamed
result and log the guard decision. No-speech finalization returns an empty
success so the coordinator's existing no-insertion path handles it quietly. The
The tier scheduler and fallback path have now been exercised in an app-level
session. The remaining acceptance caveat is the streamed-disposition path:
this fixture stayed below the 0.6 confidence frontier, so a verified
high-confidence corpus or physical microphone session is still needed to
measure first confirmed-word latency and prove streamed (non-fallback) commit.
The observed stop-to-final times (3.300–3.871s) are substantially better than
an arbitrary polling wait but do not meet the PRD's aspirational 0.7s target.
A direct cached-model stop benchmark measured one 9.4s final Whisper decode at
3.319s and three final passes at 9.914s; the model-bound lower bound is already
above 0.7s before result assembly. A silent one-second tail was 0.005s, which
confirms that the budget is attainable only when a completed live result can be
reused and no speech remains to decode. Three final passes or a full-audio
fallback cannot meet 0.7s on Large v3 Turbo.

A temporary fixture-driven app probe was run against the cached model. The
first Samantha fixture produced no text and was not counted. A verified Daniel
TTS fixture then produced the same 142-character final text for all three tiers:

| Tier | Live updates | Stop-to-final | Disposition |
| --- | ---: | ---: | --- |
| classic | 2 | 3.300s | batchFallback |
| balanced | 2 | 3.871s | batchFallback |
| reactive | 3 | 3.337s | batchFallback |

The fallback path ran end to end and returned the complete sentence without
duplication or loss. The agreement probabilities produced zero confirmed words,
so this run validates fallback and final-text integrity, not the streamed-disposition path or the 2.5s first-confirmation target. `P7_TICK` records also
showed the first balanced tick at 5.516s including VAD startup, followed by
5-second rolling ticks at 3.071s and 3.696s. `P7_UPDATE` now logs the first
visible-update elapsed time for the next verified session. The probe also
exposed a safety issue where a no-text tick could advance the committed buffer
index; finalization now retains the full recording whenever no live segment was
successfully committed, preventing speech loss.
