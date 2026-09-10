# Contributing to EchoTune

Thanks for your interest in improving EchoTune!

## Ground rules

- EchoTune is licensed under **GPL-3.0**. By contributing, you agree your
  contributions are licensed under the same terms.
- Do **not** paste code from other projects unless it is compatible with
  GPL-3.0 and properly attributed in `NOTICE.md`. EchoTune's dictation code was
  written from behavior specs specifically to keep provenance clean — please
  keep it that way.

## Getting set up

1. Requires Xcode (macOS 14 SDK or later).
2. Open `EchoTune.xcodeproj` and build the `EchoTune` scheme, or:
   ```sh
   xcodebuild -project EchoTune.xcodeproj -scheme EchoTune -configuration Debug build
   ```
   Dependencies resolve automatically via Swift Package Manager.

## Making changes

- Keep the build green: `Debug` must build before you open a PR.
- Match the surrounding SwiftUI style (system colors, `.secondary` labels,
  native controls).
- One focused change per pull request; describe what and why.
- If you change behavior a user can see, add a line to `CHANGELOG.md` under
  "Unreleased".

## Release checklist (maintainers)

Before `xcodebuild archive` for a release build, run:

```sh
./Scripts/bundle_default_model.sh
```

This populates the git-ignored `EchoTune/Resources/CompiledModels/` folder with the
default model's CoreML model bundles plus `compiled-manifest.json`, so the DMG carries
the verified artifacts needed by the bundled-model load path. The exact first-load
latency still depends on WhisperKit/CoreML device specialization; the app falls back
to normal loading when the manifest is absent or stale.

## Reporting bugs

Open an issue with steps to reproduce, your macOS version, and whether you're
using a local or cloud model. For security issues, see `SECURITY.md` instead.
