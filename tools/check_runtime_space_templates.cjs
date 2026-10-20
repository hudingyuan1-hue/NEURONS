// Offline delivery/interaction contract check. No browser engine is claimed.
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'..');
const outIndex=process.argv.indexOf('--output');
const output=outIndex>=0?path.resolve(process.argv[outIndex+1]):path.join(root,'deliverables/space_templates_corrected_20261019');
const page=fs.readFileSync(path.join(output,'00_空间与家具模板_可分享.html'),'utf8');
const matches=[...page.matchAll(/<script(?: [^>]*)?>([\s\S]*?)<\/script>/g)];
const readData=id=>JSON.parse(page.match(new RegExp('<script[^>]*id="'+id+'"[^>]*>([\\s\\S]*?)<\\/script>'))[1]);
const data=readData('space-data'),meta=readData('template-meta'),samples=readData('style-data'),js=matches.at(-1)[1];
const runtime=JSON.parse(fs.readFileSync(path.join(output,'runtime_spaces.json'),'utf8'));
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const passes=[],failures=[],downloads=[],copies=[];
function check(b,label){(b?passes:failures).push(label);if(!b)console.error('FAIL',label)}
const close=(a,b,eps=1e-5)=>Math.abs(a-b)<=eps;
const sub=(a,b)=>a.map((v,i)=>v-b[i]),dot=(a,b)=>a.reduce((n,v,i)=>n+v*b[i],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],length=a=>Math.hypot(...a),unit=a=>a.map(v=>v/length(a));
function pointInPolygon(p,poly){
 let inside=false;
 for(let i=0,j=poly.length-1;i<poly.length;j=i++){
  const a=poly[j],b=poly[i],d=sub(b,a),t=Math.max(0,Math.min(1,dot(sub(p,a),d)/Math.max(1e-20,dot(d,d))));
  if(length(sub(p,a.map((v,k)=>v+d[k]*t)))<1e-8)return true;
  if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])inside=!inside;
 }
 return inside;
}
function facePlane(f){
 if(!Array.isArray(f.points)||f.points.length<3||f.points.some(p=>p.length!==3||p.some(v=>!Number.isFinite(v))))return null;
 const origin=f.points[0],u=unit(sub(f.points[1],origin));let normal;
 for(let i=2;i<f.points.length;i++){const n=cross(u,sub(f.points[i],origin));if(length(n)>1e-8){normal=unit(n);break}}
 if(!normal||f.points.some(p=>Math.abs(dot(sub(p,origin),normal))>1e-6))return null;
 return {origin,u,v:cross(normal,u),normal};
}
function continuousEdges(faces){
 const planes=faces.map(facePlane);if(planes.some(p=>!p))return false;
 for(let fi=0;fi<faces.length;fi++){
  const f=faces[fi],plane=planes[fi];
  if(!['west','south','top'].includes(f.side)||!Array.isArray(f.edges))return false;
  const project=p=>[dot(sub(p,plane.origin),plane.u),dot(sub(p,plane.origin),plane.v)];
  const coplanar=faces.filter((g,i)=>Math.abs(dot(planes[i].normal,plane.normal))>1-1e-7&&Math.abs(dot(sub(g.points[0],plane.origin),plane.normal))<1e-7).map(g=>g.points.map(project));
  const covered=p=>coplanar.some(poly=>pointInPolygon(p,poly));
  for(const line of f.edges){
   if(line.length!==2||line.some(p=>p.length!==3||p.some(v=>!Number.isFinite(v))))return false;
   const a=project(line[0]),b=project(line[1]),du=b[0]-a[0],dv=b[1]-a[1],size=Math.hypot(du,dv);
   if(size<=1e-7)return false;
   const mid=[(a[0]+b[0])/2,(a[1]+b[1])/2],n=[-dv/size*2e-6,du/size*2e-6];
   if(covered(mid.map((v,i)=>v+n[i]))&&covered(mid.map((v,i)=>v-n[i])))return false;
  }
 }
 return true;
}
function canonicalRing(raw,hole=false){
 const ring=raw.map(p=>p.slice());if(same(ring[0],ring.at(-1)))ring.pop();
 const area=ring.reduce((n,p,i)=>{const q=ring[(i+1)%ring.length];return n+p[0]*q[1]-q[0]*p[1]},0);
 if(hole?area>0:area<0)ring.reverse();return ring;
}
function offsetRing(ring,t){
 return ring.map((p,i)=>{const a=unit(sub(p,ring[(i+ring.length-1)%ring.length])),b=unit(sub(ring[(i+1)%ring.length],p)),na=[a[1],-a[0]],nb=[b[1],-b[0]],den=Math.max(.2,1+dot(na,nb));let v=na.map((n,k)=>(n+nb[k])*t/den);if(length(v)>t*3)v=unit(v).map(n=>n*t*3);return p.map((n,k)=>n+v[k])});
}
function joinedContour(source){
 const pieces=source.architecture_surface.pieces,faces=pieces.flatMap(p=>p.custom_faces||[]),spec=source.space_spec||{},t=source.physical_wall.thickness_m;
 if(!faces.length)return false;
 const outer=spec.floor_polygon_m||[[0,0],[source.size_m[0],0],source.size_m,[0,source.size_m[1]]],rings=[canonicalRing(outer),...(spec.floor_holes_m||[]).map(r=>canonicalRing(r,true))];
 const tops=faces.filter(f=>f.side==='top');
 const at=(p,q)=>close(p[0],q[0],1e-5)&&close(p[2],q[1],1e-5);
 for(let ri=0;ri<rings.length;ri++){
  const ring=rings[ri];let width=t;
  if(ri>0){
   // Inner guard lips may be thinner than exterior walls. Measure their real
   // exported strip width, then require the entire ring to share that miter.
   const cap=tops.find(f=>f.points.slice(0,2).some(v=>at(v,ring[0])));if(!cap)return false;
   const index=at(cap.points[0],ring[0])?0:1,outerPoint=cap.points[index===0?3:2],d=unit(sub(ring[1],ring[0])),n=[d[1],-d[0]];
   width=dot(sub([outerPoint[0],outerPoint[2]],ring[0]),n);if(width<=0||width>t+1e-5)return false;
  }
  const offset=offsetRing(ring,width);
  for(let i=0;i<ring.length;i++){
   const p=ring[i],caps=tops.filter(f=>f.points.some(v=>at(v,p)));
   const interrupted=ri===0&&source.portals.some(m=>length(sub(p,m.wall_point||m.wall_point_m||m.at||m.at_m))<m.width_m*.5+t+.03);
   if(!interrupted&&caps.length<2)return false;
   // Every incident strip must end at the same mitred outer corner, rather
   // than an independent rectangular cap. Different shown heights are legal.
   for(const cap of caps)if(!cap.points.some(v=>at(v,offset[i])))return false;
  }
 }
 return true;
}
function joinedCornersFilled(source){
 const pieces=source.architecture_surface.pieces;if(pieces.some(p=>p.custom_faces))return joinedContour(source);
 const [w,d]=source.size_m,t=source.physical_wall.thickness_m,inside=(x,h,z)=>pieces.some(p=>{if(!Array.isArray(p.rect))return false;const [a,b,c,e]=p.rect;return x>a-1e-6&&x<a+c+1e-6&&z>b-1e-6&&z<b+e+1e-6&&h>p.bottom_m-1e-6&&h<p.bottom_m+p.height_m+1e-6});
 const heights=[...new Set(pieces.flatMap(p=>[p.bottom_m,p.bottom_m+p.height_m]))].sort((a,b)=>a-b);
 for(let hi=0;hi<heights.length-1;hi++){
  const h=(heights[hi]+heights[hi+1])/2;
  for(const [x,z,dx,dz] of [[0,0,1,1],[w,0,-1,1],[0,d,1,-1],[w,d,-1,-1]]){
   const cx=x-dx*t/2,cz=z-dz*t/2;
   if(inside(x+dx*.01,h,cz)&&inside(cx,h,z+dz*.01)&&!inside(cx,h,cz))return false;
  }
 }
 return true;
}
const activeProps=r=>[...r.furniture,...(r.decor||[])].filter(f=>!['wall','mapping','floor_marks'].includes(f.kind)&&!f.wall_mount&&!f.logical_exclusion&&f.render!==false&&Number(f.height_m)>.02);
class Node{constructor(tag){this.tag=tag;this.children=[];this.selectors=new Map;this.dataset={};this.style={};this.value='';this.open=false;this.handlers={};}set innerHTML(v){this.html=v;this.selectors.clear()}get innerHTML(){return this.html||''}append(...n){this.children.push(...n)}replaceChildren(...n){this.children=n}querySelector(s){if(!this.selectors.has(s))this.selectors.set(s,new Node(s));return this.selectors.get(s)}addEventListener(k,f){this.handlers[k]=f}click(){if(this.tag==='a')downloads.push({href:this.href,name:this.download});if(this.onclick)return this.onclick()}select(){}remove(){}}
const nodes=new Map;for(const id of ['rooms','query','chapter','counter','toast','first-message','space-data','template-meta','style-data','style-samples'])nodes.set(id,new Node(id));nodes.get('chapter').value='all';nodes.get('space-data').textContent=JSON.stringify(data);nodes.get('template-meta').textContent=JSON.stringify(meta);nodes.get('style-data').textContent=JSON.stringify(samples);
const document={body:new Node('body'),getElementById:id=>nodes.get(id),createElement:tag=>new Node(tag),execCommand:()=>true};
const context={document,navigator:{clipboard:{writeText:async s=>copies.push(s)}},setTimeout:()=>0,console,JSON,String};
vm.createContext(context);vm.runInContext(js,context,{timeout:10000});
(async()=>{
 check(data.length===56&&nodes.get('rooms').children.length===56,'all55 regular scenes and independent hidden fragment are present');
 const expectedPropCount=runtime.rooms.reduce((n,r)=>n+activeProps(r).length,0);
 check(meta.furniture_templates===expectedPropCount&&data.reduce((n,r)=>n+r.props.length,0)===expectedPropCount,'every current eligible runtime object has one locator; hidden legacy IDs do not create production orders');
 check(same(runtime.presentation.x_basis_px,[96,-6])&&same(runtime.presentation.depth_basis_px,[16,56])&&runtime.presentation.height_px_per_m===78,'export uses exact shared corrected2D basis and adult height density');
 check(nodes.get('style-samples').children.length===2,'both existing style references are embedded with restricted reference roles');
 check(samples[0].filename==='ENV_ROOM_L1_ROOM_BASE_v001.png','main empty-room style reference is the newly approved BASE image');
 check(!/<(?:script|img)[^>]+(?:src|href)=["'](?:https?:|file:)/i.test(page),'page images/scripts do not depend on local paths or external hosts');
 const room=nodes.get('rooms').children[0];
 room.querySelector('[data-act="base"]').click();
 check(downloads[0].name===data[0].base_filename&&downloads[0].href===data[0].base,'room download points to the embedded exact PNG');
 room.querySelector('[data-act="style"]').click();
 check(downloads.at(-1).name===samples[0].filename&&downloads.at(-1).href===samples[0].png,'per-room style download is the approved main reference, not the engineering locator');
 await room.querySelector('[data-act="prompt"]').click();check(copies.at(-1)===data[0].prompt,'room prompt copies only that room instruction');
 const details=room.querySelector('details');details.open=true;details.handlers.toggle();
 const prop=room.querySelector('.props').children[0];
 check(room.querySelector('.props').children.length===data[0].props.length,'expansion creates only this room furniture cards');
 prop.querySelector('[data-act="download"]').click();await prop.querySelector('[data-act="copy"]').click();
 check(downloads.at(-1).href===data[0].props[0].png&&copies.at(-1)===data[0].props[0].prompt,'furniture PNG and prompt copy remain paired');
 nodes.get('chapter').value='6';nodes.get('chapter').onchange();check(nodes.get('rooms').children.length===7,'Street filter includes main and both branch segments');
 nodes.get('chapter').value='0';nodes.get('chapter').onchange();check(nodes.get('rooms').children.length===1,'hidden route remains independent from Street7');
 nodes.get('chapter').value='all';nodes.get('query').value='床头柜';nodes.get('query').oninput();check(nodes.get('rooms').children.length>0,'furniture name search finds containing scenes');
 await nodes.get('first-message').click();check(copies.at(-1).includes('极乐迪斯科')&&copies.at(-1).includes('死亡之门'),'first-message copy contains unified style and limited reference uses');
 check(!copies.at(-1).includes('0.85')&&!copies.at(-1).includes('后20%')&&copies.at(-1).includes('低矮横窗'),'first-message separates painting from fixed runtime cut algorithm and includes wall-integrated low windows');
 check(data.every(r=>!r.prompt.includes('0.85米实体剖切')&&!r.prompt.includes('西墙后20%')),'generation copy no longer forces engine cut profile as final architectural appearance');
 check(data.filter(r=>r.reuse).every(r=>r.prompt.includes('图1是已确认的同房前阶段底图')),'same-room phase edits request the actual confirmed base as primary image');
 check(data.find(r=>r.id==='L6_street_side').outdoor===false,'Street covered side room is described as interior, not open air');
 check(data.find(r=>r.id==='L3_ward').reuse===false,'different L3 ward door/window orientation is not forced to preserve L2 geometry');
 const bedroom=data.find(r=>r.id==='L1_bedroom').window_display[0];
 check(bedroom.physical.sill===.9&&bedroom.physical.opening===1.15&&bedroom.drawing.sill<bedroom.physical.sill&&(bedroom.drawing.end-bedroom.drawing.start)/bedroom.drawing.opening>2.5,'bedroom art display is a low horizontal window; original physical opening and along-wall span remain recorded');
 const names=new Set;let pngCount=0;
 for(const r of data){for(const [url,name,size] of [[r.base,r.base_filename,r.room_png_geometry.pixel_size],[r.placed,r.placement_filename,r.room_png_geometry.pixel_size],...r.props.map(p=>[p.png,p.filename,p.pixel_size])]){check(!names.has(name),'unique filename '+name);names.add(name);const b=Buffer.from(url.split(',')[1],'base64');if(!b.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))failures.push('invalid PNG '+name);else if(!same([b.readUInt32BE(16),b.readUInt32BE(20)],size))failures.push('PNG dimensions differ from anchor metadata '+name);pngCount++}for(const p of r.props){if(p.ground_anchor_px.some((v,i)=>v<0||v>p.pixel_size[i]))failures.push('ground anchor outside '+p.filename)}}
 check(pngCount===data.length*2+data.reduce((n,r)=>n+r.props.length,0)&&pngCount===meta.files,'all embedded room/placement/object PNGs match actual manifest, not a stale hardcoded count');
 for(const r of data){
  const source=runtime.rooms.find(s=>s.id===r.id);check(!!source,'room exported from actual layout '+r.id);if(!source)continue;
  check(same(r.size,source.size_m)&&same(r.wall,source.physical_wall),'physical size/wall retained '+r.id);
  check(same(r.wall_display_segments,source.wall_display_segments),'exact runtime opaque wall segments '+r.id);
  check(same(r.floor_polygon_m,source.space_spec?.floor_polygon_m??null)&&same(r.floor_holes_m,source.space_spec?.floor_holes_m||[]),'actual floor contour and nonwalkable holes retained '+r.id);
  const surface=r.architecture_surface,shared=source.architecture_surface;
  check(surface?.source==='runtime_export'&&shared&&same(surface.pieces,shared.pieces)&&same(surface.faces,shared.faces),'template uses exact game-exported architectural solids/faces '+r.id);
  check(surface?.internal_block_outlines===false&&continuousEdges(surface.faces),'only real coplanar boundaries are outlined '+r.id);
  check(shared&&joinedCornersFilled(source),'all actually adjoining exterior wall spans have solid corners '+r.id);
  const g=r.room_png_geometry,[pw,ph]=g.pixel_size,pad=g.padding_px,content=g.content_pixel_size;
  check(pw*9===ph*16&&same(g.canvas_aspect_ratio,[16,9])&&pad.length===4&&pad.every(v=>v>=0)&&close(content[0]+pad[0]+pad[2],pw)&&close(content[1]+pad[1]+pad[3],ph)&&close(pad[0],pad[2])&&close(pad[1],pad[3]),'16:9 room canvas expands by equal padding without scaling '+r.id);
  const raw=[];for(const x of [-.2,source.size_m[0]+.2])for(const z of [-.2,source.size_m[1]+.2])for(const h of [0,source.physical_wall.height_m])raw.push([(x*source.projection.x_basis_px[0]+z*source.projection.depth_basis_px[0])*g.source_scale,(x*source.projection.x_basis_px[1]+z*source.projection.depth_basis_px[1]-h*source.projection.height_px_per_m)*g.source_scale]);
  check(g.ground_origin_px.every((v,i)=>close(v,64-Math.min(...raw.map(p=>p[i]))+pad[i],.0011)),'room ground origin includes exact canvas padding '+r.id);
  check(Array.isArray(source.window_display_specs)&&r.window_display.every(w=>{const e=source.window_display_specs.find(e=>e.physical.wall===w.physical.wall&&close(e.physical.start,w.physical.start)&&close(e.physical.end,w.physical.end));return e&&w.drawing.source==='runtime_export'&&close(w.drawing.sill,e.drawing.sill??e.drawing.sill_height_m)&&close(w.drawing.opening,e.drawing.opening??e.drawing.opening_height_m)&&w.drawing.mode===e.drawing.mode}),'window drawing follows the shared runtime display specification '+r.id);
  check(same(r.room_png_geometry.x_basis_px,source.projection.x_basis_px.map(n=>n*2))&&same(r.room_png_geometry.depth_basis_px,source.projection.depth_basis_px.map(n=>n*2)),'template uses actual per-room projection '+r.id);
  check(r.material_prompt&&r.prompt.includes(r.material_prompt)&&r.prompt.includes(r.connection_text),'room prompt pairs per-room material with actual exported openings '+r.id);
  check(!r.prompt.includes('下一轮')&&!r.prompt.includes('构图建议'),'no obsolete editorial screen-layout proposal copied into actual template '+r.id);
  const shown=r.wall_display_segments;
  const environment=source.presentation?.environment,openAir=environment?environment==='outdoor'||environment.startsWith('open_air'):r.outdoor,nearCut=source.presentation?.near_cut_height_m??.85;
  check(openAir===r.outdoor,'drawing environment agrees with actual runtime presentation '+r.id);
  const contour=shared.pieces.some(p=>p.custom_faces),tops=shared.faces.filter(f=>f.side==='top').map(f=>f.points[0][1]);
  if(contour&&openAir){const allowed=[.14,source.space_spec?.hole_wall_height_m??.22,...(source.space_spec?.boundary_facades||[]).map(f=>f.height_m)];check(tops.some(h=>close(h,.14))&&tops.every(h=>allowed.some(v=>close(v,h))),'street contour uses low kerbs and only explicitly configured façade heights '+r.id)}
  else if(contour)check(tops.some(h=>h<=nearCut+1e-6)&&tops.every(h=>h<=r.wall.height_m+1e-6),'covered nonrectangular space has real cut surfaces without a forced rectangular shell '+r.id);
  else if(openAir)check([...shown.south,...shown.west].every(s=>Math.abs(s.height_m-.14)<1e-6),'open-air runtime near edges retain actual low kerbs '+r.id);
  else check(shown.south.every(s=>s.height_m<=nearCut+1e-6)&&shown.west.some(s=>s.height_m<=nearCut+1e-6)&&shown.west.some(s=>Math.abs(s.height_m-r.wall.height_m)<1e-6),'covered interior retains its actual solid cut and rear-left full-height segment '+r.id);
  const expectedProps=activeProps(source);check(r.props.length===expectedProps.length,'current independent object coverage '+r.id);
  for(const p of r.props){const f=expectedProps.find(f=>f.id===p.id);check(!!f&&same(p.position,f.rect.slice(0,2)),'furniture source placement preserved '+r.id+':'+p.id);check(!!p.shape_family&&!!p.construction&&p.prompt.includes(p.construction),'object-specific construction is copied with its actual locator '+r.id+':'+p.id)}
 }
 const result={passes,failures,scenes:data.length,props:data.reduce((n,r)=>n+r.props.length,0),scope:'Offline JavaScript DOM contract, actual exported geometry/projection and embedded file checks. This is not real-browser visual/download acceptance, game execution, final art or human playthrough.'};
 const dir=path.join(root,'docs/validation/spatial_presentation_20261019');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'template_page_check.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify({passes:passes.length,failures:failures.length,scenes:result.scenes,props:result.props}));process.exitCode=failures.length?1:0;
})().catch(e=>{console.error(e);process.exitCode=1});
