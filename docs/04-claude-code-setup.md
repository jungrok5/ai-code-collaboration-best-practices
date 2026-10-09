# 04. Claude Code 설정: settings · hooks · skills · subagents · plugin marketplace

## 1. 파일 구조

```text
.claude/
  settings.json          # 팀 정책(커밋됨): permissions, env, attribution, hooks, marketplace/plugins
  settings.local.json    # 개인 오버라이드(git-ignored)
  hooks/session-start.sh # 세션 시작 시 의존성·pre-commit·컨텍스트 준비(클라우드 세션 포함)
  rules/*.md             # paths: 프런트매터 경로 규칙
  skills/<name>/SKILL.md # 레포 전용 스킬(/new-repo, /validate-ai-config)
.claude-plugin/marketplace.json   # 이 레포 = 팀 마켓플레이스 "ai-collab"
plugins/team-ai-workflow/         # 공유 플러그인: hooks + skills + agents
CLAUDE.md                         # @AGENTS.md + Claude 전용 메모
.mcp.json                         # 프로젝트 MCP 서버(GitHub 원격 MCP, 토큰은 env)
```

설정 우선순위: 관리형(managed) > `--settings` 플래그 > `.claude/settings.local.json` > `.claude/settings.json` >
`~/.claude/settings.json`.

## 2. `settings.json` 핵심

### permissions

- `allow`: 읽기용 git/gh, `make *`, 테스트·린트 도구, 문서 사이트 WebFetch. 확인 없이 실행해요.
- `ask`: push, rebase/merge, PR/이슈 생성·수정, 패키지 설치, docker, `rm -r`. 매번 확인해요.
- `deny`: `.env*`/비밀/키 읽기, force-push, `reset --hard`, `clean -fd`, `gh secret`, `sudo`, `curl | sh`. 항상
  거부해요.
- 문법: `Bash(git commit *)`(prefix 매칭, 공백 뒤 `*`), `Read(./.env)`, `WebFetch(domain:docs.github.com)`,
  `mcp__github__*`.
- `defaultMode: default`는 도구를 처음 쓸 때 확인을 받아요. 최신 모델에 맞춰 덜어낸 설정(auto 모드, `ask`는 `rm -r`만,
  main push·PR 머지는 deny)은 사람이 `scripts/apply-lean-permissions.sh`로 적용해요([15](15-lean-harness.md)).
  CI/샌드박스에서는 `--permission-mode dontAsk|acceptEdits`를 쓰고, `bypassPermissions`는 격리된 컨테이너에서만
  써요.

### attribution

`commit`/`pr` 문자열로 공동저자 트레일러와 PR 바이라인을 정해요(`includeCoAuthoredBy`는 deprecated). 이 레포는 감사
추적을 위해 기본값을 유지해요(ADR-0002).

### hooks

팀 settings에는 `SessionStart`만 두고, 가드레일 훅은 플러그인(`plugins/team-ai-workflow/hooks/hooks.json`)에 둬요.
플러그인에 두면 모든 레포의 훅을 한 번에 업데이트할 수 있어요.

| 이벤트 | 훅 | 동작 | 종료 코드 |
| --- | --- | --- | --- |
| PreToolUse `Edit\|Write\|MultiEdit\|NotebookEdit` | `protect-files.sh` | 보호 경로 편집 차단 | 2 = 차단(사유를 stderr로 Claude에 전달) |
| PreToolUse `Bash` | `git-guard.sh` → `git_guard.py` | 명령을 셸처럼 토큰화(`&&`, `;`, `$(…)`, `cd`, `-C`, `--git-dir`)해서 보호 브랜치 커밋과, 기능 접두어(`feat/`, `fix/`, `ai/` …)가 아닌 브랜치로의 force-push(`+refspec`, `--mirror` 포함)·삭제를 차단. 셸 키워드(`if`/`for`/`{ }`), 서브셸 `cd`, `GIT_DIR=`도 해석. 크기 제한은 없앰([15](15-lean-harness.md)) | 2 |
| PostToolUse `Edit\|Write\|MultiEdit` | `format-after-edit.sh` | prettier/ruff/gofmt 등 자동 포맷 | 항상 0 |
| PostToolUse `Edit\|Write\|MultiEdit` | `style/style_check.py --hook` | 글·화면 기준 검사 결과를 AI에게 돌려줌(막지 않음, [17](17-writing-and-design-standards.md)) | 항상 0 |
| SessionStart | `.claude/hooks/session-start.sh` | 의존성 설치, pre-commit 설치, 팀의 활성 설계·작업 영역 요약(`board.py brief`)을 컨텍스트에 주입 | 0 |

훅은 stdin으로 JSON(`tool_name`, `tool_input.file_path`/`command` …)을 받아요. `type: command` 말고도
`prompt`(LLM 판정), `agent`(검증 에이전트), `http` 훅이 있어요. 지원 이벤트는 PreToolUse, PostToolUse,
PostToolUseFailure, PermissionRequest, UserPromptSubmit, Notification, Stop, SubagentStart/Stop,
PreCompact/PostCompact, SessionStart/End, TaskCompleted, ConfigChange, WorktreeCreate/Remove 등이에요(`settings`
JSON 스키마 참조).

### plugins / marketplace

```json
"extraKnownMarketplaces": { "ai-collab": { "source": { "source": "github", "repo": "OWNER/REPO" } } },
"enabledPlugins": { "team-ai-workflow@ai-collab": true }
```

팀원이 레포를 열면 Claude Code가 마켓플레이스를 알아보고 플러그인 설치를 제안해요. 수동 설치:
`claude plugin marketplace add OWNER/REPO && claude plugin install team-ai-workflow@ai-collab`. 로컬에서 시험할
때: `claude --plugin-dir ./plugins/team-ai-workflow`.

## 3. 스킬 (`SKILL.md`)

| 스킬 | 용도 | 호출 |
| --- | --- | --- |
| `polish-writing` | 글의 AI 말투를 걷어내고 구체적으로(제품 문구, 문서, PR) | 글 파일을 다룰 때 자동 |
| `polish-ui` | 화면의 AI 티를 걷어내고 접근성·한글 타이포 최소선 지키기 | UI 파일을 다룰 때 자동 |
| `design` | 1쪽 설계 + Mermaid 구조도 작성 → 겹침 확인 → 설계 PR | `/design "결제 재시도"` |
| `check-overlap` | 내가 건드릴 경로·영역을 팀 보드와 비교 | `/check-overlap src/auth/**` |
| `implement-issue` | 이슈 → 브랜치 → 테스트 → 구현 → 검증 → 커밋(푸시 전 정지) | `/implement-issue 123` |
| `create-pr` | 전제 확인 → push → 템플릿 본문 → 초안 PR + 라벨 | `/create-pr` |
| `review-pr` | 읽기 전용 리뷰, 심각도순 findings | `/review-pr 42` |
| `fix-ci` | 실패 로그 분류 → 재현 → 근본 원인 수정 | `/fix-ci` |
| `split-pr` | 큰 diff를 스택으로 분할 제안 | `/split-pr` |
| `triage-issue` | 템플릿 완성도·중복·라벨 제안(닫지 않음) | `/triage-issue 7` |
| `write-adr` | ADR 작성 | `/write-adr "use pnpm"` |
| `onboard` | 레포 투어 | `/onboard` |
| `new-repo`(허브 전용) | 템플릿에서 새 레포 생성+부트스트랩 | `/new-repo org/svc` |
| `validate-ai-config` | 설정 전체 검증 | `/validate-ai-config` |

프런트매터: `name`, `description`(언제 쓰는지. Claude가 이 문장을 보고 스킬을 고름), `allowed-tools`,
`disable-model-invocation`(사용자만 호출), `context: fork`, `$ARGUMENTS`. 검증: `claude plugin validate <dir> --strict`.

## 4. 서브에이전트 (`agents/*.md`)

`code-reviewer`, `security-reviewer`(읽기 전용), `test-writer`, `issue-triager`, `docs-writer`가 있어요. 프런트매터에는
`tools`, `model: inherit`, `permissionMode` 등을 적어요. "security-reviewer로 이 diff를 검토해"라고 하거나
`@security-reviewer`로 불러요. 리뷰는 새 컨텍스트에서 돌려야 방금 쓴 코드에 끌리지 않아요.

## 5. 헤드리스 / CI

```bash
claude -p "run the test suite and fix failures" --permission-mode acceptEdits \
  --allowedTools "Read" "Edit" "Bash(make test)" --max-turns 30 --max-budget-usd 5 --output-format json
```

- `--bare`: 훅/스킬/MCP/CLAUDE.md 자동 탐색을 건너뛰어요(CI 권장, `ANTHROPIC_API_KEY` 필요).
- `--json-schema`로 구조화된 출력을 받아 다음 단계를 통과시킬지 정해요. `--permission-prompts none`이면 기다리지 않고
  거부해요.
- GitHub Actions에서는 `anthropics/claude-code-action@v1`이 이 옵션들을 감싸요([05](05-github-automation.md)).

## 6. 병렬 작업과 클라우드

- `claude --worktree <name>`: `.claude/worktrees/<name>`에 별도 체크아웃을 만들어요(.gitignore에 포함).
  `.worktreeinclude`로 `.env` 같은 무시 파일을 복사해요.
- 서브에이전트 `isolation: worktree`, `/batch`로 여러 작업을 한꺼번에 병렬로 돌려요.
- Claude Code on the web / Remote Control 세션에서도 `SessionStart` 훅이 실행돼서 `session-start.sh`가 의존성을
  준비해요.
- 에이전트 팀(실험적, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)은 팀원마다 서로 다른 파일을 맡게 작업을 나눠요.

## 7. 비용·성능 팁

- `AGENTS.md`는 짧게, 스킬과 규칙은 필요할 때만 로드되게(경로 규칙, description)
- 작업 사이에 `/clear`로 컨텍스트 초기화, 긴 조사는 서브에이전트에
- CI: `--max-turns`, `timeout-minutes`, `concurrency`, 모델 고정

## 출처

- Settings: https://code.claude.com/docs/en/settings · Permissions: https://code.claude.com/docs/en/permissions · Hooks: https://code.claude.com/docs/en/hooks
- Skills: https://code.claude.com/docs/en/skills · Subagents: https://code.claude.com/docs/en/sub-agents · Plugins/marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
- Headless: https://code.claude.com/docs/en/headless · Worktrees: https://code.claude.com/docs/en/worktrees · Best practices: https://code.claude.com/docs/en/best-practices
- JSON schemas: https://www.schemastore.org/claude-code-settings.json , …/claude-code-marketplace.json , …/claude-code-plugin-manifest.json
