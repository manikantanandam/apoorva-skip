#!/bin/bash
# PreToolUse hook for Bash. Blocks shell-based file writes (redirects, heredocs,
# tee, sed -i, scripted writes) so files are created/edited with Write/Edit instead.
# Redirects into /tmp or /private/tmp (scratchpad) and /dev/null are allowed.

command=$(jq -r '.tool_input.command // ""')

# Drop harmless redirects before checking for file-writing redirects.
stripped=$(printf '%s' "$command" | sed -E \
  -e 's/[0-9]?>>?[[:space:]]*&[0-9-]+//g' \
  -e 's#[0-9]?>>?[[:space:]]*/dev/null##g' \
  -e 's#[0-9]?>>?[[:space:]]*(/private)?/tmp/[^[:space:]]*##g')

block() {
  echo "Blocked: $1. Do not write or modify files from Bash; use the Write/Edit tools. Bash is for reading and running only." >&2
  exit 2
}

# heredocs / here-strings
printf '%s' "$command" | grep -Eq '<<-?[[:space:]]*'\''?"?[A-Za-z_]+' && block "heredoc"
# output redirection to a file (cat >, echo >, printf >>, bare > file)
printf '%s' "$stripped" | grep -Eq '(^|[[:space:]])[0-9]?>>?[[:space:]]*[^&[:space:]>]' && block "output redirection to a file"
# tee, in-place edits, dd, install/cp-style writes via scripting
printf '%s' "$stripped" | grep -Eq '(^|[|;&[:space:]])tee([[:space:]]|$)' && block "tee"
printf '%s' "$stripped" | grep -Eq '(^|[|;&[:space:]])(sed|perl|gsed)[[:space:]].*(-i|--in-place)' && block "in-place sed/perl edit"
printf '%s' "$stripped" | grep -Eq '(^|[[:space:]])dd[[:space:]].*of=' && block "dd of="
# scripted writes from python/node/ruby/perl
printf '%s' "$stripped" | grep -Eq '(python[0-9.]*|node|ruby|perl|osascript)[[:space:]].*(open\(|write|writeFile|File\.|\.write_text|fs\.)' && block "scripted file write"

exit 0
