# 기여 가이드 (CONTRIBUTING)

이 저장소의 규칙은 `AGENTS.md` 한 곳에 있으며, 사람과 AI 에이전트가 같은 규칙을 따릅니다. 이 문서는 처음 참여하는
사람을 위한 요약입니다.

## 1. 시작하기

```bash
git clone <repo> && cd <repo>
make setup          # 의존성, pre-commit 훅, Claude 플러그인, 설정 검증
make check          # 린트 + 글·UI 기준 + 타입체크 + 테스트 (커밋 전에 항상)
```

## 2. 작업 흐름

1. 이슈 작성: 템플릿(Task / Bug / Feature)으로 이슈를 만듭니다. 수용 기준(Acceptance criteria)이 테스트의 기준이
   됩니다.
2. 크기 판단: 여러 모듈·레포에 걸치거나 영역이 모호한 작업은 코드보다 1쪽 설계(`/design`, `docs/designs/`)를 작은
   PR로 먼저 머지합니다. 시작 전에 `make overlap AREAS=...`(또는 `/check-overlap`)로 겹치는 작업이 있는지
   확인합니다([docs/14](docs/14-design-first-and-overlap.md)).
3. 브랜치: `<type>/<issue>-<slug>` (예: `feat/123-rate-limit`). `main`에는 직접 커밋하지 않습니다.
4. PR 크기: 400줄 이하가 목표입니다. 이보다 크면 `/split-pr`로 스택을 구성합니다.
5. PR 작성: 제목은 Conventional Commit, 본문은 템플릿(요약 / 변경 / 테스트 증거 / AI 사용 공개 / 체크리스트)을
   따릅니다.
6. 리뷰: CI와 AI 리뷰(참고용) 뒤에 사람(CODEOWNERS) 승인이 1명 이상 필요합니다. 모든 리뷰 스레드에 답한 뒤 다시
   리뷰를 요청합니다.
7. 머지: squash만 사용합니다. PR 제목이 커밋 제목이 되며, 브랜치는 자동으로 삭제됩니다.

## 3. AI 도구 사용 시

- 에이전트에게 이슈 번호를 전달하고 `AGENTS.md`를 따르도록 지시합니다. Claude Code에서는 `/implement-issue 123`,
  터미널에서는 `make ai-implement ISSUE=123`(본인 구독 로그인, API 키 불필요)을 사용합니다.
- AI가 작성한 코드는 모두 읽고 이해한 뒤 PR을 올립니다. PR 본문의 AI 사용 공개 항목은 반드시 체크하십시오.
- 보호 경로(`.env*`, 락파일, CODEOWNERS, 룰셋, `.claude/settings.json`)는 사람이 직접 수정합니다.
- 테스트를 끄거나 건너뛰어 CI를 통과시키지 않습니다. 원인을 수정하거나 이슈를 등록합니다.
- 사람이 읽는 글과 사람이 사용하는 화면은 [docs/17](docs/17-writing-and-design-standards.md)을 따릅니다. 기계적으로
  판별할 수 있는 부분은 `make style`이 검사합니다.

## 4. 커밋 메시지

형식은 `<type>(<scope>): <summary> (#<issue>)`이며, 본문에는 변경 이유를 적습니다. AI 도구가 추가하는
`Co-Authored-By` 트레일러는 삭제하지 않습니다(감사 추적용).

## 5. 질문

`SUPPORT.md`를 참고하거나 Discussions에 등록하십시오. 보안 문제는 `SECURITY.md`의 비공개 경로로만 제보하십시오.
