const repo='https://github.com/jungrok5/ai-code-collaboration-best-practices/blob/85738cb5d8daf608d701b60cf82e9c5aa98c6c10/';
const chapters={
 flow:{title:'이슈에서 머지까지',steps:[
 ['10','이슈에 완료 조건을 적습니다.','사람 · 작업 범위','무엇을 바꾸고 어떤 결과가 나오면 완료인지 정합니다. AI가 테스트로 확인할 수 있는 수용 기준이 출발점입니다.','이슈 → 브랜치 → 초안 PR','docs/01-playbook.md'],
 ['11','AI가 작업을 분류합니다.','AI · 제안','AI는 이슈를 읽고 라벨과 범위를 제안합니다. 분류 결과만으로 구현이 시작되지는 않습니다.','make ai-triage ISSUE=12','README.md'],
 ['12','사람이 AI에 맡길지 정합니다.','사람 판단 ①','메인테이너가 ai:ready 라벨을 지정합니다. 무엇을 맡길지, 완료 조건이 충분히 명확한지 사람이 판단하는 지점입니다.','ai:ready','docs/01-playbook.md'],
 ['13','AI가 테스트와 코드를 작성합니다.','AI · 구현','기존 코드를 탐색하고 필요한 테스트와 코드를 작성합니다. 별도 worktree에서 작업하고, 실행한 검사 결과를 증거로 남깁니다.','make ai-implement ISSUE=12 POST=1','docs/01-playbook.md'],
 ['14','초안 PR에서 검증합니다.','CI · 검사 / AI · 참고 리뷰','CI가 린트·타입·테스트 등을 검사합니다. AI 리뷰의 지적은 검증할 주장입니다. CI가 실패하면 원인을 수정하고 다시 검사합니다.','make check\nAI 리뷰 ≠ 사람 승인','docs/06-code-review-policy.md'],
 ['15','CODEOWNER가 결과를 승인합니다.','사람 판단 ②','작성자는 생성된 코드를 읽습니다. CODEOWNER는 정확성·보안·설계 정합성을 검토합니다. AI 승인은 사람 승인으로 집계되지 않습니다.','ci-ok + CODEOWNER 승인\n에이전트 커밋은 agent-approval-check','docs/06-code-review-policy.md'],
 ['16','조건을 충족한 PR을 머지합니다.','사람 · 반영 / 워크플로 · 상태 동기화','squash로 main에 반영합니다. 에이전트 PR이 머지되면 워크플로가 이슈를 ai:done으로 변경합니다. 에이전트는 직접 승인하거나 머지하지 않습니다.','squash → ai:done\nrelease-please가 릴리스 PR 갱신','docs/01-playbook.md']
 ]},
 guards:{title:'같은 규칙, 서로 다른 검사 지점',steps:[
 ['10','규칙의 원본은 하나입니다.','팀 · 규칙','AGENTS.md에 사람과 에이전트가 공유할 규칙을 둡니다. CLAUDE.md, GEMINI.md 등은 이 파일을 가리키는 연결 파일입니다.','AGENTS.md','docs/03-ai-context-files.md'],
 ['11','도구 선택과 팀 기준을 분리합니다.','여러 AI 도구','도구별 기능은 달라도 읽어야 하는 팀 기준은 같습니다. Claude 훅이 모든 AI 도구에서 동작하는 것은 아닙니다.','Claude · Copilot · Cursor\nCodex · Gemini','docs/11-tool-support-matrix.md'],
 ['12','Claude Code는 작업 중에도 차단합니다.','로컬 · Claude 전용','플러그인 훅은 보호 경로 수정, main 커밋, 강제 푸시를 차단합니다. 이 훅의 적용 범위는 Claude Code입니다.','team-ai-workflow / hooks','README.md'],
 ['13','커밋 전에는 같은 검사를 실행합니다.','로컬 · 공통 검사','pre-commit과 make check가 사람의 변경에도 검사를 적용합니다. 린트·타입·테스트와 글·화면 기준을 확인합니다.','make check\nmake style','README.md'],
 ['14','PR에서도 검사와 승인을 요구합니다.','GitHub · 공통 조건','CI, CODEOWNERS, 룰셋이 GitHub 쪽 조건을 확인합니다. 에이전트 커밋이 포함된 PR은 사람 승인도 별도로 확인합니다.','ci-ok\nagent-approval-check','docs/06-code-review-policy.md']
 ]},
 size:{title:'작업의 크기만큼 방향을 먼저 확인',steps:[
 ['11','T0는 이슈와 브랜치로 시작합니다.','T0 · 작은 변경','한 문장으로 설명되는 버그 수정이나 작은 기능입니다. 모든 작은 변경에 별도 설계 문서를 요구하지 않습니다.','이슈 → 브랜치 → 일반 PR 리뷰','docs/14-design-first-and-overlap.md'],
 ['12','T1는 초안 PR에 계획을 둡니다.','T1 · 여러 파일 / 방법 미정','여러 파일을 바꾸거나 접근법이 하나로 정해지지 않은 작업입니다. 계획을 초안 PR 맨 위에 공유하고 리뷰어의 OK를 받은 뒤 구현합니다.','초안 PR 계획 → 리뷰어 OK → 구현','docs/14-design-first-and-overlap.md'],
 ['13','T2는 설계를 먼저 머지합니다.','T2 · 큰 변경 / 계약 변경','여러 모듈·레포, 공개 API·스키마, 하루 이상 걸리거나 영역이 모호한 작업입니다. 1쪽 설계와 구조도를 작은 PR로 먼저 머지합니다.','설계 PR 머지 → 구현 PR\ndocs/designs/NNNN-*.md','docs/14-design-first-and-overlap.md'],
 ['17','먼저 같은 영역의 작업을 확인합니다.','팀 · 겹침 조율','활성 설계와 열린 PR의 영역을 비교합니다. 겹침이 있으면 담당자와 작업을 합치거나 영역·순서를 조율합니다. 겹침 알림 자체는 PR 차단이 아닙니다.','make overlap AREAS="src/auth/**"','docs/14-design-first-and-overlap.md']
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
  const activate=()=>{const idx=chapters[current].steps.findIndex(s=>s[0]===n.dataset.node);if(idx!==-1){step=idx;updateStep()}else if(n.dataset.node==='17'&&current==='flow'){step=4;updateStep();el('step-text').textContent='CI 실패는 구현 단계로 돌아가는 신호입니다. 실패 원인을 고치고 다시 검증하며, 테스트를 끄거나 느슨하게 만들어 통과시키지 않습니다.'}};
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
function showError(error){console.error('Diagram loading failed:',error);el('step-text').textContent='구조도를 불러오지 못했습니다. 페이지를 새로고침하거나 Draw.io 편집 버튼으로 원본을 확인할 수 있습니다.';}
showDiagram('flow').catch(showError);
