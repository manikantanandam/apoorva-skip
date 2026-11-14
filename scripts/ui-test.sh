#!/usr/bin/env bash
# Low-noise runner for the app's XCUITest target (ApoorvaUITests).
# Prints one SUCCESS or FAILED line plus root-cause lines; full output goes to a log file.
#
# Usage: scripts/ui-test.sh [TestClass[/testMethod]]
#   TestClass   optional filter, e.g. LoginUITests or LoginUITests/testLoginWithWrongPasswordShowsError
#
# Environment:
#   XC_DESTINATION  simulator destination (default: iPhone 17 on latest iOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/apoorva-xc"
DESTINATION="${XC_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
raw="$LOG_DIR/ApoorvaUITests.raw.log"
log="$LOG_DIR/ApoorvaUITests.log"
xcresult="$LOG_DIR/ApoorvaUITests.xcresult"

if ! command -v xcbeautify >/dev/null 2>&1; then
  echo "FAILED: xcbeautify is not installed. Run scripts/install-tools.sh" >&2
  exit 2
fi

args=(-workspace "$ROOT/app/Project.xcworkspace" -scheme "Apoorva App" -destination "$DESTINATION"
      -skipPackagePluginValidation -skipMacroValidation -resultBundlePath "$xcresult")
if [ $# -ge 1 ]; then
  args+=(-only-testing:"ApoorvaUITests/$1")
else
  args+=(-only-testing:ApoorvaUITests)
fi

mkdir -p "$LOG_DIR"
rm -rf "$xcresult"
status=0
# SKIP_ACTION=none stops the Skip gradle phase from launching an Android build.
(set -o pipefail && SKIP_ACTION=none xcodebuild test "${args[@]}" 2>&1 | tee "$raw" | xcbeautify --quiet > "$log") || status=$?

if [ "$status" -eq 0 ]; then
  echo "SUCCESS: ApoorvaUITests test"
  exit 0
fi

echo "FAILED: ApoorvaUITests test (exit $status)"
causes="$(grep -E "error:|❌|✖" "$log" | head -5 || true)"
if [ -z "$causes" ]; then
  causes="$(grep -hE "Test [Cc]ase .* failed|Testing failed|Failing tests" "$raw" | sort -u | head -5 || true)"
fi
[ -n "$causes" ] && echo "$causes"
echo "log: $log"
exit "$status"
