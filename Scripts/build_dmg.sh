#!/bin/bash
#
# build_dmg.sh — build the drag-to-Applications DMG with a branded background.
#
# USAGE
#   Scripts/build_dmg.sh <EchoTune.app> <output.dmg>
#
# Wraps Scripts/build_dmg.py (dmgbuild): the Finder window layout is written
# directly into the volume's .DS_Store, so no Finder/AppleScript automation
# is required. A Python venv with dmgbuild is created on first use.
#
set -euo pipefail

APP_PATH="${1:?usage: build_dmg.sh <EchoTune.app> <output.dmg>}"
DMG_PATH="${2:?usage: build_dmg.sh <EchoTune.app> <output.dmg>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.dmg-venv"

[ -d "$APP_PATH" ] || { echo "error: $APP_PATH not found" >&2; exit 1; }

if [ ! -x "$VENV/bin/python" ]; then
    echo "==> creating dmgbuild venv at $VENV"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet dmgbuild
fi

rm -f "$DMG_PATH"
"$VENV/bin/python" "$ROOT/Scripts/build_dmg.py" "$APP_PATH" "$DMG_PATH"

echo "==> DMG built: $DMG_PATH"
