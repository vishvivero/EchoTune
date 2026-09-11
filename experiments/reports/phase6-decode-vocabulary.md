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
| Unit tests (`-only-testing:EchoTuneTests`) | PASS |
| Vocabulary/boundary tests | PASS |
| Whisper final-options compatibility tests | PASS |
| Parakeet context biasing | BLOCKED by pinned FluidAudio batch API |

No deployment performed.
