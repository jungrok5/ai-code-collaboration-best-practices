# 06. 코드 리뷰 정책: AI는 1차 참고, 결정은 사람이

## 1. 원칙

1. AI 리뷰는 참고(advisory)로 시작합니다. 2–4주 보정한 뒤 신호 품질이 확인된 보안·정확성 카테고리만 필수 체크로 승격합니다. 스타일은 승격하지 않습니다. 처음부터 blocking으로 두면 오탐이 누적되어 팀이 봇을 신뢰하지 않게 됩니다. "참고용 리뷰는 아무것도 강제하지 않는다"는 반론(Codacy)도 있습니다. 따라서 강제해야 하는 기준은 결정적 도구(린트·타입·테스트·CodeQL)로 CI에 넣습니다.
2. AI 승인은 승인으로 인정하지 않습니다. Copilot 기본값과 Claude Code Review 모두 승인으로 집계되지 않으며, 사람 CODEOWNER 1명 이상의 승인이 필요합니다.
3. 에이전트 커밋에는 사람 검토를 추가로 요구합니다. `agent-approval-check`가 에이전트 커밋을 포함한 PR에 사람 승인 N명(기본 1, 권장 2)을 요구합니다. GitHub 룰셋에는 "attribution 없는 Copilot PR에 추가 승인 요구"가 기본으로 켜져 있습니다.
4. 작성자는 자기 코드를 전부 읽습니다. AI가 작성했더라도 설명하지 못하는 줄은 올리지 않습니다(Simon Willison이 구분한 vibe coding과 agentic engineering의 경계). PR 본문에는 AI 사용 여부를 반드시 밝힙니다.
5. 리뷰어 피로는 구조로 방지합니다. PR은 400줄 이하, 첫 리뷰는 24시간 SLO로 운영합니다. 스타일 검사는 CI가 담당하고 리뷰 봇은 하나로 시작합니다.

## 2. 리뷰 체크리스트(REVIEW.md 요약)

| 순서 | 항목 | 블로킹 기준 |
| --- | --- | --- |
| 1 | 범위·크기 | 이슈와 다른 변경, 400줄 초과 사유 없음 |
| 2 | 정확성 | 로직 오류, 경계값, null, 경쟁 조건, 에러 처리, 자원 정리 |
| 3 | 테스트 | 수용 기준 미커버, 구현 세부에 결합, skip/disable |
| 4 | 보안 | 인젝션, 인가 누락, 비밀 노출, SSRF/경로 탐색, 위험한 의존성, Actions 하드닝 |
| 5 | 호환성 | 공개 API/스키마/설정/마이그레이션 비호환, 플래그·ADR 없음 |
| 6 | 가독성·관례 | 모듈 패턴 위반, 중복, *왜*가 없는 주석 |
| 7 | 문서·운영 | README/ADR/CHANGELOG 누락, 로깅·지표 없음 |

AI 코멘트는 주장부터 검증합니다. 지적한 경로가 실제로 발생하면 수정하고 발생하지 않으면 스레드에 근거를 적고 resolve합니다. 보안 finding은 사람이 결정할 때까지 열어 둡니다.

## 3. 리뷰 봇 고르기

| 봇 | 승인 집계 | 설정 파일 | 비용(2026-10) | 강점 |
| --- | --- | --- | --- | --- |
| Claude (이 레포 `claude-code-review.yml`) | 불가(인라인+요약만) | 워크플로 프롬프트, `REVIEW.md`, `AGENTS.md` | API 토큰 사용량 | 레포 규칙에 맞춘 프롬프트, 도구 제한 가능 |
| Claude Code Review(관리형, Team/Enterprise) | 불가(neutral check) | `CLAUDE.md`, `REVIEW.md` | 리뷰당 $15–25(크레딧) | 다중 에이전트, `@claude review` |
| Copilot code review | 옵션(기본 미집계) | `copilot-instructions.md`, `*.instructions.md`, `REVIEW.md` | Lite $0.05–1, Balanced $0.25–5/리뷰(크레딧) | 룰셋 자동 요청, 플랫폼 내장 |
| CodeRabbit | `request_changes_workflow` 옵션 | `.coderabbit.yaml` | $24–72/개발자/월, 공개 레포 무료 | 린터 통합, 요약/워크스루 |
| Codex | 리뷰 코멘트 | `AGENTS.md` Code Review Rules | ChatGPT 플랜 | P0/P1 집중 |
| Gemini Code Assist | 리뷰 코멘트 | `.gemini/config.yaml` | 엔터프라이즈 시트 | 소비자용 종료(2026-07) |
| Cursor Bugbot | 리뷰 코멘트 | `.cursor/BUGBOT.md` | 사용량 | "Fix in Cursor" |

권장 조합은 Claude(또는 Copilot) 1개 + CodeQL/linters(결정적)입니다. 봇을 추가할 때마다 소음 대비 수정률을 2주 동안 측정합니다.

## 4. 승격 기준(advisory → required)

- 4주 동안 봇 코멘트 중 수정으로 이어진 비율 ≥ 30%, 오탐 불만 < 10%
- 승격 대상: `security`, `correctness` 카테고리만. 구현 방법은 봇 결과를 `--json-schema`로 받아 심각도가 high 이상일 때만 실패하는 별도 잡 추가. 현재 워크플로는 neutral

## 5. 자동 머지 (선택, 기본 꺼짐)

다음 조건이 모두 참일 때만 자동 머지합니다: `risk/low` 라벨(사람이 부여) ∧ CI 초록 ∧ 사람 승인 ∧ `agent-approval-check` 통과. 구현 예시는 [`docs/05`](05-github-automation.md)의 gh-aw/`gh pr merge --auto` 패턴입니다. Dependabot minor/patch는 `dependabot-auto-merge.yml`이 이미 자동 머지합니다.

## 6. 측정

측정 항목은 time-to-first-review, time-in-review, 리뷰 라운드 수, 사람 리뷰 없이 머지된 PR 비율, 봇 코멘트 수정률, 되돌림(revert) 비율입니다. 수집 방법은 [09](09-metrics.md)에 정리되어 있습니다.

## 출처

- GitHub Copilot code review 개념(승인 미집계): https://docs.github.com/en/copilot/concepts/agents/code-review
- Claude Code Review: https://code.claude.com/docs/en/code-review · agent-approval-check: https://github.com/anthropics/claude-code-action/tree/main/agent-approval-check
- Rulesets available rules(unattributed Copilot PR 추가 승인): https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- Advisory-first: https://droidorbit.com/ai-code-review-tools-for-developers/ · 반론: https://blog.codacy.com/ai-code-review-tools-compared-2026-why-most-cant-safely-block-a-merge-and-what-code-governance-fixes
- Thoughtworks, Complacency with AI-generated code(Hold): https://www.thoughtworks.com/radar/techniques/complacency-with-ai-generated-code
- Simon Willison, vibe coding vs agentic engineering: https://simonwillison.net/2026/May/6/vibe-coding-and-agentic-engineering/
