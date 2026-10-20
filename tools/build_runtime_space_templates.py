"""Offline PNG + portable HTML templates from Godot's actual exported layouts.

No external images, network, model calls or copied candidate geometry. Original
art and existing forms are not overwritten. Re-run after changing room layouts.
"""
from __future__ import annotations
import argparse, base64, hashlib, html, io, json, math, re, shutil, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from asset_shape_contracts import draw_object, shape_instruction, spatial_description

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'deliverables' / 'space_templates_corrected_20261019'
EDITORIAL = ROOT / 'deliverables/generation_forms_20261019/data/scene_editorial.json'
SIDES={'north':'北侧远墙','east':'东侧远墙','south':'南侧近墙','west':'西侧近墙'}
SAMPLES=[
    ('画法主参考：空房',ROOT/'DOCX/新建文件夹/ENV_ROOM_L1_ROOM_BASE_v001.png','学习成组冷暖、嵌墙窗洞、薄切边与有疏密的笔触；保留本房定位图的机位和布局。'),
    ('画法补充：使用感与光影',ROOT/'DOCX/新建文件夹/dc3eba99-ce86-428f-81ef-e84724936df1.png','学习静墙与细节的对比、窗洞进深和局部光影。家具、人物、窗帘和摆位不搬入本房底图。')]

FIRST_MESSAGE='''为《NEURONS》制作二维手绘游戏素材。主画法借鉴《极乐迪斯科》的大色块、冷暖塑形和有取舍的笔触；《死亡之门》只借清楚的形体、空间层次和光影组织。
基础场景的图1是画法主参考，图2是当前房间的空间定位图；同房阶段改图时，图1改为已确认的同房底图。图2固定机位、真实地面边界、开口、不可走沟井、通路和操作留位；不把外围长宽范围补成矩形。图1只负责画法和观看关系，不把卧室房型移植到脑部、桥廊、井室或露天街道。物件参照图中的外形是结构示意，尺寸是可容纳范围，不是要求所有物件填满长方体。
建筑有实际厚度：用平静的大面承托成组材质变化与墙根暗部，转角和开口处才加强细节。墙角、门上过梁与窗边属于连续墙面，抹灰与墙顶自然接续；只保留真实开口和剖切轮廓。近墙沿既有转角与窗洞组织剖切；普通近窗像样板中那样是连续墙身内的低矮横窗，窗下墙、两侧墙段和水平窗台连成整体，窗框向墙内退，窗顶仅略高邻近墙段。先在墙上留窗洞再装框，不是在墙顶摆一个独立窗框。功能高窗按本项保留。光影有主次，其余用柔和中间调和冷影组织，不在每处加光晕或满铺斑驳。
可自由处理门窗包边、墙面色区、切边衔接、笔触疏密与光影；保持实际通路、门窗和操作地面。每房材质、房型和时段沿本项说明：普通建筑才用连续抹灰墙；脑部是连续完整的褶面和弧形边界；桥廊有狭长连接与空隙；露天街道以路缘和建筑群界定。桌椅有腿和透空，圆凳与风扇保持圆形，纤维束有弯曲走向，核心有分叶大形；矩形柜体也保留板厚、门缝和底脚。活动家具、人物与活动门窗扇独立。保留原图，另存版本。'''

def is_outdoor(room):
    environment=room.get('space_spec',{}).get('environment','')
    return room['chapter'] in [0,6] and environment!='covered_interior'

def scene_prompt(room, material, connections, fixed, reuse):
    size=room['size_m'];wall=room['physical_wall'];outdoor=is_outdoor(room)
    reference='图1是画法主参考，图2是本房空间定位图。图2只锁机位、地面轮廓与尺度、门窗位置、通路和操作留位；不逐线描摹它的纯色工程块与剖切阶梯。图1负责成品色块、建筑表面与边缘处理，不移植其房型或家具摆位。'
    if reuse:
        reference='图1是已确认的同房前阶段底图，图2是本房空间定位图。在图1上编辑本阶段的表面与氛围，保持原机位、画布、房型和摆位；图2只核门窗、尺度和操作留位，不照抄工程块外观。需要校画风时另附已确认画法参考。'
    camera=f"本房外围范围约{size[0]:g}×{size[1]:g}米，这不是矩形房型指令。固定中等高度斜侧观看，立面、地面纵深与开口内侧同时可读；沿图2的地面轴向和可见侧，不压缩长通道来凑同一画框。"
    shape=spatial_description(room)
    if outdoor:
        architecture='本项是露天街道空间，保留低路缘、现有建筑立面和实际通行地面。不把空房样板的四面墙或卧室材料搬到街道，不增加出入口。'
    elif room['chapter'] in [4,5]:
        architecture='本项沿文档定义的脑部功能区域构成空间：真实地面曲线、凹沟、洞口和狭窄连接以图2为准。远侧保留连续完整的宽褶面或本房设备边界，近侧、左侧用低位剖切让活动区可见；不添四面直墙、规则墙柱、卧室木地板、门头或凭空窗户。边界转折属于同一完整表面，不画成逐块砌出的方砖。'
    else:
        architecture=f"建筑真实墙高约{wall['height_m']:g}米、厚{wall['thickness_m']:g}米，用作尺度参照。后侧与右侧保留可读立面；前侧和左侧遮挡活动区的墙分段剖开，切边薄而有真实厚度，窗边保留必要墙段。切边衔接可围绕既有转角和开口自然组织，不把定位图的统一低墙和生硬台阶当最终造型。"
    opening=''
    if windows(room):
        opening='本房窗从连续墙身中开出：窗框退入墙面，两侧窄墙垛、凹入内壁和水平窗台包住开口，窗下实体墙连续接入左右墙段；玻璃只留透光与少量反射，窗外景压低细节。保持本房窗位，不把完整窗框插在墙顶。'
        if any(window_display(room,w)['mode']=='low_near_window' for w in windows(room)):
            opening+='普通近窗采用样板的低矮完整横窗：窗洞在墙身内，窗顶与窗边墙面齐，局部墙顶仅略高相邻剖墙；横向窗台、侧墙和窗下墙是同一建筑构造，画出薄切面与窗洞进深。'
        if any(window_display(room,w)['mode']=='functional_high_window' for w in windows(room)):
            opening+='本房功能高窗保持原高度和用途，周边保留必要墙身，不套卧室低横窗。'
    elif not outdoor and room['chapter'] not in [4,5]:
        opening='本房没有配置窗，不为借用样板的光影而另开窗；门洞、既有灯光与明暗分区沿本房用途组织。'
    painting='画法沿图1：先用几组大的明暗与冷暖关系塑形，大片墙地保留安静底色，材质变化集中在少数组团与实际使用处。开口内侧和墙根有接触暗部，转角与切面清楚，远处纹理和非重点边缘适度合并。墙面连续，门窗从同一墙身中扣出，不画工程分块缝。包边衔接、色块形状和笔触疏密可自行设计，形成有主次的绘画空间。'
    if room['chapter']==5:painting+='异化大形和深部材料沿本房说明，不套普通旧漆墙。'
    if room['chapter']==1:
        painting+='卧室以暖灰、灰紫与浅赭墙面配灰棕木地板；木纹用少数长接缝和宽色面交代。窗光为主要暖亮区，门洞内保持较暗的冷灰中间调，地板为哑光；保留日常温度。'
    return '\n'.join([f"绘制《NEURONS》{room['title']}的"+('固定街道建筑与地面。' if outdoor else '固定空间建筑底图。'),reference,material,camera,shape,'实际连接：'+connections,architecture,opening,*fixed,painting,'活动家具、人物、活动门窗扇不画入建筑底图；保留移走家具后完整的地面和操作空间。图2的网格、编号、箭头、文字与比例人仅供定位。']+(['本项编辑对应前阶段已确认的同房底图，保持同一机位、画布、门位和摆位；尚无合格底图先完成基础项。'] if reuse else []))
FONT = Path('C:/Windows/Fonts/msyh.ttc')
CORTEX_ROOMS={'atrium','memory','visual','decision','body','bridge','rhythm','index','switch','verify','identity'}
def production_room_id(room):
    c=room['chapter'];r=room['room_id']
    if c==0:return 'ENV_ROOM_HIDDEN_STREET'
    if c==1:return 'ENV_ROOM_L1_ROOM_BASE'
    if c==3 and r in ['ward','lobby','clinic','pharmacy','office']:return 'ENV_ROOM_L2_'+r.upper()+'_ASYLUM'
    if c==5 and r in CORTEX_ROOMS:return 'ENV_ROOM_L4_'+r.upper()+'_ALTERED'
    aliases={'group_therapy':'GROUP','bathroom':'BATH','double_ward':'DOUBLE','workshop':'WORK','street_plaza':'SQUARE','street_side':'SIDE','street_narrow':'NARROW','street_twisted':'TWIST','street_maintenance':'MAINT','street_node':'MUTATION','street_end':'EXIT'}
    return 'ENV_ROOM_L'+str(c)+'_'+aliases.get(r,r.upper())+'_BASE'
def font(size):
    return ImageFont.truetype(str(FONT), size) if FONT.exists() else ImageFont.load_default(size=size)
def safe(value):
    slug=re.sub(r'[^a-zA-Z0-9_-]', '_', str(value))
    return slug if slug==str(value) else slug+'_'+hashlib.sha256(str(value).encode()).hexdigest()[:8]
def png_data(im):
    b=io.BytesIO(); im.save(b,format='PNG',optimize=True); return b.getvalue()
def vec(v):
    return [float(v[0]),float(v[1])]
def palette(room):
    c=room['chapter']
    if c==1:return {'floor':(149,132,108,255),'wall':(185,176,158,255),'prop':(139,143,126,255)}
    if c in [2,3]:return {'floor':(188,194,184,255),'wall':(180,194,188,255) if c==2 else (172,183,175,255),'prop':(142,161,154,255)}
    if c in [0,6]:return {'floor':(139,149,145,255),'wall':(135,148,145,255),'prop':(119,137,131,255)}
    if c==5 and room['room_id'] not in CORTEX_ROOMS:return {'floor':(205,204,191,255),'wall':(218,216,202,255),'prop':(177,186,180,255)}
    if c==5:return {'floor':(161,145,151,255),'wall':(184,161,166,255),'prop':(142,144,155,255)}
    return {'floor':(153,163,169,255),'wall':(175,182,185,255),'prop':(133,151,158,255)}
def windows(room):
    result=[];window=room.get('config',{}).get('window',{})
    if window:
        side=window['wall'];at=window['center_m'];middle=at[0] if side in ['north','south'] else at[1]
        result.append({'wall':side,'start':middle-window['width_m']/2,'end':middle+window['width_m']/2,'sill':window['sill_height_m'],'opening':window['opening_height_m']})
    for f in room['furniture']+room.get('decor',[]):
        side=f.get('wall_mount')
        if f.get('kind')!='window' or side not in SIDES:continue
        r=f['rect'];a,b=(r[0],r[0]+r[2]) if side in ['north','south'] else (r[1],r[1]+r[3])
        result.append({'wall':side,'start':a,'end':b,'sill':float(f.get('sill_height_m',f.get('height_m',1.1))),'opening':float(f.get('opening_height_m',.83))})
    return result

def window_display(room,window):
    """Drawing spec only. Physical apertures stay unchanged in runtime_spaces.

    Ordinary near windows use the user's approved low, wall-integrated display;
    privacy/high functional windows keep their original sill and clear height.
    """
    result=dict(window);near=window['wall'] in ['south','west']
    # Prefer the exact display specification exported by the shared game helper.
    # Physical sill/opening remain in `windows(room)` for gameplay provenance.
    for entry in room.get('window_display_specs',room.get('window_display',[])):
        physical=entry.get('physical',entry)
        if physical.get('wall')!=window['wall']:continue
        if abs(float(physical.get('start',window['start']))-window['start'])>1e-5:continue
        if abs(float(physical.get('end',window['end']))-window['end'])>1e-5:continue
        shown=entry.get('drawing',entry.get('display',entry))
        result.update(sill=float(shown.get('sill_height_m',shown.get('sill',window['sill']))),opening=float(shown.get('opening_height_m',shown.get('opening',window['opening']))),mode=shown.get('mode','low_near_window' if near and window['sill']<1.5 else 'functional_high_window' if near else 'full_far_window'),source='runtime_export')
        if 'cap_height_m' in shown or 'wall_cap_height_m' in shown:result['cap_height_m']=float(shown.get('cap_height_m',shown.get('wall_cap_height_m')))
        return result
    if near and window['sill']<1.5:
        result.update(sill=min(window['sill'],.60),opening=min(window['opening'],.55,(window['end']-window['start'])*.34),mode='low_near_window')
    else:result['mode']='functional_high_window' if near else 'full_far_window'
    result['source']='legacy_shared_formula_fallback'
    return result


def architectural_union(pieces):
    """Expose the union's west/south/top faces, never the individual box seams.

    Pieces use the same metre contract as architectural_surface.gd:
    rect=[x,z,width,depth], bottom_m, height_m and a drawing group. Points use
    (x,height,z). Groups control painting order and do not change occupancy.
    """
    eps=1e-7;rank={'far':0,'mid':1,'near':2}
    valid=[p for p in pieces if p['height_m']>eps and min(p['rect'][2:])>eps]
    if not valid:return [],[]
    axes=[]
    for axis in range(3):
        values=[]
        for p in valid:
            x,z,w,d=p['rect'];b=p['bottom_m'];h=p['height_m']
            values.extend(([x,x+w],[b,b+h],[z,z+d])[axis])
        axes.append(sorted(set(round(v,5) for v in values)))
    xs,ys,zs=axes;indices=[{v:i for i,v in enumerate(a)} for a in axes];cells={}
    for p in valid:
        x,z,w,d=p['rect'];b=p['bottom_m'];h=p['height_m'];group=p['group']
        lo=[indices[i][round(v,5)] for i,v in enumerate([x,b,z])]
        hi=[indices[i][round(v,5)] for i,v in enumerate([x+w,b+h,z+d])]
        for ix in range(lo[0],hi[0]):
            for iy in range(lo[1],hi[1]):
                for iz in range(lo[2],hi[2]):
                    key=(ix,iy,iz);old=cells.get(key)
                    if old is None or rank[group]>rank[old]:cells[key]=group
    planes={}
    for (ix,iy,iz),group in cells.items():
        for side,adj,plane,uv in [('west',(ix-1,iy,iz),ix,(iz,iy)),('south',(ix,iy,iz+1),iz+1,(ix,iy)),('top',(ix,iy+1,iz),iy+1,(ix,iz))]:
            if adj not in cells:planes.setdefault((side,plane,group),set()).add(uv)
    faces=[]
    for (side,plane,group),remaining in sorted(planes.items()):
        uaxis,vaxis=(zs,ys) if side=='west' else (xs,ys) if side=='south' else (xs,zs)
        while remaining:
            u,v=min(remaining,key=lambda p:(p[1],p[0]));end=u+1
            while (end,v) in remaining:end+=1
            top=v+1
            while all((a,top) in remaining for a in range(u,end)):top+=1
            for a in range(u,end):
                for b in range(v,top):remaining.remove((a,b))
            u0,u1,v0,v1=uaxis[u],uaxis[end],vaxis[v],vaxis[top]
            if side=='west':points=[(xs[plane],v0,u0),(xs[plane],v0,u1),(xs[plane],v1,u1),(xs[plane],v1,u0)]
            elif side=='south':points=[(u0,v0,zs[plane]),(u1,v0,zs[plane]),(u1,v1,zs[plane]),(u0,v1,zs[plane])]
            else:points=[(u0,ys[plane],v0),(u1,ys[plane],v0),(u1,ys[plane],v1),(u0,ys[plane],v1)]
            faces.append({'side':side,'points':points,'group':group})
    # Split shared collinear edges at all endpoints. Coplanar shared spans are
    # internal tessellation, while silhouette and changes of face remain visible.
    lines={}
    for fi,face in enumerate(faces):
        points=face['points']
        for a,b in zip(points,points[1:]+points[:1]):
            axis=next(i for i in range(3) if abs(a[i]-b[i])>eps)
            fixed=tuple(round(a[i],8) for i in range(3) if i!=axis)
            lines.setdefault((axis,fixed),[]).append((min(a[axis],b[axis]),max(a[axis],b[axis]),fi))
    edges=[]
    for (axis,fixed),runs in lines.items():
        cuts=sorted(set(v for a,b,_ in runs for v in [a,b]))
        for a,b in zip(cuts,cuts[1:]):
            active=[fi for left,right,fi in runs if left<(a+b)*.5<right]
            normals={faces[fi]['side'] for fi in active}
            if not active or len(active)>1 and len(normals)==1:continue
            pts=[]
            for value in [a,b]:
                other=iter(fixed);pts.append(tuple(value if i==axis else next(other) for i in range(3)))
            owner=max(active,key=lambda fi:(rank[faces[fi]['group']],fi))
            edges.append({'points':pts,'group':faces[owner]['group'],'owner':owner})
    return faces,edges

def portal_at(portal):return portal.get('wall_point',portal.get('wall_point_m',portal.get('at',portal.get('at_m'))))
def connection_text(room):
    rows=[]
    nonrect=len(room.get('space_spec',{}).get('floor_polygon_m',[]))>4
    organic=room['chapter'] in [4,5]
    for p in room['portals']:
        at=portal_at(p);side=p.get('wall');start='西端' if side in ['north','south'] else '北端'
        along=at[0] if side in ['north','south'] else at[1]
        kind='单向入场边界' if p.get('role')=='entry_only_no_return_transition' else 'E1事件阈值，不是新房门' if str(p.get('toward'))=='E1' else '现有开口'
        if nonrect or organic or is_outdoor(room):
            label={'north':'北侧边界','east':'东侧边界','south':'南侧边界','west':'西侧边界'}.get(side,side)
            rows.append(f"{label}坐标({at[0]:.2f},{at[1]:.2f})m：{kind}→{p['toward']}，净宽{p['width_m']:g}m；沿实际边界留连接，不增加独立房门")
        else:rows.append(f"{SIDES.get(side,side)}距{start}{along:.2f}m：{kind}→{p['toward']}，净宽{p['width_m']:g}m，高{p.get('height_m',2.2):g}m")
    for original in windows(room):
        w=window_display(room,original)
        rows.append(f"{SIDES[w['wall']]}现有窗沿墙{w['start']:.2f}–{w['end']:.2f}m；"+(f"近墙绘画显示为低横窗，窗下墙约{w['sill']:g}m，可见窗洞高约{w['opening']:.2f}m" if w['mode']=='low_near_window' else f"窗台{w['sill']:g}m，净开口高{w['opening']:g}m")+'；窗下有实体墙，不作门')
    return '；'.join(rows) or '无新增出入口；沿本房实际边界。'

class Renderer:
    def __init__(self, room, isolated=None):
        self.room=room; self.scale=2
        p=room['projection']; self.x=p['x_basis_px']; self.z=p['depth_basis_px']; self.hp=p['height_px_per_m']
        self.wall=room['physical_wall']; self.size=room['size_m']; self.colors=palette(room)
        if isolated:
            r=isolated['rect']; h=isolated.get('height_m',1)
            points=[self.raw(x,z,y) for x in [r[0],r[0]+r[2]] for z in [r[1],r[1]+r[3]] for y in [0,h]]
        else:
            points=[self.raw(x,z,y) for x in [-.2,self.size[0]+.2] for z in [-.2,self.size[1]+.2] for y in [0,self.wall.get('height_m',2.55)]]
        self.offset=[64-min(p[i] for p in points) for i in range(2)]
        self.content_dim=tuple(int(math.ceil(max(p[i] for p in points)+self.offset[i]+64)) for i in range(2))
        self.padding=[0,0];self.dim=self.content_dim
        if not isolated:
            # Expand the canvas, never the room or metre-to-pixel transform.
            unit=max(math.ceil(self.content_dim[0]/16),math.ceil(self.content_dim[1]/9))
            self.dim=(unit*16,unit*9)
            self.padding=[(self.dim[i]-self.content_dim[i])/2 for i in range(2)]
            self.offset=[self.offset[i]+self.padding[i] for i in range(2)]
        self._architecture=None
        self.im=Image.new('RGBA',self.dim,(0,0,0,0) if isolated else (238,239,233,255)); self.d=ImageDraw.Draw(self.im)
    def raw(self,x,z,h=0):
        return ((x*self.x[0]+z*self.z[0])*self.scale,(x*self.x[1]+z*self.z[1]-h*self.hp)*self.scale)
    def p(self,x,z,h=0):
        a=self.raw(x,z,h);return (a[0]+self.offset[0],a[1]+self.offset[1])
    def polygon(self,pts,color,outline=(70,82,84,255)):
        self.d.polygon(pts,fill=color)
        if outline:self.d.line(pts+[pts[0]],fill=outline,width=2)
    def box(self,r,h,color=(153,166,160,255),bottom=0,alpha=255):
        x,z,w,d=r; a=self.p(x,z,bottom);b=self.p(x+w,z,bottom);c=self.p(x+w,z+d,bottom);q=self.p(x,z+d,bottom)
        aa=self.p(x,z,bottom+h);bb=self.p(x+w,z,bottom+h);cc=self.p(x+w,z+d,bottom+h);qq=self.p(x,z+d,bottom+h)
        colors=[tuple(int(v*.77) for v in color[:3])+(alpha,),tuple(int(v*.9) for v in color[:3])+(alpha,),tuple(color[:3])+(alpha,)]
        self.polygon([q,a,aa,qq],colors[0]);self.polygon([c,q,qq,cc],colors[1]);self.polygon([aa,bb,cc,qq],colors[2])
    def wall_segments(self,side):
        world_width,world_depth=self.size;t=self.wall.get('thickness_m',.15);height=self.wall.get('height_m',2.55)
        length=world_width if side in ['north','south'] else world_depth
        holes=[]
        for p in self.room['portals']:
            if p.get('wall')!=side:continue
            at=p.get('wall_point',p.get('wall_point_m',p.get('at',p.get('at_m'))))
            if not at:continue
            center=at[0] if side in ['north','south'] else at[1]
            holes.append((max(0,center-float(p['width_m'])/2),min(length,center+float(p['width_m'])/2),float(p.get('height_m',2.2))))
        win=[window_display(self.room,v) for v in windows(self.room) if v['wall']==side]
        def rr(a,b):
            return [a,-t,b-a,t] if side=='north' else [a,world_depth,b-a,t] if side=='south' else [-t,a,t,b-a] if side=='west' else [world_width,a,t,b-a]
        limits=self.room.get('space_spec',{}).get('wall_ranges_m',{}).get(side,[0,length])
        start,end=map(float,limits);shown=self.room['wall_display_segments'][side]
        edges={start,end}
        for a,b,h in holes:edges.update([max(start,min(end,a)),max(start,min(end,b))])
        for w in win:edges.update([max(start,min(end,w['start'])),max(start,min(end,w['end']))])
        if side in ['south','west']:
            for w in win:edges.update([max(start,min(end,w['start']-.12)),max(start,min(end,w['end']+.12))])
        for part in shown:edges.update([max(start,min(end,part['start'])),max(start,min(end,part['end']))])
        edges=sorted(edges)
        for a,b in zip(edges,edges[1:]):
            if b-a<1e-6:continue
            mid=(a+b)*.5;cap=next((float(v['height_m']) for v in shown if float(v['start'])-1e-6<=mid<=float(v['end'])+1e-6),height)
            if side in ['south','west']:
                for w in win:
                    if w['start']-.12<mid<w['end']+.12:
                        cap=max(cap,min(height,w.get('cap_height_m',w['sill']+w['opening']+.08)))
            door=next((h for left,right,h in holes if left<mid<right),None)
            if door is not None:
                if cap>door:yield rr(a,b),cap-door,door
                continue
            window=next((w for w in win if w['start']<mid<w['end']),None)
            if window:
                if min(cap,window['sill'])>0:yield rr(a,b),min(cap,window['sill']),0
                top=window['sill']+window['opening']
                if cap>top:yield rr(a,b),cap-top,top
            elif cap>0:yield rr(a,b),cap,0
    def architecture_pieces(self):
        pieces=[];by_side={};corners=[];eps=1e-6
        for side in SIDES:
            by_side[side]=[]
            for r,h,b in self.wall_segments(side):
                piece={'rect':list(r),'height_m':float(h),'bottom_m':float(b),'group':'near' if side in ['south','west'] else 'far','side':side}
                by_side[side].append(piece);pieces.append(piece)
        width,depth=self.size;t=float(self.wall['thickness_m'])
        # Only actual endpoint-to-endpoint wall spans get an outside corner.
        # A door at an endpoint, truncated L boundary or open street mouth has
        # no pair of overlapping solid spans and therefore gains no fill.
        for name,a,at_a,b,at_b,rect in [
            ('north_west','north',0,'west',0,[-t,-t,t,t]),
            ('north_east','north',width,'east',0,[width,-t,t,t]),
            ('south_west','south',0,'west',depth,[-t,depth,t,t]),
            ('south_east','south',width,'east',depth,[width,depth,t,t])]:
            def touches(piece,side,endpoint):
                r=piece['rect'];lo=r[0] if side in ['north','south'] else r[1];hi=lo+(r[2] if side in ['north','south'] else r[3])
                return abs(lo-endpoint)<eps or abs(hi-endpoint)<eps
            for pa in by_side[a]:
                if not touches(pa,a,at_a):continue
                for pb in by_side[b]:
                    if not touches(pb,b,at_b):continue
                    bottom=max(pa['bottom_m'],pb['bottom_m']);top=min(pa['bottom_m']+pa['height_m'],pb['bottom_m']+pb['height_m'])
                    if top-bottom<=eps:continue
                    piece={'rect':rect,'bottom_m':bottom,'height_m':top-bottom,'group':'near' if 'near' in [pa['group'],pb['group']] else 'far','corner':name}
                    pieces.append(piece);corners.append(piece)
        spec=self.room.get('space_spec',{})
        partitions=spec.get('partitions',self.room.get('config',{}).get('static_walls',self.room.get('partitions',[])))
        for f in partitions:
            if isinstance(f,dict):
                if f.get('logical_exclusion') or f.get('render') is False:continue
                pieces.append({'rect':f.get('rect_m',f.get('rect')),'bottom_m':float(f.get('bottom_m',0)),'height_m':float(f.get('height_m',2)),'group':'mid'})
            else:pieces.append({'rect':f,'bottom_m':0.,'height_m':2.,'group':'mid'})
        for f in self.room['furniture']+self.room.get('decor',[]):
            if f.get('logical_exclusion') or f.get('render') is False:continue
            if f.get('kind') not in ['wall','facade','shower']:continue
            for rect in f.get('collision_rects') or [f['rect']]:pieces.append({'rect':rect,'bottom_m':float(f.get('bottom_m',0)),'height_m':float(f.get('height_m',2)),'group':'mid'})
        return pieces,corners
    def architecture_surface(self):
        if self._architecture is None:
            exported=self.room.get('architecture_surface')
            if exported is not None:
                # These exact faces and boundary edges come from the actual
                # game's architectural_surface.gd, not a second Python model.
                extra=[];source_ids={str(p['source_id']) for p in exported.get('pieces',[]) if 'source_id' in p}
                spec=self.room.get('space_spec',{})
                if not exported.get('includes_fixed_partitions',False):
                    for f in spec.get('partitions',self.room.get('config',{}).get('static_walls',self.room.get('partitions',[]))):
                        if isinstance(f,dict):
                            if f.get('logical_exclusion') or f.get('render') is False:continue
                            extra.append({'rect':f.get('rect_m',f.get('rect')),'bottom_m':float(f.get('bottom_m',0)),'height_m':float(f.get('height_m',2)),'group':'mid'})
                        else:extra.append({'rect':f,'bottom_m':0.,'height_m':2.,'group':'mid'})
                for f in self.room['furniture']+self.room.get('decor',[]):
                    if f.get('logical_exclusion') or f.get('render') is False or str(f['id']) in source_ids:continue
                    kind=f.get('kind')
                    if self.room['chapter'] in [4,5] and kind=='wall':continue
                    if kind not in ['wall','facade','shower'] or kind=='shower' and exported.get('includes_shower_walls',False):continue
                    for rect in f.get('collision_rects') or [f['rect']]:extra.append({'rect':rect,'bottom_m':float(f.get('bottom_m',0)),'height_m':float(f.get('height_m',2)),'group':'mid'})
                extra_faces,extra_edges=architectural_union(extra)
                for fi,face in enumerate(extra_faces):face['edges']=[edge['points'] for edge in extra_edges if edge['owner']==fi]
                self._architecture={'pieces':exported.get('pieces',[]),'corners':exported.get('corner_fills',[]),'faces':exported['faces'],'source':'runtime_export','includes_fixed_partitions':exported.get('includes_fixed_partitions',False),'includes_shower_walls':exported.get('includes_shower_walls',False),'supplemental_pieces':extra,'supplemental_faces':extra_faces}
            else:
                pieces,corners=self.architecture_pieces();faces,edges=architectural_union(pieces)
                for fi,face in enumerate(faces):face['edges']=[edge['points'] for edge in edges if edge['owner']==fi]
                self._architecture={'pieces':pieces,'corners':corners,'faces':faces,'source':'legacy_union_fallback','includes_fixed_partitions':True}
        return self._architecture
    def architecture(self,group):
        surface=self.architecture_surface();faces=surface['faces']+surface.get('supplemental_faces',[]);color=self.colors['wall']
        colors={'west':tuple(int(v*.77) for v in color[:3])+(255,),'south':tuple(int(v*.88) for v in color[:3])+(255,),'top':tuple(color[:3])+(255,)}
        def point(v):return self.p(v[0],v[2],v[1])
        def drawing_pass(face):
            source_group=face.get('group','far')
            if source_group.startswith('fixed:'):return 'mid'
            return 'far' if source_group=='all' else source_group
        ordered=sorted((face for face in faces if drawing_pass(face)==group),key=lambda face:(max(self.raw(v[0],v[2])[1] for v in face['points']),face['side']=='top'))
        for face in ordered:
            pixels=[point(v) for v in face['points']]
            if face['side'] in colors:tone=colors[face['side']]
            else:
                normal=face.get('normal',[0,1]);light=.86-.08*float(normal[0])-.04*float(normal[1])
                if isinstance(face.get('tone'),(int,float)):light=float(face['tone'])
                tone=tuple(max(0,min(255,round(v*light))) for v in color[:3])+(255,)
            self.polygon(pixels,tone,outline=None)
            # PIL's separately rasterised oblique polygons can leave one-pixel
            # holes at collinear T-junctions, despite perfectly shared metre
            # geometry. A one-source-pixel fill overlap seals that coverage;
            # it is the face colour, never a new block edge or changed anchor.
            self.d.line(pixels+[pixels[0]],fill=tone,width=2)
            # Draw immediately, so a later near face can cover a distant edge.
            for edge in face.get('edges',[]):self.d.line([point(v) for v in edge],fill=colors['west'],width=max(1,round(1.1*self.scale)))
    def window_frames(self,near=False):
        # This is an aperture locator, not a filled window sprite. A solid pane
        # over a cut wall previously taught image tools to draw a standing board.
        # Near ordinary windows have a low, complete wall-integrated opening.
        # Ground positions/widths and full physical apertures stay in runtime JSON.
        for original in windows(self.room):
            w=window_display(self.room,original)
            side=w['wall']
            if (side in ['south','west'])!=near:continue
            a,b=w['start'],w['end'];sill=w['sill'];top=sill+w['opening'];size=self.size
            t=float(self.wall['thickness_m']);height=float(self.wall['height_m'])
            length=size[0] if side in ['north','south'] else size[1]
            def rect(left,right):
                return [left,-t,right-left,t] if side=='north' else [left,size[1],right-left,t] if side=='south' else [-t,left,t,right-left] if side=='west' else [size[0],left,t,right-left]
            def at(along,h,layer=0):
                return self.p(along,-t*layer if side=='north' else size[1]+t*layer,h) if side in ['north','south'] else self.p(-t*layer if side=='west' else size[0]+t*layer,along,h)
            # Supporting wall, lower wall and lintel are already in the union.
            # This pass draws only recessed reveals and the inset frame.
            face=1 if near else 0;inset=.52
            for edge in [a,b]:
                self.polygon([at(edge,sill,face),at(edge,top,face),at(edge,top,inset),at(edge,sill,inset)],(123,128,117,255),outline=None)
            self.polygon([at(a,sill,face),at(b,sill,face),at(b,sill,inset),at(a,sill,inset)],(195,190,168,255),outline=None)
            self.polygon([at(a,top,face),at(b,top,face),at(b,top,inset),at(a,top,inset)],(133,136,121,255),outline=None)
            pts=[at(a,sill,inset),at(b,sill,inset),at(b,top,inset),at(a,top,inset)]
            # Clear opening (no opaque green fill); the frame is recessed.
            self.d.line(pts+[pts[0]],fill=(85,107,111,255),width=3*self.scale)
            self.d.line([at((a+b)/2,sill,inset),at((a+b)/2,top,inset)],fill=(99,118,117,255),width=2*self.scale)
    def floor(self):
        w,d=self.size
        spec=self.room.get('space_spec',{})
        outline=spec.get('floor_polygon_m',[[0,0],[w,0],[w,d],[0,d]])
        holes=spec.get('floor_holes_m',[])
        self.polygon([self.p(*p) for p in outline],self.colors['floor'])
        for feature in spec.get('floor_features',[]):
            if not feature.get('render',True):continue
            points=feature.get('polygon_m')
            if points is None and feature.get('rect_m'):
                x,z,w,h=feature['rect_m'];points=[[x,z],[x+w,z],[x+w,z+h],[x,z+h]]
            if points:self.polygon([self.p(*p) for p in points],tuple(feature.get('color_rgba',[100,113,116,255])))
        # Clip construction grid to the real L-shaped floor, not the excluded
        # void that older layouts represented as an enormous solid rectangle.
        mask=Image.new('L',self.dim,0);md=ImageDraw.Draw(mask);md.polygon([self.p(*p) for p in outline],fill=255)
        for hole in holes:
            points=hole.get('polygon_m',hole.get('points',[])) if isinstance(hole,dict) else hole
            if not points:continue
            pixels=[self.p(*p) for p in points]
            self.polygon(pixels,(238,239,233,255));md.polygon(pixels,fill=0)
        grid=Image.new('RGBA',self.dim,(0,0,0,0));gd=ImageDraw.Draw(grid)
        for z in range(1,math.ceil(d)):
            gd.line([self.p(0,z),self.p(w,z)],fill=(179,184,170,255),width=1)
        for x in range(1,math.ceil(w)):
            gd.line([self.p(x,0),self.p(x,d)],fill=(179,184,170,255),width=1)
        self.im.paste(grid,(0,0),Image.composite(grid.getchannel('A'),Image.new('L',self.dim,0),mask));self.d=ImageDraw.Draw(self.im)
    def ruler(self,at):
        x,z=at;foot=self.p(x,z);top=self.p(x,z,1.75);sx=self.scale
        self.d.ellipse([top[0]-8*sx,top[1],top[0]+8*sx,top[1]+16*sx],fill=(120,141,145,170))
        self.d.line([(top[0],top[1]+18*sx),(foot[0],foot[1]-32*sx)],fill=(120,141,145,180),width=16*sx)
        for side in [-1,1]:self.d.line([(foot[0],foot[1]-35*sx),(foot[0]+side*9*sx,foot[1])],fill=(120,141,145,180),width=5*sx)
    def prop(self,item,color=None):
        # Capacity/collision rectangles are not appearance meshes. Each noun
        # gets a recognisable schematic, including the actual negative spaces.
        return draw_object(self,item,color)
    def stairs(self):
        geometry=self.room.get('config',{}).get('stairs_geometry',{})
        # Landings share the navigation plane; tread lips are the game's
        # existing four pixels, not cumulative risers or invented world height.
        for r in geometry.get('landings',[]):
            x,z,w,d=r
            self.polygon([self.p(x,z),self.p(x+w,z),self.p(x+w,z+d),self.p(x,z+d)],(174,184,175,255))
        for flight in geometry.get('flights',[]):
            x,z,w,d=flight['rect_m'];direction=flight.get('direction',[0,1]);count=max(1,int(flight.get('steps',9)))
            along_x=abs(direction[0])>abs(direction[1]);positive=direction[0 if along_x else 1]>0
            for step in range(count):
                progress=step if positive else count-1-step
                rect=[x+w*step/count,z,w/count,d] if along_x else [x,z+d*step/count,w,d/count]
                tone=tuple(min(255,n+(5 if progress%2 else 0)) for n in (130,149,143))+(255,)
                self.box(rect,4.0/self.hp,tone)
            amount=min(w,d)*.25;middle=[x+w*.5,z+d*.5]
            start=self.p(middle[0]-direction[0]*amount,middle[1]-direction[1]*amount)
            end=self.p(middle[0]+direction[0]*amount,middle[1]+direction[1]*amount)
            self.d.line([start,end],fill=(214,223,204,255),width=2*self.scale)
            angle=math.atan2(end[1]-start[1],end[0]-start[0])
            for turn in [-.6,.6]:self.d.line([end,(end[0]-math.cos(angle+turn)*10*self.scale,end[1]-math.sin(angle+turn)*10*self.scale)],fill=(214,223,204,255),width=2*self.scale)
    def draw(self,placed=False):
        self.floor()
        for f in self.room['furniture']+self.room.get('decor',[]):
            if f.get('kind')=='shower' and f.get('render',True):
                x,z,w,d=f['rect']
                self.polygon([self.p(x,z),self.p(x+w,z),self.p(x+w,z+d),self.p(x,z+d)],(154,169,158,255))
        self.architecture('far');self.window_frames();self.stairs();self.architecture('mid')
        if self.room['chapter'] in [4,5]:
            # Searchable cortical grooves/folds are fixed organic structures,
            # not rectangular building slabs. They appear in both base and
            # placement locators, without changing their gameplay envelopes.
            for f in self.room['furniture']+self.room.get('decor',[]):
                if f.get('kind')=='wall' and not f.get('logical_exclusion') and f.get('render',True):self.prop(f)
        if placed:
            def depth(f):
                x,z,w,d=f['rect'];return max(self.p(a,b)[1] for a in [x,x+w] for b in [z,z+d])
            for i,f in sorted(enumerate(self.room['furniture']+self.room.get('decor',[])),key=lambda x:depth(x[1])):
                if f.get('wall_mount') or f.get('kind') in ['wall','facade'] or f.get('logical_exclusion') or f.get('render') is False:continue
                if f.get('kind')!='shower':self.prop(f)
                stand=f.get('operation_approach')
                if stand:
                    a=self.p(*stand);self.d.ellipse((a[0]-7,a[1]-7,a[0]+7,a[1]+7),fill=(189,112,70,255))
                top=self.p(f['rect'][0]+f['rect'][2]/2,f['rect'][1]+f['rect'][3]/2,f.get('height_m',.8))
                self.d.text(top,str(i+1),font=font(22),fill=(36,56,57,255),anchor='mm')
            for p in self.room['portals']:
                at=p.get('at',p.get('at_m'))
                if at:self.d.text(self.p(*at),str(p['toward']),font=font(18),fill=(28,76,88,255),anchor='mm')
            self.ruler(self.room['spawn_m'])
        self.architecture('near');self.window_frames(near=True)
        return self.im

def build(destination,share):
    data=json.loads((destination/'runtime_spaces.json').read_text(encoding='utf-8-sig'))
    if data['failures']:raise RuntimeError('Resolve exported layout issues before producing templates: '+str(data['failures']))
    if data.get('schema',0)<2:raise RuntimeError('Re-export schema2 after shared presentation changes; old transparent-wall data is not accepted.')
    for name,expected in data.get('source_sha256',{}).items():
        if hashlib.sha256((ROOT/'neurons'/name).read_bytes()).hexdigest()!=expected:
            raise RuntimeError('Layout source changed; run export_runtime_spaces.gd before building templates: '+name)
    source_form=Path('C:/Users/23623/Desktop/NEW/最终表单/01_美术资产表_可分享.html')
    if source_form.exists():
        asset_table=json.loads(re.search(r'<script[^>]*id="table-data"[^>]*>([\s\S]*?)</script>',source_form.read_text(encoding='utf-8-sig')).group(1))
        asset_names={a['id']:a.get('filename',a['id']+'_v001.png') for g in asset_table['groups'] for a in g['items']}
    else:
        # A second computer need not have the first owner's Windows account.
        packs=[json.loads((ROOT/'deliverables/generation_forms_20261019/data'/n).read_text(encoding='utf-8')) for n in ['scene_items.json','non_scene_items.json']]
        asset_names={a['id']:a['filename'] for pack in packs for a in pack['items']}
    rows=json.loads(EDITORIAL.read_text(encoding='utf-8-sig'));rows=rows['items'] if isinstance(rows,dict) else rows
    editorial={r['id']:r for r in rows}
    generated=destination/'png';generated.mkdir(exist_ok=True)
    cards=[];files=[];objects=0
    for room in data['rooms']:
        if room.get('wall_display_segments') is None or room.get('physical_wall') is None:raise RuntimeError('Missing physical/display wall contract: '+room['id'])
        if room.get('architecture_surface') is None or 'window_display_specs' not in room:raise RuntimeError('Re-export shared architecture faces and window display specifications: '+room['id'])
        for key in ['x_basis_px','depth_basis_px','height_px_per_m']:
            if room['projection'][key]!=data['presentation'][key]:raise RuntimeError('Actual layout differs from shared projection: '+room['id']+' '+key)
        if room['id'] not in editorial:raise RuntimeError('Missing per-room material brief: '+room['id'])
        stem=safe(room['id']);folder=generated/stem;folder.mkdir(exist_ok=True)
        images={}
        room_renderer=Renderer(room)
        room_png_geometry={'pixel_size':list(room_renderer.dim),'content_pixel_size':list(room_renderer.content_dim),'padding_px':[room_renderer.padding[0],room_renderer.padding[1],room_renderer.padding[0],room_renderer.padding[1]],'canvas_aspect_ratio':[16,9],'canvas_policy':'Expand canvas with equal opposite padding only. The metre projection, room footprint and object scale are unchanged.','ground_origin_px':[round(n,3) for n in room_renderer.p(0,0)],'x_basis_px':[n*room_renderer.scale for n in room['projection']['x_basis_px']],'depth_basis_px':[n*room_renderer.scale for n in room['projection']['depth_basis_px']],'height_px_per_m':room['projection']['height_px_per_m']*room_renderer.scale,'source_scale':room_renderer.scale,'runtime_origin_px':room['projection']['origin_px'],'alignment':'runtime pixel = template pixel / source_scale + runtime_origin_px - ground_origin_px / source_scale; then apply runtime camera transform'}
        for label,placed in [('space',False),('placement',True)]:
            im=(Renderer(room) if placed else room_renderer).draw(placed);raw=png_data(im);p=folder/(stem+'_'+label+'.png');p.write_bytes(raw);files.append(p)
            images[label]='data:image/png;base64,'+base64.b64encode(raw).decode()
        props=[]
        for i,f in enumerate(room['furniture']+room.get('decor',[]),1):
            if f.get('kind') in ['wall','mapping','floor_marks'] or f.get('wall_mount') or f.get('logical_exclusion') or f.get('render') is False or float(f.get('height_m',0))<=.02:continue
            renderer=Renderer(room,isolated=f);renderer.prop(f)
            raw=png_data(renderer.im);name=stem+'_'+safe(f['id'])+'_volume.png';p=folder/name;p.write_bytes(raw);files.append(p);objects+=1
            r=f['rect'];h=float(f.get('height_m',.8));at=f.get('operation_approach') or f['at']
            dx=(at[0]-r[0]-r[2]/2)/max(.01,r[2]/2); dz=(at[1]-r[1]-r[3]/2)/max(.01,r[3]/2)
            face=('east' if dx>0 else 'west') if abs(dx)>abs(dz) else ('south' if dz>0 else 'north')
            face_text={'west':'左侧可见立面','south':'下方可见立面','east':'背向镜头的右侧面','north':'背向镜头的后侧面'}[face]
            front=f' 主要操作面在{face_text}.' if f.get('operation_approach') and max(abs(dx),abs(dz))>1 and f.get('kind') in ['drawer','cabinet','wardrobe','books','desk','console','counter'] else ''
            if f.get('collision_rects'):front+=' 保留模板的分段轮廓和中间开口，不把包围尺寸填成一整块实体。'
            family,construction=shape_instruction(f)
            if f.get('silhouette_note'):construction+=' '+f['silhouette_note']
            prompt=f"绘制{f.get('name',f['id'])}的独立二维素材。\n物件构造：{construction}\n尺寸参考的宽×深×高约{r[2]:g}×{r[3]:g}×{h:g}米，是本处可容纳范围；只固定落脚支点、总高、可见侧、操作处和拿取空间。模板示意不是最终外形，曲线、薄板、支腿和开口必须按真实构造保留，不把长深高填满为方盒。\n沿已确认同类母图的画法，没有母图时沿所附画法参考；以冷暖色块和选择性笔触塑形，柔和中性光，细节集中在结构与操作处。工具支持时透明底，否则均匀浅暖灰底；不画场景、地面、外扩光晕或大片固定投影。"+front
            props.append({'number':i,'id':f['id'],'name':f.get('name',f['id']),'kind':f.get('kind'),'shape_family':family,'construction':construction,'size':[round(r[2],3),round(r[3],3),round(h,3)],'position':r[:2],'approach':f.get('operation_approach'),'operation_face':face if max(abs(dx),abs(dz))>1 else None,'operation_face_text':face_text if max(abs(dx),abs(dz))>1 else '固定陈设, 无指定开合面','filename':name,'pixel_size':renderer.dim,'ground_anchor_px':[round(n,2) for n in renderer.p(r[0]+r[2]/2,r[1]+r[3]/2)],'png':'data:image/png;base64,'+base64.b64encode(raw).decode(),'prompt':prompt,'wall_mount':f.get('wall_mount',None),'source':f.get('source',f.get('data',{}).get('source',''))})
        size=room['size_m'];wall=room['physical_wall'];outdoor=is_outdoor(room);e=editorial[room['id']]
        connections=connection_text(room)
        reuse=room['chapter']==5 and room['room_id'] in CORTEX_ROOMS or room['chapter']==3 and room['room_id'] in ['lobby','clinic','pharmacy','office']
        fixed=[]
        if room.get('config',{}).get('stairs_geometry',{}).get('flights'):fixed.append('固定楼梯踏步和转角平台画入本张，走向沿模板；平台与现有通路连续，不增高台、门或通道。')
        if any(f.get('kind')=='shower' for f in room['furniture']+room.get('decor',[])):fixed.append('两处淋浴的固定三面薄围墙画入本张，保留真实侧向开口与内侧地面；活动帘另层，不用整个包围矩形画成封闭方盒。')
        material=room.get('space_spec',{}).get('material_brief') or e['material_prompt']
        if room['id']=='L3_ward':
            material='精神病院病房，冷灰绿与偏白的大色面、浅灰地面，保持完整墙面和有限使用磨损。门窗、设施与操作位沿本房当前定位建立；本项有自己的门向和采光窗，不套用L2病房的旧门位。'
        prompt=scene_prompt(room,material,connections,fixed,reuse)
        asset_id=production_room_id(room)
        if asset_id not in asset_names:raise RuntimeError('No existing production asset ID for '+room['id']+': '+asset_id)
        surface=room_renderer.architecture_surface()
        surface_meta={'source':surface['source'],'pieces':surface['pieces'],'faces':surface['faces'],'corner_fills':surface['corners'],'includes_fixed_partitions':surface.get('includes_fixed_partitions',False),'includes_shower_walls':surface.get('includes_shower_walls',False),'supplemental_pieces':surface.get('supplemental_pieces',[]),'supplemental_faces':surface.get('supplemental_faces',[]),'internal_block_outlines':False,'visible_sides':['west','south','top'],'point_order':['x','height','z']}
        cards.append({'id':room['id'],'asset_id':asset_id,'art_filename':asset_names[asset_id],'chapter':room['chapter'],'title':e.get('title',room['title']),'room_id':room['room_id'],'size':size,'wall':wall,'presentation':room['presentation'],'wall_display_segments':room['wall_display_segments'],'architecture_surface':surface_meta,'floor_polygon_m':room.get('space_spec',{}).get('floor_polygon_m'),'floor_holes_m':room.get('space_spec',{}).get('floor_holes_m',[]),'shape_description':spatial_description(room),'outdoor':outdoor,'environment':room.get('space_spec',{}).get('environment','interior'),'reuse':reuse,'window_display':[{'physical':w,'drawing':window_display(room,w)} for w in windows(room)],'portals':[p['toward'] for p in room['portals']],'connection_text':connections,'material_prompt':material,'base':images['space'],'placed':images['placement'],'props':props,'prompt':prompt,'base_filename':stem+'_space.png','placement_filename':stem+'_placement.png','room_png_geometry':room_png_geometry,'version':room.get('spatial_version',room['geometry_version'])})
    manifest={'scenes':len(cards),'furniture_templates':objects,'files':len(files),'source':'runtime_spaces.json','generated_at':data.get('generated_at'),'presentation':data['presentation'],'source_sha256':data.get('source_sha256',{}),'editorial_source':str(EDITORIAL.relative_to(ROOT)),'editorial_sha256':hashlib.sha256(EDITORIAL.read_bytes()).hexdigest(),'editorial_policy':'Only material_prompt reused; portals, direction, floor and placement derive solely from actual runtime export.','reference_policy':'Style image governs painting and architectural surface/edge treatment; space locator fixes camera, footprint, scale, opening positions and operation clearance. Runtime cut heights remain metadata, not mandatory finished silhouettes.','architecture_policy':'Render the exact exposed faces and true coplanar boundary edges exported from the game. Connected external corners belong to the same solid union; no internal box seams are outlined.','canvas_policy':'Room and placement canvases have exact 16:9 aspect using padding only. Furniture canvases and all metre projection scales remain unchanged. Ground anchors include the added padding.','window_locator_policy':'Ground positions/widths and full physical apertures remain recorded. Drawing sill, opening and cap come from the shared runtime window_display_specs; ordinary near windows are low horizontal apertures within the continuous wall. Functional high/far windows retain their source dimensions.','status':'spatial locators and revised prompts; AI generated appearance, runtime art integration and normal human play remain separate acceptance'}
    (destination/'scene_generation_contracts.json').write_text(json.dumps([{k:v for k,v in r.items() if k not in ['base','placed','props','architecture_surface']} for r in cards],ensure_ascii=False,indent=2),encoding='utf-8')
    (destination/'template_anchors.json').write_text(json.dumps([{'id':r['id'],'room_png':r['base_filename'],'room_png_geometry':r['room_png_geometry'],'window_display':r['window_display'],'furniture':[{k:v for k,v in p.items() if k not in ['png','prompt']} for p in r['props']]} for r in cards],ensure_ascii=False,indent=2),encoding='utf-8')
    (destination/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    samples=[]
    for name,path,note in SAMPLES:
        path=Path(path)
        if path.exists():samples.append({'name':name,'note':note,'filename':path.name,'png':'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()})
    page=PAGE.replace('__DATA__',json.dumps(cards,ensure_ascii=False).replace('</','<\\/')).replace('__META__',json.dumps(manifest,ensure_ascii=False).replace('</','<\\/')).replace('__SAMPLES__',json.dumps(samples,ensure_ascii=False).replace('</','<\\/')).replace('__FIRST__',json.dumps(FIRST_MESSAGE,ensure_ascii=False).replace('</','<\\/')).replace('__COUNT__',str(len(cards))).replace('__OBJECTS__',str(objects))
    pagepath=destination/'00_空间与家具模板_可分享.html';pagepath.write_text(page,encoding='utf-8')
    zip_path=destination/'NEURONS_空间与家具模板_20261019.zip'
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
        for p in files+[pagepath,destination/'runtime_spaces.json',destination/'manifest.json',destination/'template_anchors.json',destination/'scene_generation_contracts.json']:
            z.write(p,p.relative_to(destination))
    if share:
        share.mkdir(parents=True,exist_ok=True)
        previous=share/pagepath.name
        if previous.exists() and previous.read_bytes()!=pagepath.read_bytes():
            archive=share.parent/'历史'/('空间模板修订前_'+hashlib.sha256(previous.read_bytes()).hexdigest()[:10]+'.html');archive.parent.mkdir(exist_ok=True)
            if not archive.exists():shutil.copy2(previous,archive)
        for p in [pagepath,zip_path]:shutil.copy2(p,share/p.name)
    print(json.dumps(dict(manifest,html=str(pagepath),share=str(share)),ensure_ascii=False))

PAGE=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEURONS 空间与家具模板</title>
<style>body{margin:0;background:#f3f1e9;color:#273d3b;font:16px/1.6 system-ui,"Microsoft Yahei",sans-serif}main{max-width:1180px;margin:auto;padding:24px}h1{font-size:26px;margin:0}p{margin:8px 0}header{border-bottom:1px solid #c7cdc2;padding-bottom:16px}nav{display:flex;gap:10px;margin:18px 0;flex-wrap:wrap}input,select,button{font:inherit;padding:9px 12px;border:1px solid #b0beb4;border-radius:6px;background:#fff;color:inherit}button{cursor:pointer}button.primary{background:#345c54;color:white}article{background:white;border:1px solid #cbd3c7;border-radius:8px;margin:14px 0;padding:16px}.meta{font-size:14px;color:#5b6b63}.images{display:grid;grid-template-columns:1fr 1fr;gap:14px}img{max-width:100%;height:auto;background:#e7e8de;border-radius:5px}.images figure{margin:0}.actions{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0}summary{cursor:pointer;font-weight:600}.prop{display:grid;grid-template-columns:180px 1fr;gap:14px;border-top:1px solid #e2e7dd;padding:12px 0}.prop img{max-height:190px;width:100%;object-fit:contain;background:repeating-conic-gradient(#e8e9e4 0% 25%,#fff 0% 50%) 0/20px 20px}textarea{width:100%;min-height:60px;box-sizing:border-box;font:14px/1.5 inherit}.notice{background:#e2e9dc;padding:12px;border-radius:6px}a{color:#2f695b}#toast{position:fixed;bottom:20px;right:20px;background:#273d3b;color:#fff;padding:10px;border-radius:5px;display:none}@media(max-width:650px){.images{grid-template-columns:1fr}.prop{grid-template-columns:110px 1fr}main{padding:12px}}</style>
<main><header><h1>NEURONS 场景与家具 · 画法参考＋空间定位</h1><p>__COUNT__ 个实际关卡空间 · __OBJECTS__ 个物件结构参考，数量不等于人工制作任务数。</p><p><b>新对话:</b> 先复制首次说明；每房按卡片附图，再复制本房提示词。基础场景用画法参考＋定位图；同房阶段用已确认底图＋定位图。</p><p class="notice">画法参考只借观看关系、色块与笔触；每房独立定位图负责真实曲线、沟井、入口和操作位。物件按结构示意与本项构造绘制，尺寸是容纳范围，不要求填满为方盒。</p></header>
<p><button id="first-message">复制新对话首次说明</button></p><details><summary>已确认的两张画法参考（不借布局）</summary><div id="style-samples" class="images"></div></details><nav><select id="chapter"><option value="all">全部场景</option><option value="1">L1 卧室</option><option value="2">L2 医院</option><option value="3">L3 精神病院</option><option value="4">L4 脑部探索</option><option value="5">L5 异化与深部</option><option value="6">L6 Street</option><option value="0">隐藏路线</option></select><input id="query" placeholder="搜索房间或物品"><span id="counter"></span></nav><section id="rooms"></section><p class="meta">同房异化沿用原资产ID；已有原图另存版本。正式资产ID与文件名沿用原美术表，物件文件名仅用于模板。图中一格1米；窗边局部墙段说明嵌墙关系，成品切边仍需核遮挡。优先复用已有素材，不把所有尺度参考变成人工订单。本页内嵌图像，可单独转发离线打开；ZIP保留PNG、运行空间JSON和锚点。定位图不是成品画法，生成结果仍需对位、接入和实际观看验收。</p></main><div id="toast"></div><script id="space-data" type="application/json">__DATA__</script><script id="template-meta" type="application/json">__META__</script><script id="style-data" type="application/json">__SAMPLES__</script><script>
const rooms=JSON.parse(document.getElementById('space-data').textContent), root=document.getElementById('rooms');
// UI labels are rounded; full-precision runtime coordinates stay in JSON/PNG anchors.
for(const r of rooms){r.size=r.size.map(v=>Number(v.toFixed(3)));r.wall={...r.wall,height_m:Number(r.wall.height_m.toFixed(3)),thickness_m:Number(r.wall.thickness_m.toFixed(3))};for(const p of r.props){p.position=p.position.map(v=>Number(v.toFixed(3)));if(p.approach)p.approach=p.approach.map(v=>Number(v.toFixed(3)))}}
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function save(url,name){const a=document.createElement('a');a.href=url;a.download=name;a.click()}
function toast(s){const t=document.getElementById('toast');t.textContent=s;t.style.display='block';setTimeout(()=>t.style.display='none',1800)}
async function copy(s){try{await navigator.clipboard.writeText(s)}catch(e){const t=document.createElement('textarea');t.value=s;document.body.append(t);t.select();const ok=document.execCommand('copy');t.remove();if(!ok){toast('复制被设备限制，请选中提示词手动复制');return}}toast('已复制')}
const templateMeta=JSON.parse(document.getElementById('template-meta').textContent),samples=JSON.parse(document.getElementById('style-data').textContent);
for(const s of samples){const f=document.createElement('figure');f.innerHTML='<img loading="lazy" src="'+s.png+'" alt="'+esc(s.name)+'"><figcaption><b>'+esc(s.name)+'</b><p>'+esc(s.note)+'</p><button>下载画法参考</button></figcaption>';f.querySelector('button').onclick=()=>save(s.png,s.filename);document.getElementById('style-samples').append(f)}
document.getElementById('first-message').onclick=()=>copy(__FIRST__);
function render(){
 const ch=document.getElementById('chapter').value,q=document.getElementById('query').value.trim().toLowerCase();root.replaceChildren();let count=0;
 rooms.forEach((r,ri)=>{
  if(ch!=='all'&&String(r.chapter)!==ch)return;
  if(q&&!JSON.stringify([r.title,r.room_id,r.props.map(p=>p.name)]).toLowerCase().includes(q))return;
  count++;const a=document.createElement('article');
   const upload=r.reuse?'图1用已确认的同房前阶段底图，图2核本房定位；仅画风需要校正时补画法参考。':r.outdoor?'图1只借笔触与明暗，不搬入室内墙体；图2保留本段实际街道结构。':'图1负责画法和墙窗处理；图2负责机位、布局与尺度。';
  a.innerHTML='<h2>'+esc(r.title)+' <small class="meta">'+esc(r.id)+'</small></h2>'+
   '<p class="meta">空间范围 '+r.size.join(' × ')+' m'+(r.outdoor?' · 含街道及原有支房':' · 原建筑墙高 '+r.wall.height_m+' m / 厚 '+r.wall.thickness_m+' m')+' · '+esc(r.asset_id)+' · 连接: '+esc(r.portals.join(' / ')||'隐藏入口与E1阈值')+'</p>'+
   '<p><b>本项上传:</b> '+(r.reuse?'已确认同房底图(图1)':'画法主参考(图1)')+'＋本房空间定位(图2)。'+upload+' 摆放核对图不用上传。</p>'+
   '<div class="actions"><button data-act="style">'+(r.reuse?'画风需校正时下载参考':'下载图1 · 画法主参考')+'</button></div>'+
   '<div class="images"><figure><img loading="lazy" src="'+r.base+'" alt="空间定位图"><figcaption>图2 · 空间定位 <button data-act="base">下载PNG</button></figcaption></figure>'+
   '<figure><img loading="lazy" src="'+r.placed+'" alt="摆放核对"><figcaption>摆放核对 · 仅供核位置 <button data-act="placed">下载PNG</button></figcaption></figure></div>'+
   '<div class="actions"><button class="primary" data-act="prompt">复制本场景提示词</button><button data-act="filename">复制文件名</button></div><details><summary>家具与物件 ('+r.props.length+')</summary><div class="props"></div></details>';
  a.querySelector('[data-act="style"]').onclick=()=>save(samples[0].png,samples[0].filename);
  a.querySelector('[data-act="base"]').onclick=()=>save(r.base,r.base_filename);
  a.querySelector('[data-act="placed"]').onclick=()=>save(r.placed,r.placement_filename);
  a.querySelector('[data-act="prompt"]').onclick=()=>copy(r.prompt);
  a.querySelector('[data-act="filename"]').onclick=()=>copy(r.art_filename);
  const detail=a.querySelector('details');detail.addEventListener('toggle',()=>{
   if(!detail.open||detail.dataset.loaded)return;detail.dataset.loaded='1';const host=a.querySelector('.props');
   r.props.forEach(p=>{
    const n=document.createElement('div');n.className='prop';
    n.innerHTML='<img loading="lazy" src="'+p.png+'" alt="物件尺度定位图"><div><b>'+p.number+'. '+esc(p.name)+'</b><p class="meta">宽 × 深 × 高: '+p.size.join(' × ')+' m<br>模板 '+p.pixel_size.join(' × ')+' px (2倍源图), 地面锚点 ['+p.ground_anchor_px.join(', ')+'] px<br>左上地面位置: ['+p.position.join(', ')+'] m；操作参考站位: ['+(p.approach?p.approach.join(', ')+'] m':'无指定操作点]')+'<br>操作面: '+esc(p.operation_face_text)+'</p>'+
     '<p><b>本物构造:</b> '+(p.construction||'按实际物件保留薄厚、弧度、支点和透空。')+'</p><p><b>本项上传:</b> 此物件结构图＋已确认同类母图（没有母图时用上方画法参考）。尺寸只限容纳范围、支点和操作处。'+(p.wall_mount?'这是挂墙物件。':'保留脚底接地点。')+' 不用上传整张房间图。</p>'+
     '<div class="actions"><button data-act="download">下载尺度PNG</button><button class="primary" data-act="copy">复制物件提示词</button><button data-act="name">复制模板文件名</button></div></div>';
    n.querySelector('[data-act="download"]').onclick=()=>save(p.png,p.filename);n.querySelector('[data-act="copy"]').onclick=()=>copy(p.prompt);n.querySelector('[data-act="name"]').onclick=()=>copy(p.filename);host.append(n);
   });
  });root.append(a);
 });document.getElementById('counter').textContent=count+' 个场景';
}
document.getElementById('chapter').onchange=render;document.getElementById('query').oninput=render;render();
</script></html>'''

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=DEST);p.add_argument('--share',type=Path);a=p.parse_args();build(a.output,a.share)
