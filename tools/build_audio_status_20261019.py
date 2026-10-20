"""Compact audio delivery status, without reopening old asset orders."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, wave

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables/audio_status_20261019'
NAME='02_声音资产状态_可分享.html'
MUSIC={
 'MUS_MENU':('标题与建档','持续背景，进入标题后稳定播放'),
 'MUS_ROOM':('教程与卧室','持续背景，同场景不重启'),
 'MUS_HOSPITAL':('医院、精神病院、脑皮层探索','这些探索共用一曲；既有深部探索选曲也复用，不新增玩法'),
 'MUS_DANGER':('第五关战斗／深部追逐、Street与隐藏路线','沿已确认危险音乐用途复用'),
 'MUS_END':('E2、E3与来处星球尾声','一次播放；尾声接续不重启，不循环'),
}
LABELS={
 'AMB_FAN':'风扇环境','SFX_UI_CONFIRM':'新版界面确认','SFX_UI_BACK':'界面返回','SFX_UI_DENIED':'操作拒绝',
 'SFX_UI_SAVE':'保存反馈','SFX_UI_REWARD':'奖励反馈','SFX_DOOR_OPEN':'开门','SFX_DOOR_CLOSE':'关门',
 'SFX_FOOTSTEP':'脚步','SFX_SEARCH_CLOTH':'翻找布料','SFX_SEARCH_PAPER':'翻找纸页','SFX_SKIN':'皮肤刺激',
 'SFX_GUT':'腹部不适','SFX_DRAWER':'抽屉接触','SFX_COLD':'冷气释放','SFX_KEY':'钥匙反馈',
 'SFX_ITEM_HANDOFF':'物件交付','SFX_HIT':'真实受击','SFX_COMBAT_WINDUP':'攻击预告','SFX_BED_ROLL':'推床移动',
 'SFX_RACK_CONTACT':'衣架接触','SFX_SPLASH':'药液实际泼出',
}
MERGED=[
 {'old':'MUS_ASYLUM / MUS_CORTEX / MUS_DEEP','current':'MUS_HOSPITAL','reason':'已确认探索共用；第五关战斗、追逐另用MUS_DANGER。'},
 {'old':'MUS_STREET / MUS_STREET_FINAL','current':'MUS_DANGER','reason':'Street及隐藏路线沿现有危险音乐，不另订街道曲。'},
 {'old':'MUS_ENDING_E2 / MUS_ENDING_E3 / MUS_EPILOGUE','current':'MUS_END','reason':'同一已交E2录音用于两结局及星球尾声，连续播放。'},
 {'old':'MUS_OPEN / MUS_STORY','current':'保留已交旧候选，当前不另加绑定','reason':'按10月17日确认范围；未接入的旧候选不转成缺失订单。'},
]

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def make(share=None):
 bindings_path=ROOT/'neurons/data/audio_bindings.json'
 bindings=json.loads(bindings_path.read_text(encoding='utf-8-sig'))
 loops_path=ROOT/'neurons/data/audio_loop_variants.json'
 loop_manifest=json.loads(loops_path.read_text(encoding='utf-8'))
 loops={entry['id']:entry for entry in loop_manifest['variants']}
 for entry in loops.values():
  path=ROOT/'neurons'/entry['stream'].removeprefix('res://')
  if not path.is_file() or sha(path)!=entry['output_sha256']:raise RuntimeError('Loop variant changed: '+entry['id'])
 legacy=ROOT/'deliverables/NEURONS_2D_资产需求_20261015/01_音频需求表.html'
 assets=[]
 for entry in bindings['assets']:
  path=ROOT/'neurons'/entry['stream'].removeprefix('res://')
  if not path.is_file():raise RuntimeError('Missing current audio: '+entry['stream'])
  digest=sha(path)
  if entry.get('output_sha256') and digest!=entry['output_sha256']:raise RuntimeError('Audio changed without matching delivery record: '+entry['id'])
  source=ROOT/entry.get('source','');pcm=path if path.suffix.lower()=='.wav' else source
  duration=None
  if pcm.is_file() and pcm.suffix.lower()=='.wav':
   with wave.open(str(pcm),'rb') as audio:duration=audio.getnframes()/audio.getframerate()
  id=entry['id'];music=id in MUSIC
  use,note=MUSIC[id] if music else (LABELS.get(id,id),'已绑定；短音加工与复用由Codex处理。')
  if id in loops:note+=' 持续用途采用独立首尾交叠副本，原录音和单次用途保留；仍待实际听验。'
  if id=='AMB_FAN':note='已交并绑定；卧室内持续、离房淡出、回房可再响。独立0.12秒首尾交叠副本，仍待接缝听验；无需人工重做。'
  mode='持续场景BGM，状态切换约0.35秒淡变' if music and id!='MUS_END' else '持续卧室环境，进出约0.2秒淡变' if id=='AMB_FAN' else '一次播放'
  assets.append({'id':id,'name':use,'channel':entry['channel'],'duration_s':round(duration,4) if duration is not None else None,'duration_basis':'原始PCM文件头；持续衍生略短于原件，不代表主观听验','stream':entry['stream'],'source':entry.get('source',''),'source_sha256':entry.get('source_sha256',''),'output_sha256':digest,'source_binding_loop':entry.get('loop',False),'runtime_mode':mode,'loop_variant':loops.get(id),'status':'已交付并绑定；无需人工重做' if entry.get('source','').startswith('DOCX/') else 'Codex已有合成占位；无需人工制作','note':note,'instruction':f"{id} | {use} | {mode} | {entry['stream']} | {note}"})
 observed=[]
 for name in ['final_dummy_r3','final_delivery','final_dialogue','final_wasapi']:
  path=ROOT/'docs/validation/music_context_20261019'/name/'result.json'
  if path.exists():
   data=json.loads(path.read_text(encoding='utf-8-sig'));observed.append({'case':name,'passes':len(data.get('passes',[])),'failures':data.get('failures',[]),'evidence':str(path.relative_to(ROOT)).replace('\\','/')})
 data={'title':'NEURONS 声音资产状态','version':'2026-10-19','manual_orders':[],'assets':assets,'music_count':len(MUSIC),'binding_count':len(assets),'confirmed_rule':'2026-10-17 HANDOFF 音频2指定用途；已完成的人工音乐不重新开单。','source_manifest':{'bindings':str(bindings_path.relative_to(ROOT)).replace('\\','/'),'bindings_sha256':sha(bindings_path),'loop_variants':str(loops_path.relative_to(ROOT)).replace('\\','/'),'loop_variants_sha256':sha(loops_path),'old_form':str(legacy.relative_to(ROOT)).replace('\\','/'),'old_form_sha256':sha(legacy),'old_form_items':496,'old_form_policy':'原表与进度保留。本页取代旧15首人工曲的任务解释，不重跑旧生成器。'},'merged':MERGED,'codex_remaining':['现有短音的材质区分、触发点、尾音与整体响度关系。','持续BGM与风扇衍生的接缝、乐句衔接及最终混音耳验；一次结局不循环。'],'deferred':['未启用的旧开场/剧情/Street音乐候选保留，不新增制作。','正式配音不新增人工录制任务。'],'technical_verification':observed,'acceptance':'播放器、实际跨尾、暂停、切换和保存属于技术验证；未主观听验、未批准循环接缝或最终混音。'}
 if len(assets)!=27:raise RuntimeError('Unexpected binding count; review actual delivery before publishing status.')
 OUT.mkdir(parents=True,exist_ok=True)
 (OUT/'02_声音资产状态_来源.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 page=PAGE.replace('__DATA__',json.dumps(data,ensure_ascii=False).replace('</','<\\/'))
 (OUT/NAME).write_text(page,encoding='utf-8')
 if share:
  share.mkdir(parents=True,exist_ok=True)
  for name in [NAME,'02_声音资产状态_来源.json']:shutil.copy2(OUT/name,share/name)
 print(json.dumps({'manual_orders':0,'music':len(MUSIC),'bindings':len(assets),'html':str(OUT/NAME),'share':str(share)},ensure_ascii=False))

PAGE=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEURONS 声音资产状态</title>
<style>body{margin:0;background:#f3f1e9;color:#273d3b;font:16px/1.65 system-ui,"Microsoft Yahei",sans-serif}main{max-width:1100px;margin:auto;padding:24px}h1{font-size:26px;margin:0}h2{font-size:20px;margin:26px 0 10px}.notice{padding:14px;background:#e2e9dc;border-radius:7px}.muted{font-size:14px;color:#607068}table{border-collapse:collapse;width:100%;background:white}th,td{padding:11px;text-align:left;border-bottom:1px solid #d7ded4;vertical-align:top}th{font-weight:600}code{font-size:13px;word-break:break-all}button,select{font:inherit;padding:7px 10px;background:white;color:inherit;border:1px solid #aabbb0;border-radius:5px;cursor:pointer}nav{display:flex;gap:10px;margin:12px 0}details{margin:12px 0}summary{cursor:pointer;font-weight:600}#toast{position:fixed;bottom:20px;right:20px;background:#273d3b;color:white;padding:10px;border-radius:5px;display:none}@media(max-width:650px){main{padding:12px}td,th{padding:8px;font-size:14px}}</style>
<main><h1>NEURONS 声音资产状态</h1><p class="notice"><b>本轮新增人工制作：0项。</b>人工音乐已交付；现有5个音乐ID按确认用途复用，27个声音绑定均已在工程中。无需按照旧表重新制作15首音乐。</p><p class="muted">这是交付与接入状态，不是新生成清单。旧原件、旧表与填写进度保留。</p><button id="copy-summary">复制当前接入安排</button>
<h2>已交音乐 · 复用这5个ID</h2><table><thead><tr><th>音乐／用途</th><th>播放与状态</th><th>接入</th></tr></thead><tbody id="music"></tbody></table>
<h2>现有环境声与短音 · Codex处理</h2><nav><select id="channel"><option value="all">全部22项</option><option value="ambience">环境声</option><option value="ui">界面</option><option value="world">场景与动作</option></select></nav><table><thead><tr><th>声音</th><th>当前处理</th><th>接入</th></tr></thead><tbody id="other"></tbody></table>
<details><summary>旧表哪些项目已合并／暂缓</summary><div id="merged"></div></details><details><summary>剩余由Codex处理</summary><ul id="remaining"></ul></details><p class="muted">技术检查包含实际播放器、曲目切回、暂停、音量、存档与正常WASAPI设备初始化。听感、全曲循环接缝与最终混音仍待验收。此HTML内嵌状态数据，可单独转发离线打开；实际音频沿工程资源另传。</p></main><div id="toast"></div><script id="audio-status-data" type="application/json">__DATA__</script><script>
const D=JSON.parse(document.getElementById('audio-status-data').textContent),$=id=>document.getElementById(id),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function toast(s){$('toast').textContent=s;$('toast').style.display='block';setTimeout(()=>$('toast').style.display='none',1800)}
async function copy(s){try{await navigator.clipboard.writeText(s)}catch(e){const t=document.createElement('textarea');t.value=s;document.body.append(t);t.select();if(!document.execCommand('copy')){t.remove();toast('请手动选择文字复制');return}t.remove()}toast('已复制')}
function row(a){const n=document.createElement('tr');n.innerHTML='<td><b>'+esc(a.id)+'</b><br>'+esc(a.name)+'</td><td>'+esc(a.runtime_mode)+' · '+(a.duration_s===null?'':a.duration_s.toFixed(2)+'秒')+'<br>'+esc(a.status)+'<br><span class="muted">'+esc(a.note)+'</span></td><td><button>复制接入说明</button><details><summary>运行文件</summary><code>'+esc(a.stream)+'</code></details></td>';n.querySelector('button').onclick=()=>copy(a.instruction);return n}
for(const a of D.assets.filter(a=>a.channel==='music'))$('music').append(row(a));
function render(){const channel=$('channel').value;$('other').replaceChildren();for(const a of D.assets.filter(a=>a.channel!=='music'&&(channel==='all'||a.channel===channel)))$('other').append(row(a))}
$('channel').onchange=render;render();for(const m of D.merged){const p=document.createElement('p');p.textContent=m.old+' → '+m.current+'。'+m.reason;$('merged').append(p)}for(const s of D.codex_remaining){const li=document.createElement('li');li.textContent=s;$('remaining').append(li)}
$('copy-summary').onclick=()=>copy('新增人工制作: 0项。\n'+D.assets.filter(a=>a.channel==='music').map(a=>a.instruction).join('\n')+'\n剩余由Codex处理: '+D.codex_remaining.join('；'));
</script></html>'''

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--share',type=Path);args=parser.parse_args();make(args.share)
