#!/usr/bin/env bash
# Prints a JSON array of testable modules (libraries/* with Package.swift + Tests/)
# affected by the diff between <base> and <head>: changed modules plus everything
# that transitively depends on them via `.package(path: "../X")`.
# Falls back to ALL modules when <base> is empty/zero, or a global file changed.
# Usage: scripts/changed-modules.sh <base-sha> <head-sha>
set -euo pipefail

BASE="${1:-}"
HEAD="${2:-HEAD}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PACKAGES=()   # every library with a Package.swift (needed for the dependency walk)
for dir in libraries/*; do
  if [ -d "$dir" ] && [ -f "$dir/Package.swift" ]; then PACKAGES+=("$(basename "$dir")"); fi
done

emit() {
  local out=() m
  for m in "$@"; do
    if [ -d "libraries/$m/Tests" ]; then out+=("\"$m\""); fi
  done
  local IFS=,
  echo "[${out[*]-}]"
}

if [ -z "$BASE" ] || [[ "$BASE" =~ ^0+$ ]] || ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  emit "${PACKAGES[@]}"; exit 0
fi

FILES="$(git diff --name-only "$BASE" "$HEAD")"

# Global triggers: anything that can affect every module.
if echo "$FILES" | grep -qE '^(\.github/|scripts/|sonar-project\.properties)'; then
  emit "${PACKAGES[@]}"; exit 0
fi

CHANGED=" "
for m in "${PACKAGES[@]}"; do
  if echo "$FILES" | grep -q "^libraries/$m/"; then CHANGED="$CHANGED$m "; fi
done

# Expand to reverse dependents until stable.
grew=1
while [ "$grew" = 1 ]; do
  grew=0
  for m in "${PACKAGES[@]}"; do
    case "$CHANGED" in *" $m "*) continue ;; esac
    for dep in $(grep -oE '\.package\(path: *"\.\./[^"]+"' "libraries/$m/Package.swift" \
                  | sed -E 's|.*\.\./([^"]+)"|\1|'); do
      case "$CHANGED" in *" $dep "*) CHANGED="$CHANGED$m "; grew=1; break ;; esac
    done
  done
done

# shellcheck disable=SC2086
emit $CHANGED
