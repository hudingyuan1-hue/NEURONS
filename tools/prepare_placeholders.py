"""Clearly provisional code-drawn sprites for testing resource replacement."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

root=Path(__file__).resolve().parents[1]/'neurons'
out=root/'assets/placeholders';out.mkdir(parents=True,exist_ok=True)
states=['idle','walk','search','scratch','give','grab','hit','fear']
for variant,color in [('a','#8caebc'),('b','#a5bed0')]:
    im=Image.new('RGBA',(64*16,80*8))
    for row,state in enumerate(states):
        for direction in range(4):
            for frame in range(4):
                layer=Image.new('RGBA',(64,80));d=ImageDraw.Draw(layer)
                bend=5 if state=='search' else -3 if state=='hit' else 0
                stride=[-3,0,3,0][frame] if state=='walk' else 0
                d.ellipse((24,15+bend,40,31+bend),fill='#d6c8b0')
                d.rectangle((23,32+bend,41,52),fill=color)
                d.line((27,52,27+stride,71),fill=color,width=6)
                d.line((37,52,37-stride,71),fill=color,width=6)
                hand=(48,43) if state in ['search','give','grab'] else (37+(frame%2)*3,31) if state=='scratch' else (45,48)
                d.line((39,35+bend,*hand),fill=color,width=5)
                d.line((25,35+bend,20,49),fill=color,width=4)
                # A small orientation notch, not an invented face or identity.
                x,y=[(39,23),(32,17),(25,23),(32,29)][direction]
                d.rectangle((x-1,y-1,x+1,y+1),fill='#344248')
                if variant=='b':d.line((24,50,40,50),fill='#677f8a',width=2)
                im.alpha_composite(layer,((direction*4+frame)*64,row*80))
    im.save(out/f'host_{variant}.png')

assets={}
for variant in ['a','b']:
    assets[variant]={
        'CHR_MAIN':{'texture':f'res://assets/placeholders/host_{variant}.png','cell':[64,80],'foot':[32,72],'hand':[45,44],
          'directions':4,'frames':4,'states':states,'frame_seconds':0.16,'status':'程序占位，非正式造型'},
        'ENV_BEDSIDE':{'canvas':[96,80],'foot':[8,40],'handle':[60.7394,25.7744],'travel':[7,0],
          'body':'res://assets/environment/bedside_trial_v001/cabinet_frame.png',
          'drawer':'res://assets/environment/bedside_trial_v001/drawer_face.png',
          'tray':'res://assets/environment/bedside_trial_v001/drawer_tray.png','tray_size':[48,24],
          'book':'res://assets/environment/bedside_trial_v001/book.png',
          'clock':'res://assets/environment/bedside_trial_v001/alarm_clock.png',
          'front':'res://assets/environment/bedside_trial_v001/foreground_rail_v002.png',
          'tint':'ffffff' if variant=='a' else 'b9c9cf'}}
(root/'data').mkdir(exist_ok=True)
(root/'data/presentation.json').write_text(json.dumps({'schema':1,'default':'a','sets':assets},ensure_ascii=False,indent=2),encoding='utf8')
print('2 explicit placeholder atlases; same foot/hand/cell; furniture mapping uses existing layers')
