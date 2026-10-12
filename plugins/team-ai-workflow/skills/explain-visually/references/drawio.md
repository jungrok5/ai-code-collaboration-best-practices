# Draw.io 출력과 페이지 구성

## 실제 패키지 사용

설명 대상 체크아웃이나 별도 도구 캐시에 필요한 버전만 설치합니다.

```bash
npm install --prefix .cache/visual-tools @next-ai-drawio/mcp-server@0.4.1
node plugins/team-ai-workflow/skills/explain-visually/scripts/prepare-drawio.mjs input.xml output.drawio .cache/visual-tools/node_modules
python3 plugins/team-ai-workflow/skills/explain-visually/scripts/render-svg.py output.drawio output.svg
```

Claude Code 플러그인으로 설치한 경우 명령의 스킬 경로를 실제 설치 위치로 바꿉니다. 패키지의 `get_drawing_guide` 또는 `dist/drawing-guide.js`를 읽습니다. 800×600 안에 요소를 배치하고, 식별자를 중복시키지 않으며, 화살표가 다른 노드를 가로지르지 않게 합니다. 색은 사람의 판단·실패·완료처럼 의미를 나타내는 데 사용합니다.

`prepare-drawio.mjs`는 Next AI Draw.io의 실제 XML 정규화·검증 모듈을 호출합니다. `render-svg.py`는 그 XML에서 단순 도형과 연결선을 그리는 팀의 정적 렌더러입니다. 편집이 필요하면 패키지의 `dist/drawio/`를 페이지의 `assets/drawio/`로 복사하고 라이선스를 함께 배포합니다. 전체 Next.js 앱과 모델 API를 배포한 것처럼 설명하지 않습니다.

## 페이지 데이터

`viewer.html`과 두 JS 파일을 같은 디렉터리에 둡니다. 다음 형식으로 `data/manifest.json`을 작성하고, SVG와 `.drawio`를 `data/`에 둡니다.

```json
{"title":"이 저장소의 역할","summary":"원문에 근거한 한 문장","topics":[{"id":"flow","title":"한 작업 따라가기","svg":"flow.svg","drawio":"flow.drawio","steps":[{"node":"10","title":"단계 이름","description":"원문에 근거한 설명","source":"https://github.com/owner/repo/blob/COMMIT/README.md"}]}]}
```

현재 렌더러는 한 페이지의 사각형·마름모·단순 텍스트·직교 연결선만 지원합니다. 아이콘 라이브러리·스윔레인·복합 도형은 실제 draw.io 편집기에서 렌더링합니다. 정적 렌더러가 지원하지 않는 도형을 다른 모양으로 조용히 바꾸지 않습니다.

확인할 항목: XML과 SVG 네임스페이스, 연결선의 대상, 노드 겹침, 원문 링크, 모든 탭, 노드 선택, 배율의 실제 변화, 전체보기 후 스크롤 초기화, 375px와 데스크톱 화면, 키보드, 움직임 최소화 설정.
