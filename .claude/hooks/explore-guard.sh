#!/bin/bash
# Pre/PostToolUse hook for Read|Grep|Glob. Blocks an exact-duplicate
# exploration call already answered earlier for this project — in this
# session or an earlier one (PreToolUse), and records each call so later
# duplicates can be detected (PostToolUse). State is keyed per project
# directory, not per session, so it persists across sessions.
# Also blocks Bash (PreToolUse only) from using cat/sed/head/tail/awk/less/
# more/bat/grep to dump a file already Read before (any session) — closes
# the bypass where a blocked duplicate Read is re-fetched through the shell.

command -v jq >/dev/null 2>&1 || exit 0
command -v stat >/dev/null 2>&1 || exit 0

get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

payload=$(cat)

event=$(printf '%s' "$payload" | jq -r '.hook_event_name // ""')
session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""')
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""')

[ -n "$event" ] || exit 0
[ -n "$session_id" ] || exit 0
[ -n "$tool" ] || exit 0

state_dir="/tmp/claude-explore-guard"
mkdir -p "$state_dir" 2>/dev/null || exit 0

# Keyed per project directory (not per session_id) so a file explored in an
# earlier session still counts as a duplicate in this one.
project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
project_key=$(printf '%s' "$project_dir" | shasum -a 256 2>/dev/null | awk '{print $1}')
[ -n "$project_key" ] || exit 0
state_file="$state_dir/$project_key.log"

if [ "$tool" = "Bash" ]; then
  [ "$event" = "PreToolUse" ] || exit 0
  [ -f "$state_file" ] || exit 0
  command_str=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
  [ -n "$command_str" ] || exit 0
  case "$command_str" in
    *cat\ *|*sed\ *|*head\ *|*tail\ *|*awk\ *|*less\ *|*more\ *|*bat\ *|*grep\ *) ;;
    *) exit 0 ;;
  esac
  while IFS= read -r read_path; do
    [ -n "$read_path" ] || continue
    case "$command_str" in
      *"$read_path"*)
        echo "Already Read this exact file ($read_path) before — in this session or an earlier one. Running cat/sed/head/tail/awk/grep/etc. on it via Bash bypasses the duplicate-read guard instead of honoring it. Reuse the prior Read result, or say plainly you no longer have that detail — don't re-fetch it through Bash." >&2
        exit 2
        ;;
    esac
  done < <(jq -r 'select(.tool == "Read") | .key' "$state_file" 2>/dev/null | sort -u)
  exit 0
fi

file_path=""

case "$tool" in
  Read)
    file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')
    [ -n "$file_path" ] || exit 0
    has_range=$(printf '%s' "$payload" | jq -r 'if (.tool_input.offset != null) or (.tool_input.limit != null) then "1" else "0" end')
    # A partial-range read is never a duplicate of, or matched against, a full read.
    [ "$has_range" = "0" ] || exit 0
    key="$file_path"
    ;;
  Grep|Glob)
    key=$(printf '%s' "$payload" | jq -S -c '.tool_input' 2>/dev/null | shasum -a 256 2>/dev/null | awk '{print $1}')
    ;;
  *)
    exit 0
    ;;
esac

[ -n "$key" ] || exit 0

if [ "$event" = "PostToolUse" ]; then
  mtime=""
  if [ "$tool" = "Read" ]; then
    mtime=$(get_mtime "$file_path")
  fi
  jq -nc --arg tool "$tool" --arg key "$key" --arg mtime "$mtime" \
    '{tool: $tool, key: $key, mtime: $mtime}' >> "$state_file" 2>/dev/null
  exit 0
fi

if [ "$event" = "PreToolUse" ]; then
  match=$(jq -c --arg tool "$tool" --arg key "$key" 'select(.tool == $tool and .key == $key)' "$state_file" 2>/dev/null | tail -n1)
  [ -n "$match" ] || exit 0

  if [ "$tool" = "Read" ]; then
    recorded_mtime=$(printf '%s' "$match" | jq -r '.mtime // ""')
    current_mtime=$(get_mtime "$file_path")
    # File changed since the earlier read (or mtime unavailable) - re-reading is justified.
    if [ -z "$current_mtime" ] || [ "$current_mtime" != "$recorded_mtime" ]; then
      exit 0
    fi
    echo "Already read this exact file ($file_path) before — in this session or an earlier one — and it hasn't changed since. Reuse the prior result instead of repeating the call. If you no longer have that detail (e.g. context was summarized), say so rather than re-running it." >&2
  else
    echo "Already ran this exact $tool call before — in this session or an earlier one. Reuse the prior result instead of repeating the call. If you no longer have that detail (e.g. context was summarized), say so rather than re-running it." >&2
  fi
  exit 2
fi

exit 0
