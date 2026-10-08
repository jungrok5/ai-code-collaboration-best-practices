#!/usr/bin/env bash
# PreToolUse hook for Bash commands that run git (hooks.json: `if: Bash(git *)`).
# Enforces two team git rules deterministically:
#  - never commit directly on main/master/develop/release/*
#  - never force-push (--force, -f, --force-with-lease, +refspec) to anything but your own feature branch
set -uo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

protected='^(main|master|develop|release/.*)$'
feature='^(feat|fix|chore|docs|refactor|test|ci|perf)/'

current_branch() { # $1 = repo dir or empty
  local dir="${1:-.}"
  # symbolic-ref also works on an unborn branch (fresh repo with no commits)
  git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ''
}

# Look at each simple command separately (a && b; c | d), word-split on whitespace.
while IFS= read -r segment; do
  read -ra w <<<"$segment"
  i=0
  while [ "$i" -lt "${#w[@]}" ] && [ "${w[$i]}" != "git" ]; do i=$((i + 1)); done
  [ "$i" -lt "${#w[@]}" ] || continue
  i=$((i + 1))
  dir=""
  # global options before the subcommand: -C <dir>, -c <k=v>, --git-dir=..., etc.
  while [ "$i" -lt "${#w[@]}" ]; do
    case "${w[$i]}" in
      -C) dir="${w[$((i + 1))]:-}"; i=$((i + 2)) ;;
      -c) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  sub="${w[$i]:-}"
  args=("${w[@]:$((i + 1))}")
  branch="$(current_branch "$dir")"

  if [ "$sub" = "commit" ] && printf '%s' "$branch" | grep -Eq "$protected"; then
    echo "BLOCKED: you are on protected branch '$branch'. Create a feature branch first: git switch -c <type>/<issue>-<slug>" >&2
    exit 2
  fi

  if [ "$sub" = "push" ]; then
    force=0; positional=()
    for a in "${args[@]}"; do
      case "$a" in
        --force | --force-with-lease* | --force-if-includes) force=1 ;;
        --*) ;;
        -*f*) force=1 ;; # -f, -uf, -fu ...
        -*) ;;
        *) positional+=("$a") ;;
      esac
    done
    # positional[0] is the remote; the rest are refspecs. No refspec → the current branch.
    dests=()
    for ref in "${positional[@]:1}"; do
      case "$ref" in +*) force=1; ref="${ref#+}" ;; esac
      dst="${ref##*:}"; dst="${dst#refs/heads/}"
      [ "$dst" = "HEAD" ] && dst="$branch"
      dests+=("$dst")
    done
    [ "${#dests[@]}" -eq 0 ] && dests=("$branch")
    if [ "$force" = 1 ]; then
      for dst in "${dests[@]}"; do
        if printf '%s' "$dst" | grep -Eq "$protected" || ! printf '%s' "$dst" | grep -Eq "$feature"; then
          echo "BLOCKED: force-push is only allowed to your own feature branch (target: '$dst'). Merge instead of rewriting shared history." >&2
          exit 2
        fi
      done
    fi
  fi
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
