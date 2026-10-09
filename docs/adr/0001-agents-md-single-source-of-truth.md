# ADR-0001: `AGENTS.md`를 단일 소스로, 도구별 파일은 포인터 래퍼로

- 상태: Accepted
- 날짜: 2026-10-07

## 맥락

팀원이 Claude Code, Copilot, Cursor, Codex, Gemini CLI를 함께 사용합니다. 도구마다 규칙 파일을 복사하면 내용이 빠르게 어긋납니다. 일부 도구(Copilot, Augment, Claude `claude-md-and-agents-md` 모드)는 여러 파일을 동시에 읽으므로 중복이 토큰 낭비와 모순을 유발합니다. `AGENTS.md`는 2025-12부터 Linux Foundation AAIF가 관리하는 열린 표준이며 주요 도구가 네이티브로 읽습니다.

## 고려한 선택지

1. 도구별 파일 각각 유지: 익숙함 / 드리프트, 중복
2. 생성 도구(Ruler/rulesync)로 각 파일 생성: 자동 일관성 / 추가 도구·생성 파일 커밋, 학습 비용
3. **`AGENTS.md` 1개 + 얇은 포인터 래퍼**: 표준, 중복 없음, 도구 추가 쉬움 / 래퍼가 "복사"로 변질되지 않게 규칙 필요
4. 심링크(`CLAUDE.md → AGENTS.md`): 파일 1개 / Windows에서 텍스트로 체크아웃, 다른 도구 동작 미문서화

## 결정

`AGENTS.md`를 단일 소스로 둡니다. `CLAUDE.md`는 `@AGENTS.md` import와 Claude 전용 메모만, `.github/copilot-instructions.md`·`.cursor/rules/00-team-rules.mdc`·`GEMINI.md`·`.rules`는 포인터와 도구 전용 메모만 담습니다. 경로 규칙은 각 도구의 경로 기능(`.claude/rules`, `*.instructions.md`, `.mdc globs`)으로 같은 내용을 짧게 유지합니다. `.claude/rules/ai-config.md`가 에이전트에게 "도구 파일은 `AGENTS.md`를 가리키기만 한다"는 규칙을 제공하고, `make ai-validate`가 길이를 검사합니다(ADR-0006 이후: 150줄 초과 시 경고).

## 결과

- 긍정: 규칙 변경이 한 곳. 새 도구는 포인터 파일 하나로 추가.
- 부정: 도구별 고급 기능(Cursor description 트리거 등)은 래퍼에 소량 중복이 생길 수 있음.
- 후속: 도구가 5개를 넘으면 Ruler/rulesync 도입 재검토.
