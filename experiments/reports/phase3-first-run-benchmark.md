# Phase 3 first-run model benchmark

**Date:** 2026-09-10
**Branch:** `phase/3-first-run-model-experience`
**Host:** Apple M4, 16 GB, macOS 26.6.2
**WhisperKit:** 0.15.0 exact
**Model:** `openai_whisper-large-v3-v20240930_turbo_632MB` / app id `openai_whisper-large-v3-v20240930_turbo`

## What was measured

The external harness at `/Users/yashna/echotune-bench` created a fresh temporary model directory for each process, copied only `config.json` and `generation_config.json`, linked the cached tokenizer, and supplied the four model bundles from the Release app's:

```
Contents/Resources/CompiledModels/
```

It then timed `WhisperKit(modelFolder:..., computeOptions: cpuAndGPU, load: true, download: false)` in a new process. The generated Release resource folder is 616 MB and contains the four `.mlmodelc` bundles plus `compiled-manifest.json`.

## Results

### Bundled-model path (five fresh processes)

| Run | Load time |
|---:|---:|
| 1 | 28.561 s |
| 2 | 29.712 s |
| 3 | 31.109 s |
| 4 | 32.812 s |
| 5 | 33.427 s |

**Median:** 31.109 s
**Range:** 28.561–33.427 s

### Direct installed-model path (five fresh processes)

| Run | Load time |
|---:|---:|
| 1 | 27.180 s |
| 2 | 3.002 s |
| 3 | 5.262 s |
| 4 | 6.013 s |
| 5 | 2.576 s |

The direct path is not a clean pre/post control: CoreML's process/system caches make later runs much faster. It is included to show the cache effect, not as an A/B claim.

## Interpretation

The resource and load-path implementation is functioning, but this run does **not** validate the PRD target of `<10 s` first load. The available model directory contains top-level `.mlmodelc` bundles, not the original `.mlpackage` artifacts or a separate device-specialized compiled set. WhisperKit 0.15.0 calls `MLModel.load(contentsOf:configuration:)` on the top-level bundles; the remaining first-process cost appears to be CoreML/device specialization and is not eliminated by shipping these same `.mlmodelc` packages.

Therefore:

- Phase 3 code/resource/download hardening is implemented and tested.
- The measured first bundled load is ~31.1 s, not <10 s.
- No speedup claim is made.
- A clean acceptance run requires a separately produced device-specialized artifact (or a confirmed WhisperKit/CoreML supported offline precompilation workflow) and a clean model/cache environment.

## Reproduction

```sh
cd /Users/zac/.openclaw/workspace/worktrees/echotune-phase3-firstrun
./Scripts/bundle_default_model.sh \
  --model-id openai_whisper-large-v3-v20240930_turbo \
  --model-folder "$HOME/Library/Application Support/EchoTune/WhisperModels/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_turbo_632MB"
xcodebuild -project EchoTune.xcodeproj -scheme EchoTune \
  -configuration Release \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/EchoTune-phase3-fixed" \
  build CODE_SIGNING_ALLOWED=NO
cd /Users/yashna/echotune-bench
swift build -c release
.build/release/echotune-bench
```

The harness source is external to the EchoTune repository and is not part of the product source tree. Its prior Phase 2 source is retained as `main.swift.phase2-before-phase3`.
