# 09. 측정 — AI가 팀을 고쳐 주지 않는다, 증폭할 뿐이다

DORA 2025(약 5,000명): 응답자 90%가 AI 사용, 처리량은 증가하지만 **배포 안정성과는 음의 상관**. 그러니 속도와 안정성을 같이 본다.

## 1. 지표 세트

| 범주 | 지표 | 수집 |
| --- | --- | --- |
| **DORA 5** | 변경 리드타임, 배포 빈도, 변경 실패율, 실패 복구 시간, 배포 재작업률 | 배포 파이프라인 + `gh api` |
| **리뷰 건강도**(Faros) | 첫 리뷰까지 시간, 리뷰 체류 시간, 리뷰 라운드 수, 사람 리뷰 없이 머지된 PR 비율, PR 크기 분포 | GitHub API(`pulls`, `reviews`), `size/*` 라벨 |
| **에이전트 성과** | 에이전트 PR 머지율, 수정 없이 머지된 비율, 에이전트 PR 되돌림/핫픽스율, PR당 인시던트, 봇 코멘트 → 수정 전환율 | `ai:generated`/`ai:assisted` 라벨, 공동저자 트레일러, revert 커밋 |
| **채택·비용** | 활성 사용자, 세션 수, 토큰/실행 비용, 워크플로 실패율 | Copilot metrics API(CCA/CCR 포함), Claude Code 분석/OpenTelemetry, Actions 사용량 |
| **신뢰**(설문) | AI 스탠스 명확성, 생성 코드 신뢰도 | 분기 설문(DORA 문항 차용) |

AI 접촉 PR과 비접촉 PR을 **분리해 비교**하는 것이 핵심이다(라벨이 그 기준).

## 2. 빠른 수집 예시

```bash
# 최근 30일 PR: 크기, AI 라벨, 첫 리뷰까지 시간
gh pr list --state merged --limit 200 --json number,additions,deletions,labels,createdAt,mergedAt,reviews \
  --jq '.[] | {n:.number, size:(.additions+.deletions), ai:([.labels[].name|select(startswith("ai:"))]|join(",")), created:.createdAt, merged:.mergedAt, firstReview:(.reviews|map(.submittedAt)|min)}'

# 에이전트 커밋 비율 (공동저자 트레일러)
git log --since="30 days ago" --format='%H%n%b' | grep -ci "co-authored-by: claude" ; git rev-list --count --since="30 days ago" HEAD

# 되돌림
git log --since="30 days ago" --oneline | grep -ci '^[0-9a-f]* revert'
```

## 3. 벤치마크로 삼을 외부 수치(출처 명시, 팀 수치와 혼동 금지)

- Faros 2026(22,000명): AI 고도입 시 PR 크기 +51%, PR당 버그 +54%, 첫 리뷰까지 +157%, 리뷰 체류 +441%, 사람 리뷰 없이 머지 +31%.
- Stack Overflow 2026: AI 사용자 73%가 매일 사용, 에이전트 사용 66%; 출처 표시가 있어야 신뢰 93%.
- METR 2025 RCT: 숙련 OSS 개발자가 AI로 **19% 느려짐**(기대는 +24%) — 생산성 체감은 믿을 수 없으니 측정한다.
- 에이전트 PR 머지율(arXiv, 2025–26): Claude Code PR 83.8% 수락 vs 사람 91%; 5개 에이전트 비교 68–80%. "32.7% vs 84.4%"는 1차 출처가 없으니 인용하지 않는다.

## 4. 운영

- 월 1회 15분: 지표 대시보드(LinearB/Swarmia/DX/Faros 또는 스프레드시트) 리뷰 → 규칙·훅·프롬프트 1개를 고친다.
- 분기 1회: `AGENTS.md`·스킬·워크플로 정리(더 이상 틀리지 않는 규칙 삭제, 봇 소음 재평가).
- 되돌림·인시던트가 늘면 **PR 크기와 리뷰 SLO**부터 조인다.

## 출처

- DORA 2025 report: https://dora.dev/research/2025/dora-report/ · DORA metrics(5 keys): https://dora.dev/guides/dora-metrics-four-keys/
- Faros AI 2026: https://www.faros.ai/blog/ai-code-quality-senior-engineer-review-burden
- METR 2025: https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/ · Stack Overflow 2026: https://survey.stackoverflow.co/2026/ai/data
- Copilot metrics API: https://docs.github.com/en/rest/copilot/copilot-metrics · Claude Code monitoring: https://code.claude.com/docs/en/monitoring-usage
