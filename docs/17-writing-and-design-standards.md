# 17. 글과 화면의 팀 기준: AI 티 빼기

사람이 읽는 글과 사람이 쓰는 화면은 이 기준을 따라요. 제품 사이트(예: Redis 소개 페이지), API 문서(예: 토스페이먼츠
개발자센터), 새로 여는 SaaS 대시보드, 그리고 이 레포의 README와 docs/까지 모두 해당해요.

AI가 쓴 글과 화면은 내용이 틀리지 않아도 티가 나요. 과장된 수식어, 번역투, 보라색 그라데이션, 똑같이 생긴 카드 세
장 같은 것들이에요. 독자는 이런 신호를 보면 내용까지 덜 믿어요. 그래서 이 기준은 팀 협업의 기본 도구로 넣었어요.

## 1. 글 기준

| 기준 | 하지 않는 것 | 하는 것 |
| --- | --- | --- |
| 구체적으로 | 칭찬하는 형용사 | 숫자와 단위(`1 ms`, `64 KB`, `50,000원`), 조건, 동작 |
| 사실만 | 근거 없는 최상급, 지어낸 고객·수치 | 출처가 있는 숫자. 없으면 `[숫자 필요]`로 남김 |
| 제목과 버튼 | 기능 이름, 모든 버튼에 "시작하기" | 제목은 사용자가 얻는 결과, 버튼은 누르면 일어나는 일 |
| 말투 하나 | 한 문서 안에서 합니다체·해요체·한다체 섞기 | 팀 기본은 해요체. 목록과 표는 명사형(개조식) |
| 자연스러운 한국어 | `~을 통해`, `~에 있어서`, `수행합니다`, 이중 피동 | `~로`, `~에서`, 동사, 주어가 있는 능동문 |
| 비계 걷어내기 | 도입부 예고, 결론 요약, 의미 부풀리기, 대구, 3단 나열 | 바로 내용으로 시작해서 마지막 사실로 끝내기 |
| 꾸밈 줄이기 | 목록 앞 이모지, 문장마다 굵게, 문장마다 대시 | 굵게는 UI 이름과 꼭 알아야 할 값에만 |

<!-- style-ignore-start -->
| 전 | 후 |
| --- | --- |
| 혁신적인 AI 기반 분석으로 브랜드 경쟁력을 강화하세요 | URL을 넣으면 AI 검색 답변에 내 사이트가 몇 번 나오는지 보여 줘요 |
| 이 API를 통해 결제 정보를 조회할 수 있습니다 | 이 API로 결제 정보를 조회해요 |
| 결론적으로 Redis는 최적의 선택입니다 | Redis는 읽기 응답이 1 ms 이하라서 세션 저장소로 써요 |
| 시작하기 | API 키 발급 |
<!-- style-ignore-end -->

글을 다듬다가 사실·숫자·이름·인용을 새로 만들면 안 돼요. 코드, 명령어, 경로, 링크 주소, API 이름은 그대로 둬요.

## 2. 화면 기준

| 기준 | 하지 않는 것 | 하는 것 |
| --- | --- | --- |
| 제품에서 출발 | 중앙 정렬 히어로 + 그라데이션 + 버튼 두 개 + 로고 띠 + 카드 세 장 | 실제 코드 예제, 실제 결과 화면, 동작을 설명하는 다이어그램 |
| 색 | 보라·남색 그라데이션, 글자에 그라데이션, 네온 글로 | 제품 색 토큰. 강조색 하나는 동작과 상태에만 |
| 모양 | 모든 곳에 `rounded-2xl`과 같은 그림자, 장식용 유리 효과 | 크기별 radius 단계, 테두리나 배경 단계로 구분 |
| 아이콘과 장식 | 이모지 아이콘, 제목마다 대문자 라벨, 모든 링크에 `→` | SVG 아이콘(`aria-hidden`), 라벨은 제목에 합치기 |
| 움직임 | 섹션마다 페이드업, 튀는 애니메이션 | 변화를 설명할 때만 150–250 ms ease-out |
| 신뢰 | 지어낸 후기, 로고, "10,000+ 팀" | 실제 인용과 수치만 |

모든 화면이 지키는 최소선이에요.

- 대비: 본문 4.5:1, 큰 글자와 UI 요소·포커스 링 3:1 (WCAG 2.2 SC 1.4.3, 1.4.11)
- 키보드: 모든 조작 요소에 보이는 `:focus-visible`
- 터치 영역: 44 px 목표, 24 px 최소 (SC 2.5.8). 확대 막지 않기
- 움직임: `prefers-reduced-motion` 존중
- 반응형: 375·768·1024·1440 px, 라이트와 다크 둘 다 확인
- 한글: `lang="ko"`, `word-break: keep-all`, 본문 줄 간격 1.6–1.8, Pretendard 또는 시스템 글꼴

## 3. 늘 쓰이게 하는 방법

스킬은 모델이 필요하다고 판단할 때 불러와요. 그래서 스킬만으로는 "항상"을 보장하지 못해요. 반대로 모든 요청마다 스킬을
강제로 읽히면 글과 상관없는 작업에도 토큰과 주의를 써요. 그래서 비용이 거의 없는 결정적 검사를 바닥에 깔고, 판단이 필요한
부분만 스킬에 맡겨요.

| 층 | 언제 동작 | 비용 | 무엇을 |
| --- | --- | --- | --- |
| 수정 직후 검사(PostToolUse 훅) | AI가 `.md`, `.html`, `.css`, `.tsx` 등을 고칠 때마다 | 0.1초, 토큰 0(문제가 없을 때) | `style_check.py`가 규칙을 검사하고 결과를 AI에게 돌려줌. 수정을 막지는 않음 |
| 경로 규칙 | 해당 파일을 열거나 고칠 때 | 규칙 몇 줄 | `.claude/rules/writing-and-ui.md`, Cursor·Copilot에도 같은 규칙 |
| 스킬 | 글이나 화면 작업일 때(설명문과 `paths:`로 자동 선택) | 필요할 때만 본문을 읽음 | `polish-writing`, `polish-ui`: 규칙으로 못 잡는 판단 |
| `make style`, pre-commit, CI | 커밋할 때, PR마다 | 0 | 사람이 쓴 글과 다른 AI 도구가 쓴 글도 같은 기준으로 검사. `error`는 CI 실패 |
| 평가 | 스킬을 바꿀 때 `make ai-eval` | 케이스당 몇 센트 | 써야 할 때 쓰는지, 안 써야 할 때 안 쓰는지 |

훅으로 스킬을 강제하지 않은 이유예요.

- 규칙 위반은 결정적으로 잡을 수 있어서 모델 판단이 필요 없어요.
- 강제 주입은 모든 요청에 토큰을 쓰고, 글이 아닌 작업에서 엉뚱하게 반응할 수 있어요([15](15-lean-harness.md)).
- 수정 직후 검사가 위반을 돌려주면 AI가 그 자리에서 고쳐요. 스킬을 안 불렀어도 기준은 지켜져요.

## 4. 규칙 다루기

- 규칙 목록: `python3 plugins/team-ai-workflow/style/style_check.py --list-rules`
- 심각도: `error`는 거의 항상 틀린 것이라 CI가 실패해요. `warning`은 자주 틀리는 것이라 알려만 줘요.
- 나쁜 예시를 일부러 인용할 때: 그 줄에 `style-ignore`, 여러 줄이면 `style-ignore-start`와 `style-ignore-end` 사이에 둬요.
- 레포마다 다르게: `.style/rules.toml`에 같은 형식으로 규칙을 추가하거나 `severity = "off"`로 꺼요.
- 규칙이 틀리게 잡으면 규칙을 고쳐요. 예외 표시를 늘리는 것보다 나아요.

## 5. 팀 공용 스킬과 기준을 추가하는 절차

이 기준이 첫 사례예요. 다음 스킬도 같은 순서로 넣어요.

1. **조사하고 출처의 라이선스를 확인해요.** MIT·Apache-2.0은 출처를 밝히고 가져다 고쳐 쓸 수 있어요. CC BY-SA,
   CC BY-NC-SA, 라이선스 없음은 인용만 하고 문장은 우리가 새로 써요. 이번에는 humanizer, im-not-ai, DaleSeo,
   Vercel, Anthropic frontend-design, Impeccable을 참고했고, 토스 가이드와 위키백과는 인용만 했어요
   (`plugins/team-ai-workflow/THIRD_PARTY_NOTICES.md`).
2. **남의 기준을 그대로 들이지 않아요.** 출처끼리 부딪히는 부분은 팀이 정해요. 이번 결정이에요.
   - 말투: 자연스러움을 이유로 말투를 섞으라는 권고가 있었지만, 제품 문구는 일관성이 먼저라 한 가지 말투로 정했어요.
   - 굵은 라벨 목록: 권하는 곳과 피하라는 곳이 갈려서, 굵게는 UI 이름과 핵심 값에만 쓰기로 했어요.
   - 제목: Title Case 대신 문장형(sentence case)으로 정했어요.
   - 글꼴: Pretendard는 Inter를 바탕으로 만든 글꼴이라 "Inter 금지" 규칙에서 예외예요.
3. **기계로 잡을 수 있는 것은 규칙으로, 판단은 스킬로 나눠요.** 규칙은 `rules.toml`, 판단은 `SKILL.md`에 둬요.
   규칙이 잡는 것을 스킬에 다시 쓰지 않아요.
4. **늘 쓰이게 할 장치를 고르고 비용을 적어요.** 이번에는 수정 직후 검사, 경로 규칙, CI를 골랐고, 모든 요청에 끼워
   넣는 방식은 쓰지 않았어요(§3).
5. **평가 케이스를 붙여요.** 써야 할 때와 쓰지 말아야 할 때를 하나씩(`plugins/team-ai-workflow/evals/`).
6. **기존 결과물에 먼저 적용해요.** 이번에는 이 레포의 README, docs/, 해설 페이지, 구조도 이미지를 이 기준으로
   다시 썼어요. 직접 써 보면 규칙이 틀린 곳이 보여요.
7. **플러그인 버전을 올려 배포해요.** 팀원은 `claude plugin update`로 받아요. 2주 뒤 경고가 실제로 도움이 됐는지
   보고 규칙을 줄이거나 고쳐요.

## 출처

- [blader/humanizer](https://github.com/blader/humanizer), [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai),
  [DaleSeo/korean-skills](https://github.com/DaleSeo/korean-skills) (MIT)
- [vercel-labs/writing-guidelines](https://github.com/vercel-labs/writing-guidelines),
  [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines) (MIT)
- [anthropics/skills: frontend-design](https://github.com/anthropics/skills/tree/main/skills/frontend-design),
  [pbakaus/impeccable](https://github.com/pbakaus/impeccable) (Apache-2.0)
- [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) (CC BY-SA, 인용만)
- [토스 테크니컬 라이팅 가이드](https://technical-writing.dev/), [토스의 8가지 라이팅 원칙](https://toss.tech/article/8-writing-principles-of-toss) (인용만)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- Claude Code [hooks](https://code.claude.com/docs/en/hooks), [skills](https://code.claude.com/docs/en/skills), [memory](https://code.claude.com/docs/en/memory)
