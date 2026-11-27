#!/usr/bin/env bash
# Local Android APK export, same command as .github/workflows/android-apk.yml.
# Prints one SUCCESS or FAILED line plus de-duplicated compile errors; full output goes to a log file.
#
# Usage: scripts/android-export.sh
#
# Environment:
#   ANDROID_HOME  Android SDK (default: ~/Library/Android/sdk)
#   OUT_DIR       export folder (default: $TMPDIR/apoorva-android-export)
#   ARCH          build one ABI only, e.g. ARCH=aarch64 for arm64 phones (~3x faster; CI uses aarch64).
#                 Unset builds arm64 + armv7 + x86_64.
#   CONFIG        release (default, R8-minified like CI) or debug (no R8; faster, for bisecting R8 issues).
#
# app/Skip.env keeps SKIP_NO_ANDROID=1 in git; like CI, this drops it for the run and restores it on exit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${TMPDIR:-/tmp}/apoorva-android-export.log"
OUT_DIR="${OUT_DIR:-${TMPDIR:-/tmp}/apoorva-android-export}"
ENV_FILE="$ROOT/app/Skip.env"
ENV_BACKUP="$(mktemp)"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

cp "$ENV_FILE" "$ENV_BACKUP"
restore_env() { cp "$ENV_BACKUP" "$ENV_FILE"; rm -f "$ENV_BACKUP"; }
trap restore_env EXIT

grep -v '^SKIP_NO_ANDROID' "$ENV_BACKUP" > "$ENV_FILE"

rm -rf "$OUT_DIR"
START=$(date +%s)
set +e
ARCH_ARGS=()
[ -n "${ARCH:-}" ] && ARCH_ARGS=(--arch "$ARCH")
(cd "$ROOT/app" && skip export -v --android --no-ios "--${CONFIG:-release}" ${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"} -d "$OUT_DIR") > "$LOG" 2>&1
STATUS=$?
set -e
ELAPSED=$(( $(date +%s) - START ))

APK="$(find "$OUT_DIR" -name '*.apk' 2>/dev/null | head -1 || true)"
if [ "$STATUS" -eq 0 ] && [ -n "$APK" ]; then
  echo "SUCCESS (${ELAPSED}s): $APK"
  exit 0
fi

echo "FAILED (${ELAPSED}s, exit $STATUS). Log: $LOG"
# "<package> | <message>" with counts, so repeated errors collapse to one line.
perl -pe 's/\e\[[0-9;]*m//g; s/\^\[\[[0-9;]*m//g' "$LOG" \
  | perl -ne 'print(($1 // "-"), " | ", $2, "\n") if m{(?:checkouts|Packages|Sources)/([A-Za-z]+)/.*?\.swift:\d+:\d+: error: (.*)$}' \
  | sort | uniq -c | sort -rn | head -20
exit 1
