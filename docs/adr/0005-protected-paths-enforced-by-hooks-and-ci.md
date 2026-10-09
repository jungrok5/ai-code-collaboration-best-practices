# ADR-0005: 보호 경로는 지시가 아니라 훅·CODEOWNERS·룰셋으로 강제

- 상태: Accepted
- 날짜: 2026-10-07

## 맥락

지시 파일은 에이전트에게 "컨텍스트"일 뿐 강제력이 없어요(Anthropic 문서). 에이전트가 비밀·락파일·정책 파일을 바꾸면 보안 사고나 CI 붕괴로 이어져요.

## 결정

PreToolUse 훅(`protect-files.sh`, `git-guard.sh`)이 로컬에서 막고, `CODEOWNERS`와 룰셋이 GitHub에서 사람 리뷰를 강제해요. Claude 액션은 PR 이벤트에서 `.claude/` 설정을 베이스 브랜치 것으로 복원해요. 보호 목록의 원본은 `protect-files.sh`이고 `AGENTS.md` "Things to know"에 요약해요. 목록을 바꾸면 플러그인 버전을 올려 배포해요.

## 결과

- 긍정: 모델이 지시를 무시해도 결정적으로 막힘.
- 부정: 정당한 변경도 사람이 직접 해야 함(의도된 마찰).
