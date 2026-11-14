#!/usr/bin/env bash
# Builds a markdown table of per-module coverage.
#
# Usage: coverage-summary.sh <current-dir> [baseline-dir]
#   <current-dir>   holds <Module>.json files ({"module","covered","executable"}) from this run
#   [baseline-dir]  optional; same format from the last main run, used for modules not tested in this run
# Writes the markdown to stdout and a merged <Module>.json set to ./merged-coverage/.
set -euo pipefail

CURRENT="$1"
BASELINE="${2:-}"
MERGED="merged-coverage"
rm -rf "$MERGED" && mkdir -p "$MERGED"

if [ -n "$BASELINE" ] && [ -d "$BASELINE" ]; then
  cp "$BASELINE"/*.json "$MERGED"/ 2>/dev/null || true
fi
cp "$CURRENT"/*.json "$MERGED"/

echo "## 📊 Code Coverage (all modules)"
echo
echo "| Module | Coverage | Covered / Total lines | Source |"
echo "|---|---:|---:|---|"

TOTAL_COV=0
TOTAL_EXE=0
for f in $(ls "$MERGED"/*.json | sort); do
  module=$(jq -r .module "$f")
  cov=$(jq -r .covered "$f")
  exe=$(jq -r .executable "$f")
  if [ -f "$CURRENT/$(basename "$f")" ]; then source="this run"; else source="last main run"; fi
  pct=$(awk -v c="$cov" -v e="$exe" 'BEGIN { if (e == 0) print "n/a"; else printf "%.1f%%", c * 100 / e }')
  echo "| $module | $pct | $cov / $exe | $source |"
  TOTAL_COV=$((TOTAL_COV + cov))
  TOTAL_EXE=$((TOTAL_EXE + exe))
done

TOTAL_PCT=$(awk -v c="$TOTAL_COV" -v e="$TOTAL_EXE" 'BEGIN { if (e == 0) print "n/a"; else printf "%.1f%%", c * 100 / e }')
echo "| **Overall** | **$TOTAL_PCT** | **$TOTAL_COV / $TOTAL_EXE** | |"
echo
echo "_Raw Xcode line coverage; Sonar's view/router exclusions are not applied. Commit: \`${GITHUB_SHA:-local}\`_"
