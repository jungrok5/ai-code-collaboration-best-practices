# 기여 가이드 (CONTRIBUTING)

이 저장소의 규칙은 `AGENTS.md` 한 곳에 있고, 사람과 AI 에이전트가 같은 규칙을 따라요. 이 문서는 처음 참여하는
사람을 위한 요약이에요.

## 1. 시작하기

```bash
git clone <repo> && cd <repo>
make setup          # 의존성, pre-commit 훅, Claude 플러그인, 설정 검증
make check          # 린트 + 글·UI 기준 + 타입체크 + 테스트 (커밋 전에 항상)
```

## 2. 작업 흐름

1. 이슈부터: 템플릿(Task / Bug / Feature)으로 이슈를 만들어요. 수용 기준(Acceptance criteria)이 테스트가 돼요.
2. 크기 가늠: 여러 모듈·레포에 걸치거나 영역이 모호하면 코드보다 1쪽 설계(`/design`, `docs/designs/`)를 작은 PR로
   먼저 머지해요. 시작 전에 `make overlap AREAS=...`(또는 `/check-overlap`)로 겹치는 작업이 있는지 봐요
   ([docs/14](docs/14-design-first-and-overlap.md)).
3. 브랜치: `<type>/<issue>-<slug>` (예: `feat/123-rate-limit`). `main`에 직접 커밋하지 않아요.
4. 작게: PR은 400줄 이하가 목표예요. 크면 `/split-pr`로 스택을 만들어요.
5. PR: 제목은 Conventional Commit, 본문은 템플릿(요약 / 변경 / 테스트 증거 / AI 사용 공개 / 체크리스트)을 따라요.
6. 리뷰: CI + AI 리뷰(참고용) 뒤에 사람(CODEOWNERS) 승인이 1명 이상 필요해요. 모든 리뷰 스레드에 답하고 다시
   리뷰를 요청해요.
7. 머지: squash만 써요. PR 제목이 커밋 제목이 되고, 브랜치는 자동으로 지워져요.

## 3. AI 도구를 쓸 때

- 에이전트에게 이슈 번호를 주고 `AGENTS.md`를 따르게 해요. Claude Code에서는 `/implement-issue 123`, 터미널에서는
  `make ai-implement ISSUE=123`(본인 구독 로그인, API 키 불필요).
- AI가 쓴 코드는 본인이 모두 읽고 이해한 뒤 PR을 올려요. PR 본문의 AI 사용 공개 항목은 꼭 체크해요.
- 보호 경로(`.env*`, 락파일, CODEOWNERS, 룰셋, `.claude/settings.json`)는 사람이 직접 고쳐요.
- 테스트를 끄거나 건너뛰어서 CI를 초록으로 만들지 않아요. 원인을 고치거나 이슈를 열어요.
- 사람이 읽는 글과 화면은 [docs/17](docs/17-writing-and-design-standards.md)을 따라요. `make style`이 기계로 잡을 수
  있는 부분을 검사해요.

## 4. 커밋 메시지

`<type>(<scope>): <summary> (#<issue>)` 형식이고, 본문에는 왜 바꿨는지를 적어요. AI 도구가 붙이는 `Co-Authored-By`
트레일러는 남겨 둬요(감사 추적용).

## 5. 질문

`SUPPORT.md`를 보거나 Discussions에 올려 주세요. 보안 문제는 `SECURITY.md`의 비공개 경로로만 알려 주세요.
