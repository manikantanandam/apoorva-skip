#!/usr/bin/env bash
# Checks that every iOS UI test scenario has an Android (Maestro) twin.
# - iOS scenarios: literal `scenario("…")` and `runActivity(named: "…")` names in app/Darwin/UITests/<Group>/<Class>.swift.
# - Android twin: app/Android/maestro/scenarios/<flow>/<slug>.yaml, run from app/Android/maestro/<flow>.yaml,
#   where <flow> is the class name without "UITests" in kebab case (KiranaPOSUITests -> kirana-pos)
#   and <slug> is the scenario name in kebab case ("Focus-driven visibility" -> focus-driven-visibility).
# - A scenario that can't run on Android may stay as a file whose first line is `# android-skip: <reason>`;
#   it counts as covered and is listed.
#
# Usage: scripts/check-ui-test-parity.sh   (exit 1 lists anything missing)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/app/Darwin/UITests"
MAESTRO_DIR="$ROOT/app/Android/maestro"

kebab() { sed -E 's/([a-z0-9])([A-Z])/\1-\2/g; s/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g' | tr '[:upper:]' '[:lower:]'; }

total=0
missing=()
skipped=()
while IFS= read -r file; do
  class="$(basename "$file" .swift)"
  flow="$(printf '%s' "${class%UITests}" | kebab)"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    total=$((total + 1))
    slug="$(printf '%s' "$name" | kebab)"
    scenario="scenarios/$flow/$slug.yaml"
    if [ ! -f "$MAESTRO_DIR/$scenario" ]; then
      missing+=("$class \"$name\" -> $scenario (file missing)")
    elif ! grep -qF "runFlow: $scenario" "$MAESTRO_DIR/$flow.yaml" 2>/dev/null; then
      missing+=("$class \"$name\" -> $scenario (not run from $flow.yaml)")
    elif head -1 "$MAESTRO_DIR/$scenario" | grep -q '^# android-skip:'; then
      skipped+=("$class \"$name\": $(head -1 "$MAESTRO_DIR/$scenario" | sed 's/^# android-skip: *//')")
    fi
  done < <(grep -oE '(scenario|runActivity\(named:) ?\(?"[^"]+"' "$file" | sed -E 's/.*"([^"]+)"/\1/')
done < <(find "$IOS_DIR" -name '*UITests.swift' | sort)

covered=$((total - ${#missing[@]}))
for line in "${skipped[@]+"${skipped[@]}"}"; do echo "SKIPPED on Android: $line"; done
if [ ${#missing[@]} -gt 0 ]; then
  echo "FAILED: $covered/$total iOS UI test scenarios have an Android twin"
  for line in "${missing[@]}"; do echo "  missing: $line"; done
  exit 1
fi
echo "SUCCESS: $covered/$total iOS UI test scenarios have an Android twin (${#skipped[@]} skipped)"
