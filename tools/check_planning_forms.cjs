// Planning form QA only. Does not launch Godot or write production assets/progress.
const fs=require('fs'),path=require('path'),assert=require('assert');
const {chromium}=require(process.env.NEURONS_NODE_MODULES+'/playwright');
const root=path.resolve(__dirname,'..'),out=path.join(root,'docs/validation/planning_20261015');
const dataDir=path.join(root,'deliverables/NEURONS_2D_资产需求_20261015');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'}),results=[];
 for(const name of ['01_全游戏提示词表单.html','01_音频需求表.html']){
  const p=await browser.newPage({viewport:{width:1366,height:950}}),errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.goto('file:///'+path.join(dataDir,name).replaceAll('\\','/'));await p.locator('.group').first().waitFor();
  const r=await p.evaluate(()=>({kind,defaultHuman:document.getElementById('owner').value==='我们'&&visibleGroups().every(g=>g.owner==='我们'),count:visibleGroups().length,rows:rows.length,groups:groups.length}));assert(r.defaultHuman);
  await p.locator('#search').fill(r.kind==='art'?'ENV_BEDSIDE':'MUS_ROOM');assert(await p.locator('#cards .group').count()>=1);
  const group=p.locator('#cards .group').first();await group.locator(':scope > summary').click();
  await group.locator('[data-copy="prompt"]').first().click();
  r.promptCopy=await p.evaluate(()=>document.getElementById('copybox').value.length>10&&!/保存|导出|Godot/.test(document.getElementById('copybox').value));assert(r.promptCopy);
  await group.locator('[data-copy="delivery"]').first().click();r.deliveryCopy=await p.evaluate(()=>document.getElementById('copybox').value.includes('制作方式：'));assert(r.deliveryCopy);
  await group.locator('textarea[data-field="notes"]').first().fill('表单往返测试，不写入仓库进度');
  r.progress=await p.evaluate(()=>{
   const edited=progress()[kind].find(x=>x.notes==='表单往返测试，不写入仓库进度');
   const saved=map.get(rows[0].id).status;let atomic=false;try{merge([{id:rows[0].id,status:'错误覆盖'},{id:rows[0].id,status:'重复'}]);}catch{atomic=map.get(rows[0].id).status===saved;}
   const other=kind==='art'?'audio':'art';merge({kind:'progress',schema_version:2,[kind]:[{id:rows[0].id,notes:'旧v2叶ID测试'}],[other]:[{id:'OTHER_KIND_TEST',notes:'另一表保留'}]});merge([{id:'FUTURE_UNKNOWN_ID',notes:'未来版本保留'}]);
   return {editedGroup:!!edited,atomicDuplicate:atomic,oldLeaf:progress()[kind].some(x=>x.notes==='旧v2叶ID测试'),unknown:progress()[kind].some(x=>x.id==='FUTURE_UNKNOWN_ID'),other:progress()[other][0].id==='OTHER_KIND_TEST'};
  });assert(Object.values(r.progress).every(Boolean));
  // Real DOM import/download roundtrip; test data is temporary only.
  await p.locator('#file').setInputFiles({name:'legacy.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify([{id:r.kind==='art'?'ENV_BEDSIDE':'MUS_ROOM',notes:'DOM导入进度'}]))});
  assert((await p.locator('#msg').textContent()).includes('合并'));
  const downloadPromise=p.waitForEvent('download');await p.locator('#export').click();const dl=await downloadPromise;const exported=JSON.parse(fs.readFileSync(await dl.path(),'utf8'));assert(exported.kind==='progress'&&exported.schema_version===2);assert(exported[r.kind].some(x=>x.notes==='DOM导入进度'));r.download=true;
  // Emulated file handle verifies connect/read-latest/write without touching repo JSON.
  await p.evaluate(()=>{window.testFile={kind:'progress',schema_version:2,art:[],audio:[]};window.writes=0;window.showOpenFilePicker=async()=>[{getFile:async()=>({text:async()=>JSON.stringify(window.testFile)}),createWritable:async()=>({write:async text=>{window.testFile=JSON.parse(text);window.writes++;},close:async()=>{}})}];});
  await p.locator('#connect').click();await p.evaluate(()=>{testFile[kind==='art'?'audio':'art']=[{id:'NEW_OTHER_EDIT',notes:'另一页最新修改'}];});await p.locator('#save').click();
  r.connectedSave=await p.evaluate(()=>writes===1&&testFile[kind==='art'?'audio':'art'][0].id==='NEW_OTHER_EDIT');assert(r.connectedSave);
  await p.evaluate(()=>{testFile={kind,rows:[]};});await p.locator('#save').click();r.refuseRequirementOverwrite=await p.evaluate(()=>writes===1);assert(r.refuseRequirementOverwrite);
  await p.locator('#owner').selectOption('Codex');await p.locator('#search').fill(r.kind==='art'?'UI_SKILL_SKIN':'SFX_DRAWER');r.codexSearch=await p.locator('#cards .group').count()>0;assert(r.codexSearch);
  await p.locator('#cards .group > summary').first().click();await p.screenshot({path:path.join(out,r.kind+'_codex.png')});
  if(r.kind==='audio'){
   await p.locator('#cue-panel > summary').click();await p.locator('#cue-search').fill('刚才……是我想动的吗？');r.cueSearch=await p.locator('#cues .leaf').count()>0;assert(r.cueSearch);
  }
  await p.reload();await p.locator('#search').fill(r.kind==='art'?'ENV_BEDSIDE':'MUS_ROOM');await p.locator('#cards .group > summary').first().click();await p.screenshot({path:path.join(out,r.kind+'_human.png')});
  if(r.kind==='audio'){await p.locator('#cue-panel > summary').click();await p.locator('#cue-search').fill('刚才……是我想动的吗？');}
  await p.setViewportSize({width:430,height:900});await p.screenshot({path:path.join(out,r.kind+'_mobile.png')});r.mobileNoOverflow=await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1);if(!r.mobileNoOverflow)console.log(await p.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,wide:[...document.querySelectorAll('body *')].filter(e=>e.getBoundingClientRect().right>innerWidth).map(e=>({tag:e.tagName,id:e.id,right:e.getBoundingClientRect().right})).slice(0,12)})));assert(r.mobileNoOverflow);
  r.errors=errors;assert(errors.length===0);results.push(r);await p.close();
 }
 await browser.close();fs.writeFileSync(path.join(out,'browser_results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
})().catch(e=>{console.error(e);process.exit(1);});
