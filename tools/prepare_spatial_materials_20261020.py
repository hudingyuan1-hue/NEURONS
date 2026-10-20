"""Copy generated master and slice its explicit 4x4 atlas without repainting pixels."""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('C:/Users/23623/.codex/generated_images/01a154b7-b1d3-7a72-928d-69239c6a387f/exec-b8a1ed3d-aaad-4603-8092-75fc4171da84.png')
OUT=ROOT/'neurons/assets/production/materials';OUT.mkdir(parents=True,exist_ok=True)
QA=ROOT/'docs/validation/asset_production_20261020/materials';QA.mkdir(parents=True,exist_ok=True)
MASTER=OUT/'painterly_material_atlas_v002.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if not MASTER.exists():shutil.copy2(SOURCE,MASTER)
assert sha(SOURCE)==sha(MASTER)
names=['aged_floorboards','worn_plaster','institution_tile','sage_paint','cortical_fibers','white_matter','street_stone','asphalt','furniture_wood','painted_metal','ivory_fabric','aged_paper','bark','tarnished_brass','smoky_glass','concrete']
scales=[2.1,6.8,2.4,5.5,14.0,15.0,3.4,6.0,2.4,3.4,2.0,1.8,2.8,2.2,3.2,4.5]
entries={}
with Image.open(MASTER) as im:
 assert im.width==im.height
 for index,name in enumerate(names):
  col=index%4;row=index//4
  # Four-pixel in-cell inset avoids contaminating a material with its neighbour.
  region=(round(im.width*col/4)+4,round(im.height*row/4)+4,round(im.width*(col+1)/4)-4,round(im.height*(row+1)/4)-4)
  target=OUT/(name+'_v002.png');im.crop(region).save(target)
  entries[name]={'texture':'res://'+target.relative_to(ROOT/'neurons').as_posix(),'source_cell':[col,row],'source_region_px':list(region),'world_span_m':scales[index],'sha256':sha(target),'filter':'linear','repeat':'mirrored_repeat','notes':'Flat hand-painted material only; architecture/doors/placement come from current metric geometry.'}
manifest={'schema_version':1,'enabled':False,'status':'representative_gpu_preview_pending_art_quality_review','master_texture':'res://assets/production/materials/painterly_material_atlas_v002.png','master_sha256':sha(MASTER),'materials':entries,'render_policy':{'geometry_unchanged':True,'world_space_uv':True,'voids_remain_open':True,'flat_normals_only':True,'source':'Built-in image_gen: user-approved two paintings are style-only references; no generated room geometry.'}}
(ROOT/'neurons/data/production_materials.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
refs=[ROOT/'DOCX/新建文件夹/ENV_ROOM_L1_ROOM_BASE_v001.png',ROOT/'DOCX/新建文件夹/dc3eba99-ce86-428f-81ef-e84724936df1.png']
record={'tool':'built_in_image_gen','prompt':(QA/'atlas_prompt_v002.txt').read_text(encoding='utf-8'),'transparent_background':False,'generated_original_path':str(SOURCE),'master_copy_path':str(MASTER),'master_sha256':sha(MASTER),'edit_target':{'path':str(OUT/'painterly_material_atlas_v001.png'),'sha256':sha(OUT/'painterly_material_atlas_v001.png')},'references':[{'path':str(p),'sha256':sha(p),'role':'painterly palette / brush grouping only; not room-layout authority'} for p in refs],'processing':'Exact original master copy and deterministic pixel crops only; no material repaint, background keying or geometry generation.','crop_count':len(entries),'production_enabled':False,'pixel_size':list(Image.open(MASTER).size),'prior_master_preserved':'res://assets/production/materials/painterly_material_atlas_v001.png'}
(QA/'atlas_provenance_v002.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'atlas_size':record['pixel_size'],'crops':len(entries),'enabled':False}))
