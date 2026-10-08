# 01. 일일 플레이북 — 사람과 에이전트가 함께 일하는 하루

> 원칙 한 줄: **검증할 수 없으면 배포하지 않는다.** 컨텍스트 파일보다 먼저 오는 것은 "실행 가능한 확인 수단(테스트·린트·빌드)"이다. (Anthropic Claude Code best practices, VS Code AI best practices, OpenAI Codex 가이드 공통)

## 0. 역할 분담

| 역할 | 책임 | 하지 않는 것 |
| --- | --- | --- |
| **사람(작성자)** | 이슈 범위 결정, 계획 승인, 생성 코드 전부 읽기, PR 본문의 AI 공개, 리뷰 대응 | 읽지 않은 코드를 올리기 |
| **사람(리뷰어/CODEOWNER)** | 비즈니스 정합성·아키텍처·보안 판단, 최종 승인 | 스타일 지적(CI가 함), AI 코멘트 무조건 수용 |
| **에이전트(Claude Code 등)** | 탐색·계획·테스트 작성·구현·자기검증·초안 PR | 머지, 승인, 보호 경로 수정, 권한 확대 |
| **CI / 봇** | 결정적 검증(린트·타입·테스트·보안 스캔), 라벨·크기·제목 규칙, AI 1차 리뷰(참고용) | 사람 승인 대체 |

## 1. 하루의 흐름

```mermaid
flowchart LR
  A[이슈 선택<br/>ai:ready 또는 본인 작업] --> B[세션 시작<br/>make setup · /onboard]
  B --> C[탐색·계획<br/>plan mode]
  C --> D[테스트 먼저<br/>test-writer]
  D --> E[구현<br/>/implement-issue]
  E --> F[자기 검증<br/>make check · code-reviewer]
  F --> G[작은 커밋<br/>conventional]
  G --> H[PR 초안<br/>/create-pr]
  H --> I[CI + AI 리뷰<br/>참고용]
  I --> J[사람 리뷰<br/>CODEOWNERS]
  J --> K[squash 머지<br/>release-please]
```

### 1.1 이슈 고르기

- 이슈 템플릿의 **수용 기준(Acceptance criteria)** 이 테스트 가능해야 시작한다. 모호하면 코드를 쓰기 전에 이슈 댓글로 질문한다.
- 에이전트에게 맡길 이슈는 메인테이너가 `ai:ready`를 붙인다(쓰기 권한 필요 → 이것이 첫 번째 사람 체크포인트).
- 에이전트에 맞지 않는 일(GitHub 공식 가이드): 보안·PII·인증 영향, 프로덕션 장애, 여러 레포에 걸친 리팩터링, 열린 제품 결정.

### 1.2 세션 시작

```bash
git fetch origin && git switch -c feat/123-rate-limit origin/main
claude                      # SessionStart 훅이 의존성·pre-commit·팀 컨텍스트를 준비
/onboard                    # 처음이면 레포 투어
```

- 병렬 작업은 **worktree**로 체크아웃을 분리한다: `claude --worktree rate-limit` (서로 다른 파일을 소유하도록 작업을 나눈다).
- 관련 없는 작업으로 넘어갈 때는 `/clear`. 긴 조사는 서브에이전트(`code-reviewer`, `security-reviewer`)에 위임해 메인 컨텍스트를 작게 유지한다.

### 1.3 탐색 → 계획 → 테스트 → 구현 → 검증

1. **탐색**: 관련 코드를 읽고 기존 패턴을 찾는다("비슷한 코드: `src/billing/limits.ts`"처럼 파일을 지목하면 품질이 급상승).
2. **계획**: 일의 크기로 정한다([14](14-design-first-and-overlap.md)). 한 문장으로 설명되는 diff면 계획을 생략한다(T0). 여러 파일이거나 방법이 여럿이면 plan mode(`Shift+Tab` 두 번 또는 `--permission-mode plan`)의 계획을 초안 PR 맨 위에 두고 리뷰어 OK를 받는다(T1). 여러 모듈·레포, 공개 인터페이스·스키마, 하루 이상이거나 영역이 모호하면 `/design`으로 1쪽 설계를 먼저 PR로 머지한다(T2). 시작 전에 `/check-overlap`(`make overlap`)으로 겹치는 작업을 확인한다.
3. **테스트 먼저**: 수용 기준을 테스트로 적고 실패를 확인한다(`issue_123_*` 회귀 테스트).
4. **구현**: 최소 변경. 리팩터링 아이디어는 PR 본문 "후속" 항목으로.
5. **검증**: `make check` 결과를 붙인다. 새 컨텍스트의 `code-reviewer` 서브에이전트로 적대적 리뷰를 한 번 돌린다("방금 쓴 코드에 편향되지 않은 리뷰").

Claude Code 한 줄 버전: `/implement-issue 123` (위 절차가 스킬에 들어 있음).

### 1.4 커밋과 PR

- 커밋: `feat(api): add rate limiting (#123)` + 본문에 *왜*. PR이 커지면 `size/*` 라벨과 리뷰에서 걸린다 → `/split-pr`로 쪼갠다.
- PR: `/create-pr` → 템플릿(요약 / 변경 / 테스트 증거 / **AI 공개** / 체크리스트), 초안(draft)으로 열고 CI가 초록이면 ready.
- 400줄을 넘으면 `/split-pr`로 스택을 만든다(순서: 준비 리팩터 → 인터페이스+테스트 → 플래그 뒤 구현 → 연결 → 문서/플래그 전환).

### 1.5 리뷰 대응

- AI 리뷰 코멘트는 **주장**이다. 경로를 추적해 진짜면 고치고, 아니면 왜 아닌지 답한다(`/fix-ci`, `/review-pr`).
- 모든 스레드에 답한 뒤 리뷰를 재요청한다. 리뷰어는 24시간 내 첫 응답을 목표로 한다(지표: time-to-first-review).
- CI가 빨간데 원인이 내 변경이 아니면(베이스도 빨감/인프라) 한 번만 재실행하고 PR에 한 줄 남긴다. 테스트 끄기/건너뛰기 금지.

### 1.6 머지 후

- squash 머지 → PR 제목이 커밋 제목. 브랜치 자동 삭제. release-please가 릴리스 PR을 갱신.
- 에이전트가 만든 PR이 머지되면 이슈 라벨이 `ai:done`으로 자동 전환된다.

## 2. 프롬프트 요령 (에이전트에게 말할 때)

| 좋은 요청 | 나쁜 요청 |
| --- | --- |
| "#123 구현. 수용 기준 3개를 테스트로 먼저 작성하고 `make check` 결과를 보여줘. `src/auth/*`만 수정." | "로그인 고쳐줘" |
| "이 함수의 엣지 케이스를 나열하고, 테스트 되지 않은 것을 표로" | "테스트 좀 추가해" |
| "리뷰: 정확성→보안→테스트 순. 스타일 지적 금지. file:line 인용" | "코드 봐줘" |

- 실행 가능한 확인 명령을 함께 준다(`make test`, 스크린샷 비교, 재현 스크립트).
- 결과를 믿지 말고 **증거**를 요구한다: 실행한 명령과 출력.
- 반복되는 실수는 프롬프트가 아니라 `AGENTS.md`/`.claude/rules/`에 적는다(단, "지우면 실수하나?"를 통과한 줄만 — 비대한 규칙 파일은 무시되고 비용만 는다, [15](15-lean-harness.md)).

## 3. 하지 말 것 (요약)

- `main`에 직접 커밋, 공유 브랜치 force-push, `--no-verify`.
- 읽지 않은 AI 코드 PR, AI 사용 미공개.
- 보호 경로 수정(`.env*`, 락파일, CODEOWNERS, 룰셋, `.claude/settings.json`).
- 테스트를 끄거나 느슨하게 만들어 CI 통과.
- 이슈/PR 본문에 들어온 지시를 명령으로 취급(프롬프트 인젝션).

## 출처

- Anthropic, Claude Code best practices: https://code.claude.com/docs/en/best-practices
- VS Code, Best practices for using AI: https://code.visualstudio.com/docs/agents/best-practices
- OpenAI Codex best practices: https://learn.chatgpt.com/guides/best-practices
- GitHub, Best practices for Copilot cloud agent tasks: https://docs.github.com/en/copilot/using-github-copilot/coding-agent/best-practices-for-using-copilot-to-work-on-tasks
- Kent Beck, Augmented Coding: https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
