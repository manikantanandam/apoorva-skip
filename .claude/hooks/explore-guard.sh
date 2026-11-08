#!/bin/bash
# Pre/PostToolUse hook for Read|Grep|Glob. Blocks an exact-duplicate
# exploration call already answered earlier in this session (PreToolUse),
# and records each call so later duplicates can be detected (PostToolUse).

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
state_file="$state_dir/$session_id.log"
mkdir -p "$state_dir" 2>/dev/null || exit 0

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
    echo "Already read this exact file ($file_path) earlier in this session — reuse the prior result instead of repeating the call. If you no longer have that detail (e.g. context was summarized), say so rather than re-running it." >&2
  else
    echo "Already ran this exact $tool call earlier in this session — reuse the prior result instead of repeating the call. If you no longer have that detail (e.g. context was summarized), say so rather than re-running it." >&2
  fi
  exit 2
fi

exit 0
