"""Freeze NPC source selection and copy genuine source-alpha files unchanged.

This is a preparation registry, never an implicit runtime binding or new visual
approval. Source masters, existing catalog and presentation configuration stay
untouched. Revised altered subdirectory has explicit precedence over versions
elsewhere; existing approved normal/pose hashes outrank unrelated newer drafts.
"""
from __future__ import annotations
import hashlib,json,re,shutil
from datetime import datetime,timezone,timedelta
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'DOCX/最终素材'
OUT=ROOT/'docs/validation/asset_production_20261020/characters'
PRODUCTION=ROOT/'neurons/assets/production/characters'
REGISTRY=ROOT/'neurons/data/npc_visual_registry.json'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def stable(path):return re.sub(r'_v\d+$','',path.stem)
def identity(component):
 if component.startswith('CHR_OTHER_NPCS_'):
  tail=component[len('CHR_OTHER_NPCS_'):].split('_')[0]
  return 'CHR_OTHER_NPCS_'+tail
 for k in ['FATHER','MOTHER','DOG','CAT']:
  if component.startswith('CHR_'+k+'_'):return 'CHR_OTHER_NPCS_'+k
 return component.split('__')[0].split('_L1_')[0]
def main():
 OUT.mkdir(parents=True,exist_ok=True)
 baseline=json.loads((ROOT/'deliverables/comprehensive_forms_20261019/data/approval_baseline.json').read_text(encoding='utf-8'))
 approved={p['sha256'] for values in baseline['accepted_parts'].values() for p in values if p.get('sha256')}
 groups={};records=[]
 for folder in ['人物','动作']:
  for path in sorted((SOURCE/folder).rglob('*.png')):
   component=stable(path)
   if component.startswith(('CHR_MAIN','CHR_PLAYER')):continue
   raw=path.read_bytes();digest=hashlib.sha256(raw).hexdigest()
   with Image.open(path) as im:
    alpha=im.getchannel('A') if 'A' in im.getbands() else None
    histogram=alpha.histogram() if alpha else []
    total=im.width*im.height
    a0=histogram[0]/total if histogram else 0
    valid=bool(alpha and alpha.getextrema()[0]==0 and a0>.01 and alpha.getbbox())
    rec={'part_id':component,'asset_id':component.split('__')[0],'identity_id':identity(component),'filename':path.name,'source_path':str(path.resolve()),'source_project_path':path.relative_to(ROOT).as_posix(),'sha256':digest,'pixel_size':list(im.size),'mode':im.mode,'alpha_extrema':list(alpha.getextrema()) if alpha else None,'fully_transparent_fraction':round(a0,6),'alpha_bbox':list(alpha.getbbox()) if alpha else None,'source_alpha_available':valid,'source_folder_role':'user_revised_altered' if '异化' in path.parts else 'named_source','original_approved_hash':digest in approved,'source_is_preserved':True,'technical_state':'source_alpha_unprocessed' if valid else 'background_extraction_required'}
   version=re.search(r'_v(\d+)$',path.stem);rec['version']=int(version.group(1)) if version else 0
   rec['state']='altered' if '_ALTERED' in component else 'collapse' if '_COLLAPSE' in component else 'remains' if '_REMAINS' in component else 'normal'
   direction=re.search(r'_D([0-3])(?:_|$)',component)
   rec['direction']=('D'+direction.group(1)) if direction else 'back_reference' if '_BACK' in component else 'reference_view'
   rec['direction_policy']='Only filename-explicit direction is assigned. Reference/back views require runtime camera validation; never infer four-way animation from one mother.'
   rec['action_clip']=component.split('__')[1] if '__' in component else None
   phase=re.search(r'__P(\d+)$',component);rec['pose_number']=int(phase.group(1)) if phase else None
   rec['play_order_not_inferred']=True
   if valid:
    target=PRODUCTION/rec['identity_id']/(component+'_source_v'+str(rec['version']).zfill(3)+'_'+digest[:12]+'.png')
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists() and sha(target)!=digest:raise ValueError('Refusing to overwrite differing source alpha: '+str(target))
    if not target.exists():shutil.copy2(path,target)
    assert sha(target)==digest
    rec['production_copy']='res://'+target.relative_to(ROOT/'neurons').as_posix()
    rec['production_copy_sha256']=digest
    rec['technical_state']='source_alpha_copied_exactly_pending_anchor_contact_preview'
   records.append(rec);groups.setdefault(component,[]).append(rec)
 assets={}
 for component,candidates in groups.items():
  altered=[r for r in candidates if r['source_folder_role']=='user_revised_altered']
  accepted=[r for r in candidates if r['original_approved_hash']]
  if altered:
   pool=altered;reason='Explicit user-revised altered subdirectory wins over every root-folder v-number. Latest named revision only within that authoritative subdirectory; old versions retained.'
  elif accepted:
   pool=accepted;reason='Retain the exact previously approved normal/key-pose hash. A numerically newer unreviewed draft does not replace approval.'
  else:
   pool=candidates;reason='No previously approved source for this exact stable component: newest same-component named candidate is proposed for technical preparation only, never auto-approved or bound.'
  chosen=max(pool,key=lambda r:(r['version'],r['source_alpha_available'],r['source_project_path']))
  assets[component]={'asset_id':chosen['asset_id'],'identity_id':chosen['identity_id'],'state':chosen['state'],'direction':chosen['direction'],'action_clip':chosen['action_clip'],'pose_number':chosen['pose_number'],'selected_source':chosen['source_project_path'],'selected_sha256':chosen['sha256'],'selection_reason':reason,'source_approval':'user_revised_no_aesthetic_reevaluation' if altered else 'original_approved_hash' if accepted else 'named_candidate_technical_preparation','variants':candidates,'production_texture':chosen.get('production_copy'),'runtime_binding_enabled':False,'remaining_technical_checks':['alpha edge quality and white clothes retained','proportion and ground anchor','separate held props/supports where required','continuous pose transitions and actual contact preview']}
 result={'schema_version':1,'kind':'NPC_SOURCE_PREPARATION_REGISTRY','captured_at':datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds'),'scope':'NPC/parents/animals/hunter sources and named poses; main host and player creature are owned by the separate rig workflow. No active presentation or catalog load is modified.','source_policy':['Original sources and all variants preserved','Explicit altered subdirectory has precedence; no aesthetic reevaluation of user revisions','Approved normal/key-pose hashes retained; higher version alone never means approval','Copy only genuine existing alpha without pixel modifications','Reference direction and pose number are not inferred runtime direction/playback order'],'source_files':len(records),'stable_components':len(assets),'source_alpha_copies':sum(r['source_alpha_available'] for r in records),'assets':assets}
 write(REGISTRY,result);write(OUT/'source_inventory_snapshot.json',{'captured_at':result['captured_at'],'files':records});write(OUT/'registry_summary.json',{k:v for k,v in result.items() if k!='assets'})
 print(json.dumps({k:result[k] for k in ['source_files','stable_components','source_alpha_copies']},ensure_ascii=False))
if __name__=='__main__':main()
