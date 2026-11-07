#!/bin/bash
# PreToolUse hook for Bash.
# - Blocks remote PR merges (the user merges PRs).
# - Blocks local git merge while on main/master.
# - Asks for approval on any other local git merge, showing source and target.

command=$(jq -r '.tool_input.command // ""')
start='(^|[;&|])[[:space:]]*'

if printf '%s' "$command" | grep -Eq "${start}(gh[[:space:]]+pr[[:space:]]+merge|gh[[:space:]]+api[[:space:]].*pulls/[0-9]+/merge)"; then
  echo "Blocked: PR merging is done by the user. Do not run the PR merge command or the merge API." >&2
  exit 2
fi

if printf '%s' "$command" | grep -Eq "${start}git[[:space:]]+merge([[:space:]]|$)"; then
  target=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)
  source=$(printf '%s' "$command" | sed -E 's/.*git[[:space:]]+merge//' | tr -s ' ' '\n' | grep -v '^-' | grep -v '^$' | head -1)

  if [ "$target" = "main" ] || [ "$target" = "master" ]; then
    echo "Blocked: no local merges into $target (attempted: merge '${source:-?}' into '$target'). Merge via PR instead." >&2
    exit 2
  fi

  jq -n --arg r "Local merge: '${source:-?}' into '${target:-?}'. Approve?" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
fi

exit 0
