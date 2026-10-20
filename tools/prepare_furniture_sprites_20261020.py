"""Non-destructive atlas copies and rectangle crops; no alpha keying or repaint."""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parents[1]
GENERATED=Path('C:/Users/23623/.codex/generated_images/01a154b7-b1d3-7a72-928d-69239c6a387f')
OUT=ROOT/'neurons/assets/production/furniture';OUT.mkdir(parents=True,exist_ok=True)
QA=ROOT/'docs/validation/asset_production_20261020/furniture';QA.mkdir(parents=True,exist_ok=True)
atlases={'a':'exec-d83f9eb4-fdbd-46dd-a699-b59ff196c663.png','b':'exec-645614ae-83ae-4833-a74c-70f0e1dcb2b2.png','c':'exec-143094b9-0f29-4b1e-ac3a-139a74469f21.png'}
# Explicit non-overlapping content boxes after inspecting each actual tool result.
regions={'bed':('a',[16,130,640,490]),'bedside':('a',[640,130,986,500]),'desk':('a',[988,130,1536,500]),'chair':('a',[80,500,470,960]),'bedside_drawer':('a',[500,550,980,915]),'bed_blanket':('a',[990,540,1536,940]),'fan':('b',[100,10,470,500]),'rack':('b',[600,0,940,500]),'books':('b',[1090,0,1430,500]),'wardrobe':('b',[100,500,470,1024]),'fan_rotor':('b',[550,530,1010,960]),'wardrobe_open':('b',[1090,490,1500,1024])}
regions.update({'stool':('c',[80,100,390,400]),'stool_parcel':('c',[480,100,790,395]),'box_lower':('c',[845,40,1230,400]),'box_upper':('c',[25,460,470,880]),'storage':('c',[510,410,805,885]),'rack_coat':('c',[870,390,1220,920]),'bedside_book':('c',[55,955,420,1220]),'bedside_clock':('c',[525,960,760,1210]),'desk_paper':('c',[860,940,1240,1240])})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
master_records={}
for key,name in atlases.items():
 source=GENERATED/name;target=OUT/('bedroom_furniture_atlas_'+key+'_v001.png')
 if target.exists() and sha(target)!=sha(source):raise ValueError('Differing master '+str(target))
 if not target.exists():shutil.copy2(source,target)
 refs=[QA/('atlas_'+key+'_geometry_guide.png'),ROOT/'DOCX/新建文件夹/ENV_ROOM_L1_ROOM_BASE_v001.png',ROOT/'DOCX/新建文件夹/dc3eba99-ce86-428f-81ef-e84724936df1.png']
 master_records[key]={'generated_original_path':str(source),'master_copy_path':str(target),'sha256':sha(target),'prompt':(QA/('atlas_'+key+'_prompt.txt')).read_text(encoding='utf-8'),'tool':'built_in_image_gen','transparent_background':True,'references':[{'path':str(p),'sha256':sha(p),'role':'geometry orientation/scale only' if i==0 else 'approved painterly style/camera only; no placement copying'} for i,p in enumerate(refs)]}
records={};preview=Image.new('RGB',(4*410,((len(regions)+3)//4)*470),(224,225,219));draw=ImageDraw.Draw(preview)
for index,(id,(atlas,region)) in enumerate(regions.items()):
 with Image.open(OUT/('bedroom_furniture_atlas_'+atlas+'_v001.png')) as master:
  assert master.mode=='RGBA'
  image=master.crop(region);target=OUT/(id+'_v001.png');image.save(target)
  alpha=image.getchannel('A');hist=alpha.histogram();bbox=alpha.point(lambda a:255 if a>=16 else 0).getbbox()
  record={'id':id,'texture':'res://'+target.relative_to(ROOT/'neurons').as_posix(),'sha256':sha(target),'atlas':atlas,'atlas_region_px':region,'pixel_size':list(image.size),'meaningful_alpha_threshold':16,'alpha_bbox':list(bbox),'raw_alpha_extrema':list(alpha.getextrema()),'transparent_fraction':round(hist[0]/sum(hist),5),'near_invisible_alpha_1_7_fraction':round(sum(hist[1:8])/sum(hist),5),'processing':'Exact rectangular crop only; alpha and painted source pixels unchanged.','runtime_binding_enabled':False}
  records[id]=record
  tile=Image.new('RGBA',(410,470),(223,225,219,255) if index%2 else (36,43,48,255))
  thumb=ImageOps.contain(image,(390,420));tile.alpha_composite(thumb,((410-thumb.width)//2,40))
  preview.paste(tile.convert('RGB'),((index%4)*410,(index//4)*470));draw.text(((index%4)*410+10,(index//4)*470+10),id,fill=(231,172,104))
preview.save(QA/'sprite_alpha_review.jpg',quality=94)
result={'schema_version':1,'atlases':master_records,'sprites':records,'source_masters_preserved':True,'runtime_binding_enabled':False,'scope':'Actual painterly furniture/layer sprites; source atlas arrangement is not a room layout. Dimensions/registration/state mapping are separately calibrated from the current metric slot.'}
(QA/'sprite_preparation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'atlases':len(atlases),'sprites':len(records),'originals_preserved':True,'runtime_binding_enabled':False}))
