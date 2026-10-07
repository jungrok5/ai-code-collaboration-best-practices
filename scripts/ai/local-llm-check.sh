#!/usr/bin/env bash
# Verify that a local LLM / gateway speaks the Anthropic Messages API and that Claude Code can use it.
# Usage: ANTHROPIC_BASE_URL=http://host:8080 [AI_MODEL=alias] scripts/ai/local-llm-check.sh
set -euo pipefail
# shellcheck source=scripts/ai/common.sh
. "$(dirname "$0")/common.sh"
ai_need curl jq
base="${ANTHROPIC_BASE_URL:?set ANTHROPIC_BASE_URL (e.g. http://127.0.0.1:8080 for llama-server, http://127.0.0.1:11434 for Ollama)}"
model="${AI_MODEL:-${ANTHROPIC_MODEL:-}}"
token="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-local}}"
ai_log "POST $base/v1/messages (model: ${model:-<server default>})"
payload="$(jq -cn --arg m "${model:-default}" '{model:$m, max_tokens:32, messages:[{role:"user", content:"Reply with the single word OK."}]}')"
resp="$(curl -sS --max-time 120 "$base/v1/messages" -H "content-type: application/json" -H "anthropic-version: 2023-06-01" -H "x-api-key: $token" -H "authorization: Bearer $token" -d "$payload" || true)"
if printf '%s' "$resp" | jq -e '.content[0].text' >/dev/null 2>&1; then
  ai_log "endpoint OK: $(printf '%s' "$resp" | jq -r '.content[0].text' | head -c 80)"
else
  ai_warn "unexpected response: $(printf '%s' "$resp" | head -c 300)"; exit 1
fi
if command -v claude >/dev/null 2>&1; then
  ai_log "claude -p smoke test via $(ai_backend)"
  AI_MAX_TURNS=1 AI_PERMISSION_MODE=dontAsk AI_ALLOWED_TOOLS="" ai_run "Reply with the single word OK." || { ai_warn "claude could not use the endpoint (see infra/local-llm/README.md troubleshooting)"; exit 1; }
fi
ai_log "local LLM backend works"
