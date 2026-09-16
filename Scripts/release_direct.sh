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
NOTARY_PROFILE="${NOTARY_PROFILE:-EchoTune Notary 2}"
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

# --- sign WITH entitlements (the whole point) ---------------------------------
echo "==> signing with entitlements"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"

if ! codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q 'com.apple.security.device.audio-input'; then
  echo "error: com.apple.security.device.audio-input missing from signature — refusing to ship" >&2
  echo "       (this is exactly the 7.4.5 bug; the app would be denied microphone access)" >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=1 "$APP"

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
