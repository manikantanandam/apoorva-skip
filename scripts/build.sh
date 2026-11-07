#!/usr/bin/env bash
# Low-noise build and test runner for the libraries/* packages.
# Prints one SUCCESS or FAILED line plus root-cause lines; full output goes to a log file.
#
# Usage: scripts/build.sh [Module|all] [build|test] [--coverage]
#   [Module]     a folder name under libraries/, or "all" (default: all)
#   build|test   xcodebuild action (default: test)
#   --coverage   enable code coverage and print the module's line coverage
#   --serial     run modules one at a time instead of in parallel
#   --shared     build in dependency order with one shared DerivedData, so common
#                packages (Models, Firebase, ...) compile once; less CPU, same results
#
# Environment:
#   MAX_JOBS        max parallel modules (default: ncpu/4, min 2)
#   XC_DESTINATION  simulator destination (default: iPhone 17 on latest iOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/apoorva-xc"
DESTINATION="${XC_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"

usage() {
  echo "Usage: scripts/build.sh [Module|all] [build|test] [--coverage] [--serial] [--shared]" >&2
  exit 64
}

MODULE="all"
if [ $# -ge 1 ] && [[ "$1" != build && "$1" != test && "$1" != --* ]]; then
  MODULE="$1"
  shift
fi

ACTION="test"
COVERAGE=0
SERIAL=0
SHARED=0
MAX_JOBS="${MAX_JOBS:-$(( $(sysctl -n hw.ncpu) / 4 ))}"
[ "$MAX_JOBS" -ge 2 ] || MAX_JOBS=2
for arg in "$@"; do
  case "$arg" in
    build|test) ACTION="$arg" ;;
    --coverage) COVERAGE=1 ;;
    --serial) SERIAL=1 ;;
    --shared) SHARED=1 ;;
    *) usage ;;
  esac
done

if ! command -v xcbeautify >/dev/null 2>&1; then
  echo "FAILED: xcbeautify is not installed. Run scripts/install-tools.sh" >&2
  exit 2
fi

# A stale CoreSimulator service hides every simulator from xcodebuild; listing devices refreshes it.
if ! sim_out="$(xcrun simctl list devices available 2>&1)" || grep -q "out of date" <<<"$sim_out"; then
  echo "FAILED: CoreSimulator is out of date or unavailable." >&2
  echo "Run: xcrun simctl shutdown all && killall -9 com.apple.CoreSimulator.CoreSimulatorService (or restart Xcode)" >&2
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
  if [ "$SHARED" -eq 1 ]; then
    args+=(-derivedDataPath "$LOG_DIR/DerivedData")
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
  causes="$(grep -hE "CoreSimulator is out of date|Unable to find a device" "$raw" | head -2 || true)"
  if [ -z "$causes" ]; then
    causes="$(grep -E "error:|❌|✖" "$log" | head -5 || true)"
  fi
  if [ -z "$causes" ]; then
    causes="$(grep -E "error:" "$raw" | head -5 || true)"
  fi
  if [ -n "$causes" ]; then
    echo "$causes"
  fi
  echo "log: $log"
  return "$status"
}

if [ "$SERIAL" -eq 1 ] || [ ${#MODULES[@]} -eq 1 ]; then
  MAX_JOBS=1
fi

mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.time
count=${#MODULES[@]}
pids=()
status_of=()
level_of=()
running=()
overall=0

index_of() {
  local i
  for i in "${!MODULES[@]}"; do
    if [ "${MODULES[$i]}" = "$1" ]; then echo "$i"; return 0; fi
  done
  return 1
}

# Names of selected modules that module $1 depends on (from `.package(path: "../X")`).
deps_of() {
  local dep
  grep -oE '\.package\(path: *"\.\./[^"]+"' "$ROOT/libraries/$1/Package.swift" 2>/dev/null \
    | sed -E 's|.*\.\./([^"]+)"|\1|' | while read -r dep; do
      if index_of "$dep" >/dev/null; then echo "$dep"; fi
    done
}

for i in "${!MODULES[@]}"; do
  level_of[$i]=0
  status_of[$i]=0
done

# --shared: level = 1 + max level of dependencies, so shared packages build once before dependents.
if [ "$SHARED" -eq 1 ]; then
  for ((pass = 0; pass < count; pass++)); do
    for i in "${!MODULES[@]}"; do
      lvl=0
      for dep in $(deps_of "${MODULES[$i]}"); do
        j="$(index_of "$dep")"
        if [ $((level_of[j] + 1)) -gt "$lvl" ]; then lvl=$((level_of[j] + 1)); fi
      done
      level_of[$i]=$lvl
    done
  done
fi

# Slot-based throttle (bash 3.2 has no `wait -n`): reap finished jobs until a slot is free.
wait_for_slot() {
  while [ ${#running[@]} -ge "$MAX_JOBS" ]; do
    local still=()
    for pid in "${running[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then still+=("$pid"); fi
    done
    running=("${still[@]+"${still[@]}"}")
    if [ ${#running[@]} -ge "$MAX_JOBS" ]; then sleep 1; fi
  done
}

failed_dep_of() {
  local dep j
  for dep in $(deps_of "${MODULES[$1]}"); do
    j="$(index_of "$dep")"
    if [ "${status_of[$j]}" -ne 0 ]; then echo "$dep"; return 0; fi
  done
  return 1
}

max_level=0
for i in "${!MODULES[@]}"; do
  if [ "${level_of[$i]}" -gt "$max_level" ]; then max_level="${level_of[$i]}"; fi
done

# Without --shared every module is level 0, so all start together (full concurrency).
for ((lvl = 0; lvl <= max_level; lvl++)); do
  level_idx=()
  for i in "${!MODULES[@]}"; do
    [ "${level_of[$i]}" -eq "$lvl" ] || continue
    if bad="$(failed_dep_of "$i")"; then
      echo "SKIPPED: ${MODULES[$i]} $ACTION (dependency $bad failed)" > "$LOG_DIR/${MODULES[$i]}.summary"
      status_of[$i]=1
      continue
    fi
    wait_for_slot
    (
      started=$SECONDS
      rc=0
      run_module "${MODULES[$i]}" > "$LOG_DIR/${MODULES[$i]}.summary" 2>&1 || rc=$?
      echo $((SECONDS - started)) > "$LOG_DIR/${MODULES[$i]}.time"
      exit "$rc"
    ) &
    pids[$i]=$!
    running+=($!)
    level_idx+=("$i")
  done
  for i in ${level_idx[@]+"${level_idx[@]}"}; do
    st=0
    wait "${pids[$i]}" || st=$?
    status_of[$i]=$st
    if [ "$st" -ne 0 ]; then overall=$st; fi
  done
  running=()
done

# Print summaries in module order so output stays deterministic.
for i in "${!MODULES[@]}"; do
  cat "$LOG_DIR/${MODULES[$i]}.summary"
  if [ "${status_of[$i]}" -ne 0 ] && [ "$overall" -eq 0 ]; then overall=1; fi
done

format_duration() {
  printf '%dm%02ds' $(($1 / 60)) $(($1 % 60))
}

# Per-module wall time (modules run concurrently, so the sum can exceed the total).
echo "--- timing ---"
sum=0
for i in "${!MODULES[@]}"; do
  if [ "${status_of[$i]}" -ne 0 ]; then result="FAILED"; else result="ok"; fi
  secs=""
  [ -f "$LOG_DIR/${MODULES[$i]}.time" ] && secs="$(cat "$LOG_DIR/${MODULES[$i]}.time")"
  if [ -n "$secs" ]; then
    sum=$((sum + secs))
    printf '%-24s %8s  %s\n' "${MODULES[$i]}" "$(format_duration "$secs")" "$result"
  else
    printf '%-24s %8s  %s\n' "${MODULES[$i]}" "-" "skipped"
  fi
done
printf '%-24s %8s\n' "sum of modules" "$(format_duration "$sum")"
printf '%-24s %8s\n' "overall (wall)" "$(format_duration "$SECONDS")"
exit "$overall"
