#!/bin/bash
# PostToolUse ("post") + Stop ("stop") hook. Forces exploration/decisions made
# during a session to be written to the repo's decisions folder before the
# session can end, instead of only living in chat/private memory.
#
# Usage:
#   enforce-decision-log.sh post <decisions-dir-relative-to-repo-root>
#   enforce-decision-log.sh stop <decisions-dir-relative-to-repo-root>

command -v jq >/dev/null 2>&1 || exit 0

mode="$1"
decisions_dir="$2"
[ -n "$mode" ] || exit 0
[ -n "$decisions_dir" ] || exit 0

payload=$(cat)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""')
[ -n "$session_id" ] || exit 0

state_dir="/tmp/claude-explore-guard"
mkdir -p "$state_dir" 2>/dev/null || exit 0

explore_log="$state_dir/$session_id.log"
plan_exit_marker="$state_dir/$session_id.plan-exit"
decision_logged_marker="$state_dir/$session_id.decision-logged"

if [ "$mode" = "post" ]; then
  tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""')

  if [ "$tool" = "ExitPlanMode" ]; then
    touch "$plan_exit_marker" 2>/dev/null
    exit 0
  fi

  if [ "$tool" = "Write" ] || [ "$tool" = "Edit" ]; then
    file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')
    case "$file_path" in
      */"$decisions_dir"/*) touch "$decision_logged_marker" 2>/dev/null ;;
    esac
  fi
  exit 0
fi

if [ "$mode" = "stop" ]; then
  stop_hook_active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')
  [ "$stop_hook_active" = "true" ] && exit 0

  [ -f "$decision_logged_marker" ] && exit 0

  explored=0
  [ -s "$explore_log" ] && explored=1
  [ -f "$plan_exit_marker" ] && explored=1

  [ "$explored" = "1" ] || exit 0

  jq -nc --arg dir "$decisions_dir" \
    '{decision:"block", reason: ("This session explored files or finalized a plan/decision, but nothing was written under " + $dir + "/. Write a short dated markdown entry there (what was explored, what was decided, why) before finishing.")}'
  exit 0
fi

exit 0
