# Phase 9 — Model roster and multilingual breadth

Date: 2026-09-11
Branch: `phase/9-model-roster-multilingual`

## Implementation

- Added verified FluidAudio roster entries:
  - SenseVoice Small (`sensevoice-small`, 472,467,765 bytes; 50+ language coverage).
  - Paraformer Large Chinese (`paraformer-large-zh`, 435,730,164 bytes).
  - Parakeet Japanese TDT (`parakeet-ja-0.6b`, 619,049,694 bytes).
  - Parakeet TDT-CTC 110M (`parakeet-tdt-ctc-110m`, 227,453,720 bytes).
- Sizes were calculated from the required pinned-checkout artifacts using
  Hugging Face `HEAD` responses on 2026-09-11.
- Extended `ParakeetEngine` to the pinned FluidAudio 0.15.5 `.tdtJa` and
  `.tdtCtc110m` model versions.
- Added local batch wrappers for `SenseVoiceManager` and
  `ParaformerManager`, including FluidAudio download/cache integration.
- Added `SenseVoicePostprocessor` at the ASR boundary. It strips the
  documented/observed forms `<|zh|>`, `<|NEUTRAL|>`, `<|Music|>`, `[BGM]`,
  `[Laughter]`, `[Applause]`, and `[Cough]`; it returns removed tags and has
  an explicit `keepTags` debug escape hatch.
- SenseVoice's pinned manager currently strips its control tokens internally;
  EchoTune still applies the postprocessor defensively before returning any
  result to dictionary processing, history, insertion, or memory mining.
- Added fixed-language metadata and one-time language defaults for Mandarin,
  Japanese, and the small English CTC model. Manual language changes are
  recorded as per-model overrides and are not clobbered on later selection.
- Model rows now show language coverage and byte-derived size.
- No launch-time network probe was added: FluidAudio's model downloader is the
  authoritative reachability check, and all new rows are marked experimental.
  This avoids adding four blocking catalog requests; installed models remain
  visible through the existing local-cache checks.

## Automated validation

- Debug build: passed.
- Full EchoTune unit suite after implementation: **96 tests passed**.
- Catalog backend and FluidAudio version mapping tests: passed.
- SenseVoice tag tests: passed, including observed tags, punctuation adjacency,
  tag-only input, whitespace collapse, and `keepTags`.
- Fixed-language default/override test: passed.

## Runtime probes

Runtime probes used macOS `say` fixtures and are therefore synthetic-TTS
proxies, not real microphone recordings. Model downloads are included in cold
load time; the model cache is local and generated artifacts are not committed.

| Model | Fixture | Cold load + decode | Result |
|---|---|---:|---|
| SenseVoice Small | English TTS | 161.008 s (first download) | Non-empty, but not an accuracy gate |
| SenseVoice Small | Mandarin TTS | 1.747 s warm load/decode | `请安排下周一上五十点的...`; near-match, 3-character edit distance / 33 = 9.1% CER against the TTS script |
| Paraformer Large zh | Mandarin TTS | 524.353 s cold; 70.234 s cached load/decode | Exact script text, no tags |
| Parakeet Japanese TDT | Japanese TTS | 152.538 s cold load/decode | Exact script text |
| Parakeet TDT-CTC 110M | English TTS | 131.477 s load; 0.078 s decode | Exact English script |

The SenseVoice Mandarin probe does **not** meet PRD-9's strict 3% CER
criterion on this synthetic fixture. The stronger Paraformer Mandarin path
meets the script probe exactly. The Japanese and 110M probes are successful.

The pinned FluidAudio checkout also documents its canonical AISHELL-1 result
for this exact CoreML model: **3.09% average CER over 7,176 samples**, versus
approximately 2.9% for upstream SenseVoice. This is a 0.09 percentage-point
miss against EchoTune's strict 3% target, not an implementation regression.
The vendor benchmark is retained as the broad accuracy evidence; EchoTune's
synthetic TTS probe is retained as a smoke/regression result. SenseVoice stays
explicitly experimental, while Paraformer is the recommended Mandarin model.
A human recording remains useful for product QA but is not available in this
environment.

One later cached SenseVoice benchmark was affected by the known Xcode test
runner bootstrap failure (`test runner hung before establishing connection`);
the successful 1.747-second probe above is retained as the valid runtime result.

## Gate status

Phase 9 is **complete with a documented accuracy exception**:

- roster, routing, download/cache handling, language defaults, UI metadata,
  postprocessing, automated tests, and runtime smoke probes are complete;
- Paraformer, Japanese Parakeet, and TDT-CTC 110M pass their available runtime
  probes;
- SenseVoice is shipped as opt-in/experimental because the canonical vendor
  AISHELL result is 3.09% CER and the local synthetic probe is 9.1% CER;
- no accuracy claim stronger than that evidence is made.

The Phase 9 decision is to keep SenseVoice in the additive roster, recommend
Paraformer for Mandarin, and preserve Whisper-auto as the fallback. Phase 10
may now start only as a separate phase; this exception must remain visible in
its planning and release notes.
