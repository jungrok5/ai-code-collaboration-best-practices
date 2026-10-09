# 12. 셋업 점검

셋업 단계를 사람이 문서를 보며 따라 하지 않습니다. `make doctor`가 이 컴퓨터와 GitHub 레포의 상태를 확인하고, 남은 일을 한 줄씩 보여 줍니다.
Claude Code에서는 `/onboard`를 실행하면 에이전트가 같은 점검을 돌리고, 안전한 항목은 확인을 받은 뒤 고치고, 사람만 할 수 있는 항목을 정리해 알려 줍니다.

```bash
make doctor                 # 전체 점검(로컬 + GitHub)
make doctor SCOPE=local     # 이 컴퓨터만(네트워크·gh 없이도 동작)
make doctor FIX=1           # git 훅, 커밋 템플릿, 플러그인 설치·업데이트만 자동 수정
scripts/doctor.sh --json    # 에이전트용 출력
```

## 1. 처음 할 일

| 상황 | 명령 |
| --- | --- |
| 새 제품 레포 생성 | `make new-repo REPO=org/name VISIBILITY=private` |
| 클론 직후(모든 팀원) | `make setup` (마지막에 `make doctor` 결과 출력) |
| 레포 설정·라벨·룰셋(관리자 1회) | `make github-setup`, 허브는 `make github-setup TEMPLATE=1`, 프로토타입 레포는 `PROFILE=prototype` |
| 남은 일 확인 | `make doctor` 또는 `/onboard` |

AI 백엔드는 선택 사항입니다. `AI_BACKEND`를 설정하지 않으면 AI 워크플로는 skipped로 끝나고, 팀원은 각자 `claude` 로그인으로 `make ai-*`를 실행합니다([13](13-ai-backends.md)).

## 2. 결과 읽는 법

각 줄은 `상태 점검ID 내용 → fix: 할 일` 형식입니다.

| 상태 | 의미 |
| --- | --- |
| `PASS` | 문제 없음 |
| `FAIL` | 고쳐야 하는 항목. 하나라도 있으면 종료 코드 1 |
| `WARN` | 동작은 하지만 권장 상태와 다른 항목 |
| `SKIP` | 확인 불가(gh 없음, 오프라인, 권한 부족). 누구에게 요청할지 함께 표시 |
| `MANUAL` | 사람만 처리할 수 있는 항목(승인, 구매, 본인만 아는 값). 할 일을 그대로 표시 |
| `INFO` | 참고 정보 |

## 3. 점검 항목

| 점검 ID | 확인 내용 | 자동화되지 않을 때 처리할 사람 |
| --- | --- | --- |
| `tools.*` | git, jq, make, python3(필수), gh, claude, pre-commit, shellcheck, actionlint, yamllint | 본인(설치) |
| `auth.gh`, `auth.claude` | gh 로그인과 `workflow` 스코프, claude 로그인 | 본인(`gh auth login`, `claude` 한 번 실행) |
| `auth.local-llm` | `ANTHROPIC_BASE_URL`이 로컬 LLM일 때 서버 응답 | 서버 담당자([infra/local-llm](../infra/local-llm/README.md)) |
| `local.hooks`, `local.commit-template` | pre-commit·commit-msg 훅, 커밋 템플릿 | 없음(`FIX=1`로 수정) |
| `local.git-identity` | `git user.email` | 본인 |
| `local.plugin` | `team-ai-workflow@ai-collab` 설치 여부와 마켓플레이스 버전 일치 | 없음(`FIX=1`로 설치·업데이트) |
| `local.placeholders` | `AGENTS.md` Project 섹션, `OWNER/REPO`, `@OWNER` | 에이전트(`AGENTS.md`), 사람(`CODEOWNERS`, `settings.json`) |
| `local.lean-permissions` | `.claude/settings.json`의 ask 목록 정리 여부([15](15-lean-harness.md)) | 사람(`scripts/apply-lean-permissions.sh` 실행 후 PR) |
| `gh.default-branch`, `gh.template` | 기본 브랜치 `main`, 허브의 템플릿 레포 지정 | 관리자(`make github-setup TEMPLATE=1`) |
| `gh.ruleset.*`, `gh.profile` | 룰셋 존재·enforcement·규칙 일치, 프로필과 승인 수 일치 | 관리자(`make github-setup`). 비공개 레포의 플랜 제한은 조직 소유자 |
| `gh.labels`, `gh.area-labels` | `labels.yml`의 라벨 전부 존재, `area/*` 라벨 | 쓰기 권한자(`make labels`), 에이전트(`area/*` 제안) |
| `gh.workflows`, `gh.ci-main` | 비활성 워크플로 없음, main의 마지막 CI 성공 | 쓰기 권한자, 에이전트(`/fix-ci`) |
| `gh.pages`, `gh.board`, `gh.board-repos`, `gh.board-token` | (허브) Pages 소스, `board.json` 게시, 보드 레포 접근, 비공개 레포용 `BOARD_TOKEN` | 관리자(`scripts/setup-github.sh pages`), 사람(`BOARD_TOKEN` 발급) |
| `gh.merge` | squash 전용, 자동 머지, 머지 후 브랜치 삭제 | 관리자(`scripts/setup-github.sh settings`) |
| `gh.ai-backend`, `gh.claude-app`, `gh.runner` | `AI_BACKEND` 값과 필요한 변수·시크릿, Claude GitHub App, self-hosted 러너 | 사람(토큰 값, 앱 설치, 러너 등록) |
| `gh.design-board-url`, `gh.max-open-prs` | (스포크) `DESIGN_BOARD_URL` 설정과 접근, 숫자 변수 | 쓰기 권한자(`gh variable set`) |
| `gh.actions`, `gh.actions-token`, `gh.secret-scanning` | Actions 활성화, 워크플로 토큰 권한, 푸시 보호 | 관리자. 조직 정책·Secret Protection 구매는 조직 소유자 |
| `gh.codeql`, `gh.optional-secrets` | CodeQL 중복 실행, 선택 시크릿(`RELEASE_PLEASE_TOKEN`, `REPO_ADMIN_TOKEN`) | 관리자 |
| `stack.*` | 감지한 스택과 CodeQL 언어, `release-type`, `buf.yaml` | 에이전트 |

권한별로 읽을 수 있는 범위가 다릅니다. 읽기 권한으로 기본 브랜치, 룰셋, 라벨, 워크플로, Pages를 확인합니다. 변수와 시크릿 이름은 쓰기 권한, Actions 권한·푸시 보호·러너는 관리자 권한이 필요합니다. 권한이 부족한 항목은 `SKIP`으로 표시됩니다.

## 4. `make doctor`가 확인하지 않는 항목

| 항목 | 처리할 사람 |
| --- | --- |
| Copilot 코드 리뷰·MCP·방화벽 설정(웹 UI 전용) | 관리자 |
| CodeRabbit·Codex 같은 외부 앱 설치 | 관리자(구매 결정 포함) |
| VS Code 권장 확장 설치, `.vscode/mcp.json`의 PAT 입력 | 본인 |
| 프로토타입에서 운영으로 전환할 시점([16](16-team-scale-ai.md) §5) | 리드 |
| 첫 PR과 `make ai-implement ISSUE=1 POST=1`의 실제 동작 확인 | 에이전트에게 요청 가능 |

## 5. 자주 묻는 문제

- AI 워크플로가 항상 skipped: 의도한 기본값입니다. `AI_BACKEND` 변수를 설정해야 활성화됩니다(docs/13).
- Claude 액션이 "write access"로 거부: 트리거한 사람에게 쓰기 권한이 없습니다. 공개 레포 트리아지는 워크플로 주석의 `allowed_non_write_users`를 참고하십시오.
- 에이전트 PR에 CI가 실행되지 않음: `github_token`을 직접 넘기면 액션이 `GITHUB_TOKEN`으로 동작합니다. 이 토큰의 작업은 다른 워크플로를 트리거하지 않습니다. 앱 인증(기본)을 사용하십시오.
- 훅이 편집을 차단함: 의도한 보호 경로입니다. 사람이 직접 수정하고 PR에 사유를 기록합니다.
