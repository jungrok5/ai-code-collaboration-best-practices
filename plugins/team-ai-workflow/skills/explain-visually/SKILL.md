---
name: explain-visually
description: Create a Korean visual explainer for a repository, technical concept, architecture, workflow or incident using source-grounded diagrams, step-by-step examples and an interactive HTML page. Use when asked to explain a repo simply, show how something works, visualize a process, or replace a dense technical overview with a visual explanation. Do not use for a one-line factual answer or a small code edit.
---

# 시각적으로 설명하기

- 실제 README·규칙·코드·워크플로를 먼저 읽고, 독자가 기억할 핵심 한 문장을 정합니다. 원문 경로와 읽은 커밋을 기록합니다.
- 대표 작업 한 건을 고르고, 누가 무엇을 하는지·어디서 검사하는지·실패하면 어디로 돌아가는지 그림으로 설명합니다. 원문에 없는 단계나 승인 지점을 만들지 않습니다.
- 작업 흐름, 검사 구조, 크기별 판단처럼 서로 다른 질문을 별도 그림으로 나눕니다. 한 그림은 8개 안팎의 주요 노드와 가로 3개 이하의 열을 기본으로 합니다.
- Next AI Draw.io를 기본으로 사용합니다. 실제 패키지로 XML을 검증하고 원본 `.drawio`를 보존합니다. 패키지를 사용할 수 없으면 제한을 명시하며, 직접 만든 SVG를 도구의 출력이라고 소개하지 않습니다. 실행 방법은 [references/drawio.md](references/drawio.md)에 있습니다.
- `scripts/render-svg.py`로 검증된 XML에서 첫 화면용 SVG를 생성합니다. 접두어 없는 기본 SVG 네임스페이스를 사용합니다. 편집기만 켜야 그림이 보이는 페이지를 만들지 않습니다.
- `assets/viewer.html`, `assets/viewer.js`, `assets/diagram-runtime.js`를 설명 페이지의 출발점으로 사용합니다. 실제 내용으로 `data/manifest.json`을 작성합니다. 전체 AI 채팅 앱을 설치하거나 API 키를 요구할 필요는 없습니다.
- 제목은 결과를, 그림은 관계를, 짧은 설명은 조건과 예외를 맡습니다. 노드 선택·이전/다음·확대/축소·전체보기·원문 링크·원본 저장을 제공합니다. 꾸밈과 반복 설명을 줄이고 팀의 `polish-writing`·`polish-ui` 기준을 따릅니다.
- 전체보기는 그림 너비를 화면 안에 맞추고 스크롤 위치를 초기화합니다. 모바일 최소 너비가 확대·축소를 막지 않도록 공통 런타임을 사용합니다.
- 설명 도구는 Next AI Draw.io로 통일합니다. 원문에 없는 수치나 효과를 새로 만들지 않습니다.
- SVG가 실제 SVG 요소로 삽입되는지, 모든 그림과 노드 선택·단계 이동·확대/축소·전체보기가 동작하는지 확인합니다. 브라우저나 실기기 확인을 못 했다면 그 범위를 명시합니다. 결과 페이지와 원문 링크를 전달합니다.
