# 13. AI 백엔드: API 키 없이 돌리는 세 가지 방법

## 0. 키가 필요한 곳

GitHub 호스티드 러너(`ubuntu-latest`)는 로그인 정보가 없는 일회용 VM이에요. 거기서 Claude Code를 실행하려면 자격증명을 넘겨야 해서, 공식 액션은 `ANTHROPIC_API_KEY`나 구독 토큰(`claude setup-token`)을 받아요.
개발자 PC에서는 `claude`에 이미 구독으로 로그인돼 있어서 키가 필요 없어요. 이 템플릿은 이 방식을 기본값으로 써요.

## 1. 세 가지 백엔드

| 백엔드 | 자격증명 | 실행 위치 | 켜는 법 | 비고 |
| --- | --- | --- | --- | --- |
| ① 개인 자리(기본) | 본인 claude.ai 로그인 | 개발자 PC | 없음. `make ai-*` | 구독 한도 사용. 가장 안전하고 품질이 가장 높음 |
| ② 로컬 LLM 서버 | 없음 | 사내 서버 + self-hosted 러너 | `gh variable set AI_BACKEND -b local` + `AI_BASE_URL`, `AI_MODEL` | llama.cpp / Ollama / LM Studio. 품질은 모델 의존. `infra/local-llm/` |
| ③ Anthropic API/구독 토큰 | `ANTHROPIC_API_KEY` 또는 `CLAUDE_CODE_OAUTH_TOKEN` | GitHub 호스티드 러너 | `gh variable set AI_BACKEND -b anthropic` + 시크릿 | 공식 액션 사용(추적 댓글, 인라인 리뷰, 안전한 push) |
| 없음 | — | — | `AI_BACKEND` 비움(기본) | AI 워크플로는 모두 `skipped`. CI·PR 검사·라벨·릴리스는 정상 |

`AI_BACKEND`는 레포 변수예요(Settings → Secrets and variables → Actions → Variables, 또는 `gh variable set`). 비어 있으면 AI 잡이 하나도 시작되지 않으니 실패할 일도 없어요.

## 2. ① 개인 자리에서 `claude -p`로 처리하기

```bash
make setup                       # 한 번. claude CLI가 없으면: npm i -g @anthropic-ai/claude-code && claude (로그인)
make ai-check                    # 어떤 백엔드를 쓰는지 표시

make ai-triage ISSUE=12          # 라벨·누락 항목·중복 제안 (dry run)
make ai-triage ISSUE=12 POST=1   # 라벨 적용 + 댓글 1개 (절대 닫지 않음)
make ai-review PR=34 POST=1      # 리뷰 코멘트 1개 (승인 안 함)
make ai-implement ISSUE=12       # 격리 worktree에서 테스트→구현→make check→커밋 (푸시 안 함)
make ai-implement ISSUE=12 POST=1  # + push + 초안 PR(ai:generated) + 이슈 ai:review
make ai-fix-ci PR=34 POST=1      # 실패 로그 분석 → 수정 PR 또는 진단 댓글
make ai-respond NUM=12 TEXT="왜 이렇게 했어?" POST=1
make ai-maintenance POST=1       # 주간 리포트 이슈
make ai-queue POST=1 LIMIT=3     # ai:ready 이슈를 순서대로 처리(내 자리가 에이전트 러너)
```

`scripts/ai/*.sh`가 `gh`로 GitHub를 읽고, 플러그인 스킬과 같은 절차를 프롬프트로 `claude -p`(헤드리스)에 넘기고, 결과를 다시 `gh`로 GitHub에 써요. 모델은 GitHub 토큰을 받지 않아요. 보호 경로·git 규칙 훅은 그대로 적용돼요. 기본은 dry run이고, `POST=1`일 때만 GitHub에 써요.

이 방법은 사람이 명령을 실행할 때만 돌아요. 이벤트에 자동으로 반응하려면 ②나 ③을 쓰세요.

## 3. ② 로컬 LLM 서버 + self-hosted 러너

llama.cpp(`/v1/messages`, 2026-01~)·Ollama(v0.14+) 설정, 환경 변수, 러너 등록, 문제 해결은 `infra/local-llm/README.md`에 있어요. 최소 설정은 다음과 같아요.

```bash
# 서버
llama-server -hf <GGUF repo:quant> --alias local-coder --port 8080 --jinja -c 65536
# 러너/개발자 환경
export ANTHROPIC_BASE_URL=http://127.0.0.1:8080 ANTHROPIC_AUTH_TOKEN=local ANTHROPIC_MODEL=local-coder
make ai-local-check
# GitHub
gh variable set AI_BACKEND -b local; gh variable set AI_BASE_URL -b http://127.0.0.1:8080; gh variable set AI_MODEL -b local-coder
```

`.github/workflows/ai-local-runner.yml` 하나가 이슈 생성(트리아지), `ai:ready`(구현), `@claude` 댓글(응답), PR(리뷰), CI 실패(수정), 주간 일정(리포트)을 받아 `scripts/ai/dispatch.sh`로 보내요. 쓰기 권한자의 요청과 같은 레포의 PR만 처리해요. 공식 액션 대신 스크립트를 쓰는 이유는 액션과 커스텀 베이스 URL 조합 문제가 아직 해결되지 않았기 때문이에요(#1089).

주의: Anthropic 문서는 Claude가 아닌 모델로 라우팅하는 것을 지원하지 않는다고 밝혀요. 로컬 모델은 툴 호출과 긴 컨텍스트에서 실수가 잦을 수 있어요. 트리아지·리뷰 요약·리포트에 먼저 쓰고, 구현은 사람이 ①로 돌리기를 권해요.

## 4. ③ Anthropic API 또는 구독 토큰(선택)

```bash
gh variable set AI_BACKEND -b anthropic
gh secret set CLAUDE_CODE_OAUTH_TOKEN   # claude setup-token 출력(개인 구독에 묶임), 또는
gh secret set ANTHROPIC_API_KEY         # 조직용. 정적 키가 싫으면 Workload Identity Federation(docs/05)
```

`claude*.yml` 워크플로가 공식 액션으로 동작해요(05 문서).

## 5. 팀 상황별 조합

| 팀 상황 | 권장 |
| --- | --- |
| 개인/소규모, 구독만 있음 | ①만. `make ai-queue`를 하루 한두 번 |
| 사내 GPU 서버 있음, 데이터 외부 전송 불가 | ② + ① (구현은 ①) |
| 조직 예산 있음, 자동 반응 원함 | ③ + ①(개발자 로컬) |
| 아직 결정 안 함 | 아무것도 설정하지 않음. 나머지 자동화는 전부 동작 |

## 출처

- Claude Code 게이트웨이/베이스 URL: https://code.claude.com/docs/en/llm-gateway , https://code.claude.com/docs/en/llm-gateway-connect
- 헤드리스 모드: https://code.claude.com/docs/en/headless
- llama.cpp Anthropic Messages API: https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp · Ollama: https://docs.ollama.com/api/anthropic-compatibility
- GitHub Actions 변수: https://docs.github.com/en/actions/learn-github-actions/variables · self-hosted 러너: https://docs.github.com/en/actions/hosting-your-own-runners
- claude-code-action 커스텀 베이스 URL 이슈: https://github.com/anthropics/claude-code-action/issues/1089
