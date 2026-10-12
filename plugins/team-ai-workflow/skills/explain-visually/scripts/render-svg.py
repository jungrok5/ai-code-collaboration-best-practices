"""Static first-paint fallback from the verified Next AI Draw.io XML.
The bundled draw.io editor remains available for native rendering/editing.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import sys
import html,re
NS='http://www.w3.org/2000/svg'
E.register_namespace('',NS)
def tag(name,attrs={},text=None):
 n=E.Element('{%s}%s'%(NS,name),{k:str(v) for k,v in attrs.items()})
 if text is not None:n.text=text
 return n
def style(s):
 return dict(x.split('=',1) for x in s.split(';') if '=' in x)
if len(sys.argv)!=3: raise SystemExit('Usage: render-svg.py INPUT.drawio OUTPUT.svg')
p=Path(sys.argv[1]);root=E.fromstring(p.read_bytes());name=re.sub(r'[^a-z0-9_-]','-',p.stem.lower())
if len(root.findall('diagram'))!=1: raise ValueError('Render one diagram page at a time')
cells={n.get('id'):n for n in root.iter('mxCell')};geo={}
for id,n in cells.items():
 if n.get('vertex')=='1':
  g=n.find('mxGeometry')
  st=style(n.get('style',''))
  if n.get('parent','1')!='1' or 'swimlane' in n.get('style','') or st.get('shape','rectangle') not in ['rectangle','rhombus']:raise ValueError('Use the native draw.io editor for compound shapes')
  geo[id]=tuple(float(g.get(k,'0')) for k in ['x','y','width','height'])
svg=tag('svg',{'viewBox':'0 0 800 600','width':'800','height':'600','role':'img','aria-labelledby':f'{name}-title'})
svg.append(tag('title',{'id':f'{name}-title'},root.find('diagram').get('name')))
defs=tag('defs'); marker=tag('marker',{'id':f'arrow-{name}','markerWidth':8,'markerHeight':8,'refX':7,'refY':4,'orient':'auto','markerUnits':'userSpaceOnUse'});marker.append(tag('path',{'d':'M0,0 L8,4 L0,8 Z','fill':'#647487'}));defs.append(marker);svg.append(defs)
for id,n in cells.items():
 if n.get('edge')!='1':continue
 st=style(n.get('style',''));a=geo[n.get('source')];b=geo[n.get('target')]
 start=(a[0]+a[2]*float(st.get('exitX','.5')),a[1]+a[3]*float(st.get('exitY','1')))
 end=(b[0]+b[2]*float(st.get('entryX','.5')),b[1]+b[3]*float(st.get('entryY','0')))
 points=[(float(t.get('x')),float(t.get('y'))) for t in n.findall('.//Array/mxPoint')]
 if not points and abs(start[0]-end[0])>1 and abs(start[1]-end[1])>1:
  points=[(start[0],(start[1]+end[1])/2),(end[0],(start[1]+end[1])/2)]
 route=[start]+points+[end];g=tag('g',{'data-edge':id});g.append(tag('path',{'d':'M'+' L'.join(f'{x},{y}' for x,y in route),'fill':'none','stroke':'#647487','stroke-width':2,'stroke-dasharray':'5 4' if st.get('dashed')=='1' else 'none','marker-end':f'url(#arrow-{name})'}))
 value=n.get('value','')
 if value:
  # Most edge labels sit between adjacent nodes. Return paths use the outside gutter.
  x=(start[0]+end[0])/2;y=(start[1]+end[1])/2-8
  if id=='37':x=262;y=390
  g.append(tag('text',{'x':x,'y':y,'text-anchor':'middle','font-size':11,'fill':'#536374','paint-order':'stroke','stroke':'white','stroke-width':4},value))
 svg.append(g)
for id,n in cells.items():
 if id not in geo:continue
 st=style(n.get('style',''));x,y,w,h=geo[id];text=n.get('value','');g=tag('g',{'data-node':id})
 if 'text;' in n.get('style',''):
  g.append(tag('text',{'x':x,'y':y+17,'font-size':12,'font-weight':600,'fill':'#536374'},text));svg.append(g);continue
 g.set('tabindex','0');g.set('role','button');g.set('aria-label',text.replace('\n',' '));g.set('class','diagram-node')
 attrs={'fill':st.get('fillColor','#fff'),'stroke':st.get('strokeColor','#c4cbd3'),'stroke-width':1.4}
 if 'rhombus' in n.get('style',''):
  g.append(tag('polygon',{**attrs,'points':f'{x+w/2},{y} {x+w},{y+h/2} {x+w/2},{y+h} {x},{y+h/2}'}))
 else:g.append(tag('rect',{**attrs,'x':x,'y':y,'width':w,'height':h,'rx':6}))
 lines=text.split('\n');base=y+h/2-(len(lines)-1)*12+5
 for i,line in enumerate(lines):g.append(tag('text',{'x':x+w/2,'y':base+i*24,'text-anchor':'middle','font-size':15 if i==0 else 12,'font-weight':650 if i==0 else 400,'fill':'#172333'},line))
 svg.append(g)
svg.set('style','font-family:Arial,"Noto Sans KR",sans-serif');Path(sys.argv[2]).write_bytes(E.tostring(svg,encoding='utf-8'))
print(name,'fallback SVG:',len(geo),'nodes')
