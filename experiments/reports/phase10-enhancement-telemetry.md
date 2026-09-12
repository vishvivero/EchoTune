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
- Ollama was detected at `/usr/local/bin/ollama`, and the default
  `llama3.2:1b` model was pulled so the PRD's exact-model latency gate could be
  measured rather than inferred. `LocalCLIEnhancementProvider` completed a real
  polish round trip with `llama3.2:1b` in **2.087s** (and with the previously
  installed `gemma4:e2b` in **4.347s**). A small model therefore meets the
  interactive budget comfortably on this machine.
- The provider boundary now applies `EnhancementOutputFilter.clean` itself, as
  P10.2 requires, honoring the same `stripEnhancementWrappers` toggle. Because
  `clean` is idempotent, the engine's later pass is a no-op; the guarantee is
  now held at both boundaries rather than relying on the engine alone.
- `LocalCLIEnhancementProvider` gained injectable `executablePath`, `timeout`,
  and `stripsWrappers` inputs plus a `modelName` accessor. These exist so the
  timeout, failure, and filtering paths can be tested with stub executables
  instead of only against a live model.

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
- OutputFilterTests: passed (7 tests).
- EnhancementProviderTests: 9 tests passed, including four new stub-backed
  tests covering the provider boundary: wrapper filtering, the raw-output
  toggle, clean timeout termination, and failure surfaced as `processFailed`
  with no cloud fallback.
- PerfStoreTests: passed (round trip, aggregate math, rotation backup, corrupt
  recovery).
- A generated performance-session record passed the existing benchmark
  validator.
- Validator regression check: nine malformed records (wrong schema version,
  missing field, wrong type, negative duration, zero fixture duration,
  negative `decodeMs`, missing `decodeMs`, negative optional metric) were all
  rejected, while a valid runtime record and a valid performance-session
  record (including explicitly null optional metrics) were accepted. The
  Phase 10 validator diff versus its pre-Phase 10 form is the additive
  `performanceSession` branch only; no existing check was weakened or removed.
- Retired Mixtral ID scan across `EchoTune/` and `EchoTuneTests/`: clean.
- Telemetry-path scan for `URLSession`, `Sentry`, `Network.`, and
  `NWConnection` in `PerfStore.swift`, `PerformanceDashboardView.swift`, and
  `PerformanceMonitor.swift`: clean.
- Final full EchoTuneTests run: **127 passed, 0 failed, 2 skipped**
  (`xcresulttool`: `totalTestCount=129`, result `Passed`, failures `[]`). The
  two skips are the opt-in Phase 9 multilingual model benchmark and the opt-in
  Ollama runtime test, both default-off by design.
- Real Ollama runtime gate: passed with the PRD's default `llama3.2:1b` in
  **2.087s** (and with `gemma4:e2b` in **4.347s**).
- The run emitted known macOS `com.apple.linkd.autoShortcut` diagnostic
  warnings, but the test runner established successfully and all selected
  tests completed.
- Runner stability: a reused derived-data path reproduced the known
  `The test runner hung before establishing connection` bootstrap hang, while
  a fresh derived-data path ran the same tests to completion. This is an
  environment characteristic of the Xcode macOS runner, not a test or product
  failure; the compile itself was confirmed separately with
  `build-for-testing` (`TEST BUILD SUCCEEDED`).

## Release decision

Phase 10 implementation is complete and additive. No deployment or release was
performed. Both previously recorded environment-dependent acceptance items are
now closed: the full suite passes on a fresh derived-data path, and the PRD's
`llama3.2:1b` local-model latency was measured directly. The branch is ready
for review.
