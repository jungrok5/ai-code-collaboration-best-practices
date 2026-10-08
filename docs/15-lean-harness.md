# 15. 가벼운 하네스 — 최신 모델에 맞게 덜어내기

## 1. 왜 덜어내나

초기 에이전트 하네스는 지시를 잘 안 따르는 모델을 기준으로 만들어졌습니다. "반드시", "절대", 단계별 체크리스트, 넓은 `ask` 목록이 그 흔적입니다. 지금 모델은 지시를 **문자 그대로, 강하게** 따르기 때문에 같은 하네스가 오히려 해가 됩니다.

| 근거 | 내용 |
| --- | --- |
| Anthropic, Claude Code best practices | CLAUDE.md 각 줄마다 "이걸 지우면 Claude가 실수하나?"를 묻고, 아니면 지운다. 너무 길면 중요한 규칙이 묻힌다 |
| Anthropic, 프롬프트 가이드(최신 모델) | 예전 모델용 `CRITICAL`/`MUST` 강조는 이제 과잉 반응을 부른다. 톤을 낮추고 **이유**를 설명하라 |
| Anthropic, 하네스 설계 글 | 하네스 구성요소는 "모델이 혼자 못 하는 것"에 대한 가정이고, 모델이 좋아지면 낡는다. 업그레이드마다 다시 검증 |
| ETH Zurich, AGENTS.md 연구 (2026) | 컨텍스트 파일은 과제 성공률을 거의 올리지 못하고 비용은 20% 이상 늘렸다. 도움 되는 것은 **명령어와 레포 특유의 함정** 정도 |
| OpenAI, GPT-5 프롬프트 가이드 | 모순되거나 지나치게 단호한 지시는 모델이 조정하느라 추론을 낭비한다 |

## 2. 남기고, 풀고, 지운 것

| 구분 | 무엇 | 이유 |
| --- | --- | --- |
| **남김** | 보호 경로 훅, `main` 직접 커밋·force-push 차단, CI, CODEOWNERS·룰셋, 샌드박스 | 결정적 안전장치. 모델이 좋아져도 사고 비용이 크다 |
| **남김** | 명령어 표, 레포 특유의 함정 | 연구상 실제로 도움 되는 부분 |
| **풀음** (사람이 §3 스크립트 실행 후) | 일상적인 `git push`/`gh pr create`/`gh issue comment` 등의 `ask` 목록 | auto 모드 분류기가 판단. 매번 묻는 것은 피로만 늘린다 |
| **풀음** | "반드시/절대" 톤, AGENTS.md 200줄 상한(실패→150줄 경고) | 과잉 반응 방지 |
| **지움** | 800줄 초과 커밋 차단 훅(과 이를 위한 `AI_MAX_*` 환경 변수) | PR 크기는 라벨과 리뷰로 다룬다. 커밋 단위 차단은 작업만 쪼갠다 |
| **지움** | Stop 훅의 요약 리마인더 | 모델이 이미 한다 |
| **지움** | 모델 기본 동작을 반복하는 단계별 스킬 본문 | 기존 스킬 8개를 목표·제약 위주로 다시 썼다(새 `/design`, `/check-overlap` 포함 10개 합계 약 100줄) |

AGENTS.md는 120줄 → 55줄, 규칙 파일은 "왜"를 한 줄씩 붙인 짧은 문장으로 바꿨습니다.

## 3. 권한: auto 모드 + 좁은 deny

auto 모드는 분류기가 위험한 동작만 확인합니다. 단, 우선순위는 `deny` > `ask` > 분류기입니다. `ask`에 넣은 것은 auto여도 **항상** 묻습니다. 그래서 `ask`는 `rm -r`/`rm -rf`만 남기고, 되돌리기 어려운 것만 `deny`로 막습니다.

auto 모드는 기본 브랜치로의 push를 허용하므로 deny에 명시합니다.

```text
deny 추가: git push origin main, git push origin main *, git push * HEAD:main, gh pr merge *
ask: 기존 목록 전체를 rm -r / rm -rf 두 개로 교체
deny 유지: 비밀 파일, 파괴적 git, gh auth * (토큰 출력 방지)
allow 추가: gh repo view *, gh workflow list *, python3 scripts/designs/board.py *
defaultMode: auto
env 제거: AI_MAX_COMMIT_LINES, AI_MAX_PR_LINES (읽는 훅이 없음)
```

`.claude/settings.json`은 팀 정책 파일이라 에이전트가 직접 고치면 분류기가 "자기 권한 수정"으로 막습니다(의도된 동작). 사람이 실행합니다.

```bash
scripts/apply-lean-permissions.sh   # jq로 위 변경 적용, 멱등
git diff .claude/settings.json      # 확인 후 PR
```

## 4. 모델을 올릴 때마다 하는 점검 (30분)

1. AGENTS.md·규칙·스킬을 한 줄씩 보며 "지우면 실수하나?" — 아니면 지운다.
2. 훅이 지난 한 달 실제로 막은 기록을 본다. 한 번도 안 막았고 안전장치도 아니면 지운다.
3. `ask` 목록에서 매번 "허용"만 누른 항목은 allow나 분류기로 넘긴다.
4. 새 모델이 반복해서 틀리는 것이 있으면 그때 **한 줄** 추가한다(이유 포함).

## 출처

- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Claude 프롬프트 가이드: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- Claude Code 권한·auto 모드: https://code.claude.com/docs/en/permissions
- Anthropic, Harness design for long-running apps: https://www.anthropic.com/engineering/harness-design-long-running-apps
- ETH Zurich, Evaluating AGENTS.md: https://arxiv.org/abs/2602.11988
- OpenAI GPT-5 prompting guide: https://cookbook.openai.com/examples/gpt-5/gpt-5_prompting_guide
