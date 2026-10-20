"""Non-destructive UI/narrative source preparation; original pixels preserved."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'neurons/assets/production/narrative'
OUT.mkdir(parents=True,exist_ok=True)
def copy(asset_id,path,role,folder='',extra=None):
 source=Path(path)
 if not source.is_absolute():source=ROOT/source
 digest=hashlib.sha256(source.read_bytes()).hexdigest()
 target=OUT/folder/f'{asset_id}_{digest[:12]}.png';target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists():shutil.copy2(source,target)
 with Image.open(source) as im:
  size=list(im.size);mode=im.mode
 return dict(asset_id=asset_id,texture='res://'+target.relative_to(ROOT/'neurons').as_posix(),
             source=str(source),sha256=digest,pixel_size=size,mode=mode,role=role,
             pixels_changed=False,**(extra or {}))

textures={}
for path in sorted((ROOT/'DOCX/最终素材/开场').glob('*.png')):
 stem=path.stem
 asset_id=stem.rsplit('_v',1)[0]
 if asset_id.startswith('ENDING_HOST_EYES'):asset_id='ENDING_HOST_EYES'
 textures[asset_id]=copy(asset_id,path,'user_named_narrative_source')
extra_sources={
 'APPROVED_ROOM_STYLE':'DOCX/新建文件夹/ENV_ROOM_L1_ROOM_BASE_v001.png',
 'PLAYER_MASTER':'DOCX/最终素材/人物/CHR_PLAYER_MASTER_2D_v001.png',
 'PLAYER_FRONT':'DOCX/最终素材/人物/CHR_PLAYER_TURN__FRONT_v005.png',
 'PLAYER_BACK':'DOCX/最终素材/人物/CHR_PLAYER_TURN__BACK_v005.png',
 'PLAYER_SIDE':'DOCX/最终素材/人物/CHR_PLAYER_TURN__SIDE_v005.png',
 'PLAYER_WAVE':'DOCX/最终素材/动作/CHR_PLAYER_ACT_WAVE__wave__P02_v005.png',
}
for asset_id,path in extra_sources.items():textures[asset_id]=copy(asset_id,path,'user_reference_preserved')
generated={
 'E2_ORIGIN_GROUND':'C:/Users/23623/.codex/generated_images/01a154b9-0ced-70d3-84e6-031e88a14a7b/exec-d87d601e-1ce3-4c34-a75c-0a1f2a2e2873.png',
 'ENDING_HOSPITAL_RESTING':'C:/Users/23623/.codex/generated_images/01a154b9-0ced-70d3-84e6-031e88a14a7b/exec-6f2e3bc8-de51-48c5-8c84-6704e60c75d3.png',
 'INTRO_HOST_SLEEP':'C:/Users/23623/.codex/generated_images/01a154b9-0ced-70d3-84e6-031e88a14a7b/exec-cba81cef-4242-45f2-beb8-b001f2d3a324.png',
 'INTRO_HOST_WAKE':'C:/Users/23623/.codex/generated_images/01a154b9-0ced-70d3-84e6-031e88a14a7b/exec-ebe02ec6-4cec-4066-b33c-48ed8dd26278.png',
}
prior_path=ROOT/'neurons/data/narrative_visuals.json'
prior=json.loads(prior_path.read_text(encoding='utf-8')) if prior_path.exists() else {}
for asset_id,path in generated.items():textures[asset_id]=copy(asset_id,path,'codex_generated_from_named_references')
for key,value in prior.get('textures',{}).items():
 if key not in textures:textures[key]=value

registry=json.loads((ROOT/'neurons/data/npc_visual_registry.json').read_text(encoding='utf-8'))
portraits={}
for item in registry['assets'].values():
 identity=item['identity_id']
 if item['asset_id']!=identity or item.get('state')!='normal':continue
 path=item.get('production_texture')
 if path:path=ROOT/'neurons'/path.removeprefix('res://')
 else:path=ROOT/item['selected_source']
 if not Path(path).exists():continue
 portraits[identity]=copy(identity,path,'existing_normal_identity_portrait','portraits',
                         {'source_approval':item.get('source_approval'),'selected_source':item['selected_source'],
                          'alpha_policy':'Use existing true alpha or show unchanged source in a paper picture frame; no white-threshold matting.'})
 if identity in ['CHR_OTHER_NPCS_FATHER','CHR_OTHER_NPCS_MOTHER','CHR_OTHER_NPCS_N03','CHR_OTHER_NPCS_N04']:
  portraits[identity]['normalized_rect']=[.28,0,.4,.38]

aliases={}
for name in ['combat_chapter.json','street_chapter.json']:
 spec=json.loads((ROOT/'neurons/data'/name).read_text(encoding='utf-8'))
 for actor in spec.get('actors',[]):
  if actor.get('identity_id'):aliases[str(actor['id'])]=str(actor['identity_id'])
aliases.update({'mother':'CHR_OTHER_NPCS_MOTHER','father':'CHR_OTHER_NPCS_FATHER',
                'dog':'CHR_OTHER_NPCS_DOG','cat':'CHR_OTHER_NPCS_CAT'})

data={
 'schema':1,'scope':'UI/narrative presentation only; no actor/world/rule state mutation or unknown identity inference',
 'textures':textures,'portraits':portraits,'observation_actor_aliases':aliases,
 'portrait_missing':{'CHR_OTHER_NPCS_N41':'Registry only has normal BACK and altered references; do not invent a normal front face or silently substitute altered.'},
 'card_bindings':{
  'opening_crisis':'SLIDE_A02','opening_city':'SLIDE_A02','opening_country':'SLIDE_A03','opening_sea':'SLIDE_A04',
  'opening_accident':'SLIDE_A06','opening_invasion':'SLIDE_A02','opening_room':'APPROVED_ROOM_STYLE','opening_logo':'APPROVED_ROOM_STYLE',
  'intro_name':'PLAYER_BACK','intro_id':'PLAYER_BACK','intro_denial':'PLAYER_WAVE','intro_turn':'PLAYER_FRONT','intro_parasite':'PLAYER_FRONT',
  'intro_sleep':'INTRO_HOST_SLEEP','intro_motive':'INTRO_HOST_SLEEP','intro_wake':'INTRO_HOST_WAKE',
 },
 'regions':{'ENDING_EYES_CLOSED':{'texture':'ENDING_HOST_EYES','normalized_rect':[0,0,.5,1]},
            'ENDING_EYES_OPEN':{'texture':'ENDING_HOST_EYES','normalized_rect':[.5,0,.5,1]},
            'PLAYER_PROFILE':{'texture':'PLAYER_MASTER','normalized_rect':[.38,.38,.3,.56]},
            'TITLE_DOOR':{'texture':'APPROVED_ROOM_STYLE','normalized_rect':[.55,0,.45,1]}},
 'reserved_sources':{
  'SLIDE_B04':'Original user source preserved. Actual image is an orbital rock, not the source-required surface view. No automatic substitution into opening or E2 ground.',
  'SLIDE_B05':'Spacecraft kept out of opening per opening.json revision. No invented new epilogue beat.',
  'ENDING_HOST_BODY_REFERENCE':'Identity/support reference; opaque source is not pasted onto the hospital bed.',
  'UI_EVIDENCE_FAMILY_PHOTO':'Only show after exact hospital_family_photo_seen observation; never infer depicted identities/relationships.'
 },
}
prior_path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
(Path(__file__).parent/'narrative_manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'narrative_sources':len(textures),'normal_portraits':len(portraits),'actor_aliases':len(aliases),'originals_changed':False},ensure_ascii=False))
