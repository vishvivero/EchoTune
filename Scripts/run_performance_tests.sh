#!/bin/bash
# EchoTune performance test guidance and result-directory setup.
# This script never assumes a checkout path or username and does not make
# production performance claims. Use the flag-gated runtime benchmark for
# reproducible local-model measurements.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${ECHOTUNE_RESULTS_DIR:-$REPO_ROOT/BenchmarkResults}"
APP_PATH="${ECHOTUNE_APP_PATH:-$REPO_ROOT/build/Debug/EchoTune.app}"
mkdir -p "$RESULTS_DIR"

if [[ "${1:-}" == "--paths" ]]; then
  printf 'repo_root=%s\napp_path=%s\nresults_dir=%s\n' "$REPO_ROOT" "$APP_PATH" "$RESULTS_DIR"
  exit 0
fi

cat <<EOF
EchoTune performance test setup
===============================
Repository: $REPO_ROOT
App path:   $APP_PATH
Results:    $RESULTS_DIR

For reproducible local Whisper measurements, use the phase benchmark with an
explicit fixture and isolated derived-data directory. Audio duration must be
read from file metadata; never infer it from a filename.

Example:
  ECHOTUNE_RESULTS_DIR="$RESULTS_DIR" \\
    "$REPO_ROOT/Scripts/phase2_runtime_inventory.sh"

Manual scenarios remain useful for UX checks, but this script intentionally
makes no unverified latency, RTF, VAD, or speedup promises.
EOF
