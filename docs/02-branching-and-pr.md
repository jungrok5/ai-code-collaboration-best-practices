# 02. 브랜치 · PR · 커밋 · 릴리스 규칙

AI가 코드를 빠르게, 많이 생성할수록 변경은 작게, 자주, 검증된 상태로 합쳐야 합니다. 이것이 유일한
방어선입니다. DORA 2025에 따르면 AI 도입은 처리량을 높이지만 안정성과는 음의 상관이 있으며, 핵심 역량은 "작은 배치"와
"강한 버전 관리"입니다.

## 1. 브랜치 모델: 트렁크 기반 + 짧은 브랜치

| 항목 | 규칙 | 근거/비고 |
| --- | --- | --- |
| 기본 브랜치 | `main` (보호: PR 필수, 삭제·force-push 금지, 선형 이력) | `scripts/rulesets/main.json` |
| 작업 브랜치 | `<type>/<issue>-<slug>` 예: `fix/142-null-session` | 룰셋 `feature-branches.json`(evaluate 모드)의 패턴 감시 |
| 에이전트 브랜치 | `ai/issue-<n>-<ts>`(Claude), `copilot/*`(Copilot) | 자동 생성, 패턴 규칙에서 제외 |
| 수명 | 2일 안에 머지 또는 분할 (팀 결정, 1차 출처 없음) | 수명이 길수록 충돌과 리뷰 지연이 비선형으로 증가 |
| 공유 브랜치 | 사람 둘 이상이 커밋한 브랜치는 rewrite 금지(merge만) | 사람 간 약속 + 룰셋. 훅 `git-guard.sh`는 `main`/`develop`/`release/*` 등 보호 브랜치와 접두어 없는 브랜치로의 force-push만 차단(커밋 작성자는 판별하지 않음) |
| 큰 기능 | feature flag(기본 off) 뒤에서 작은 PR로 나누어 병합 | ADR 기록 |

## 2. PR 크기

| 라벨 | 변경 줄 수(락파일 제외) | 기대 |
| --- | --- | --- |
| `size/XS` | ≤ 20 | 즉시 리뷰 |
| `size/S` | ≤ 100 | 당일 리뷰 |
| `size/M` | ≤ 300 | 팀 목표 상한에 근접 |
| `size/L` | ≤ 800 | 사유 필요, 가능하면 분할 |
| `size/XL` | > 800 | 분할 필수 (`/split-pr`) |

팀 목표는 400줄 이하입니다(AGENTS.md "How work flows"). Faros AI 2026 데이터에서 AI 도입률이 높은 팀은 PR 크기가
51%, 리뷰 체류 시간이 441%, PR당 버그가 54% 늘었습니다. PR 크기를 관리하지 않으면 리뷰가 병목이 됩니다.

### 분할 순서(스택 PR)

1. 동작 변화 없는 준비 리팩터(이동·추출·이름 변경)
2. 인터페이스/타입/스키마 + 단위 테스트
3. feature flag 뒤의 핵심 구현
4. 연결(와이어링) + 통합 테스트
5. 문서, 플래그 전환, 정리

스택의 각 PR은 이전 PR 브랜치를 base로 삼거나(stacked) 차례로 머지합니다(sequential). 본문에는 `stack/2-of-4`처럼
위치를 표시합니다.

## 3. 커밋

- Conventional Commits: `<type>(<scope>): <summary> (#<issue>)`. type은 feat fix chore docs refactor test ci perf
  build revert 중 하나입니다. 본문에는 변경 이유를 적습니다.
- 커밋 하나에 논리적 변경 하나를 담습니다. 커밋 크기는 훅으로 제한하지 않으며, PR 크기는 `size/*` 라벨과 리뷰로
  관리합니다([15](15-lean-harness.md)).
- AI 도구가 붙이는 트레일러는 유지합니다. Claude Code는 `Co-Authored-By: Claude <noreply@anthropic.com>`(기본값,
  `.claude/settings.json`의 `attribution`)을, Copilot은 `Co-authored-by: Copilot …`을 붙입니다. 이 트레일러가 감사
  추적의 근거입니다. VS Code가 2026-05에 기본 공동저자 표기를 되돌린 사례처럼 도구의 기본값은 바뀔 수 있으므로, 팀이
  명시적으로 정해 둡니다(ADR-0002).
- 서명 커밋을 요구하려면 `required_signatures` 규칙을 켭니다. 이 경우 Claude 액션에 `use_commit_signing: true`(API
  커밋, Verified)가 설정되어 있어야 규칙을 통과합니다.

## 4. PR

- 제목은 Conventional Commit 형식이며 `pr-checks.yml`이 검사합니다. squash 머지 시 이 제목이 커밋 제목이 되므로 룰셋의
  `commit_message_pattern`도 같은 형식을 검사합니다.
- 본문은 템플릿을 사용합니다. AI 공개 체크박스를 정확히 하나 선택해야 `ai-disclosure` 체크가 통과하고
  `ai:assisted`/`ai:generated` 라벨이 지정됩니다.
- PR은 초안으로 열고 CI가 통과하면 ready로 전환합니다. 에이전트 PR은 항상 초안으로 시작합니다.
- 리뷰 조건: CODEOWNER 1명 이상 승인, 모든 스레드 해결, 마지막 push 이후 승인(`require_last_push_approval`), stale
  승인 자동 해제. AI의 승인은 승인 수에 포함하지 않습니다.
- 머지: squash만 허용, 브랜치 자동 삭제, `allow_update_branch`로 베이스 최신화. 머지 큐는 조직 레포에서 선택적으로
  사용합니다(CI에는 `merge_group` 트리거가 이미 있습니다).

## 5. 릴리스

- `release-please`가 `main`의 Conventional Commits를 읽어 릴리스 PR(CHANGELOG + 버전)을 유지합니다. 이 PR을 머지하면
  태그와 GitHub Release가 생성됩니다.
- 릴리스 태그로 다른 워크플로(배포 등)를 트리거하려면 `RELEASE_PLEASE_TOKEN`(PAT 또는 App 토큰)이 필요합니다. 기본
  `GITHUB_TOKEN`으로 만든 이벤트는 다른 워크플로를 연쇄 트리거하지 않습니다.
- `release-please-config.json`의 `release-type`을 스택에 맞게 변경합니다(`node`, `python`, `go`, `simple`).

## 6. 의존성 변경

- Dependabot이 매주 PR을 엽니다. Actions는 SHA 핀과 버전 주석을 함께 갱신합니다. minor/patch는 CI가 통과하면
  `dependabot-auto-merge.yml`이 자동 승인·자동 머지하고, major는 사람이 검토합니다.
- 에이전트가 새 의존성을 추가하면 PR 본문에 사유를 한 줄 적습니다. 락파일은 패키지 매니저로만 변경하며, 직접 편집은
  훅이 차단합니다.

## 출처

- DORA 2025 AI Capabilities Model: https://cloud.google.com/blog/products/ai-machine-learning/introducing-doras-inaugural-ai-capabilities-model
- Faros AI, AI code quality & review burden (2026): https://www.faros.ai/blog/ai-code-quality-senior-engineer-review-burden
- GitHub rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- Conventional Commits: https://www.conventionalcommits.org/
- release-please: https://github.com/googleapis/release-please-action
