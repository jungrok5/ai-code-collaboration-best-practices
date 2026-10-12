import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {resolve} from 'node:path';
const require=createRequire(import.meta.url),modules=process.argv[2]||'.cache/visual-tests/node_modules';
const {JSDOM}=require(resolve(modules,'jsdom'));
for(const width of [375,768,1024,1440]){
 const dom=new JSDOM(readFileSync('docs/site/index.html','utf8'),{url:'https://example.test/index.html',runScripts:'outside-only'}),w=dom.window;
 const stage=w.document.getElementById('diagram-stage');stage.style.padding='10px';Object.defineProperty(stage,'clientWidth',{value:width,configurable:true});
 w.fetch=async path=>({ok:true,text:async()=>readFileSync(resolve('docs/site',String(path)),'utf8')});
 w.eval(readFileSync('docs/site/diagram-runtime.js','utf8'));w.eval(readFileSync('docs/site/drawio.js','utf8'));
 for(const id of ['flow','guards','size']){
  await w.showDiagram(id);const svg=stage.querySelector('svg');
  assert.ok(svg instanceof w.SVGSVGElement);assert.ok(svg.querySelector('rect') instanceof w.SVGElement);assert.ok(svg.querySelector('path') instanceof w.SVGElement);
  const before=parseFloat(svg.style.width);w.document.getElementById('zoom-in').click();assert.ok(parseFloat(svg.style.width)>before);w.document.getElementById('zoom-out').click();assert.ok(Math.abs(parseFloat(svg.style.width)-before)<.1);
  stage.scrollLeft=150;stage.scrollTop=25;w.document.getElementById('reset-zoom').click();assert.equal(parseFloat(svg.style.width),width-20);assert.equal(stage.scrollLeft,0);assert.equal(stage.scrollTop,0);
  w.document.getElementById('next-step').click();assert.ok(w.document.getElementById('step-count').textContent.startsWith('02'));
  svg.querySelector(`[data-node="${{flow:'12',guards:'12',size:'13'}[id]}"]`).dispatchEvent(new w.MouseEvent('click',{bubbles:true}));assert.ok(w.document.getElementById('step-count').textContent.startsWith('03'));
 }
 const prefixed='<ns0:svg xmlns:ns0="http://www.w3.org/2000/svg"><ns0:rect width="20" height="20"/></ns0:svg>';
 assert.ok(w.svgElementFromXml(prefixed).querySelector('rect') instanceof w.SVGElement);
 assert.throws(()=>w.svgElementFromXml('<div>invalid SVG</div>'));
 console.log(`DOM regression checks passed at ${width}px (layout dimensions are simulated)`);w.close();
}
