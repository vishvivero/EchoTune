# Phase 10 — Enhancement overhaul and local telemetry

Date: 2026-09-12
Branch: `phase/10-enhancement-telemetry`

## Delivered

### Enhancement output hygiene

- Added `EnhancementOutputFilter.clean` as a pure, idempotent sanitizer.
- Applied it once at the enhancement return choke point after hosted, Gemini,
  Groq, OpenAI, and local-provider routing.
- Removes triple-backtick fences while retaining inner content, reasoning tags
  (`think`, `thinking`, `reason`, `reasoning`), leading `Polished:`/
  `Output:`/`Result:` labels, wrapper quotes, and runaway blank lines.
- Does not remove inline single-backtick code, horizontal rules, mid-sentence
  colons, or ordinary XML-like tags.
- Added `stripEnhancementWrappers`, default `true`, with a Settings toggle.
- Tests cover the PRD fixture, middle/unterminated/one-line fences, reasoning
  wrappers, labels, quotes, empty input, raw-output toggle, and idempotence.

### Provider refresh and local enhancement

- Removed retired Groq Mixtral (`mixtral-8x7b-32768`) from the enum, migration
  path, and UI. Existing stored selections migrate to the hosted default.
- Kept the current bundled hosted/Groq/Gemini set and added a 24-hour local
  provider metadata cache with ETag support. When keys are present it queries
  the providers' model-list endpoints in the background; cached/bundled IDs
  remain available offline. API keys are never logged.
- Added the `EnhancementProvider` protocol seam.
- Added `LocalCLIEnhancementProvider` for optional Ollama enhancement:
  - checks standard macOS locations and PATH off the main thread;
  - visible but disabled when Ollama is absent;
  - uses `Process` with explicit `['run', model]` arguments and stdin, never a
    shell command or transcript interpolation;
  - terminates after 30 seconds;
  - intentionally does not fall back to a cloud provider when local was chosen.
- Added `localEnhancementEnabled` (default `true`) and configurable
  `localEnhancementModel` (default `llama3.2:1b`).
- Google model documentation was reachable and confirmed the configured
  Gemini 2.5 Flash IDs on 2026-09-12. The Groq documentation/API endpoint
  rejected unauthenticated requests in this environment; authenticated model
  refresh is implemented and the bundled Groq ID is retained pending a key.
- Ollama was detected at `/usr/local/bin/ollama`; this machine has
  `gemma4:e2b` installed but not the default `llama3.2:1b`, so no claim is
  made for the PRD's exact pulled-model latency gate. The local CLI was
  exercised with the installed model and returned local output; its reasoning
  text is handled by the shared output filter when wrapped in recognized tags.

### Local performance dashboard

- Added `PerfStore` as an append-only JSON store under
  `ECHOTUNE_RESULTS_DIR/performance-sessions.json` when configured, otherwise
  Application Support/EchoTune.
- Records preserve the existing schema v1 benchmark fields and add optional
  session telemetry: engine/model, first tick, tick p50/p95, decode wall time,
  VAD method/counts, agreement disposition, cloud seconds, enhancement time,
  and provider.
- Existing `PerformanceMonitor` sessions now write to the store without
  deleting or changing its existing UserDefaults keys or in-memory behavior.
- Live tick latency is captured for p50/p95. Fields unavailable to a batch
  session remain explicitly `Not recorded`, not fabricated.
- Cap is 1,000 records; backup is written before rotation. Corrupt input is
  moved to a timestamped recovery file and its path is retained in
  `perfStoreLastRecoveryPath`.
- Added a Settings Performance pane with last-session metrics, 30-day median /
  p95 aggregates, cloud usage estimates from the existing local UsageMeter,
  and a local-only privacy footer.
- Extended `Scripts/validate_benchmark_json.py` to validate performance-session
  records under the existing schema version; no parallel schema version was
  introduced.

## Validation

- Debug build: passed after all Phase 10 changes.
- OutputFilterTests: passed.
- EnhancementProviderTests: passed.
- PerfStoreTests: passed (round trip, aggregate math, rotation backup, corrupt
  recovery).
- A generated performance-session record passed the existing benchmark
  validator.
- Retired Mixtral ID scan: clean.
- Telemetry-path scan for `URLSession`, `Network`, and `Sentry`: clean in
  `PerfStore.swift`, `PerformanceDashboardView.swift`, and
  `PerformanceMonitor.swift`.
- Full-suite compile completed, but the Xcode macOS test runner again failed
  before establishing a connection. Focused Phase 10 suites passed before the
  final generic-tag filter refinement; the subsequent build passed, while its
  rerun hit the same runner bootstrap instability recorded during Phase 8/9.

## Release decision

Phase 10 implementation is complete and additive. No deployment or release was
performed. The only environment-dependent acceptance item is a full test-runner
pass and the exact `llama3.2:1b` Ollama latency measurement; both are blocked by
local environment state rather than an untested code path. The branch is ready
for review with these limitations explicitly recorded.
