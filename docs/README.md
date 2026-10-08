# 문서 목차

| 문서 | 내용 | 누가 읽나 |
| --- | --- | --- |
| [01 일일 플레이북](01-playbook.md) | 이슈 → 세션 → 구현 → 검증 → PR → 리뷰 → 머지, 사람과 에이전트의 하루 | 모든 팀원 |
| [02 브랜치·PR·커밋 규칙](02-branching-and-pr.md) | 트렁크 기반, 브랜치 이름, PR 크기, 스택 PR, squash, 릴리스 | 모든 팀원 |
| [03 AI 컨텍스트 파일](03-ai-context-files.md) | `AGENTS.md` 단일 소스, 도구별 래퍼, 작성 규칙, 모노레포/경로 규칙 | 규칙 관리자 |
| [04 Claude Code 설정](04-claude-code-setup.md) | settings/permissions/hooks/skills/subagents/plugin marketplace/headless | Claude Code 사용자 |
| [05 GitHub 자동화](05-github-automation.md) | 워크플로 목록, 라벨 상태 머신, 시크릿/앱 설치, 다른 에이전트 봇 | 레포 관리자 |
| [06 코드 리뷰 정책](06-code-review-policy.md) | AI 리뷰(참고) → 사람 승인, 체크리스트, 리뷰 봇 비교 | 리뷰어 |
| [07 멀티 레포 전략](07-multi-repo-strategy.md) | 허브·스포크, 배포 채널(템플릿/마켓플레이스/재사용 워크플로), 동기화 | 플랫폼/리드 |
| [08 보안·거버넌스](08-security-and-governance.md) | 프롬프트 인젝션, 최소 권한, 보호 경로, AI 정책, 라이선스 | 리드/보안 |
| [09 측정 지표](09-metrics.md) | DORA 5지표 + 리뷰 건강도 + 에이전트 성과, 수집 방법 | 리드 |
| [10 조사 교차검증](10-research-crosscheck.md) | Gemini 조사 내용 검증 결과와 1차 출처 | 궁금한 사람 |
| [11 도구 지원 매트릭스](11-tool-support-matrix.md) | 도구별 규칙 파일·AGENTS.md 지원·PR 리뷰 봇 트리거 | 도구 선택 시 |
| [12 셋업 체크리스트](12-setup-checklist.md) | 허브/신규 레포/팀원 온보딩에서 할 일 | 관리자, 신규 팀원 |
| [13 AI 백엔드](13-ai-backends.md) | API 키 없이: 개인 자리 `claude -p` · 로컬 LLM 서버 · (선택) Anthropic. 없어도 동작 | 모두 |
| [14 설계 먼저, 겹치지 않게](14-design-first-and-overlap.md) | T0/T1/T2 설계 단계, 팀 작업 보드와 겹침 확인, 이슈보다 큰 일 | 모든 팀원 |
| [15 가벼운 하네스](15-lean-harness.md) | 최신 모델에 맞게 규칙·훅·권한을 덜어낸 근거와 점검법 | 규칙 관리자 |
| [설계 목록](designs/INDEX.md) | 활성·완료 설계 문서(자동 생성), [템플릿](designs/TEMPLATE.md) | 모든 팀원 |
| [ADR](adr/) | 아키텍처 결정 기록 (왜 이렇게 했는가) | 모두 |
