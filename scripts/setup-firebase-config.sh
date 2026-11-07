#!/usr/bin/env bash
# Writes the per-environment Firebase plists from base64-encoded secrets.
# LaunchEnvironment (ApoorvaAppCore) picks the right one at RUNTIME based on
# the AppEnvironment selected in Developer Settings:
#   .debug      -> GoogleService-Info-debug.plist
#   .production -> GoogleService-Info.plist (the default, no suffix)
# Both must be bundled as Resources for Bundle.main to find them.
#
# Local use:
#   export GOOGLE_SERVICE_INFO_PLIST_DEBUG_B64=$(base64 -i /path/to/GoogleService-Info-debug.plist)
#   export GOOGLE_SERVICE_INFO_PLIST_PRODUCTION_B64=$(base64 -i /path/to/GoogleService-Info.plist)
#   scripts/setup-firebase-config.sh
#
# CI use (GitHub Actions secrets):
#   GOOGLE_SERVICE_INFO_PLIST_DEBUG_B64: ${{ secrets.GOOGLE_SERVICE_INFO_PLIST_DEBUG_B64 }}
#   GOOGLE_SERVICE_INFO_PLIST_PRODUCTION_B64: ${{ secrets.GOOGLE_SERVICE_INFO_PLIST_PRODUCTION_B64 }}
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DARWIN_DIR="$ROOT_DIR/app/Darwin"

wrote_any=0

if [ -n "${GOOGLE_SERVICE_INFO_PLIST_DEBUG_B64:-}" ]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_DEBUG_B64" | base64 --decode > "$DARWIN_DIR/GoogleService-Info-debug.plist"
  echo "Wrote $DARWIN_DIR/GoogleService-Info-debug.plist"
  wrote_any=1
fi

if [ -n "${GOOGLE_SERVICE_INFO_PLIST_PRODUCTION_B64:-}" ]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_PRODUCTION_B64" | base64 --decode > "$DARWIN_DIR/GoogleService-Info.plist"
  echo "Wrote $DARWIN_DIR/GoogleService-Info.plist"
  wrote_any=1
fi

if [ "$wrote_any" -eq 0 ]; then
  echo "ERROR: none of GOOGLE_SERVICE_INFO_PLIST_{DEBUG,PRODUCTION}_B64 is set." >&2
  exit 1
fi
