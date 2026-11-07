#!/bin/bash
# PreToolUse hook for Bash.
# - Blocks remote PR merges (the user merges PRs).
# - Blocks local git merge while on main/master (merge recovery flags are allowed).
# - Asks for approval on any other local git merge, showing source and target.

command=$(jq -r '.tool_input.command // ""')
# A command may start the line, follow a separator, or sit inside a group/substitution.
start='(^|[;&|(`{]|\$\()[[:space:]]*'
# gh global flags (e.g. -R owner/repo) may sit between `gh` and the subcommand.
gh_flags='([[:space:]]+-[^[:space:]]+([[:space:]]+[^[:space:]-][^[:space:]]*)?)*'

if printf '%s' "$command" | grep -Eq "${start}gh${gh_flags}[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)"; then
  echo "Blocked: PR merging is done by the user. Do not run the PR merge command." >&2
  exit 2
fi

if printf '%s' "$command" | grep -Eq "${start}gh${gh_flags}[[:space:]]+api[[:space:]].*pulls/[0-9]+/merge"; then
  # `gh api` defaults to GET (merge-status check); an explicit write method or body fields make it a merge.
  if printf '%s' "$command" | grep -Eiq '(-X|--method)[[:space:]=]*(PUT|POST|PATCH|DELETE)|[[:space:]](-f|-F|--field|--raw-field|--input)([[:space:]=]|$)'; then
    echo "Blocked: PR merging is done by the user. Do not call the merge API." >&2
    exit 2
  fi
fi

if printf '%s' "$command" | grep -Eq "${start}git[[:space:]]+merge([[:space:]]|$)"; then
  rest=${command#*git*merge}
  rest=$(printf '%s' "$rest" | sed -E 's/[;&|)].*//')

  source=""
  skip_quoted=""
  take_value=0
  set -f
  for word in $rest; do
    if [ -n "$skip_quoted" ]; then
      case "$word" in *"$skip_quoted") skip_quoted="" ;; esac
      continue
    fi
    if [ "$take_value" = 1 ]; then
      take_value=0
      case "$word" in
        \"*|\'*)
          q=${word:0:1}
          [ "${#word}" -gt 1 ] && case "$word" in *"$q") ;; *) skip_quoted=$q ;; esac
          ;;
      esac
      continue
    fi
    case "$word" in
      --abort|--quit|--continue) exit 0 ;;
      -m|--message|-F|--file|-s|--strategy|-X|--strategy-option|--into-name) take_value=1 ;;
      -*) ;;
      *) [ -z "$source" ] && source=$word ;;
    esac
  done
  set +f

  if ! target=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null) || [ -z "$target" ]; then
    echo "Blocked: cannot determine the current branch, so the merge target is unknown." >&2
    exit 2
  fi

  if [ "$target" = "main" ] || [ "$target" = "master" ]; then
    echo "Blocked: no local merges into $target (attempted: merge '${source:-?}' into '$target'). Merge via PR instead." >&2
    exit 2
  fi

  jq -n --arg r "Local merge: '${source:-?}' into '$target'. Approve?" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
fi

exit 0
