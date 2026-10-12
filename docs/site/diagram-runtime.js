(function(global){
 const ns='http://www.w3.org/2000/svg';
 function parseSvg(markup){
  const doc=new DOMParser().parseFromString(markup,'image/svg+xml'),source=doc.documentElement;
  if(doc.querySelector('parsererror')||source.localName!=='svg'||source.namespaceURI!==ns)throw Error('Invalid SVG document');
  const root=document.createElementNS(ns,'svg');
  for(const attr of source.attributes)if(!attr.name.startsWith('xmlns'))root.setAttribute(attr.name,attr.value);
  for(const child of source.childNodes)root.appendChild(document.importNode(child,true));
  return root;
 }
 function viewport(stage,svg,onChange=()=>{}){
  let zoom=1,base=1;
  function measure(){const css=getComputedStyle(stage);return Math.max(1,stage.clientWidth-(parseFloat(css.paddingLeft)||0)-(parseFloat(css.paddingRight)||0))}
  function apply(value,center=true){
   const oldWidth=parseFloat(svg.style.width)||base*zoom,oldCenter=stage.scrollLeft+stage.clientWidth/2;
   base=measure();zoom=Math.max(.35,Math.min(4,value));
   svg.style.minWidth='0';svg.style.maxWidth='none';svg.style.width=`${base*zoom}px`;svg.style.height='auto';svg.style.flexShrink='0';stage.style.justifyContent='flex-start';
   stage.scrollLeft=center?Math.max(0,oldCenter*(base*zoom/oldWidth)-stage.clientWidth/2):0;
   if(!center)stage.scrollTop=0;
   onChange(Math.round(zoom*100));
  }
  base=measure();apply(Math.max(1,640/base),false);
  const observer=typeof ResizeObserver==='function'?new ResizeObserver(()=>{if(Math.abs(measure()-base)>1)apply(zoom,false)}):null;
  observer?.observe(stage);
  return {increase:()=>apply(zoom*1.25),decrease:()=>apply(zoom/1.25),fit:()=>apply(1,false),destroy:()=>observer?.disconnect(),get scale(){return zoom}};
 }
 global.VisualDiagram={parseSvg,viewport};
})(window);
