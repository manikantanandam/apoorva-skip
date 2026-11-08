#!/usr/bin/env bash
# Switch a registered library dependency between its pinned remote version and the
# sibling Libraries/<folder> checkout, by editing the single .package(...) line that
# declares it in each registered consumer manifest.
#
# Usage: scripts/toggle-library.sh {local|remote|status} [LibraryName]
#   LibraryName  a key in scripts/library-registry.json (the product name, e.g.
#                "ManiSwiftUIComponents" or "ApoorvaUtilities"), required for
#                local/remote, omitted for status (reports every registered library).
#
# Never hand-edit Package.resolved afterwards — run scripts/build.sh <Module> build
# to re-resolve. Path dependencies aren't version-pinned, so a library's entry
# disappears from Package.resolved in local mode and reappears in remote mode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT/.." && pwd)"
REGISTRY="$ROOT/scripts/library-registry.json"

usage() {
  echo "Usage: scripts/toggle-library.sh {local|remote|status} [LibraryName]" >&2
  exit 64
}

[ $# -ge 1 ] || usage
MODE="$1"
LIB="${2:-}"

case "$MODE" in
  local|remote) [ -n "$LIB" ] || usage ;;
  status) ;;
  *) usage ;;
esac

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

lib_names() {
  jq -r '.libraries | keys[]' "$REGISTRY"
}

lib_field() {
  jq -er --arg n "$1" --arg f "$2" '.libraries[$n][$f]' "$REGISTRY"
}

lib_consumers() {
  jq -er --arg n "$1" '.libraries[$n].consumers[]' "$REGISTRY"
}

require_lib() {
  jq -e --arg n "$1" '.libraries[$n]' "$REGISTRY" >/dev/null 2>&1 || {
    echo "Unknown library '$1' (not in $REGISTRY)" >&2
    exit 1
  }
}

# Relative path from a consumer manifest's directory up to Libraries/<folder>.
# consumer is relative to $ROOT, e.g. "libraries/ApoorvaModules/Package.swift".
local_path_for() {
  local consumer="$1" folder="$2"
  local dir="${consumer%/Package.swift}"
  local depth
  depth="$(tr -cd '/' <<<"$dir" | wc -c | tr -d ' ')"
  depth=$((depth + 1))
  local up=""
  local i
  for ((i = 0; i < depth + 1; i++)); do
    up="${up}../"
  done
  echo "${up}Libraries/${folder}"
}

mode_status() {
  printf '%-20s %-45s %s\n' "LIBRARY" "CONSUMER" "MODE"
  local any_unknown=0
  for name in $(lib_names); do
    local url folder
    url="$(lib_field "$name" remoteURL)"
    folder="$(lib_field "$name" folder)"
    while IFS= read -r consumer; do
      local file="$ROOT/$consumer"
      local state="UNKNOWN"
      if grep -qF ".package(url: \"$url\"" "$file" 2>/dev/null; then
        state="remote"
      elif grep -Eq "\.package\(path: \"[^\"]*/${folder}\"\)" "$file" 2>/dev/null; then
        state="local"
      else
        any_unknown=1
      fi
      printf '%-20s %-45s %s\n' "$name" "$consumer" "$state"
    done < <(lib_consumers "$name")
  done
  [ "$any_unknown" -eq 0 ] || {
    echo "Warning: one or more consumers matched neither known form — registry or manifest may have drifted." >&2
    exit 1
  }
}

mode_local() {
  local name="$1"
  require_lib "$name"
  local url folder
  url="$(lib_field "$name" remoteURL)"
  folder="$(lib_field "$name" folder)"
  while IFS= read -r consumer; do
    local file="$ROOT/$consumer"
    local path
    path="$(local_path_for "$consumer" "$folder")"
    local before after count
    before="$(grep -cF ".package(url: \"$url\"" "$file" || true)"
    [ "$before" -eq 1 ] || {
      echo "Expected exactly 1 remote declaration for '$name' in $consumer, found $before" >&2
      exit 1
    }
    # Preserve a trailing comma if the matched line has one. Values travel via env
    # vars so nothing needs escaping for both bash's and Perl's quoting rules at once.
    URL="$url" PATHVAL="$path" perl -pi -e \
      's{\.package\(url: "\Q$ENV{URL}\E"[^)]*\)(,?)}{".package(path: \"$ENV{PATHVAL}\")" . $1}e' \
      "$file"
    after="$(grep -cF ".package(path: \"$path\")" "$file" || true)"
    [ "$after" -ge 1 ] || {
      echo "Substitution failed for '$name' in $consumer" >&2
      exit 1
    }
    echo "local:  $consumer -> $path"
  done < <(lib_consumers "$name")
  echo
  echo "Run scripts/build.sh <module> build to re-resolve; '$name' will disappear from the affected Package.resolved files."
}

mode_remote() {
  local name="$1"
  require_lib "$name"
  local url version folder constraint
  url="$(lib_field "$name" remoteURL)"
  version="$(lib_field "$name" remoteVersion)"
  folder="$(lib_field "$name" folder)"
  constraint="$(lib_field "$name" versionConstraint)"
  local remote_line=".package(url: \"$url\", $constraint: \"$version\")"
  while IFS= read -r consumer; do
    local file="$ROOT/$consumer"
    local local_count remote_count total
    local_count="$(grep -Ec "\\.package\\(path: \"[^\"]*/${folder}\"\\)" "$file" || true)"
    remote_count="$(grep -cF ".package(url: \"$url\"" "$file" || true)"
    total=$((local_count + remote_count))
    [ "$total" -eq 1 ] || {
      echo "Expected exactly 1 local-or-remote declaration for '$name' in $consumer, found $total" >&2
      exit 1
    }
    if [ "$local_count" -eq 1 ]; then
      FOLDER="$folder" LINE="$remote_line" perl -pi -e \
        's{\.package\(path: "[^"]*/\Q$ENV{FOLDER}\E"\)(,?)}{$ENV{LINE} . $1}e' \
        "$file"
    else
      URL="$url" LINE="$remote_line" perl -pi -e \
        's{\.package\(url: "\Q$ENV{URL}\E"[^)]*\)(,?)}{$ENV{LINE} . $1}e' \
        "$file"
    fi
    echo "remote: $consumer -> $version"
  done < <(lib_consumers "$name")
  echo
  echo "Run scripts/build.sh <module> build to re-resolve; '$name' will reappear pinned at $version in the affected Package.resolved files."
}

case "$MODE" in
  status) mode_status ;;
  local) mode_local "$LIB" ;;
  remote) mode_remote "$LIB" ;;
esac
