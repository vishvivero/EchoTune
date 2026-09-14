# EchoTune 7.4.4 Commitment Agent Handoff

- Commitment detection is synchronous, local, finalized-source only, and confirmation-gated. Pending proposals are process-memory-only; dismiss and edit do not persist.
- Acceptance persists the edited task, person, context, due date, priority, bounded deterministic confidence, exact source sentence, and available Echo sourceEntryID. Duplicate pending/open proposals are suppressed.
- Historical backfill is intentionally side-effect free. Ordinary dictation and existing task search/completion/list controls remain unchanged.
- Changed implementation/tests: `EchoTune/AppCoordinator+Transcription.swift`, `EchoTune/Managers/CommitmentExtractor.swift`, `EchoTune/Managers/CommitmentMemoryManager.swift`, `EchoTune/Managers/EchoMemoryManager.swift`, `EchoTune/Models/Commitment.swift`, `EchoTune/Views/CommitmentsView.swift`, `EchoTune/Views/MainDashboardView.swift`, `EchoTune/Views/MenuBar/StatusBarController.swift`, and `EchoTuneTests/CommitmentMemoryTests.swift`.
- Validation: Debug app build succeeds with `xcodebuild -project EchoTune.xcodeproj -scheme EchoTune -configuration Debug -derivedDataPath /tmp/echotune-commit-debug CODE_SIGNING_ALLOWED=NO build`. Full test execution remains dependent on the repository's local CompiledModels prerequisite.
- Privacy review: the commitment path has no URLSession, provider, enhancement, Keychain, Contacts/EventKit, or external automation calls; cloud/unknown transcription providers fail closed.
- `EchoTune/Resources/CompiledModels/` is an ignored local build prerequisite and is not part of this change.
