# 기여 가이드 (CONTRIBUTING)

이 저장소의 규칙은 **`AGENTS.md`** 한 곳에 있습니다. 사람과 AI 에이전트 모두 같은 규칙을 따릅니다.
아래는 처음 참여하는 사람을 위한 요약입니다.

## 1. 시작하기

```bash
git clone <repo> && cd <repo>
make setup          # 의존성, pre-commit 훅, Claude 플러그인, 설정 검증
make check          # 린트 + 타입체크 + 테스트 (커밋 전에 항상)
```

## 2. 작업 흐름

1. **이슈부터**: 템플릿(Task / Bug / Feature)으로 이슈를 만듭니다. 수용 기준(Acceptance criteria)이 테스트가 됩니다.
2. **브랜치**: `<type>/<issue>-<slug>` (예: `feat/123-rate-limit`). `main`에 직접 커밋하지 않습니다.
3. **작게**: PR은 400줄 이하를 목표로 합니다. 크면 `/split-pr`로 스택을 만듭니다.
4. **PR**: 제목은 Conventional Commit, 본문은 템플릿(요약 / 변경 / 테스트 증거 / **AI 사용 공개** / 체크리스트).
5. **리뷰**: CI + AI 리뷰(참고용) → 사람(CODEOWNERS) 승인 1명 이상. 모든 리뷰 스레드에 답하고 재요청합니다.
6. **머지**: squash만. PR 제목이 커밋 제목이 됩니다. 브랜치는 자동 삭제됩니다.

## 3. AI 도구를 쓸 때

- 에이전트에게 이슈 번호를 주고 `AGENTS.md`를 따르게 합니다. Claude Code는 `/implement-issue 123`.
- AI가 작성한 코드는 **본인이 모두 읽고 이해한 뒤** PR을 올립니다. PR 본문의 AI 공개 항목을 반드시 체크합니다.
- 보호 경로(`.env*`, 락파일, CODEOWNERS, 룰셋, `.claude/settings.json`)는 사람이 직접 수정합니다.
- 테스트를 끄거나 건너뛰어 CI를 초록으로 만들지 않습니다. 원인을 고치거나 이슈를 엽니다.

## 4. 커밋 메시지

`<type>(<scope>): <summary> (#<issue>)` — 본문에는 *왜*를 적습니다. AI 도구가 붙이는 `Co-Authored-By` 트레일러는 유지합니다(감사 추적).

## 5. 질문

`SUPPORT.md`를 보거나 Discussions에 올려 주세요. 보안 문제는 `SECURITY.md`의 비공개 경로로만 보고합니다.
