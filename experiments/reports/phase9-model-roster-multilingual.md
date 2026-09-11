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
A real human Mandarin recording remains required before claiming multilingual
accuracy acceptance; the SenseVoice result should remain experimental.

One later cached SenseVoice benchmark was affected by the known Xcode test
runner bootstrap failure (`test runner hung before establishing connection`);
the successful 1.747-second probe above is retained as the valid runtime result.

## Gate status

Implementation and automated gates are complete. Phase 9 is **not yet an
unqualified accuracy acceptance** because no real human Mandarin recording was
available and SenseVoice exceeded the 3% synthetic CER threshold. Paraformer,
Japanese Parakeet, and TDT-CTC 110M are runtime-verified. Keep SenseVoice
experimental and do not promote Phase 10 as a final release gate until the
Mandarin accuracy decision is recorded.
