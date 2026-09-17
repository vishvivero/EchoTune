#!/bin/bash
#
# release_direct.sh — sign, notarize, staple and package the direct-download build.
#
# WHY THIS EXISTS
#   EchoTune 7.4.5 shipped without any code-signing entitlements because the
#   built app was re-signed by hand with `--options runtime` but WITHOUT
#   `--entitlements`. Under hardened runtime macOS then refuses to show the
#   microphone prompt (kTCCServiceMicrophone requires
#   com.apple.security.device.audio-input), so dictation was dead on arrival.
#
#   Never hand-sign a release. Use this script; it fails loudly if the
#   entitlements are missing before anything is notarized.
#
# USAGE
#   Scripts/release_direct.sh <version> [app-path]
#     version   e.g. 7.4.6            (must match CFBundleShortVersionString)
#     app-path  defaults to the newest EchoTune.app under build/archives/
#
set -euo pipefail

VERSION="${1:?usage: release_direct.sh <version> [app-path]}"
IDENTITY="Developer ID Application: VISHNU RAJ (VYPVWG69P8)"
NOTARY_PROFILE="${NOTARY_PROFILE:-echotune-notary}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="$ROOT/EchoTune/EchoTune.entitlements"
OUT="$ROOT/build/release-$VERSION"

find_app() {
  if [ -n "${2:-}" ]; then echo "$2"; return; fi
  local newest
  newest=$(find "$ROOT/build/archives" -name 'EchoTune.app' -path '*Products/Applications*' \
             -exec stat -f '%m %N' {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  [ -n "$newest" ] || { echo "error: no archived EchoTune.app found" >&2; exit 1; }
  echo "$newest"
}

APP_SOURCE="$(find_app "$VERSION" "${2:-}")"
[ -f "$ENTITLEMENTS" ] || { echo "error: $ENTITLEMENTS not found" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"
APP="$OUT/EchoTune.app"
echo "==> staging $APP_SOURCE"
ditto "$APP_SOURCE" "$APP"

# --- version sanity -----------------------------------------------------------
SHORT=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[ "$SHORT" = "$VERSION" ] || { echo "error: app is $SHORT, expected $VERSION" >&2; exit 1; }

# --- sign nested code first, deepest-first -----------------------------------
# A Developer ID distribution build must re-sign every nested Mach-O and bundle.
# The Xcode archive's Sparkle/Sentry helpers are signed with the local
# "Apple Development" identity, which notarization rejects outright
# ("not signed with a valid Developer ID certificate" / "no secure timestamp").
# Sign innermost first, or each outer signature is invalidated by the next.
sign_path() {
  [ -e "$1" ] || return 0
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$1"
}

echo "==> signing nested frameworks and helpers"
SPARKLE_B="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign_path "$SPARKLE_B/Autoupdate"
sign_path "$SPARKLE_B/XPCServices/Downloader.xpc"
sign_path "$SPARKLE_B/XPCServices/Installer.xpc"
sign_path "$SPARKLE_B/Updater.app"
sign_path "$APP/Contents/Frameworks/Sparkle.framework"
sign_path "$APP/Contents/Frameworks/Sentry.framework"
for extra in "$APP/Contents/Frameworks"/*.framework "$APP/Contents/Frameworks"/*.dylib; do
  [ -e "$extra" ] || continue
  case "$extra" in *Sparkle.framework|*Sentry.framework) continue ;; esac
  sign_path "$extra"
done

# --- sign the app itself WITH entitlements (the whole point of this script) ---
echo "==> signing app with entitlements"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"

if ! codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q 'com.apple.security.device.audio-input'; then
  echo "error: com.apple.security.device.audio-input missing from signature — refusing to ship" >&2
  echo "       (this is exactly the 7.4.5 bug; the app would be denied microphone access)" >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=1 "$APP"

# --- pre-flight: every Mach-O must carry a Developer ID signature + timestamp -
# Cheaper than a failed notarization round-trip.
echo "==> pre-flight signature audit"
bad=0
while IFS= read -r -d '' candidate; do
  file -b "$candidate" | grep -q 'Mach-O' || continue
  info=$(codesign -dvv "$candidate" 2>&1 || true)
  if ! grep -q 'Developer ID Application' <<<"$info"; then
    echo "error: not Developer ID signed: ${candidate#$APP/}" >&2; bad=1
  fi
  if ! grep -q '^Timestamp=' <<<"$info"; then
    echo "error: no secure timestamp: ${candidate#$APP/}" >&2; bad=1
  fi
done < <(find "$APP/Contents" -type f -print0)
[ "$bad" -eq 0 ] || { echo "error: refusing to notarize an inconsistent build" >&2; exit 1; }
echo "    all nested code Developer ID signed with timestamps"

# --- notarize the app ---------------------------------------------------------
echo "==> notarizing app"
ditto -c -k --keepParent "$APP" "$OUT/EchoTune-$VERSION-notarize.zip"
xcrun notarytool submit "$OUT/EchoTune-$VERSION-notarize.zip" \
  --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# --- distribution zip ---------------------------------------------------------
echo "==> building distribution zip"
ditto -c -k --keepParent "$APP" "$OUT/EchoTune-$VERSION.zip"

# --- DMG ----------------------------------------------------------------------
echo "==> building DMG"
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/EchoTune.app"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/EchoTune-$VERSION-arm64.dmg"
hdiutil create -volname "EchoTune" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo
echo "==> done"
shasum -a 256 "$OUT/EchoTune-$VERSION.zip" "$DMG"
echo
echo "Next: sign the zip for Sparkle and update appcast.xml, then"
echo "  netlify deploy --prod --site cad89859-cef4-4480-b464-f1fcaf05727e \\"
echo "    --no-build --dir <echotune-site-fable> --functions netlify/functions"
