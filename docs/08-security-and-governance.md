# 08. 보안 · 거버넌스 — 에이전트를 "새 직원"처럼 다룬다

## 1. 위협 모델과 이 레포의 통제

| 위협 | 예 | 통제(파일) |
| --- | --- | --- |
| **프롬프트 인젝션** | 이슈/PR/댓글/CI 로그/웹 페이지에 숨긴 지시로 비밀 유출·리뷰 우회 ("Comment and Control", 2026-04: Claude Code Security Review·Gemini CLI·Copilot 에이전트에서 API 키 탈취 재현) | 액션은 쓰기 권한자만 트리거, 봇 거부, 숨은 문자 제거; 프롬프트에 "untrusted data" 명시; 도구 allow-list 최소; `AGENTS.md` §8 |
| **과도한 권한** | 에이전트가 `contents: write`로 포크 코드 실행, PAT 유출 | 최상위 `permissions: read`, 잡별 확대; 포크 PR 제외(`head.repo.full_name == github.repository`); `pull_request_target`는 메타데이터 잡에만; PAT 대신 App/OIDC |
| **보호 자산 변경** | `.env`, 락파일, CODEOWNERS, 룰셋, `.claude/settings.json` 수정 | PreToolUse 훅 `protect-files.sh`, CODEOWNERS, 룰셋, 액션의 베이스 브랜치 설정 복원 |
| **테스트 무력화** | skip/only, 실패를 삼키는 쉘 OR-true 트릭, 타임아웃 증가로 CI 초록 | `AGENTS.md` §5, `.claude/rules/tests.md`, 리뷰 체크리스트, CI-fix 프롬프트 금지 조항 |
| **공급망** | 태그 핀 액션 변조, 타이포스쿼팅 패키지 | SHA 핀(`scripts/pin-actions.sh`) + Dependabot, zizmor, CodeQL(actions), 의존성 추가 사유 의무 |
| **비밀 커밋** | 키·토큰 푸시 | gitleaks(pre-commit), 푸시 보호, `deny: Read(./.env)` |
| **기록 파괴** | force-push, reset --hard, branch -D | `deny` 규칙, `git-guard.sh`, 룰셋 `non_fast_forward`/`deletion` |
| **비용 폭주** | 무한 루프 에이전트 | `--max-turns`, `timeout-minutes`, `concurrency`, 모델 고정, `--max-budget-usd` |
| **무단 자율 머지** | 봇이 승인·머지 | 인라인 코멘트 서버는 승인 불가, AI 승인 미집계, `agent-approval-check`, `allowed_merge_methods: squash` |

OWASP 참고: LLM Top 10(2025) LLM01 프롬프트 인젝션, LLM02 민감정보 노출, LLM05 출력 처리, LLM06 과도한 에이전시; Agentic Top 10(2026) ASI01 목표 탈취, ASI02 도구 오용, ASI03 권한 남용, ASI05 예기치 않은 코드 실행.

## 2. GitHub Actions 하드닝 규칙(`.claude/rules/github-workflows.md`와 동일)

1. `permissions` 최소화, 기본 토큰 읽기 전용(레포 설정).
2. `${{ github.event.* }}` 텍스트를 `run:`에 직접 넣지 않는다 → `env:`.
3. `pull_request_target`에서 PR 코드를 체크아웃하지 않는다(checkout v7은 기본 거부).
4. 서드파티 액션 SHA 핀. `zizmor`·`actionlint`가 CI에서 검사.
5. 시크릿은 `${{ secrets.X }}`만; `show_full_output`/`display_report` 끔.
6. 에이전트 잡은 `concurrency`·`timeout-minutes`·`--max-turns`.

## 3. 팀 AI 정책(DORA 2025의 1번 역량: "명확히 소통된 AI 스탠스")

템플릿을 쓰는 팀은 아래를 채워 `docs/`에 두고 `AGENTS.md` §1에서 링크한다.

- **허용 도구**: (예) Claude Code, Copilot, Cursor. 회사 데이터 정책에 맞는 플랜/엔드포인트(Bedrock/Vertex 등).
- **공개 의무**: PR 본문 체크박스 + `ai:assisted`/`ai:generated` 라벨 + 공동저자 트레일러(ADR-0002).
- **에이전트가 절대 하지 않는 것**: 머지·승인, 보호 경로 수정, 권한 확대, 비밀 접근, 프로덕션 조작.
- **사람 승인이 필요한 영역**(Metacto 게이트 목록 참고): 인증, 비밀, IAM, 결제, 마이그레이션, 의존성 메이저 업그레이드, 파괴적 명령, 고객 데이터 경로 → CODEOWNERS로 강제.
- **코드 출처·라이선스**: Copilot의 공개 코드 매칭 참조 표시를 켠다. 미국 저작권청(2025-01): 순수 AI 생성물은 저작권 보호 대상 아님 → 사람의 실질 기여를 PR에 남긴다. 외부 OSS에 기여할 때는 해당 프로젝트 정책을 따른다(QEMU·NetBSD·Gentoo는 AI 생성 기여를 거부/제한, Ghostty는 공개 의무, curl은 AI 슬롭 보고로 버그바운티 종료).
- **규제**: EU AI Act 투명성 의무(2026-08-02~)는 주로 모델 제공자·규제 분야 배치자에게 해당. 팀은 승인 도구 목록과 세션 로그를 보관하면 충분(법률 자문 아님).

## 4. 사고 대응

- 에이전트가 비밀을 노출했다 → 즉시 키 폐기·회전, 워크플로 비활성화, 세션/실행 로그 보존, SECURITY.md 경로로 보고.
- 에이전트 PR에서 악성 변경 발견 → PR 닫기, 브랜치 보존(증거), `ai:ready` 부여자·트리거 댓글 작성자 확인, 프롬프트/허용 도구 축소.
- 재발 방지는 규칙 파일이 아니라 **훅·CI·룰셋**(결정적 통제)에 넣는다.

## 출처

- Claude Code Action security: https://github.com/anthropics/claude-code-action/blob/main/docs/security.md
- GitHub Actions secure use: https://docs.github.com/en/actions/reference/security/secure-use · Copilot agent risks: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/risks-and-mitigations
- Comment and Control(2026-04): https://oddguan.com/blog/comment-and-control-prompt-injection-credential-theft-claude-code-gemini-cli-github-copilot/
- OWASP LLM Top 10: https://genai.owasp.org/llm-top-10/ · Agentic Top 10: https://genai.owasp.org/risk-maps-supported/top-10-for-agentic-apps-2026/
- Ghostty AI policy PR: https://github.com/ghostty-org/ghostty/pull/10412 · QEMU: https://www.qemu.org/docs/master/devel/code-provenance.html · NetBSD: https://www.netbsd.org/developers/commit-guidelines.html
- DORA 2025: https://dora.dev/research/2025/dora-report/ · EU AI Act 요약: https://artificialintelligenceact.eu/high-level-summary/
