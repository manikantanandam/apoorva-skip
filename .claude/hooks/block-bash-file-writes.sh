#!/bin/bash
# PreToolUse hook for Bash. Blocks shell-based file writes (cat > file, heredocs)
# so files are created with the Write tool instead.

command=$(jq -r '.tool_input.command // ""')

if printf '%s' "$command" | grep -Eq 'cat[[:space:]]*>|<<-?[[:space:]]*'\''?[A-Za-z_]+'; then
  echo "Blocked: do not write files with cat > or heredocs in Bash. Use the Write tool instead. Bash output is for reading and running only." >&2
  exit 2
fi

exit 0
