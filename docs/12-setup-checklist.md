# 12. 셋업 체크리스트

## A. 허브(이 템플릿 레포) 관리자

- [ ] Settings → General → **Default branch**를 `main`으로, **Template repository** 체크
- [ ] Settings → Actions → General → Workflow permissions → **"Allow GitHub Actions to create and approve pull requests"** 체크 (release-please·Dependabot 자동 머지에 필요; `make github-setup`이 API로도 설정)
- [ ] `make github-setup`(설정·라벨·룰셋) — rulesets는 공개 레포 또는 Pro/Team/Enterprise
- [ ] AI 백엔드 결정(`docs/13-ai-backends.md`): 기본은 아무것도 안 함(개발자가 `make ai-*`). 서버 자동화를 원하면 `AI_BACKEND` 변수 + (`local`: `AI_BASE_URL`/`AI_MODEL`, `anthropic`: `CLAUDE_CODE_OAUTH_TOKEN` 또는 `ANTHROPIC_API_KEY` + Claude GitHub App)
- [ ] 선택 시크릿: `RELEASE_PLEASE_TOKEN`, `REPO_ADMIN_TOKEN`
- [ ] `.github/CODEOWNERS`의 `@OWNER` 교체, `ISSUE_TEMPLATE/config.yml`의 `OWNER/REPO` 교체
- [ ] `.claude/settings.json`의 `extraKnownMarketplaces.ai-collab.source.repo`를 허브 경로로
- [ ] 플러그인 릴리스: `plugins/team-ai-workflow/.claude-plugin/plugin.json`과 `marketplace.json` 버전 동일 → `claude plugin tag plugins/team-ai-workflow`
- [ ] Settings → Pages → Source: **GitHub Actions**, Environments → `github-pages`에서 `main` 배포 허용 (`work-board.yml`이 해설 페이지와 `board.json` 게시)
- [ ] 팀 작업 보드: `.github/work-board-repos.txt`에 팀 레포 나열. 비공개 레포가 있으면 해당 레포를 읽을 수 있는 PAT를 시크릿 `BOARD_TOKEN`으로
- [ ] 권한 다이어트 적용: `scripts/apply-lean-permissions.sh` 실행 후 PR (`docs/15-lean-harness.md`)
- [ ] 선택: Copilot 자동 리뷰 룰셋(`scripts/rulesets/optional-copilot-review.json`), CodeRabbit/Codex 앱

## B. 새 제품 레포(스포크)

- [ ] `make new-repo REPO=org/name VISIBILITY=private` (또는 GitHub UI "Use this template" 후 `make setup`)
- [ ] `AGENTS.md`의 Project 섹션 작성, Commands 표 확인(`make check`가 실제로 돌아야 함)
- [ ] `CODEOWNERS`, `labels.yml`의 `area/*`, `release-please-config.json`의 `release-type`
- [ ] `ci.yml` 툴체인 버전(`vars.NODE_VERSION`/`PYTHON_VERSION`), `codeql.yml` 언어 매트릭스
- [ ] AI 백엔드(A와 동일, 선택), `make github-setup`
- [ ] 변수 `DESIGN_BOARD_URL`=허브의 `https://<owner>.github.io/<hub>/board.json` (PR 겹침 확인과 세션 시작 요약이 팀 전체 보드를 봄), 허브의 `work-board-repos.txt`에 이 레포 추가
- [ ] 첫 PR을 열어 `ci-ok`, `pr-checks`, `Claude Code Review`가 도는지 확인
- [ ] 이슈 하나로 `make ai-triage ISSUE=1`, `make ai-implement ISSUE=1 POST=1`을 끝까지 확인(초안 PR + `ai:review`)

## C. 팀원 온보딩(10분)

- [ ] 도구: `git`, `jq`, `gh`(`gh auth login`), `claude`(`npm i -g @anthropic-ai/claude-code`, 한 번 실행해 구독 로그인), `pre-commit`
- [ ] `git clone … && make setup` → 마지막 "ALL CHECKS PASSED" 확인
- [ ] Claude Code: 첫 세션에서 플러그인 설치 수락(또는 `claude plugin install team-ai-workflow@ai-collab`), `/onboard`
- [ ] VS Code: 권장 확장 설치 팝업 수락(`.vscode/extensions.json`), GitHub MCP는 `.vscode/mcp.json`(PAT 프롬프트)
- [ ] Cursor/Gemini/Codex 사용자: 추가 설정 없음(`AGENTS.md` 자동 인식). Aider는 `.aider.conf.yml` 자동
- [ ] `docs/01-playbook.md` 읽기, `CONTRIBUTING.md`의 AI 공개 규칙 숙지
- [ ] Windows: `git config core.symlinks true`는 불필요(심링크 미사용). Git Bash 또는 WSL에서 `make` 사용

## D. 검증 명령

```bash
make ai-validate          # 설정 전체 검증(로컬)
make check                # 린트+타입+테스트
scripts/setup-github.sh check
claude plugin validate ./plugins/team-ai-workflow --strict
gh workflow list          # 워크플로 등록 확인
```

## E. 자주 묻는 문제

- **워크플로가 안 돈다**: 템플릿에서 만든 레포는 Actions가 꺼져 있을 수 있음 → Actions 탭에서 활성화, 한 번 push.
- **release-please가 "GitHub Actions is not permitted to create or approve pull requests"로 실패**: 위 Actions 설정 체크박스를 켠다.
- **라벨이 없다**: Actions 탭 → "Sync labels" → Run workflow (또는 `.github/labels.yml`을 수정해 main에 push).
- **AI 워크플로가 항상 skipped**: 의도된 기본값. `AI_BACKEND` 변수를 설정해야 켜진다(docs/13).
- **Claude 액션이 "write access" 거부**: 트리거한 사람에게 쓰기 권한이 없음. 공개 레포 트리아지는 워크플로 주석의 `allowed_non_write_users` 참고.
- **에이전트 PR에 CI가 안 돈다**: `github_token`을 직접 넘기면 `GITHUB_TOKEN`이라 워크플로가 연쇄 트리거되지 않음 → 앱 인증(기본) 사용.
- **룰셋 생성 403**: admin 권한 필요. 개인 private 레포는 플랜 제한.
- **훅이 편집을 막았다**: 의도된 보호 경로. 사람이 직접 수정하고 PR에 사유를 적는다.
