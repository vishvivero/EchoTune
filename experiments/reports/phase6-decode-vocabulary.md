# Phase 6 — Decode-time vocabulary

## Implemented

- Added `VocabularyBiasing` to collect:
  - enabled dictionary written forms;
  - enabled correct-spelling terms and their variations;
  - correction-learner suggestions after the existing three-strike threshold;
  - the fixed app term `EchoTune`.
- Deduplicates case/diacritic-insensitively while retaining the first user
  spelling.
- Adds language-aware ordering/filtering with a never-empty fallback.
- Encodes Whisper prompt terms with WhisperKit's pinned API:
  `whisperKit.tokenizer.encode(text:)`.
- Caps prompts at 224 tokens deterministically and logs trimming once.
- Injects prompts into the shared Whisper options builder for both live and
  final transcription. Translation passes remain unprompted.
- Added default-on `AppSettings.vocabularyBiasingEnabled` and a Settings row
  to disable it for regression comparisons.
- Preserved nil `promptTokens` when disabled or when the vocabulary is empty.
- Replaced `\\b` dictionary matching with explicit Unicode-aware lookarounds:
  `(?<![\\p{L}\\p{N}_])term(?![\\p{L}\\p{N}_])`.
- Added boundary coverage for substrings, `C++`, hyphenated terms, accented
  terms, and correct spellings.

## FluidAudio API finding / blocker

The pinned FluidAudio 0.15.5 checkout exposes:

```swift
SlidingWindowAsrManager.configureVocabularyBoosting(
    vocabulary: CustomVocabularyContext,
    ctcModels: CtcModels,
    config: VocabularyRescorer.Config? = nil
)
```

`CustomVocabularyTerm` supports `text`, `weight`, `aliases`, `tokenIds`, and
`ctcTokenIds`. However, EchoTune's Phase 5 batch engine intentionally uses
FluidAudio's direct `AsrManager` API for disk-backed long-audio transcription.
That public batch API has no vocabulary-context parameter. The context hook is
only on `SlidingWindowAsrManager` and requires an additional CTC model download
through `CtcModels.downloadAndLoad()`.

Per the packet's safety rule, Phase 6 does not guess token IDs, silently add a
second large CTC download, or change batch semantics to a streaming manager.
Parakeet therefore retains the word-boundary-safe post-hoc dictionary pass;
native Parakeet context biasing remains a follow-up once FluidAudio exposes a
supported batch hook or the product explicitly accepts the extra CTC model.

## Validation

| Gate | Result |
|---|---:|
| Debug build | PASS |
| Release build | PASS |
| Unit tests (`-only-testing:EchoTuneTests`) | PASS |
| Vocabulary/boundary tests | PASS |
| Whisper final-options compatibility tests | PASS |
| Parakeet context biasing | BLOCKED by pinned FluidAudio batch API |

## Runtime benchmark

The benchmark used WhisperKit 0.15.0 directly with the same compute units and
`DecodingOptions` shapes constructed by EchoTune. It compared prompt disabled
versus enabled using the four default dictionary terms plus `EchoTune`:
`by the way`, `for your information`, `as soon as possible`, and `EchoTune`.
The prompt contained 25 Whisper tokens. Model preparation was measured
separately and was not included in warm decode medians.

Target: arm64 MacBook Air, macOS 26.6.2. Fixture:
`synthetic-speech-12s.aiff` (12.124 seconds).

| Mode | Prompt off p50 | Prompt on p50 | Delta | Off RTFx | On RTFx |
|---|---:|---:|---:|---:|---:|
| Live, pinned language | 3.551s | 4.089s | +15.1% | 3.41x | 2.97x |
| Final, pinned language | 3.702s | 4.122s | +11.3% | 3.27x | 2.94x |

A focused first-4-second live-tick run showed a larger but still sub-tick
latency increase: 2.577s → 3.104s (+20.4%), with prompt-on p90 3.242s.
Tokenizer construction itself averaged only 0.148 ms per decode over 1,000
iterations, so the measured regression is decoder prompt-prefill work rather
than dictionary collection/tokenization. An eight-term stress prompt measured
+30.6% on the full fixture.

The prompt changed the synthetic fixture's normalization from `Echo to` to
`EchoTune`, which is the intended vocabulary effect. The truncated 4-second
fixture is not suitable for quality scoring because it ends mid-utterance.

As a Phase 5 regression check, the cached FluidAudio 0.15.5 Parakeet TDT v3
benchmark was rerun in a separate process: preparation 0.343s, five warm
transcription p50 0.093s, p90 0.093s, and 130.74x RTFx. The output remained the
same (`Echo to ...`), confirming that Phase 6 did not alter the Parakeet batch
path. This is a regression check, not a new Phase 5 acceptance benchmark.

## Benchmark scope decision

The benchmark should be extended for **Phase 6**, not reworked as a combined
Phase 5/6 benchmark. Phase 5's backend and model path are unchanged; retaining
one cached Parakeet smoke run is sufficient for regression coverage. The Phase
6 report should carry the Whisper on/off latency and parity measurements above.

The +15–20% default-vocabulary live cost is measurable but remains below the
4-second tick budget on this fixture. Before treating Phase 6 as fully closed,
repeat the comparison with at least one natural-speech fixture and decide
whether the product accepts that cost or needs prompt-size/decoder-path tuning.

No deployment performed.
