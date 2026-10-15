"""Measured 2D reprojection/slicing of a generated layered kit; no color key,
alpha threshold, palette quantization or invented texture painting. Preserve source.
The generated product perspective is not the game's projection: map the painted
faces to authored oblique corners, and preserve a complete empty drawer well.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
raw = Image.open(ROOT/'art/source/bedside_layers_v001.png').convert('RGBA')
SIZE=(96,80)
out=ROOT/'art/working/bedside_trial_v001';out.mkdir(parents=True,exist_ok=True)
runtime=ROOT/'neurons/assets/environment/bedside_trial_v001';runtime.mkdir(parents=True,exist_ok=True)
def inverse_map(src,dst):
    rows=[];rhs=[]
    for (x,y),(u,v) in zip(dst,src):
        rows.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]])
        rhs.extend([u,v])
    return np.linalg.solve(np.array(rows),np.array(rhs))
def warp(src,dst,clip=None):
    coeff=inverse_map(src,dst)
    result=raw.transform(SIZE,Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)
    mask=Image.new('L',SIZE);ImageDraw.Draw(mask).polygon(dst if clip is None else clip,fill=255)
    a=np.array(result.getchannel('A'),dtype=np.uint16)*np.array(mask,dtype=np.uint16)//255
    result.putalpha(Image.fromarray(a.astype('uint8')))
    return result
def save(name,image):
    image.save(out/(name+'.png'));image.save(runtime/(name+'.png'))

# Anchor is projected rear-left floor corner, not an alpha bounding-box center.
A=(8,40);B=(54.4,40);C=(67.84,62.08);D=(21.44,62.08)
top=[(8,10),(54.4,10),(67.84,32.08),(21.44,32.08)]
side=[(21.44,32.08),(67.84,32.08),(67.84,58.08),(21.44,58.08)]
front=[(54.4,10),(67.84,32.08),(67.84,58.08),(54.4,36)]
front_src=[(370,248),(490,228),(490,452),(370,475)]
body=Image.new('RGBA',SIZE)
for leg_src,leg_dst in [
 ([(214,467),(238,467),(238,496),(214,496)],[(20,57),(24,57),(24,63),(20,63)]),
 ([(462,448),(487,448),(487,475),(462,475)],[(65,57),(69,57),(69,63),(65,63)]),
 ([(89,383),(111,383),(111,403),(89,403)],[(52,34),(56,34),(56,40),(52,40)])]:
    body.alpha_composite(warp(leg_src,leg_dst))
body.alpha_composite(warp([(88,162),(217,255),(217,462),(90,390)],side))
body.alpha_composite(warp(front_src,front))
body.alpha_composite(warp([(86,135),(367,135),(490,219),(225,235)],top))
save('cabinet_frame',body)

# Map original drawer face to the measured empty well. Tray and face are separate
# draw passes; the fixed frame masks the tray while closed. No closed face in body.
forward=np.linalg.inv(np.array([[*inverse_map(front_src,front)[:3]],
                              [*inverse_map(front_src,front)[3:6]],
                              [*inverse_map(front_src,front)[6:],1]]))
def to_front(p):
    v=forward@np.array([p[0],p[1],1]);return tuple((v[:2]/v[2]).tolist())
hole=[to_front(p) for p in [(377,252),(477,237),(477,300),(377,323)]]
face_src=[(757,281),(888,260),(888,347),(757,368)]
drawer_face=warp(face_src,hole)
save('drawer_face',drawer_face)
# The tray's complete silhouette transforms under the same face alignment.
matrix=np.linalg.inv(np.array([[*inverse_map(face_src,hole)[:3]],
                             [*inverse_map(face_src,hole)[3:6]],
                             [*inverse_map(face_src,hole)[6:],1]]))
def map_tray(p):
    v=matrix@np.array([*p,1]);return tuple((v[:2]/v[2]).tolist())
silhouette=[map_tray(p) for p in [(668,222),(753,207),(890,262),(890,347),(764,369),(668,306)]]
# The generated tray's product perspective would protrude above the cabinet.
# Keep only its painted interior surface; the trial maps that surface to the
# actual swept drawer top. No tall product-view tray silhouette is shipped.
tray=raw.crop((696,229,801,266)).resize((48,24),Image.Resampling.LANCZOS)
save('drawer_tray',tray)

# Foreground rail/feet are retained as a separate, narrowly masked layer.
fore=body.copy();mask=Image.new('L',SIZE);d=ImageDraw.Draw(mask)
d.polygon([(21,55),(69,55),(69,64),(20,64)],fill=255)
alpha=np.array(fore.getchannel('A'),dtype=np.uint16)*np.array(mask,dtype=np.uint16)//255
fore.putalpha(Image.fromarray(alpha.astype('uint8')));save('foreground_rail_v002',fore)
save('book',warp([(164,708),(261,706),(360,775),(267,815)],[(25,14),(36,14),(41,21),(30,21)]))
clock=raw.crop((678,638,828,838)).resize((12,16),Image.Resampling.LANCZOS)
clock_layer=Image.new('RGBA',SIZE);clock_layer.alpha_composite(clock,(14,2));save('alarm_clock',clock_layer)

# Bed edge is a local strip, not a whole-room background or new full bed asset.
bed=raw.crop((1018,268,1498,450)).resize((188,42),Image.Resampling.LANCZOS)
save('bed_edge',bed)
metadata={'source':'art/source/bedside_layers_v001.png','canvas':list(SIZE),'anchor':[8,40],
          'footprint_m':[.58,.48],'height_world_px':30,
          'handle_closed':list(to_front((427,285))), 'open_delta_world_px':[7,0],
          'drawer_top_closed':[list(hole[0]),list(hole[1])],
          'method':'measured face reprojection and alpha-preserving slices, not lossless automatic room extraction',
          'approval':'experimental_pending_user_review'}
(out/'anchors.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')

# Same-scale concept comparison, never presented as runtime.
font_path=ROOT/'neurons/assets/fonts/NotoSansCJKsc-Regular.otf'
font=ImageFont.truetype(str(font_path),23)
canvas=Image.new('RGB',(2560,810),(31,42,46));draw=ImageDraw.Draw(canvas)
for index,version in enumerate(['v003','v005']):
    image=Image.open(ROOT/f'art/source/bedroom_visual_candidate_{version}.png').convert('RGB')
    image=image.resize((1280,720),Image.Resampling.LANCZOS)
    canvas.paste(image,(index*1280,50))
    draw.text((index*1280+28,12),version+' 视觉候选，非实机；未获美术定稿确认',font=font,fill=(228,220,198))
draw.text((26,775),'同尺度对照：减弱金黄窗光 / 区分材质 / 补齐可搜寻部位与线索；凳椅轮廓仍待修改',font=font,fill=(213,207,188))
canvas.save(ROOT/'art/previews/bedroom_visual_comparison_v005.png')
for v in ['v004','v005']:
    image=Image.open(ROOT/f'art/source/bedroom_visual_candidate_{v}.png')
    logical=image.resize((640,360),Image.Resampling.BOX)
    logical.save(ROOT/f'art/previews/bedroom_visual_candidate_{v}_640x360.png')
    logical.resize((1280,720),Image.Resampling.NEAREST).save(ROOT/f'art/previews/bedroom_visual_candidate_{v}_1280x720.png')
print(json.dumps(metadata,ensure_ascii=False))
