(function(){
'use strict';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const names=D=>Object.fromEntries(D.items.map(a=>[a.id,a.name]));
function phasePart(a,c,i){return (a.parts||[]).find(p=>p.clip===c.key&&p.pose_index===i)}
function availablePhases(a,c,optional=false){
 return (c.play_order||c.poses.map((_,i)=>i)).filter(i=>c.poses[i]&&(!c.poses[i].optional||optional)&&!c.poses[i].codex_first&&!['accepted','user_supplied'].includes(phasePart(a,c,i)?.status));
}
function requiredRefs(D,a){
 const ns=names(D);let refs=[];
 if(a.category==='UI与功能界面')return a.upload||'只附本界面实际内容与状态截图、已认可的界面基准；原型只负责信息和功能，不沿用旧的粗糙样式。';
 if(a.category==='场景')return a.upload;
 if(a.category==='动作')return '必附下方选定衣装／形态的已确认母图。'+(a.clips?.some(c=>c.poses.some(p=>p.guide_media))?'再附下方当前姿态参照（可下载PNG），它只锁动作。':'已有合格相邻关键图时才附，保持手位与持物连续。')+' 接触相位只加当前一个对象的操作面局部，不上传全部候选。';
 if(a.mother)refs.push('必附：'+(ns[a.mother]||a.mother)+'的当前确认版本，仅锁身份、衣装与画法。');
 for(const r of a.refs||[])if(r.id!==a.mother&&r.required)refs.push('必附：'+(r.name||ns[r.id]||r.id)+'，用途：'+r.role+'。');
 if(a.category==='家具与物品')refs.push(a.upload||'有已确认安装处时，仅附局部核机位、大小、操作面。');
 else if(a.upload&&!a.mother)refs.push(a.upload);
 if(!refs.length)refs.push('首次建立此主体：附一张同类别已认可画法参考。已有同主体候选只用于身份核对，不把错误姿态和背景一并继承。');
 if(a.category==='动作')refs.push(a.clips?.some(c=>c.poses.some(p=>p.guide_media))?'另附下方当前姿态参照（可下载PNG）；接触时只加当前一个对象的局部。':'已有合格相邻关键图时才附；接触时只加当前一个对象的局部，不上传全部候选。');
 return refs.join('\n');
}
function makePrompt(D,a,o={}){
 const ns=names(D);let out=[];
 if(a.category==='场景')return a.content;
 if(a.category==='UI与功能界面')return a.prompt||a.content;
 if(a.category==='通用效果与接入')return [a.prompt||a.content,a.note,'复用来源：'+(a.reuse||[]).join('、'),'验收：'+(a.checks||[]).join('；'),'由Codex加工／接入；只有明确局部缺图才补图，不因存在占位效果就下整套人工序列订单。'].filter(Boolean).join('\n');
 if(o.clip&&o.pose){
  const c=o.clip,p=o.pose,m=ns[o.mother||a.mother]||o.mother||a.mother||'本次角色';
  out.push('编辑所附同一角色，制作《NEURONS》“'+a.name+'／'+c.label+'”中的一个明确瞬间：'+p.label+'。');
  out.push('图1是“'+m+'”的已确认母图，只锁定身份、脸型、发型、当次衣装、身体比例与绘画语言，不锁住母图静态站姿。'+(p.guide_media?'图2是下方已提供的本方向骨架姿态参照，规定本张关节与承重，不借它的线条画法。':'已有合格相邻关键图时另附，沿它的持物手和接触关系；无相邻图时按下面一个明确姿态制作。')+'已有合格起始图时沿其机位、画布与尺度。');
  if(a.direction)out.push('观看方向沿实际游戏的本方向定位参照；'+a.direction+'仅为界面简称，不能用完全不同的正面／侧面镜头替换。左右手脚均指角色自身。');
  out.push('本张具体姿态：'+p.text);
  if(o.target)out.push('另附当前唯一接触对象“'+(ns[o.target]||o.target)+'”的操作面／支撑处局部，校准接触高度和大小。人物、活动道具与另一角色仍可分层，不合成永久连体主体。');
  out.push('上下文：'+c.action+' 本次只画所选瞬间，不把整段动作叠成一张，也不在画布内横移整个人冒充行走。');
  out.push(c.support||a.support||'保持真实地面／座面／床面支撑，不逐张独立放大缩小。');
  if(c.key==='walk')out.push('脚下根基准与身体比例固定；支撑脚相对身体向后运动，另一脚向前摆，骨盆和头允许自然小幅起伏。对侧摆臂，真正交换承重；不镜像整张人物、不把两脚同时钉在地上。母图不负责决定步态。');
  out.push(a.note||'',D.char_style,'沿已核画布留足全身、手脚与活动范围；使用透明背景；若工具不能稳定输出透明，改用单一浅暖灰纯底，禁止画内棋盘格。柔和一致面光，无房间、文字、箭头、网格、速度残影、外扩光晕或大投影。');
  return out.filter(Boolean).join('\n\n');
 }
 if(a.mother)out.push('附图中的“'+(ns[a.mother]||a.mother)+'”负责同一身份、脸型、发型、身体结构与衣装来源。本项只改变下面明确要求的视图、表情或状态，不沿用未认可的伤口、畸形或错误道具。');
 if(o.task)out.push('本次只做“'+o.task.name+'”这一张：'+o.task.text+'。不合成多视图或多表情网格。');
 else if(a.category==='家具与物品'&&o.placement?.match_kind==='family_variant')out.push('本次绘制“'+o.placement.name+'”，用于“'+o.placement.room_title+'”。'+o.placement.generation_note+' 这是既有同族资源的本处派生，不照抄其他场景的名称、用途和外壳。');
 else out.push(a.content);
 if(a.category==='家具与物品'){
  const construction=o.placement?.construction||a.construction;if(construction)out.push('本物件的真实构造：'+construction);
  if(o.placement){const f=o.placement;out.push('安装处：'+f.room_title+'／'+f.name+'。可容纳范围参考：'+f.size.join('×')+'米（长、深、高），操作面：'+f.operation_face_text+'。只保持实际落脚、接触高度、可见侧和操作留空；圆面、弧面、薄板、支腿、孔洞与缝隙按本物构造，不能为了填满长深高而画成方盒。结构参照的线条与纯色不是最终外观。')}
  out.push('独立绘制完整物件。只从已认可场景局部参考机位、主色、面光和操作面；环境雾、窗光光束、外扩光晕、大片地面投影与交互高亮由游戏另加。活动门扇／抽屉／可取物按需要可拆，移开后内侧与背景完整。主体外用透明底，工具不支持时使用均匀浅暖灰底。',D.prop_style);
 }else if(a.category==='开场与结局'){
  let canvas='独立叙事横幅16:9，保留高分辨率原画。';
  if(a.id==='ENDING_HOST_EYES')canvas='本次仅一张眼部局部，1:1，可从1024×1024起试；闭眼／刚睁眼沿同一裁切、机位和光源，不合并成对照拼图。';
  if(a.id.startsWith('UI_EVIDENCE_')||a.id==='UI_RECORD_34')canvas='照片内容按4:3，可从1280×960起试；照片边框和可变文字另层，不擅自生成名单／案件数字。';
  if(a.id==='UI_REHAB_WORK_ART')canvas='沿已确认作品的实际长宽比，不强行裁成统一横幅。';
  if(['ENDING_HOST_BODY_REFERENCE','ENV_EVENT_BODY_UNKNOWN'].includes(a.id))canvas='完整人物独立层，背景透明或单一浅暖灰。沿实际躺卧姿态扩画布，不把站姿横转，不连床与设备一起烘焙。';
  out.push(D.story_style,'这是本事件的独立叙事画面，机位服务剧情，不套探索房间斜俯视。不新增来源不明的剧情符号或可读文字。字幕、UI、可变内容另层。',canvas);
 }else{
  out.push(D.char_style,a.canvas||'保持母图比例；站姿可从1024×1280起试，坐卧／四足按展开身体扩画布，不把主体压扁。','场内主体沿确认使用处的斜侧观看高度；完整保留头、手、脚、尾部及实际支点。透明底，工具不支持时用均匀浅暖灰底，无环境、画内棋盘格、外扩光晕或大投影。');
 }
 if(a.note)out.push(a.note);
 return out.filter(Boolean).join('\n\n');
}
function flattenProgress(raw){
 const result={};
 function visit(v){
  if(!v||typeof v!=='object')return;
  if(Array.isArray(v)){for(const p of v){if(p&&p.id)result[p.id]={...(result[p.id]||{}),...p};else visit(p)};return}
  if(v.id&&(v.status||v.notes||v.file)){result[v.id]={...(result[v.id]||{}),...v};return}
  for(const[k,p]of Object.entries(v)){
   if(p&&typeof p==='object'&&!Array.isArray(p)&&(p.status||p.notes||p.file)&&!/^(form_progress|art|audio|initial|source_progress)$/.test(k))result[k]={...(result[k]||{}),...p};
   else if(['form_progress','art','audio','initial','source_progress','source_progress_files','desktop','progress','user_progress'].includes(k)||Array.isArray(p))visit(p);
  }
 }
 visit(raw);return result;
}
function selectItems(D,f){
 return D.items.filter(a=>(!f.category||a.category===f.category)&&(!f.group||a.group===f.group)&&(!f.owner||(a.current_owner||a.role)===f.owner)&&(!f.status||(f.status==='needs'?!['accepted','user_supplied','deferred'].includes(a.review_status)&&!(D.ui_generation&&a.category==='UI与功能界面'&&a.generation_mode!=='generate'):a.review_status===f.status))&&(!f.query||[a.id,a.name,a.group,a.scope,a.content,...(a.existing||[]).map(x=>x.filename)].join(' ').toLowerCase().includes(f.query.toLowerCase())));
}
if(typeof module!=='undefined'&&module.exports)module.exports={makePrompt,availablePhases,requiredRefs,flattenProgress,selectItems};
if(typeof document==='undefined')return;
const D=JSON.parse(document.getElementById('form-data').textContent),$=id=>document.getElementById(id),ns=names(D),STORAGE='NEURONS_COMPREHENSIVE_ART_PROGRESS_V4';
for(const id of['stats','category','status','stylelinks','stylepreviews'])$(id).replaceChildren();
let state={...flattenProgress(D.initial),...flattenProgress(D.source_progress),...flattenProgress(D.source_progress_files),...(D.user_progress||{})};
try{state={...state,...JSON.parse(localStorage.getItem(STORAGE)||'{}')}}catch{}
let toastTimer;
function toast(s){$('toast').textContent=s;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,2400)}
function persist(){try{localStorage.setItem(STORAGE,JSON.stringify(state))}catch{toast('浏览器未保存进度，请导出进度文件。')}}
async function copy(s){try{await navigator.clipboard.writeText(s);toast('已复制')}catch{const t=document.createElement('textarea');t.value=s;document.body.append(t);t.select();const ok=document.execCommand('copy');t.remove();toast(ok?'已复制':'请选中提示词手动复制')}}
function saveBlob(blob,name){const u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(u),2000)}
function downloadMedia(key){const m=D.media[key];if(!m)return;if(m.kind==='pose'){const im=new Image();im.onload=()=>{const c=document.createElement('canvas');c.width=im.naturalWidth;c.height=im.naturalHeight;c.getContext('2d').drawImage(im,0,0);c.toBlob(b=>saveBlob(b,m.filename.replace(/\.svg$/,'.png')),'image/png')};im.src=m.url;return}const a=document.createElement('a');a.href=m.url;a.download=m.filename;a.click()}
function element(tag,cls,text){const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n}
function paragraph(host,text,cls){if(text)host.append(element('p',cls,text))}
function btn(host,label,fn,cls){const n=element('button',cls,label);n.type='button';n.onclick=fn;host.append(n);return n}
function details(host,label,fn){const d=element('details','inner'),s=element('summary',null,label),b=element('div');d.append(s,b);let built=false;d.addEventListener('toggle',()=>{if(d.open&&!built){built=true;fn(b)}});host.append(d);return d}
function imageFigure(host,key,label,note){const m=D.media[key];if(!m)return;const fig=element('div','figure'+(['template','pose','ui_guide'].includes(m.kind)?' template':'')),img=element('img');img.src=m.url;img.alt=label;img.loading='lazy';fig.append(element('h3',null,label),img);paragraph(fig,note,'meta');paragraph(fig,m.source_filename,'file');btn(fig,m.kind==='ui_guide'?'下载本项功能分区PNG':m.kind==='template'?'下载本模板PNG':m.kind==='pose'?'下载当前姿态参照PNG':'下载本张参考PNG',()=>downloadMedia(key));host.append(fig)}
function previewExisting(a,host){
 if(!a.existing?.length)return;
 details(host,'已有素材与本轮审查（'+a.existing.length+'份）',box=>{
  const grid=element('div','preview-grid');box.append(grid);
  for(const f of a.existing){const fig=element('div','figure');grid.append(fig);paragraph(fig,D.labels[f.status]||f.status,'badge '+f.status);if(f.media){const m=D.media[f.media],im=element('img');im.src=m.url;im.loading='lazy';im.alt=f.filename;fig.append(im)}paragraph(fig,f.filename,'file');paragraph(fig,f.note);paragraph(fig,f.path,'file');btn(fig,'复制原图位置',()=>copy(f.path));}
 });
}
function showParts(a,host){
 if(!a.parts?.length)return;
 const pending=a.parts.filter(p=>!['accepted','user_supplied'].includes(p.status)&&!p.optional),done=a.parts.filter(p=>['accepted','user_supplied'].includes(p.status));
 const short=p=>p.label.split(' · ').at(-1);
 if(done.length)paragraph(host,'已补充／已有可用：'+done.map(short).join('；')+'。这些部分无需重新生成。','existing-note');
 if(pending.length&&done.length)paragraph(host,'尚需处理：'+pending.map(short).join('；')+'。下方只对剩余部分出提示词。','warn');
 if(a.parts.length>1)details(host,'各部件／相位的状态',box=>{const table=element('table','parts');table.innerHTML='<thead><tr><th>部件／姿态</th><th>审查</th><th>文件</th></tr></thead>';const body=element('tbody');for(const p of a.parts){const tr=element('tr');for(const s of[p.label+(p.optional?'（按需过渡）':''),D.labels[p.status]||p.status,p.filename])tr.append(element('td',null,s));body.append(tr)}table.append(body);box.append(table)});
}
function progress(a,host){
 const box=element('div','progress'),line=element('div','selectline'),st=element('select'),file=element('input'),notes=element('textarea'),p=state[a.id]||{};
 st.setAttribute('aria-label','我的制作进度');for(const s of['未开始','已有候选','部分已补充','已交付待验','需局部修改','需重新生成','已确认']){const op=element('option',null,s);op.value=s;st.append(op)}
 if(p.status&&!Array.from(st.options).some(o=>o.value===p.status)){const op=element('option',null,p.status);op.value=p.status;st.append(op)}
 const initialStatus={accepted:'已确认',user_supplied:'已确认',partial:'部分已补充',candidate:'已有候选',edit:'需局部修改',redo:'需重新生成'}[a.review_status]||'未开始';
 st.value=p.status||initialStatus;file.value=p.file||(a.existing?.[0]?.filename||'');file.placeholder='当前文件／交付位置';file.setAttribute('aria-label','当前文件');notes.value=p.notes||'';notes.placeholder='补充备注；这里的制作进度不覆盖上方实图审查结论';notes.setAttribute('aria-label','制作备注');line.append(element('span',null,'我的进度'),st,file);box.append(line,notes);for(const n of[st,file,notes])n.onchange=()=>{state[a.id]={...p,status:st.value,file:file.value,notes:notes.value};persist()};host.append(box);
}
function promptBox(host,getText,getFile,disabled=false){
 const t=element('textarea','prompt');t.readOnly=true;t.setAttribute('aria-label','可复制完整提示词');t.value=getText();host.append(t);const bar=element('div','actions');host.append(bar);const b=btn(bar,'复制本次完整提示词',()=>copy(t.value),'primary');b.disabled=disabled;if(getFile)btn(bar,'复制本次文件名',()=>copy(getFile()));return{t,b,update:()=>{t.value=getText()}};
}
function renderAction(a,host){
 paragraph(host,a.clips.some(c=>c.poses.some(p=>p.guide_media))?'操作：选尚缺姿态 → 下载下方姿态参照 → 与本次母图一起上传 → 复制提示词。先连播核对，再按需补过渡。':'操作：选尚缺姿态，附本次母图；已有相邻关键图才加，接触时加一个对象局部。复制本张提示词，成图后连播核对。','note');
 const line=element('div','selectline'),ms=element('select'),cs=element('select'),ps=element('select'),ts=element('select'),opt=element('input');opt.type='checkbox';ms.setAttribute('aria-label','动作母图');cs.setAttribute('aria-label','动作片段');ps.setAttribute('aria-label','当前姿态');ts.setAttribute('aria-label','当前唯一接触对象');
 const mothers=a.mother_choices?.length?a.mother_choices:[a.mother||a.id];for(const id of mothers){const op=element('option',null,ns[id]||id);op.value=id;ms.append(op)}
 for(let i=0;i<a.clips.length;i++){const op=element('option',null,a.clips[i].label);op.value=i;cs.append(op)}
 for(const [s,label]of[[ms,'本次母图'],[cs,'动作'],[ps,'本张姿态']]){const l=element('label',null,label);l.append(s);line.append(l)}host.append(line);
 const sub=element('div','selectline'),l=element('label',null,'显示按需过渡');l.prepend(opt);sub.append(l);
 const no=element('option',null,'无／本相位不接触对象');no.value='';ts.append(no);for(const id of a.target_choices||[]){const op=element('option',null,ns[id]||id);op.value=id;ts.append(op)}if((a.target_choices||[]).length){const q=element('label',null,'接触对象');q.append(ts);sub.append(q)}host.append(sub);
 const guide=element('p','meta'),blocked=element('p','warn'),guideBox=element('div');host.append(guide,blocked,guideBox);let c,p,pi=0;
 const ui=promptBox(host,()=>p?makePrompt(D,a,{clip:c,pose:p,mother:ms.value,target:ts.value}):'本动作的当前必需姿态已有可用；若连续预览发现缺少过渡，再勾选“显示按需过渡”。',()=>p?newPoseName(p.filename):a.new_filename);
 function update(){c=a.clips[+cs.value];pi=+ps.value;p=c.poses[pi];const mother=D.items.find(x=>x.id===ms.value),needMother=mother&&a.id.includes('ALTERED')&&['edit','redo','blocked'].includes(mother.review_status)&&state[mother.id]?.status!=='已确认';blocked.hidden=!needMother;blocked.textContent=needMother?'先修正并确认本形态母图，再制作它的动作；不能把当前待改的畸形结构继续锁进序列。':'';ui.b.disabled=!!a.blocked||needMother||!p;guide.textContent=(c.key==='walk'?'核心循环：左接触 → 左支撑经过 → 右接触 → 右支撑经过。下沉／蹬地只按连播缺口补；编号不等于播放顺序。 ':c.guide||'')+(c.method==='Codex分层变形'?'此动作先由Codex沿合格基姿做轻动，不默认补一整套图。':'');guideBox.replaceChildren();if(p?.guide_media)details(guideBox,'下载本张姿态参照（只锁动作）',b=>imageFigure(b,p.guide_media,p.label,'上传此参照与同角色母图；它只规定支撑、左右侧和动作相位，不是新人物造型。'));ui.update()}
 function phases(){const c=a.clips[+cs.value],ids=availablePhases(a,c,opt.checked);ps.replaceChildren();for(const i of ids){const part=phasePart(a,c,i),op=element('option',null,c.poses[i].label+(c.poses[i].optional?'（按需）':'')+(part?.status==='edit'?'（局改）':''));op.value=i;ps.append(op)}if(!ids.length){const op=element('option',null,'本片段必需姿态已有');op.value='-1';ps.append(op)}update()}
 cs.onchange=phases;opt.onchange=phases;ms.onchange=update;ps.onchange=update;ts.onchange=update;phases();
}
function newPoseName(filename){return filename.replace(/_v(\d+)(?=\.)/,(_,n)=>'_v'+String(+n+1).padStart(3,'0'))}
function renderProp(a,host){
 let placement;const items=a.placements||[];
 paragraph(host,a.placement_note,'meta');
 for(const c of a.placement_context||[])details(host,'本处只作上下文参考：'+c.room_title,b=>{paragraph(b,c.reason,'warn');imageFigure(b,c.media,c.room_title+' · 位置上下文','只看本物件的容纳／安装处；不把图中家具的尺寸作为本物体尺寸。')});
 if(items.length){const line=element('div','selectline'),sel=element('select');sel.setAttribute('aria-label','本物件实际安装处');for(let i=0;i<items.length;i++){const f=items[i],op=element('option',null,f.room_title+'／'+f.name+' · '+f.size.join('×')+'m');op.value=i;sel.append(op)}line.append(element('span',null,'本次使用处'),sel);host.append(line);const box=element('div');host.append(box);const pui=promptBox(host,()=>makePrompt(D,a,{placement}),()=>a.new_filename,!!a.blocked);
  function update(){placement=items[+sel.value];box.replaceChildren();if(placement.generation_note)paragraph(box,placement.generation_note,'note');if(placement.construction)paragraph(box,placement.construction,'note');details(box,'下载本物体结构与尺度参照',b=>imageFigure(b,placement.media,placement.name+' · 结构参照','结构示意显示圆面、腿架和透空；尺寸只限容纳范围、支点与操作处，不要求填满长方体，也不沿用示意线条与纯色。'));pui.update()}sel.onchange=update;update();
 }else promptBox(host,()=>makePrompt(D,a),()=>a.new_filename,!!a.blocked);
}
function renderScene(a,host){
 const s=D.spaces[a.runtime_id];
 if(s){paragraph(host,'本房外围范围：'+s.size.map(v=>Number(v.toFixed(2))).join('×')+'m，具体形状按下图，不代表矩形地面。'+(s.shape_description||'')+' 门路、沟井与设施留位按本房定位。','note');details(host,'本房唯一空间定位图／物品摆位图',box=>{imageFigure(box,s.space_media,'图2 · 本房建筑与机位定位','与上方规定的图1一起上传；保持真实多边形／曲线边界、沟井、通路和机位。图1只借画法，不把每房变成卧室方盒。');if(s.placement_media)imageFigure(box,s.placement_media,'本房家具留位核对 · 不上传生成','用于检查通路和家具位置；家具独立生成时只取其当前安装处，不将整套家具烘焙进建筑底图。')});}
 promptBox(host,()=>makePrompt(D,a),()=>a.new_filename,!!a.blocked);
 if(a.conflict_note)paragraph(host,a.conflict_note,'warn');
 if(s?.furniture?.length)details(host,'本房家具规格（'+s.furniture.length+'处）',box=>{for(const f of s.furniture)details(box,f.name+' · '+f.size.join('×')+'m · '+f.operation_face_text,b=>imageFigure(b,f.media,f.name,'本处独立体积参照；物品造型按对应条目。'))});
}
function renderUI(a,host){
 paragraph(host,a.delivery_brief,'note');
 if(a.reuse_from?.length){const bar=element('div','actions');host.append(bar);for(const id of a.reuse_from){const source=D.items.find(x=>x.id===id);btn(bar,'查看复用：'+(source?.name||id),()=>{$('status').value='';$('category').value='';$('search').value=id;groups();render()})}}
 if(a.reuse_media?.length)details(host,'已有可用来源（不重新生成）',box=>{const grid=element('div','preview-grid');box.append(grid);for(const r of a.reuse_media)imageFigure(grid,r.media,r.label,r.note)});
 if(a.generation_mode==='generate'){
  paragraph(host,'上传：'+requiredRefs(D,a));
  const refs=element('div','preview-grid');host.append(refs);for(const r of a.required_media||[])imageFigure(refs,r.media,r.label,r.note);
  if(a.variants?.length){const sel=element('select');sel.setAttribute('aria-label','本次仅生成一个图标');for(let i=0;i<a.variants.length;i++)sel.append(new Option(a.variants[i].name,i));host.append(sel);const p=promptBox(host,()=>a.variants[+sel.value].prompt,()=>a.variants[+sel.value].filename);sel.onchange=p.update}
  else promptBox(host,()=>makePrompt(D,a),()=>a.new_filename);
  paragraph(host,'图层与透明：'+a.alpha_contract,'meta');paragraph(host,'切片／留空：'+a.slice_contract,'meta');
 }else paragraph(host,a.generation_mode==='reuse'?'本项不重复生成图片；使用上方既有来源，按下面状态接入。':'本项不交出图工具；由程序完成真实文字、点击、状态与动效。','existing-note');
 paragraph(host,'程序负责：'+a.program_contract,'meta');
 if(a.states?.length)paragraph(host,'需保留状态：'+a.states.join('／'));
 if(a.checks?.length)details(host,'验收重点',box=>{for(const c of a.checks)paragraph(box,'• '+c)});
 progress(a,host);
}
function renderItem(a,host){
 paragraph(host,a.id+' · '+(a.scope||a.group||''),'meta');
 if(a.new_candidates_note)paragraph(host,a.new_candidates_note,'warn');
 if(a.review_status==='accepted')paragraph(host,'已有可用：本轮认可的具体版本保留，无需重复生成。剩余去底、画布、尺度、锚点与接入由Codex处理。','existing-note');
 if(a.review_status==='user_supplied')paragraph(host,'用户已修订可用：按用户确认保留当前命名版本，不再评估或重复生成。Codex只处理透明、比例、锚点、拆层与游戏导入。','existing-note');
 if(a.review_status==='redo')paragraph(host,'已有文件，但本部分需重生；同角色已通过的正常形态／背面继续使用。','warn');
 if(a.pending)paragraph(host,a.pending,'warn');
 if(a.note)paragraph(host,a.note,'meta');
 showParts(a,host);previewExisting(a,host);
 if(a.category==='UI与功能界面'&&D.ui_generation){renderUI(a,host);return}
 if(!['accepted','user_supplied'].includes(a.review_status)){
  if((a.current_owner||a.role)==='codex')paragraph(host,'当前责任：Codex生产、加工与接入，不要求你逐帧制作。','note');
  if(a.role==='conditional')paragraph(host,'按需补图：先由Codex复用、分层并连续预览；下方提示词只用于确认仍缺的姿态或局部，不要求把全部选项重新生成一遍。','note');
  paragraph(host,'附图：'+requiredRefs(D,a));
  if(a.clips?.length)renderAction(a,host);
  else if(a.category==='场景')renderScene(a,host);
  else if(a.category==='家具与物品')renderProp(a,host);
  else if(a.tasks?.length){const remaining=a.tasks.filter(t=>!['accepted','user_supplied'].includes(a.parts.find(p=>p.key===t.key)?.status));if(remaining.length){const line=element('div','selectline'),sel=element('select');sel.setAttribute('aria-label','本次剩余部件');for(let i=0;i<remaining.length;i++){const op=element('option',null,remaining[i].name);op.value=i;sel.append(op)}line.append(sel);host.append(line);const pui=promptBox(host,()=>makePrompt(D,a,{task:remaining[+sel.value]}),()=>newPoseName(remaining[+sel.value].filename),!!a.blocked);sel.onchange=pui.update}else paragraph(host,'各子图已有可用，不重复生成。','existing-note')}
  else promptBox(host,()=>makePrompt(D,a),()=>a.new_filename,!!a.blocked||a.review_status==='deferred');
 }
 if(a.states?.length)paragraph(host,'状态：'+a.states.join('／'));
 if(a.parts_to_make?.length)paragraph(host,'交付部件：'+a.parts_to_make.join('；'));
 if(a.checks?.length)details(host,'只核这些验收点',box=>{const ul=element('ul','checklist');for(const c of a.checks)ul.append(element('li',null,c));box.append(ul)});
 progress(a,host);
}
function getFilters(){return{category:$('category').value,group:$('group').value,status:$('status').value,owner:$('owner').value,query:$('search').value.trim()}}
function groups(){const gs=[...new Set(D.items.filter(a=>!$('category').value||a.category===$('category').value).map(a=>a.group))];$('group').replaceChildren(new Option('全部分组',''),...gs.map(g=>new Option(g,g)))}
function render(){const f=getFilters(),list=selectItems(D,f);$('items').replaceChildren();$('count').textContent=list.length+' / '+D.items.length+'项';const frag=document.createDocumentFragment();for(const a of list){const ar=element('article'),d=element('details'),s=element('summary'),body=element('div','panel');s.append(document.createTextNode(a.name),element('span','badge '+a.review_status,a.ui_delivery_label||D.labels[a.review_status]||a.review_status));d.append(s,body);let done=false;d.addEventListener('toggle',()=>{if(d.open&&!done){done=true;renderItem(a,body)}});ar.append(d);frag.append(ar)}$('items').append(frag);if(!list.length)$('items').append(element('p','empty','当前筛选没有条目；可切换状态或点击“查看完整清单”。'));$('context').replaceChildren();if(f.category==='动作')paragraph($('context'),'先用一个方向核通动作，再扩展其他方向。已有关键姿态不重画；灰底图仍需去底和连续预览。','note');if(f.category==='UI与功能界面')paragraph($('context'),D.ui_generation?'先复制 UI 首次说明，再展开本次需要生成的图层。默认只列新图订单；“查看完整清单”显示全部38项功能及复用安排。文字、数值、点击与动画由程序实现。':'这里制作真实界面的设计、复用部件和交互状态。文字、数字和按钮保持程序排版，整页效果图只作设计参照。','note')}
$('version').textContent=' '+D.version;
for(const [value,label]of[['','全部类别'],...['场景','人物母图','动作','家具与物品','开场与结局','UI与功能界面','通用效果与接入'].filter(c=>D.items.some(a=>a.category===c)).map(c=>[c,c])])$('category').append(new Option(label,value));
for(const[v,l]of[['needs','需要处理（含部分已有）'],['','全部状态'],...Object.entries(D.labels)])$('status').append(new Option(l,v));
$('status').value='needs';if(D.ui_only)$('category').value='UI与功能界面';
const total=D.items.length,has=D.items.filter(a=>a.existing?.length).length,usable=D.items.filter(a=>a.review_status==='accepted').length,partial=D.items.filter(a=>a.review_status==='partial').length;
for(const[n,l]of[[total,'资产条目'],[has,'已有文件的条目'],[usable,'已有可用'],[partial,'部分已有可用']]){const s=element('span','stat');s.append(element('b',null,n),document.createTextNode(l));$('stats').append(s)}
$('firsttext').value=D.ui_only?D.ui_first:D.first;$('first-copy').onclick=()=>{const s=D.ui_only?D.ui_first:D.first;$('firsttext').value=s;copy(s)};$('scene-first-copy').onclick=()=>{$('firsttext').value=D.scene_first;copy(D.scene_first)};$('ui-first-copy').onclick=()=>{$('firsttext').value=D.ui_first;copy(D.ui_first)};
if(D.ui_only){$('first-copy').textContent='复制 UI 首次说明';$('scene-first-copy').hidden=true;$('ui-first-copy').hidden=true}
for(const g of D.style_links||[]){const p=element('p','meta');p.append(document.createTextNode(g.section+'：'));for(const l of g.links){const a=element('a',null,l.name);a.href=l.url;a.target='_blank';a.rel='noopener';p.append(a,document.createTextNode('　'))}p.append(document.createTextNode('取用：'+g.take));$('stylelinks').append(p)}
let stylesBuilt=false;document.querySelector('details.first').addEventListener('toggle',e=>{if(e.currentTarget.open&&!stylesBuilt){stylesBuilt=true;for(const s of D.styles)imageFigure($('stylepreviews'),s.media,s.name,s.note)}});
$('category').onchange=()=>{groups();render()};for(const id of['group','status','owner'])$(id).onchange=render;$('search').oninput=render;
$('all').onclick=()=>{$('status').value='';$('category').value=D.ui_only?'UI与功能界面':'';$('owner').value='';$('search').value='';groups();render()};
$('export').onclick=()=>saveBlob(new Blob([JSON.stringify({schema_version:4,kind:'NEURONS_COMPREHENSIVE_PROGRESS',form_progress:state,source_progress:D.source_progress,source_progress_files:D.source_progress_files},null,2)],{type:'application/json'}),'NEURONS_完整美术进度.json');
$('filled').onclick=()=>{const doc=document.documentElement.cloneNode(true),payload={...D,user_progress:state};doc.querySelector('#form-data').textContent=JSON.stringify(payload).replace(/</g,'\\u003c');doc.querySelector('#items').replaceChildren();doc.querySelector('#stylepreviews').replaceChildren();doc.querySelector('#toast').hidden=true;saveBlob(new Blob(['<!doctype html>'+doc.outerHTML],{type:'text/html;charset=utf-8'}),D.ui_only?'NEURONS_UI表_填写版.html':'NEURONS_完整美术表_填写版.html')};
$('import').onclick=()=>$('importfile').click();$('importfile').onchange=async e=>{try{const raw=JSON.parse(await e.target.files[0].text()),v=flattenProgress(raw);state={...state,...v};D.source_progress_files.imported=raw;persist();render();toast('已导入'+Object.keys(v).length+'项进度；审查状态保留')}catch{toast('进度文件无法读取，原进度保留')}e.target.value=''};
window.NEURONS_FORM={D,getState:()=>state,selectItems,makePrompt,render,getFilters,renderItem,flattenProgress};groups();render();
})();
