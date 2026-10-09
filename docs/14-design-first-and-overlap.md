# 14. 설계 먼저, 겹치지 않게: 이슈보다 큰 일을 다루는 법

## 1. 풀려는 문제

AI를 쓰는 팀에서 자주 생기는 문제는 두 가지예요.

1. **영역이 모호한 일에서 중복 작업.** 범위를 딱 자르기 어려운 일을 두 사람이 각자 AI로 하다가 같은 모듈을 고치거나 같은 기능을 따로 만들어요. git은 같은 파일 충돌만 잡고 "같은 것을 두 번 만드는 것"은 못 잡아요.
2. **설계 없이 바로 구현.** 요청을 받은 AI가 곧장 코드를 만들고, 방향이 틀린 것을 리뷰에서야 발견해요. 1,000줄을 리뷰해서 되돌리는 것보다 1쪽짜리 설계를 먼저 보는 편이 훨씬 싸요.

## 2. 접근: 일의 크기에 따라 세 단계

모든 일에 설계 문서를 강제하면 문서가 쌓이고 승인 대기가 병목이 돼요(Uber의 RFC 과부하, Thoughtworks가 spec-driven 개발을 "Assess"에 두는 이유). 그래서 필요한 절차는 일의 크기와 모호함에 맞춰 늘려요.

| 단계 | 기준 | 필요한 것 | 승인 |
| --- | --- | --- | --- |
| **T0** | 한 문장으로 설명되는 변경 (버그 수정, 작은 기능) | 이슈 + 브랜치. 브랜치와 초안 PR이 곧 "내가 한다"는 표시 | 일반 PR 리뷰 |
| **T1** | 여러 파일, 접근법이 하나로 정해지지 않음 | AI의 plan 모드 계획을 PR 본문 맨 위에. 코드 전에 초안 PR로 먼저 공유 | 계획에 리뷰어 OK 후 구현 |
| **T2** | 여러 모듈·레포, 공개 인터페이스·스키마 변경, 하루 이상, 영역이 모호함 | `docs/designs/NNNN-*.md` 1쪽 설계 + Mermaid 구조도. 설계만 담은 작은 PR | 설계 PR 머지 = 승인. 그 뒤 구현 PR들이 설계를 링크 |

판단이 애매하면 T2로 가요. 초안은 AI가 쓰니 몇 분이면 돼요(`/design`).

## 3. 흐름

```mermaid
flowchart TD
  R["요청 또는 아이디어"] --> C{"한 문장으로<br/>설명되나?"}
  C -- 예 --> T0["T0: 이슈 → 브랜치 → PR"]
  C -- 아니오 --> O["/check-overlap<br/>누가 이미 하고 있나?"]
  O -- 겹침 --> TALK["담당자와 대화<br/>합치기 · 영역 나누기 · 순서 정하기"]
  O -- 없음 --> D["/design<br/>1쪽 설계 + 구조도"]
  TALK --> D
  D --> P["설계 PR (docs/designs/)<br/>Design check가 겹침을 다시 확인"]
  P --> A{"사람이 승인<br/>(PR 머지)"}
  A -- 수정 --> D
  A -- 승인 --> S["작업 분할 → 이슈들<br/>status: in-progress"]
  S --> I["구현 PR들 (설계 링크)<br/>Design check: 바뀐 파일이 남의 영역이면 알림"]
  I --> DONE["status: done"]
```

## 4. 중복을 잡는 장치: 팀 작업판(work board)

설계 문서의 머리말(front matter)에 담당자와 영역(`areas`)을 적어요. 영역은 경로 글롭(`src/auth/**`)이나 이름 붙은 영역(`api:/login`, `db:sessions`, `ui:checkout`)이에요.

| 장치 | 하는 일 | 토큰 비용 |
| --- | --- | --- |
| `.github/workflows/work-board.yml` (허브) | 30분마다 `.github/work-board-repos.txt`의 모든 레포에서 활성 설계와 열린 PR의 변경 파일을 모아 `board.json`으로 Pages에 게시 | 0 (LLM 없음) |
| `scripts/designs/board.py overlap` | 내가 건드릴 경로·영역이 활성 설계나 열린 PR과 겹치는지 글롭 비교 | 0 |
| `.github/workflows/design-check.yml` | 모든 PR에서 위 비교를 돌려 겹치면 댓글. 큰 PR에 설계 링크가 없으면 알림 (막지 않음, `no-design` 라벨로 끔) | 0 |
| `/check-overlap` 스킬 | AI가 작업 시작 전에 위 명령을 실행하고 결과를 두 줄로 보고 | 수백 토큰 |
| 세션 시작 | 활성 설계 목록을 한 줄씩(최대 40줄) AI 컨텍스트에 넣음 | 설계 50개 ≈ 1.5~2K 토큰 |

토큰이 적게 드는 이유: 매 세션 AI가 여러 레포의 PR을 읽게 하면 세션당 수만~수십만 토큰이 들고, 컨텍스트가 차서 작업 품질도 떨어져요. 여기서는 스케줄 작업이 한 번 모아 두고, 겹침 판단은 결정적 스크립트가 하고, AI는 한 줄 요약만 읽어요.

오래된 표시: `updated`가 21일 넘게 갱신되지 않은 활성 설계는 `stale`로 표시돼요. 버려진 표시가 다른 사람을 막지 않게 하려는 장치예요(`DESIGN_STALE_DAYS`로 조정).

## 5. "그냥 대화를 더 하면 되지 않나?"

대화는 여전히 필요해요. 다만 AI는 회의에 들어오지 않고, 사람은 모든 채팅을 기억하지 못해요. 이 구조는 대화를 대신하지 않고 대화가 필요한 순간을 알려 줘요. 겹침이 감지되면 "@alice와 먼저 이야기하라"는 결과가 나와요. 여러 에이전트 실험에서도 상대가 진행 중인 변경을 알려 주기만 해도 실패의 대부분이 회복됐어요(arXiv 2609.25396).

정기 모임은 하나면 돼요. 주 1회 15분, 작업판을 함께 보며 겹침과 오래된 설계를 정리해요.

## 6. 이슈 단위가 아닌 일들

| 일의 종류 | 다루는 법 |
| --- | --- |
| 이니셔티브/에픽 (여러 주, 여러 사람) | T2 설계 1개가 부모. "작업 분할"의 각 줄이 하위 이슈(sub-issue). 설계의 `issues`에 번호를 적어 연결 |
| 탐색·스파이크 (뭘 만들지 모름) | 기한(예: 2일)을 정한 `spike/<주제>` 브랜치에서 자유롭게. 결과물은 코드가 아니라 설계 문서. 스파이크 코드는 머지하지 않음 |
| 여러 레포 변경 | 설계의 `repos`에 모두 적음. 구현은 레포별 PR로 나누고 각자 설계 링크. 순서(예: API 먼저, 클라이언트 나중)를 설계에 명시 |
| 대규모 리팩터링 | T2. 영역을 넓게(`src/**`) 잡으면 모두와 겹치므로 단계별로 영역을 좁혀 여러 설계로 나눔 |
| 장애 대응·핫픽스 | 설계 생략(`no-design` 라벨). 끝난 뒤 필요하면 사후 ADR |
| 운영·설정·문서 | 보통 T0 |

## 7. 실무 적용 순서

1. 이번 주: 허브의 `.github/work-board-repos.txt`에 팀 레포를 적고, 비공개 레포면 `BOARD_TOKEN` 시크릿을 추가해요.
2. 다음 T2 작업 하나를 `/design`으로 시작해요. 설계 PR 리뷰는 하루 안에 끝내요. 늦어지면 그 자체가 신호예요.
3. 2주 뒤 회고: 겹침 알림이 실제로 대화를 만들었는지, 설계가 리뷰 시간을 줄였는지 봐요. 알림이 소음이면 T2 기준을 올려요.

## 8. 하지 않는 것

- 설계 승인이 없다고 PR을 막지 않아요. 알리기만 해요. 막으면 사람들이 문서를 형식적으로 쓰기 시작해요.
- AI에게 매 세션 모든 PR을 읽히지 않아요.
- 설계 문서를 길게 쓰지 않아요. 1쪽, 구조도 하나예요.

## 출처

- Anthropic, Claude Code best practices("한 문장이면 계획 생략", "인터뷰 후 SPEC.md"): https://code.claude.com/docs/en/best-practices
- Thoughtworks Radar, Spec-driven development(Assess): https://www.thoughtworks.com/radar/techniques/spec-driven-development
- Birgitta Böckeler, spec-driven 도구 체험기: https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- Google design docs: https://www.industrialempathy.com/posts/design-docs-at-google/ · Oxide RFD: https://rfd.shared.oxide.computer/rfd/0001
- Uber RFC 확장 경험: https://blog.pragmaticengineer.com/scaling-engineering-teams-via-writing-things-down-rfcs/
- OpenSpec: https://github.com/Fission-AI/OpenSpec · GitHub Spec Kit: https://github.com/github/spec-kit
- Anthropic agent teams(팀원별 파일 소유): https://code.claude.com/docs/en/agent-teams
- AgenticFlict(에이전트 PR 충돌률): https://arxiv.org/abs/2604.03551 · Passes Alone, Fails Together: https://arxiv.org/abs/2609.25396
