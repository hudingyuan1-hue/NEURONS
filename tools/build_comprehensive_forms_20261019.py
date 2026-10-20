"""Build a new audited art register. No game/source-art/legacy-form writes."""
from pathlib import Path
from collections import Counter
from datetime import datetime,timezone,timedelta
import base64, copy, hashlib, io, json, re, shutil, zipfile
from PIL import Image
from build_walk_pose_guides_20261019 import svg_guide,phase_key
from asset_shape_contracts import shape_instruction,spatial_description
from build_runtime_space_templates import FIRST_MESSAGE as SCENE_FIRST_MESSAGE, windows

ROOT=Path(__file__).resolve().parents[1]
DESKTOP=Path('C:/Users/23623/Desktop/NEW/最终表单')
OUT=ROOT/'deliverables/comprehensive_forms_20261019'
WORK=ROOT/'tmp/comprehensive_forms_20261019'
OLD=ROOT/'deliverables/generation_forms_20261019/data'
SPACE=ROOT/'deliverables/space_templates_corrected_20261019'
PAGE='03_全项目美术资产总表_含已有素材_可分享.html'
UI_PAGE='04_UI与功能界面表_可分享.html'

def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def dump(p,d):
 p.parent.mkdir(parents=True,exist_ok=True)
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def stem(s):return re.sub(r'_v\d+$','',Path(s).stem)
def embedded(p,id):
 h=Path(p).read_text(encoding='utf-8-sig')
 return json.loads(re.search(r'<script[^>]*id="'+id+r'"[^>]*>([\s\S]*?)</script>',h).group(1))
def guarded_files():
 files=list((ROOT/'neurons').rglob('*'))+list((ROOT/'DOCX/最终素材').rglob('*'))
 files += [DESKTOP/'01_美术资产表_可分享.html',DESKTOP/'02_声音资产状态_可分享.html',DESKTOP/'NEURONS_美术进度.json']
 return {str(p):sha(p) for p in files if p.is_file() and '.godot' not in p.parts}

LABELS={'accepted':'已有可用','user_supplied':'用户已修订可用','partial':'部分已有可用','edit':'已有，需局改','redo':'已有，需重生','candidate':'已有候选，待验','pending':'待补充','codex':'Codex制作／加工','blocked':'待依据确认','deferred':'暂缓'}
REVIEW_MAP={'retain_visual':'accepted','retain_direction_or_key_pose':'accepted','retain_key_pose_transition_pending':'edit','retain_identity_redesign_task_pose':'edit','retain_identity_reduce_blood_locally':'edit','local_edit_altered_only':'edit','regenerate_altered_only':'redo'}

class Media:
 def __init__(self):self.data={}
 def file(self,p,kind='preview'):
  p=Path(p)
  if not p.exists():return None
  key=kind+'_'+sha(p)[:18]
  if key in self.data:return key
  if kind=='template':
   raw=p.read_bytes();mime='image/png';filename=p.name
  else:
   with Image.open(p) as im:
    im=im.convert('RGB');im.thumbnail((1200,900) if kind=='style' else (560,700))
    b=io.BytesIO();im.save(b,format='JPEG',quality=86 if kind=='style' else 78,optimize=True)
   raw=b.getvalue();mime='image/jpeg';filename=p.stem+'_预览.jpg'
  self.data[key]={'url':'data:'+mime+';base64,'+base64.b64encode(raw).decode(),'filename':filename,'source_filename':p.name,'source_path':str(p),'original_sha256':sha(p),'kind':kind}
  return key
 def vector(self,source,filename):
  raw=source.encode('utf-8');key='pose_'+hashlib.sha256(raw).hexdigest()[:18]
  self.data[key]={'url':'data:image/svg+xml;base64,'+base64.b64encode(raw).decode(),'filename':filename,'source_filename':filename,'kind':'pose','original_sha256':hashlib.sha256(raw).hexdigest()}
  folder=OUT/'pose_guides';folder.mkdir(parents=True,exist_ok=True);(folder/filename).write_bytes(raw)
  return key

def source_assets():
 data=embedded(DESKTOP/'01_美术资产表_可分享.html','table-data')
 return data,{a['id']:a for g in data['groups'] for a in g['items']}

def status_for(parts,a):
 if a.get('blocked'):return 'blocked'
 if a.get('role')=='defer':return 'deferred'
 if not parts:return 'codex' if a.get('role')=='codex' else 'pending'
 ss={p['status'] for p in parts}
 if len(ss)==1:return next(iter(ss))
 if 'accepted' in ss:return 'partial'
 if 'redo' in ss:return 'redo'
 if 'edit' in ss:return 'edit'
 if 'candidate' in ss:return 'candidate'
 return 'pending'

def candidate_record(path,media):
 p=ROOT/path
 if not p.is_file():return None
 return {'filename':p.name,'path':str(p),'sha256':sha(p),'status':'candidate','note':'旧目录已有文件；本轮未逐图认可，先复核，不等于需要重画。','media':media.file(p) if p.suffix.lower() in ['.png','.jpg','.jpeg','.webp'] else None}

def publish_current_entries():
 """Keep legacy content/progress intact, but make its obsolete status explicit."""
 banner='<aside id="neurons-current-form-entry" style="padding:16px 24px;background:#efe2c8;border-bottom:2px solid #8b713c;font:16px/1.7 Microsoft YaHei,sans-serif;color:#382f20"><strong>历史版本，请使用当前03总表。</strong> 本页旧提示词仅作历史保留。 <a href="03_全项目美术资产总表_含已有素材_可分享.html">打开当前完整美术表单</a> · <a href="空间与家具模板/00_空间与家具模板_可分享.html">打开纠正后的空间与家具模板</a></aside>'
 updated=[]
 for name in ['01_美术资产表_可分享.html','02_声音资产状态_可分享.html']:
  path=DESKTOP/name
  if not path.exists():continue
  old=path.read_text(encoding='utf-8-sig')
  page=re.sub(r'<aside id="neurons-current-form-entry"[\s\S]*?</aside>','',old)
  if re.search(r'<body\b',page,re.I):page=re.sub(r'(<body\b[^>]*>)',lambda m:m.group(1)+banner,page,count=1,flags=re.I)
  elif re.search(r'<main\b',page,re.I):page=re.sub(r'(<main\b)',lambda m:banner+m.group(1),page,count=1,flags=re.I)
  else:page=banner+page
  if page==old:continue
  history=DESKTOP/'历史';history.mkdir(exist_ok=True)
  backup=history/(path.stem+'_新版入口前_'+hashlib.sha256(old.encode()).hexdigest()[:10]+'.html')
  if not backup.exists():backup.write_text(old,encoding='utf-8')
  path.write_text(page,encoding='utf-8');updated.append(name)
 launch='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=03_全项目美术资产总表_含已有素材_可分享.html"><title>打开最新NEURONS美术表单</title><p><a href="03_全项目美术资产总表_含已有素材_可分享.html">打开当前完整美术表单</a></p><p><a href="空间与家具模板/00_空间与家具模板_可分享.html">纠正后的空间与家具模板</a></p></html>'
 (DESKTOP/'打开最新表单.html').write_text(launch,encoding='utf-8')
 return updated

def apply_production_policy(data):
 data['production_policy']={'current_owner':'codex','scope':'剩余人物、动作、场景、家具物件、UI、通用效果均由Codex生产加工；用户不必继续逐帧生成。','preserve':'已认可具体文件与用户已修订异化保留；异化不再评估。','main_animation':'主角只制作一套服装动作并用于全关；其他衣装仅留静态来源或历史，不增加独立动作序列。','single_main_mother':'CHR_MAIN','history':'资产ID与原始责任保留在origin_role；当前责任写current_owner，不删旧进度。'}
 for a in data['items']:
  a.setdefault('origin_role',a.get('role'));a['current_owner']='codex'
  if a['category']=='动作' and a['id'].startswith('CHR_MAIN_'):
   a.setdefault('origin_mother_choices',a.get('mother_choices',[]))
   a['mother_choices']=['CHR_MAIN'];a['mother']='CHR_MAIN'
   a['production_reuse']='单一主角衣装动作跨关复用；原其他衣装选项仅作历史来源，不另下序列订单。'
 return data

def build_data():
 old=read(OLD/'non_scene_items.json');scene=read(OLD/'scene_items.json')
 src,source=source_assets();audit=read(ROOT/'tmp/review_20261019_assets/review_decisions.json')
 char=read(WORK/'character_overrides.json');sov=read(WORK/'scene_overrides.json');ui=read(WORK/'ui_items.json')
 rows=copy.deepcopy(old['items']+scene['items']);media=Media()
 snapshot_paths=sorted((ROOT/'DOCX/最终素材').rglob('*.png'))
 snapshot_at=datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds')
 reviewed={str(ROOT/Path(r['file'])):r for r in audit['files']}
 reviewed_content={(stem(Path(r['file']).name),r['sha256']):r for r in audit['files']}
 # Resolve by exact stable component stem, ignoring only version suffix.
 owned=set();file_records=[]
 for p in snapshot_paths:
  r=reviewed.get(str(p)) or reviewed_content.get((stem(p.name),sha(p)));state=REVIEW_MAP.get(r['status'],'candidate') if r else 'candidate'
  rec={'filename':p.name,'path':str(p),'sha256':sha(p),'status':state,'note':r['note'] if r else '本轮逐图清单之后新增，尚待核验。','media':media.file(p),'original_audit_source':str(p) in reviewed and reviewed[str(p)]['sha256']==sha(p)}
  # These event images are usable keys; only the P03 hand continuity needs editing.
  if r and r['sha256']==rec['sha256'] and re.match(r'CHR_OTHER_NPCS_N04_ACTION_FIRST__event__P0[124]_v',p.name):
   rec.update(status='accepted',note='已有可用事件关键姿态；保持本图，优先局修P03持夹手以衔接，不重画本图。')
  elif r and r['sha256']==rec['sha256'] and re.match(r'CHR_OTHER_NPCS_N04_ACTION_FIRST__event__P03_v',p.name):
   rec.update(status='edit',note='只局修手与夹板：继承P02托夹手，另一手移到家庭栏，其他造型与画布保留。')
  if r and r['sha256']!=rec['sha256']:
   rec['status']='candidate';rec['note']='此文件已在审查后变更；沿旧版结论不自动认可当前版本。'
  if '_ALTERED_v' in p.name and (not r or r['sha256']!=rec['sha256']):
   rec.update(status='user_supplied',note='用户已明确完成本版异化修订并要求不再评估；作为可用源图保留，仅待透明、尺度、锚点、拆层与游戏技术导入检查，不发重生订单。',approval_source='explicit user instruction after initial asset audit')
  file_records.append(rec)
 versions={}
 for r in file_records:versions.setdefault(stem(r['filename']),[]).append(r)
 def version_order(r):
  number=re.search(r'_v(\d+)(?:\.[^.]+)?$',r['filename'])
  return (int(number.group(1)) if number else 0,-len(Path(r['path']).parts),r['path'])
 for component,records in versions.items():
  if not component.endswith('_ALTERED'):continue
  latest=max(version_order(r)[0] for r in records)
  for r in records:
   if version_order(r)[0]==latest and r['status']!='accepted':
    r['historical_review_status']=r['status'];r['historical_review_note']=r['note']
    r.update(status='user_supplied',note='用户已明确当前命名的异化版本已修订完成，不再评估或重生；仅待技术导入检查。',approval_source='explicit user instruction after initial asset audit')
 # An added, unreviewed version cannot silently replace an approved source.
 # For unfinished components, newest candidates remain visible with all older
 # versions attached, never promoted to approval by their v-number.
 lookup={key:max([r for r in records if r['status']=='accepted'],key=lambda r:(r.get('original_audit_source',False),version_order(r))) if any(r['status']=='accepted' for r in records) else max([r for r in records if r['status']=='user_supplied'] or records,key=version_order) for key,records in versions.items()}
 for a in rows:
  a.setdefault('clips',[]);a.setdefault('tasks',[]);a['existing']=[];a['parts']=[]
  ov=char.get('by_id',{}).get(a['id'],{})
  a.update(copy.deepcopy(ov))
  a.update(copy.deepcopy(sov.get('by_id',{}).get(a['id'],{})))
  if a['category']=='场景':
   # Legacy screen-side warnings must not contradict the corrected text.
   a['conflict_note']=sov.get('by_id',{}).get(a['id'],{}).get('conflict_note','')
   if a.get('runtime_id') in ['L2_ward','L3_ward']:
    a['conflict_note']='旧房间文案记有采光窗，但当前运行合同没有该窗；由Codex核源并校正几何后再定，不把这一冲突转成人工反复重画。现有候选先保留，本条不宣称窗位已冻结。'
    a['blocked']=True
  a['category']='场景' if a.get('runtime_id') else a['category']
  # Prefer current edited source filename stems over obsolete generated mother versions.
  if a['clips']:
   for c in a['clips']:
    for i,p in enumerate(c['poses']):
     if re.fullmatch(r'CHR_MAIN_WALK_D[0-3]',a['id']) and c['key']=='walk':
      direction=int(a['id'][-1]);phase=phase_key(p)
      p['guide_media']=media.vector(svg_guide(direction,phase),f'WALK_D{direction}_{phase}_姿态参照.svg')
     key=f"{c['key']}::{i}";r=lookup.get(stem(p['filename']))
     reuse=p.get('reuse_from')
     if a['id']=='CHR_OTHER_NPCS_FATHER_ACTION_FIRST' and c['key']=='release' and i==0:
      reuse='CHR_OTHER_NPCS_FATHER_ACTION_FIRST__reach__P02_v004.png'
      p['reuse_from']=reuse
     if not r and reuse:
      origin=lookup.get(stem(reuse))
      if origin and origin['status']=='accepted':
       r=copy.deepcopy(origin);r['note']='已有可复用：沿已认可的'+origin['filename']+'保持／起接，无需另画相同姿态。'
     part={'key':key,'label':c['label']+' · '+p['label'],'filename':p['filename'],'status':'pending','clip':c['key'],'pose_index':i,'optional':bool(p.get('optional'))}
     if r:part.update(copy.deepcopy(r));a['existing'].append(copy.deepcopy(r));owned.add(r['path'])
     if reuse:part['reuse_from']=reuse
     if a['id']=='CHR_OTHER_NPCS_FATHER_ACTION_FIRST' and c['key']=='release' and i==2 and not r:
      part.update(status='codex',note='先沿同方向正常基姿组合归位；只在实际缺少可见肢体表面时补局部。')
      p['codex_first']=True
     a['parts'].append(part)
  elif a['tasks']:
   for t in a['tasks']:
    r=lookup.get(stem(t['filename']));part={'key':t['key'],'label':t['name'],'filename':t['filename'],'status':'pending'}
    if r:part.update(copy.deepcopy(r));a['existing'].append(copy.deepcopy(r));owned.add(r['path'])
    a['parts'].append(part)
  else:
   r=lookup.get(stem(a.get('filename',a['id']))) or lookup.get(a['id'])
   if r:
    a['existing'].append(copy.deepcopy(r));owned.add(r['path']);a['parts'].append({'key':'main','label':a['name'],**copy.deepcopy(r)})
  # Existing old candidates remain visible; they are never called approved without review.
  for p in source.get(a['id'],{}).get('existing',[]):
   r=candidate_record(p,media)
   if r and all(r['path']!=x['path'] for x in a['existing']):a['existing'].append(r)
  components={stem(a.get('filename',a['id'])),a['id']}
  components.update(stem(p['filename']) for c in a['clips'] for p in c['poses'])
  components.update(stem(t['filename']) for t in a['tasks'])
  for component in components:
   for r in versions.get(component,[]):
    owned.add(r['path'])
    if all(r['path']!=x['path'] for x in a['existing']):a['existing'].append(copy.deepcopy(r))
  if not a['parts'] and a['existing']:
   a['parts']=[{'key':'main','label':a['name'],**copy.deepcopy(a['existing'][0])}]
  if a['id']=='CHR_OTHER_NPCS_N02' and a['parts']:
   a['parts'][0].update(status='edit',label='任务道具与手部',note='保留正常身份与衣装，只把持续持束带改为核对夹的实际工作姿态。')
   identity=next((f for f in a['existing'] if f['filename']=='CHR_OTHER_NPCS_N02_v001.png' and reviewed_content.get((stem(f['filename']),f['sha256']))),a['existing'][0])
   a['parts'].append({'key':'identity','label':'正常身份、脸型与衣装','status':'accepted','filename':identity['filename']})
   identity.update(status='partial',note='本具体版本的身份、脸型与衣装已有可用；任务道具与手部局改。新增版本另列候选，不沿用此认可。')
  for part in a['parts']:
   if part['status']=='pending' and a['role']=='codex':part['status']='codex'
  a['review_status']=status_for(a['parts'],a)
  unique={}
  for f in a['existing']:
   key=(f['filename'],f['sha256'])
   if key in unique:unique[key].setdefault('alternate_paths',[]).append(f['path'])
   else:unique[key]=f
  a['existing']=list(unique.values())
  # Override interpretation of newly reviewed atrium: candidate, not approved texture.
  if a['id']=='ENV_ROOM_L4_ATRIUM_ALTERED' and a['existing']:
   a['review_status']='edit'
   for p in a['parts']:p.update(status='edit',note='画法可留；现图仅有后/前两处明确开口，须补齐本房四条连接，减轻肉色沟槽。')
   for p in a['existing']:p.update(status='edit',note='画法可留；结构连接尚未通过。')
  a['review_label']=LABELS[a['review_status']]
  a['new_filename']=next_version(a.get('filename',a['id']+'_v001.png'),a['existing'])
  a['legacy_progress']=copy.deepcopy(src.get('initial',{}).get(a['id'],{}))
  a['audit_scope']='造型／关键姿态认可，不代表透明、动画连播、实机接触或正式接入已验收。'
  a['source_existing']=[str(p) for p in source.get(a['id'],{}).get('existing',[])]
  new_candidates=[f for f in a['existing'] if f['status']=='candidate' and '本轮逐图清单之后新增' in f.get('note','')]
  if new_candidates:a['new_candidates_note']='本项有本轮期间新增的候选版本，尚未逐图审查；不要因版本号较新就当作已认可，也不必先重复生成。已有可用结论只适用于下方明确标注的具体文件／hash。'
  if a['id'].endswith('_ALTERED') and any(f['status']=='user_supplied' for f in a['existing']):
   a['note']='用户已完成异化修订，不再进行审美评估或重复生图；保留明确的用户修订版本，Codex只做技术导入与动作接入。旧版问题记录仅留在对应历史文件下。'
   a['pending']=''
   a['checks']=['透明、比例、锚点、拆层与实际接触按运行用途验证；不重评用户已修订造型。']
 for a in ui['items']:
  for key in ['prompt','content','upload']:a[key]=a.get(key,'').replace('\\n','\n')
  a['parts_to_make']=a.get('parts',[])
  a.update(review_status='codex',review_label=LABELS['codex'],clips=[],tasks=[],parts=[],existing=[],filename=a['id']+'_v001.png',new_filename=a['id']+'_v001.png',scope=a.get('scope','全游戏UI'),audit_scope='功能已实现；本条正式视觉与状态仍待制作验收。')
  rows.append(a)
 for e in old['effects']:
  a=copy.deepcopy(e);a.update(copy.deepcopy(char.get('effect_overrides',{}).get(e['id'],{})))
  a.update(category='通用效果与接入',group='真实事件与占位替换',role='codex',content=a.get('method',''),upload='优先沿本条列出的已认可主体分层、遮罩或复用；只有加工无法达到验收点时，才补本条明确的一张局部或终态。',review_status='codex',review_label=LABELS['codex'],clips=[],tasks=[],parts=[],existing=[],filename=e['id']+'_v001.png',new_filename=e['id']+'_v001.png',checks=[a.get('acceptance','')],note=a.get('manual',''))
  rows.append(a)
 # Link each actual furniture locator to production asset IDs, using names/old scene choices.
 anchors=read(SPACE/'template_anchors.json');runtime=read(SPACE/'runtime_spaces.json')
 rt={r['id']:r for r in runtime['rooms']};spaces={};locators=[]
 for ar in anchors:
  rid=ar['id'];r=rt[rid];folder=SPACE/'png'/rid
  spaces[rid]={'id':rid,'title':r['title'],'size':r['size_m'],'floor_polygon_m':r.get('space_spec',{}).get('floor_polygon_m'),'floor_holes_m':r.get('space_spec',{}).get('floor_holes_m',[]),'shape_description':spatial_description(r),'wall':r.get('physical_wall',{}),'presentation':r.get('presentation',{}),'space_media':media.file(folder/ar['room_png'],'template'),'placement_media':media.file(folder/(rid+'_placement.png'),'template'),'furniture':[]}
  for f in ar['furniture']:
   x=copy.deepcopy(f);x['room_id']=rid;x['room_title']=r['title'];x['media']=media.file(folder/f['filename'],'template');spaces[rid]['furniture'].append(x);locators.append(x)
 # Explicit room/locator links replace name substring matches that confuse beds/chairs/boxes.
 links=read(WORK/'placement_links.json');locator_index={(f['room_id'],f['id']):f for f in locators}
 for a in rows:
  if a['category']!='家具与物品':continue
  choices=[];derived_context=[]
  for link in links['by_asset'].get(a['id'],[]):
   key=(link['room_id'],link['furniture_id'])
   if key not in locator_index:
    rr=rt.get(link['room_id'],{});legacy=next((f for f in rr.get('furniture',[])+rr.get('decor',[]) if f.get('id')==link['furniture_id']),None)
    absorbed={('L4_bridge','bridge_fibers'):'桥下纤维已成为真实桥体外背景；不再从旧长方形体积单独生成。',('L5_bridge','bridge_fibers'):'同房桥下纤维背景沿当前哑铃桥与桥外空隙组织。',('L5_brainstem','brainstem_guard_w'):'旧西侧直护栏已改为当前圆井沿的连续弧形构造。',('L5_brainstem','brainstem_guard_e'):'旧东侧直护栏已改为当前圆井沿的连续弧形构造。'}
    if legacy is not None and (legacy.get('render') is False or legacy.get('logical_exclusion')):
     a.setdefault('archived_placements',[]).append({**link,'note':'保留旧稳定ID与资产记录；本处已不显示，不再提供误导性的生成定位图。'})
     continue
    if key in absorbed or legacy is not None and float(legacy.get('height_m',0))<=.02:
     reason=absorbed.get(key,'本处是贴地薄层／表面覆盖，不是独立高体积物件；沿当前地面和材质生成薄层，不能拉成方盒。')
     a.setdefault('archived_placements',[]).append({**link,'note':reason})
     derived_context.append({'room_id':key[0],'asset_id':a['id'],'room_title':spaces[key[0]]['title'],'media':spaces[key[0]]['placement_media'],'reason':reason})
     continue
    raise ValueError('Unresolved current furniture locator: '+a['id']+' '+str(key))
   f=copy.deepcopy(locator_index[key]);f.update(link);choices.append(f)
  for asset_id,rid in [('ENV_ALL_023','L2_ward'),('ENV_ALL_056','L3_ward')]:
   if a['id']!=asset_id:continue
   key=(rid,'ward_sink')
   if key in locator_index and not any(f['room_id']==rid and f['id']=='ward_sink' for f in choices):
    f=copy.deepcopy(locator_index[key]);f.update(room_id=rid,furniture_id='ward_sink',match_kind='exact_or_named_alias',reason='依用户文档恢复的病房洗手池，复用已有同类洗手池资产，不增加重复人工订单。',generation_note='沿本处病房洗手池的支点、盆口和水龙头绘制；不把盆腔填成方箱。',source='document-based spatial rebuild runtime export');choices.append(f)
  a['placements']=choices
  a['placement_context']=[{**c,'room_title':spaces[c['room_id']]['title'],'media':spaces[c['room_id']]['placement_media']} for c in links['context_only'] if c['asset_id']==a['id']]+derived_context
  a['shape_family'],a['construction']=shape_instruction(a)
  a['placement_note']='选择实际使用处，只下载该处结构参照；落脚与操作空间由Codex配置。长深高是容纳范围，支腿、弧面、圆形、孔洞和薄板按本物真实构造，不能把参照填成实心方盒。同族派生按本处名称与用途。' if choices else '本物不采用其他家具的总体积。只取实际容纳处或接触处局部，不必附整房；小道具按自身弧度、薄厚与孔洞绘制。'
 # Architectural locators are assigned to fixed scene art, not a new furniture order.
 for a in rows:
  if a['category']!='场景':continue
  fixed=[x for x in links['unmapped'] if x['room_id']==a.get('runtime_id') and x['kind'] in ['fixed_architecture','architecture_surface']]
  if fixed:
   a['fixed_architecture']=fixed
   line=re.search(r'占位不画入：([^\n]*)',a['content'])
   if line:
    new=line.group(1)
    for x in fixed:new=new.replace(x['name']+'、','').replace('、'+x['name'],'').replace(x['name']+'；','')
    a['content']=a['content'].replace(line.group(0),'占位不画入：'+new)
   a['content']+='\n本房固定建筑另外画入：'+'；'.join(x['name']+'（'+x['reason']+'）' for x in fixed)+'。'
  if a.get('runtime_id')=='HIDDEN_PLAZA':
   a['content']+='\n隐藏广场不画两扇独立房门：卧室来向是既有入场边界，E1是街段尽头事件阈值。沿定位保留边界落脚地面，不凭通路标记增加门框。'
 for a in rows:
  if a['id']=='ENV_ALL_172':
   a['content']='画本项目后期空间中独立的异化结构块：沿实际位置与体积，以灰白、冷灰紫和少量暗粉的大折面、纤维走向及层叠表皮表现压力和有机变化。轮廓和可操作面有真实变化，不只是把正常物件染红。表面完整，无鲜血、开放创面、外露骨肉或器官；不与人物身体融合。'
   a['note']='沿当前空间与同族造型局部派生；不沿旧血肉创面提示词生成。'
  if a['id']=='VIS_ENV_ALTER':
   a['checks']=['保持同一房间入口、通路与必要接触点；异化通过轮廓、折面、纤维、明暗和局部遮挡变化可读，不能只染红。','不出现开放创面、鲜血或外露组织；完整表面，保留原事件和功能。']
   a['acceptance']='同一空间结构与接触关系可用，异化有形体变化；完整非血腥表面，不只红染。'
   a['prompt']='由Codex沿已认可同房底图分层派生后期状态；以结构折面、完整纤维表皮、局部色温和明暗变化表达异化，保留入口、通路和可操作面；不绘制血肉创面或外露组织。'
 final=read(WORK/'final_scene_corrections.json')
 for a in rows:
  a.update(copy.deepcopy(final.get('by_id',{}).get(a['id'],{})))
  a.update(copy.deepcopy(final.get('non_scene',{}).get(a['id'],{})))
 # The edited legacy JSON is history, not a second current geometry authority.
 # Rebase scenes LAST, after all legacy overrides, from the exact same contract
 # that produced this build's downloadable runtime templates.
 contracts={c['id']:c for c in read(SPACE/'scene_generation_contracts.json')}
 for a in rows:
  rid=a.get('runtime_id')
  if rid in contracts:
   c=contracts[rid];r=rt[rid]
   a.update(content=c['prompt'],prompt=c['prompt'],connection_text=c['connection_text'],shape_description=c['shape_description'],geometry_version=c['version'])
   a['upload']='按顺序只附两张：图1＝本页已确认画法样板；图2＝下方本房当前空间定位图。图1只负责斜侧观看、连续表面、近侧剖切及色块笔触，不借卧室房型；图2负责实际地面轮廓、洞口、通路、支点与机位。家具摆放核对图不用上传。' if not c['reuse'] else '按顺序只附两张：图1＝已确认同房基础图；图2＝下方本房当前空间定位图。图1锁同一画布和画法；图2核本房真实入口、地面、沟井和操作位。尚无合格基础图，先做本房基础项。家具摆放核对图不用上传。'
   a['note']='本项文字和模板同步来自纠正后的运行空间；形状、连接按文档落到实际几何。物件留位不等于家具外形，也不把矩形外围范围补成方房。'
   a['conflict_note']=''
   if rid in ['L2_ward','L3_ward'] and not windows(r):
    a['conflict_note']='本房采光窗尚未落入运行导出；不将未核冲突转成人工重画，须先修正运行几何。'
    a['blocked']=True
   else:a.pop('blocked',None)
   a['review_status']=status_for(a['parts'],a);a['review_label']=LABELS[a['review_status']]
   a['checks']=['实际入口、沟井、桥廊与可走地面和本房定位一致，不补平成矩形。','近侧与左侧剖切便于活动和搜寻；曲墙与转角连续，不出现拼块缝。','可移动家具独立，移开后固定底图完整，操作位和触点可达。']
  if a['category']=='家具与物品':
   a['shape_family'],a['construction']=shape_instruction(a)
   for p in a.get('placements',[]):
    p.setdefault('shape_family',shape_instruction(p)[0]);p.setdefault('construction',shape_instruction(p)[1])
   if a['id']=='ENV_ALL_172' and not a.get('placements'):
    a.update(name='异常附着痕迹：墙地背景贴层',role='codex',content='由Codex在当前Street墙地背景上制作低对比附着痕迹：沿实际墙面或地面延展的完整纤维表皮、灰紫色温与少量浅凹纹理。保持透明薄层，不塑造成凸出方块、器官或新障碍；不影响既有通路。',construction='本处是约0.015米的表面贴层，随墙地展开，不是有厚度的独立柜块；光影和腐朽变化用场景分层／Shader加工。',note='当前四个来源均是附着墙地的低位痕迹，由Codex制作；保留原ID和旧进度，不追加人工独立物件订单。',quantity='Codex背景加工；无新增人工出图任务')
    a['review_status']=status_for(a['parts'],a);a['review_label']=LABELS[a['review_status']]
 supplied_mothers={a['id'] for a in rows if a['id'].endswith('_ALTERED') and any(f['status']=='user_supplied' for f in a.get('existing',[]))}
 for a in rows:
  if a['category']=='动作' and a.get('mother') in supplied_mothers and a['id'].endswith('_ACTION_ALTERED'):
   a.pop('blocked',None);a['pending']=''
   a['review_status']=status_for(a['parts'],a);a['review_label']=LABELS[a['review_status']]
   a['note']='采用用户已修订的同角色异化母图；不再评估母图，只按真实动作接触和技术接入需要处理。'
 # Only approved style pictures selected by user; distinct from per-room geometry.
 style_files=[ROOT/'DOCX/新建文件夹/ENV_ROOM_L1_ROOM_BASE_v001.png',ROOT/'DOCX/新建文件夹/dc3eba99-ce86-428f-81ef-e84724936df1.png']
 styles=[{'name':'空房画法与近墙处理' if i==0 else '人物／家具落地与绘画语言','media':media.file(p,'style'),'path':str(p),'note':'只借斜侧观看、连续转角、近侧低墙与嵌墙窗、冷暖笔触；本房结构与物品位置按当前条目。'} for i,p in enumerate(style_files) if p.exists()]
 orphan=[r for r in file_records if r['path'] not in owned]
 if orphan:raise ValueError('Unmapped final assets: '+str([(r['filename']) for r in orphan]))
 original={x['id'] for x in old['items']+scene['items']};ids=[a['id'] for a in rows]
 assert len(ids)==len(set(ids)), 'duplicate IDs'
 assert original.issubset(ids) and len(original)==579
 return {'schema_version':4,'kind':'NEURONS_COMPREHENSIVE_ART_FORM','title':'NEURONS 全项目美术资产总表','version':str(runtime.get('generated_at','2026-10-20'))[:10]+' · 文档空间重构与真实物件构造修订','items':rows,'labels':LABELS,'media':media.data,'spaces':spaces,'styles':styles,'style_links':old['style_links'],'first':char.get('first',old['first']),'ui_first':ui['first'].replace('\\n','\n'),'scene_first':SCENE_FIRST_MESSAGE,'char_style':char.get('character_style',old['char_style']),'prop_style':old['prop_style'],'story_style':old['story_style'],'action_method':char.get('action_method',''),'initial':old.get('initial',{}),'source_progress':src.get('source_progress',{}),'source_progress_files':{'desktop':read(DESKTOP/'NEURONS_美术进度.json')},'review_summary':{'files':len(file_records),'characters':sum('人物' in Path(f['path']).parts for f in file_records),'actions':sum('动作' in Path(f['path']).parts for f in file_records),'new_scene':sum('场景' in Path(f['path']).parts for f in file_records),'original_audit_files':187,'new_files_since_previous_audit':max(0,len(file_records)-187),'new_files_audited_this_spatial_task':0,'user_revised_altered_files':sum(f['status']=='user_supplied' for f in file_records),'altered':audit['altered_totals'],'ui_items':len(ui['items']),'original_items':579,'effects':len(old['effects']),'legacy_candidates':sum(1 for a in rows for f in a['existing'] if f['status']=='candidate')},'missing_existing':audit['missing_files_to_check_not_automatic_new_orders'],'coverage':ui.get('coverage',{}),'inventory_snapshot':{'captured_at':snapshot_at,'timezone':'Asia/Shanghai','scope':'构建开始时冻结的本轮素材版本；之后新增由资产生产阶段接收。','files':[{k:v for k,v in f.items() if k!='media'} for f in file_records]},'review_scope':'已认可指具体版本的造型／姿态可用；用户已修订的异化不再评估，技术导入仍验。代码占位不算正式美术完成。'}

def next_version(filename,existing):
 v=[int(x) for s in [filename]+[x['filename'] for x in existing] for x in re.findall(r'_v(\d+)',s)]
 return re.sub(r'_v\d+(?=\.[^.]+$)',f'_v{max(v+[1])+1:03d}',filename) if re.search(r'_v\d+',filename) else Path(filename).stem+'_v002'+Path(filename).suffix

HTML='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__TITLE__</title><style>
:root{--ink:#28352f;--muted:#67726b;--paper:#f5f3ed;--line:#d3dbd2;--green:#345b4f;--wash:#e8ede5;--red:#934e38;--gold:#9a7629}*{box-sizing:border-box}[hidden]{display:none!important}body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.65 "Microsoft YaHei","Segoe UI",sans-serif}header,main{max-width:1160px;margin:auto;padding:22px 28px}header{padding-bottom:12px}h1{font-size:27px;margin:0 0 8px}h2{font-size:18px}h3{font-size:16px;margin:8px 0}p{margin:8px 0}small,.meta{font-size:13px;color:var(--muted)}a{color:#32675c}button,select,input,textarea{font:inherit}button{border:1px solid var(--line);background:white;padding:7px 12px;border-radius:5px;color:var(--ink);cursor:pointer}button:hover{border-color:var(--green)}button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,summary:focus-visible{outline:3px solid #d8b66c;outline-offset:2px}.primary{background:var(--green);color:white;border-color:var(--green)}button:disabled{opacity:.5;cursor:default}.bar,.filters,.actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.bar{margin:14px 0}.filters{position:sticky;top:0;z-index:5;padding:12px;background:#f5f3edf5;border-block:1px solid var(--line)}input,select{padding:7px 9px;border:1px solid var(--line);border-radius:4px;background:white;max-width:100%}#search{flex:1;min-width:180px}.counts{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}.stat{padding:8px 12px;background:white;border:1px solid var(--line);border-radius:5px}.stat b{font-size:19px;margin-right:5px}.note,.warn,.existing-note{padding:10px 13px;border-radius:4px;background:var(--wash);margin:10px 0}.warn{background:#f3e9dc;border-left:3px solid var(--gold)}.existing-note{background:#e5eee9;border-left:3px solid var(--green)}article{margin:10px 0;background:white;border:1px solid var(--line);border-radius:6px;overflow:hidden}summary{cursor:pointer;padding:12px 14px;font-weight:650}details>summary{list-style-position:inside}.panel{padding:0 16px 16px;border-top:1px solid #e8eae4}details.inner{border:1px solid var(--line);margin:10px 0;border-radius:4px}details.inner>div{padding:0 12px 12px}.badge{font-size:12px;font-weight:500;border-radius:3px;display:inline-block;padding:1px 7px;background:#eee;margin-left:8px}.badge.accepted{color:#285a42;background:#e0efe2}.badge.edit,.badge.partial{color:#805d13;background:#f5eaca}.badge.redo{color:#8c3f30;background:#f4dfd7}.badge.codex{color:#355d78;background:#e1edf3}.badge.blocked{color:#74424e;background:#f2e3e9}.lead{font-size:14px;color:var(--muted)}textarea.prompt{display:block;resize:vertical;width:100%;min-height:190px;padding:10px;margin:10px 0;border:1px solid var(--line);border-radius:4px;background:#fcfcf9;font-size:14px;line-height:1.7}.preview-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}.figure{padding:10px;border:1px solid var(--line);border-radius:4px;min-width:0}.figure img{display:block;max-width:100%;height:250px;object-fit:contain;background:#ecece5;margin:auto}.figure.template img{height:auto;max-height:470px;width:100%;object-fit:contain}.file{word-break:break-all;font-size:12px;font-family:Consolas,monospace}.checklist{margin:6px 0;padding-left:22px}.parts{width:100%;border-collapse:collapse;font-size:13px}.parts th,.parts td{text-align:left;border-bottom:1px solid #e3e7df;padding:8px;vertical-align:top}.progress{margin-top:14px;padding-top:12px;border-top:1px solid var(--line)}.progress input{width:min(450px,100%)}.progress textarea{width:100%;height:55px;margin-top:8px;border:1px solid var(--line);padding:8px}.prompt-layout{display:grid;grid-template-columns:1fr;gap:10px}.selectline{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0}.selectline label{display:flex;gap:6px;align-items:center}.empty{text-align:center;padding:35px;color:var(--muted)}#toast{position:fixed;bottom:20px;left:50%;transform:translateX(-50%);padding:9px 18px;background:#263e35;color:white;z-index:20;border-radius:5px;max-width:90vw}footer{padding:16px 0;color:var(--muted);font-size:13px}.first{background:white;padding:12px;border:1px solid var(--line);border-radius:5px}.first>summary{padding:0}#intro-actions button{font-size:13px}@media(max-width:650px){header,main{padding:14px}.filters{position:static}.filters select{width:48%;flex:1}.figure img{height:210px}.parts td,.parts th{padding:6px}h1{font-size:22px}.hide-small{display:none}}@media print{.filters,.bar,.actions,.progress{display:none}.panel{display:block}body{background:white}}
</style></head><body><header><h1>__TITLE__</h1><p class="lead">已认可的素材保留在表中；只补缺项，只改未通过的部分。<span id="version"></span></p><p class="note">剩余资产由Codex统一生产、加工和接入，你不必继续逐帧生成。主角只做一套服装动作供全关使用；用户已修订异化保留，不再评估。</p><div class="counts" id="stats"></div><p class="meta">“已有可用”指造型／关键姿态认可；去底、比例、锚点、连播和实机接触仍由Codex加工验收。音乐按已完成处理，本表不追加音乐订单。</p><div class="bar"><button id="export">导出进度</button><button id="filled">导出填写版网页</button><button id="import">导入旧／新进度</button><input hidden type="file" id="importfile" accept=".json"><button id="all">查看完整清单</button></div><details class="first"><summary>新对话首次说明与统一画风</summary><div class="bar"><button id="first-copy" class="primary">复制通用首次说明</button><button id="scene-first-copy">复制场景首次说明</button></div><textarea readonly class="prompt" id="firsttext"></textarea><p class="meta">随后只按当前条目上传所需图片。画法样板不负责物品摆位，空间模板不负责墙面装饰。</p><div id="stylelinks"></div><div id="stylepreviews"></div></details></header><main><div class="filters"><select id="category" aria-label="资产类别"></select><select id="group" aria-label="分组"></select><select id="status" aria-label="审查状态"></select><select id="owner" aria-label="制作责任"><option value="">全部责任</option><option value="human">你制作主体</option><option value="codex">Codex制作／加工</option><option value="conditional">按需补图</option><option value="defer">暂缓</option></select><input id="search" placeholder="搜索名称、编号、文件名" aria-label="搜索资产"><span id="count" class="meta"></span></div><div id="context"></div><section id="items" aria-live="polite"></section><footer>本页包含内嵌预览与模板，可单独分享。原图保持原文件；预览不冒充精灵成品。网页进度只保存在当前浏览器，换电脑请导出进度或填写版。旧进度导入后保留原始字段，不自动把功能通过改成美术认可。</footer></main><div id="toast" hidden role="status"></div><script id="form-data" type="application/json">__DATA__</script><script>__RUNTIME__</script></body></html>'''

def render(data,ui_only=False):
 d=copy.deepcopy(data)
 if ui_only:
  d['items']=[a for a in d['items'] if a['category']=='UI与功能界面'];d['spaces']={}
  used={s['media'] for s in d['styles']}
  used.update(r['media'] for a in d['items'] for r in a.get('required_media',[]))
  used.update(r['media'] for a in d['items'] for r in a.get('reuse_media',[]))
  d['media']={k:v for k,v in d['media'].items() if k in used}
  d['title']='NEURONS UI与功能界面美术表'
 d['ui_only']=ui_only
 payload=json.dumps(d,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
 page=HTML.replace('__TITLE__',d['title']).replace('__DATA__',payload).replace('__RUNTIME__',(ROOT/'tools/comprehensive_form_runtime.js').read_text(encoding='utf-8'))
 page=page.replace('</style>','@media(max-width:650px){.filters select{flex:0 0 calc(50% - 4px);width:calc(50% - 4px);min-width:0}#search{flex:1 0 100%;width:100%}}</style>')
 if d.get('ui_generation'):
  page=page.replace('剩余资产由Codex统一生产、加工和接入，你不必继续逐帧生成。主角只做一套服装动作供全关使用；用户已修订异化保留，不再评估。','UI 图层由你生成，Codex负责切片、文字、真实控件与接入；其余资产沿原分工。已认可素材继续复用，用户已修订异化不再评估。')
  page=page.replace('随后只按当前条目上传所需图片。画法样板不负责物品摆位，空间模板不负责墙面装饰。','随后只上传本项列出的参考图。画法图只取笔触与色彩，功能分区图只取位置与留空；不把旧 UI 外观或参考游戏角色照搬进成图。')
 return page.replace('<button id="scene-first-copy">复制场景首次说明</button>','<button id="scene-first-copy">复制场景首次说明</button><button id="ui-first-copy">复制UI首次说明</button>')

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 before=guarded_files();data=apply_production_policy(build_data())
 dump(OUT/'data/comprehensive_assets.json',data)
 dump(OUT/'data/inventory_snapshot.json',data['inventory_snapshot'])
 dump(OUT/'data/active_spatial_contracts.json',{'source':'Current runtime-derived templates supersede legacy scene_overrides and final_scene_corrections geometry.','runtime_sha256':sha(SPACE/'runtime_spaces.json'),'scene_contract_sha256':sha(SPACE/'scene_generation_contracts.json'),'scenes':{a['id']:{'runtime_id':a['runtime_id'],'geometry_version':a.get('geometry_version'),'connection_text':a.get('connection_text'),'shape_description':a.get('shape_description')} for a in data['items'] if a.get('runtime_id')},'placements':{a['id']:[{k:v for k,v in p.items() if k!='media'} for p in a.get('placements',[])] for a in data['items'] if a['category']=='家具与物品'}})
 for name,only in [(PAGE,False),(UI_PAGE,True)]:
  html=render(data,only);(OUT/name).write_text(html,encoding='utf-8');(DESKTOP/name).write_text(html,encoding='utf-8')
 dump(OUT/'data/review_decisions.json',read(ROOT/'tmp/review_20261019_assets/review_decisions.json'))
 for name in ['character_overrides.json','scene_overrides.json','ui_items.json','placement_links.json','coverage_notes.json','final_scene_corrections.json']:shutil.copy2(WORK/name,OUT/'data'/name)
 info='新版入口：'+PAGE+'\nUI专表：'+UI_PAGE+'\n已认可素材仍列入并显示已有可用；部分认可只补剩余部分。\n默认先看需处理项目，点查看完整清单可显示已有可用。\n本次同步文档空间、运行模板和逐物件真实构造；原图和旧进度保留。01/02旧页增加新版入口，旧提示词只作历史。\n本表进度可以导入/导出；同一浏览器延续原进度。\n'
 (OUT/'使用说明.txt').write_text(info,encoding='utf-8')
 (DESKTOP/'新版完整表单_使用说明.txt').write_text(info,encoding='utf-8')
 after=guarded_files();changed=[p for p,h in before.items() if after.get(p)!=h]
 if changed:raise ValueError('Protected files changed: '+str(changed))
 legacy_entries=publish_current_entries()
 manifest={'schema_version':1,'kind':'comprehensive_art_form_delivery','items':len(data['items']),'counts_by_category':dict(Counter(a['category'] for a in data['items'])),'counts_by_review':dict(Counter(a['review_status'] for a in data['items'])),'files_matched':data['review_summary']['files'],'original579_retained':True,'effects23_retained':True,'source_art_and_game_unchanged_during_form_build':not changed,'source_art_and_game_unchanged':not changed,'legacy_entry_banners':legacy_entries,'runtime_contract_sha256':sha(SPACE/'runtime_spaces.json'),'scene_contract_sha256':sha(SPACE/'scene_generation_contracts.json'),'protected_files_checked':len(before),'entry':str(DESKTOP/PAGE),'ui':str(DESKTOP/UI_PAGE),'game_changes':False,'images_generated':False}
 dump(OUT/'delivery_manifest.json',manifest)
 archive=OUT/'NEURONS_完整美术表单_含已有素材_20261019.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for name in [PAGE,UI_PAGE,'使用说明.txt','delivery_manifest.json']:z.write(OUT/name,name)
  for p in (OUT/'data').glob('*.json'):
   if p.name!='comprehensive_assets.json':z.write(p,'审查与修订依据/'+p.name)
  for p in (OUT/'pose_guides').glob('*.svg'):z.write(p,'行走姿态参照/'+p.name)
 shutil.copy2(archive,DESKTOP/archive.name)
 print(json.dumps(manifest,ensure_ascii=False))

if __name__=='__main__':main()
