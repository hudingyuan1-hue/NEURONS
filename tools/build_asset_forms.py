"""Build the versioned, offline 2D production forms. Never modifies old repos.

Requirements are committed JSON; browser edits are exported to progress.json.
Old IDs remain as active records, aliases, or explicitly retired tombstones.
"""
from pathlib import Path
from zipfile import ZipFile
import collections
import hashlib
import html
import json
import re
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'deliverables/NEURONS_2D_资产需求_20261015'
DATA = OUT / 'data'
DATA.mkdir(parents=True, exist_ok=True)
NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def dump(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def doc_lines(path):
    with ZipFile(path) as z:
        body = ET.fromstring(z.read('word/document.xml')).find('w:body', NS)
    rows=[]; p=t=0
    for b in body:
        if b.tag.endswith('}p'):
            p+=1
            rows.append((f'P{p}', ''.join(n.text or '' for n in b.findall('.//w:t',NS))))
        elif b.tag.endswith('}tbl'):
            t+=1
            for i,r in enumerate(b.findall('w:tr',NS),1):
                rows.append((f'T{t}R{i}', ' | '.join(''.join(n.text or '' for n in c.findall('.//w:t',NS)) for c in r.findall('w:tc',NS))))
    return rows

def read_form(name, script_id):
    candidates=list((ROOT/'DOCX/前人AI推荐提示词 仅供参考').rglob(name))
    assert len(candidates)==1, (name,candidates)
    src=candidates[0]
    archive=OUT/'history'/name
    archive.parent.mkdir(exist_ok=True)
    if not archive.exists():shutil.copy2(src,archive)
    text=src.read_text(encoding='utf-8-sig')
    data=json.loads(re.search(r'<script[^>]*id="'+script_id+r'"[^>]*>([\s\S]*?)</script>',text)[1])
    return data, {'path':src.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'count':len(data)}

legacy_art, art_origin=read_form('01_全游戏提示词表单.html','asset-data')
legacy_audio, audio_origin=read_form('01_音频需求表.html','data')
s1path=next(ROOT.glob('DOCX/AI整理后文档/*第一阶段*.docx'))
s3path=next(ROOT.glob('DOCX/AI整理后文档/*第三阶段*.docx'))
s1=doc_lines(s1path);s3=doc_lines(s3path)
all_images=[p for p in (ROOT/'DOCX/早期素材').rglob('*') if p.suffix.lower() in ['.png','.jpg','.webp']]

def batch(scope):
    for text,n in [('第1关','B1'),('第一关','B1'),('第2关','B2'),('第二关','B2'),('第3关','B3'),('第三关','B3'),('第4关','B4'),('第四关','B4'),('第5关','B5'),('第五关','B5'),('第6关','B6'),('第六关','B6')]:
        if text in scope:return n
    return 'B0'

def source_for(name, default='S1空间/物件；S3对应人物事件；旧表只提供ID索引'):
    simple=name.split('／')[0]
    hit=[(k,v) for k,v in s1 if simple and simple in v]
    return 'S1:'+','.join(k for k,_ in hit[:4]) if hit else default

def row_base(id,name,category,scope):
    return dict(id=id,name=name,category=category,scope=scope,rooms=scope,events=name,
        batch=batch(scope),quantity='1',spec='',filename=id+'_v001.png',prompt='',
        requirement='',source='',proposal='',pending='',existing_paths=[],
        status='待制作',file='',license='',notes='',alias_of='',delivery='',animation=None)

def clips_for(id,name):
    directions=4
    if any(w in name for w in ['轮椅','被转运','双头']):directions=2
    frames=3;duration='由动作配置同步至规则游戏时钟';loop=False
    if 'WALK' in id:frames=4;duration='0.64秒（表现建议）';loop=True
    if 'IDLE' in id:frames=2;duration='1.2秒（表现建议）';loop=True
    rules={'SKIN':'0.5秒；战斗侧挪0.25秒','GUT':'1.2秒','PORES':'3秒','TEMP':'3秒','TINNITUS':'探索1秒/战斗0.3秒','DRYMOUTH':'交接延后2秒/战斗抑制发声6秒','KNEE':'0.15秒准备+0.15秒接触+0.35秒收势','WITHDRAW':'0.3秒','STARTLE':'探索实际移动完成；战斗0.35秒','FEAR':'探索延后6秒/战斗撤离倾向3秒','JOY':'一次精神效果，表现不延长世界停顿','CONTROL':'接管6秒；结束冷却20秒'}
    for skill,value in rules.items():
        if id=='CHR_MAIN_SKILL_'+skill:duration=value
    contacts='接触归一化0.55（建议）；逻辑事件独立；不可只按动画尾帧发奖'
    if 'KNEE' in id:contacts='0.15–0.30游戏秒有效；同次同目标只结算一次'
    if 'EAT' in id:contacts='实际吞服完成1.5游戏秒；此前中断保留物品'
    if 'SEARCH' in id:contacts='首次翻查占次数；完成节点才发奖；按点位复杂度同步4秒基值'
    return dict(directions=directions,frames_per_direction=frames,duration=duration,loop=loop,
        canvas='64×80世界像素；大型/四足96×96候选',foot_anchor=[32,72],
        hand_anchor='每帧JSON左右手定位；默认相对脚底(±12,-28)，接触姿势另量',
        contact=contacts,files=id+'_d{direction}_f{frame:02d}_v001.png',
        phases=['准备','接触或有效阶段','结束或释放'],
        note='基础帧数为制作建议；整套共用画布/脚锚。单一通用动作可在同一身份复用；不混用人物身份。')

art=[]
for old in legacy_art:
    id=old['id'];name=old['name'];scope=old.get('level','全程');cat=old['category']
    cat={'3D模型':'二维物件或角色','场景参考':'场景分层','动作参考':'动作','肖像与序列帧':'肖像','开场镜头':'开场与结局','UI与贴图':'UI与效果'}[cat]
    r=row_base(id,name,cat,scope)
    r['source']=source_for(name)
    r['requirement']=name+'；保留现行事件用途，图像不改变真实结果。'
    r['spec']='PNG；完整不透明源图另存，运行精灵RGBA；nearest；固定斜俯视；不得烘入文字/数值'
    r['proposal']='风格沿用ART_SPEC；数量/尺寸/帧数为首版实现建议，不是新增机制。'
    r['delivery']='原图art/source/{id}/；运行稿neurons/assets/{id}/；不裁掉细连接；附像素尺寸/锚点JSON。'.format(id=id)
    r['existing_paths']=[p.relative_to(ROOT).as_posix() for p in all_images if p.stem==id or p.stem.startswith(id+'_ref')][:4]
    if r['existing_paths']:r['status']='已有候选待校准'
    if id.startswith('CHR_PLAYER_01_05_'):
        r.update(status='停用',batch='不制作',quantity='0',prompt='',requirement='玩家旧五形象和选择流程已废弃；ID保留仅用于迁移',alias_of='CHR_PLAYER_MASTER_2D',spec='无制作需求',filename='',delivery='旧文件保留，不进入运行引用')
        art.append(r);continue
    if cat=='场景分层' or id.startswith('ENV_ROOM_'):
        r['category']='场景分层';r['quantity']='3层：墙地底图+固定背景+前景遮挡；活动物另表'
        r['spec']='世界基准640×360；大房可扩画布保持像素密度；源图至少1280×720；逐层同尺寸/原点'
        r['prompt']=f'{name.split("／")[0]}的固定斜俯视空场景，绘画大色块与克制像素边缘，保留现行门窗和通路；无人、无活动家具、无文字。'
        r['pending']='精确画布/入口像素锚在对应关卡灰盒布局后冻结；不要根据旧参考自行添加门。'
        # Reused rooms have one source plus state layers, rather than duplicate artwork.
        if id.endswith('_L5') and id[:-3] in [x['id'] for x in legacy_art]:
            r.update(alias_of=id[:-3],quantity='0套底图；1组异化覆盖层',status='复用+状态层待制作')
        if id=='ENV_ROOM_TUTORIAL':r.update(alias_of='ENV_ROOM_L1_ROOM',quantity='0',status='复用卧室')
    elif cat=='动作':
        r['animation']=clips_for(id,name)
        if '_ACTION_REF' in id:
            desc=old.get('description','')
            pieces=re.findall(r'(?:初次形态|后期形态)：([^。]+)',desc)
            r['proposal']+=' 动作清单（旧表候选，须与S3事件核对）：'+'；'.join(pieces)
            r['pending']='逐动作映射原事件；未确认攻击身份不得统一增加攻击/倒地。'
            r['animation']['clips']=list(dict.fromkeys(w.strip() for p in pieces for w in re.split('[、；]',p) if w.strip()))
            r['quantity']=str(max(1,len(r['animation']['clips'])))+'个动作候选；每项3关键帧×'+str(r['animation']['directions'])+'方向'
        else:r['quantity']=f"{r['animation']['directions']}方向×{r['animation']['frames_per_direction']}帧"
        r['filename']=id+'_sheet_v001.png + '+id+'_anchors_v001.json'
        r['prompt']=f'{name.replace("动作参考","动作序列")}，同一角色母图与统一比例，准备、接触、收势清楚，固定斜俯视，画布和脚底不漂移；不画道具残影和文字。'
    elif cat=='肖像':
        r.update(spec='256×320 RGBA运行稿；512×640不透明源图；肩部锚(128,300)',quantity='1表情；同人物重复表情共用',prompt=name+'的半身表情，沿用对应统一角色母图、克制色块与清晰五官，无文字、无场景。')
        if '_NPCS_' in id:r['quantity']='1套对应原文表情；具体表情数按S3该身份台词核定'
    elif cat=='开场与结局':
        r.update(spec='1280×720分层原图；安全区底24%/左右14%；人物和运动层独立',quantity='1镜头所需独立背景层',prompt=name+'的独立背景或所需前景层，固定构图，绘画大色块，无字幕、UI和重复角色。')
        if id in ['SLIDE_A07','SLIDE_B03','SLIDE_B08','SLIDE_A09']:
            r.update(status='代码绘制',quantity='0张',prompt='',spec='Godot动态文字/黑屏/标题时序',filename='',delivery='无需画师交图')
        if id=='SLIDE_E2':r['pending']='旧E2标签按R1重新分为E2/E3；本ID保留第六关共用收束层，不按旧双结局删E3。'
        r['requirement']=name.replace('所选怪物','统一玩家小怪物')+'；字幕和玩家编号由代码绘制，无形象选择。'
    elif cat=='UI与效果' or id.startswith('SYS_'):
        r['category']='UI与效果'
        r['spec']='图标64×64 RGBA（源图256²）；面板512×512九宫格或1280×720；动态文字/连线/数值由代码绘制'
        r['prompt']=name+'的独立无字二维组件，宽阔安静色面、轮廓清晰、少量冷暖对比，无场景、数字或烘焙状态。'
        if id.startswith('UI_RECORD_') or id in ['UI_LABEL_MEDICINE','UI_LABEL_SEAT','UI_LABEL_ANKLE']:
            r.update(alias_of='TEX_PAPER',quantity='0新增底图；按需要复用纸张',status='代码排版+共用纸底',prompt='')
        if id in ['SYS_CRT_CODE','SYS_STAR_GRAPH','UI_STATUS','UI_PROFILE','UI_SAVE','UI_LOADING','UI_ENDING','UI_BOOKMARKS_UNLOCK','UI_SKILL_RANK_OVERLAY']:
            r['status']='代码绘制';r['quantity']='0张必需；可选装饰1层';r['pending']='装饰可后置；功能不可依赖美术到齐'
    elif id.startswith('CHR_'):
        r.update(category='角色精灵',quantity='4方向×1站立关键姿势；动作另表',spec='64×80世界像素RGBA；脚底(32,72)；目标人物高60px；同画布派生',prompt=name.split('／')[0]+'的固定斜俯视角色精灵，保持现行身份与轮廓、手脚连接完整，姿态自然，低饱和绘画色块，无文字或背景。')
    else:
        r.update(category='物件分层',quantity='1套：固定体+活动部件+遮挡前沿',spec='固定斜俯视；按80px/米横轴、28/46px/米纵轴；每件独立同原点RGBA层，附占地/手锚JSON',prompt=name+'的独立二维物件层，结构清楚、绘画大色块、开口内部完整；抽屉/门/盖/内容物分开，无人物、文字、地面或固定阴影。')
    art.append(r)

def art_extra(id,name,cat,scope,requirement,**kw):
    r=row_base(id,name,cat,scope);r.update(requirement=requirement,source='本次用户要求；现行S1–S4/R1',spec='按ART_SPEC，同类规格复用',prompt=name+'，同套绘画色块风格，无文字，独立图层',delivery='不透明源图与RGBA运行稿分开；尺寸锚点JSON随交付');r.update(kw);art.append(r);return r

art_extra('CHR_PLAYER_MASTER_2D','统一玩家小怪物母图','角色精灵','开场/教程/菜单/对白','小、奇怪、可爱、清晰轮廓；用户已否决v001，需整体调整',spec='UI运行高96px；母图不透明原图+独立透明稿；非主角',status='用户制作新稿',pending='造型由用户本轮制作；不沿用被否决v001')
for outfit,title in [('L1_NEW','崭新浅蓝睡衣'),('L1_WORN','旧浅蓝睡衣'),('L1_DAMAGED','破损睡衣'),('L2_NEW','崭新病号服'),('L2_WORN','旧病号服'),('L3_NEW','精神病院病号服'),('L3_WORN','旧精神病院病号服'),('L4_COAT','医师白衣'),('L5_SUIT','黑色西装'),('L6_ROBE','红色大袍')]:
    art_extra('CHR_MAIN_OUTFIT_'+outfit,title,'角色外观层','第'+outfit[1]+'关','用户补充与Doctor P1–27：帅气、瘦弱、男性；衣装随场景与周目变化',spec='复用CHR_MAIN画布/脚锚/方向/动作；服装层或整套对应帧',quantity='1外观套',pending='血污按现行实际状态与周目表现控制；开场不预染；年龄/发型未定不得当作高中生已确认')
for suffix,label in [('E1','隐藏Street逃脱'),('E2','第六关原出口结局'),('E3','有效掌控失我分支'),('EPILOGUE','现实宿主尾声')]:
    art_extra('ENDING_'+suffix,label,'开场与结局','结局',label+'；R1覆盖原E2，原出口与死亡优先关系保留',spec='1280×720分层；文案由Godot；可复用已建场景而不新画',quantity='1表现层或0张复用',pending='只按现行结局事实展示，不能借画面补写结局因果')
art_extra('FX_BLOOD_STATE','事件血迹与衣物血污','UI与效果','全关','实际事件/规定周目变化驱动，不能凭滤镜制造伤害',spec='128×128局部遮罩；地面/衣物分别；0..1参数；提供关闭闪烁',quantity='3种局部形状')
art_extra('UI_BODY_TURN_2D','冰柜人体二维旋转','UI与效果','全程','保留旋转体验和对应身体部位技能关系',spec='同角色8视图256×320；肩/身体部位锚JSON；拖动切视图',quantity='8视图（制作建议）',pending='未提供前用二维轮廓投影，旋转关系保持可操作')
for suffix,name in [('DISTANT','疏离'),('FRAGMENTED','残缺')]:
    art_extra('CHR_MAIN_CONTROL_'+suffix,'有效掌控阶段/'+name,'角色外观层','全程', 'R1 T3：疏离30至不足60秒，残缺60至不足120秒；只改变已发生的表现，不制造伤害/血迹',spec='复用同角色动作/方向/脚锚；眼神与闲置姿态少帧覆盖',quantity='1套表情/闲置覆盖层',pending='内部累计值不展示给玩家')
art_extra('FONT_CJK_COVERAGE','中文与乱码字形补全','文字资源','全程','原对白含扩展字/颜文字，当前Noto缺13字符，不能修改原句规避',spec='可共享嵌入许可字体；覆盖coverage-source-corpus.json列出的13缺字',quantity='1个合法补充字体或字体子集',prompt='',status='待核验授权与字形',existing_paths=['neurons/assets/fonts/coverage-source-corpus.json'],pending='由程序接入；画师无需逐字绘图')
byid={r['id']:r for r in art}
byid['CHR_MAIN'].update(requirement='帅气、瘦弱、男性；第一关开场崭新浅蓝睡衣套装',source='用户2026-10-15补充；Doctor P1–27；S2/S3长期状态',pending='年龄/具体发型未定；旧提示词“中国男高中生”不当作已确认设定')
byid['CHR_MAIN']['existing_paths'].extend(['neurons/assets/placeholders/host_a.png','neurons/assets/placeholders/host_b.png'])
byid['CHR_MAIN']['status']='程序占位已接入；正式由用户制作'
byid['ENV_BEDSIDE'].update(spec='柜体/抽屉面/前沿/书/闹钟96×80共用；抽屉内侧贴片48×24按四角映射；地面角锚(8,40)；手柄(60.74,25.77)；抽屉+x最多7px',existing_paths=['neurons/assets/environment/bedside_trial_v001/cabinet_frame.png','neurons/assets/environment/bedside_trial_v001/drawer_face.png'],status='已有局部候选；功能已测；美术未定稿')
byid['ENV_ROOM_L1_ROOM']['existing_paths']=['neurons/assets/environment/bedroom_shell_v001.png','art/source/bedroom_visual_candidate_v005.png']
byid['ENV_ROOM_L1_ROOM']['status']='墙地已接入；v005仅候选未整体铺图'
byid['ENV_ROOM_L1_DESK_DETAIL'].update(alias_of='ENV_DESK',quantity='0新增，原桌附属小物复用',status='复用明细')
for r in art:
    if r['id'].startswith('UI_ITEM_'):
        related='ENV_SMALL_PROPS_'+r['id'].removeprefix('UI_ITEM_')
        if related in byid:
            r.update(alias_of=related,quantity='0新增源图；复用同物件形象派生1图标',status='复用物件图派生',prompt='')
for id in ['UI_RECORD_34','UI_EVIDENCE_REHAB_PHOTO','UI_EVIDENCE_FAMILY_PHOTO']:
    byid[id].update(alias_of='',quantity='1张照片内容；相纸底共用TEX_PAPER',status='内容待核验',pending='原文未指定的参与者/人数/时代不自行补写；按对应真实事件与已核定身份制作')
# First batch: a small set with frozen, directly consumable specifications.
first_art=['CHR_MAIN','CHR_MAIN_ACT_IDLE','CHR_MAIN_ACT_WALK','CHR_MAIN_ACT_SEARCH','CHR_MAIN_SKILL_SKIN','ENV_BEDSIDE','ENV_SMALL_PROPS_KEY','CHR_PLAYER_MASTER_2D','UI_SKILL_SKIN']
for id in first_art:byid[id]['batch']='B0'
for id in first_art:
    r=byid[id]
    if r['animation']:
        r['spec']='单帧64×80；sheet每方向一行、每行按时间排帧；4方向顺序右/上/左/下；RGBA、脚锚(32,72)，逐帧左右手锚JSON'

audio=[]
for old in legacy_audio:
    r=row_base(old['id'],old['name'],old['kind'],old['scope'])
    r.update(batch=old.get('priority','P1')+' / '+batch(old['scope']),quantity=old.get('variants','1'),spec='WAV PCM 48kHz/24bit母版；音效/对白mono，音乐/环境stereo；自然尾音，无硬限幅/过载',filename=old['id']+'_v001.wav',prompt=old.get('brief',''),requirement=old.get('trigger',''),source=old.get('source','旧音频表'),duration=old.get('duration',''),loop=old.get('loop','否'),speaker=old.get('speaker',''),original_text=old.get('original_text',''),authorization=old.get('license',''),status=old.get('status','待制作'),file=old.get('file',''),license=old.get('license',''),notes=old.get('notes',''),delivery='原始录音另存；交付无损母版；附license/作者/同意用途/来源URL/日期；标注循环采样点',proposal='音色/时长与变体数为制作建议；不能带入额外剧情；循环点写进JSON',pending='')
    r['prompt']=re.sub(r'(?:Unity|Godot|保存|导出|上传|文件名|工程)[^。；\n]*[。；\n]?','',r['prompt'])
    if r['category'] in ['对白','待核台本']:
        r['prompt']='按原文录制自然对白，保留情绪和停顿；不加台词、配乐或环境声。'
        r['pending']='旧表台本按现行事件逐句核验；随机“/”分项与“&”同框分轨，不顺序全播；动态名字/乱码另核'
        r['status']='台本候选待核' if not r['file'] else r['status']
    audio.append(r)

def au(id,name,cat,scope,brief,duration='1–3秒',loop='否',speaker='',text='',source='S1–S4对应事件；时长/音色为实现建议'):
    r=row_base(id,name,cat,scope)
    r.update(batch=batch(scope),quantity='1',spec='WAV PCM 48kHz/24bit；对白/定位声mono，音乐/底噪stereo；无削波，保留尾音',filename=id+'_v001.wav',prompt=brief,duration=duration,loop=loop,speaker=speaker,original_text=text,authorization='',source=source,requirement=scope+'对应实际事件触发',proposal='时长/音色为制作建议',delivery='母版+授权记录；循环素材附采样点，不覆盖原始录音')
    audio.append(r)

for id,name,scope in [('HOSPITAL','医院冷淡环境','第二关/第三关一层'),('ASYLUM','精神病院病区','第三关二层'),('CORTEX','脑皮层与白质通路','第四关/第五关一二层'),('DEEP','深部脑结构','第五关三层'),('STREET_FINAL','第六关Street','第六关'),('ENDING_E2','原出口收束','结局E2'),('ENDING_E3','失我收束','结局E3'),('EPILOGUE','宿主尾声','尾声')]:
    au('MUS_'+id,name,'音乐',scope,'低信息密度、可让位对白的'+name+'音乐，分离节奏与持续层，无歌词、无强制跳吓','90–150秒','是')
for id,name,scope in [('HOSPITAL','医院远处通风与走廊','第二关/第三关一层'),('WARD','病区远处生活声','第三关二层'),('CORTEX','皮层低脉冲','第四关'),('DEEP','深部机械与组织环境','第五关'),('STREET_FINAL','Street分段风与水','第六关')]:
    au('AMB_'+id,name,'环境',scope,name+'，连续稳定，局部事件声分开，无近处台词与随机巨响','45–90秒','是')
for id,name,scope in [('WHEELCHAIR','轮椅推进与刹车','第二关/第三关/第六关'),('BANDAGE','纱布包扎','第二关/第五关/第六关'),('STAMP','盖章与文书交接','第二关/第三关'),('MEDICINE','举杯吞服','第二关/第三关/第六关'),('NEEDLE','针具接触与收回','第二关/第三关'),('STRAP','束带收紧与释放','第三关/第六关'),('TRANSPORT','推床与轮子','第三关/第六关'),('ISOLATION','隔离门开关','第三关'),('RECORDER','录音启停与断线','第三关/第四关'),('CLAMP','夹具闭合与抓空','第三关/第六关'),('PAPER_TEAR','纸张撕裂','第三关/第六关'),('CORE','核心交互脉冲','第四关/第五关'),('TEMP_ZONE','温控冷热区域','第五关'),('SLAM','直线冲撞与落步','第四关/第五关/第六关'),('KICK','膝跳有效接触','第五关/第六关/隐藏Street'),('ALERT','医护警示与招援','第五关/第六关'),('WATER_STEP','浅水脚步','第六关'),('BODY_TURN','冰柜人体切视图','菜单'),('STAR_UNLOCK','星环解锁升级','菜单'),('CHECKPOINT','边界安全存档','全程')]:
    au('SFX_'+id,name,'音效',scope,name+'独立音效，准备/接触/结束可分段，短而清楚，无额外人声和音乐')

# Extract exact later-level speech, with paragraph IDs rather than invented copy.
# Speaker/emotion labels are retained; unparsed prose is not made into VO.
legacy_text={re.sub(r'\s+','',r.get('original_text','')) for r in audio if r.get('original_text')}
section='第三阶段';scene=''
for anchor,text in s3:
    if re.match(r'[2-6] [第二三四五六]+关',text):section=text
    if re.match(r'\d+\.\d+ ',text):scene=text
    if not anchor.startswith('P') or int(anchor[1:])<338:continue
    quotes=list(re.finditer(r'([^：。→]+)：[“"]([^”"]+)[”"]',text))
    for index,m in enumerate(quotes,1):
        speaker=m[1].strip();line=m[2]
        if len(speaker)>35 or not any(w in speaker for w in ['角色','玩家','护士','工','病友','医','人','患者','保安','药师','人格','主任','告密','复述','头']):continue
        if re.sub(r'\s+','',line) in legacy_text:continue
        legacy_text.add(re.sub(r'\s+','',line))
        au(f'VO_S3_{anchor}_{index}',section+' / '+scene+' / '+speaker,'对白',section, '按台本原文录制，保留所标情绪；无背景配乐、无擅加台词', '按原句自然时长（约1–12秒）','否',speaker,line,'S3:'+anchor+'；分支条件回查前后判定条款')
        audio[-1]['events']=scene or section
        audio[-1]['pending']='实际配音前核对本句分支/随机替换项和称呼；这里只提取明确引号对白，不含未解析台本'

for id in ['E1','E2','E3','EPILOGUE']:
    au('VO_ENDING_'+id,'结局/尾声台本核验包','台本待核','结局/'+id,'保留已确认原文与原说话人，不录制临时旁白','按台本','否',text='',source='R1结局/尾声；既有阅读摘要不替代逐句台本')
    audio[-1].update(status='原文已核验：复用/无新增对白',quantity='0新增录音',pending='')
    audio[-1]['source']='R1 P24–32（本轮补回原件，哈希与历史记录一致）'
    if id in ['E1','EPILOGUE']:
        audio[-1].update(prompt='',speaker='无新增说话人',requirement='无新增对白；按原镜头进行环境/动作音过渡，不擅加旁白',duration='0秒新增对白')
    else:
        related=[r['id'] for r in audio if r.get('original_text','') in ['出来了。','……','你还在？','……在。']]
        audio[-1].update(prompt='',speaker='角色与玩家分轨',requirement='R1 P25–26：原出口两组对白按识破状态互斥调用；E2/E3复用同一录音，台词ID：'+','.join(related),duration='按复用原句')
for id,speaker,line in [('VO_R1_P32_DISTANT','角色[疑虑]','刚才……是我想动的吗？'),('VO_R1_P32_FRAGMENTED','角色[低声]','我记得想说什么……却说不出来。')]:
    au(id,'失我阶段首次安全间隙','对白','全程','按原文保留疑虑与迟疑，不加邪笑或旁白','按原句','否',speaker,line,'R1 P32')
    audio[-1]['requirement']='同存档对应阶段一次；追击时延后，已跳过阶段不补演'

for r in audio:
    if r['category']!='对白' and not r.get('speaker'):r['speaker']='不适用（非语言声音）'
    if not r.get('duration'):r['duration']='按事件长度制作；待交付测量'
    if not r.get('loop'):r['loop']='否'
    r['authorization']=r.get('authorization') or '待填写：作者/来源/许可/商业使用与共享范围；真人声音须录音者同意'
    r['existing_paths']=[]
    if r['id'] in ['SFX_UI_CONFIRM','SFX_UI_DENIED','SFX_DRAWER','SFX_ITEM_HANDOFF','SFX_SKIN','SFX_HIT','SFX_UI_FOCUS']:
        r['existing_paths']=['neurons/scripts/ui/feedback_audio.gd']
        r['status']='测试合成音待替换'
first_audio=['SFX_UI_CONFIRM','SFX_UI_DENIED','SFX_DRAWER','SFX_FOOTSTEP','SFX_KEY','SFX_ITEM_HANDOFF','SFX_SKIN','SFX_CRT_ON','SFX_CRT_OFF']
for r in audio:
    if r['id'] in first_audio:r['batch']='B0'

# Descriptions are production briefs, not longer generation prompts.
# Keep canonical source excerpts and optional production choices distinct.
room_ranges={
 'ENV_ROOM_L1_ROOM':(15,23),'ENV_ROOM_HIDDEN_STREET':(24,26),
 'ENV_ROOM_L2_WARD':(34,42),'ENV_ROOM_L2_LOBBY':(43,52),'ENV_ROOM_L2_CLINIC':(53,62),'ENV_ROOM_L2_PHARMACY':(63,73),'ENV_ROOM_L2_OFFICE':(74,84),
 'ENV_ROOM_L3_WARD':(102,106),'ENV_ROOM_L3_RECEPTION':(107,111),'ENV_ROOM_L3_CLINIC':(112,116),'ENV_ROOM_L3_TREATMENT':(117,122),'ENV_ROOM_L3_OFFICE':(123,128),
 'ENV_ROOM_L3_STAIRS':(134,146),'ENV_ROOM_L3_CORRIDOR':(147,154),'ENV_ROOM_L3_ACTIVITY':(155,164),'ENV_ROOM_L3_GROUP':(165,174),'ENV_ROOM_L3_QUIET':(175,184),'ENV_ROOM_L3_BATH':(185,196),'ENV_ROOM_L3_DOUBLE':(197,206),'ENV_ROOM_L3_WORK':(207,216),
 'ENV_ROOM_L4_ATRIUM':(225,233),'ENV_ROOM_L4_MEMORY':(234,243),'ENV_ROOM_L4_VISUAL':(244,252),'ENV_ROOM_L4_DECISION':(253,262),'ENV_ROOM_L4_BODY':(263,272),
 'ENV_ROOM_L4_BRIDGE':(283,287),'ENV_ROOM_L4_RHYTHM':(288,293),'ENV_ROOM_L4_INDEX':(294,299),'ENV_ROOM_L4_SWITCH':(300,305),'ENV_ROOM_L4_VERIFY':(306,312),'ENV_ROOM_L4_IDENTITY':(313,319),
 'ENV_ROOM_L5_HIPPOCAMPUS':(432,437),'ENV_ROOM_L5_THALAMUS':(438,443),'ENV_ROOM_L5_CEREBELLUM':(444,449),'ENV_ROOM_L5_HYPOTHALAMUS':(450,455),'ENV_ROOM_L5_BASAL':(456,461),'ENV_ROOM_L5_AMYGDALA':(462,467),'ENV_ROOM_L5_BRAINSTEM':(468,473)}
for base,span in [('ATRIUM',(333,338)),('MEMORY',(339,344)),('VISUAL',(345,350)),('DECISION',(351,356)),('BODY',(357,362)),('BRIDGE',(377,382)),('RHYTHM',(383,388)),('INDEX',(389,394)),('SWITCH',(395,400)),('IDENTITY',(401,406)),('VERIFY',(407,412))]:room_ranges['ENV_ROOM_L4_'+base+'_L5']=span
room_evidence={}
for id,(start,end) in room_ranges.items():
    block=[];current=0
    for anchor,text in s1:
        if anchor.startswith('P'):current=int(anchor[1:])
        if start<=current<=end and text:block.append((anchor,text))
    room_evidence[id]=block
old_byid={r['id']:r for r in legacy_art}

def clean_reference_description(text):
    text=text.split('参考使用范围：')[0].split('原文语境')[0]
    parts=re.split(r'(?<=[。；\n])',text)
    parts=[p for p in parts if not re.search(r'3D|Tripo|Unity|\.glb|面数|四边面|拓扑|骨骼|蒙皮|UV|模型截图|认可模型|逐帧.*生成|每帧.*生成|绿底|蓝底|棋盘|所选|五选',p,re.I)]
    return ''.join(parts).strip()[:900]

for r in art:
    id=r['id'];category=r['category']
    r['description']='用于'+r['scope']+'的'+r['name']+'。'+r['requirement']
    r['reference_note']=clean_reference_description(old_byid.get(id,{}).get('description',''))
    r['source_details']=''
    r['reuse_scope']=r['scope']+('；复用'+r['alias_of']+'，不重复制作底图/录入资产' if r['alias_of'] else '；同一稳定ID跨场景实例复用，状态单独配置')
    r['acceptance']='正常1倍下轮廓可读；0.8和1.3倍检查边缘；透明运行稿在浅/深底与实机检查；脚底/物件原点一致；图片不带文字和结算结果。'
    if r['status']=='停用':
        r.update(description='仅保留旧ID供历史进度迁移。五选一已废弃，既不需要补图，也不进入正式游戏选择。',reference_note='',layers='无制作层',acceptance='运行引用为空，旧工程文件保留。')
        continue
    if category=='场景分层':
        r['layers']='①完整墙地；②不动的远景或固定背景；③前景切墙/窗台遮挡。人物、活动家具、门扇、抽屉、道具、动态阴影另交，移走后底图仍完整。'
        r['acceptance']+=' 门口、床边、转身位和通道与灰盒占地核对，不能从画面暗处直接判断不可走。'
        if id in room_evidence:
            r['source_details']='\n'.join('S1:'+a+' '+t for a,t in room_evidence[id])
            r['description']+=' 本房必需物件、空间用途和连接见下方原文配置；美术只能优化局部布置，不能增加出口或删除必要物件。'
    elif category=='物件分层':
        r['layers']='固定主体/完整内部、活动门盖或抽屉、前沿遮挡、可拿内容物、阴影分别；无活动部件的物件只交主体。既有纹理可复用，不将固定阴影画入可动件。'
        simple=re.sub(r'[（(].*','',r['name'].split('／')[0])
        tokens={'床':['单人床','病床','床位'],'书桌':['书桌'],'椅子':['靠背椅','学习椅','椅子'],'圆凳':['小圆凳','蓝色塑料圆凳'],'一碗粥':['粥']}.get(simple,[simple])
        uses=[];details=[]
        for room,block in room_evidence.items():
            hit=[(a,t) for a,t in block if any(token in t for token in tokens)]
            if hit:
                uses.append(room)
                details.extend('S1:'+a+' '+t for a,t in hit[:2])
        if uses:
            r['rooms']=' / '.join(uses)
            r['source_details']='\n'.join(list(dict.fromkeys(details))[:8])
    elif category=='动作':
        r['layers']='主体序列；手持物保持独立。准备、接触、结束/抓空/释放分别可辨；高/中/低搜寻可复用同一身份的基础姿态。'
        r['description']+=' 此项交付可播放序列而非仅姿势参考。动画展示动作，真实命中/归属/恢复由玩法节点结算；打断时能从当前姿态合理收势。'
        r['acceptance']+=' 连播不换脸、不独立缩放；持物点与双人接触点不漂移；非循环动作不能靠重播重复交付。'
    elif category in ['角色精灵','角色外观层','肖像']:
        r['layers']='身体/衣装或完整统一精灵；可动表情按需要另层。持物不烘在身体中。以同一母图派生，外观状态不另造身份。'
        r['description']+=' 游戏内身份、衣装和长期状态分别校对；表情可以简化，但原事件要求的疼痛、迟疑、注视与失我区别应可辨。'
    elif category=='开场与结局':
        r['layers']='背景、需要运动的主体、前景遮挡分别；字幕、名字、编号、结局标识全部留给界面。静态镜头允许复用场景，不强制另画整张。'
        r['description']+=' 对应镜头先后、出镜身份和实际结局条件不因画面改写；不得把宿主、角色与玩家当成同一主体。'
    elif category=='UI与效果':
        r['layers']='无字面板/纸底或图标/局部遮罩；按钮、数值、连接线、锁定与悬停状态由Godot绘制。特效只读取参数，不能产生伤害或收益。'
        r['description']+=' 交独立组件而不是整张带字界面截图；九宫格、可拉伸边缘或遮罩用途在交付备注注明。'
    else:r['layers']='按规格交付独立资源；不需要画师处理的代码/文字资源已另标状态。'

specific={
 'CHR_MAIN':('第一关开始时全身站立基准：帅气、瘦弱、男性，崭新浅蓝色睡衣套装。先保证小尺寸下头、躯干、手脚与衣装轮廓清楚；年龄和具体发型不是已经确认的“高中生”设定。此图将作为其他衣装、动作和表情的统一体型基准。','四方向站立图；身体完整、手空置；脚底相同。后续衣装层复用同一体型。'),
 'CHR_MAIN_ACT_IDLE':('自然待机表现呼吸和轻微重心变化；角色处于原地自主等待，不摆夸张表演姿势。两张关键帧通过表现时间交替，不以呼吸节奏推进玩法冷却。','四方向，每方向2帧；共享脚底，不上下漂浮。'),
 'CHR_MAIN_ACT_WALK':('用于主角实际沿可走路径移动。每个方向包含左右脚交替的4个姿势；身体高度和头部体积一致，落脚与地面速度核对。朝向标记只用于占位检验，正式精灵通过姿势/脸部朝向表达方向。','右/上/左/下四行；每行按时间顺序4帧；不把手持物画进帧。'),
 'CHR_MAIN_ACT_SEARCH':('一套通用搜寻动作供不同物件复用，分别覆盖高处、中部和低位。每种高度都要看出伸手准备、翻查接触、结束收手；低位要有俯身/蹲查差别。实际物件状态、复杂度和总时长由规则决定，不用单次挥手代表所有翻查。','3种高度×4方向×3关键帧；每种高度独立sheet；抽屉/书/衣物另层。'),
 'CHR_MAIN_SKILL_SKIN':('皮肤刺激成功后的0.5秒抓挠反应：收起尚未完成的搜寻，手接触身体，最后收势恢复自主。被抵抗时不能播放成功抓挠。战斗侧挪使用另一运动关系，不把此动作当作无敌或通用解抓。','4方向各3关键帧：收手/抓挠接触/收势；不画蚊虫等未经设定的原因。'),
 'ENV_BEDSIDE':('卧室木床头柜，保留上层可动抽屉、下方开放格、落地柜脚、柜顶书与闹钟。抽屉拉开时应露出完整暗槽和内侧，关闭时不残留开屉阴影。当前试接入素材可继续修改，不能把整体候选图直接贴成不可互动家具。','固定柜体/暗槽、抽屉面、前沿遮挡、书、闹钟用96×80共享原点；内侧贴片48×24经四角映射到实际展开区；阴影另层。'),
 'ENV_SMALL_PROPS_KEY':('通关钥匙的场景小物，找到后应能从家具处辨认并通过伸手拿取转为主角持有。实际钥匙仅有一个实例；发现、拾取和开门用不同节点，画面不能让未拾取钥匙提前出现在角色手中。','钥匙独立RGBA；圆环和齿部连接完整。世界显示尺寸先试16–24px，物品图标另复用同形。'),
 'CHR_PLAYER_MASTER_2D':('玩家小怪物整体重新定型。用户已否决v001母图，不以该稿继续派生。保持体型小、奇怪可爱、外轮廓清楚、便于表情和动作；开场、教程、对白和菜单使用同一个形象。它与自主主角分开，不因为可爱改变全游戏气质。','先1张完整不透明母图；确定后另存透明成品。此阶段不要求完整动作/表情套件。'),
 'UI_SKILL_SKIN':('CRT神经节点内的皮肤刺激标识。图标只负责让玩家快速辨别技能；费用、强度、冷却、锁定/抵抗等信息均由界面绘制。应与其他11项技能图标共享尺度与笔触，不能靠细小文字辨认。','单个无字图标；64×64 RGBA运行稿及256×256不透明源图。')}
for id,(description,layers) in specific.items():
    byid[id]['description']=description
    byid[id]['layers']=layers
byid['CHR_MAIN_ACT_SEARCH']['quantity']='3高度×4方向×3关键帧'
byid['CHR_MAIN_ACT_SEARCH']['animation']['height_variants']=['高','中','低']
byid['CHR_MAIN_ACT_SEARCH']['filename']='CHR_MAIN_ACT_SEARCH_{high|mid|low}_sheet_v001.png + anchors.json'

sound_briefs={
 'SFX_UI_CONFIRM':'确认按钮按下后的短反馈，单次触发清楚，尾音不盖对白。悬停不播放同一确认声，避免连续浏览造成密集敲击。',
 'SFX_UI_DENIED':'余额不足、冷却未好或当前不能执行时使用的短无效反馈。与确认声容易区分，但不刺耳、不暗示角色受伤；原因由文字显示。',
 'SFX_DRAWER':'木抽屉开始滑出、达到接触/停住及收回时的摩擦与轻碰，可分段交付。角色尚未真正接触拉手前不提前播开屉声；不带房间底噪。',
 'SFX_FOOTSTEP':'室内行走落脚声音，先提供木地板与硬质地面各少量自然差异，音量与节奏可连续播放。只交单步，不把整段行走节奏或衣料声混进去。',
 'SFX_KEY':'小金属钥匙真正被拿起时的轻碰/短响，体积小、不做宝箱式奖励和弦。发现但尚未拾取不应使用同一拿取声。',
 'SFX_ITEM_HANDOFF':'两人实际递接小物时的轻微接触，保留准备、触碰与结束可区分的节点；物件材质声可另层。说完赠物台词不代表已交付。',
 'SFX_SKIN':'手在皮肤/衣料处短促抓挠的近处细节，用于0.5秒身体反应。保持克制，不加入虫鸣、魔法爆破或角色新台词。',
 'SFX_CRT_ON':'老式电脑开机的短电流启动和稳定收尾，属于界面时间，可在世界暂停时继续。与持续电流底噪分开，避免每次开菜单重叠一整段噪声。',
 'SFX_CRT_OFF':'CRT收屏时短暂压缩/断电的结束声，与开机形成同一设备的声音家族。关闭动画可播，不能使世界在菜单尚未关完时提前推进。'}
for r in audio:
    r['description']=sound_briefs.get(r['id'], r['name']+'用于'+r['scope']+'。'+(r['requirement'] if r['category']=='对白' else r['prompt']))
    if r['category']=='对白':
        r['performance_notes']='保持本句说话人与情绪；按台本原字录制，标点停顿自然。随机“/”逐项交文件；双方同框“&”各自分轨。动态姓名与乱码先核对读法，不擅自改句。'
        r['sound_layers']='纯人声干轨；呼吸/笑/受伤等非语言声可按需要另交，禁止把背景音乐混入对白母版。'
    elif r['category'] in ['音乐','环境']:
        r['performance_notes']='低层持续音与节奏/事件强调可分轨；保留对白空间。循环开始/结束点与自然尾音分别标明，不把每个房间做成一次性剧情高潮。'
        r['sound_layers']='持续底层与可选变化层分开；环境不烘入已发生/未发生的人物事件、警报或近处对白。'
    else:
        r['performance_notes']='同类声响保持统一距离感和响度，变体只改自然细节。准备/接触/结束可分段；不以全屏惊吓音代替事件反馈。'
        r['sound_layers']='单次事件干声；必要材质层和尾音独立，持续机械/房间底噪另交。'
    r['acceptance']='无削波、开头无多余静音、结尾自然；循环无爆点/明显接缝；单声/立体声与规格一致；授权记录齐全；实机分别核对暂停、语音与音效层。'
    r['reuse_scope']=r['scope']+'；同稳定ID在相同材质/事件下复用，不因房间数量复制录音。'
    r['implementation_note']='按照真实事件节点触发，播放或停止声音不能提交伤害、治疗、资源或剧情结果。音频文件/触发绑定/授权分别登记。'

progress_path=DATA/'progress.json'
progress=json.loads(progress_path.read_text(encoding='utf8')) if progress_path.exists() else {'schema_version':2,'kind':'progress','updated':'2026-10-15','art':[],'audio':[]}
dump(progress_path,progress)
for kind,rows,origin in [('art',art,art_origin),('audio',audio,audio_origin)]:
    assert len({r['id'] for r in rows})==len(rows),kind
    payload={'schema_version':2,'kind':kind,'date':'2026-10-15','origin':origin,'rows':rows}
    dump(DATA/(kind+'_requirements.json'),payload)
    template=(ROOT/'tools/asset_form_template.html').read_text(encoding='utf8')
    title='全游戏二维美术需求' if kind=='art' else '全游戏音频需求'
    embedded=json.dumps(payload,ensure_ascii=False).replace('</',r'<\/')
    template=template.replace('__TITLE__',title).replace('__KIND__',kind).replace('__DATA__',embedded).replace('__PROGRESS__',json.dumps(progress,ensure_ascii=False).replace('</',r'<\/'))
    (OUT/('01_全游戏提示词表单.html' if kind=='art' else '01_音频需求表.html')).write_text(template,encoding='utf8')
dump(DATA/'id_migration.json',{'art':{r['id']:{'status':r['status'],'alias_of':r['alias_of']} for r in art},'audio':{r['id']:{'status':r['status'],'alias_of':r['alias_of']} for r in audio}})
dump(DATA/'coverage.json',{'scope':'完整需求初表；非最终逐项制作/台本审核完成','art':len(art),'audio':len(audio),'legacy_art_preserved':len(legacy_art),'legacy_audio_preserved':len(legacy_audio),'art_groups':dict(collections.Counter(r['category'] for r in art)),'audio_groups':dict(collections.Counter(r['category'] for r in audio)),'first_art':first_art,'first_audio':first_audio,'open_items':['旧表NPC动作与表情数为候选，逐人物实现前校准','照片参与者等原稿未指定内容不自动生成','主角年龄/具体发型未确认','原文对白中的随机/同框/动态名字需分轨校对','R1结局/尾声已补读，E1无原对白，不擅加旁白']})
first=['# 首批可制作需求（2026-10-15）','','先交以下B0；后续B1–B6随功能推进，不需要等正式美术。两张HTML均可离线搜索、筛选、修改进度、导入旧JSON、导出同一progress.json。原表留history，稳定ID不重编号。','','## 美术（由用户制作）','']
for id in first_art:
    r=byid[id];first += [f"### {id} / {r['name']}",'',r['description'],'',f"- 数量/规格：{r['quantity']}；{r['spec']}。",f"- 分层/状态：{r['layers']}",f"- 交付文件：`{r['filename']}`。",f"- 验收：{r['acceptance']}"]
    if r['animation']:
        a=r['animation'];first += [f"- 动画：{a['directions']}方向、每方向{a['frames_per_direction']}帧；时长{a['duration']}；循环{a['loop']}；脚底{a['foot_anchor']}；手部{a['hand_anchor']}；接触节点{a['contact']}。"]
    first+=['']
first+=['','## 音频（由同伴制作）','','母版WAV PCM 48kHz/24bit；mono音效，循环底噪/音乐stereo。无额外主混响；交付授权说明，循环点用采样编号。']
for r in audio:
    if r['id'] in first_audio:first += [f"### {r['id']} / {r['name']}",'',r['description'],'',f"- 数量/时长：{r['quantity']}条，{r['duration']}，循环{r['loop']}；`{r['filename']}`。",f"- 分轨/演绎：{r['sound_layers']} {r['performance_notes']}",f"- 验收：{r['acceptance']}",'']
first+=['','## 接入与兼容','','同角色统一画布与脚锚，逐帧手锚可调整；坐标在JSON中声明，图片不能改变碰撞或作用距离。尺寸/动作缺帧不兼容时给出具体报告，不保证任意图片免调。已有候选未获视觉批准不记作正式完成。','','`data/art_requirements.json` / `data/audio_requirements.json` 为完整初表；`data/progress.json`是可同步进度。表单的本地缓存仅临时便利，跨机前导出并覆盖该JSON，再由用户Commit/Push。也可点击“连接进度JSON”直接选择该文件，点击保存写入；浏览器不支持时使用下载导出。','','原文要求、实现建议、待确认分别列字段。旧提示词本身不作为创作定稿证据。台本候选未核验分支或说话人前不要录整批。']
(OUT/'02_首批制作与交付.md').write_text('\n'.join(first)+'\n',encoding='utf8')
print(json.dumps({'art':len(art),'audio':len(audio),'out':str(OUT)},ensure_ascii=False))
