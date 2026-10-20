// Offline status/data/copy contract. This is not a real browser or listening test.
const fs=require('fs'),path=require('path'),vm=require('vm'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'deliverables/audio_status_20261019');
const page=fs.readFileSync(path.join(out,'02_声音资产状态_可分享.html'),'utf8'),data=JSON.parse(fs.readFileSync(path.join(out,'02_声音资产状态_来源.json'),'utf8'));
const embedded=JSON.parse(page.match(/<script id="audio-status-data" type="application\/json">([\s\S]*?)<\/script>/)[1]),scripts=[...page.matchAll(/<script(?: [^>]*)?>([\s\S]*?)<\/script>/g)];
const passes=[],failures=[],copies=[];const check=(ok,label)=>(ok?passes:failures).push(label);
class Node{constructor(){this.children=[];this.nodes=new Map;this.style={};this.value='all'}append(n){this.children.push(n)}replaceChildren(){this.children=[]}querySelector(s){if(!this.nodes.has(s))this.nodes.set(s,new Node);return this.nodes.get(s)}select(){}remove(){}}
const nodes=new Map(['music','other','channel','merged','remaining','copy-summary','toast','audio-status-data'].map(k=>[k,new Node]));nodes.get('audio-status-data').textContent=JSON.stringify(embedded);
const document={getElementById:id=>nodes.get(id),createElement:()=>new Node,body:new Node,execCommand:()=>true};
const context={document,navigator:{clipboard:{writeText:async s=>copies.push(s)}},setTimeout:()=>0,console,JSON,String};vm.createContext(context);vm.runInContext(scripts.at(-1)[1],context);
(async()=>{
 check(JSON.stringify(data)===JSON.stringify(embedded),'portable HTML embeds exactly the source status data');
 check(data.manual_orders.length===0,'no new manual sound/music orders');
 check(data.assets.length===27&&new Set(data.assets.map(a=>a.id)).size===27,'all27 existing unique bindings accounted for');
 check(nodes.get('music').children.length===5&&nodes.get('other').children.length===22,'five music and22 existing ambience/effects rows are separate');
 check(!/<(?:script|img|audio)[^>]+(?:src|href)=["'](?:https?:|file:)/i.test(page),'page has no network or original-machine media dependency');
 for(const a of data.assets){const file=path.join(root,'neurons',a.stream.replace(/^res:\/\//,''));check(fs.existsSync(file)&&crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===a.output_sha256,'actual delivery hash '+a.id)}
 const legacy=path.join(root,data.source_manifest.old_form);check(crypto.createHash('sha256').update(fs.readFileSync(legacy)).digest('hex')===data.source_manifest.old_form_sha256,'old audio form is preserved');
 await nodes.get('music').children[0].querySelector('button').onclick();check(copies.at(-1)===data.assets.find(a=>a.channel==='music').instruction,'music copy contains its exact existing binding/use');
 await nodes.get('other').children[0].querySelector('button').onclick();check(copies.at(-1)===data.assets.find(a=>a.channel!=='music').instruction,'effect copy is paired with its existing asset');
 nodes.get('channel').value='ui';nodes.get('channel').onchange();check(nodes.get('other').children.length===data.assets.filter(a=>a.channel==='ui').length,'channel filter lists the actual UI sounds only');
 await nodes.get('copy-summary').onclick();check(copies.at(-1).startsWith('新增人工制作: 0项。')&&copies.at(-1).includes('MUS_HOSPITAL')&&copies.at(-1).includes('MUS_END'),'summary copy explains reuse and no new manual orders');
 check(data.merged.length===4&&data.merged.some(m=>m.current==='MUS_DANGER')&&data.merged.some(m=>m.current==='MUS_END'),'legacy distinct-track requests are explicitly merged or deferred');
 check(data.technical_verification.some(v=>v.case==='final_wasapi'&&v.failures.length===0),'normal audio-driver evidence is recorded separately from listening acceptance');
 for(const a of data.assets.filter(a=>a.loop_variant)){const file=path.join(root,'neurons',a.loop_variant.stream.replace(/^res:\/\//,''));check(fs.existsSync(file)&&crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===a.loop_variant.output_sha256,'sustained-only derivative hash '+a.id)}
 check(data.assets.filter(a=>a.loop_variant).length===3&&!data.assets.find(a=>a.id==='MUS_END').loop_variant,'only the three approved continuous variants are processed');
 check(data.assets.find(a=>a.id==='AMB_FAN').runtime_mode.includes('持续')&&!data.codex_remaining.some(s=>s.includes('持续播放及')),'fan continuity is completed while subjective seam listening remains open');
 const dir=path.join(root,'docs/validation/music_context_20261019');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'status_page_check.json'),JSON.stringify({passes,failures,scope:'Offline JavaScript DOM, embedded data, clipboard instruction and actual file hash checks; not real-browser or subjective listening acceptance.'},null,2));
 console.log(JSON.stringify({passes:passes.length,failures:failures.length,manual_orders:data.manual_orders.length}));process.exitCode=failures.length?1:0;
})().catch(e=>{console.error(e);process.exitCode=1});
