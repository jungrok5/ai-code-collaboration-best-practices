#!/usr/bin/env bash
# Create a new product repository from this template and bootstrap it.
#   scripts/new-repo.sh <owner>/<name> [--private|--public|--internal] [--template owner/template] [--dir path]
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <owner>/<name> [--private|--public|--internal] [--template owner/template] [--dir path]" >&2; exit 2; }
NAME="$1"; shift
VIS="--private"; TEMPLATE=""; DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --private|--public|--internal) VIS="$1"; shift ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
command -v gh >/dev/null || { echo "gh is required (https://cli.github.com)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login"; exit 1; }

if [ -z "$TEMPLATE" ]; then
  TEMPLATE="$(git -C "$(dirname "$0")/.." remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##' || true)"
fi
[ -n "$TEMPLATE" ] || { echo "cannot determine template repo; pass --template owner/repo"; exit 1; }
DIR="${DIR:-$(basename "$NAME")}"

echo "Creating $NAME from template $TEMPLATE ($VIS) ..."
gh repo create "$NAME" --template "$TEMPLATE" "$VIS" --clone --description "Created from $TEMPLATE"
cd "$DIR"
# GitHub needs a moment to materialise template contents
for _ in 1 2 3 4 5; do [ -f AGENTS.md ] && break; sleep 2; git pull -q origin HEAD 2>/dev/null || true; done

scripts/bootstrap.sh --mode project --marketplace "$TEMPLATE" --yes
if git status --porcelain | grep -q .; then
  git add -A && git commit -qm "chore: bootstrap repository from template ($TEMPLATE)" && git push -q
fi
scripts/setup-github.sh all || echo "(setup-github reported problems; re-run: make github-setup)"
echo
echo "Done: https://github.com/$NAME"
echo "Remaining manual steps: add ANTHROPIC_API_KEY secret, install the Claude GitHub App, edit the AGENTS.md Project section and CODEOWNERS."
