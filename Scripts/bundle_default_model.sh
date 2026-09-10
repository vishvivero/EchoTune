#!/bin/bash
#
# Scripts/bundle_default_model.sh
#
# Copies the CoreML-compiled Whisper model set for the app's default local
# model into EchoTune/Resources/CompiledModels/ so the release build ships
# verified CoreML model bundles are available on first launch. CoreML device
# specialization may still apply. Also writes compiled-manifest.json, which the app validates before
# trusting the bundles.
#
# The folder is git-ignored (.gitignore); the release pipeline runs this script
# before `xcodebuild archive`, so the DMG carries the compiled models while the
# repo stays lean.
#
# Usage:
#   ./Scripts/bundle_default_model.sh                        # default model, auto-discover
#   ./Scripts/bundle_default_model.sh --dry-run              # list what would be copied
#   ./Scripts/bundle_default_model.sh --model-folder <path>  # explicit source folder
#   ./Scripts/bundle_default_model.sh --model-id <id>        # override the manifest model id
#
# Runtime note: WhisperKit loads <modelFolder>/<Name>.mlmodelc directly
# (ModelUtilities.detectModelURL), so WhisperEngine links these bundles into the
# model folder's top level, NOT a "compiled/" subdirectory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$REPO_ROOT/EchoTune/Resources/CompiledModels"

# Keep in sync with AppSettings.defaultLocalTranscriptionModel. The value is
# re-read from the Swift source below when available so the two cannot drift.
DEFAULT_MODEL_ID="distil-whisper_distil-large-v3_turbo_600MB"

MODEL_ID=""
MODEL_FOLDER=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --model-folder) MODEL_FOLDER="${2:-}"; shift 2 ;;
        --model-id) MODEL_ID="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

APP_SETTINGS="$REPO_ROOT/EchoTune/Models/AppSettings.swift"
if [ -z "$MODEL_ID" ] && [ -f "$APP_SETTINGS" ]; then
    SOURCE_DEFAULT="$(sed -n 's/.*defaultLocalTranscriptionModel = "\([^"]*\)".*/\1/p' "$APP_SETTINGS" | head -1)"
    if [ -n "$SOURCE_DEFAULT" ]; then
        DEFAULT_MODEL_ID="$SOURCE_DEFAULT"
    fi
fi
if [ -z "$MODEL_ID" ]; then
    MODEL_ID="$DEFAULT_MODEL_ID"
fi

APP_SUPPORT_MODELS="$HOME/Library/Application Support/EchoTune/WhisperModels/models/argmaxinc/whisperkit-coreml"

find_source_dir() {
    if [ -n "$MODEL_FOLDER" ]; then
        if [ -d "$MODEL_FOLDER" ]; then echo "$MODEL_FOLDER"; return 0; fi
        return 1
    fi
    # An already-installed model folder (WhisperKit compiles in place on first load).
    local candidate
    for candidate in "$APP_SUPPORT_MODELS/$MODEL_ID" "$APP_SUPPORT_MODELS/${MODEL_ID}_"*; do
        if [ -d "$candidate" ] && compgen -G "$candidate/*.mlmodelc" > /dev/null; then
            echo "$candidate"; return 0
        fi
    done
    # Fall back to DerivedData (same scan the precompile script uses).
    local dd
    dd="$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 6 -type d -name "$MODEL_ID" 2>/dev/null | head -1)"
    if [ -n "$dd" ] && compgen -G "$dd/*.mlmodelc" > /dev/null; then
        echo "$dd"; return 0
    fi
    return 1
}

SRC_DIR="$(find_source_dir || true)"
if [ -z "$SRC_DIR" ]; then
    echo "❌ Could not locate a compiled model folder for '$MODEL_ID'." >&2
    echo "   Run the app once so WhisperKit compiles the model, or pass --model-folder <path>." >&2
    exit 1
fi

ENTRIES=()
for entry in "$SRC_DIR"/*.mlmodelc; do
    [ -e "$entry" ] || continue
    ENTRIES+=("$(basename "$entry")")
done

if [ "${#ENTRIES[@]}" -eq 0 ]; then
    echo "❌ No .mlmodelc bundles found in $SRC_DIR" >&2
    exit 1
fi

echo "=== EchoTune bundle-default-model ==="
echo "Model id : $MODEL_ID"
echo "Source   : $SRC_DIR"
echo "Dest     : $DEST_DIR"
echo "Bundles  : ${#ENTRIES[@]}"

if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "DRY RUN — would copy:"
    for name in "${ENTRIES[@]}"; do echo "   $name"; done
    exit 0
fi

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
for name in "${ENTRIES[@]}"; do
    echo "   → $name"
    cp -R "$SRC_DIR/$name" "$DEST_DIR/$name"
done

# Digest definition (must match CompiledModelBundleCheck.digestOfEntry in Swift):
#   regular file  -> SHA256 of its bytes
#   directory     -> SHA256 over, for each regular file sorted by relative path:
#                    relPath UTF-8, 0x00, file bytes, 0x00
compute_entry_digest() {
    local entry="$1"
    if [ -f "$entry" ]; then
        shasum -a 256 "$entry" | awk '{print $1}'
        return 0
    fi
    (
        cd "$entry" || exit 1
        find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' file; do
            printf '%s\0' "${file#./}"
            cat "$file"
            printf '\0'
        done
    ) | shasum -a 256 | awk '{print $1}'
}

{
    echo "{"
    echo "  \"schemaVersion\": 1,"
    echo "  \"modelId\": \"$MODEL_ID\","
    echo "  \"files\": ["
    first=1
    for name in "${ENTRIES[@]}"; do
        digest="$(compute_entry_digest "$DEST_DIR/$name")"
        comma=","
        if [ "$first" -eq 1 ]; then comma=""; first=0; fi
        printf '%s    { "name": "%s", "sha256": "%s" }\n' "$comma" "$name" "$digest"
    done
    echo "  ]"
    echo "}"
} > "$DEST_DIR/compiled-manifest.json"

echo ""
echo "✅ Wrote $(basename "$DEST_DIR") with ${#ENTRIES[@]} bundles + manifest"
du -sh "$DEST_DIR"
echo ""
echo "Reminder: this folder is git-ignored; run it before 'xcodebuild archive'."