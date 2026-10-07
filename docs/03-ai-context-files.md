# 03. AI 컨텍스트 파일 — `AGENTS.md` 단일 소스와 도구별 래퍼

## 1. 왜 단일 소스인가

팀원마다 Claude Code, Copilot, Cursor, Codex, Gemini CLI를 섞어 쓴다. 규칙 파일이 도구마다 따로 있으면 금방 어긋난다.
`AGENTS.md`는 OpenAI·Google·Cursor·Factory 등이 함께 만든 열린 포맷으로, 2025-12부터 **Linux Foundation 산하 Agentic AI Foundation**이 관리하며 6만 개 이상 프로젝트가 쓴다. Codex, Copilot(클라우드 에이전트·코드 리뷰·CLI·VS Code), Cursor, Jules, Amp, Warp, Factory, Devin, Junie, Kiro, Zed, Claude Code(v2.1.277+)가 읽는다. Thoughtworks Radar Vol.34(2026-04)는 "팀 공용 지침 파일을 레포에 커밋"을 **Adopt**로 올렸다.

## 2. 이 레포의 파일 맵

| 파일 | 역할 | 누가 읽나 |
| --- | --- | --- |
| `AGENTS.md` | **단일 소스**(명령, 워크플로, 코딩/테스트/git 규칙, 보호 경로, 에이전트 행동) | Codex, Copilot, Cursor, Jules, Amp, Warp, Factory, Devin, Junie, Kiro, Claude Code(네이티브 또는 import) |
| `CLAUDE.md` | `@AGENTS.md` import + Claude 전용 메모(스킬/서브에이전트/훅 안내) | Claude Code, Copilot(루트 CLAUDE.md도 읽음) |
| `.claude/rules/*.md` | `paths:` 프런트매터로 경로별 규칙(워크플로, 테스트, AI 설정) | Claude Code (해당 파일을 만질 때만 로드) |
| `.github/copilot-instructions.md` | 포인터 + Copilot 전용 메모 | Copilot 전 표면 |
| `.github/instructions/*.instructions.md` | `applyTo:` 글롭 경로 규칙 | Copilot(VS Code, 클라우드 에이전트, 코드 리뷰, CLI) |
| `.github/agents/*.agent.md` | Copilot 커스텀 에이전트(reviewer, test-specialist) | Copilot |
| `REVIEW.md` | 리뷰 기준 | Copilot code review, Claude Code Review, Bugbot/Gemini 스타일가이드가 참조 |
| `.cursor/rules/*.mdc` | 포인터(alwaysApply) + `globs` 경로 규칙 | Cursor |
| `.cursor/BUGBOT.md` | Bugbot 리뷰 규칙 | Cursor Bugbot |
| `GEMINI.md` + `.gemini/settings.json` | 설정이 `AGENTS.md`를 컨텍스트 파일로 지정; GEMINI.md는 Gemini 전용 메모만 | Gemini CLI |
| `.gemini/config.yaml`, `styleguide.md` | Gemini Code Assist PR 리뷰(엔터프라이즈) | Gemini Code Assist |
| `.aider.conf.yml` | `read: [AGENTS.md]`, 테스트/린트 명령 | Aider |
| `.codex/config.toml` | 프로젝트 Codex 설정(신뢰한 프로젝트만 로드) | Codex |
| `.rules` | Zed용 한 줄 포인터(Zed는 첫 매칭 파일만 읽음) | Zed |
| `.claude/skills/`, `plugins/*/skills/` | 절차(스킬). Copilot도 `.claude/skills/`의 SKILL.md를 읽는다 | Claude Code, Copilot |

규칙: **래퍼는 가리키기만 하고 복사하지 않는다.** Copilot은 `copilot-instructions.md`와 `AGENTS.md`를 둘 다 로드하므로 복사하면 중복 토큰과 불일치가 생긴다.

## 3. `AGENTS.md` 작성 규칙

GitHub가 2,500개 레포를 분석한 결론과 Anthropic·OpenAI 가이드를 합치면:

1. **명령을 맨 앞에**, 정확한 플래그와 함께(빌드·테스트·린트·타입체크). 이 레포는 `make` 타깃으로 고정했고 CI가 같은 명령을 돈다.
2. **코드에서 유추할 수 있는 것은 쓰지 않는다.** 아키텍처 결정, 기본값과 다른 스타일, 테스트 러너, 레포 에티켓(브랜치·PR), 환경의 함정만.
3. **경계 3단계**: Always do / Ask first / Never do. 비밀 커밋 금지가 가장 흔한 규칙.
4. **200줄 이하**(Anthropic: "비대한 CLAUDE.md는 실제 지시를 무시하게 만든다"). Codex는 체인 합계 32KiB 기본 상한, Cursor는 규칙 500줄 권장.
5. **짧고 정확한 파일이 길고 모호한 파일보다 낫다**(OpenAI). 반복 실수를 관찰한 뒤에만 규칙을 추가한다.
6. 스타일은 설명보다 **실제 코드 한 조각**이 낫다.
7. 지시 파일은 **컨텍스트이지 강제가 아니다**. 반드시 막아야 하면 훅(PreToolUse)이나 CI로 강제한다(`plugins/team-ai-workflow/hooks`).

## 4. 모노레포·경로 규칙

- 패키지마다 `AGENTS.md`를 둘 수 있다. "편집 중인 파일에 가장 가까운 AGENTS.md가 이긴다"(agents.md 표준). Claude Code도 하위 디렉터리 파일을 읽을 때 해당 `CLAUDE.md`/`AGENTS.md`를 지연 로드한다.
- 경로별 규칙: Claude `.claude/rules/*.md`(`paths:`), Copilot `.github/instructions/*.instructions.md`(`applyTo:`), Cursor `.mdc`(`globs:`). 세 파일의 내용은 같은 규칙을 담되, 길어지면 `docs/`에 쓰고 링크한다.
- 다른 레포를 함께 봐야 하면 Claude Code `--add-dir ../other-repo`(또는 `permissions.additionalDirectories`).

## 5. 도구별 세부

### Claude Code

- v2.1.277+는 경로에 `CLAUDE.md`가 없으면 `AGENTS.md`를 네이티브로 읽는다. 이 레포는 Claude 전용 메모가 필요해 `CLAUDE.md`에 `@AGENTS.md`를 import한다(최대 4단계, 코드 블록 안의 `@`는 무시).
- 심링크(`ln -s AGENTS.md CLAUDE.md`)도 되지만 Windows에서 일반 텍스트로 체크아웃될 수 있어 import 방식을 쓴다.
- `/init`은 `.cursor/rules`, `.github/copilot-instructions.md` 등을 가져와 CLAUDE.md를 만든다. `claude import codex|gemini|cursor`로 다른 도구 설정을 가져올 수 있다.

### Copilot

- 우선순위: 개인 지침 > 레포 지침 > 조직 지침. 레포 전체 + 경로 지침은 **합쳐서** 적용.
- 클라우드 에이전트·코드 리뷰는 `AGENTS.md`(가장 가까운 파일), 루트 `CLAUDE.md`/`GEMINI.md`, `REVIEW.md`, 스킬까지 읽는다(2026-07부터).
- `.github/workflows/copilot-setup-steps.yml`이 에이전트 환경을 준비한다(잡 이름 고정).
- 구형 `.chatmode.md` → `.agent.md`, 프롬프트 파일(`.prompt.md`)은 Agent Host에서 deprecated → 스킬로 이전.

### Cursor

- `AGENTS.md`를 루트와 하위 디렉터리에서 읽는다. `.cursorrules`는 레거시(현재 문서에 언급 없음) — 만들지 않는다(Zed에서 AGENTS.md를 가리기도 함).
- `.mdc` 유형: Always Apply / Apply Intelligently(description) / Apply to Specific Files(globs) / Apply Manually.

### Gemini CLI

- 기본 컨텍스트 파일은 `GEMINI.md`. `.gemini/settings.json`의 `context.fileName: ["AGENTS.md","GEMINI.md"]`로 둘 다 로드(v2 중첩 키 형식).
- `/memory list|show|refresh`, `@./path.md` import 지원.

### Codex

- `AGENTS.md`를 git 루트→작업 디렉터리 순으로 이어 붙여 읽는다(`AGENTS.override.md` 우선). PR 리뷰 규칙은 `## Code Review Rules` 섹션(이 레포는 `REVIEW.md`를 가리키는 문장을 AGENTS.md에 넣어도 된다).

## 6. 여러 도구용 파일을 자동 생성하고 싶다면

Ruler(`npx @intellectronica/ruler apply`, ~2.9k★)나 rulesync(`npx rulesync generate`, ~1.5k★)가 `.ruler/AGENTS.md` 한 곳에서 각 도구 파일을 생성한다. 이 레포는 생성 도구 없이 "포인터 래퍼" 방식을 택했다(ADR-0001). 도구 수가 많아지면 도입을 검토한다.

## 7. 유지보수

- 규칙 변경은 PR + CODEOWNERS 리뷰(`.claude/rules/ai-config.md`).
- `make ai-validate`가 프런트매터·스키마·길이(≤200줄)를 검사한다.
- 분기마다(또는 주요 모델 출시 후) 규칙을 다듬는다: 더 이상 틀리지 않는 규칙은 지운다.

## 출처

- agents.md: https://agents.md/ · Agentic AI Foundation: https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation
- GitHub, How to write a great agents.md (2,500 repos): https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/
- GitHub custom instructions support matrix: https://docs.github.com/en/copilot/reference/custom-instructions-support
- Claude Code memory/imports: https://code.claude.com/docs/en/memory
- Cursor rules: https://cursor.com/docs/context/rules · Gemini CLI config: https://geminicli.com/docs/reference/configuration/ · Codex AGENTS.md: https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Thoughtworks Radar, Curated shared instructions (Adopt): https://www.thoughtworks.com/radar/techniques/curated-shared-instructions-for-software-teams
- Ruler: https://github.com/intellectronica/ruler · rulesync: https://github.com/dyoshikawa/rulesync
