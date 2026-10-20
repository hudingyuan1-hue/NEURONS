const fs=require('fs'),path=require('path'),assert=require('assert'),crypto=require('crypto');
const {pathToFileURL}=require('url');
const root=path.resolve(__dirname,'..'),out=path.join(root,'deliverables/comprehensive_forms_20261019'),work=path.join(root,'tmp/comprehensive_forms_20261019');
const api=require('./comprehensive_form_runtime.js');
const htmlFile=path.join(out,'03_全项目美术资产总表_含已有素材_可分享.html');
const html=fs.readFileSync(htmlFile,'utf8');
const D=JSON.parse(html.match(/<script id="form-data"[^>]*>([\s\S]*?)<\/script>/)[1]);
const by=Object.fromEntries(D.items.map(a=>[a.id,a]));let passed=[],runningBrowser;
function check(v,s){assert(v,s);passed.push(s)}
check(D.items.length===640&&new Set(D.items.map(a=>a.id)).size===640,'640 unique items retained including38UI and23effects');
const inventoryData=JSON.parse(fs.readFileSync(path.join(out,'data/inventory_snapshot.json'),'utf8'));
const inventory=Array.isArray(inventoryData)?inventoryData:inventoryData.files;
check(Array.isArray(inventory)&&D.review_summary.files===inventory.length,'all files from this frozen production snapshot are represented without chasing later additions');
check(D.items.filter(a=>a.category==='UI与功能界面').length===38,'complete38 UI production definitions');
check(Object.keys(D.spaces).length===56,'56 distinct spatial contracts');
check(D.items.filter(a=>a.review_status==='accepted').length===113,'all113 approved asset records retained without becoming fresh orders');
const runtimePath=path.join(root,'deliverables/space_templates_corrected_20261019/runtime_spaces.json'),runtime=JSON.parse(fs.readFileSync(runtimePath,'utf8'));
const anchors=JSON.parse(fs.readFileSync(path.join(root,'deliverables/space_templates_corrected_20261019/template_anchors.json'),'utf8'));
const contracts=JSON.parse(fs.readFileSync(path.join(root,'deliverables/space_templates_corrected_20261019/scene_generation_contracts.json'),'utf8'));
const current=JSON.parse(fs.readFileSync(path.join(out,'data/active_spatial_contracts.json'),'utf8'));
const links=JSON.parse(fs.readFileSync(path.join(out,'data/placement_links.json'),'utf8'));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),same=(a,b)=>JSON.stringify(a)===JSON.stringify(b),key=(room,id)=>room+'::'+id;
const baseline=JSON.parse(fs.readFileSync(path.join(out,'data/approval_baseline.json'),'utf8'));
for(const[id,parts]of Object.entries(baseline.accepted_parts))for(const part of parts){
 check(!!by[id]?.parts.some(p=>p.key===part.key&&p.status==='accepted'&&p.filename===part.filename&&(!part.sha256||p.sha256===part.sha256)),'original approved component/hash retained '+id+' '+part.key);
}
const fileRefs=new Map;
for(const a of D.items)for(const f of a.existing||[])for(const p of [f.path,...(f.alternate_paths||[])])if(p)fileRefs.set(path.resolve(p).toLowerCase(),f);
for(const f of inventory){const r=fileRefs.get(path.resolve(f.path).toLowerCase());check(!!r&&r.sha256===f.sha256,'frozen source path and exact hash mapped '+f.filename)}
check(runtime.failures.length===0,'actual layout export has no unresolved geometry failure');
check(current.runtime_sha256===sha(runtimePath),'comprehensive forms cite this exact current runtime export');
const eligible=r=>[...r.furniture,...(r.decor||[])].filter(f=>!['wall','mapping','floor_marks'].includes(f.kind)&&!f.wall_mount&&!f.logical_exclusion&&f.render!==false&&Number(f.height_m)>.02);
const actual=new Map(runtime.rooms.flatMap(r=>eligible(r).map(f=>[key(r.id,f.id),{room:r,f}]))),located=new Map;
for(const r of Object.values(D.spaces)){
 const source=runtime.rooms.find(s=>s.id===r.id),anchor=anchors.find(a=>a.id===r.id);check(!!source&&!!anchor,'runtime room and geometry anchors resolve '+r.id);
 check(same(r.size,source.size_m)&&same(r.floor_polygon_m,source.space_spec?.floor_polygon_m??null)&&same(r.floor_holes_m,source.space_spec?.floor_holes_m||[]),'room size, contour and voids match the actual layout '+r.id);
 check(r.furniture.length===eligible(source).length&&r.furniture.length===anchor.furniture.length,'all current eligible locators represented '+r.id);
 for(const f of r.furniture){
  const k=key(r.id,f.id),entry=actual.get(k),a=anchor.furniture.find(p=>p.id===f.id);check(!!entry&&!!a&&!located.has(k),'unique actual furniture locator '+k);located.set(k,f);
  check(same(f.position,entry.f.rect.slice(0,2))&&same(f.position,a.position)&&same(f.size,a.size),'furniture position and dimensions match current runtime '+k);
  check(Array.isArray(f.ground_anchor_px)&&f.ground_anchor_px.every((v,i)=>Number.isFinite(v)&&v>=0&&v<=f.pixel_size[i]),'furniture ground anchor inside its exact PNG '+k);
  check(!!D.media[f.media]&&!!f.shape_family&&!!f.construction,'locator image and object construction supplied '+k);
 }
}
check(located.size===actual.size,'locator count derives from active rendered runtime objects, never stale381');
const mapped=new Set;
for(const a of D.items.filter(a=>a.category==='家具与物品')){
 const expected=current.placements[a.id]||[];check((a.placements||[]).length===expected.length,a.id+' matches active placement contract');
 for(const p of a.placements||[]){const k=key(p.room_id,p.id);check(located.has(k),'human furniture placement points to a current actual locator '+a.id+' '+k);mapped.add(k);check(expected.some(e=>key(e.room_id,e.id)===k&&same(e.position,p.position)&&same(e.size,p.size)),a.id+' actual placement/size preserved '+k)}
 for(const p of a.archived_placements||[])check(!located.has(key(p.room_id,p.furniture_id)),'archived location is not a current generation target '+a.id+' '+p.room_id+' '+p.furniture_id);
}
const explicitlyNonmanual=new Set((links.unmapped||[]).filter(p=>p.manual_order===false&&p.reason).map(p=>key(p.room_id,p.furniture_id)));
for(const k of located.keys())check(mapped.has(k)||explicitlyNonmanual.has(k),'each locator has an asset assignment or explicit fixed/derived nonmanual treatment '+k);
for(const a of D.items.filter(a=>a.runtime_id)){
 const c=contracts.find(c=>c.id===a.runtime_id);check(!!c&&a.content===c.prompt&&a.connection_text===c.connection_text,'scene prompt comes from exact corrected geometry '+a.id);
}
check(D.items.flatMap(a=>a.clips||[]).flatMap(c=>c.poses).filter(p=>p.guide_media).length===32,'32 four-direction phase guides actually supplied');
check(by.CHR_MAIN_IDLE_D0.review_status==='accepted','approved directional bases retained');
check(by.CHR_OTHER_NPCS_N02.review_status==='partial','N02 partial identity approval preserved');
check(by.CHR_PLAYER_EXPR_06.parts.filter(p=>p.status==='accepted').length===3,'expression06 retains three existing expressions');
check(by.CHR_PLAYER_EXPR_06.parts.filter(p=>p.status!=='accepted').length===1,'expression06 only E02 remains');
const nurse=by.CHR_OTHER_NPCS_N04_ACTION_FIRST;
check(api.availablePhases(nurse,nurse.clips[0]).join(',')==='2','nurse only P03 requests editing');
const father=by.CHR_OTHER_NPCS_FATHER_ACTION_FIRST;
check(api.availablePhases(father,father.clips[0],true).length===0,'father retained reach and hold not reordered');
check(!api.availablePhases(father,father.clips[1]).includes(0),'father release reuses existing outstretched pose');
const altered=D.items.filter(a=>a.category==='人物母图'&&a.id.endsWith('_ALTERED'));
const supplied=altered.filter(a=>(a.existing||[]).some(f=>f.status==='user_supplied'));
check(supplied.length>0&&supplied.every(a=>['accepted','user_supplied'].includes(a.review_status)),'user-revised altered sources remain usable, not fresh review or regeneration orders');
const needs=new Set(api.selectItems(D,{status:'needs'}).map(a=>a.id));
check(supplied.every(a=>!needs.has(a.id)),'user-revised altered mothers do not appear in generation queue');
for(const a of D.items){
 check(a.review_status in D.labels,a.id+' has explicit status');
 for(const f of a.existing||[])check(f.media&&D.media[f.media]||!(/\.(png|jpe?g|webp)$/i.test(f.filename)),a.id+' existing image preview resolves');
 if(a.clips?.length){for(const c of a.clips)for(const p of c.poses){const s=api.makePrompt(D,a,{clip:c,pose:p,mother:a.mother,target:a.target_choices?.[0]});assert(s&&!s.includes('undefined'),a.id+' valid phase')}}
 else{const s=api.makePrompt(D,a,{task:a.tasks?.[0]});assert(s&&!s.includes('undefined'),a.id+' valid prompt')}
 if(a.category==='UI与功能界面')check(a.role==='codex'&&a.states.length&&a.parts_to_make.length,a.id+' genuine UI controls/states');
 if(a.runtime_id){const r=D.spaces[a.runtime_id];assert(r&&D.media[r.space_media]&&D.media[r.placement_media],a.id+' templates exist')}
}
check(!api.makePrompt(D,by.ENDING_HOST_EYES,{task:by.ENDING_HOST_EYES.tasks[0]}).includes('16:9'),'eye detail does not inherit landscape aspect');
check(api.makePrompt(D,by.UI_EVIDENCE_FAMILY_PHOTO).includes('4:3'),'evidence photo retains actual aspect');
check(api.flattenProgress({form_progress:{art:{OLD:{status:'old',notes:'原文'}}},art:[{id:'OTHER',status:'done'}]}).OLD.notes==='原文','nested legacy progress preserved');
check(!/<(?:img|script)[^>]+src=["'](?:https?:|file:)/i.test(html),'portable embedded images and script');

(async()=>{
 const {chromium}=require('C:/Users/23623/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
 const browser=runningBrowser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true});
 const context=await browser.newContext({viewport:{width:1360,height:1000},acceptDownloads:true});
 await context.addInitScript(()=>{window.__copies=[];Object.defineProperty(navigator,'clipboard',{value:{writeText:async s=>window.__copies.push(s)}})});
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(htmlFile).href);await page.waitForFunction(()=>window.NEURONS_FORM);
 check(await page.locator('article').count()>400,'default renders remaining work across all categories');
 await page.click('#all');check(await page.locator('article').count()===640,'complete register includes accepted materials');
 async function show(id){await page.selectOption('#category','');await page.selectOption('#status','');await page.fill('#search',id);const a=page.locator('article').filter({has:page.locator('summary',{hasText:by[id].name})}).first();await a.locator(':scope > details > summary').click();await page.waitForTimeout(60);return a}
 let article=await show('CHR_MAIN_IDLE_D0');check(await article.locator('.prompt').count()===0,'accepted item has no new generation order');
 article=await show('CHR_PLAYER_EXPR_06');check(await article.locator('select[aria-label="本次剩余部件"] option').count()===1,'partial expression offers missing component only');
 article=await show('CHR_OTHER_NPCS_N04_ACTION_FIRST');check(await article.locator('select[aria-label="当前姿态"]').inputValue()==='2','nurse edit opens required P03');
 await article.locator('button.primary').click();check((await page.evaluate(()=>window.__copies.at(-1))).includes('托夹手和夹板位置继承P02'),'copy matches selected current phase');
 await article.locator('details.inner').first().locator('summary').click();await page.screenshot({path:path.join(work,'review_nurse_desktop.png'),fullPage:true});
 article=await show(supplied.find(a=>a.review_status==='user_supplied').id);check(await article.locator('.prompt').count()===0,'user-revised altered mother displays supplied status with no repeated generation prompt');
 article=await show('CHR_OTHER_NPCS_N04_ACTION_ALTERED');check(!by.CHR_OTHER_NPCS_N04_ACTION_ALTERED.blocked,'user-revised nurse mother no longer blocks necessary derived action work');
 if(await article.locator('button.primary').count())check(!(await article.locator('button.primary').isDisabled()),'derived action copy is available after supplied mother confirmation');
 article=await show('ENV_BED');check(await article.locator('select[aria-label="本物件实际安装处"]').count()===1,'prop has actual placement/size selector');
 article=await show('CHR_MAIN_WALK_D0');const gd=article.locator('details.inner').filter({hasText:'下载本张姿态参照'});await gd.locator('summary').click();await gd.locator('img').waitFor({state:'visible'});let gp=page.waitForEvent('download');await gd.locator('button').click();const guideDownload=await gp;check(guideDownload.suggestedFilename().endsWith('.png'),'walk phase reference downloads as usable PNG');
 article=await show('ENV_ROOM_L1_ROOM_BASE');const d=article.locator('details.inner').filter({hasText:'本房唯一空间定位图'});await d.locator('summary').click();await d.locator('img').first().waitFor({state:'visible'});check(await d.locator('img').count()===2,'scene geometry and placement guide visible');
 await page.locator('img').evaluateAll(xs=>xs.forEach(x=>x.loading='eager'));await page.waitForFunction(()=>Array.from(document.images).every(x=>x.complete&&x.naturalWidth));check(true,'visible embedded previews load');
 // Real downloads verify JSON and a filled share page, without touching source progress.
 await page.evaluate(()=>window.NEURONS_FORM.getState().CHECK_SHARE={status:'已交付待验',notes:'</script><b>跨设备</b>'});
 let promise=page.waitForEvent('download');await page.click('#export');let dl=await promise;const p=await dl.path();const prog=JSON.parse(fs.readFileSync(p,'utf8'));check(prog.form_progress.CHECK_SHARE.notes==='</script><b>跨设备</b>','export preserves special text');check(prog.form_progress.ART_CODE_UI,'old ART_CODE_UI progress retained');
 promise=page.waitForEvent('download');await page.click('#filled');dl=await promise;const filled=fs.readFileSync(await dl.path(),'utf8'),fd=JSON.parse(filled.match(/<script id="form-data"[^>]*>([\s\S]*?)<\/script>/)[1]);check(fd.user_progress.CHECK_SHARE.notes==='</script><b>跨设备</b>','filled HTML safely preserves progress');const share=path.join(work,'filled_browser_check.html');fs.writeFileSync(share,filled);await page.goto(pathToFileURL(share).href);await page.waitForFunction(()=>window.NEURONS_FORM);check(await page.evaluate(()=>window.NEURONS_FORM.getState().CHECK_SHARE.status)==='已交付待验','filled page reopens with progress');
 await page.locator('#importfile').setInputFiles({name:'old_progress.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify({art:[{id:'IMPORTED_BROWSER_CHECK',status:'已交付待验',notes:'旧表实际导入'}]}))});await page.waitForFunction(()=>window.NEURONS_FORM.getState().IMPORTED_BROWSER_CHECK);check(await page.evaluate(()=>window.NEURONS_FORM.getState().IMPORTED_BROWSER_CHECK.notes)==='旧表实际导入','browser imports legacy progress without overwriting audit');
 check(await page.locator('#stats .stat').count()===4,'filled page does not duplicate rendered statistics');check(await page.locator('#category option').count()===8,'filled page does not duplicate category options');
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(work,'review_mobile.png'),fullPage:false});check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'mobile has no horizontal overflow');check(await page.locator('#category').evaluate(n=>n.getBoundingClientRect().width)>150,'mobile selectors remain readable');
 const u=await context.newPage();u.on('pageerror',e=>errors.push(e.message));await u.goto(pathToFileURL(path.join(out,'04_UI与功能界面表_可分享.html')).href);await u.waitForFunction(()=>window.NEURONS_FORM);check(await u.locator('article').count()===38,'standalone UI form all38 entries');await u.locator('article').filter({hasText:'UI视觉规范与部件母版'}).locator(':scope > details > summary').click();await u.screenshot({path:path.join(work,'review_ui_desktop.png'),fullPage:true});
 check(errors.length===0,'no browser JavaScript errors');await browser.close();
 const result={passed:passed.length,failed:0,checks:passed,scope:'Data and actual Edge browser form verification only; no game run, new image generation or UI art acceptance.'};fs.writeFileSync(path.join(out,'form_verification.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({passed:passed.length,failed:0}));
})().catch(async e=>{console.error(e);if(runningBrowser)await runningBrowser.close();process.exitCode=1});
