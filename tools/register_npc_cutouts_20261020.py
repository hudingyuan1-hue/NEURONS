"""Persist the four built-in background-extraction results without altering pixels."""
import json,hashlib,shutil
from pathlib import Path
from PIL import Image,ImageChops,ImageStat,ImageOps,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/validation/asset_production_20261020/characters'
GENERATED=Path('C:/Users/23623/.codex/generated_images/01a154b7-b1d3-7a72-928d-69239c6a387f')
FILES={
 'CHR_OTHER_NPCS_FATHER':'exec-40af2014-0f3a-4423-8ea4-c749ec69b305.png',
 'CHR_OTHER_NPCS_MOTHER':'exec-fa249eb6-b935-4d60-8745-52f87abcfefc.png',
 'CHR_OTHER_NPCS_N04':'exec-b4756421-c820-427d-b588-dd2b3f5b88be.png',
 'CHR_OTHER_NPCS_N03':'exec-9c51d9f8-8f28-4b8f-b403-978ecd69974c.png',
}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
registry_path=ROOT/'neurons/data/npc_visual_registry.json'
registry=json.loads(registry_path.read_text(encoding='utf-8'))
results=[];preview=Image.new('RGB',(4*420,940),(32,36,42));draw=ImageDraw.Draw(preview)
for index,(asset,name) in enumerate(FILES.items()):
 request_path=OUT/(asset+'_cutout_request.json');request=json.loads(request_path.read_text(encoding='utf-8'))
 source=Path(request['source_path']);generated=GENERATED/name
 assert sha(source)==request['source_sha256'],'Source changed during extraction: '+asset
 folder=ROOT/'neurons/assets/production/characters'/asset;folder.mkdir(parents=True,exist_ok=True)
 target=folder/(asset+'_normal_reference_cutout_v001.png')
 if target.exists() and sha(target)!=sha(generated):raise ValueError('Refusing to replace differing production cutout '+str(target))
 if not target.exists():shutil.copy2(generated,target)
 with Image.open(source) as original,Image.open(target) as cutout:
  assert cutout.mode=='RGBA' and cutout.getchannel('A').getextrema()==(0,255)
  alpha=cutout.getchannel('A');hist=alpha.histogram();raw_bbox=alpha.getbbox();bbox=alpha.point(lambda a:255 if a>=8 else 0).getbbox();count=cutout.width*cutout.height
  assert hist[0]/count>.25 and bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<cutout.width and bbox[3]<cutout.height,'No genuine complete transparent cutout '+asset
  same_canvas=original.size==cutout.size
  opaque_difference=None
  if same_canvas:
   mask=alpha.point(lambda a:255 if a>=250 else 0)
   opaque_difference=ImageStat.Stat(ImageChops.difference(original.convert('RGB'),cutout.convert('RGB')),mask=mask).mean
  result={**request,'status':'generated_and_technical_preview_checked_not_runtime_bound','generated_original_path':str(generated),'output_path':str(target),'production_texture':'res://'+target.relative_to(ROOT/'neurons').as_posix(),'output_sha256':sha(target),'mode':'RGBA','pixel_size':list(cutout.size),'alpha_bbox':list(bbox),'alpha_bbox_threshold':8,'raw_nonzero_alpha_bbox':list(raw_bbox),'transparent_fraction':round(hist[0]/count,6),'antialias_fraction':round(sum(hist[1:255])/count,6),'near_invisible_alpha_1_to_7_fraction':round(sum(hist[1:8])/count,6),'alpha_edge_note':'Raw tool output retains sparse near-invisible alpha 1-7 pixels outside the subject. PNG pixels are unchanged; anchor uses alpha >=8 bounds. Check fringes during final rig/contact compositing.','same_canvas_as_source':same_canvas,'source_opaque_rgb_mean_absolute_difference':opaque_difference,'ground_anchor_px':[round((bbox[0]+bbox[2])*.5,2),bbox[3]],'ground_anchor_policy':'Initial full-body footprint reference from meaningful alpha >=8 bounds; actual contact and individual foot/body-part anchors require rig/runtime preview.','visual_review':{'entire_head_and_both_shoes':True,'same_identity_costume_pose_and_view':True,'white_clothes_gloves_cap_shoes_preserved':True,'no_visible_floor_or_cast_shadow':True,'source_painterly_style_retained_not_pixel_identical':True},'runtime_binding_enabled':False}
  results.append(result);write(OUT/(asset+'_cutout_result.json'),result)
  a=registry['assets'][asset]
  assert a['selected_sha256']==request['source_sha256']
  a.update(production_texture=result['production_texture'],production_sha256=result['output_sha256'],production_pixel_size=result['pixel_size'],production_alpha_bbox=result['alpha_bbox'],production_ground_anchor_px=result['ground_anchor_px'],technical_state='builtin_cutout_prepared_alpha_and_identity_checked_pending_rig_contact_preview',production_provenance_path=(OUT/(asset+'_cutout_result.json')).relative_to(ROOT).as_posix())
  # Inspection-only light/dark backdrops; the production PNG stays untouched.
  thumb=ImageOps.contain(cutout,(400,880))
  background=Image.new('RGBA',(420,940),(37,42,49,255) if index%2==0 else (220,223,220,255));background.alpha_composite(thumb,((420-thumb.width)//2,50))
  preview.paste(background.convert('RGB'),(index*420,0));draw.text((index*420+12,12),asset,fill=(255,160,80))
registry['first_cutout_batch']={'built_in_tool_calls':4,'results':[r['production_texture'] for r in results],'status':'four exact-source technical cutouts; not yet game animation acceptance'}
write(registry_path,registry);write(OUT/'cutout_results.json',{'tool':'built_in_image_gen','assets':results,'source_masters_unchanged':True,'runtime_binding_modified':False})
preview.save(OUT/'cutout_alpha_preview.jpg',quality=93)
print(json.dumps({'cutouts':len(results),'genuine_alpha':all(r['mode']=='RGBA' for r in results),'source_unchanged':True,'same_canvas':sum(r['same_canvas_as_source'] for r in results)},ensure_ascii=False))
