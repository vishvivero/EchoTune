# EchoTune Mind Graph — PRD & Implementation Plan

**Status:** Proposal · not yet scheduled
**Baseline:** `release/7.7-backlog` @ 7.7.16 (build 131)
**Owner:** Vish
**Author:** pi (coding), with product input from Vish

---

## 0. The one-sentence pitch

> EchoTune is the only dictation app that *remembers what you were working on* — and shows it to you as a living, clickable map of your own thinking, built entirely on your Mac, never leaving it.

Every competitor (superwhisper, VoiceInk, Wispr Flow, MacWhisper) treats a dictation as a disposable string: speak → insert → forget. EchoTune already captures something none of them do — **the transcript, the app it went into, and the window title, together**. The Mind Graph turns that triple into a product.

---

## 1. Why this, why now

### 1.1 What already exists (the 70%)

| Component | File | What it does today | Gap |
|---|---|---|---|
| `EchoMemoryEntry` | `Managers/EchoMemoryManager.swift` | Stores every transcript + `frontmostApp` + `windowTitle` + model + duration | ✅ the raw material is here |
| `EchoProfile.frequentTopics` | same | Bag-of-words with a 25-word stoplist, `prefix(5)` | ❌ surfaces "the", "i'm", "it's" as *interests* |
| `EchoCoachInsight` | same | One canned suggestion | ❌ not derived from content |
| `CommitmentExtractor` | `Managers/CommitmentExtractor.swift` | Regex-mined tasks, confirmation-gated | ✅ keep; feeds the graph |
| `CorrectionLearner` | `Managers/CorrectionLearner.swift` | Learns vocabulary from edits | ✅ keep; feeds entity resolution |
| `ClipboardHistoryManager` | `Managers/ClipboardHistoryManager.swift` (7.7.15) | In-memory clip timeline | ✅ second signal source |
| `EchoProfileView` | `Views/EchoProfileView.swift` | 177-line stats page | ❌ reads like a settings panel, not a brain |
| Persistence | `UserDefaults` JSON blob | Fine for 50 entries | ❌ will not survive 5,000 entries × 512-float embeddings |

**Verdict:** the data capture is correct and already shipping. Extraction is weak and the UI tells no story. We are not building memory from scratch — we are giving memory a brain and a face.

### 1.2 What the research said

Checked GitHub for reusable open source (Nov 2026):

| Repo | Stars | Fit | Takeaway |
|---|---|---|---|
| `mem0ai/mem0` | 69k | ❌ Python server + LLM calls | Their **"extract facts → dedupe → update"** loop is the right *shape* |
| `topoteretes/cognee` | 34k | ❌ Python platform | Entity/relation graph over text is the right *model* |
| `letta-ai/letta` | 26k | ❌ Stateful agent server | Core/archival memory split is a useful *concept* |
| `microsoft/graphrag` | 37k | ❌ Python RAG | Community detection over an entity graph — we can do a lite version |
| `basicmachines-co/basic-memory` | 4.7k | ⚠️ Closest in spirit | **Entities + Observations + Relations as plain records** — adopt this schema |
| Obsidian graph view | — | 🎯 UX reference | Force-directed, hover-to-highlight-neighbours, click-to-open, filter chips, local-graph mode |

**None of these ship inside a Swift menu-bar app.** They are infrastructure for agent builders. What we take is the *schema* (basic-memory) and the *interaction model* (Obsidian), and we build the engine on what every Mac already has.

### 1.3 The unfair advantage — Apple `NaturalLanguage`

Tested on this machine (macOS 26.6, deployment target 14.0 — all of this is available from macOS 14):

```
NLEmbedding.sentenceEmbedding(for: .english)   → 512-dim vectors, on-device
NLEmbedding.wordEmbedding(for: .english)       → 300-dim, neighbours()
NLTagger(.lemma)                               → "debugging" → "debug"
NLTagger(.nameType)                            → Person / Place / Organization
NLTokenizer(.sentence)                         → segmentation
```

Zero dependencies. Zero network. Zero model download. Sub-millisecond per sentence.

Combined with the `(transcript, app, windowTitle)` triple nobody else has, this means EchoTune can answer *"what was I doing in Cursor last Tuesday?"* with **no API key, no server, no Python** — which is a claim no competitor can make.

---

## 2. Goals & non-goals

### Goals

1. **Make memory real.** Replace bag-of-words with lemmatised, entity-aware, embedding-clustered themes. The profile should surface *"Payment webhook migration"*, not *"the"*.
2. **Give memory a face.** An Obsidian-class graph view where each node is a theme / project / person / app, edges are co-occurrence, size is weight, and everything is hoverable, clickable, filterable, and animated.
3. **Make it feel owned.** The user must be able to see every node, rename it, merge it, delete it, exclude an app, or nuke everything — in two clicks. If they can't manage it, it isn't theirs.
4. **Keep it local.** Nothing leaves the Mac without an explicit, per-feature opt-in. Phase 3's summariser defaults to the on-device Apple model from ET-762.
5. **Make it fast.** Graph of 500 nodes must hold 60 fps on an M1 Air. Extraction must never add latency to insertion.

### Non-goals (for v1)

- ❌ Cross-device sync (would require a server; contradicts goal 4)
- ❌ Full-text semantic search over *every* transcript (that is History; the graph is about *themes*)
- ❌ Automatic actions on the user's behalf (the Commitment agent already owns that, confirmation-gated)
- ❌ A chat interface ("talk to your memory") — tempting, but scope creep; Phase 3 digest is the cheap version
- ❌ Replacing Obsidian / Notion / Apple Notes — we are a *lens on your dictation*, not a PKM

---

## 3. User stories

| # | As a… | I want… | So that… | Phase |
|---|---|---|---|---|
| U1 | Daily dictator | my profile to show *real* topics, not stopwords | I trust the app knows me | 1 |
| U2 | Knowledge worker | to see a map of what I've been thinking about this month | I notice patterns I'd miss in a list | 2 |
| U3 | Developer | to click "Kubernetes" and see every dictation that touched it, in which app | I can reconstruct a thread of work | 2 |
| U4 | Privacy-conscious user | to see *exactly* what is remembered, and delete any of it | I'm never surprised by what the app knows | 2 |
| U5 | Manager | to exclude Slack and Mail from memory entirely | sensitive conversations never enter the graph | 2 |
| U6 | Anyone | to merge "k8s" and "Kubernetes" into one node | the graph reflects how *I* think, not a tokenizer | 2 |
| U7 | Weekly reviewer | a Monday digest: "last week you focused on X, Y, Z; three open commitments" | the graph produces something I act on | 3 |
| U8 | New user | the graph to look alive from the first 10 dictations | the feature doesn't feel empty for a month | 2 |

---

## 4. Architecture

### 4.1 Layering

```
┌─────────────────────────────────────────────────────────────┐
│  UI                                                          │
│  MindGraphView (Canvas + physics)  ·  NodeInspector          │
│  MindGraphFilterBar  ·  MindGraphDigestCard                  │
├─────────────────────────────────────────────────────────────┤
│  Query                                                       │
│  MindGraphQuery — neighbours(of:), timeline(for:), search()  │
├─────────────────────────────────────────────────────────────┤
│  Graph                                                       │
│  MindGraphBuilder — nodes, edges, weights, layout seeds      │
│  ThemeClusterer — k-means over sentence embeddings           │
├─────────────────────────────────────────────────────────────┤
│  Extraction                                                  │
│  MemoryExtractor — NLTagger lemma + NER + NLEmbedding        │
│  EntityResolver — merges aliases (k8s ≡ Kubernetes)          │
├─────────────────────────────────────────────────────────────┤
│  Store                                                       │
│  MindGraphStore — SQLite (GRDB-free, raw sqlite3)            │
│  tables: observation · entity · relation · embedding         │
├─────────────────────────────────────────────────────────────┤
│  Sources (existing, unchanged)                               │
│  EchoMemoryManager · ClipboardHistoryManager · Commitments   │
└─────────────────────────────────────────────────────────────┘
```

Each layer is a pure Swift type with no UI dependency, so Phases 1–2 are fully unit-testable without a window.

### 4.2 Data model (adopted from basic-memory, adapted)

```swift
/// One captured moment: a transcript or a clip, with its context.
struct Observation: Codable, Identifiable {
    let id: UUID
    let date: Date
    let kind: Kind                      // .dictation | .clipboard
    let text: String
    let appBundleID: String?            // "com.todesktop.230313mzl4w4u92" (Cursor)
    let appName: String?                // "Cursor"
    let windowTitle: String?            // "PaymentWebhook.swift — EchoTune"
    let sourceEntryID: UUID?            // back-pointer to EchoMemoryEntry / history
    var embedding: [Float]?             // 512-dim sentence embedding, computed lazily
    enum Kind: String, Codable { case dictation, clipboard }
}

/// A thing the user talks about. Promoted from extraction, user-editable.
struct Entity: Codable, Identifiable {
    let id: UUID
    var canonicalName: String           // "Kubernetes"
    var aliases: Set<String>            // ["k8s", "kubernetes", "kube"]
    var kind: Kind                      // .theme | .project | .person | .org | .place | .app
    var isPinned: Bool                  // user said "this matters"
    var isHidden: Bool                  // user said "stop showing this"
    var firstSeen: Date
    var lastSeen: Date
    var observationCount: Int           // denormalised for sort/size
    enum Kind: String, Codable { case theme, project, person, org, place, app }
}

/// Entity ↔ Observation membership, and Entity ↔ Entity co-occurrence.
struct Relation: Codable, Identifiable {
    let id: UUID
    let fromEntityID: UUID
    let toEntityID: UUID?               // nil ⇒ relation is to an observation
    let observationID: UUID?
    var weight: Double                  // co-occurrence count, time-decayed
    var lastReinforced: Date
}
```

**Why not SwiftData / CoreData?** Both are fine, but the codebase has neither, and the graph needs one thing they are bad at: **vector similarity over 512-float columns**. Raw `sqlite3` with a BLOB column and in-memory cosine scan is simpler, faster to ship, and matches the "no new frameworks" posture. At 5,000 observations × 512 floats = 10 MB, an in-memory scan is ~2 ms. We do not need an ANN index until ~100k observations, which is years of dictation.

**Storage location:** `~/Library/Application Support/EchoTune/mindgraph.sqlite`, `0600`, excluded from Time Machine? **No** — the user's memory should be backed up; it is their data. But it must be **excluded from iCloud** (`NSURLIsExcludedFromBackupKey` is for iOS; on macOS we simply never put it in a synced folder).

### 4.3 Extraction pipeline (Phase 1)

Runs **off the insertion path**, on a `.utility` queue, debounced 2 s after the last dictation so a burst of three short dictations is processed once.

```
Observation.text
  │
  ├─► NLTokenizer(.sentence)        ─► sentences[]
  │
  ├─► NLTagger(.lemma)              ─► lemmas[]  (drop stop-lemmas: ~180-word list, not 25)
  │
  ├─► NLTagger(.nameType)           ─► people[], orgs[], places[]
  │
  ├─► Capitalised-run heuristic     ─► product names: "EchoTune", "AppIntents", "WhisperKit"
  │     (NER misses tech nouns; PhoneticVocabularyMatcher's dictionary is a seed list)
  │
  ├─► NLEmbedding.sentence          ─► embedding[512]  (store on Observation)
  │
  └─► EntityResolver.resolve(lemmas + entities + products)
        │
        ├─ exact alias match        ─► existing Entity
        ├─ word-embedding neighbour ─► existing Entity (cos > 0.82)
        ├─ user merge table         ─► existing Entity
        └─ otherwise                ─► new Entity(kind: inferred)
```

**Entity kind inference:**
- NER tag `.personalName` → `.person`
- NER `.organizationName` → `.org`
- NER `.placeName` → `.place`
- `appName` from the observation → `.app` (always created; one node per app ever dictated into)
- Capitalised run matching a dictionary term → `.project`
- Everything else surviving the stop-lemma filter with count ≥ 2 → `.theme`

**Themes are the hard part.** A raw lemma like "ship" is noise; a cluster of embeddings around "ship / deploy / release / Friday" is a theme. So:

```
ThemeClusterer
  input:  all Observation.embedding (last 90 days by default)
  method: k-means, k = clamp(sqrt(n/2), 3, 24), 20 iterations, cosine
  label:  top-3 TF-IDF lemmas across the cluster's observations
  output: [Entity(kind: .theme)] + Relation(observation ∈ cluster)
  rerun:  nightly, or on demand from the inspector
```

Cluster labels are the one place extraction can look stupid ("project / thing / stuff"). Mitigation: label = top TF-IDF lemmas **that are also nouns** (`NLTagger(.lexicalClass)`), and the user can rename any theme (U6).

### 4.4 Relation weighting & decay

```
weight(e1, e2) = Σ over observations containing both:  1.0 × decay(age)
decay(age)     = 0.5 ^ (age_days / 45)      // half-life 45 days
```

So a theme you dictated about daily last month and never since fades to the edge of the graph but never vanishes. Pinned entities (`isPinned`) get `decay = 1.0`.

Edges below `weight < 0.15` are **not drawn** but **are stored**, so a theme can re-ignite without losing history.

### 4.5 Privacy architecture (non-negotiable)

This feature changes EchoTune's privacy story from *"transcripts stored locally"* to *"we build a model of what you work on"*. That must be honest and controllable:

| Control | Where | Default |
|---|---|---|
| **Master switch** "Build my Mind Graph" | Settings → Privacy | **OFF** for existing users, ON-by-choice in onboarding for new users |
| **App exclusions** — never observe these apps | Settings → Privacy | Password managers pre-excluded (reuse `ClipboardHistoryManager.excludedBundleIdentifiers`); user adds Slack/Mail/etc. |
| **Clipboard contribution** | Settings → Privacy | OFF (dictation only) |
| **"What do you know about me?"** | Dashboard → Mind | Full node list, every observation, every alias — nothing hidden |
| **Forget this** | Node inspector | Deletes entity + its relations; observations survive unless also deleted |
| **Forget everything** | Settings → Privacy | Drops `mindgraph.sqlite`; hooks into existing *Erase All Local Data* |
| **Retention** | Settings → Privacy | 90 / 180 / 365 / forever; default 365 |
| **Export** | Settings → General | JSON of the whole graph; hooks into ET-764 backup (**excluded from the portable setup backup** by default — a brain is not a setting) |
| **Telemetry** | — | **None.** No Sentry breadcrumbs may contain entity names. Add a unit test that greps for it, like `releaseUnifiedLogsNeverContainRawTranscriptBodies`. |

`PrivacyInfo.xcprivacy` currently declares `NSPrivacyCollectedDataTypes = []`. That stays true — nothing is *collected* by us — but the App Store privacy label copy and the in-app Privacy page must describe on-device profiling plainly.

---

## 5. The graph view — Obsidian-class UI spec

This is the feature's face. It is also the most expensive line item, so the spec is precise.

### 5.1 Placement

- New `NavigationItem.mind = "Mind"` in the Dashboard sidebar, icon `brain.head.profile`, between **Home** and **History**.
- `EchoProfileView` (current 177-line stats page) becomes the **Inspector sidebar** of the Mind view rather than a separate window. `showEchoProfile()` in `AppDelegate` opens `showDashboard(item: .mind)`.
- Menu bar: **Echo Profile** item relabelled **Mind Graph**, same selector.
- A compact "Mind" card (top 5 nodes, mini-graph thumbnail) on **Home**, beside the ET-763 heatmap, that deep-links into the full view (U8 — visible early).

### 5.2 Layout — the canvas

```
┌──────────────────────────────────────────────────────────────────────┐
│ [ Search nodes…      ]  [All ▾][Themes][Projects][People][Apps]  ⚙  │ ← filter bar
├──────────────────────────────────────────────┬───────────────────────┤
│                                              │  Kubernetes           │
│         ·  ·                                 │  theme · 14 dictations│
│      ·   (Cursor)──────(Kubernetes)          │  first  3 Nov         │
│    ·       │   \          /    \             │  last   today         │
│          (EchoTune)   (Deploy) (Helm)        │  ─────────────────    │
│             │              │                 │  Also appears with    │
│          (Vish)·        (Friday)             │   • Cursor      11    │
│                                              │   • EchoTune     6    │
│   · = faded (decayed) node                   │   • Deploy       5    │
│                                              │  ─────────────────    │
│                                              │  Recent              │
│                                              │   "deploy the helm…"  │
│                                              │   "k8s cluster is…"   │
│                                              │  ─────────────────    │
│                                              │  [Rename] [Merge]     │
│                                              │  [Pin]  [Forget]      │
├──────────────────────────────────────────────┴───────────────────────┤
│ ◀ 30d ▶  ━━━━━━━━●━━━━━━━━  Last 90 days          Local graph ◯ Full│ ← time scrubber
└──────────────────────────────────────────────────────────────────────┘
```

### 5.3 Rendering

**Technology: SwiftUI `Canvas` inside `TimelineView(.animation)`** — the exact pattern `AuroraBackgroundView` already uses, so it is proven in this codebase and needs no new framework.

Rejected alternatives:
- *SpriteKit* — good physics, but a `SKView` inside SwiftUI fights the Dashboard's layout and dark-mode; and we only need springs.
- *Metal* — overkill below ~5,000 nodes.
- *SwiftUI views per node* — dies at ~150 nodes; `Canvas` draws 1,000 circles + 3,000 lines per frame comfortably.

Draw order per frame: edges (alpha by weight) → faded nodes → active nodes → labels (only for nodes with `radius ≥ 8pt` or hovered/selected/pinned) → selection ring → hover halo.

### 5.4 Physics — force-directed layout

Implemented as a pure `struct ForceLayout` (testable), stepped once per frame:

| Force | Formula | Purpose |
|---|---|---|
| Repulsion (all pairs) | `F = k² / d`, Barnes–Hut quadtree above 300 nodes | nodes spread |
| Spring (edges) | `F = (d − L) / L × weight` | related nodes cluster |
| Gravity (to centre) | `F = 0.05 × d_to_centre` | graph doesn't drift off-canvas |
| Damping | `v ×= 0.85` | settles in ~2 s |
| Kind-cluster | weak spring to a per-kind anchor | apps drift to the rim, themes to the middle |

**Settling:** layout runs at 60 fps while `Σ|v| > ε`, then drops to 0 fps (the `TimelineView` pauses). Dragging a node re-heats it. This is what makes it feel *alive* on open and *calm* once read.

**Seeded positions:** on first open, nodes start at their previous saved position (`Entity.layoutX/Y`, persisted) so the graph does not re-shuffle every time — Obsidian gets this wrong and it is the #1 complaint.

### 5.5 Interactions (all with 150–250 ms eased animation)

| Action | Result |
|---|---|
| **Hover node** | Node and its 1-hop neighbours brighten; everything else drops to 25% alpha; edge labels appear on hovered edges; inspector shows a preview (not selection) |
| **Click node** | Selects; inspector pins to it; node gets accent ring; camera eases to centre it *only if off-screen* |
| **Double-click node** | Enters **Local graph** mode — only this node + 2 hops, re-laid out; breadcrumb to go back |
| **Drag node** | Moves it; physics re-heats; position persists on release |
| **Scroll / pinch** | Zoom 0.25×–4×, cursor-anchored; labels appear/disappear by zoom level |
| **Drag canvas** | Pan |
| **⌘F / click search** | Filters nodes by name/alias; non-matches fade; first match selected on ⏎ |
| **Filter chips** | Toggle kinds; combinable; state persisted |
| **Time scrubber** | Drag to see the graph *as of* that date — nodes not yet seen vanish, decayed weights recompute; this is the "watch your month unfold" moment |
| **Right-click node** | Rename · Merge into… · Pin · Hide · Forget · Open in History |
| **Click observation in inspector** | Opens History filtered to that transcript |
| **Space** | Re-heat layout ("shuffle") |
| **⌘0** | Fit to view |

### 5.6 Visual language

- **Node radius** = `6 + 10 × log10(1 + observationCount)`, capped at 28 pt
- **Node colour** by kind: theme = accent, project = teal, person = orange, org = purple, place = green, app = grey (uses the app's icon at ≥ 18 pt radius via `NSWorkspace.icon(forFile:)`)
- **Decayed nodes** (`weight < 0.3`) render at 35% alpha with no label until hovered — present but quiet
- **Pinned** nodes get a thin gold ring
- **Edges** stroke width `0.5 + 2 × weight`, alpha `0.15 + 0.6 × weight`
- Dark mode is first-class; the Dashboard is already dark-mode aware

### 5.7 Empty & sparse states (U8)

| Observations | Experience |
|---|---|
| 0 | Illustrated empty state: *"Your Mind Graph builds itself as you dictate. Hold ⌥Space to add your first thought."* + the aurora background from onboarding, so it still looks alive |
| 1–9 | Graph renders with what exists; a subtle *"\(n) more dictations until themes appear"* caption; app nodes alone already make a small constellation |
| 10+ | Full experience; first clustering run happens at 10 |

---

## 6. Phased delivery

### Phase 1 — Real extraction (≈ 1 day)

**Goal:** `EchoProfile` becomes trustworthy; nothing new in the UI beyond better words.

| # | Work | Files | Test |
|---|---|---|---|
| 1.1 | `MemoryExtractor` — lemma + NER + capitalised-run + 180-word stop-lemma list | `Managers/Mind/MemoryExtractor.swift` (new) | 12 cases: lemma collapse, NER tags, "EchoTune" survives, "the" dies |
| 1.2 | `EntityResolver` — alias table + word-embedding neighbour merge | `Managers/Mind/EntityResolver.swift` (new) | "k8s"/"Kubernetes"/"kube" → one; "Apple" (org) ≠ "apple" (fruit) stays split |
| 1.3 | Replace `updateProfile()` bag-of-words with extractor output | `Managers/EchoMemoryManager.swift` | profile on fixture corpus names ≥ 4 real topics, 0 stopwords |
| 1.4 | Compute + store sentence embedding per `EchoMemoryEntry` (new optional field, Codable-compatible) | same | round-trip survives decode of old blobs without the field |
| 1.5 | Off-path: debounce 2 s, `.utility` QoS, never touches insertion latency | `AppCoordinator+Transcription.swift` | timing test: `processTranscription` unchanged ±1 ms |

**Ship as 7.8.0.** Zero privacy posture change — same data, better words.

### Phase 2 — Mind Graph (≈ 4–6 days)

**Goal:** the Obsidian-class view, the inspector, the controls. This is the feature.

| # | Work | Files | Test |
|---|---|---|---|
| 2.1 | `MindGraphStore` — SQLite schema, migrations, CRUD, cosine scan | `Managers/Mind/MindGraphStore.swift` (new) | insert 5k obs, query neighbours < 5 ms; migration from `EchoMemoryEntry` blob |
| 2.2 | `ThemeClusterer` — k-means over embeddings, TF-IDF noun labels | `Managers/Mind/ThemeClusterer.swift` (new) | 40-sentence fixture → 3 clusters with sensible labels; deterministic with seed |
| 2.3 | `MindGraphBuilder` — nodes/edges/weights/decay from store | `Managers/Mind/MindGraphBuilder.swift` (new) | decay half-life; pinned exempt; sub-threshold edges stored not drawn |
| 2.4 | `ForceLayout` — pure struct, Barnes–Hut above 300 | `Views/Mind/ForceLayout.swift` (new) | settles in < 200 steps; 500 nodes step < 4 ms |
| 2.5 | `MindGraphView` — Canvas + TimelineView, hit-testing, camera | `Views/Mind/MindGraphView.swift` (new) | manual + snapshot of a seeded fixture |
| 2.6 | `MindGraphInspector` — right panel; absorbs `EchoProfileView` | `Views/Mind/MindGraphInspector.swift` (new) | — |
| 2.7 | Filter bar, search, time scrubber, local-graph mode | `Views/Mind/MindGraphChrome.swift` (new) | scrubber filters by `firstSeen` |
| 2.8 | Context menu: rename / merge / pin / hide / forget | inspector + store | merge is transitive; forget removes relations, keeps observations |
| 2.9 | `NavigationItem.mind`, Home mini-card, menu bar relabel | `MainDashboardView.swift`, `HomeContentView.swift`, `StatusBarController.swift` | `MenuBarWiringTests` still green |
| 2.10 | Privacy: master switch (default OFF for upgraders), app exclusions, clipboard opt-in, retention, forget-everything, export | `Models/AppSettings.swift`, `Views/Settings/SettingsCompositeViews.swift` | exclusions honoured; forget-everything drops the file; no entity name in any log line |
| 2.11 | Onboarding step for new users: one screen, one toggle, honest copy | `Views/Onboarding/` | UI test |

**Ship as 7.9.0.** This is the marketing moment.

### Phase 3 — Digest (≈ 1–2 days, optional)

**Goal:** the graph produces something you act on.

| # | Work | Notes |
|---|---|---|
| 3.1 | `MindDigestBuilder` — deterministic summary: top themes by Δweight, new entities, open commitments, busiest app | No LLM required; this alone is useful |
| 3.2 | Optional LLM polish via `OnDeviceRefinementProvider` (ET-762) → fallback custom endpoint (ET-766) → **never** hosted by default | Prompt receives the *digest*, never raw transcripts |
| 3.3 | Monday 9 am local notification (user-scheduled), digest card on Home, `WeeklyDigestIntent` for Shortcuts | Reuses ET-769 intent plumbing |

**Ship as 7.9.1.**

---

## 7. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Cluster labels look dumb ("thing / stuff / work") | High | Users distrust the whole feature | Noun-only TF-IDF labels; min cluster size 4; rename is one click; show the top 3 observations under the label so the *meaning* is visible even when the label is weak |
| NER misses tech nouns ("Kubernetes" is not a Place) | Certain | Projects don't appear | Capitalised-run heuristic + `DictionaryManager.correctSpellings` + `CorrectionLearner` as seed vocabularies |
| `UserDefaults` blob corrupts at scale | Medium | Data loss | Phase 2 migrates to SQLite with the existing `memoryUnreadableKey` recovery pattern kept; `EchoMemoryRecoveryTests` extended |
| Graph is empty for weeks | High for new users | Feature feels broken | App nodes alone form a constellation from dictation #1; sparse-state captions; Home mini-card seeds curiosity |
| Performance on Intel / 8 GB | Medium | Jank | Barnes–Hut; label culling; physics pauses when settled; 500-node budget tested on CI's slowest target |
| Privacy backlash ("it profiles me") | Medium | Reputational | OFF by default for upgraders; full "what do you know" transparency; one-click forget; honest copy; no telemetry — enforced by test |
| Window-title capture reads as surveillance | Medium | Same | Already captured today; surface it in the inspector *as the user's own data*, with the app exclusion list front and centre |
| Scope creep into "chat with your memory" | High | Never ships | Non-goal in v1; Phase 3 digest is the bounded version |

---

## 8. Success metrics (local, opt-in, aggregated — never per-user)

Because telemetry is off, these are **self-reported via the existing Help & Feedback form** plus in-app counters shown only to the user:

- Mind view opened ≥ 1×/week by ≥ 40% of active users (counter in `UsageStatistics`, shown on Home)
- Median time-to-first-rename < 3 sessions (shows the user *engaged* with the graph as theirs)
- < 5% of users flip the master switch off after enabling it
- Zero privacy-related support tickets citing surprise

---

## 9. Open questions for Vish

1. **Default for upgraders** — I've specified OFF. The alternative (ON, with a "we started building your Mind Graph" notice) gets adoption but risks the surveillance reaction. Which?
2. **Clipboard contribution** — I've specified OFF by default. Clips are higher-signal than dictation for "what are you working on" but far more sensitive (URLs, snippets, passwords despite exclusions). Your call.
3. **Name** — "Mind Graph" / "Echo Mind" / "Brain" / "Threads". "Mind" is in the nav; final name affects onboarding copy.
4. **Phase 3 scope** — ship 3.1 (deterministic digest) with Phase 2 and defer the LLM step? It's cheap and makes Phase 2 feel complete.
5. **Should the graph be visible in the menu bar card?** A 120×80 thumbnail on Overview is tempting. I'd say no for v1 — it competes with the pipeline summary — but it's a 1-day add later.

---

## 10. Definition of done

- [ ] All Phase 1–2 tests green; full suite stays deterministic (3 consecutive runs)
- [ ] 500-node seeded graph holds 60 fps on M1 Air, 30 fps on 2019 Intel i5
- [ ] A new user sees a non-empty graph after dictation #1 (app node)
- [ ] Every node can be renamed, merged, pinned, hidden, forgotten from the inspector
- [ ] "Forget everything" leaves `~/Library/Application Support/EchoTune/mindgraph.sqlite` absent
- [ ] A test asserts no `os_log` / Sentry line contains any entity canonical name
- [ ] Privacy settings page describes on-device profiling in plain language, reviewed by Vish
- [ ] CHANGELOG, in-app Help page, and website `docs/` updated
- [ ] Signed, notarized, installed, menu bar + red ✕ verified (the usual gate)
