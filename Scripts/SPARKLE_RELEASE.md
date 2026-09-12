# Sparkle release procedure

EchoTune uses Sparkle 2.9.6 for signed direct-download updates.

## App configuration

- Feed: `https://echotune.app/appcast.xml`
- Feed key: `SUPublicEDKey` is supplied from the `SPARKLE_PUBLIC_ED_KEY` build
  setting and is intentionally not committed.
- Automatic checks: enabled by default, scheduled every 24 hours.
- Users can also choose **EchoTune → Check for Updates…** or the About/License
  settings panel.

## One-time signing setup

Run Sparkle's `generate_keys` with an organization-specific account on a
secure release machine. Store the private key in the macOS Keychain or CI
secret storage. Commit only the printed public key; never commit or log the
private key.

The release build must receive the public key:

```bash
xcodebuild -project EchoTune.xcodeproj -scheme EchoTune \
  -configuration Release \
  SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
  archive
```

The current project default is intentionally empty, so a release build cannot
silently pretend that signed updates are configured. The distribution pipeline
must provide the real public key before publishing an update feed.

## Publishing an update

1. Build and sign/notarize the direct-download app with the same Developer ID
   identity used for the existing release.
2. Use Sparkle's `generate_appcast` with the release archive and the signing
   key held by the release machine. Do not hand-edit the generated signature.
3. Upload the archive and generated `appcast.xml` to `echotune.app`.
4. Verify the appcast is reachable over HTTPS and that the enclosure contains:
   - a strictly higher `sparkle:version`;
   - a valid `sparkle:edSignature`;
   - the correct archive URL and byte length;
   - the minimum system version (`14.0`).
5. Test from an installed 7.4.2 build: open **Check for Updates…**, verify the
   signed update is offered, and complete installation on a clean test account.

Sparkle applies its own signature verification and installer flow. EchoTune
never opens a feed-supplied download URL directly when Sparkle is available.
