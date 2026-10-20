"""Check frozen NPC provenance and cutouts without changing any pixel or runtime binding."""
import hashlib,json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/validation/asset_production_20261020/characters'
registry=json.loads((ROOT/'neurons/data/npc_visual_registry.json').read_text(encoding='utf-8'))
snapshot=json.loads((OUT/'source_inventory_snapshot.json').read_text(encoding='utf-8'))
cutouts=json.loads((OUT/'cutout_results.json').read_text(encoding='utf-8'))
checks=[]
def check(label,condition):
 checks.append({'check':label,'pass':bool(condition)})
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def from_res(path):return ROOT/'neurons'/path.removeprefix('res://')
check('frozen source count matches registry',len(snapshot['files'])==registry['source_files'])
check('component count matches registry',len(registry['assets'])==registry['stable_components'])
check('main/player rig ownership excluded',not any(k.startswith(('CHR_MAIN','CHR_PLAYER')) for k in registry['assets']))
for source in snapshot['files']:
 path=Path(source['source_path'])
 check('source preserved: '+source['source_project_path'],path.exists() and sha(path)==source['sha256'])
 if source.get('production_copy'):
  check('exact source-alpha copy: '+source['part_id']+' v'+str(source['version']),sha(from_res(source['production_copy']))==source['sha256'])
for component,asset in registry['assets'].items():
 variants=asset['variants'];selected=[v for v in variants if v['source_project_path']==asset['selected_source'] and v['sha256']==asset['selected_sha256']]
 check('selected source is recorded variant: '+component,len(selected)==1)
 check('not automatically runtime bound: '+component,asset['runtime_binding_enabled'] is False)
 authoritative=[v for v in variants if v['source_folder_role']=='user_revised_altered']
 approved=[v for v in variants if v['original_approved_hash']]
 if authoritative:
  check('explicit user-revised altered source preferred: '+component,selected[0]['source_folder_role']=='user_revised_altered' and asset['source_approval']=='user_revised_no_aesthetic_reevaluation')
 elif approved:
  check('approved hash retained: '+component,selected[0]['original_approved_hash'])
for result in cutouts['assets']:
 asset=registry['assets'][Path(result['source_path']).stem.rsplit('_v',1)[0]]
 target=Path(result['output_path']);generated=Path(result['generated_original_path'])
 check('source master unchanged for cutout: '+target.parent.name,sha(result['source_path'])==result['source_sha256'])
 check('builtin result copied without pixel modification: '+target.parent.name,sha(target)==sha(generated)==result['output_sha256'])
 check('registry refers exact cutout: '+target.parent.name,asset['production_texture']==result['production_texture'] and asset['production_sha256']==result['output_sha256'])
 with Image.open(target) as image:
  alpha=image.getchannel('A');bounds=alpha.point(lambda a:255 if a>=8 else 0).getbbox()
  check('RGBA alpha and matching complete subject bounds: '+target.parent.name,image.mode=='RGBA' and alpha.getextrema()==(0,255) and list(bounds)==result['alpha_bbox'] and bounds[0]>0 and bounds[1]>0 and bounds[2]<image.width and bounds[3]<image.height)
  check('complete source canvas preserved: '+target.parent.name,list(image.size)==result['pixel_size'] and result['same_canvas_as_source'])
passed=sum(x['pass'] for x in checks)
report={'passed':passed,'failed':len(checks)-passed,'frozen_source_files':len(snapshot['files']),'stable_components':len(registry['assets']),'source_alpha_copies':registry['source_alpha_copies'],'built_in_cutouts':len(cutouts['assets']),'runtime_binding_enabled':False,'visual_qa_path':'docs/validation/asset_production_20261020/characters/cutout_alpha_preview.jpg','scope_note':'Source selection, provenance, true alpha, canvas and meaningful bounds only. Not movement, contact or animation acceptance. Raw alpha 1-7 peripheral specks are recorded for later composite QA; pixels are not changed.','checks':checks}
(OUT/'preparation_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False,indent=2))
if report['failed']:raise SystemExit(1)
