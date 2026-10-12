const repo='https://github.com/jungrok5/ai-code-collaboration-best-practices/blob/85738cb5d8daf608d701b60cf82e9c5aa98c6c10/';
const chapters={
 flow:{title:'이슈에서 머지까지',steps:[
 ["10","완료 조건을 정합니다.","사람 · 작업 범위","바꿀 대상과 기대하는 결과를 이슈에 적습니다. 완료 여부를 테스트로 확인할 수 있도록 조건을 구체적으로 작성합니다.","이슈 → 브랜치 → 초안 PR","docs/01-playbook.md"],
 ["11","AI가 작업 범위와 라벨을 제안합니다.","AI · 제안","사람이 이슈의 분류 결과를 확인합니다. 분류가 끝나도 이 단계에서는 구현을 시작하지 않습니다.","make ai-triage ISSUE=12","README.md"],
 ["12","사람이 구현 시작을 허용합니다.","사람 · 작업 위임","저장소 관리자가 작업 범위와 완료 조건을 확인한 뒤 ai:ready 라벨을 지정합니다.","ai:ready","docs/01-playbook.md"],
 ["13","AI가 테스트와 코드를 작성합니다.","AI · 구현","기존 코드를 확인하고 별도 작업 공간(worktree)에서 구현합니다. 필요한 테스트를 작성하고 실행한 검사 결과를 기록합니다.","make ai-implement ISSUE=12 POST=1","docs/01-playbook.md"],
 ["14","초안 PR에서 자동 검사 결과를 확인합니다.","CI · 자동 검사 / AI · 참고 리뷰","변경 제안(PR, Pull Request)을 올리면 자동 검사(CI, Continuous Integration)가 린트·타입·테스트 등을 확인합니다. AI 리뷰의 지적도 실제 코드로 검증하며 CI가 실패하면 원인을 수정하고 다시 검사합니다.","make check\nAI 리뷰 ≠ 사람 승인","docs/06-code-review-policy.md"],
 ["15","코드 담당자가 변경을 검토합니다.","사람 · 코드 검토와 승인","작성자는 생성된 코드를 읽고 코드 담당자(CODEOWNER)는 정확성·보안·설계 정합성을 검토합니다. AI의 승인은 사람 승인으로 집계되지 않습니다.","ci-ok + CODEOWNER 승인\n에이전트 커밋은 agent-approval-check","docs/06-code-review-policy.md"],
 ["16","승인된 PR을 main에 반영합니다.","사람 · 머지 / 워크플로 · 상태 변경","커밋을 하나로 합치는 squash 방식으로 머지합니다. 에이전트 PR이 머지되면 워크플로가 이슈 라벨을 ai:done으로 변경합니다. 에이전트는 PR을 직접 승인하거나 머지하지 않습니다.","squash → ai:done\nrelease-please가 릴리스 PR 갱신","docs/01-playbook.md"]
 ]},
 guards:{title:'검사 도구와 적용 범위',steps:[
 ["10","팀 규칙은 AGENTS.md에 둡니다.","팀 · 규칙","CLAUDE.md, GEMINI.md 등 도구별 파일은 AGENTS.md를 참조합니다. 사람과 AI 도구가 같은 원문을 읽도록 구성합니다.","AGENTS.md","docs/03-ai-context-files.md"],
 ["11","AI 도구마다 적용 범위가 다릅니다.","여러 AI 도구","Claude, Copilot, Cursor, Codex, Gemini는 같은 팀 규칙을 읽습니다. 작업 중 변경을 차단하는 Claude 훅은 Claude Code에서만 동작합니다.","Claude · Copilot · Cursor\nCodex · Gemini","docs/11-tool-support-matrix.md"],
 ["12","Claude 훅이 작업 중 변경을 차단합니다.","로컬 · Claude Code 전용","차단 대상은 보호 경로 수정, main 커밋, 강제 푸시입니다.","team-ai-workflow / hooks","README.md"],
 ["13","커밋 전 검사는 사람의 변경에도 적용합니다.","로컬 · 공통 검사","pre-commit과 make check로 린트·타입·테스트를 실행합니다. make style은 글과 화면의 팀 기준을 검사합니다.","make check\nmake style","README.md"],
 ["14","PR 검사와 사람 승인은 GitHub에서 확인합니다.","GitHub · 머지 조건","CI 검사와 CODEOWNERS, 룰셋을 함께 적용합니다. 에이전트 커밋이 포함된 PR은 사람이 승인했는지도 별도로 확인합니다.","ci-ok\nagent-approval-check","docs/06-code-review-policy.md"]
 ]},
 size:{title:'작업 크기별 계획과 설계',steps:[
 ["11","작은 변경은 이슈와 브랜치로 시작합니다.","T0 · 작은 변경","한 문장으로 설명할 수 있는 버그 수정이나 작은 기능입니다. 별도 설계 문서를 만들지 않고 일반 PR 리뷰로 검토합니다.","이슈 → 브랜치 → 일반 PR 리뷰","docs/14-design-first-and-overlap.md"],
 ["12","여러 파일을 바꿀 때는 계획을 먼저 공유합니다.","T1 · 여러 파일 / 방법 미정","접근법이 정해지지 않은 작업도 여기에 해당합니다. 초안 PR 맨 위에 계획을 적고 리뷰어의 동의를 받은 뒤 구현합니다.","초안 PR 계획 → 리뷰어 OK → 구현","docs/14-design-first-and-overlap.md"],
 ["13","큰 변경은 설계 PR을 먼저 머지합니다.","T2 · 큰 변경 / 계약 변경","여러 모듈·레포에 걸친 작업이나 공개 API·스키마 변경이 대상입니다. 하루 이상 걸리거나 작업 영역이 모호한 경우도 포함하며 한 쪽 설계와 구조도를 작은 PR로 먼저 머지합니다.","설계 PR 머지 → 구현 PR\ndocs/designs/NNNN-*.md","docs/14-design-first-and-overlap.md"],
 ["17","같은 영역의 진행 중인 작업을 확인합니다.","팀 · 작업 겹침 조율","활성 설계와 열린 PR의 작업 영역을 비교합니다. 겹치면 담당자와 작업을 합치거나 범위와 순서를 조율합니다. 겹침 알림만으로 PR을 차단하지는 않습니다.","make overlap AREAS=\"src/auth/**\"","docs/14-design-first-and-overlap.md"]
 ]}
};
let current='flow',step=0,version=0,xmls={},editorReady=false,editedXml='',viewport=null;
const el=id=>document.getElementById(id);
function svgElementFromXml(markup){return VisualDiagram.parseSvg(markup)}
async function showDiagram(id){
 current=id;step=0;const token=++version;
 document.querySelectorAll('[data-diagram]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.diagram===id)));
 el('diagram-title').textContent=chapters[id].title;el('download-drawio').href=`data/${id}.drawio`;
 const svg=await fetch(`data/drawio-${id}.svg`).then(r=>{if(!r.ok)throw Error('구조도를 불러오지 못했습니다.');return r.text()});
 if(token!==version)return;
 const root=svgElementFromXml(svg);
 viewport?.destroy();
 el('diagram-stage').replaceChildren(root);
 viewport=VisualDiagram.viewport(el('diagram-stage'),root,value=>{el('zoom-value').textContent=`${value}%`});
 root.setAttribute('aria-label',chapters[id].title);
 root.querySelectorAll('[data-node]').forEach(n=>{
  const activate=()=>{const idx=chapters[current].steps.findIndex(s=>s[0]===n.dataset.node);if(idx!==-1){step=idx;updateStep()}else if(n.dataset.node==='17'&&current==='flow'){step=4;updateStep();el('step-text').textContent='CI가 실패하면 구현 단계에서 원인을 수정하고 다시 검사합니다. 테스트를 끄거나 기준을 완화해 통과시키지 않습니다.'}};
  n.addEventListener('click',activate);n.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();activate()}});
 });
 updateStep();
}
function updateStep(){
 const all=chapters[current].steps,s=all[step];
 el('step-count').textContent=`${String(step+1).padStart(2,'0')} / ${String(all.length).padStart(2,'0')}`;
 el('step-title').textContent=s[1];el('step-owner').textContent=s[2];el('step-text').textContent=s[3];el('step-code').textContent=s[4];el('step-source').href=repo+s[5];
 el('prev-step').disabled=step===0;el('next-step').disabled=step===all.length-1;
 el('step-dots').replaceChildren(...all.map((_,i)=>{const b=document.createElement('button');b.textContent=String(i+1);b.setAttribute('aria-label',`${i+1}단계: ${all[i][1]}`);b.setAttribute('aria-pressed',String(i===step));b.addEventListener('click',()=>{step=i;updateStep()});return b}));
 el('diagram-stage').querySelectorAll('[data-node]').forEach(n=>n.classList.toggle('active',n.dataset.node===s[0]));
 const stage=el('diagram-stage'),selected=stage.querySelector(`[data-node="${s[0]}"]`),svg=stage.querySelector('svg');
 if(selected&&svg&&stage.scrollWidth>stage.clientWidth){const b=selected.getBBox();stage.scrollTo({left:Math.max(0,(b.x+b.width/2)*svg.getBoundingClientRect().width/800-stage.clientWidth/2),behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'})}
}
document.querySelectorAll('[data-diagram]').forEach(b=>b.addEventListener('click',()=>showDiagram(b.dataset.diagram).catch(showError)));
el('prev-step').addEventListener('click',()=>{if(step>0){step--;updateStep()}});el('next-step').addEventListener('click',()=>{if(step<chapters[current].steps.length-1){step++;updateStep()}});
el('zoom-in').addEventListener('click',()=>viewport?.increase());el('zoom-out').addEventListener('click',()=>viewport?.decrease());el('reset-zoom').addEventListener('click',()=>viewport?.fit());
const frame=el('editor-frame');
function post(msg){frame.contentWindow?.postMessage(JSON.stringify(msg),location.origin)}
el('edit-diagram').addEventListener('click',async()=>{
 if(!xmls[current])xmls[current]=await fetch(`data/${current}.drawio`).then(r=>r.text());editedXml=xmls[current];
 el('editor-dialog').showModal();
 if(!frame.getAttribute('src'))frame.src='assets/drawio/index.html?embed=1&proto=json&spin=1&ui=min&noSaveBtn=1&noExitBtn=1&saveAndExit=0&offline=1&lang=ko&dark=0';
 else if(editorReady)post({action:'load',xml:editedXml,autosave:1});
});
window.addEventListener('message',e=>{
 if(e.origin!==location.origin||e.source!==frame.contentWindow)return;
 let msg;try{msg=typeof e.data==='string'?JSON.parse(e.data):e.data}catch{return}
 if(msg.event==='init'){editorReady=true;post({action:'load',xml:editedXml,autosave:1})}
 if((msg.event==='autosave'||msg.event==='save')&&msg.xml)editedXml=msg.xml;
});
el('close-editor').addEventListener('click',()=>el('editor-dialog').close());
el('save-edits').addEventListener('click',()=>{const a=document.createElement('a'),url=URL.createObjectURL(new Blob([editedXml],{type:'application/xml'}));a.href=url;a.download=`ai-collab-${current}-edited.drawio`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});
function showError(error){console.error('Diagram loading failed:',error);el('step-text').textContent='구조도를 불러오지 못했습니다. 페이지를 새로고침하고 같은 문제가 계속되면 Draw.io에서 편집 버튼으로 원본을 확인하십시오.';}
showDiagram('flow').catch(showError);
