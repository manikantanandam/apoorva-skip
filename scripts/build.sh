#!/usr/bin/env bash
# Low-noise build and test runner for the libraries/* packages.
# Prints one SUCCESS or FAILED line plus root-cause lines; full output goes to a log file.
#
# Usage: scripts/build.sh [Module|all] [build|test] [--coverage]
#   [Module]     a folder name under libraries/, or "all" (default: all)
#   build|test   xcodebuild action (default: test)
#   --coverage   enable code coverage and print the module's line coverage
#
# Environment:
#   XC_DESTINATION  simulator destination (default: iPhone 17 on latest iOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/apoorva-xc"
DESTINATION="${XC_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"

usage() {
  echo "Usage: scripts/build.sh [Module|all] [build|test] [--coverage]" >&2
  exit 64
}

MODULE="all"
if [ $# -ge 1 ] && [[ "$1" != build && "$1" != test && "$1" != --coverage ]]; then
  MODULE="$1"
  shift
fi

ACTION="test"
COVERAGE=0
for arg in "$@"; do
  case "$arg" in
    build|test) ACTION="$arg" ;;
    --coverage) COVERAGE=1 ;;
    *) usage ;;
  esac
done

if ! command -v xcbeautify >/dev/null 2>&1; then
  echo "FAILED: xcbeautify is not installed. Run scripts/install-tools.sh" >&2
  exit 2
fi

MODULES=()
if [ "$MODULE" = "all" ]; then
  for dir in "$ROOT"/libraries/*/; do
    [ -f "$dir/Package.swift" ] || continue
    if [ "$ACTION" = "test" ] && [ ! -d "$dir/Tests" ]; then
      continue
    fi
    MODULES+=("$(basename "$dir")")
  done
else
  if [ ! -f "$ROOT/libraries/$MODULE/Package.swift" ]; then
    echo "FAILED: unknown module '$MODULE' (no libraries/$MODULE/Package.swift)" >&2
    exit 64
  fi
  MODULES=("$MODULE")
fi

if [ ${#MODULES[@]} -eq 0 ]; then
  echo "FAILED: no modules to $ACTION" >&2
  exit 64
fi

print_coverage() {
  local module="$1"
  local xcresult="$2"
  local line
  line="$(xcrun xccov view --report --only-targets "$xcresult" 2>/dev/null | grep -m1 "$module" || true)"
  if [ -n "$line" ]; then
    echo "coverage: $(echo "$line" | awk '{for (i = 1; i <= NF; i++) if ($i ~ /%$/) {print $i; exit}}')"
  fi
}

run_module() {
  local module="$1"
  local dir="$ROOT/libraries/$module"
  local raw="$LOG_DIR/$module.raw.log"
  local log="$LOG_DIR/$module.log"
  local xcresult="$LOG_DIR/$module.xcresult"
  local args=(-scheme "$module" -destination "$DESTINATION" -skipPackagePluginValidation -skipMacroValidation -resultBundlePath "$xcresult")
  local status=0

  mkdir -p "$LOG_DIR"
  rm -rf "$xcresult"
  if [ "$COVERAGE" -eq 1 ]; then
    args+=(-enableCodeCoverage YES)
  fi

  (cd "$dir" && set -o pipefail && xcodebuild "$ACTION" "${args[@]}" 2>&1 | tee "$raw" | xcbeautify --quiet > "$log") || status=$?

  if [ "$status" -eq 0 ]; then
    echo "SUCCESS: $module $ACTION"
    if [ "$COVERAGE" -eq 1 ]; then
      print_coverage "$module" "$xcresult"
    fi
    return 0
  fi

  echo "FAILED: $module $ACTION (exit $status)"
  local causes
  causes="$(grep -E "error:|❌|✖" "$log" | head -5 || true)"
  if [ -z "$causes" ]; then
    causes="$(grep -E "error:" "$raw" | head -5 || true)"
  fi
  if [ -n "$causes" ]; then
    echo "$causes"
  fi
  echo "log: $log"
  return "$status"
}

overall=0
for module in "${MODULES[@]}"; do
  run_module "$module" || overall=$?
done
exit "$overall"
