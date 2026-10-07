# 11. 도구 지원 매트릭스 (2026-10 기준)

## 1. 규칙 파일과 AGENTS.md

| 도구 | 규칙 파일 | `AGENTS.md` 네이티브 | 중첩(하위 디렉터리) | 비고 |
| --- | --- | --- | --- | --- |
| Claude Code | `CLAUDE.md`, `.claude/rules/*.md`(paths) | ○ v2.1.277+(CLAUDE.md 없을 때) / `@AGENTS.md` import | ○ | 심링크 가능(Windows 주의) |
| GitHub Copilot(클라우드 에이전트, 코드 리뷰, CLI, VS Code) | `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`(applyTo), `.github/agents/*.agent.md`, `REVIEW.md` | ○ | ○(VS Code 로컬은 실험) | `CLAUDE.md`/`GEMINI.md` 루트도 읽음 |
| Cursor | `.cursor/rules/*.mdc`(globs/alwaysApply) | ○ | ○ | `.cursorrules` 레거시 |
| OpenAI Codex | `.codex/config.toml`(선택) | ○(루트→cwd 연결, 32KiB) | ○ | `AGENTS.override.md` |
| Gemini CLI | `GEMINI.md`, `.gemini/settings.json` | 설정 필요 `context.fileName` | ○ | v2 중첩 키 |
| Google Jules | — | ○ 루트 | ? | 라벨 `jules` |
| Amp | — | ○(+`AGENT.md`, `CLAUDE.md` 폴백) | ○ | |
| Factory droid | `.factory/` | ○ | ○ | 80k/40k chars |
| Devin / Devin Desktop(구 Windsurf) | `.devin/rules/`, `.windsurf/rules/` | ○ | ○ | 12,000 chars/file |
| Zed | `.rules` 등 첫 매칭 1개 | ○(앞선 이름에 가려짐) | ✕ | 이 레포는 `.rules` 포인터 |
| Warp | `WARP.md`(레거시) | ○ | ○ | |
| Aider | `.aider.conf.yml` `read:` | 자동 로드 없음 → `read: [AGENTS.md]` | — | |
| Junie(JetBrains) | `.junie/guidelines.md`(레거시) | ○ | ? | |
| Kiro | `.kiro/steering/*.md` | ○ | ○ | 항상 포함 |
| Cline | `.clinerules/` | ○ | ? | |
| Roo Code | `.roo/rules/` | ○ 루트 | ✕ | |
| Continue | `.continue/rules/` | 문서화되지 않은 폴백 | ✕ | 포인터 파일 권장 |
| Augment | `.augment/rules/` | ○ | ○ | |

## 2. PR 리뷰 봇

| 봇 | 자동 트리거 | 수동 트리거 | 설정 | 승인 집계 |
| --- | --- | --- | --- | --- |
| Claude(action) | PR opened/synchronize | `@claude` | 워크플로 프롬프트, `REVIEW.md` | ✕ |
| Claude Code Review(관리형) | 레포 설정 | `@claude review` | `CLAUDE.md`, `REVIEW.md` | ✕(neutral) |
| Copilot code review | 룰셋 | 리뷰어에 Copilot 추가 | instructions, `REVIEW.md` | 옵션 |
| CodeRabbit | 자동 | `@coderabbitai review` | `.coderabbit.yaml` | 옵션 |
| Codex | Automatic review 설정 | `@codex review` | `AGENTS.md` | ✕ |
| Gemini Code Assist(엔터프라이즈) | 자동 | `/gemini review` | `.gemini/config.yaml` | ✕ |
| Cursor Bugbot | 자동 | `bugbot run` | `.cursor/BUGBOT.md` | ✕ |
| Devin Review | — | `/devin review` | — | ✕ |

## 3. 이슈 → PR 에이전트

| 에이전트 | 시작 | 결과 | 환경 설정 |
| --- | --- | --- | --- |
| Claude(action, 이 레포) | 라벨 `ai:ready`, `@claude`, 담당자 | 브랜치 + 초안 PR | 워크플로 내 toolchain 단계 |
| Copilot 클라우드 에이전트 | 담당자 Copilot, `gh agent-task create`, MCP | 초안 PR(`copilot/*`) | `copilot-setup-steps.yml`, 레포 MCP/방화벽 설정 |
| Codex 클라우드 | 앱/`@codex` 댓글 | PR | 설정 UI |
| Jules | 라벨 `jules` | PR | Jules UI 셋업 스크립트 |
| Cursor Cloud Agent | 대시보드/Bugbot autofix | PR | `.cursor/environment.json` |
| Devin | `/devin <prompt>` | PR | — |

## 4. 비용·플랜 메모(변동 잦음, 각 사이트 확인)

Copilot 리뷰 Lite $0.05–1 / Balanced $0.25–5(크레딧) · Claude Code Review 관리형 $15–25/리뷰(Team/Enterprise) · CodeRabbit $24–72/dev/월(공개 레포 무료) · Codex Plus 이상 · Gemini Code Assist 엔터프라이즈 시트.

## 출처

agents.md(https://agents.md/), GitHub custom-instructions-support(https://docs.github.com/en/copilot/reference/custom-instructions-support), Cursor rules(https://cursor.com/docs/context/rules), Codex AGENTS.md(https://learn.chatgpt.com/docs/agent-configuration/agents-md), Gemini CLI(https://geminicli.com/docs/cli/gemini-md/), Jules(https://jules.google/docs), Amp(https://ampcode.com/docs/customize/agents-md), Factory(https://docs.factory.com/cli/configuration/agents-md), Devin(https://docs.devin.ai), Zed(https://zed.dev/docs/ai/instructions.md), Warp(https://docs.warp.dev/agents/capabilities/rules), Aider(https://aider.chat/docs/usage/conventions.html), Junie(https://junie.jetbrains.com/docs/), Kiro(https://kiro.dev/docs/steering), Cline(https://docs.cline.bot/features/cline-rules), Roo(https://roocodeinc.github.io/Roo-Code/), Continue(https://docs.continue.dev), Augment(https://docs.augmentcode.com/cli/rules), CodeRabbit(https://docs.coderabbit.ai), Bugbot(https://cursor.com/docs/bugbot), Devin GitHub(https://docs.devin.ai/integrations/gh).
