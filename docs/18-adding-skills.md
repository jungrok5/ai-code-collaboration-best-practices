# 18. 스킬 추가 가이드

스킬은 등급에 따라 필요한 절차가 다릅니다. 대부분의 스킬은 개인 또는 커뮤니티 등급으로 시작하고, 팀이 실제로 의존하게
되면 상위 등급으로 승격합니다. 뼈대 생성, 형식 검사, 버전 확인은 명령과 CI가 처리하므로 작성자는 스킬 본문과 평가
케이스 작성에 집중합니다.

## 등급

| 등급 | 위치 | 설치 | 요구 사항 | 승인 |
| --- | --- | --- | --- | --- |
| 개인 | `~/.claude/skills/<이름>/` | 본인만 | `SKILL.md` | 없음 |
| 커뮤니티 | `plugins/team-ai-community/skills/` | 선택 설치 | `SKILL.md`, 플러그인 검증 통과 | 리뷰어 1명 |
| 팀 | `plugins/team-ai-workflow/skills/` | 기본 설치 | 위 항목, 평가 케이스 2개(사용·미사용), 버전 동기화 | CODEOWNER |
| 팀 기준 | 팀 플러그인 + 검사 규칙 + 훅 | 기본 적용 | [docs/17](17-writing-and-design-standards.md) §5 절차 | 리드 |

## 추가 방법

에이전트에게 "스킬 추가"를 요청하면 `/new-skill`이 아래 과정을 수행합니다. 직접 실행할 때의 명령은 다음과 같습니다.

```bash
make new-skill NAME=release-notes TIER=community DESC="변경 이력에서 릴리스 노트 초안을 작성합니다. 릴리스 노트, 변경 요약 요청 시 사용합니다."
```

| 단계 | 개인 | 커뮤니티 | 팀 |
| --- | --- | --- | --- |
| 뼈대 생성 | `make new-skill` | `make new-skill` | `make new-skill` (평가 케이스 뼈대 포함) |
| 본문 작성 | 목표와 제약 | 목표와 제약 | 목표와 제약 |
| 검증 | 없음 | `make ai-validate` | `make ai-validate`, `make ai-eval CASE=<이름>-*` |
| 배포 | 다음 세션부터 적용 | PR, 플러그인 버전 갱신 | PR, `plugin.json`·`marketplace.json` 버전 동시 갱신 |

## 작성 기준

- `description`은 무엇을 하는지와 언제 쓰는지를 함께 적습니다. 모델은 이 문장으로 스킬 호출 여부를 판단합니다.
- 본문은 목표와 제약만 적습니다. 모델이 기본으로 수행하는 단계를 나열하면 비용만 늘어납니다([docs/15](15-lean-harness.md)).
- 외부 자료를 참고한 경우 라이선스를 확인하고 플러그인의 `THIRD_PARTY_NOTICES.md`에 출처를 기록합니다.
  MIT·Apache-2.0은 출처 표기 후 수정해 사용할 수 있고, CC BY-SA·CC BY-NC-SA·라이선스 미표기 자료는 인용만 합니다.
- 팀 등급의 평가 케이스는 사용해야 하는 요청 1개와 사용하지 않아야 하는 유사 요청 1개로 구성합니다.

## 자동 검사

| 검사 | 위치 | 기준 |
| --- | --- | --- |
| 형식 | `make ai-validate`, CI | `name`이 디렉터리 이름과 같음, `description` 40–1,536자, 플러그인 검증 통과 |
| 버전 | `make ai-validate`, CI | `plugin.json`과 `marketplace.json` 버전 일치 |
| 평가 | `make ai-validate` | 팀 등급 스킬에 평가 케이스가 없으면 경고 |
| 문서 기준 | 수정 직후 훅, CI | `SKILL.md`도 [docs/17](17-writing-and-design-standards.md) 규칙 적용 |

## 승격과 정리

| 전환 | 조건 | 방법 |
| --- | --- | --- |
| 개인 → 커뮤니티 | 다른 팀원도 사용 | `make new-skill TIER=community`로 생성 후 본문 이동 |
| 커뮤니티 → 팀 | 팀 작업 흐름이 이 스킬에 의존 | 디렉터리 이동, 평가 케이스 2개 추가, 두 플러그인 버전 갱신 |
| 삭제 | 분기 동안 호출이 거의 없거나 모델 기본 동작과 중복 | PR로 삭제, 버전 갱신 |
