#!/bin/bash
#
# Backward-compatible entry point for the compiled-model bundler.
#
# The old script had a separate DerivedData scanner and could drift from the
# release path. Keep this name for existing release notes and call sites, but
# delegate all discovery, copying, manifest generation, dry-run behavior, and
# size reporting to bundle_default_model.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/bundle_default_model.sh" "$@"
