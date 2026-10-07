# 06. 코드 리뷰 정책 — AI는 1차(참고), 사람이 결정

## 1. 원칙

1. **AI 리뷰는 참고(advisory)** 로 시작한다. 2–4주 보정 후, 신호 품질이 확인된 **보안·정확성** 카테고리만 필수 체크로 승격한다(스타일은 영원히 아님). 이유: 처음부터 blocking이면 오탐이 팀의 신뢰를 깎는다. 반대 의견(Codacy)도 알아 두자: "참고용 리뷰는 아무것도 강제하지 않는다" → 강제가 필요한 기준은 **결정적 도구**(린트·타입·테스트·CodeQL)로 CI에 넣는다.
2. **AI 승인은 승인이 아니다.** Copilot 기본값·Claude Code Review 모두 승인으로 집계되지 않는다. 사람 CODEOWNER 1명 이상이 승인한다.
3. **에이전트 커밋 = 더 강한 사람 검토.** `agent-approval-check`가 에이전트 커밋을 포함한 PR에 사람 승인 N명(기본 1, 권장 2)을 요구한다. GitHub 룰셋에는 "attribution 없는 Copilot PR에 추가 승인 요구"가 기본 켜져 있다.
4. **작성자는 자기 코드를 전부 읽었다.** AI가 썼더라도 설명하지 못하는 줄은 올리지 않는다(vibe coding과 agentic engineering의 경계, Simon Willison). PR 본문의 AI 공개는 의무다.
5. **리뷰어 피로를 구조로 막는다.** PR ≤ 400줄, 첫 리뷰 24시간 SLO, 스타일은 CI가 처리, 봇은 하나부터.

## 2. 리뷰 체크리스트 (REVIEW.md 요약)

| 순서 | 항목 | 블로킹 기준 |
| --- | --- | --- |
| 1 | 범위·크기 | 이슈와 다른 변경, 400줄 초과 사유 없음 |
| 2 | 정확성 | 로직 오류, 경계값, null, 경쟁 조건, 에러 처리, 자원 정리 |
| 3 | 테스트 | 수용 기준 미커버, 구현 세부에 결합, skip/disable |
| 4 | 보안 | 인젝션, 인가 누락, 비밀 노출, SSRF/경로 탐색, 위험한 의존성, Actions 하드닝 |
| 5 | 호환성 | 공개 API/스키마/설정/마이그레이션 비호환, 플래그·ADR 없음 |
| 6 | 가독성·관례 | 모듈 패턴 위반, 중복, *왜*가 없는 주석 |
| 7 | 문서·운영 | README/ADR/CHANGELOG 누락, 로깅·지표 없음 |

AI 코멘트 처리: **주장을 검증**한다. 경로가 실제면 고치고, 아니면 스레드에 이유를 적고 resolve. 보안 finding은 사람이 결정할 때까지 열어 둔다.

## 3. 리뷰 봇 선택 가이드

| 봇 | 승인 집계 | 설정 파일 | 비용(2026-10) | 강점 |
| --- | --- | --- | --- | --- |
| Claude (이 레포 `claude-code-review.yml`) | 불가(인라인+요약만) | 워크플로 프롬프트, `REVIEW.md`, `AGENTS.md` | API 토큰 사용량 | 레포 규칙에 맞춘 프롬프트, 도구 제한 가능 |
| Claude Code Review(관리형, Team/Enterprise) | 불가(neutral check) | `CLAUDE.md`, `REVIEW.md` | 리뷰당 $15–25(크레딧) | 다중 에이전트, `@claude review` |
| Copilot code review | 옵션(기본 미집계) | `copilot-instructions.md`, `*.instructions.md`, `REVIEW.md` | Lite $0.05–1, Balanced $0.25–5/리뷰(크레딧) | 룰셋 자동 요청, 플랫폼 내장 |
| CodeRabbit | `request_changes_workflow` 옵션 | `.coderabbit.yaml` | $24–72/개발자/월, 공개 레포 무료 | 린터 통합, 요약/워크스루 |
| Codex | 리뷰 코멘트 | `AGENTS.md` Code Review Rules | ChatGPT 플랜 | P0/P1 집중 |
| Gemini Code Assist | 리뷰 코멘트 | `.gemini/config.yaml` | 엔터프라이즈 시트 | 소비자용 종료(2026-07) |
| Cursor Bugbot | 리뷰 코멘트 | `.cursor/BUGBOT.md` | 사용량 | "Fix in Cursor" |

권장 조합: **Claude(또는 Copilot) 1개 + CodeQL/linters(결정적)**. 봇을 추가할 때마다 소음 대비 수정률을 2주 측정한다.

## 4. 승격 기준 (advisory → required)

- 4주간 봇 코멘트 중 수정으로 이어진 비율 ≥ 30%, 오탐 불만 < 10%.
- 승격 대상은 `security`, `correctness` 카테고리뿐. 구현은 봇 결과를 `--json-schema`로 받아 심각도 ≥ high일 때만 실패하는 별도 잡을 만든다(현재 워크플로는 neutral).

## 5. 자동 머지 (선택, 기본 꺼짐)

조건이 전부 참일 때만: `risk/low` 라벨(사람이 부여) ∧ CI 초록 ∧ 사람 승인 ∧ `agent-approval-check` 통과. 구현 예시는 `docs/05`의 gh-aw/`gh pr merge --auto` 패턴. Dependabot minor/patch는 이미 자동 머지한다.

## 6. 측정

time-to-first-review, time-in-review, 리뷰 라운드 수, 사람 리뷰 없이 머지된 PR 비율, 봇 코멘트 수정률, 되돌림(revert) 비율. 수집 방법은 09 문서.

## 출처

- GitHub Copilot code review 개념(승인 미집계): https://docs.github.com/en/copilot/concepts/agents/code-review
- Claude Code Review: https://code.claude.com/docs/en/code-review · agent-approval-check: https://github.com/anthropics/claude-code-action/tree/main/agent-approval-check
- Rulesets available rules(unattributed Copilot PR 추가 승인): https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- Advisory-first: https://droidorbit.com/ai-code-review-tools-for-developers/ · 반론: https://blog.codacy.com/ai-code-review-tools-compared-2026-why-most-cant-safely-block-a-merge-and-what-code-governance-fixes
- Thoughtworks, Complacency with AI-generated code(Hold): https://www.thoughtworks.com/radar/techniques/complacency-with-ai-generated-code
- Simon Willison, vibe coding vs agentic engineering: https://simonwillison.net/2026/May/6/vibe-coding-and-agentic-engineering/
