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

## 다른 레포의 플러그인

이 레포에서 떼어 낸 플러그인(예: `jungrok5/ai-design`)과 외부 오픈소스 플러그인은 같은 방법으로 들이고 같은 기준으로
갱신합니다. 위험은 누가 만들었는지가 아니라 무엇이 바뀌었는지로 정해집니다. 훅, MCP·LSP 서버, `bin/` 실행 파일은
사용자 권한으로 실행되고 Claude의 권한 확인을 거치지 않습니다.

### 들이기

`.claude-plugin/marketplace.json`에 항목을 추가하고 출처를 커밋 SHA로 고정합니다. 상대 레포에 태그, 릴리스 절차,
특정 설정이 있다고 가정하지 않습니다.

```json
{
  "name": "example-skill",
  "source": { "source": "git-subdir", "url": "owner/repo", "path": "plugins/example-skill",
              "sha": "<40자 커밋 SHA>" },
  "description": "..."
}
```

- `version`은 적지 않습니다. 플러그인의 `plugin.json` 값이 쓰이고, 양쪽에 적으면 Claude Code 문서가 권하지 않는
  상태가 됩니다.
- 상대 레포가 태그를 쓰면 `"ref": "v1.2.3"`을 함께 적습니다. `ref`와 `sha`가 함께 있으면 `sha`가 우선합니다.
- 처음 들일 때 확인할 것: 라이선스, `hooks/hooks.json`·`.mcp.json`·`bin/`·스크립트의 내용, 최근 관리 여부
- 원본이 삭제되거나 이력이 바뀌면 고정한 커밋을 받을 수 없습니다. 팀이 계속 의존할 외부 플러그인은 조직 계정으로
  fork해 두고 fork를 고정합니다.
- `SKILL.md` 한 장뿐인 외부 스킬은 의존성으로 두지 않고 커뮤니티 등급으로 복사한 뒤 출처를
  `THIRD_PARTY_NOTICES.md`에 기록하는 편이 단순합니다.
- 다른 레포의 플러그인은 설정 파일만으로 설치되지 않습니다. 팀원마다 한 번
  `claude plugin install <이름>@ai-collab --scope project`를 실행합니다([docs/04](04-claude-code-setup.md)).

### 갱신

`.github/workflows/plugin-deps.yml`이 매주 월요일 고정된 항목마다 상대 레포의 새 커밋을 찾아 PR을 하나씩 엽니다.
검사 로직은 `scripts/deps-update.py`에 있습니다. 직접 확인할 때는 `python3 scripts/deps-update.py check`를 실행합니다.

| 상대 레포 상태 | 고정할 커밋 |
| --- | --- |
| 버전 태그가 있음(`v1.2.3`, `1.2.3`, `<플러그인>--v1.2.3`) | 가장 높은 버전 태그의 커밋. `ref`도 그 태그로 변경 |
| 태그가 없음 | 기본 브랜치의 최신 커밋 |
| 항목에 브랜치 `ref`가 있음 | 그 브랜치의 최신 커밋 |
| 플러그인 폴더 밖만 바뀜(사이트, CI 등) | PR을 열지 않음 |

PR 본문에는 비교 링크, 바뀐 파일, `plugin.json` 버전 변화가 들어갑니다. 실행되는 코드가 바뀌었으면 그 파일을 맨
위에 표시합니다. 검토 기준은 다음과 같습니다.

| 바뀐 것 | 검토 |
| --- | --- |
| 스킬 본문, 문서, 규칙 같은 텍스트만 | CI 결과와 변경 기록 확인 후 CODEOWNER 승인 |
| 훅, MCP·LSP 서버, `bin/`, 스크립트 | 해당 diff를 사람이 직접 읽은 뒤 CODEOWNER 승인 |
| 고정한 커밋을 더 이상 받을 수 없음 | 상대 레포의 이력 변경 여부를 확인하고, 필요하면 fork로 출처 변경 |

`plugin.json`의 `version`이 그대로면 이미 설치한 팀원은 새 파일을 받지 않습니다. 새로 설치하는 사람만 새 커밋을
받으므로, PR 본문에 그 사실이 표시되면 상대 레포에 버전 갱신을 요청합니다.

### 필요한 설정

| 설정 | 위치 | 없을 때 |
| --- | --- | --- |
| "Allow GitHub Actions to create and approve pull requests" 체크 후 Save | 이 레포 Settings → Actions → General | PR 생성 실패 |
| `DEPS_TOKEN` 시크릿(fine-grained PAT 또는 GitHub App 토큰, contents·pull-requests 쓰기) | 이 레포 Settings → Secrets | PR은 열리지만 CI가 자동으로 돌지 않음 |

상대 레포에는 아무 설정도 필요하지 않습니다. 워크플로는 `git`, Python, `gh`만 쓰므로 GitHub Enterprise Server에서도
러너가 상대 레포의 호스트에 접근할 수 있으면 동작합니다.
