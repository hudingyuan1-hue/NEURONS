"""Technical atlas trimming/packing and joints for the user-requested cutout workflow.
Generated originals and user mothers remain untouched. No white-key extraction.
"""
from pathlib import Path
import json, math, argparse
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'neurons/assets/production/characters/main'
IDS=['head','torso','pelvis','left_upper_arm','left_forearm','left_hand',
     'right_upper_arm','right_forearm','right_hand','left_thigh','left_shin',
     'left_foot','right_thigh','right_shin','right_foot']
BONE_KEYS=['pelvis','spine','chest','neck','head','left_upper_arm','left_forearm','left_hand',
           'right_upper_arm','right_forearm','right_hand','left_thigh','left_shin','left_foot',
           'right_thigh','right_shin','right_foot']
DIRECTION_DATA={
 'D1':{'rest':[[555,750],[550,590],[540,370],[550,260],[552,250],[445,330],[405,515],[414,685],
               [614,354],[657,545],[680,735],[495,758],[491,980],[484,1190],[605,770],[610,1003],[619,1230]],
       'foot':[555,1280],'height':1210,'toe':{'left_foot':[450,1153],'right_foot':[695,1192]},'knees':{'left':-1,'right':-1},'stride':.50},
 'D2':{'rest':[[555,752],[558,600],[555,360],[550,272],[545,248],[454,323],[420,495],[415,672],
               [635,355],[673,540],[664,724],[501,780],[505,980],[500,1170],[615,785],[623,1025],[632,1240]],
       'foot':[555,1330],'height':1280,'toe':{'left_foot':[432,1210],'right_foot':[622,1320]},'knees':{'left':1,'right':1},'stride':.55},
 'D3':{'rest':[[556,752],[556,590],[556,360],[556,278],[556,258],[445,336],[405,519],[413,703],
               [670,336],[707,520],[703,703],[495,778],[494,1000],[492,1195],[617,778],[621,1000],[627,1195]],
       'foot':[556,1310],'height':1270,'toe':{'left_foot':[463,1282],'right_foot':[659,1282]},'knees':{'left':1,'right':-1},'stride':.50},
}

def largest_core(alpha):
    from collections import deque
    foreground=alpha>=64;seen=np.zeros_like(foreground);best=[]
    height,width=foreground.shape
    for y,x in zip(*np.where(foreground)):
        if seen[y,x]:continue
        queue=deque([(int(x),int(y))]);seen[y,x]=True;component=[]
        while queue:
            px,py=queue.popleft();component.append((px,py))
            for nx,ny in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)]:
                if 0<=nx<width and 0<=ny<height and foreground[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;queue.append((nx,ny))
        if len(component)>len(best):best=component
    assert len(best)>150,'Missing usable painted part'
    mask=np.zeros_like(alpha)
    for x,y in best:mask[y,x]=255
    dilated=Image.fromarray(mask).filter(ImageFilter.MaxFilter(5))
    return np.array(dilated)>0,len(best)

def fade_alpha(image, top=0, bottom=0):
    pixels=np.array(image);alpha=pixels[:,:,3].astype(float)
    if top:alpha[:top]*=np.linspace(0,1,top)[:,None]
    if bottom:alpha[-bottom:]*=np.linspace(1,0,bottom)[:,None]
    pixels[:,:,3]=np.uint8(np.clip(alpha,0,255));return Image.fromarray(pixels)

def alpha_hole(image, points):
    mask=Image.new('L',image.size);d=ImageDraw.Draw(mask)
    d.polygon([(round(x*image.width),round(y*image.height)) for x,y in points],fill=255)
    mask=mask.filter(ImageFilter.GaussianBlur(1))
    pixels=np.array(image);pixels[:,:,3]=np.uint8(pixels[:,:,3].astype(float)*(1-np.array(mask)/255))
    return Image.fromarray(pixels)

def hide_tube_cap(image, cut=.12, ramp=.05):
    pixels=np.array(image);alpha=pixels[:,:,3].astype(float)
    first=round(image.height*cut);last=round(image.height*(cut+ramp))
    alpha[:first]=0
    alpha[first:last]*=np.linspace(0,1,max(1,last-first))[:,None]
    pixels[:,:,3]=np.uint8(np.clip(alpha,0,255));return Image.fromarray(pixels)

def pack(direction):
    version='v002' if direction=='D1' else 'v001'
    source=DEST/f'CHR_MAIN_BLUE_{direction}_PARTS_{version}.png'
    im=Image.open(source).convert('RGBA');out=Image.new('RGBA',(1536,1536));records=[]
    for i,name in enumerate(IDS):
        x,y=i%4,i//4;cell=im.crop((x*im.width//4,y*im.height//4,(x+1)*im.width//4,(y+1)*im.height//4))
        pixels=np.array(cell);keep,area=largest_core(pixels[:,:,3]);pixels[:,:,3]=np.where(keep,pixels[:,:,3],0)
        clean=Image.fromarray(pixels);box=clean.getchannel('A').getbbox();clean=clean.crop(box)
        correction=DEST/f'CHR_MAIN_BLUE_{direction}_TORSO_CORRECTED_v001.png'
        if name=='torso' and correction.exists():
            replacement=Image.open(correction).convert('RGBA');rp=np.array(replacement)
            keep,area=largest_core(rp[:,:,3]);rp[:,:,3]=np.where(keep,rp[:,:,3],0)
            replacement=Image.fromarray(rp);replacement=replacement.crop(replacement.getchannel('A').getbbox())
            replacement=replacement.resize(clean.size,Image.Resampling.LANCZOS)
            # Other views need the corrected collar as a whole; remove any
            # generated baked sleeves along the torso seam before assembly.
            if direction!='D0':
                garment=Image.new('L',clean.size);gd=ImageDraw.Draw(garment)
                points=[(0,0),(1,0),(1,.30),(.81,.47),(.84,.80),(.94,1),(.06,1),(.16,.8),(.20,.47),(0,.30)]
                if direction=='D1':points=[(0,0),(1,0),(1,.30),(.80,.48),(.82,.80),(.89,1),(.11,1),(.18,.8),(.21,.48),(0,.30)]
                gd.polygon([(round(x*clean.width),round(y*clean.height)) for x,y in points],fill=255)
                rp=np.array(replacement);rp[:,:,3]=np.uint8(rp[:,:,3].astype(float)*np.array(garment.filter(ImageFilter.GaussianBlur(.7)))/255)
                clean=Image.fromarray(rp)
            else:
                # D0's collar is already aligned; restrict its donor to repair
                # areas so no generated fixed arm is baked onto the torso.
                pass
            mask=Image.new('L',clean.size);md=ImageDraw.Draw(mask)
            if direction=='D1':
                polygons=[[(.88,.14),(.99,.13),(1,.42),(.85,.42)]]
            else:
                polygons=[[(.34,0),(.67,0),(.70,.22),(.32,.22)],[(0,.26),(.18,.26),(.23,.58),(0,.61)]]
            for points in polygons:md.polygon([(round(x*clean.width),round(y*clean.height)) for x,y in points],fill=255)
            mask=mask.filter(ImageFilter.GaussianBlur(2))
            cp=np.array(clean);rp=np.array(replacement);weight=np.array(mask).astype(float)/255
            weight*=rp[:,:,3]/255
            cp[:,:,:3]=np.uint8(cp[:,:,:3]*(1-weight[:,:,None])+rp[:,:,:3]*weight[:,:,None])
            if direction=='D0':clean=Image.fromarray(cp)
        feet=DEST/f'CHR_MAIN_BLUE_{direction}_FEET_v001.png'
        directional_foot=False
        if name.endswith('foot') and feet.exists():
            pair=Image.open(feet).convert('RGBA');left=name.startswith('left')
            shoe=pair.crop((0 if left else pair.width//2,0,pair.width//2 if left else pair.width,pair.height))
            fp=np.array(shoe);keep,area=largest_core(fp[:,:,3]);fp[:,:,3]=np.where(keep,fp[:,:,3],0)
            shoe=Image.fromarray(fp);shoe=shoe.crop(shoe.getchannel('A').getbbox());factor=min(180/shoe.width,350/shoe.height)
            clean=shoe.resize((round(shoe.width*factor),round(shoe.height*factor)),Image.Resampling.LANCZOS);directional_foot=True
        if name=='head':original_head=clean.copy()
        if name=='head' and direction!='D1':
            # Remove only the internal neck-root outline that becomes a seam
            # over the corrected collar; the face and hair alpha are untouched.
            ap=np.array(clean.getchannel('A'));eroded=np.array(clean.getchannel('A').filter(ImageFilter.MinFilter(7)))
            yy,xx=np.mgrid[:clean.height,:clean.width]
            selection=(yy>clean.height*.77)&(xx<clean.width*.77)
            ap=np.where(selection,eroded,ap).astype('uint8');clean.putalpha(Image.fromarray(ap))
            if direction in ['D2','D3']:clean=fade_alpha(clean,bottom=38 if direction=='D2' else 18)
        elif name=='head' and direction=='D1':
            clean=clean.crop((0,0,clean.width,round(clean.height*.80)))
            clean=fade_alpha(clean,bottom=6)
        if name=='torso':original_torso=clean.copy()
        if name.endswith('upper_arm'):
            clean=clean.crop((0,0,clean.width,round(clean.height*.83)))
            clean=fade_alpha(hide_tube_cap(clean),bottom=5)
        elif name.endswith('forearm'):clean=hide_tube_cap(clean)
        elif name.endswith('thigh'):
            clean=clean.crop((0,0,clean.width,round(clean.height*.87)))
            clean=fade_alpha(hide_tube_cap(clean),bottom=7)
        elif name.endswith('shin'):clean=hide_tube_cap(clean)
        elif name.endswith('hand'):clean=hide_tube_cap(clean,cut=.10,ramp=.04)
        elif name.endswith('foot'):clean=fade_alpha(clean,top=round(clean.height*.12))
        elif name=='pelvis':
            clean=clean.crop((0,0,clean.width,round(clean.height*.48)))
            clean=fade_alpha(clean,bottom=24)
            if direction=='D3':
                # The supplied front mother already contains the continuous
                # trouser fork. Preserve those interior clothing pixels;
                # the generated short-pants patch has an invented lower hem.
                mother=Image.open(ROOT/f'DOCX/最终素材/动作/CHR_MAIN_IDLE_{direction}__idle__P01_v004.png').convert('RGBA')
                clean=mother.crop((430,680,700,860));mask=Image.new('L',clean.size)
                ImageDraw.Draw(mask).polygon([(10,10),(250,10),(254,120),(216,162),(136,90),(33,162),(8,120)],fill=255)
                clean.putalpha(mask.filter(ImageFilter.GaussianBlur(4)));clean=fade_alpha(clean,bottom=22)
        elif name=='torso' and direction!='D1' and not correction.exists():
            clean=alpha_hole(clean,[(.36,.025),(.48,.02),(.60,.06),(.65,.13),(.60,.18),(.45,.18),(.38,.13)])
            clean=alpha_hole(clean,[(.012,.29),(.06,.29),(.14,.35),(.19,.49),(.14,.56),(.065,.53),(.024,.42)])
        assert max(clean.size)<368, (name,clean.size)
        ox,oy=x*384+16,y*384+16;out.paste(clean,(ox,oy))
        records.append({'id':name,'region_px':[ox,oy,clean.width,clean.height],
                        'original_grid_cell':i,'painted_pixels':area,'directional_foot':directional_foot})
    if direction!='D1' and not (DEST/f'CHR_MAIN_BLUE_{direction}_TORSO_CORRECTED_v001.png').exists():
        # The first neck extension duplicated a diagonal head cut and looked
        # pasted. Reuse this torso's existing upper-chest skin under its collar;
        # the collar itself and the face remain untouched.
        w,h=original_torso.size
        patch=original_torso.crop((round(w*.47),round(h*.19),round(w*.56),round(h*.26)))
        patch=patch.resize((62,57),Image.Resampling.BICUBIC)
        mask=Image.new('L',patch.size);d=ImageDraw.Draw(mask);d.ellipse((0,0,61,56),fill=255)
        pixels=np.array(patch);pixels[:,:,3]=np.uint8(pixels[:,:,3].astype(float)*np.array(mask.filter(ImageFilter.GaussianBlur(1)))/255)
        patch=Image.fromarray(pixels);ox,oy=1168,1168;out.paste(patch,(ox,oy))
        records.append({'id':'neck_patch','region_px':[ox,oy,patch.width,patch.height],
                        'original_grid_cell':'derived original head skin','painted_pixels':int(np.count_nonzero(np.array(patch)[:,:,3])),
                        'neck_pivot_px':[w*.5-75,h*.28-4]})
    target=DEST/f'CHR_MAIN_BLUE_{direction}_ATLAS_v002.png';out.save(target)
    return records,target

def main(direction='D0'):
    records,target=pack(direction)
    rests={
     'pelvis':[565,752],'spine':[565,600],'chest':[555,360],'neck':[575,270],'head':[580,250],
     'left_upper_arm':[442,342],'left_forearm':[423,525],'left_hand':[438,707],
     'right_upper_arm':[642,320],'right_forearm':[693,485],'right_hand':[705,660],
     'left_thigh':[515,778],'left_shin':[495,1002],'left_foot':[486,1237],
     'right_thigh':[623,775],'right_shin':[618,982],'right_foot':[615,1186]}
    info=DIRECTION_DATA.get(direction,{})
    if info:rests=dict(zip(BONE_KEYS,info['rest']))
    scales={'head':[.86,.86],'torso':[1.61,1.61],'pelvis':[1.17,.82],
      'left_upper_arm':[.70,.70],'left_forearm':[.70,.80],'left_hand':[.62,.62],
      'right_upper_arm':[.62,.65],'right_forearm':[.65,.92],'right_hand':[.60,.60],
      'left_thigh':[.80,.85],'left_shin':[.90,.85],'left_foot':[.68,.68],
      'right_thigh':[.70,.80],'right_shin':[.90,.75],'right_foot':[.68,.68]}
    if direction=='D1':scales.update(torso=[1.49,1.58],left_upper_arm=[.66,.7],left_forearm=[.68,.8],right_upper_arm=[.75,.7],right_forearm=[.75,.8],right_thigh=[.88,.85],right_shin=[.95,.85])
    elif direction=='D2':scales.update(torso=[1.58,1.61],left_upper_arm=[.64,.7],left_forearm=[.66,.8],right_upper_arm=[.74,.7],right_forearm=[.72,.8],right_thigh=[.85,.85],right_shin=[.95,.85])
    elif direction=='D3':scales.update(torso=[1.66,1.66],pelvis=[1.22,.82],left_upper_arm=[.78,.7],right_upper_arm=[.78,.7],left_forearm=[.77,.8],right_forearm=[.77,.8],left_thigh=[.88,.85],right_thigh=[.88,.85],left_shin=[.95,.85],right_shin=[.95,.85])
    pivots={'head':[.50,.94],'torso':[.50,.28],'pelvis':[.50,.13],
            'left_foot':[.40,.17],'right_foot':[.28,.16]}
    z={'head':20,'torso':10,'pelvis':5,'left_upper_arm':9,'left_forearm':8,'left_hand':7,
       'right_upper_arm':-5,'right_forearm':-6,'right_hand':-7,
       'left_thigh':2,'left_shin':1,'left_foot':0,'right_thigh':-2,'right_shin':-3,'right_foot':-4}
    if direction in ['D1','D2']:
        for suffix in ['upper_arm','forearm','hand','thigh','shin','foot']:
            z['left_'+suffix],z['right_'+suffix]=z['right_'+suffix],z['left_'+suffix]
    children={'left_upper_arm':'left_forearm','left_forearm':'left_hand',
              'right_upper_arm':'right_forearm','right_forearm':'right_hand',
              'left_thigh':'left_shin','left_shin':'left_foot',
              'right_thigh':'right_shin','right_shin':'right_foot'}
    atlas=Image.open(target)
    for part in records:
        name=part['id'];w,h=part['region_px'][2:];frac=pivots.get(name,[.5,.08])
        if name=='neck_patch':
            part.update(bone='chest',pivot_px=part.pop('neck_pivot_px'),scale=scales['torso'],z_index=9,rotation_degrees=0)
            continue
        part.update(bone='chest' if name=='torso' else name,pivot_px=[round(w*frac[0],2),round(h*frac[1],2)],
                    scale=scales[name],z_index=z[name],rotation_degrees=0)
        if name=='pelvis':
            # The generated hip patch includes unwanted short-leg hems.
            # Keep the waist/crotch overlap; full thighs supply the long legs.
            part['pivot_px']=[w*.5,h*.27]
            part['offset_px']=[0,-60 if direction=='D3' else -50 if direction in ['D1','D2'] else -35]
            if direction=='D3':part.update(pivot_px=[126,72],offset_px=[0,0],scale=[1,1],source_crop_px=[430,680,700,860])
        if name in children:
            x,y,w,h=part['region_px'];alpha=np.array(atlas.crop((x,y,x+w,y+h)).getchannel('A'))
            def center_at(fraction):
                cy=round(h*fraction);ys,xs=np.where(alpha[max(0,cy-3):min(h,cy+4)]>=96)
                assert len(xs)>0,(name,fraction)
                return np.array([float(xs.mean()),float(cy)])
            start,end=center_at(.18),center_at(.90)
            delta=end-start;dest=np.array(rests[children[name]])-np.array(rests[name]);length=float(np.linalg.norm(dest))
            sx=part['scale'][0];sy=math.sqrt(max(1,length*length-(delta[0]*sx)**2))/abs(delta[1])
            mapped=delta*np.array([sx,sy]);angle=math.degrees(math.atan2(dest[1],dest[0])-math.atan2(mapped[1],mapped[0]))
            part.update(pivot_px=[round(n,3) for n in start],scale=[sx,round(sy,6)],rotation_degrees=round(angle,6),
                        attachment_px=[list(start),list(end)])
        if info and name.endswith('foot') and not part.get('directional_foot'):
            x,y,w,h=part['region_px'];alpha=np.array(atlas.crop((x,y,x+w,y+h)).getchannel('A'))
            def foot_point(fraction):
                cy=round(h*fraction);ys,xs=np.where(alpha[max(0,cy-3):min(h,cy+4)]>=96)
                return np.array([float(xs.mean()),float(cy)])
            ankle,toe=foot_point(.17),foot_point(.82);delta=toe-ankle;desired=np.array(info['toe'][name])-np.array(rests[name])
            factor=float(np.linalg.norm(desired)/np.linalg.norm(delta));angle=math.degrees(math.atan2(desired[1],desired[0])-math.atan2(delta[1],delta[0]))
            part.update(pivot_px=list(ankle),scale=[factor,factor],rotation_degrees=angle)
        elif part.get('directional_foot'):
            x,y,w,h=part['region_px'];pixels=np.array(atlas.crop((x,y,x+w,y+h)))
            skin=(pixels[:,:,0]>pixels[:,:,1]*1.025)&(pixels[:,:,1]>pixels[:,:,2]*1.015)&(pixels[:,:,3]>128)
            cy=round(h*(.40 if direction=='D3' else .55));ys,xs=np.where(skin[max(0,cy-5):min(h,cy+6)])
            pivot=[float(xs.mean()) if len(xs) else w*.5,float(cy)]
            desired={'D1':{'left_foot':110,'right_foot':140},'D2':{'left_foot':160,'right_foot':115},'D3':{'left_foot':125,'right_foot':125}}[direction][name]
            factor=desired/w
            part.update(pivot_px=pivot,scale=[factor,factor],rotation_degrees=0,anchor_method='skin-only centroid for ankle landmark; no color-key extraction')
    path=ROOT/'neurons/data/character_rig.json'
    data=json.loads(path.read_text(encoding='utf-8'));rig=data['rigs']['CHR_MAIN_PAJAMA']
    rig.update(enabled=True,production_ready=False,canvas_px=[1122,1402],foot_anchor_px=[580,1315],body_height_px=1290,stride_m=.55,walk_pelvis_drop_fraction=.043,
               costume='single light-blue pajama set shared by all chapters',
               source_mother='DOCX/最终素材/动作/CHR_MAIN_IDLE_D0__idle__P01_v004.png')
    rig['directions'][direction]={'enabled':True,'atlas':'res://'+str(target.relative_to(ROOT/'neurons')).replace('\\','/'),
         'canvas_px':[1122,1402],'foot_anchor_px':info.get('foot',[580,1315]),'body_height_px':info.get('height',1290),
         'bones':{k:{'rest_px':v} for k,v in rests.items()},'parts':records}
    rig['directions'][direction].update(knee_bend=info.get('knees',{'left':-1,'right':-1}),elbow_bend={'left':-1,'right':1},soft_skinning=True,depth_projection=direction in ['D1','D3'],crouch_drop_fraction=.13,adaptive_pelvis=True,stride_m=info.get('stride',.55),walk_lift_fraction=.025,
        source_mother=f'DOCX/最终素材/动作/CHR_MAIN_IDLE_{direction}__idle__P01_v004.png',status='Actual motion and contact verification pending')
    rig['directions'][direction]['sockets']={'left_hand':{'bone':'left_hand','offset_px':[0,36]},
         'right_hand':{'bone':'right_hand','offset_px':[0,36]},'mouth':{'bone':'head','offset_px':[49 if direction=='D0' else -49 if direction=='D2' else 0,-25 if direction in ['D0','D2'] else -35]}}
    data['notes']=['Visual cutout rig: caller owns movement, contacts and all clocks.',
                   'Per-direction calibration follows each actual mother; production_ready stays false until continuous rendered verification.',
                   'Only one main costume action rig is produced, as requested by the user.']
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    report=ROOT/'docs/validation/asset_production_20261020/main_parts.json';report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps({'method':'Generated true-alpha parts; source-preserving alpha cleanup, corrective collar patch, local Polygon2D skinning. No white-key removal.','directions':rig['directions'],'status':'Continuous actual motion and visual verification pending'},ensure_ascii=False,indent=2),encoding='utf-8')
    print(direction,'packed',target,len(records))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--direction',choices=['D0','D1','D2','D3','all'],default='D0');args=parser.parse_args()
    for direction in ['D0','D1','D2','D3'] if args.direction=='all' else [args.direction]:main(direction)
