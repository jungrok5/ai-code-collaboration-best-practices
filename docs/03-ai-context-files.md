# 03. AI 컨텍스트 파일: `AGENTS.md` 단일 소스와 도구별 래퍼

## 1. 단일 소스를 쓰는 이유

팀원들은 Claude Code, Copilot, Cursor, Codex, Gemini CLI를 함께 사용합니다. 규칙 파일이 도구마다 따로 있으면 내용이
곧 서로 어긋납니다.

`AGENTS.md`는 OpenAI·Google·Cursor·Factory 등이 함께 만든 개방형 포맷입니다. 2025-12부터 Linux Foundation 산하
Agentic AI Foundation이 관리하며 6만 개 이상의 프로젝트가 사용합니다. Codex, Copilot(클라우드 에이전트·코드 리뷰·CLI·VS
Code), Cursor, Jules, Amp, Warp, Factory, Devin, Junie, Kiro, Zed, Claude Code(v2.1.277+)가 이 파일을 읽습니다.
Thoughtworks Radar Vol.34(2026-04)는 "팀 공용 지침 파일을 레포에 커밋"하는 기법을 Adopt 단계로 올렸습니다.

## 2. 이 레포의 파일 맵

| 파일 | 역할 | 읽는 도구 |
| --- | --- | --- |
| `AGENTS.md` | 단일 소스(명령, 워크플로, 코딩/테스트/git 규칙, 보호 경로, 에이전트 행동) | Codex, Copilot, Cursor, Jules, Amp, Warp, Factory, Devin, Junie, Kiro, Claude Code(네이티브 또는 import) |
| `CLAUDE.md` | `@AGENTS.md` import + Claude 전용 메모(스킬/서브에이전트/훅 안내) | Claude Code, Copilot(루트 CLAUDE.md도 읽음) |
| `.claude/rules/*.md` | `paths:` 프런트매터 기반 경로별 규칙(워크플로, 테스트, AI 설정, 글·화면) | Claude Code (해당 파일을 다룰 때만 로드) |
| `.github/copilot-instructions.md` | 포인터 + Copilot 전용 메모 | Copilot 전 표면 |
| `.github/instructions/*.instructions.md` | `applyTo:` 글롭 기반 경로 규칙 | Copilot(VS Code, 클라우드 에이전트, 코드 리뷰, CLI) |
| `.github/agents/*.agent.md` | Copilot 커스텀 에이전트(reviewer, test-specialist) | Copilot |
| `REVIEW.md` | 리뷰 기준 | Copilot code review, Claude Code Review, Bugbot/Gemini 스타일가이드가 참조 |
| `.cursor/rules/*.mdc` | 포인터(alwaysApply) + `globs` 경로 규칙 | Cursor |
| `.cursor/BUGBOT.md` | Bugbot 리뷰 규칙 | Cursor Bugbot |
| `GEMINI.md` + `.gemini/settings.json` | 설정에서 `AGENTS.md`를 컨텍스트 파일로 지정, GEMINI.md에는 Gemini 전용 메모만 | Gemini CLI |
| `.gemini/config.yaml`, `styleguide.md` | Gemini Code Assist PR 리뷰(엔터프라이즈) | Gemini Code Assist |
| `.aider.conf.yml` | `read: [AGENTS.md]`, 테스트/린트 명령 | Aider |
| `.codex/config.toml` | 프로젝트 Codex 설정(신뢰한 프로젝트만 로드) | Codex |
| `.rules` | Zed용 한 줄 포인터(Zed는 첫 번째로 매칭된 파일만 읽음) | Zed |
| `.claude/skills/`, `plugins/*/skills/` | 절차(스킬). Copilot도 `.claude/skills/`의 SKILL.md를 읽음 | Claude Code, Copilot |

래퍼 파일은 `AGENTS.md`를 가리키기만 하고 내용을 복사하지 않습니다. Copilot은 `copilot-instructions.md`와
`AGENTS.md`를 모두 로드하므로, 내용을 복사하면 토큰이 중복되고 두 파일이 어긋납니다.

## 3. `AGENTS.md` 작성 규칙

GitHub의 레포 2,500개 분석 결과와 Anthropic·OpenAI 가이드를 종합한 규칙입니다.

1. 명령을 맨 앞에, 정확한 플래그와 함께 적습니다(빌드·테스트·린트·타입체크). 이 레포는 명령을 `make` 타깃으로
   고정했고 CI도 같은 명령을 실행합니다.
2. 코드에서 알 수 있는 내용은 적지 않습니다. 아키텍처 결정, 기본값과 다른 스타일, 테스트 러너, 레포 에티켓(브랜치·PR),
   환경의 함정만 적습니다.
3. 경계는 Always do / Ask first / Never do 3단계로 나눕니다. 가장 흔한 규칙은 비밀 커밋 금지입니다.
4. 짧게 작성합니다. Anthropic은 "비대한 CLAUDE.md는 실제 지시를 무시하게 만든다"고 설명합니다. 판단 기준은 줄 수가
   아니라 "이 줄을 지우면 에이전트가 실수하는가?"입니다. 이 레포의 `AGENTS.md`는 약 60줄이며, 150줄을 넘으면
   `make ai-validate`가 경고합니다([15](15-lean-harness.md)). Codex는 체인 합계 32KiB가 기본 상한이고, Cursor는 규칙을
   500줄 이하로 유지하도록 권장합니다.
5. OpenAI 가이드에 따르면 짧고 정확한 파일이 길고 모호한 파일보다 효과가 큽니다. 규칙은 반복되는 실수를 확인한 뒤에만
   추가합니다.
6. 스타일은 설명 대신 실제 코드 한 조각으로 제시합니다.
7. 지시 파일은 컨텍스트일 뿐 강제력이 없습니다. 반드시 막아야 하는 동작은 훅(PreToolUse)이나 CI로 차단합니다
   (`plugins/team-ai-workflow/hooks`).

## 4. 모노레포·경로 규칙

- 패키지마다 `AGENTS.md`를 둘 수 있습니다. agents.md 표준에서는 편집 중인 파일에 가장 가까운 AGENTS.md가 우선합니다.
  Claude Code도 하위 디렉터리의 파일을 읽을 때 그 디렉터리의 `CLAUDE.md`/`AGENTS.md`를 지연 로드합니다.
- 경로별 규칙의 위치는 도구마다 다릅니다: Claude `.claude/rules/*.md`(`paths:`), Copilot
  `.github/instructions/*.instructions.md`(`applyTo:`), Cursor `.mdc`(`globs:`). 세 위치에 같은 규칙을 두고, 내용이
  길어지면 `docs/`에 작성한 뒤 링크합니다.
- 다른 레포를 함께 참조해야 하면 Claude Code에서 `--add-dir ../other-repo`(또는 `permissions.additionalDirectories`)를
  사용합니다.

## 5. 도구별 세부

### Claude Code

- v2.1.277+는 경로에 `CLAUDE.md`가 없으면 `AGENTS.md`를 직접 읽습니다. 이 레포는 Claude 전용 메모가 필요하므로
  `CLAUDE.md`에서 `@AGENTS.md`를 import합니다(최대 4단계, 코드 블록 안의 `@`는 무시).
- 심링크(`ln -s AGENTS.md CLAUDE.md`)도 동작하지만 Windows에서는 일반 텍스트 파일로 체크아웃될 수 있어 import 방식을
  사용합니다.
- `/init`은 `.cursor/rules`, `.github/copilot-instructions.md` 등을 읽어 CLAUDE.md를 생성합니다.
  `claude import codex|gemini|cursor`로 다른 도구의 설정을 가져올 수 있습니다.

### Copilot

- 우선순위: 개인 지침 > 레포 지침 > 조직 지침. 레포 전체 지침과 경로 지침은 합쳐서 적용됩니다.
- 2026-07부터 클라우드 에이전트와 코드 리뷰는 `AGENTS.md`(가장 가까운 파일), 루트 `CLAUDE.md`/`GEMINI.md`,
  `REVIEW.md`, 스킬까지 읽습니다.
- `.github/workflows/copilot-setup-steps.yml`이 에이전트 환경을 준비합니다(잡 이름 고정).
- 구형 `.chatmode.md`는 `.agent.md`로 대체되었습니다. 프롬프트 파일(`.prompt.md`)은 Agent Host에서 deprecated
  상태이므로 스킬로 옮깁니다.

### Cursor

- `AGENTS.md`를 루트와 하위 디렉터리에서 읽습니다. `.cursorrules`는 레거시이며 현재 문서에 나오지 않으므로 만들지
  않습니다. 이 파일은 Zed에서 AGENTS.md보다 먼저 읽혀 AGENTS.md를 가리기도 합니다.
- `.mdc` 유형: Always Apply / Apply Intelligently(description) / Apply to Specific Files(globs) / Apply Manually.

### Gemini CLI

- 기본 컨텍스트 파일은 `GEMINI.md`입니다. `.gemini/settings.json`의 `context.fileName: ["AGENTS.md","GEMINI.md"]`로
  두 파일을 모두 로드합니다(v2 중첩 키 형식).
- `/memory list|show|refresh`와 `@./path.md` import를 지원합니다.

### Codex

- `AGENTS.md`를 git 루트부터 작업 디렉터리까지 차례로 이어 붙여 읽습니다(`AGENTS.override.md`가 우선). PR 리뷰 규칙은
  `## Code Review Rules` 섹션에 둡니다. 이 레포에서는 AGENTS.md에 `REVIEW.md`를 가리키는 문장을 넣는 방법도 가능합니다.

## 6. 여러 도구용 파일 자동 생성

Ruler(`npx @intellectronica/ruler apply`, ~2.9k★)와 rulesync(`npx rulesync generate`, ~1.5k★)는 `.ruler/AGENTS.md`
한 곳에서 도구별 파일을 생성합니다. 이 레포는 생성 도구 없이 포인터 래퍼 방식을 선택했습니다(ADR-0001). 지원할 도구가
더 늘어나면 도입을 검토합니다.

## 7. 유지보수

- 규칙 변경은 PR과 CODEOWNERS 리뷰를 거칩니다(`.claude/rules/ai-config.md`).
- `make ai-validate`가 프런트매터와 스키마를 검사하고, `AGENTS.md`가 150줄을 넘으면 경고합니다.
- 분기마다(또는 주요 모델 출시 후) 규칙을 정리합니다. 에이전트가 더 이상 틀리지 않는 규칙은 삭제합니다.

## 출처

- agents.md: https://agents.md/ · Agentic AI Foundation: https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation
- GitHub, How to write a great agents.md (2,500 repos): https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/
- GitHub custom instructions support matrix: https://docs.github.com/en/copilot/reference/custom-instructions-support
- Claude Code memory/imports: https://code.claude.com/docs/en/memory
- Cursor rules: https://cursor.com/docs/context/rules · Gemini CLI config: https://geminicli.com/docs/reference/configuration/ · Codex AGENTS.md: https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Thoughtworks Radar, Curated shared instructions (Adopt): https://www.thoughtworks.com/radar/techniques/curated-shared-instructions-for-software-teams
- Ruler: https://github.com/intellectronica/ruler · rulesync: https://github.com/dyoshikawa/rulesync
