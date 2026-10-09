# ADR-0002: squash 머지 + Conventional Commits + AI 공동저자 트레일러 유지

- 상태: Accepted
- 날짜: 2026-10-07

## 맥락

AI 보조로 커밋 수가 늘고 메시지 품질이 일정하지 않습니다. 릴리스 노트 자동화(release-please)와 AI 기여 감사 추적이 필요합니다. 공동저자 트레일러에 대해서는 의견이 갈립니다(VS Code가 2026-05에 기본 표기를 되돌림).

## 고려한 선택지

1. merge commit 허용: 이력 보존 / 노이즈, commitlint 필요
2. rebase 머지: 선형 / 개별 커밋 품질 의존
3. **squash만**: PR 제목 = 커밋 제목, 룰셋의 커밋 패턴 검사 단순 / PR 내부 이력 소실
4. 트레일러 제거: 깔끔 / 감사 추적 상실

## 결정

squash 머지만 허용하고 PR 제목을 Conventional Commit 형식으로 강제합니다(`pr-checks.yml`, 룰셋 `commit_message_pattern`). Claude Code의 `attribution` 기본값(`Co-Authored-By: Claude <noreply@anthropic.com>`)을 유지하고, PR 본문의 AI 사용 표시와 `ai:assisted`/`ai:generated` 라벨로 출처를 이중 기록합니다. 릴리스는 release-please로 관리합니다.

## 결과

- 긍정: 깨끗한 `main`, 자동 CHANGELOG, AI 기여 측정 가능.
- 부정: 세밀한 커밋 이력은 PR에서만 볼 수 있음.
- 재검토: 조직이 커밋 서명을 요구하면 `required_signatures` + `use_commit_signing` 확인.
