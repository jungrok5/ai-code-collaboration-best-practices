# 02. 브랜치 · PR · 커밋 · 릴리스 규칙

AI가 코드를 빨리, 많이 만들수록 **작게, 자주, 검증된 상태로** 합치는 것이 유일한 방어선이다. (DORA 2025: AI 도입은 처리량은 올리지만 안정성과는 음의 상관 — "작은 배치"와 "강한 버전 관리"가 핵심 역량)

## 1. 브랜치 모델: 트렁크 기반 + 짧은 브랜치

| 항목 | 규칙 | 근거/비고 |
| --- | --- | --- |
| 기본 브랜치 | `main` (보호: PR 필수, 삭제·force-push 금지, 선형 이력) | `scripts/rulesets/main.json` |
| 작업 브랜치 | `<type>/<issue>-<slug>` 예: `fix/142-null-session` | 룰셋 `feature-branches.json`(evaluate 모드)로 패턴 감시 |
| 에이전트 브랜치 | `ai/issue-<n>-<ts>`(Claude), `copilot/*`(Copilot) | 자동 생성, 패턴 규칙에서 제외 |
| 수명 | **2일 이내** 머지 또는 분할 (팀 결정, 1차 출처 없음) | 길어지면 충돌·리뷰 지연이 비선형 증가 |
| 공유 브랜치 | 사람 둘 이상이 커밋한 브랜치는 **절대 rewrite 금지**(merge만) | 훅 `git-guard.sh` |
| 큰 기능 | feature flag(기본 off) 뒤에서 작은 PR로 나눠 합침 | ADR 기록 |

## 2. PR 크기

| 라벨 | 변경 줄 수(락파일 제외) | 기대 |
| --- | --- | --- |
| `size/XS` | ≤ 20 | 즉시 리뷰 |
| `size/S` | ≤ 100 | 당일 리뷰 |
| `size/M` | ≤ 300 | **팀 목표 상한에 근접** |
| `size/L` | ≤ 800 | 사유 필요, 가능하면 분할 |
| `size/XL` | > 800 | **분할 필수** (`/split-pr`) |

팀 목표는 **≤ 400줄**이다(AGENTS.md §3). Faros AI 2026 데이터: AI 고도입 팀에서 PR 크기 +51%, 리뷰 체류 시간 +441%, PR당 버그 +54% — 크기를 잡지 않으면 리뷰가 병목이 된다.

### 분할 순서(스택 PR)

1. 동작 변화 없는 준비 리팩터(이동·추출·이름)
2. 인터페이스/타입/스키마 + 단위 테스트
3. feature flag 뒤의 핵심 구현
4. 연결(와이어링) + 통합 테스트
5. 문서, 플래그 전환, 정리

스택은 각 PR이 이전 PR 브랜치를 base로 하거나(stacked), 순차 머지(sequential)한다. 본문에 `stack/2-of-4`처럼 표시.

## 3. 커밋

- **Conventional Commits**: `<type>(<scope>): <summary> (#<issue>)`; type ∈ feat fix chore docs refactor test ci perf build revert. 본문은 *왜*.
- 한 커밋 = 한 논리적 변경. 훅이 800줄 초과 스테이징 커밋을 막는다(`AI_MAX_COMMIT_LINES`).
- AI 도구가 붙이는 트레일러는 유지한다: `Co-Authored-By: Claude <noreply@anthropic.com>`(Claude Code 기본, `.claude/settings.json`의 `attribution`), Copilot은 `Co-authored-by: Copilot …`. 이것이 감사 추적이다. (VS Code가 2026-05에 기본 공동저자 표기를 되돌린 사례가 있듯 **팀이 명시적으로 결정**해야 한다 → ADR-0002)
- 서명 커밋을 요구하려면 `required_signatures` 규칙을 켜되, Claude 액션은 `use_commit_signing: true`(API 커밋, Verified)로 설정돼 있어야 통과한다.

## 4. PR

- 제목 = Conventional Commit(`pr-checks.yml`가 검사). squash 머지 시 커밋 제목이 되므로 룰셋의 `commit_message_pattern`도 이 제목을 검사한다.
- 본문 = 템플릿. **AI 공개 체크박스**를 정확히 하나 체크해야 `ai-disclosure` 체크가 통과하고 `ai:assisted`/`ai:generated` 라벨이 붙는다.
- 초안으로 열고 CI 초록 후 ready. 에이전트 PR은 항상 초안으로 시작한다.
- 리뷰: CODEOWNER 1명 이상 승인, 스레드 모두 해결, 마지막 push 이후 승인(`require_last_push_approval`), stale 승인 자동 해제. AI 승인은 카운트되지 않는다.
- 머지: squash만, 브랜치 자동 삭제, `allow_update_branch`로 베이스 최신화. 머지 큐는 조직 레포에서 선택(`merge_group` 트리거는 CI에 이미 포함).

## 5. 릴리스

- `release-please`가 `main`의 Conventional Commits를 읽어 릴리스 PR(CHANGELOG + 버전)을 유지한다. 그 PR을 머지하면 태그와 GitHub Release가 생긴다.
- 릴리스 태그로 다른 워크플로(배포 등)를 트리거하려면 `RELEASE_PLEASE_TOKEN`(PAT 또는 App 토큰)이 필요하다(기본 `GITHUB_TOKEN`은 워크플로를 연쇄 트리거하지 않음).
- `release-please-config.json`의 `release-type`을 스택에 맞게 바꾼다(`node`, `python`, `go`, `simple`).

## 6. 의존성 변경

- Dependabot이 주간으로 PR을 연다(Actions는 SHA 핀 + 버전 주석 동시 갱신). minor/patch는 CI 통과 시 자동 승인·자동 머지(`dependabot-auto-merge.yml`), major는 사람이 본다.
- 에이전트가 새 의존성을 추가하려면 PR 본문에 한 줄 사유. 락파일은 패키지 매니저로만 변경(훅이 직접 편집을 막음).

## 출처

- DORA 2025 AI Capabilities Model: https://cloud.google.com/blog/products/ai-machine-learning/introducing-doras-inaugural-ai-capabilities-model
- Faros AI, AI code quality & review burden (2026): https://www.faros.ai/blog/ai-code-quality-senior-engineer-review-burden
- GitHub rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- Conventional Commits: https://www.conventionalcommits.org/
- release-please: https://github.com/googleapis/release-please-action
