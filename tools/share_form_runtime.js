/* Inlined into the two existing forms. No server, storage or network dependency. */
const shareRefs=JSON.parse(document.getElementById('share-references').textContent);
const embeddedProgress=JSON.parse(document.getElementById('progress-seed').textContent);
const referenceUrls=new Map();
const itemGroups=new Map(DATA.groups.flatMap(g=>g.items.map(i=>[i.id,g])));
const originalItemHtml=itemHtml,originalPrompt=completePrompt;
const validRow=v=>v&&typeof v==='object'&&!Array.isArray(v);
function parsedProgress(d){
 if(!validRow(d))throw Error('请选择进度JSON对象，原填写保持不变');
 const result={art:{},audio:{}};
 if(d.form==='NEURONS_NEW_20261015'){
  if(!['art','audio'].includes(d.kind)||!validRow(d.progress))throw Error('旧简表进度格式不完整');
  Object.assign(result[d.kind],d.progress);
 }else if(d.art||d.audio||d.form_progress){
  for(const k of ['art','audio']){
   if(d[k]!=null&&!Array.isArray(d[k])&&!validRow(d[k]))throw Error('进度列表格式错误');
   for(const row of list(d[k]))if(validRow(row)&&typeof row.id==='string'&&row.id)result[k][row.id]=convert(row);
   if(d.form_progress?.[k]!=null&&!validRow(d.form_progress[k]))throw Error('进度分组格式错误');
   for(const [id,row] of Object.entries(d.form_progress?.[k]||{})){
    if(!id||!validRow(row))throw Error('进度条目格式错误');
    result[k][id]={...result[k][id],...row};
   }
  }
 }else throw Error('这不是两份表兼容的进度JSON');
 for(const k of ['art','audio'])for(const [id,row] of Object.entries(result[k])){
  if(['__proto__','constructor','prototype'].includes(id)||!validRow(row))throw Error('进度条目格式错误');
  if(row.done!=null&&typeof row.done!=='boolean')throw Error('完成状态须为勾选状态');
 }
 return result;
}
function combineRows(a={},b={}){
 const result={...a,...b};
 if(a.legacy||b.legacy)result.legacy={...(a.legacy||{}),...(b.legacy||{})};
 return result;
}
function sourceForms(){
 let result={art:{},audio:{}};
 if(DATA.source_progress&&(DATA.source_progress.art||DATA.source_progress.audio||DATA.source_progress.form_progress))result=parsedProgress(DATA.source_progress);
 for(const [id,row] of Object.entries(DATA.initial||{}))result[DATA.kind][id]=combineRows(result[DATA.kind][id],convert(row));
 if(embeddedProgress.kind==='progress'){
  const saved=parsedProgress(embeddedProgress);
  for(const k of ['art','audio'])for(const [id,row] of Object.entries(saved[k]))result[k][id]=combineRows(result[k][id],row);
 }
 return result;
}
forms=sourceForms();progress=forms[DATA.kind];
carry=mergeCarry(DATA.source_progress||{},embeddedProgress);
function inheritAliases(){for(const i of allItems){if(progress[i.id])continue;const row=(i.source_ids||[]).map(id=>progress[id]).find(Boolean);if(row)progress[i.id]={done:false,note:row.note||'',legacy:row.legacy,inherited:true};}}
inheritAliases();
pathUrl=function(path){
 if(!shareRefs[path])return '#source-records';
 if(!referenceUrls.has(path)){
  const item=shareRefs[path],binary=atob(item.base64),bytes=new Uint8Array(binary.length);
  for(let n=0;n<binary.length;n++)bytes[n]=binary.charCodeAt(n);
  referenceUrls.set(path,URL.createObjectURL(new Blob([bytes],{type:item.mime})));
 }
 return referenceUrls.get(path);
};
function refLink(path,label){return shareRefs[path]?`<a href="${esc(pathUrl(path))}" download="${esc(path.split('/').pop())}">${esc(label)}（图片已内嵌，可另存上传）</a>`:`<span class="source-record">来源记录：${esc(path)}（未随本页附图）</span>`;}
function roomContract(g){
 const c=g.share_layout;if(!c)return '';
 return `<details class="guide"><summary>本房比例草稿与分层要求（尚未验收）</summary><p>${esc(c.status)}</p>${Object.entries(c.fields).map(([key,value])=>`<p><strong>${esc(key)}：</strong>${esc(value)}</p>`).join('')}</details>`;
}
completePrompt=function(item){
 let text=originalPrompt(item);const group=itemGroups.get(item.id);
 if(DATA.kind==='art'&&group?.share_layout&&item.spec_id==='WORLD'){
  const c=group.share_layout;
  text+='\n\n本轮仅作比例草稿，暂不批量制作正式场景。起测参数不是定稿：\n'+Object.entries(c.fields).filter(([k])=>!['接近点与通路','来源'].includes(k)).map(([k,v])=>k+'：'+v).join('\n');
 }
 return text;
};
itemHtml=function(i){
 let html=originalItemHtml(i);
 html=html.replace(/<li><a href="[^"]*">([^<]*)<\/a><\/li>/g,'<li><span class="source-record">来源记录：$1（不随此网页提供，不是可打开的参考附件）</span></li>');
 if(i.reference_file)html=html.replace(/<p><a href="[^"]*">[^<]*<\/a>（手动上传）<\/p>/,`<p>${refLink(i.reference_file,i.reference_label||'参考图片')}</p>`);
 const label=DATA.kind==='art'&&i.spec_id==='WORLD'?'比例草稿；空间验证后再定正式图':i.owner==='A'?'人工准备（候选不等于批准）':i.owner==='B'?'Codex负责':'依原约定';
 html=html.replace('<div class="row">',`<p class="note">制作入口：${esc(label)}</p>${roomContract(itemGroups.get(i.id)||{})}<div class="row">`);
 return html;
};
layoutHtml=function(g){const l=g.layout;if(!l)return '';return `<details class="guide"><summary>连接与参考（尺寸和局部摆位仍是建议）</summary><p>通往：${esc(l.destinations.join('；'))}</p><p>${esc(l.instruction)}</p><p>${esc(l.basis)} ${esc(l.position_status)}</p>${['original_guide','guide','legacy_guide'].filter(k=>l[k]).map(k=>`<p>${refLink(l[k],k==='original_guide'?'原稿连接参考':'旧连接说明，仅核拓扑')}</p>`).join('')}</details>`;};
exportData=function(){
 const out=mergeCarry({},carry);out.schema_version=4;out.kind='progress';out.updated=new Date().toISOString();
 out.form_progress={art:{...forms.art},audio:{...forms.audio}};
 for(const k of ['art','audio'])out[k]=Object.entries(forms[k]).map(([id,row])=>({...row.legacy,...row,id,notes:row.note??row.notes??''}));
 return out;
};
function conflictsFor(incoming){const conflicts=[];for(const k of ['art','audio'])for(const [id,row] of Object.entries(incoming[k])){const existing=forms[k][id];if(!existing)continue;if(['done','file','license','note'].some(key=>existing[key]!=null&&row[key]!=null&&existing[key]!==row[key]))conflicts.push({kind:k,id});}return conflicts;}
function chooseConflict(conflicts){
 const dialog=document.getElementById('import-choice');
 document.getElementById('conflict-summary').textContent=`有 ${conflicts.length} 项填写不同。新ID和另一表的记录会合并保留；请选择冲突项保留哪一份。`;
 document.getElementById('conflict-items').textContent=conflicts.slice(0,8).map(x=>byId.get(x.id)?.name||x.id).join('、')+(conflicts.length>8?'…':'');
 return new Promise(resolve=>{
  let settled=false;
  function end(choice){if(settled)return;settled=true;dialog.close();resolve(choice);}
  dialog.querySelectorAll('[data-choice]').forEach(b=>b.onclick=()=>end(b.dataset.choice));
  dialog.oncancel=e=>{e.preventDefault();end('cancel')};
  dialog.showModal();dialog.querySelector('[data-choice="current"]').focus();
 });
}
importData=async function(doc,choice){
 const incoming=parsedProgress(doc),conflicts=conflictsFor(incoming);
 if(conflicts.length&&!['current','incoming','cancel'].includes(choice))choice=await chooseConflict(conflicts);
 if(choice==='cancel')return {count:0,conflicts:conflicts.length,cancelled:true};
 const conflictIds=new Set(conflicts.map(x=>x.kind+':'+x.id));let count=0;
 for(const k of ['art','audio'])for(const [id,row] of Object.entries(incoming[k])){
  forms[k][id]=conflictIds.has(k+':'+id)&&choice==='current'?combineRows(row,forms[k][id]):combineRows(forms[k][id],row);count++;
 }
 carry=mergeCarry(carry,doc.form==='NEURONS_NEW_20261015'?doc.source_progress||{}:doc);
 progress=forms[DATA.kind];inheritAliases();dirty=true;render();
 return {count,conflicts:conflicts.length,cancelled:false};
};
function downloadBlob(name,blob){const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);}
function progressDownload(){downloadBlob('NEURONS_制作进度.json',new Blob([JSON.stringify(exportData(),null,2)],{type:'application/json;charset=utf-8'}));dirty=false;toast('已导出两表兼容进度；请保留JSON副本');}
function filledHtml(){
 const clone=document.documentElement.cloneNode(true);
 clone.querySelector('#progress-seed').textContent=JSON.stringify(exportData()).replace(/</g,'\\u003c');
 for(const id of ['groups','others','stats','batches','shared-style','specs'])clone.querySelector('#'+id).replaceChildren();
 clone.querySelector('#import-choice').removeAttribute('open');clone.querySelector('#manual-copy').removeAttribute('open');
 clone.querySelector('#manual-copy-text').textContent='';clone.querySelector('#toast').textContent='';
 clone.querySelector('#search').setAttribute('value','');
 return '<!doctype html>\n'+clone.outerHTML;
}
document.getElementById('export').onclick=progressDownload;
document.getElementById('download-filled').onclick=()=>{downloadBlob(`NEURONS_${DATA.kind==='art'?'美术':'音频'}_已填写.html`,new Blob([filledHtml()],{type:'text/html;charset=utf-8'}));dirty=false;toast('已下载填写版HTML：单独发送此文件即可带上当前进度');};
document.getElementById('file').onchange=async event=>{try{const file=event.target.files[0];if(!file)return;const result=await importData(JSON.parse(await file.text()));toast(result.cancelled?'已取消导入，原填写保持不变':`已合并 ${result.count} 项；另一表和未知ID均保留`);}catch(error){toast('导入失败：'+error.message+'；原填写保持不变');}finally{event.target.value='';}};
copy=async function(text){
 try{await navigator.clipboard.writeText(text);toast('已复制；参考图需另行上传');return;}catch(_){}
 const dialog=document.getElementById('manual-copy'),field=document.getElementById('manual-copy-text');field.value=text;dialog.showModal();field.focus();field.select();
 try{if(document.execCommand('copy')){dialog.close();toast('已复制；参考图需另行上传');return;}}catch(_){}
 toast('自动复制不可用：内容已选中，可手动复制');
};
document.getElementById('manual-copy-close').onclick=()=>document.getElementById('manual-copy').close();
document.getElementById('share-status').textContent='本页离线独立可用；所需参考图已内嵌。填写后下载“当前填写版网页”，单独发送该HTML；两表交换填写时另导出/导入统一进度JSON。';
document.getElementById('source-records').textContent='“来源记录”仅用于追溯原件，不是接收者设备上的文件链接。内嵌参考仍是候选/连接依据，不代表美术或空间已验收。';
window.NEURONS_FORM={...window.NEURONS_FORM,progress:()=>progress,fullPrompt:completePrompt,exportData,importData,filledHtml,conflictsFor};
render();dirty=false;
