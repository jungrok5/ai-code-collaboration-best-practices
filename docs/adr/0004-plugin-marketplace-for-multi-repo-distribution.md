# ADR-0004: 훅·스킬·서브에이전트는 Claude 플러그인 마켓플레이스로 배포

- **상태**: Accepted
- **날짜**: 2026-10-07

## 맥락

여러 레포에서 같은 가드레일 훅과 스킬을 써야 한다. 조직 `.github` 레포는 `.claude/` 내용을 배포하지 못하고, 템플릿 복사는 시점 스냅샷이라 갱신이 안 된다.

## 고려한 선택지

1. 각 레포에 `.claude/hooks`·`skills` 복사 — 간단 / 갱신 불가
2. git submodule — 버전 고정 / 운영 번거로움, Claude 하위 CLAUDE.md 지연 로드
3. **플러그인 + 이 레포를 마켓플레이스로** — `enabledPlugins`로 레포별 켜기, `plugin update`로 갱신, 관리형 설정으로 조직 강제 가능 / Claude Code 전용

## 결정

`plugins/team-ai-workflow`를 플러그인으로 만들고 이 레포 루트 `.claude-plugin/marketplace.json`을 마켓플레이스로 둔다. 각 레포의 `.claude/settings.json`에 `extraKnownMarketplaces` + `enabledPlugins`를 커밋한다. 레포 고유 스킬만 `.claude/skills`에 둔다. 버전은 semver + `claude plugin tag`.

## 결과

- 긍정: 한 번 수정, 모든 레포 갱신; CI에서 `claude plugin validate --strict`.
- 부정: Copilot/Cursor는 훅을 쓰지 못하므로 같은 규칙을 CI·룰셋(결정적)으로도 강제해야 한다.
