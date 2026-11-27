#!/usr/bin/env bash
# Low-noise runner for the Android UI tests (Maestro flows in app/Android/maestro, twins of ApoorvaUITests).
# Prints one SUCCESS or FAILED line plus the failing flows; full output goes to a log file
# (and also streams to the console when CI=true).
#
# Usage: scripts/android-ui-test.sh [flow] [apk]
#   flow  optional top-level flow, e.g. login, customer-list, pos (empty runs every flow)
#   apk   optional debug APK to install first (x86_64 for the emulator; test mode is DEBUG-only)
#
# Needs a running emulator/device (adb) and the maestro CLI (curl -Ls https://get.maestro.mobile.dev | bash).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAESTRO_DIR="$ROOT/app/Android/maestro"
LOG_DIR="${TMPDIR:-/tmp}/apoorva-maestro"
log="$LOG_DIR/maestro.log"
FLOW="${1:-}"
APK="${2:-}"

for tool in adb maestro; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "FAILED: $tool is not on PATH" >&2
    exit 2
  fi
done
if [ -z "$(adb devices | sed 1d | grep -w device || true)" ]; then
  echo "FAILED: no running emulator or device (adb devices is empty)" >&2
  exit 2
fi

mkdir -p "$LOG_DIR"
rm -rf "$LOG_DIR/output"
if [ -n "$APK" ]; then
  adb install -r -t "$APK" > "$LOG_DIR/install.log" 2>&1 || { echo "FAILED: adb install $APK (see $LOG_DIR/install.log)"; exit 1; }
fi

target="$MAESTRO_DIR"
[ -n "$FLOW" ] && target="$MAESTRO_DIR/$FLOW.yaml"
[ -e "$target" ] || { echo "FAILED: no flow $target" >&2; exit 2; }

args=(test "$target" --format junit --output "$LOG_DIR/report.xml" --test-output-dir "$LOG_DIR/output")
[ -z "$FLOW" ] && args+=(--config "$MAESTRO_DIR/config.yaml")

status=0
if [ "${CI:-}" = "true" ]; then
  (set -o pipefail && maestro "${args[@]}" 2>&1 | tee "$log") || status=$?
else
  maestro "${args[@]}" > "$log" 2>&1 || status=$?
fi

if [ "$status" -eq 0 ]; then
  echo "SUCCESS: Android UI tests passed${FLOW:+ ($FLOW)}"
else
  echo "FAILED: Android UI tests${FLOW:+ ($FLOW)} (log: $log, screenshots: $LOG_DIR/output)"
  grep -E '❌|FAILED|Assertion is false|not found' "$log" | head -15 || true
fi
exit "$status"
