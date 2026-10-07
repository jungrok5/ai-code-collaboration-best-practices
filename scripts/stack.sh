#!/usr/bin/env bash
# Stack-agnostic task runner used by the Makefile and CI.
# Usage: scripts/stack.sh <setup|lint|typecheck|test|build|detect>
# Detects the project type from manifest files and runs the conventional command.
# Add a real command to your project (package.json scripts, pyproject tools, ...)
# and this script will pick it up; unknown stacks print a notice and exit 0 so the
# template stays green until you add code.
set -euo pipefail

task="${1:-detect}"
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

detect() {
  if   [ -f package.json ];   then echo node
  elif [ -f pyproject.toml ]; then echo python
  elif [ -f go.mod ];         then echo go
  elif [ -f Cargo.toml ];     then echo rust
  else echo none; fi
}

node_pm() {
  if   [ -f pnpm-lock.yaml ]; then echo pnpm
  elif [ -f yarn.lock ];      then echo yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then echo bun
  else echo npm; fi
}

has_script() { jq -e --arg s "$1" '.scripts[$s] // empty' package.json >/dev/null 2>&1; }

run_node_script() {
  local s="$1" pm; pm="$(node_pm)"
  if has_script "$s"; then
    echo "+ $pm run $s"; "$pm" run "$s"
  else
    echo "(skip) package.json has no \"$s\" script"
  fi
}

py() { if command -v uv >/dev/null 2>&1; then uv run "$@"; else "$@"; fi; }

stack="$(detect)"
case "$task" in
  detect) echo "$stack"; exit 0 ;;
  setup)
    case "$stack" in
      node)   pm="$(node_pm)"; echo "+ $pm install"; case "$pm" in
                npm) npm ci 2>/dev/null || npm install ;;
                pnpm) pnpm install --frozen-lockfile 2>/dev/null || pnpm install ;;
                yarn) yarn install --immutable 2>/dev/null || yarn install ;;
                bun) bun install ;; esac ;;
      python) if command -v uv >/dev/null 2>&1; then uv sync; else python3 -m pip install -e ".[dev]" 2>/dev/null || python3 -m pip install -e .; fi ;;
      go)     go mod download ;;
      rust)   cargo fetch ;;
      none)   echo "(no stack detected: add package.json / pyproject.toml / go.mod / Cargo.toml)" ;;
    esac ;;
  lint)
    case "$stack" in
      node)   run_node_script lint; has_script format:check && run_node_script format:check || true ;;
      python) if command -v ruff >/dev/null 2>&1 || py ruff --version >/dev/null 2>&1; then py ruff check . && py ruff format --check .; else echo "(skip) ruff not installed"; fi ;;
      go)     gofmt -l . | tee /tmp/gofmt.out; test ! -s /tmp/gofmt.out; go vet ./... ;;
      rust)   cargo fmt --all -- --check && cargo clippy --all-targets -- -D warnings ;;
      none)   echo "(skip) no stack" ;;
    esac ;;
  typecheck)
    case "$stack" in
      node)   run_node_script typecheck ;;
      python) if py mypy --version >/dev/null 2>&1; then py mypy .; else echo "(skip) mypy not installed"; fi ;;
      go)     go build ./... ;;
      rust)   cargo check --all-targets ;;
      none)   echo "(skip) no stack" ;;
    esac ;;
  test)
    case "$stack" in
      node)   run_node_script test ;;
      python) if py pytest --version >/dev/null 2>&1; then py pytest -q; else echo "(skip) pytest not installed"; fi ;;
      go)     go test ./... ;;
      rust)   cargo test ;;
      none)   echo "(skip) no stack" ;;
    esac ;;
  build)
    case "$stack" in
      node)   run_node_script build ;;
      python) echo "(skip) python build not configured" ;;
      go)     go build ./... ;;
      rust)   cargo build ;;
      none)   echo "(skip) no stack" ;;
    esac ;;
  *) echo "unknown task: $task" >&2; exit 2 ;;
esac
