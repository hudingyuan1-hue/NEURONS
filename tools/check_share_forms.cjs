// DOM/serialization contract checks only. Does not launch or automate a browser.
const fs=require('fs'),path=require('path'),assert=require('assert');
const {JSDOM,VirtualConsole,ResourceLoader}=require('../tmp/form_dom_validation/node_modules/jsdom');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'deliverables/NEURONS_2D_资产需求_20261015');
const out=path.join(root,'docs/validation/offline_forms_20261016');fs.mkdirSync(out,{recursive:true});
const elsewhere=process.env.NEURONS_SHARE_PROOF||path.join(root,'tmp/offline-share-detached');fs.mkdirSync(elsewhere,{recursive:true});
const checks=[],artifacts=[];
function check(value,label){checks.push({label,ok:!!value});assert(value,label);}
const canonical=f=>{const d=f.exportData();delete d.updated;return JSON.stringify(d);};
async function load(html,location){
 const errors=[],requests=[],downloads=[],blobs=new Map();let serial=0;
 class Offline extends ResourceLoader{fetch(url){requests.push(url);return null;}}
 const vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));
 const dom=new JSDOM(html,{url:'file:///'+location.replaceAll('\\','/'),runScripts:'dangerously',resources:new Offline(),virtualConsole:vc,
  beforeParse(w){
   w.structuredClone=structuredClone;w.Blob=Blob;
   w.URL.createObjectURL=b=>{const key='blob:local-contract-'+(++serial);blobs.set(key,b);return key};w.URL.revokeObjectURL=()=>{};
   w.HTMLAnchorElement.prototype.click=function(){if(this.download)downloads.push({name:this.download,blob:blobs.get(this.href)});};
   w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','')};w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open')};
   w.document.execCommand=()=>false;
  }});
 await new Promise(r=>setTimeout(r,5));return {dom,w:dom.window,d:dom.window.document,errors,requests,downloads};
}
(async()=>{
 for(const [kind,filename] of [['art','01_全游戏提示词表单.html'],['audio','01_音频需求表.html']]){
  const html=fs.readFileSync(path.join(dir,filename),'utf8'),old=JSON.parse(fs.readFileSync(path.join(dir,'history/20261016_offline_share_before/data',kind+'_form.json'),'utf8'));
  const current=JSON.parse(fs.readFileSync(path.join(dir,'data',kind+'_form.json'),'utf8'));
  const oldItems=old.groups.flatMap(g=>g.items),items=current.groups.flatMap(g=>g.items);
  check(JSON.stringify(oldItems)===JSON.stringify(items),kind+': all stable items, original text, prompts, IDs and source paths preserved');
  const env=await load(html,path.join(dir,filename)),{w,d}=env,f=w.NEURONS_FORM;
  check(env.errors.length===0,kind+': inline scripts execute without DOM exceptions');
  check(env.requests.length===0,kind+': no external resources requested');
  check(!/<script[^>]+src=|<link[^>]+href=|fetch\(/i.test(html),kind+': no script/style/CDN/fetch dependency');
  check([...d.querySelectorAll('#groups .asset')].every(e=>f.byId.get(e.dataset.asset).owner==='A'),kind+': default view shows human responsibilities');
  check(!d.getElementById('other-work').open,kind+': code work and uncommissioned voices remain collapsed');
  const id=items.find(i=>i.owner==='A').id;
  const search=d.getElementById('search');search.value=id;search.dispatchEvent(new w.Event('input'));
  check(d.querySelectorAll('#groups .asset').length===1,kind+': search narrows to stable ID');
  d.getElementById('expand').click();check(d.querySelector('#groups>.group').open,kind+': group expand control works');
  const asset=d.querySelector('#groups .asset');asset.open=true;
  check(asset.querySelector('.prompt').textContent.includes(f.byId.get(id).prompt),kind+': full prompt is selectable DOM text');
  asset.querySelector('.copy').click();await new Promise(r=>setTimeout(r,5));
  check(d.getElementById('manual-copy').open&&d.getElementById('manual-copy-text').value.includes(f.byId.get(id).prompt),kind+': blocked clipboard falls back to selectable manual copy');
  d.getElementById('manual-copy-close').click();
  const box=asset.querySelector('[data-done]');box.checked=true;box.dispatchEvent(new w.Event('change',{bubbles:true}));
  const note=asset.querySelector('[data-field="note"]');note.value='异地填写 </script><img src=x onerror=alert(1)> 中文测试';note.dispatchEvent(new w.Event('input',{bubbles:true}));
  check(f.progress()[id].done&&f.progress()[id].note.includes('异地填写'),kind+': actual form events update current entry');
  const other=kind==='art'?'audio':'art';
  await f.importData({kind:'progress',form_progress:{[other]:{FUTURE_OTHER:{done:true,note:'另一表未来ID'}},[kind]:{FUTURE_CURRENT:{done:false,note:'本表未来ID'}}}},'current');
  check(f.exportData().form_progress[other].FUTURE_OTHER.note==='另一表未来ID'&&f.exportData().form_progress[kind].FUTURE_CURRENT.note==='本表未来ID',kind+': unknown IDs in both forms are retained');
  const before=canonical(f),cancel=f.importData({form_progress:{[kind]:{[id]:{done:false,note:'导入内容'}}}});
  check(d.getElementById('import-choice').open,kind+': conflict requires an explicit choice');
  d.querySelector('[data-choice="cancel"]').click();await cancel;check(canonical(f)===before,kind+': cancel is atomic');
  await f.importData({form_progress:{[kind]:{[id]:{done:false,note:'导入内容',future_field:'保留扩展'}}}},'current');
  check(f.progress()[id].done&&f.progress()[id].note.includes('异地填写')&&f.progress()[id].future_field==='保留扩展',kind+': keep-current preserves both existing values and new extension fields');
  await f.importData({form_progress:{[kind]:{[id]:{done:false,note:'选择导入填写'}}}},'incoming');
  check(!f.progress()[id].done&&f.progress()[id].note==='选择导入填写',kind+': use-imported choice is honored');
  const intact=canonical(f);let rejected=false;try{await f.importData({form_progress:{[kind]:{VALID_EXTRA:{done:true},BAD:{done:'yes'}}}});}catch(e){rejected=true;}
  check(rejected&&canonical(f)===intact,kind+': invalid final row cannot partly overwrite progress');
  await f.importData({form:'NEURONS_NEW_20261015',kind:other,progress:{LEGACY_UNKNOWN:{done:true,note:'旧简表'}},source_progress:{migration_note:'旧来源保留'}},'current');
  check(f.exportData().form_progress[other].LEGACY_UNKNOWN.done,kind+': old simplified protocol imports without deleting unknown IDs');
  f.update(id,'note','异地填写 </script><img src=x onerror=alert(1)> 中文测试');f.update(id,'done',true);
  d.getElementById('export').click();const jsonDownload=env.downloads.at(-1),json=JSON.parse(await jsonDownload.blob.text());
  check(json.schema_version===4&&json.form_progress[kind][id].done&&json.form_progress[other].FUTURE_OTHER.done,kind+': JSON download contains both tables and current edits');
  const jsonPath=path.join(elsewhere,kind+'_progress.json');fs.writeFileSync(jsonPath,JSON.stringify(json,null,2));
  d.getElementById('download-filled').click();const download=env.downloads.at(-1),filled=await download.blob.text();
  const file=path.join(elsewhere,download.name);fs.writeFileSync(file,filled);artifacts.push(file);
  env.dom.window.close();
  const reopened=await load(fs.readFileSync(file,'utf8'),file),rf=reopened.w.NEURONS_FORM;
  check(reopened.errors.length===0&&reopened.requests.length===0,kind+': detached generated HTML starts without exceptions/external requests');
  check(rf.progress()[id].done&&rf.progress()[id].note===json.form_progress[kind][id].note,kind+': close/reopen generated HTML restores filled values, including script-like text');
  check(rf.exportData().form_progress[other].FUTURE_OTHER.done&&rf.exportData().form_progress[other].LEGACY_UNKNOWN.done,kind+': detached HTML retains other-table and legacy unknown IDs');
  const refs=JSON.parse(reopened.d.getElementById('share-references').textContent);
  check(Object.values(refs).every(r=>require('crypto').createHash('sha256').update(Buffer.from(r.base64,'base64')).digest('hex')===r.sha256),kind+': every embedded reference is byte-identical to its recorded original');
  check(![...reopened.d.querySelectorAll('.existing a')].length,kind+': source-record paths are not broken cross-computer hyperlinks');
  check(filled.includes('@media(max-width:600px)')&&filled.includes('overflow-wrap:anywhere'),kind+': narrow-layout rules and long text wrapping exist (not a device render test)');
  reopened.dom.window.close();
 }
 const report={checks:checks.length,failed:checks.filter(x=>!x.ok).length,results:checks,artifacts,scope:'Node/jsdom isolated DOM and serialization contracts. No real browser launched. file:// browser tool was policy-blocked; no browser download, responsive rendering, clipboard OS integration or second device claim.'};
 fs.writeFileSync(path.join(out,'result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({checks:report.checks,failed:report.failed,artifacts},null,2));
})().catch(error=>{fs.writeFileSync(path.join(out,'failed.json'),JSON.stringify({error:String(error.stack),checks},null,2));console.error(error);process.exitCode=1;});
