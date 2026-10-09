# 10. 조사 교차검증: Gemini 요약의 정확도

2026-10-07에 Gemini가 제시한 내용과 출처를 1차 문서와 대조했습니다. 큰 방향은 맞습니다. 다만 일부 구체 수치에는 출처가 없습니다. 2025–26년의 주요 변화(AGENTS.md 표준화, 훅/스킬, 보안 하드닝, 측정)도 빠져 있습니다.

## 1. 출처 검증

| Gemini 주장 | 출처 존재 | 정확도 | 비고 |
| --- | --- | --- | --- |
| Webstacks: 트렁크 기반·Conventional Commits·자동 라벨링 | ○ (실제 제목 "How to Build AI Code Collaboration Workflows That Scale", 2026-04 갱신) | 정확 | 에이전시 마케팅 블로그, 1차 데이터 없음 |
| Webstacks: 계층형 AI 리뷰 봇 + 사람 승인 필수 | ○ | 대체로 정확 | "항상 사람 승인" 문구 있음. "계층형 리뷰 봇"은 Gemini의 해석(기사는 에이전트 단계를 계층화) |
| Webstacks: PR 사이클 타임·배포 빈도·결함률 | ○ | 정확 | "Set Success Metrics Early" 섹션 |
| Metacto: `copilot-instructions.md` + `instructions/*.instructions.md` | ○ (2026-07-08) | 정확 | GitHub 공식 문서를 다시 쓴 컨설팅 블로그. 1차 출처는 GitHub 문서 |
| Metacto: "리뷰어 피로" | ○ | 의역 | 해당 표현 없음. "reviewer load" 측정을 권고. 개념 자체는 Thoughtworks·Faros가 뒷받침 |
| Metacto: 에이전트 거버넌스(수정 금지 파일, 승인 필요 동작) | ○ | 정확 | "auth, secrets, IAM, billing, migrations, dependency upgrades, destructive commands, customer-data paths"에 하드 게이트 |
| VS Code 문서: Explore→Plan→Implement→Review | ○ (공식 "Best practices for using AI in VS Code") | 거의 원문 | 플랜 모드 후 에이전트 모드, 테스트 명령 제공, 클라우드 에이전트에 이슈 할당 모두 확인 |
| Qodo: "리뷰 시간 역전" | ○ (2026-06-30) | 부분 | 벤더 설문(주 11.4h 리뷰 vs 9.8h 작성, 방법론 미공개). 방향은 Faros 데이터가 따로 확인 |
| Qodo: 참고 모드로 시작 후 차단 | ○ | 해당 출처에 없음 | 잘못된 귀속 |
| DroidOrbit: 참고 모드 2–4주 후 보안·정확성만 필수 체크로 | ○ (2026-10-03) | 해당 출처에는 있음, 권위 낮음 | 통계 출처 불명. GitHub(Copilot 리뷰 승인 미집계)·Anthropic(Code Review는 neutral) 기본 동작과는 일치. 반론: Codacy |
| DroidOrbit: 리뷰 시간 역전 | ○ | 해당 출처에 없음 | 잘못된 귀속 |

## 2. 다섯 기둥 평가

| 기둥 | 판정 | 보정 |
| --- | --- | --- |
| 1. AI 컨텍스트를 코드로(`.cursorrules`, `CLAUDE.md`, `copilot-instructions.md`) | 강하게 지지 | 도구별 파일을 따로 두는 방식은 낡은 방식. `AGENTS.md`(Linux Foundation AAIF 관리, 6만+ 프로젝트) 하나 + 얇은 래퍼가 합의. `.cursorrules`는 레거시. 200줄 제한, 중첩 파일, 경로 규칙, 스킬, 훅(결정적 강제) 누락. 지시 파일은 컨텍스트일 뿐 강제 수단이 아님 |
| 2. 1–2일 브랜치, 모듈 격리, 트렁크 + 플래그 | 방향 지지 | "1–2일" 수치는 1차 출처 없음(팀 결정으로 명시). 병렬 에이전트를 격리하는 git worktree와 에이전트 브랜치 제한(`copilot/*`) 누락 |
| 3. PR ≤300줄, 단계 분할, 공동저자 트레일러, AI/사람 구분 | 부분 지지 | "300줄"은 관행(이 레포는 400줄 목표 + size 라벨). 인터페이스→테스트→구현→통합 순서는 출처 없음(출처 있는 것은 TDD-first). 공동저자 트레일러는 의견이 갈리는 관례(VS Code는 기본값을 되돌림)라 ADR로 명시 결정 |
| 4. 브랜치 보호(린트·테스트·타입) + AI 1차 리뷰 | 지지 | AI 리뷰는 승인이 아니라는 점, 에이전트 PR은 사람이 머지한다는 점, `pull_request_target`·프롬프트 인젝션 하드닝, 민감 경로 CODEOWNERS 누락 |
| 5. AI 주도 이슈 트래킹 + 구조화 템플릿 | 지지(표현은 모호) | 실제 가이드는 "에이전트 준비된 이슈"(문제·수용 기준·파일 포인터). 에이전트에 맡기지 말 일(보안·PII·프로덕션 장애·교차 레포) 목록, 이슈 본문의 인젝션 위험, Spec Kit/Kiro/OpenSpec 같은 무거운 대안(Thoughtworks는 Assess) 누락 |

## 3. Gemini 요약에서 통째로 빠진 것

1. 검증이 1순위(테스트·빌드·스크린샷을 에이전트에게 주고 증거를 요구)
2. 탐색·계획 먼저(단, 한 문장 diff는 계획 생략)
3. 보안·최소 권한: 2026-04 실제 유출 사례, `pull_request_target`, 시크릿, 도구 allow-list, SHA 핀
4. 명시적 AI 정책(DORA 1번 역량)
5. 측정(처리량 vs 안정성, 리뷰 건강도, 에이전트 PR 되돌림)
6. 여러 레포 배포 수단(조직 `.github`로는 AGENTS.md와 워크플로를 배포할 수 없음. 대신 플러그인 마켓플레이스, 재사용 워크플로, 템플릿 동기화)
7. 외부 기여 정책(Ghostty·curl 사례)
8. 작성 컨텍스트와 리뷰 컨텍스트 분리
9. 사람 책임(agentic engineering vs vibe coding)
10. 라이선스/IP·OSS 정책 제약

## 4. 이 레포가 반영한 방식

- 기둥 1: `AGENTS.md` + 래퍼 + `.claude/rules` + 플러그인 훅(03·04 문서)
- 기둥 2: 브랜치 규칙·worktree·룰셋(02 문서)
- 기둥 3: size 라벨·`/split-pr`·ADR-0002(02 문서)
- 기둥 4: `ci-ok` 필수 체크·AI 리뷰 advisory·`agent-approval-check`·CODEOWNERS(05·06 문서)
- 기둥 5: 이슈 폼 3종·트리아지 워크플로·`ai:ready` 사람 체크포인트(05 문서)
- 빠진 10개: 01·07·08·09 문서와 워크플로 하드닝

## 5. 1차 출처(발췌)

- Anthropic: https://code.claude.com/docs/en/best-practices , https://code.claude.com/docs/en/memory , https://code.claude.com/docs/en/github-actions
- GitHub: https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/ , https://docs.github.com/en/copilot/using-github-copilot/coding-agent/best-practices-for-using-copilot-to-work-on-tasks , https://docs.github.com/en/copilot/concepts/agents/cloud-agent/risks-and-mitigations
- VS Code: https://code.visualstudio.com/docs/agents/best-practices · OpenAI: https://learn.chatgpt.com/guides/best-practices · agents.md: https://agents.md/
- DORA 2025: https://dora.dev/research/2025/dora-report/ · METR: https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/ · Faros: https://www.faros.ai/blog/ai-code-quality-senior-engineer-review-burden
- Thoughtworks Radar v33/v34: https://www.thoughtworks.com/radar · Fowler/Böckeler context engineering: https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html
- Gemini가 인용한 글: https://www.webstacks.com/blog/ai-code-collaboration-workflows , https://www.metacto.com/blogs/github-copilot-best-practices-from-high-performing-teams , https://www.qodo.ai/blog/ai-code-review/ , https://droidorbit.com/ai-code-review-tools-for-developers/
