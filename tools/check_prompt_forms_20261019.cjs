// Local form data and DOM-contract checks; this is not a browser or image-quality test.
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.resolve(__dirname,'..'),out=path.join(root,'deliverables/generation_forms_20261019');
const passed=[],failed=[];
function check(ok,name){(ok?passed:failed).push(name);if(!ok)console.error('FAIL '+name)}
const htmlFiles=['01_人物动作及其他_生成表单_可分享.html','02_场景生成表单_可分享.html'];
function load(name){
  const html=fs.readFileSync(path.join(out,name),'utf8'),ss=[...html.matchAll(/<script(?: [^>]*)?>([\s\S]*?)<\/script>/g)];
  const data=JSON.parse(ss[0][1]),js=ss.at(-1)[1],copies=[],downloads=[],blobs=new Map;
  class Node{
    constructor(tag='div'){this.tag=tag;this.children=[];this.selectors=new Map;this.dataset={};this.style={};this.value='';this.hidden=false;this.checked=false;this.handlers={};this.options=[];this.parentElement={hidden:false};}
    set innerHTML(s){this.html=s;this.selectors.clear();const ops=[...s.matchAll(/<option(?: value="([^"]*)")?[^>]*>([\s\S]*?)<\/option>/g)];if(this.tag==='select'||ops.length&&this.tag==='option-list'){this.options=ops.map(m=>({value:m[1]??m[2],textContent:m[2]}));this.value=this.options[0]?.value||''}}
    get innerHTML(){return this.html||''}
    append(...ns){this.children.push(...ns);if(this.tag==='select')for(const n of ns)this.options.push({value:n.value||n.textContent,textContent:n.textContent})}
    replaceChildren(...ns){this.children=ns}
    querySelector(s){if(!this.selectors.has(s)){const cl=s.startsWith('.')?s.slice(1):null;const re=cl?new RegExp('<(select|textarea|input|button)[^>]*class="[^"]*\\b'+cl+'\\b[^\"]*"[^>]*>([\\s\\S]*?)<\\/\\1>'):null;const match=re?.exec(this.html||'');const n=new Node(match?.[1]||s);if(match)n.innerHTML=match[2];this.selectors.set(s,n)}return this.selectors.get(s)}
    querySelectorAll(){return []}
    insertAdjacentHTML(_,s){this.html=(this.html||'')+s}
    addEventListener(k,f){this.handlers[k]=f}
    click(){if(this.disabled)return;if(this.tag==='a')downloads.push({href:this.href,name:this.download});return this.onclick?.()}
    select(){} remove(){}
  }
  const ids=['prompt-data','title','version','firsttext','first','showfirst','intro','samples','linkbody','category','group','search','defer','code','count','items','effects','effectbody','export','filled','import','importfile','toast'];
  const nodes=Object.fromEntries(ids.map(id=>[id,new Node(['category','group'].includes(id)?'select':id)]));nodes['prompt-data'].textContent=ss[0][1];nodes.firsttext.hidden=true;
  const document={body:new Node('body'),getElementById:id=>nodes[id],createElement:tag=>new Node(tag),execCommand:()=>true,title:''};
  document.documentElement={cloneNode(){const pnode={textContent:ss[0][1]};return{querySelector:s=>s==='#prompt-data'?pnode:new Node(),get outerHTML(){return html.replace(ss[0][1],pnode.textContent)}}}};
  const context={document,navigator:{clipboard:{writeText:async s=>copies.push(s)}},localStorage:{getItem:()=>null,setItem(){}},setTimeout:()=>0,URL:{createObjectURL:b=>{const id='blob:'+blobs.size;blobs.set(id,b);return id},revokeObjectURL(){}},Blob,console};
  vm.createContext(context);vm.runInContext(js,context,{timeout:10000});
  return{html,data,context,nodes,copies,downloads,blobs,Node,eval:s=>vm.runInContext(s,context),asset(id){const a=data.items.find(a=>a.id===id),host=new Node();context.subject=a;context.host=host;vm.runInContext("(D.mode==='scenes'?renderScene:renderAsset)(subject,host)",context);return{a,host}}};
}
(async()=>{
  const assets=load(htmlFiles[0]),scenes=load(htmlFiles[1]);
  check(assets.data.items.length===522,'all522 non-scene original IDs retained');
  check(scenes.data.items.filter(a=>a.runtime_id).length===56,'56 playable spatial entries retained');
  const source=fs.readFileSync('C:/Users/23623/Desktop/NEW/最终表单/01_美术资产表_可分享.html','utf8');
  const old=JSON.parse(source.match(/<script[^>]*id="table-data"[^>]*>([\s\S]*?)<\/script>/)[1]);
  const original=old.groups.flatMap(g=>g.items.map(a=>a.id)),ids=[...assets.data.items,...scenes.data.items].map(a=>a.id);
  check(ids.length===new Set(ids).size&&original.length===ids.length&&original.every(id=>ids.includes(id)),'all579 prior IDs preserved once, no inflated asset order');
  check(assets.data.effects.length===23,'all23 existing event-effect mappings retained');
  for(const page of[assets,scenes]){
    check(!/<(?:script|img)[^>]+src=["'](?:https?:|file:)/i.test(page.html),page.data.mode+' has no external script/image dependency');
    check(page.html.includes('[hidden]{display:none!important}'),page.data.mode+' hidden instructions stay hidden');
    await page.nodes.first.click();check(page.copies.at(-1)===page.data.first,page.data.mode+' first-message copy is complete');
    page.nodes.showfirst.click();check(page.nodes.firsttext.hidden===false,page.data.mode+' first-message expansion works');
    page.nodes.export.click();const exportBlob=page.blobs.get(page.downloads.at(-1).href);check(JSON.parse(await exportBlob.text()).form_progress.ART_CODE_UI,page.data.mode+' retains old source progress by original ID');
    page.eval("state['LOCAL_CHECK']={status:'已有候选',notes:'</script><b>跨设备</b>'}");page.nodes.filled.click();
    const filled=await page.blobs.get(page.downloads.at(-1).href).text();
    const filledData=JSON.parse(filled.match(/<script[^>]*id="prompt-data"[^>]*>([\s\S]*?)<\/script>/)[1]);
    check(filledData.source_progress.form_progress.LOCAL_CHECK.notes==='</script><b>跨设备</b>',page.data.mode+' filled HTML safely preserves user text and progress');
    page.nodes.importfile.onchange({target:{files:[{text:async()=>JSON.stringify({art:[{id:'IMPORT_CHECK',status:'已交付待验'}]})}]}});
  }
  await new Promise(resolve=>setImmediate(resolve));
  check(assets.eval("state.IMPORT_CHECK.status")==='已交付待验','legacy array progress import uses asset IDs');
  const walk=assets.asset('CHR_MAIN_WALK_D0'),u=walk.host.children[0];
  check(u.querySelector('.prompt').value.includes('画面右')&&u.querySelector('.prompt').value.includes('左脚跟接触'),'walk selected direction and actual support phase copied');
  const ps=u.querySelector('.pose');ps.value='1';ps.onchange();await u.querySelector('.copy').click();
  check(assets.copies.at(-1).includes('右脚跟接触')&&!assets.copies.at(-1).includes('四格排列'),'phase copy updates rather than stale sprite-sheet prompt');
  const ms=u.querySelector('.mother');ms.value='CHR_MAIN_OUTFIT_L2_NEW';ms.onchange();check(u.querySelector('.prompt').value.includes(assets.data.names.CHR_MAIN_OUTFIT_L2_NEW),'clothing mother selection enters copied text');
  check(walk.a.clips[0].play_order.join(',')==='0,4,2,5,1,6,3,7','walk production order separated from correct playback order');
  for(const id of['CHR_MAIN_SLEEP_WAKE','CHR_OTHER_NPCS_N08_ACTION_FIRST','CHR_OTHER_NPCS_N10_ACTION_FIRST','CHR_OTHER_NPCS_N10_ACTION_ALTERED']){const {host}=assets.asset(id);check(!host.children[0].querySelector('.prompt').value.includes('脚下基准线'),id+' does not force standing anchor')}
  const father=assets.asset('CHR_OTHER_NPCS_FATHER_ACTION_ALTERED'),fu=father.host.children[0],ts=fu.querySelector('.target');ts.value='CHR_OTHER_NPCS_MOTHER_ALTERED';ts.onchange();check(fu.querySelector('.prompt').value.includes('粘连')&&fu.querySelector('.prompt').value.includes(assets.data.names.CHR_OTHER_NPCS_MOTHER_ALTERED),'father current contact target and fused bottle preserved');
  const alien=assets.asset('CHR_OTHER_NPCS_N19_ALTERED');check(alien.host.querySelector('.prompt').value.includes('允许')&&alien.host.querySelector('.prompt').value.includes('前脸采用主角当前面貌')&&!alien.host.querySelector('.prompt').value.includes('体型、身体连接保持'),'whole-body alteration does not conflict with identity source');
  const eyes=assets.asset('ENDING_HOST_EYES');check(eyes.host.querySelector('.prompt').value.includes('1:1')&&!eyes.host.querySelector('.prompt').value.includes('16:9')&&eyes.host.querySelector('.copy').disabled,'eyes single-state aspect and unknown-host blocker respected');
  const story=assets.asset('SLIDE_A02');check(story.host.querySelector('.prompt').value.includes('人与动物')&&story.host.querySelector('.prompt').value.includes('来源不明'),'opening restores documented fleeing figures without inventing cause');
  const dog=assets.asset('CHR_OTHER_NPCS_DOG_ACTION_ALTERED');check(dog.host.children.some(n=>n.className==='notice'&&n.querySelector('textarea').value.includes('散落终态')),'existing dog shatter conditional prompt is directly available');
  assets.nodes.category.value='家具与物品';assets.nodes.category.onchange();check(assets.nodes.items.children.length===17,'default props list contains17 manual items, excludes181 Codex details');
  assets.nodes.code.checked=true;assets.nodes.code.onchange();check(assets.nodes.items.children.length===198,'Codex items remain inspectable when explicitly selected');
  const base=scenes.asset('ENV_ROOM_L1_ROOM_BASE');await base.host.querySelector('.copy').click();check(scenes.copies.at(-1).includes('木地板')&&scenes.copies.at(-1).includes('6.4×4.8')&&scenes.copies.at(-1).includes('左后床')&&scenes.copies.at(-1).includes('剖切'),'bedroom copied prompt includes material, dimensions, topology reservations and cutaway');
  check(scenes.nodes.items.children.length===56,'Codex-only worn state retained but hidden by default');
  for(const page of[assets,scenes])for(const a of page.data.items){
    if(a.clips?.length)for(const c of a.clips)for(const p of c.poses){page.context.checkA=a;page.context.checkC=c;page.context.checkP=p;const text=page.eval('actionPrompt(checkA,checkC,checkP,checkA.mother_choices[0]||checkA.mother||checkA.id,checkA.target_choices[0]||null)');if(!text||text.includes('undefined'))failed.push('bad phase '+a.id+' '+p.label)}
    if(a.role!=='codex'&&!a.clips?.length&&page.data.mode==='assets'){page.context.checkA=a;const text=page.eval('basePrompt(checkA,checkA.tasks[0])');if(!text||text.includes('undefined'))failed.push('bad item '+a.id)}
  }
  const result={passed,failed,scope:'Static JSON and simulated DOM-contract only; no browser engine, game execution, image generation or visual acceptance.'};
  fs.writeFileSync(path.join(out,'form_contract_check.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify({passed:passed.length,failed:failed.length,scope:result.scope}));process.exitCode=failed.length?1:0;
})().catch(e=>{console.error(e);process.exitCode=1});
