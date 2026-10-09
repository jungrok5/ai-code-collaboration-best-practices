# 로컬 LLM 백엔드 (API 키 없이 서버에서 에이전트 실행)

이 템플릿의 AI 자동화는 세 가지 백엔드 중 하나를 선택해 사용하며, 백엔드를 설정하지 않을 수도 있습니다(`docs/13-ai-backends.md`).

| 백엔드 | 비용·키 | 어디서 | 설정 |
| --- | --- | --- | --- |
| 개인 자리(기본) | 본인 claude.ai 구독 로그인, 키 없음 | 개발자 PC | `make setup` 후 `make ai-review PR=12` 등 |
| 로컬 LLM 서버 | 없음(하드웨어만) | 사내 서버 + self-hosted 러너 | 이 문서 |
| Anthropic API / 구독 토큰 | 키 또는 `claude setup-token` | GitHub 호스티드 러너 | `gh variable set AI_BACKEND -b anthropic` + 시크릿 |

> Claude Code는 `ANTHROPIC_BASE_URL`로 Anthropic Messages API 호환 서버를 지정할 수 있습니다.
> llama.cpp(2026-01 `/v1/messages` 추가), Ollama(v0.14+), LM Studio(0.4.1+)가 이 형식을 지원합니다.
> 단, Anthropic 공식 문서는 "비-Claude 모델로 Claude Code를 라우팅하는 것은 지원하지 않는다"고 명시합니다.
> 품질과 툴 호출 안정성은 모델마다 크게 다릅니다. 트리아지·리뷰 요약·리포트부터 적용하고 구현(implement)은 사람이 자기 자리에서 실행하는 방식을 권장합니다.

## 1. llama.cpp (권장: GPU 서버)

```bash
# 모델 예시(교체 가능): 툴 호출이 되는 코딩 모델 + 32K 이상 컨텍스트
llama-server -hf unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_M \
  --alias local-coder --host 0.0.0.0 --port 8080 --jinja -c 65536
# --jinja: 툴 호출(function calling)에 필요. --api-key K 를 지정하면 아래 토큰도 K로 설정.
```

Docker 환경에서는 `docker compose up -d`를 실행합니다(이 디렉터리의 `docker-compose.yml`, `local-llm.env.example` 참고).

Claude Code 쪽 환경 변수는 다음과 같습니다.

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:8080
export ANTHROPIC_AUTH_TOKEN=local          # 서버가 키를 검사하지 않으면 아무 값
export ANTHROPIC_MODEL=local-coder          # --alias 와 동일
export ANTHROPIC_DEFAULT_SONNET_MODEL=local-coder ANTHROPIC_DEFAULT_HAIKU_MODEL=local-coder ANTHROPIC_DEFAULT_OPUS_MODEL=local-coder
export CLAUDE_CODE_SUBAGENT_MODEL=local-coder
scripts/ai/local-llm-check.sh               # /v1/messages 호출 + claude -p 스모크 테스트
```

## 2. Ollama (권장: 개인 워크스테이션)

```bash
ollama pull qwen3-coder            # 또는 gpt-oss:20b, glm-4.7 등
export ANTHROPIC_BASE_URL=http://localhost:11434
export ANTHROPIC_AUTH_TOKEN=ollama # 필수지만 무시됨
claude --model qwen3-coder         # 또는: ollama launch claude
```

Ollama 문서에 따르면 `/v1/messages`는 스트리밍·툴 호출·thinking·base64 이미지를 지원하며 프롬프트 캐싱·토큰 카운트는 지원하지 않습니다. 30B급 모델에는 VRAM 24GB 이상, 컨텍스트 32K 이상을 권장합니다.

## 3. GitHub Actions에서 쓰기 (self-hosted 러너)

1. 로컬 LLM이 실행 중인 서버(또는 같은 네트워크)에 [self-hosted 러너](https://docs.github.com/en/actions/hosting-your-own-runners)를 등록합니다. 라벨은 `self-hosted`, `ai`입니다.
   러너 머신에 `claude`(`npm i -g @anthropic-ai/claude-code`), `gh`, `jq`, `git`, `make`를 설치합니다.
2. 레포 변수와 시크릿(선택)을 설정합니다.

   ```bash
   gh variable set AI_BACKEND -b local
   gh variable set AI_BASE_URL -b http://127.0.0.1:8080     # 러너에서 보이는 주소
   gh variable set AI_MODEL -b local-coder
   gh secret set AI_AUTH_TOKEN -b local                      # 서버가 키를 요구할 때만 실제 값
   gh secret set AI_GH_TOKEN                                 # 선택: App/PAT 토큰. 에이전트 PR에 CI가 돌게 하려면 필요
   ```

3. `.github/workflows/ai-local-runner.yml`이 이슈·PR·댓글·CI 실패·주간 일정 이벤트를 받아 `scripts/ai/dispatch.sh`로 전달합니다. 이 워크플로는 쓰기 권한자의 요청과 같은 레포의 PR만 처리합니다.

보안: self-hosted 러너는 레포 코드를 실행합니다. 워크플로 조건이 포크 PR과 쓰기 권한이 없는 사용자의 요청을 제외합니다. 그래도 공개 레포에서는 별도로 격리한 러너(일회용 컨테이너)를 사용하십시오.

## 4. 백엔드 없이 쓰기

`AI_BACKEND` 변수를 비워 두면 모든 AI 워크플로가 `skipped`로 끝납니다(실패 아님). CI·PR 검사·라벨·릴리스 등 나머지는 그대로 동작합니다. 사람은 언제든 자기 자리에서 `make ai-*`를 실행할 수 있습니다.

## 5. 문제 해결

| 증상 | 원인/대응 |
| --- | --- |
| `claude`가 로그인 화면을 띄움 | `ANTHROPIC_AUTH_TOKEN`(또는 `ANTHROPIC_API_KEY`)이 비어 있음. 둘 중 하나를 아무 값으로라도 설정 |
| 401 | 서버를 `--api-key`로 띄웠는데 토큰이 다름. `ANTHROPIC_AUTH_TOKEN`과 `ANTHROPIC_API_KEY`를 같은 값으로 |
| 모델을 못 찾음 | `ANTHROPIC_MODEL`/`--model`이 서버 alias와 다름. llama.cpp는 `--alias`, Ollama는 `ollama cp <model> <alias>` |
| 툴 호출이 깨짐 | llama.cpp는 `--jinja` 필수, 툴 지원 모델 필요. 컨텍스트 32K 이상 |
| 느림 | 양자화 낮추기(Q4_K_M), 컨텍스트 줄이기, `AI_MAX_TURNS` 낮추기 |
| "Ignoring N permissions.allow entries… workspace has not been trusted" | 헤드리스 실행은 신뢰하지 않은 체크아웃의 프로젝트 권한 규칙을 무시함(스크립트는 `--allowedTools`를 직접 넘기므로 동작에는 지장 없음). 러너 워크플로는 `~/.claude.json`에 trust 플래그를 설정함. 개인 PC는 해당 디렉터리에서 `claude`를 한 번 실행해 수락 |
| 액션(`anthropics/claude-code-action`)이 403 | 액션 + 커스텀 베이스 URL 조합은 미해결 이슈(#1089). 로컬 모드는 액션 대신 `scripts/ai/*`를 씀 |

## 출처

- llama.cpp Anthropic Messages API: https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp · 서버 README: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama Anthropic 호환: https://docs.ollama.com/api/anthropic-compatibility · 블로그: https://registry.ollama.ai/blog/claude
- Claude Code 게이트웨이 문서: https://code.claude.com/docs/en/llm-gateway , https://code.claude.com/docs/en/llm-gateway-connect
- claude-code-action 이슈 #1089: https://github.com/anthropics/claude-code-action/issues/1089
