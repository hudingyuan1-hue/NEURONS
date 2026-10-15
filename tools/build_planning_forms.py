"""Planning-only publisher. Reads canon; writes forms/docs, never Godot files.

Run with bundled Python. The pre-planning v2 forms/data are immutable inputs in
history/before_planning_20261015. Runtime and production assets are not touched.
"""
from pathlib import Path
from zipfile import ZipFile
import collections
import hashlib
import json
import re
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'deliverables/NEURONS_2D_资产需求_20261015'
DATA = OUT / 'data'
HISTORY = OUT / 'history/before_planning_20261015'
NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def dump(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

if not HISTORY.exists():
    HISTORY.mkdir(parents=True)
    for name in ['01_全游戏提示词表单.html','01_音频需求表.html','02_首批制作与交付.md']:
        shutil.copy2(OUT/name, HISTORY/name)
    shutil.copytree(DATA, HISTORY/'data')
    for name in ['AGENTS.md','docs/HANDOFF.md','docs/SOURCES.md']:
        target=HISTORY/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/name,target)
    dump(HISTORY/'manifest.json',{str(p.relative_to(HISTORY)).replace('\\','/'):sha(p) for p in HISTORY.rglob('*') if p.is_file()})

def read_doc(tag, pattern, folder='DOCX/AI整理后文档'):
    p=next((ROOT/folder).glob(pattern))
    with ZipFile(p) as z:
        body=ET.fromstring(z.read('word/document.xml')).find('w:body',NS)
    blocks=[];pn=tn=0
    for b in body:
        if b.tag.endswith('}p'):
            pn+=1;blocks.append({'anchor':f'{tag}:P{pn}','p':pn,'text':''.join(n.text or '' for n in b.findall('.//w:t',NS))})
        elif b.tag.endswith('}tbl'):
            tn+=1
            rows=[[''.join(n.text or '' for n in c.findall('.//w:t',NS)) for c in r.findall('w:tc',NS)] for r in b.findall('w:tr',NS)]
            blocks.append({'anchor':f'{tag}:T{tn}','p':pn,'table':rows,'text':'\n'.join(' | '.join(r) for r in rows)})
    return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'paragraphs':pn,'tables':tn,'blocks':blocks}

docs={k:read_doc(k,p) for k,p in [('S1','*第一阶段*.docx'),('S2','*第二阶段*.docx'),('S3','*第三阶段*.docx'),('S4','*第四阶段*.docx'),('R1','*规格_R1.docx')]}
docs.update({k:read_doc(k,p,'DOCX/早期文档') for k,p in [('体验','游玩体验 需求.docx'),('人物','人物.docx'),('环境','关卡 周目 环境.docx'),('纠错','纠错.docx'),('Doctor','Doctor.docx')]})

def excerpt(tag,start,end):
    return '\n'.join(b['anchor']+' '+b['text'] for b in docs[tag]['blocks'] if start<=b['p']<=end and b['text'])

art=json.loads((HISTORY/'data/art_requirements.json').read_text('utf-8'))
audio=json.loads((HISTORY/'data/audio_requirements.json').read_text('utf-8'))
progress=json.loads((DATA/'progress.json').read_text('utf-8')) # never reset live progress
by={k:{r['id']:r for r in v['rows']} for k,v in [('art',art),('audio',audio)]}
groups={'art':[],'audio':[]}
assigned={'art':set(),'audio':set()}

COMMON={
 'WORLD':{'name':'二维场景共用规格（建议，沿现有接入）','spec':'世界640×360逻辑像素，UI1280×720；固定斜俯视地面投影(80x+28z,46z)，竖直向上；相机只平移/0.8–1.3缩放、不转主场景。大房间画布可扩为1280×720同密度，不能把整房挤到640宽。画布原点/占地和门口坐标由Codex交布局指南。nearest无mipmap为当前策略，非整数缩放待逐资产检验。','prompt':'固定斜俯视的二维绘画大色块，统一像素密度和左上主光、右下冷影，轮廓清楚；无文字、无活动人物；不烘入可移动物件。','delivery':'保留不透明源PNG/分层源文件；完整墙地、固定远景、前景遮挡各层同原点；活动物件另交。文字、门牌号、仪表动态值由代码绘制。','acceptance':'移走物件后完整露底；门/床/柜接近位不被美术改道；世界比例一致，0.8/1/1.3倍及移动实机复验。'},
 'ACTOR':{'name':'角色及动画共用规格（建议）','spec':'主角单帧64×80世界像素，身体高约60px，脚底(32,72)；4方向行序右/上/左/下，每行从准备到结束。左右非对称处不能盲镜像。NPC按真实姿态用2/4方向，不默认8方向；大体型可96×112/128×144，保持每米密度及独立脚锚。','prompt':'二维固定斜俯视完整角色，绘画大色块与清楚轮廓，同一体型和光向；无背景、文字及烘入的手持物。','delivery':'不透明母图及源层保留；透明PNG另存。以母图派生统一画布的姿态/表情；Codex整理sheet与逐帧脚、左右手、持物、受击部位锚点JSON，不要求画师编引擎配置。','acceptance':'不换脸/变高/脚滑；准备、接触、结束/抓空可辨。血污依剧情和实际伤痕分层，失我不凭空增伤。'},
 'UI_CHAR':{'name':'玩家小怪物UI造型与动作（建议）','spec':'工作画布256×256，显示高约96–128UI像素；同套脚底建议(128,224)，坐姿另记臀部支点；前/侧/背关键视图按原演出需求派生，不要求世界行走四向。','prompt':'二维绘画块面的小体型怪物，轮廓清楚，表情与短肢体易读，光向统一；无背景与文字。','delivery':'完整不透明母图/源层保留；确认后派生表情与准备/接触/收势关键姿态，透明稿另存；眼镜/教棍/锤子独立。Codex切帧/变形/菜单对位。','acceptance':'同造型贯穿开场/教程/菜单/对白；不复制参考角色，不沿用被否决旧图；小尺寸不丢细连接。'},
 'PROP':{'name':'家具与道具共用规格（建议）','spec':'与WORLD同投影同密度；通常家具64–192px宽，小物16–48px，按占地指南决定，不把逻辑米当像素。每件统一画布原点、地面角锚和手柄/持物锚。','prompt':'固定斜俯视二维物件，绘画块面、轮廓可辨，统一光向；活动部件分离，内部完整，无文字。','delivery':'主体/内部、活动门盖或抽屉、前沿遮挡、可取内容、接地阴影分层；静态不可移动件可随底图。Codex切图、量锚、导入、派生物品图标。','acceptance':'开合/挪动无残影空洞；空手/持物层唯一；尺寸不兼容先报告，不承诺任意图片免调。'},
 'STORY':{'name':'叙事插图共用规格（建议）','spec':'16:9，1280×720最终显示；原画建议2560×1440，关键人物可动层独立。镜头缓移/推近由二维图层变换，不做运行时3D。','prompt':'二维绘画色块叙事画面，统一光色与轮廓，无字幕、UI或图中文字。','delivery':'底景/主体/前景分层PNG与不透明完整源图；字幕、动态姓名/编号由代码绘制。','acceptance':'依原稿图示阅读顺序；可跳过画面但不能重结算；不因插画提前揭露作者真相。'},
 'MUSIC':{'name':'配乐共用规格（建议）','spec':'WAV PCM48kHz/24bit立体声母版；保留无削波动态和自然尾音。循环交无缝主循环及可独立淡入/收尾，标记循环起止秒或采样点；节奏/低层可分stem，非强制多格式。','prompt':'心理恐怖与悬疑配乐，无歌词和对白，留出语言频段；层次和紧张度随场景变化。','delivery':'原始工程/母版另存；文件名、实际时长、循环区间、作者/来源/许可/共享与商业使用范围/日期独立记录。Codex转换运行压缩格式并混音。','acceptance':'耳机/普通音箱听验，无循环接缝和削波；事件声音不烘入音乐，世界/界面/对白各自暂停。'},
 'VOICE':{'name':'既有配音候选与全案台本','spec':'已约定句才录：WAV PCM48kHz/24bit单声道干声；每句/随机备选独立，同一说话人声线稳定，保留停顿。动态姓名/编号/乱码不要求逐变体录制，文字保留，局部留白或按已有方案处理。','prompt':'按台本原句及情绪自然说话，无配乐、环境声或新增台词。','delivery':'原始录音另存；声演者明确同意使用/剪辑/项目共享/发布范围，禁止未经同意克隆。没有正式录制约定的句子默认只做文字与时序，不新增人工任务。','acceptance':'/ 为随机备选、& 为双方同框分轨；不按序全播。原句/条件回查现行文档，书面引文不自动做角色念白。'},
 'CODE':{'name':'Codex实现与加工','spec':'代码UI/二维几何/统一主题/Shader及既有图派生；音效按材质合成/加工或有许可免费复用。此表记录制作责任与事件映射，本轮不制作运行内容。','prompt':'','delivery':'Codex在后续制作轮实现、登记来源、处理导入并实机验证；新增费用先确认。','acceptance':'反馈不提交规则；菜单/对白/世界/效果计时分开；相同材质复用仍保留不同事件触发和反馈差异。'}
}

def add(kind,gid,name,ids,owner,method,batch,scope,description,spec_id,**kw):
    ids=list(dict.fromkeys(ids));assert ids and not(assigned[kind]&set(ids)),(gid,assigned[kind]&set(ids))
    assert set(ids)<=by[kind].keys(),gid
    assigned[kind].update(ids)
    g=dict(id=gid,name=name,children=ids,owner=owner,method=method,batch=batch,scope=scope,category=kw.pop('category','美术交付包' if kind=='art' else '声音交付包'),description=description,spec_id=spec_id,
        status=kw.pop('status','待制作' if owner=='我们' else '待实现'),quantity=kw.pop('quantity','1组，子项详见展开'),filename=kw.pop('filename',ids[0]+'_v001.png / {子ID}_{活动层或姿态}_v001.png' if kind=='art' else gid+'_v001.wav'),prompt=kw.pop('prompt',''),requirement=kw.pop('requirement','现行需求对应对象保留；数量/帧数/音色为实现建议，不新增机制。'),source=kw.pop('source','S1–S4、R1及人工原稿；子项有定位'),proposal=kw.pop('proposal','按实际交付包去重，子ID保留用于映射与进度迁移'),pending=kw.pop('pending',''),dependencies=kw.pop('dependencies',''),validation=kw.pop('validation',COMMON[spec_id]['acceptance']),
        existing_paths=list(dict.fromkeys(p for i in ids for p in by[kind][i].get('existing_paths',[]))),file='',license='',notes='',**kw)
    groups[kind].append(g)
    for i in ids:
        r=by[kind][i];r.update(group_id=gid,owner=owner,method=method,completion=r.get('status','待核验'),common_spec=spec_id)
    return g

def ids_where(kind,fn):return [i for i,r in by[kind].items() if i not in assigned[kind] and fn(r)]

# Rooms: L2/L3 first floor and L4/L5 share architecture; never require a second full background.
rooms=[('L1_ROOM','卧室',15,23,'B1'),('L2_WARD','医院小病房 / 精神病院单人病房',34,42,'B2'),('L2_LOBBY','医院候诊区 / 精神病院接待区',43,52,'B2'),('L2_CLINIC','医院诊室 / 精神科接诊室',53,62,'B2'),('L2_PHARMACY','药房 / 配药治疗室',63,73,'B2'),('L2_OFFICE','医护办公室 / 护士站',74,84,'B2'),
 ('L3_STAIRS','病区楼梯',134,146,'B3'),('L3_CORRIDOR','病区走廊护士站',147,154,'B3'),('L3_ACTIVITY','公共活动室',155,164,'B3'),('L3_GROUP','团体治疗室',165,174,'B3'),('L3_QUIET','安静室',175,184,'B3'),('L3_BATH','卫生间淋浴区',185,196,'B3'),('L3_DOUBLE','双人病房',197,206,'B3'),('L3_WORK','作业康复室',207,216,'B3'),
 ('L4_ATRIUM','皮层褶皱中庭',225,233,'B4'),('L4_MEMORY','记忆档案室',234,243,'B4'),('L4_VISUAL','视觉影像室',244,252,'B4'),('L4_DECISION','意象决策室',253,262,'B4'),('L4_BODY','身体感知室',263,272,'B4'),('L4_BRIDGE','胼胝桥',283,287,'B4'),('L4_RHYTHM','节律支路',288,293,'B4'),('L4_INDEX','索引档案室',294,299,'B4'),('L4_SWITCH','切换分岔路',300,305,'B4'),('L4_VERIFY','核验出口',306,312,'B4'),('L4_IDENTITY','身份核查室',313,319,'B4'),
 ('L5_HIPPOCAMPUS','海马回廊',432,437,'B5'),('L5_THALAMUS','丘脑中继厅',438,443,'B5'),('L5_CEREBELLUM','小脑折列室',444,449,'B5'),('L5_HYPOTHALAMUS','下丘脑温控室',450,455,'B5'),('L5_BASAL','基底核选动环',456,461,'B5'),('L5_AMYGDALA','杏仁核双室',462,467,'B5'),('L5_BRAINSTEM','脑干脉冲井',468,473,'B5'),
 ('L6_SQUARE','初始广场',480,484,'B6'),('L6_SIDE','侧室',485,486,'B6'),('L6_NARROW','狭窄通道',487,488,'B6'),('L6_TWIST','扭曲街道',489,490,'B6'),('L6_MAINT','维护通道',491,492,'B6'),('L6_MUTATION','异化节点',493,494,'B6'),('L6_EXIT','出口收束段',495,497,'B6')]
l3pairs=dict(zip(['L2_WARD','L2_LOBBY','L2_CLINIC','L2_PHARMACY','L2_OFFICE'],['L3_WARD','L3_RECEPTION','L3_CLINIC','L3_TREATMENT','L3_OFFICE']))
for key,name,start,end,batch in rooms:
    ids=['ENV_ROOM_'+key];scope=key[:2]
    if key in l3pairs:ids+=['ENV_ROOM_'+l3pairs[key]];scope='L2 / L3一层'
    if key.startswith('L4_'):ids+=['ENV_ROOM_'+key+'_L5'];scope='L4 / L5一二层'
    if key=='L1_ROOM':ids+=['ENV_ROOM_TUTORIAL','ENV_ROOM_L1_DESK_DETAIL'];scope='开场 / 教程 / L1'
    if key=='L6_SQUARE':ids+=['ENV_ROOM_HIDDEN_STREET'];scope='L6 / L1隐藏Street'
    text=excerpt('S1',start,end)
    desc=f'{name}的可交付空间包。'+ ('共用房型和门位，异化层另交；L3一层不重复新画医院五房。' if key in l3pairs else 'L5复用L4房型，原搜寻件转为陈设/障碍，不能重新设钥匙。' if key.startswith('L4') else '保留既定出入口、主要陈设与可走空间。')
    desc+='墙地必须完整，人物和要移动/翻动/开合的家具独立；固定远景允许合绘。每个房间先按原稿图示与S1连接由Codex给占地/遮挡指南，再绘制；范围扩大时扩画布不缩小角色。'
    add('art','ART_ENV_'+key,name+' · 场景包',ids,'我们','主要场景分层绘制；Codex组装/遮挡/异化参数',batch,scope,desc,'WORLD',source=f'S1:P{start}–{end}；人工环境图示；对应S3人物事件',source_details=text,
        differences='基础层1套；按原状态增加血污/腐朽/局部肉体与邪典结构的状态层，不能用全屏滤镜代替明确异化。'+('隐藏Street只取广场片段和独立出口，不复制七段/45人。' if key=='L6_SQUARE' else ''),
        quantity='1房型包'+(' + 1套精神病院状态差异层' if key in l3pairs else ' + 1套第五关异化差异层' if key.startswith('L4') else ''),filename='ENV_ROOM_'+key+'_base_v001.png / _foreground_v001.png / _state_*.png',prompt=name+'空间，保留明确门路和环境线索；按日常、破败、血污或肉体异化状态分层。',status='已有候选待核验' if key=='L1_ROOM' else '待制作',dependencies='已确认房型/连接；Codex先给同投影布局指南')

# Furniture packs are deduplicated source sets used by several rooms.
prop_sets=[('HOME','卧室家具及开合层','B1',lambda r:r['id'] in ['ENV_BED','ENV_BEDSIDE','ENV_DESK','ENV_CHAIR','ENV_STOOL','ENV_TRUNK','ENV_COATRACK','ENV_STORAGE','ENV_BOOKSHELF','ENV_WARDROBE','ENV_FAN','ENV_LAMP','ENV_WINDOW','ENV_DOOR']),
 ('HOSPITAL','医院/病区家具及设施','B2',lambda r:r['id'].startswith('ENV_ALL_') and 13<=int(r['id'][-3:])<=65),
 ('BRAIN','皮层/白质设备与第五关变化层','B4',lambda r:r['id'].startswith('ENV_ALL_') and 66<=int(r['id'][-3:])<=115),
 ('DEEP','深部脑结构活动设备','B5',lambda r:r['id'].startswith('ENV_ALL_') and 116<=int(r['id'][-3:])<=164),
 ('STREET','Street公共构件及可动物','B6',lambda r:r['id'].startswith('ENV_ALL_') and 165<=int(r['id'][-3:])<=195)]
for key,name,batch,fn in prop_sets:
    ids=ids_where('art',fn)
    add('art','ART_PROP_'+key,name,ids,'我们','主体美术与活动件分层；Codex重排/变形/切图',batch,'多房间复用',name+'按子项清单一次交一套源组件。同一物件在不同房间只是摆放实例，不重复画；静态件可在对应场景底层交付并注明来源，活动件必须独立。通用开柜/翻书/抬手由角色动作和组件位移配合，不额外索要每件完整视频。','PROP',quantity=f'{len(ids)}个保留子ID，按共用形体减少重复贴图',prompt=name+'，材质和视角统一，活动门盖及内容物独立。',differences='HOME床头柜先用现有96×80共享原点、地面角锚(8,40)，抽屉内侧48×24；其他家具按实际占地交指南，不能套用柜子尺寸。' if key=='HOME' else '同材质柜体/终端/座椅复用形体；不同事件要求的内层、夹具、约束和异化轮廓保留。')

for key,name,selector,batch in [
 ('STORY','叙事小物与身份线索',lambda r:r['id'].startswith('ENV_SMALL_PROPS_') and any(t in r['id'] for t in ['DOCTOR_COAT','PATIENT_GOWN','COLLAR','PHOTO','RELIC','SHOES']),'B2'),
 ('HAND','手持/交付/搬运共用道具',lambda r:r['id'].startswith('ENV_SMALL_PROPS_'),'B1')]:
    ids=ids_where('art',selector)
    add('art','ART_PROP_'+key,name,ids,'我们','主要剧情道具绘制；Codex裁切/图标派生/持物对位',batch,'L1–L6 / 教程',name+'以物品实体为单位交付，不另画一套背包图标。钥匙、食物、针具、推床、轮椅、束带与纸页按实际归属与接触显示。文字编号、批次和文书内容由代码绘制，不烘入图；猫狗项圈、袖口缝线、病服领标和照片是身份线索，细节不能被统一缩图抹掉。','PROP',quantity=f'{len(ids)}子项；同物场景/手中/UI共用，候选文具非新增必做',prompt=name+'，小尺寸可辨，关键识别细节保留，文字区域留空。',pending='笔袋/橡皮/直尺/画笔/剪刀等旧表候选只选满足原杂物需求的最少组合，不扩大为逐个采购清单。')

hero_ids=ids_where('art',lambda r:r['id']=='CHR_MAIN' or r['id'].startswith(('CHR_MAIN_OUTFIT_','CHR_MAIN_STATE_','CHR_MAIN_CONTROL_')) or r['id'].startswith('POR_MAIN'))
add('art','ART_CHAR_MAIN','自主主角 · 体型/衣装/表情层',hero_ids,'我们','母图+衣装差异层；肖像从母图裁切派生','B1','全程','帅气、瘦弱男性。先交第一关崭新浅蓝睡衣基准，后按Doctor明确衣装阶梯：睡衣旧/破，医院病服新/旧/血，精神病院病服新/旧/血，医师白衣新/脏/血，黑西装，红大袍。长期性格、周目衣旧、实际伤痕和失我为独立状态，不按关号自动变冷血。肖像尽量由同一母图/表情层派生，不另画每个情绪一张全新脸。','ACTOR',quantity='1体型；6类衣装+原文旧/血差异；必要表情共用',source='用户外貌补充；Doctor:P1–27；S2:T6；S3:T59；R1:T3',prompt='帅气瘦弱男性，崭新浅蓝睡衣套装，自然站立，四肢完整，神情尚属日常。',pending='年龄/具体发型及最终绘画风格未定；不沿用旧表的高中生定论。后续血污衣装数量按原周目表，不新增伤口。')
action_ids=ids_where('art',lambda r:r['id'].startswith(('CHR_MAIN_ACT_','CHR_MAIN_SKILL_')))
add('art','ART_ANIM_MAIN','主角 · 共用关键姿态与必要专属动作',action_ids,'我们','少帧关键姿态+通用动作；Codex分层变形/配对/时序','B1','全程','同一体型派生待机、行走、高/中/低搜寻、递取、进食/服药、开门、躺下醒来、受击/死亡及神经反应。皮肤/腹部/缩手等可共用收手和重心姿态；真正改变轮廓的俯身、踢腿和醒来需要关键姿态。不是给每次搜寻或十二技能各做一套长动画。','ACTOR',quantity='基础姿态包1套，衣装换层；专属反应按子项列差异',animation={'directions':'基础4向；专属首次交侧面关键姿态，接入需要再补反向','frames':'待机2/向；行走4/向；搜寻高/中/低各3关键姿态/向；接取/进食/受击各3；醒来4–6；膝跳准备/伸腿/收腿3','duration':'待机1.2s循环/行走0.64s循环为表现建议；搜寻由4/5/6/7s及修正规则驱动；皮肤0.5s；肠胃1.2s；膝跳0.15/0.15/0.35s','loop':'待机/行走/翻查接触段可循环，接触结算动作不循环','anchors':'脚(32,72)；每关键帧左右手/物品点由Codex测量并记录；手空置，物品独立','contact':'接取建议0.30s并在规则交付节点提交；膝跳只攻击段可命中；抓握闭合前可缩手，收手不补交付'},prompt='同一瘦弱男性的准备、接触、收势关键姿态，衣装和脚底位置一致。',dependencies='ART_CHAR_MAIN母图；动作时序见制作规划技能表')
player_ids=ids_where('art',lambda r:('PLAYER' in r['id'] or r['id'].startswith('POR_PLAYER')) and r.get('status')!='停用')
add('art','ART_CHAR_PLAYER','新玩家小怪物 · 统一造型与演出',player_ids,'我们','新母图定型后派生表情/关键姿态；Codex菜单动画','B1','开场 / 教程 / CRT / 冰柜 / 对白','整体重新设计小体型、奇怪可爱且轮廓清楚的小家伙。旧五造型与v001都不采用。保留远眺背影、无奈摆手、转头、教学眼镜/教棍、砸节点、拉出检查面板以及原情绪；同一身体比例派生，不因可爱改变心理恐怖叙事。','UI_CHAR',quantity='1母图+前/侧/背关键视图；约8个表情可从层组合，5组演出关键姿态',differences='UI工作画布256×256，显示高约96–128UI像素；坐姿/背影按同体型。动作以2–4关键姿态+层变形；挥锤含准备/砸中/收势，锤子独立。',prompt='体型小、奇怪可爱的小怪物，轮廓清楚，易读表情与短肢体，不直接复制参考图角色。',status='需重新设计',pending='母图需要整体调整，用户尚未确认；本轮不出新图、不扩展正式动画。')

# 45 identity packs keep normal/altered/action/portrait child IDs in one delivery.
street_paras=[1596,1602,1607,1613,1619,1626,1634,1642,1648,1656,1663,1687,1693,1699,1705,1711,1718,1723,1728,1735,1742,1748,1756,1764,1773,1789,1795,1801,1806,1813,1820,1826,1831,1836,1842,1848,1853,1858,1864,1880,1885,1892,1899,1906,1914]
npcs=[]
for idx,pn in enumerate(street_paras):
    n=idx+1;prefix={1:'FATHER',12:'CAT',26:'DOG',32:'MOTHER'}.get(n,f'N{n:02}')
    baseid='CHR_OTHER_NPCS_'+prefix
    ids=ids_where('art',lambda r,prefix=prefix: r['id'].startswith('CHR_OTHER_NPCS_'+prefix+'_') or r['id']==baseid or ('POR_OTHER_NPCS_'+prefix==r['id']) or r['id'].startswith('POR_OTHER_NPCS_'+prefix+'_'))
    assert ids,(n,prefix)
    base=by['art'][baseid];name=base['name'].split('／')[0];end=(street_paras[idx+1]-1) if idx+1<len(street_paras) and street_paras[idx+1]-pn<20 else pn+6
    evidence=excerpt('S3',pn,end)
    early_scope=base['scope'].split('／')[0];batch={'第1关':'B1','第2关':'B2','第3关':'B3','第4关':'B4'}.get(early_scope,'B3')
    g=add('art','ART_NPC_'+prefix,name+' · 同一身份美术包',ids,'我们','母图/异化轮廓与必要姿态；Codex共用动作和持物配对',batch,base['scope']+'；异化L5/L6按实际出场',name+'保留独立身份，普通与异化不是两个人。先交原形及该人物事件所需2–3接触关键姿态；常规转身、走动、接纸/持杯/抬手从同角色层复用；肖像裁自母图。后期异化改变轮廓的部分专门绘制，准备与收势复用，不把全部45人都扩为全动作八方向。实际事件与后期行为见原文摘录。','ACTOR',source=base['source']+f'；S3:P{pn}–{end}（Street行为）',source_details=evidence,quantity='1身份：原形1套+明确异化1套；肖像派生，动作按需要',prompt=name+'的二维角色，保持原身份辨识；异化形态保留原服饰特征并呈现明确肉体变化。',animation={'directions':'常驻站/坐/床/轮椅用2向；实际跨房行走/追逐用4向；不补不出现的站姿','frames':'母图1/向；通用动作复用；抓握/攻击/治疗/转运等需要准备/接触/收势3关键姿态，专属轮廓见原文','duration':'服从S3实际步骤与S4:T15–21，不由美术自行改伤害/冷却','loop':'待机/移动可循环；接触/交付/施治/攻击不循环结算','anchors':'脚/轮椅轮底/病床落地锚；双手/工具/配对接触点；Codex量测','contact':'抓握闭合、针接触、绷带完成、车体碰撞各用独立节点；未命中/被打断保留未完成状态'},dependencies='ART_ANIM_MAIN共用站位；该身份对应事件，不给NPC拼接别人的能力')
    npcs.append({'number':n,'identity_id':baseid,'group_id':g['id'],'name':name,'source':g['source'],'street_event':evidence})

first_ranges={1:(165,176),2:(623,636),3:(372,436),4:(637,660),5:(788,823),6:(1063,1077),7:(346,371),8:(970,1013),9:(372,436),10:(824,843),11:(844,858),12:(60,83),13:(1183,1198),14:(661,699),15:(925,949),16:(1139,1163),17:(1217,1234),18:(560,574),19:(1259,1278),20:(372,436),21:(526,547),22:(700,731),23:(824,843),24:(887,917),25:(1014,1030),26:(39,59),27:(1199,1216),28:(700,731),29:(950,969),30:(1031,1054),31:(1078,1097),32:(99,109),33:(461,523),34:(461,523),35:(1166,1182),36:(661,699),37:(732,774),38:(887,917),39:(1098,1117),40:(1235,1258),41:(591,607),42:(575,590),43:(732,774),44:(859,886),45:(1118,1138)}
for npc in npcs:
    g=next(g for g in groups['art'] if g['id']==npc['group_id']);start,end=first_ranges[npc['number']]
    token=re.split(r'第[一二三四五六]|／',npc['name'])[0]
    if npc['number']==41:token='精神病人'
    normal=[]
    for b in docs['S1']['blocks']:
        if b['p']>=480:continue
        if 'table' in b:
            for ri,row in enumerate(b['table'][1:],2):
                if token and token in row[0]:normal.append(b['anchor']+f'R{ri} '+' | '.join(row))
    normal += [b['anchor']+' '+b['text'] for b in docs['S3']['blocks'] if start<=b['p']<=end and b['text']][:9]
    g['source_details']='首次出现形态/行为（不是另造健康常人形）：\n'+'\n'.join(normal[:12])+'\n\nStreet异化行为：\n'+g['source_details']
    g['source']+=f'；首次形态S3:P{start}–{end}'
    if npc['number']==12:g['differences']='黑猫建议64×48画布，地面脚锚(32,40)，体高约18–24世界像素；伏低/扑抓/跳窗关键姿态，猫不是缩成60px高的人形。抓、抱猫、跳窗保留接触点。'
    elif npc['number']==26:g['differences']='大黄建议80×64画布、脚锚(40,56)，体高约28–36世界像素；项圈独立，低头搜寻/叼取/递出/死亡肉泥与异化碎裂按不同事件分层。'
    elif npc['number']==9:g['differences']='轮椅人物建议96×96画布、轮底锚(48,84)，人物坐姿和轮椅分层；轮椅源件复用ENV_SMALL_PROPS_WHEELCHAIR，不新增站立全套。'
    elif npc['number']==10:g['differences']='被转运患者需卧姿/坐姿关键图，建议96×80，床/床单/腕带另层；Street坐墙边不凭空恢复完整行走套。'
    elif npc['number']==35:g['differences']='双头连体轮廓建议96×112、脚锚(48,104)；左右头与对应记录不交换。初形已有特殊身体，不先新增普通单头形态。'
    else:g['differences']='默认64×80/脚锚(32,72)；超出轮廓先扩画布不独立缩小身体。首次形态和后期异化按下方原文，不擅定未写的年龄、身份或健康前史。'

hunter=ids_where('art',lambda r:'HUNTER' in r['id'])
add('art','ART_NPC_HUNTER','隐藏Street猎手 · 追逐/扑抓',hunter,'我们','专属轮廓与3阶段关键姿态；Codex追逐/配对','B2','L1隐藏Street','仅第一关隐藏分支猎手，和自主主角/Street45身份分开。帽兜与无脸等采用现行人物描述，不能套成主角。察觉、追逐、抓前摇、扑抓接触/抓空、释放姿态可辨。','ACTOR',source='S3:P312–337；S4:T22/24',prompt='隐藏街道猎手，保持原描述的可辨轮廓，扑抓准备、接触、抓空收势。')

story_ids=ids_where('art',lambda r:r['id'].startswith('SLIDE_A'))
add('art','ART_STORY_WORLD','世界观开场 · 城市/乡村/海洋/实验室',story_ids,'我们','4张分层叙事画；黑屏/标题/卧室镜头由Codex复用','B2','启动开场A01–A09','按人工原稿左上到右下图示次序：危机黑屏→城市/乡村/大海灾变快闪→实验事故疑问与神经元实验室→入侵疑问→无选项卧室与标题显隐。只需灾变三景和实验室四幅新画，A01/05/07字幕与A08/09卧室共用，不逐字幕另画。','STORY',quantity='4新画；其余代码黑屏/卧室复用',source='体验:P3–13及相关图示；纠错:P3–13（只补未替换内容）',prompt='城市、乡村、海洋的灾变与人动物逃离，实验室神经元实验定格，疑问式叙事，不解释最终真相。')
add('art','ART_STORY_PLAYER','寄生开场 · 异星/飞船/背影',ids_where('art',lambda r:r['id'].startswith('SLIDE_B')),'我们','异星远景/飞船2张分层图，角色与卧室镜头复用','B2','建档后B01–B11','新小怪物远眺荒凉景象及白垩晶屑平原/霓虹纤维山脉；飞船航行用静态分层缓移。背影、摆手、转身从小怪物包派生，床上睡眠/醒来从主角和卧室包取景。保留动态姓名、入侵者ID、乱码及原叙述，取消五选一。','STORY',quantity='2场景新画+已有主体分层；不是11张全新插画',source='体验:P18–60及图示；本次取消五选一',prompt='白垩晶屑平原与霓虹纤维山脉拼成的荒凉流浪异星，以及飞船在太空航行的分层画面。',dependencies='新小怪物母图；主角睡眠/醒来关键姿态')
add('art','ART_STORY_ENDINGS','三结局 · 现实病床与来处星球',ids_where('art',lambda r:r['id'].startswith(('SLIDE_E','ENDING_'))),'我们','共享现实病床1底景+睁眼意图差异；E2星球复用开场','B6','E1 / E2 / E3 / 尾声','E1广场光收窄到病房灯，现实宿主睁眼，脑内出口消退；E2门内原对白后现实身体由角色接续，再切玩家外部本体于来处星球恢复感知；E3现实病床视点由玩家接续，角色身份反馈停止。病房同底景，眼神/手部/视点差异表达胜者，不再加战斗、地图或新旁白。','STORY',quantity='现实病床1底景+3差异节拍；星球复用+玩家本体恢复姿态',source='R1:P20–32；S3:P1945–1947',prompt='现实病床上身体睁眼的近景，病房灯光；短尾声异星本体恢复感知；分层保留不同意图，不写结局文字。',dependencies='ART_STORY_PLAYER、ART_CHAR_PLAYER；现实身体外貌以三重身份连续性为准',pending='现实宿主与借用人形的外貌细节未充分定稿；不直接假定两个全新设计，尾声制图前集中核对。')
photos=ids_where('art',lambda r:r['id'] in ['UI_RECORD_34','UI_EVIDENCE_REHAB_PHOTO','UI_EVIDENCE_FAMILY_PHOTO','UI_REHAB_WORK_ART','ENV_EVENT_BODY_UNKNOWN'])
add('art','ART_STORY_EVIDENCE','叙事证据图/独立遗体',photos,'我们','确需绘制内容；相纸/标签/文字由Codex','B3','L2–L5 / Street线索','家属照片、康复合影、核心记忆照片按原事件对应关系绘制，原文未定的人数与时代不补设。作业作品复用病友劳动层；独立死者不是已知活人换皮，血污/尸体与遗物依据实际事件显示。小图书签由同源裁切，不重复新画。','STORY',quantity='3类照片内容+康复作品局部+1独立死者姿态（以原文实际身份为界）',prompt='叙事照片和病区遗物图像，保留现行身份对应；伤口、血迹与尸体按实际事件状态表现，无文字。',pending='照片未明确参与者不编造；先使用局部、背影或遮挡保留信息边界。')

# Remaining records are UI, common effects, projection views, aliases and tombstones.
for key,name,test,method in [
 ('RETIRED','停用旧玩家五形象',lambda r:r.get('status')=='停用','仅保留历史ID，不制作不引用'),
 ('UI','全部界面、通用图标及书面文字',lambda r:r['category'] in ['UI与效果','文字资源'] and not r['id'].startswith(('FX_','TEX_MASKS')),'代码UI/主题/Shader；物品图标从实体裁切；不向团队索要按钮面板'),
 ('FX','基础Shader与局部反馈',lambda r:r['id'].startswith(('FX_','TEX_MASKS')),'程序遮罩/二维粒子/Shader，必要纹理从主素材派生'),
 ('DERIVED','共用材质、模块、派生与映射',lambda r:True,'现有图复用/处理/分层变形，必要缺口单独回报')]:
    ids=ids_where('art',test)
    if ids:add('art','ART_CODE_'+key,name,ids,'Codex',method,'B1','全程',name+'由Codex负责，展开保留稳定ID与各事件映射。CRT神经节点、冰柜开盖冷气、二维多视图人体旋转、螺旋星环旋转和图书三类书签保留原操作关系；不把3D体验简单删掉。血迹、灰暗、邪典/肉体异化按实际状态，提供降低震动/闪烁/虚化设置。','CODE',status='停用' if key=='RETIRED' else '待实现',quantity='复用/代码生成，0新增人工采购',prompt='')

# Clean live production fields; old candidate wording survives only in history.
for r in art['rows']:
    r['reference_note']='' # old AI advice is not a requirement
    for f in ['spec','description','prompt','requirement','proposal','pending','layers','delivery']:
        r[f]=re.sub(r'[^。；\n]*(?:Tripo|GLB|拓扑|面数|蒙皮|3D绑定)[^。；\n]*[。；]?','',r.get(f,''),flags=re.I)
    if r.get('animation'):
        r['animation']['note']='子项仅保留动作需求；交付方式按父包，共用关键姿态优先，不要求每子项独立全序列。'
    if r.get('alias_of'):r['method']='复用 '+r['alias_of']+'；0新增主体源图'
    if r['id'].startswith('CHR_OTHER_NPCS_') and r['id'].endswith('_ACTION_REF'):
        r['description']='本身份动作差异索引，按父包关键姿态与通用配对实现，不再逐条要求完整序列帧。'
    if r['id']=='ENV_CHAIR':r.update(name='靠背学习椅',pending='',requirement='S1:T2R4明确学习椅，接近电竞椅轮廓；旧方椅候选不采用')
    for f in ['description','prompt','requirement']:
        r[f]=r.get(f,'').replace('所选怪物','统一新小怪物').replace('所选玩家','统一新玩家').replace('所选形象','统一新形象')

# Music: 15 IDs, 8 actual delivery packs. E1 short ending uses MUS_END; E2/E3 share motif.
music_defs=[
 ('OPEN','世界危机与寄生开场',['MUS_OPEN','MUS_STORY'],'B2','开场','悬疑、毁灭与未知来处；世界灾变与寄生自述可共用主题，保留两段节拍。','2分段；60–100s开场+40–80s自述，非循环'),
 ('ROOM','菜单与早期卧室',['MUS_MENU','MUS_ROOM'],'B1','菜单 / 教程 / L1','日常温度与微妙不安；音乐不从开头就恐怖轰炸，后续可渐暗。','1主题+菜单/卧室2编配；60–120s无缝循环'),
 ('DANGER','父亲危险与隐藏追逐',['MUS_DANGER','MUS_STREET'],'B2','L1 / 隐藏Street','危险接近、血门和猎手追逐的压力；短促紧张节奏与持续层分开，危险解除可自然收束。','1危险底层+1追逐节奏层；60–90s循环+3–6s尾音'),
 ('HOSPITAL','医院与精神病院',['MUS_HOSPITAL','MUS_ASYLUM'],'B3','L2 / L3','医院冷淡秩序到病院规训、伤口与记录矛盾；可同主题的两状态，但不能听成完全相同房间。','2状态编配；每段90–150s无缝循环'),
 ('BRAIN','皮层白质及异化战斗',['MUS_CORTEX'],'B4','L4 / L5一二层','脑内空间、肉体结构与邪典秩序；静探索底层和战斗压力层分离，不用全程温柔氛围。','90–150s循环底层+压力stem'),
 ('DEEP','深部脑结构',['MUS_DEEP'],'B5','L5第三层','有机脉动、身份侵蚀、追逐与冷热不适；阴暗但给动作预警和对白留空间。','90–150s循环，稳定底层+追逐层'),
 ('STREET','最终Street',['MUS_STREET_FINAL'],'B6','L6七段','开阔却受困、熟悉人物肉体异化；朝出口推进，友方遇害不额外强制英雄凯歌。','90–150s循环+可渐进层；七段共用'),
 ('ENDINGS','周目收束与三结局',['MUS_END','MUS_ENDING_E2','MUS_ENDING_E3','MUS_EPILOGUE'],'B6','休息 / E1 / E2 / E3','短周目尾音与病床醒来共用动机；幻觉消退、角色切断连接、玩家夺取分为可辨收束，星球尾声不另写一整关配乐。','1个3–6s周目尾音；3个15–35s结局分段+可复用10–20s尾声，均非循环')]
for key,name,ids,batch,scope,mood,duration in music_defs:
    add('audio','AUD_MUSIC_'+key,name,ids,'我们','原创/已授权配乐；主题与分段/stem复用',batch,scope,mood+' 乐曲只提供情绪与空间，不把针刺、关门、死亡或台词烘入。','MUSIC',quantity=duration,duration=duration,loop='见分段说明',mood=mood,source='原稿演出/场景情绪；具体曲数、时长及编配为实现建议',prompt=mood+'无歌词、无对白，事件声独立。',filename='MUS_'+key+'_base_v001.wav / _tension_v001.wav / _outro_v001.wav')

# SFX groupings preserve every event mapping, not one universal beep.
sfx_sets=[
 ('UI','界面/CRT/冰柜/星环',r'^(SFX_UI_|SFX_CRT_|SFX_FREEZER_|SFX_COLD$|SFX_HAMMER$|SFX_NEURAL$|SFX_RESIST$|SFX_BODY_TURN$|SFX_STAR_UNLOCK$|SFX_CHECKPOINT$|AMB_CRT$|AMB_FREEZER$)'),
 ('MOVE','脚步/身体/布料/床褥',r'^(SFX_FOOTSTEP$|SFX_FABRIC$|SFX_BED$|SFX_SHIFT$|SFX_WATER_STEP$|VOC_HOST_BREATH$)'),
 ('SEARCH','门柜/木金属/翻找纸布/交付',r'^(SFX_DOOR_(OPEN|CLOSE|LOCK)$|SFX_DRAWER$|SFX_SEARCH_|SFX_CHAIR_MOVE$|SFX_KEY$|SFX_ITEM_HANDOFF$|SFX_BOWL$|SFX_WRAPPER$|SFX_STAMP$|SFX_PAPER_TEAR$)'),
 ('BODY','神经反应/吞咽/抓挠/受击',r'^(SFX_SKIN$|SFX_GUT$|SFX_TINNITUS$|SFX_DRYMOUTH$|SFX_HIT$|SFX_KICK$|SFX_AWAKE$|VOC_HOST_PAIN$|VOC_PLAYER_LAUGH$)'),
 ('MEDICAL','轮椅推床/针具/药物/束带夹具/录音',r'^(SFX_WHEELCHAIR$|SFX_BANDAGE$|SFX_MEDICINE$|SFX_NEEDLE$|SFX_STRAP$|SFX_TRANSPORT$|SFX_ISOLATION$|SFX_RECORDER$|SFX_CLAMP$)'),
 ('CREATURE','猫狗/肉体异化/父母/猎手',r'^(SFX_CAT_|SFX_DOG|SFX_PET_FIGHT$|SFX_BOTTLE$|SFX_DOOR_CHANGE$|SFX_COLLAPSE$|SFX_HUNTER$|VOC_PARENTS_CHANGE$)'),
 ('WORLD','空间底噪/水风/电气/冲撞/转场',r'.*')]
for key,name,pattern in sfx_sets:
    ids=ids_where('audio',lambda r: r['category'] in ['音效','环境','角色非语言'] and re.search(pattern,r['id']))
    if ids:add('audio','AUD_CODE_'+key,name,ids,'Codex','材质组自合成/加工/许可适用免费素材复用','B1' if key in ['UI','MOVE','SEARCH','BODY'] else 'B2','全程（子项保留场景/触发）',name+'按材质归成可复用音库：每种材质2–4个微变体和准备/接触/收尾需要的片段；具体事件通过音量、滤波、空间距离与播放节点区分。声音不替代真正接触，医护警示不召出不存在的人。非语言气息可加工，无法自行满足的特定声演才集中提出例外，不默认转给同伴。','CODE',quantity=f'{len(ids)}触发ID → 共用声音组，0默认人工采购',duration='UI约0.05–0.5s；接触0.1–1s；开合/生理0.5–3s；空间底45–90s可循环',loop='材质接触否；持续风/水/电机是，真实状态控制启停',speaker='非语言；不新增对白/真人录音要求',authorization='自合成登记脚本/版本；第三方逐文件记作者/URL/许可/日期/改动，许可待核不发布',prompt='')

# Legacy spoken candidates are NOT authorization for recording. Keep them grouped.
legacy_audio_ids=set(r['id'] for r in json.loads((HISTORY/'data/audio_requirements.json').read_text('utf-8'))['rows'][:244])
def voice_role(s):
    s=re.split(r'[\[【（(]',s)[0].strip()
    if '玩家' in s or '寄生者' in s:return '玩家'
    if '角色' in s or '主角' in s:return '主角'
    if '父亲' in s:return '父亲'
    if '母亲' in s:return '母亲'
    if '旁白' in s:return '开场旁白'
    return s or '原文标签待核'
voice_buckets=collections.defaultdict(list)
for i,r in by['audio'].items():
    if i in assigned['audio']:continue
    role=voice_role(r.get('speaker',''));scope=r['scope']
    scene=next((name for token,name in [('第三关','L3'),('第二关','L2'),('第四关','L4'),('第五关','L5'),('第六关','L6'),('隐藏','隐藏Street'),('第一关','L1'),('教程','教程'),('开场','开场'),('结局','结局')] if token in scope),'全程')
    voice_buckets[(scene,role)].append(i)
for idx,((scene,role),ids) in enumerate(sorted(voice_buckets.items()),1):
    legacy=any(i in legacy_audio_ids for i in ids)
    gid='AUD_SCRIPT_'+hashlib.sha256((scene+'|'+role).encode()).hexdigest()[:10].upper()
    add('audio',gid,scene+' · '+role+'台本',ids,'待约定','文本必做；只整理既有配音范围，未确认录制不新增人工工作','B2',scene,'按场景/说话人归并台本。原句及/随机备选、&同框标记逐字保留；旧表候选与现行原文来源分别标记。无配音仍需完整文字、停顿和事件顺序；不能用台词替代动作。新增后续台词只列文本覆盖，不自动变成同伴录音任务。','VOICE',category='配音候选 / 台本',quantity=f'{len(ids)}稳定台本ID，非{len(ids)}项新增录音',duration='按原句自然语速；原停顿和随机备选分开',loop='否',speaker=role,authorization='录制约定/说话人同意尚待登记；不得因旧提示词表存在而推定全量录音已获确认',status='原台本保留；录制范围待核',source='既有音频候选'+('（含旧244条内记录）' if legacy else '（后续文本补录，未批准人工录制）')+'；现行S2/S3/R1逐项定位',prompt=COMMON['VOICE']['prompt'])
for r in audio['rows']:
    r['recording_scope']='旧表配音候选；仅已有明确约定部分录制' if r['id'] in legacy_audio_ids and 'VO' in r['id'] else '文本/非语言映射，不新增人工录制'
    if r.get('category') in ['对白','待核台本','台本待核']:
        r['pending']='保留本句原字与随机备选；旧表未给完整现行定位的句子，录制前回查来源。不新增录制约定。'
    if r['id']=='SFX_DOG_CHANGE':r.update(description='第一关父亲剧情效果使大黄变肉泥，及第五/六关父亲真实命中异化体后的碎裂，按各自成立节点播放；肉体碎裂、落地和退场分层，与悲痛台词分开。',prompt='肉体异化碎裂与落地的湿重质感，和短促异常退场层分开。',source='S3:P219–231、P1290–1300、P1789–1794；各自不同触发规则')
    if r['id']=='SFX_HIT':r.update(description='按真实攻击和材质分衣料闷击、肉体接触及既定异化碎裂；空挥/命中/阻挡区别。不能给普通动作添加骨折或新伤害。',prompt='衣料闷击与肉体接触，空挥、命中、硬障碍撞击分开。')
    if r['id']=='VOC_HOST_BREATH':r.update(description='男性主角自然、紧张与恢复的非语言气息；沿已确认瘦弱男性，年龄未定。由Codex加工/许可复用，不默认新增真人录音。',prompt='瘦弱男性自然、紧张、恢复三种呼吸，短句间留白，无对白。')

# Common contracts live once. Leaf rows now describe deltas, not competing jobs.
for kind,payload in [('art',art),('audio',audio)]:
    group_map={g['id']:g for g in groups[kind]}
    for r in payload['rows']:
        g=group_map[r['group_id']]
        if kind=='art':
            if g['spec_id'] in ['WORLD','ACTOR','UI_CHAR','PROP','STORY']:
                r['spec']='适用 '+g['spec_id']+' 共用规格；仅按父包与本子项差异制作。'
            if r['id']=='ENV_BEDSIDE':r['spec']='96×80共享原点；抽屉内侧48×24；地面角锚(8,40)、拉手(60.74,25.77)；活动+x最多7px。'
            if r['id']=='ENV_SMALL_PROPS_KEY':r['spec']='16×16世界像素PNG，钥匙柄/齿轮廓可辨；同一图派生物品栏，Codex测持物锚。'
            if g['id'].startswith('ART_NPC_') and r.get('animation'):
                r['animation']=g.get('animation',{'directions':'追逐4向','frames':'准备/接触/收势3关键姿态','loop':'移动可循环，抓取不循环结算','anchors':'脚底/双手配对点由Codex测量','contact':'真实抓取接触节点，不瞬移对位'})
            if g['owner']=='Codex':r['quantity']='0新增人工任务；'+('停用旧ID' if r.get('status')=='停用' else '代码/既有素材派生复用')
        else:
            r['spec']='适用 '+g['spec_id']+' 共用规格。'
            if g['spec_id']=='MUSIC':r.update(duration=g['duration'],loop=g['loop'],performance_notes=g['description'],prompt=g['prompt'])

# Bind inherited prop names to current text, not old AI promises. Unmatched names
# remain optional implementation candidates; they are not new human purchases.
synonyms={'候诊长椅':['候诊椅'],'护士站台':['护士站'],'录音器':['录音设备'],'手工绘画桌':['手工/绘画桌','绘画桌'],'低储物柜':['低矮储物柜'],'锁闭材料柜':['材料柜'],'阅读桌':['查阅桌'],'观看椅':['座椅组'],'身体检查台':['检查台'],'脉冲检测器':['脉冲检测'],'线缆连接器':['电缆','连接器'],'运动校准机械臂':['机械臂'],'温控总控台':['温控控制台','温控台'],'温度显示屏':['温度屏'],'雕像喷泉':['喷泉'],'关卡钥匙':['钥匙'],'一碗粥':['白瓷碗','粥'],'父亲酒瓶与碎瓶':['酒瓶'],'父亲香烟':['烟'],'父亲木框眼镜':['木框眼镜'],'大黄红项圈':['红项圈'],'白色医生大褂':['白色医生大褂','破损大褂'],'旧病服':['病服'],'转运推床':['推床'],'编号腕带':['腕带'],'编号药杯':['药杯'],'检查针具':['针具','针刺'],'药师与保安钥匙串':['钥匙串'],'束带与约束扣':['束带'],'转运床单':['床单'],'密封污物袋':['污物袋'],'清洁工具':['拖把'],'家属照片实体':['家属照片'],'劳动病友空纸盒':['纸盒'],'文具笔':['文具','笔'],'空白文件纸页':['纸页'],'床头闹钟':['闹钟'],'教程玩家眼镜':['戴上眼睛','眼镜'],'教程教棍':['教棍'],'教程锤子':['锤子','大锤'],'单眼电子检查器':['单眼','检查器'],'场景书':['书籍'],'可翻查的普通衣物':['衣物'],'搬运用遮盖布':['遮盖布'],'低位带轮搬运板':['搬运板'],'可放遗物的污物桶':['污物桶'],'脑回墙内的旧门牌':['旧门牌']}
synonyms.update({'靠背学习椅':['学习椅','靠背椅'],'洗手台':['洗手池'],'手工绘画桌':['操作桌'],'低储物柜':['矮柜'],'弧形屏幕':['弧形屏'],'病历柜':['病历档案柜'],'数据终端':['资料终端'],'身体感知映射区':['身体映射区'],'检修柜':['维护设备柜'],'连接节点':['接驳节点'],'线路检修柜':['线路维护柜'],'检修储物柜':['维护储物柜'],'身份读取器':['身份识别终端'],'检修终端':['维护终端'],'身份信息屏':['身份信息显示屏'],'身份核验台':['核验台'],'检修面板':['维护面板'],'监控屏':['监测屏'],'中继控制台':['控制台'],'小脑折叶模拟阵列':['折叶阵列'],'姿态测试架':['姿态架'],'平衡训练平台':['平衡平台'],'设备储物柜':['储物柜'],'传感器终端':['传感器'],'温度显示屏':['监测屏'],'压力阀组':['阀组'],'加热液罐':['液罐'],'加热器':['加热装置'],'备用测试舱':['测试舱'],'运动测试仓':['测试舱'],'核心记忆陈列':['记忆陈列'],'记忆档案柜':['档案柜'],'记忆墙':['陈列墙'],'警戒观察位':['观察位'],'情绪切换通道':['内部通道'],'积水面':['积水'],'杂货铺立面':['店铺立面','杂货铺'],'低位检修杂物堆':['检修杂物','杂物堆'],'通用房门':['房门'],'纱布与敷料':['纱布','敷料'],'记录夹板':['记录夹','记录板'],'登记印章':['印章'],'药片':['药物','吞服'],'清洁工具':['清洗','保洁员'],'夹具与固定扣':['夹具'],'单眼电子检查器':['单边眼装饰','电子面板']})
canon=[b for tag in ['S1','S3','体验'] for b in docs[tag]['blocks'] if b['text']]
normalize=lambda t:re.sub(r'[\s/／、·]','',t)
for r in art['rows']:
    r['basis_type']='现行对象/功能要求；具体画法和数量为实现建议'
    if r['category']=='物件分层':
        name=re.split(r'[（(／]',r['name'])[0]
        tokens=synonyms.get(name,[name])
        hits=[b for b in canon if any(normalize(t) in normalize(b['text']) for t in tokens)]
        if hits:
            r['source_details']='\n'.join(b['anchor']+' '+b['text'] for b in hits[:3]);r['source']='；'.join(b['anchor'] for b in hits[:3])
            r['basis_type']='原文对象/事件所需部件；美术分层为实现建议'
        else:
            r['basis_type']='旧表/实现候选，未据此新增原文对象'
            r['pending']='候选形体先复用现有组件；没有现行来源不要求人工另做。保留旧ID与进度供核对。'+r.get('pending','')
            r['method']='候选复用/合绘；不单独新增人工绘制'
        if '候选' in r['name'] or r['id']=='ENV_LAMP':
            r['basis_type']='实现建议（杂物/照明的可选形体），非原文新增必做'
            r['quantity']='0独立新购/新绘要求；可复用/合绘'
for r in audio['rows']:r['basis_type']='原文台本候选，录制另按已有约定' if r['category'] in ['对白','待核台本','台本待核'] else '反馈/氛围需要；声音设计、曲数与时长为实现建议'
for r in art['rows']:
    if r['category']=='肖像':
        parent=next((i for i in by['art'] if re.fullmatch(r'CHR_OTHER_NPCS_(?:FATHER|MOTHER|CAT|DOG|N\d+)',i) and r['id'].startswith(i)),None)
        if r['id'].startswith('CHR_MAIN_PORTRAIT'):parent='CHR_MAIN'
        if parent:r.update(alias_of=parent,quantity='0新增母图；从同身份表情/母图裁切派生',method='Codex裁切与表情层组合，不要求逐张重绘')
    if r['id']=='ENV_SMALL_PROPS_PHOTO':r.update(alias_of='UI_EVIDENCE_FAMILY_PHOTO',quantity='0新增照片内容；同源派生世界小图',method='Codex用家属照片内容加相纸底缩制，人物只画一次')
    if r['id'] in ['SYS_BODY_PREVIEW','UI_BODY_TURN_2D']:r.update(alias_of='CHR_MAIN',quantity='0额外人体母图；复用主角多视图',method='Codex二维视图切换/变形，保留旋转操作')
    spatial={'ENV_ALL_067':'ENV_ROOM_L4_ATRIUM','ENV_ALL_068':'ENV_ROOM_L4_ATRIUM','ENV_ALL_090':'ENV_ROOM_L4_BODY','ENV_ALL_147':'ENV_ROOM_L5_BASAL','ENV_ALL_164':'ENV_ROOM_L5_AMYGDALA','ENV_ALL_179':'ENV_ROOM_L6_NARROW','ENV_ALL_180':'ENV_ROOM_L6_NARROW','ENV_ALL_184':'ENV_ROOM_L6_TWIST','ENV_ALL_185':'ENV_ROOM_L6_TWIST','ENV_ALL_188':'ENV_ROOM_L6_MUTATION'}
    if r['id'] in spatial:r.update(alias_of=spatial[r['id']],quantity='0独立物件新绘；归入对应场景结构/Shader层',method='场景底层/遮挡/Shader组合；不制作额外实体物件',basis_type='原空间构成，旧物件ID保留作层映射，不增加搜寻点或场景')
    if r['id']=='ENV_ALL_149':r.update(alias_of='ENV_ALL_145',quantity='0新增测试舱源图；同舱体组件按状态复用',method='复用测试舱，不因旧表同义名称再画一套')
for g in groups['art']:
    shared=sorted({by['art'][i]['alias_of'] for i in g['children'] if by['art'][i].get('alias_of')})
    if shared:g['shared_assets']=shared

# Source-to-event plan. All major event families; table-based subbranches stay intact.
event_defs=[
 ('OPEN','开场/建档/自述','体验',3,60,'UI时序+分层画面，首次/重播标志；命名与随机ID，取消五选一','ART_STORY_WORLD ART_STORY_PLAYER ART_CHAR_PLAYER AUD_MUSIC_OPEN','按图示次序、动态文本和跳过后一次建档'),
 ('TUTORIAL','左键CRT/右键冰柜/技能教学','体验',60,464,'教程沙盒与正式档分离，实际点击/悬停/提交/成功抵抗；二维旋转多视图+螺旋投影','ART_CODE_UI ART_CHAR_PLAYER ART_ANIM_MAIN AUD_CODE_UI','教程跳过详解、静音可玩、不给正式档重复资源/成就'),
 ('DOG','大黄同步辅助搜寻','S3',39,59,'同一搜寻目标/完成收据；实际找/捡/递钥匙，不暗读隐藏钥匙','ART_NPC_DOG ART_PROP_HAND','与角色同时完成/交付前后打断不双奖励'),
 ('CAT','黑猫占位/受惊/猫狗互殴','S3',60,98,'占点3次边界；真正异常前搜寻对象快照；抓挠接触/伤害/跳窗；组合事件优先','ART_NPC_CAT ART_NPC_DOG AUD_CODE_CREATURE','无效/抵抗不惊猫；-10/-10一次；组合不重复单人效果'),
 ('MOTHER','母亲四分支与食物','S3',99,164,'精神/猫狗/父亲实际同场判分支；走近伸手→交付→食用；返床休息另结算','ART_NPC_MOTHER ART_PROP_HAND','粥/巧克力/糖果唯一归属，赠送不等于吃，父母窗口重查'),
 ('FATHER','父亲带出/抱猫/杀狗/父母崩塌','S3',165,249,'真实抓取拖行与血门；专属清醒/挣脱；两正式觉醒一次，非普通战斗父亲','ART_NPC_FATHER ART_NPC_MOTHER ART_NPC_DOG ART_PROP_HAND','2s准备+1s抓前摇+2s稳转；0.5时速共钟；死亡优先/不隔墙抓'),
 ('BEDROOM_SEARCH','卧室11点/病服和袖口','S3',250,311,'高/中/低搜寻+活动件分层移动；信息阶段保存，钥匙发现和拿取分别','ART_ENV_L1_ROOM ART_PROP_HOME ART_ANIM_MAIN','11候选10目标；中断不奖，搬动物不复位，未看领标不知编号'),
 ('HIDDEN','隐藏Street猎手与E1','S3',312,337,'独立路线/追逐/抓握，真实避让和膝跳，失败按L1复活','ART_ENV_L6_SQUARE ART_NPC_HUNTER ART_STORY_ENDINGS AUD_MUSIC_DANGER','不套L6七段/45人/强化；实际出口E1且不接医院'),
 ('L2_WARD','小病房身份核对/污衣转交','S3',346,371,'床头卡/污衣袋/护士观察与报告分开；身体事实/已知/机构记录独立','ART_ENV_L2_WARD ART_NPC_N07 ART_PROP_STORY','同编号实际读取，污衣搬走不回生'),
 ('L2_TRANSFER','候诊登记与轮椅患者转运','S3',372,460,'手续→同一转运工交接→推行→抓门框/掰手指→离场；观察窗口/文书分账','ART_ENV_L2_LOBBY ART_NPC_N09 ART_NPC_N20 ART_NPC_N03','完整目击才扣SP10；阻挡保留车/人位置，不认离场为死亡'),
 ('L2_EXAM','医生/助手检查针刺与处方','S3',461,523,'邀请仅在合适空档；接近/抓/针刺/样本/处方独立提交，危险记忆持久','ART_ENV_L2_CLINIC ART_NPC_N33 ART_NPC_N34 ART_PROP_HAND','针未接触无伤，处方与抽血分开；持钥匙离开不被新邀请抢目标'),
 ('L2_MED','药师配药/小护士拒服与假记录','S3',524,559,'实际处方交付、取样、领药、吞咽；药片归属/吞服/文书各自状态','ART_ENV_L2_PHARMACY ART_NPC_N21 ART_NPC_N07','没吞药不能实际治疗；拒服或代写不伪造吞服'),
 ('L2_RECORD','档案员/报告/保安抓握','S3',560,590,'报告实体留桌；保安实际收报确认对象、接近抓住拖行后有限释放','ART_ENV_L2_OFFICE ART_NPC_N18 ART_NPC_N42','缺席只结束当次等待不销毁报告；HP-5/SP-10一次、最多6s或送达'),
 ('L2_PATIENT','跨关病人交谈与带离','S3',591,615,'同身份/实际伤痕/知识继承；谈话被医护中断，带离必须实际接触移动','ART_NPC_N41 ART_PROP_STORY','未说完不补台词；被带离不等于死亡，不新增本身分身'),
 ('L3_WARD','护工/束带/病床身份','S3',623,636,'单人病房休息与入床检查分开；束带/观察窗独立状态','ART_ENV_L2_WARD ART_NPC_N02','不继承错误身份，已搬走污衣不重摆'),
 ('L3_REGISTER','登记护士的自行离院记录','S3',637,660,'读取既有记录才质问，亲历与登记并列；不以登记锁通行','ART_ENV_L2_LOBBY ART_NPC_N04','前关未见事件不知情；到二层路径不额外办手续'),
 ('L3_EXAM','精神科医生/助手症状记录','S3',661,699,'陈述→写症状→固定动作；助手与前关不同人，衣物细节只作对应','ART_ENV_L2_CLINIC ART_NPC_N36 ART_NPC_N14','不因记录反造行为；技能中断只保留已发生部分'),
 ('L3_DRUG','治疗药师/给药护士/床位剂量','S3',700,731,'药柜/杯/贴纸/吞服与假记录独立；同护士可跨一二层不复制','ART_ENV_L2_PHARMACY ART_NPC_N28 ART_NPC_N22','编号/剂量只读取实物；受伤食用中断不自动无间隔重试'),
 ('L3_OFFICE','档案员/保安/跨关病人','S3',732,777,'修订记录与实际带离分开；共享保安/病人任务、报告与目标绑定','ART_ENV_L2_OFFICE ART_NPC_N43 ART_NPC_N37 ART_NPC_N41','楼层切换不刷新同身份；未读取不解锁质问'),
 ('L3_NURSING','护士长/病区护士/普通护工','S3',778,823,'护士长接收报告→签发处置→实体交接→护工找人；同护士跨层调度','ART_ENV_L3_CORRIDOR ART_NPC_N05 ART_NPC_N22 ART_NPC_N02','报告等候/错误对象/忙碌/缺席可结束不封找钥匙路线'),
 ('L3_TRANSPORT','二层推床患者与腕带','S3',824,843,'核单/刹车/患者上车/推行/安静室停稳；腕带实际掉落唯一实体','ART_NPC_N23 ART_NPC_N10 ART_PROP_HAND','转运≠治疗/死亡/隔离；缺目标/未接手不得代结算'),
 ('L3_REPORT','术后伤口/告密/带离','S3',844,886,'独处展示伤口→告密者真实进门目击→报告/许可→护工抓握带离','ART_ENV_L3_ACTIVITY ART_NPC_N11 ART_NPC_N44 ART_NPC_N02','先无旁观后进门目击；未见伤口无举报；照片不凭空出现'),
 ('L3_RECORDING','主任删录与病友照读','S3',887,922,'录音实际启停/删段/递纸；发言已听/已录/删掉分账，原撤回句保留','ART_ENV_L3_GROUP ART_NPC_N38 ART_NPC_N24','说停不自动停录；删掉录音不抹亲耳所知；对白间恢复操作'),
 ('L3_ISOLATION','隔离护工/门与关押','S3',923,949,'处置联/目标核对→接近抓住→带入→门实关开始计时→开门；不限制旁观者','ART_ENV_L3_QUIET ART_NPC_N15','非目标可走；中断/离场开门松手；不附伤害恢复，软椅非床'),
 ('L3_RELIC','保洁员/独立死者/遗物','S3',950,969,'实际装袋/交接/清理，标签鞋照各实体，已拿物不能隔空收走','ART_ENV_L3_BATH ART_NPC_N29 ART_STORY_EVIDENCE','清单/遗体/编号核对分开；新死者不偷换活人身份'),
 ('L3_CORNER','角落病友/凭条/护工带离','S3',970,1013,'谈话/出示/读清/取得分阶段，医护到门打断，真实带离到走廊','ART_ENV_L3_DOUBLE ART_NPC_N08 ART_NPC_N41 ART_NPC_N02','角落病友非本身人格；未读清保持未知，半交付有唯一归属'),
 ('L3_WORK','作业督导/夹伤/劳动病友','S3',1014,1059,'有限材料/折盒贴标半成品持久；伸手夹具真实接触，尝试用一次','ART_ENV_L3_WORK ART_NPC_N25 ART_NPC_N30 ART_PROP_HAND','夹空无伤仍占次；夹伤HP-10/SP0，1s内松开；劳动不发搜寻收入'),
 ('L4_ATRIUM','核心/背身人','S3',1060,1077,'实际环路/核心观察；背身转身仍无面，前后同编号；看清才记知识','ART_ENV_L4_ATRIUM ART_NPC_N06','不新增身份/伤害/觉醒，不凭相同编号确认患者'),
 ('L4_MEMORY','缝口人/原件与残页','S3',1078,1097,'真正翻原件→接近捏纸撕拉；纸角/碎片/所有权按实际状态','ART_ENV_L4_MEMORY ART_NPC_N31','已取得不被抽走，已读信息不因撕毁消失；未看清不补'),
 ('L4_VISUAL','蒙眼人与影像遮挡','S3',1098,1117,'真正看片→操作控制台→遮施害者面部；角色面孔叠入不改患者身份','ART_ENV_L4_VISUAL ART_NPC_N39','未操作不遮脸，已看清不忘；不把未发生伤亡做回忆'),
 ('L4_DECISION','复述者/指令与自主来源','S3',1118,1138,'亲眼看到异常→模仿→实际写自主行为；动作来源从开始保留','ART_ENV_L4_DECISION ART_NPC_N45','抵抗/内部感觉不模仿；不为展示两栏补做接受/拒绝'),
 ('L4_BODY','错位肢体/测试台夹手','S3',1139,1163,'手真实进接触区→看向/扳柄/夹闭→复位松手，疼痛灯与无异常记录分开','ART_ENV_L4_BODY ART_NPC_N16','缩手需真的撤出；夹空也占次，不凭技能成功免伤'),
 ('L4_BRIDGE','双头真实/伪造同事件陈述','S3',1164,1182,'同患者同事件两头依次陈述；加载材料与完整听见分别记录','ART_ENV_L4_BRIDGE ART_NPC_N35','无真实死亡/拒服依据不捏造矛盾；半听不完整结算'),
 ('L4_RHYTHM','抽动人/支架拖动','S3',1183,1198,'停脚与支架拖身体分开；角色实际绕行，腕扣属于本人','ART_ENV_L4_RHYTHM ART_NPC_N13','不把腕勒痕变主角伤，普通碰撞不追加伤害'),
 ('L4_INDEX','空面人/姓名标签抽取','S3',1199,1216,'见角色翻原件→走索引位→取标签收衣内→查询变查无此人','ART_ENV_L4_INDEX ART_NPC_N27','标签不复制；角色取消不撤销NPC行动；不删人/钥匙/知识'),
 ('L4_SWITCH','反身人错误指引/回环','S3',1217,1234,'看到指路且未识破才跟随；分岔→桥→索引→原分岔实际移动，辨地纹才识破','ART_ENV_L4_SWITCH ART_NPC_N17','可靠出口路线可拒绝；中断不补走，不改连接/不加觉醒'),
 ('L4_VERIFY','贴面人拦截开门','S3',1235,1258,'开门被看见→接近抬手→按脸→一次SP损失/释放；启动接近即占一次','ART_ENV_L4_VERIFY ART_NPC_N40','抓空仍占次；钥匙/解锁/门开度保留，越界后不追补'),
 ('L4_IDENTITY','双面人/核验同脸不同伤','S3',1259,1284,'两档案/两通过结果/面孔都看清才完成；注销与当前使用并列','ART_ENV_L4_IDENTITY ART_NPC_N19','完整核对SP按存档一次；未核不阻出口，不改真实身份伤痕'),
 ('L5_FIRST','异化皮层10人事件/敌人追击/友方包扎','S3',1285,1408,'复用五房，7敌/3友池；父母实际相遇互攻，大黄实际命中碎裂，包扎完成才恢复','ART_PROP_BRAIN ART_NPC_FATHER ART_NPC_MOTHER ART_NPC_N07','不重播L1崩塌觉醒；跨门追兵同实体，不复制刷新'),
 ('L5_SECOND','白质六人格及推车/反击','S3',1409,1516,'原回路战斗绕行，直线冲撞锁朝向；双头真实受击后有限反击；空面推车实际位移','ART_PROP_BRAIN ART_ANIM_MAIN','冷区/误伤实际来源/中断位置；出口不查击杀/核验'),
 ('L5_DEEP','深部七室/本身人格/冷热区','S3',1517,1579,'丘脑枢纽追逐、门边界与冷区；仅同一本身人格，衣物对照限真正看过细节','ART_ENV_L5_THALAMUS ART_PROP_DEEP ART_NPC_N41','脑干出口→L6，杏仁核非出口；返路可走，不补造回忆'),
 ('L6_ATTEMPT','Street尝试/返回快照/强化','S3',1580,1592,'从L5入口快照重返，45身份固定；七善良者真正被敌致死才强化','ART_PROP_STREET ART_ANIM_MAIN','死亡回L5不重抽旧快照；L5冷区不与Street叠乘'),
 ('L6_EXIT','实际出口/尾声/重开','R1',20,32,'门框过界先伤害死亡仲裁，control_ms阈值E2/E3；E1独立；结局锁一次，结束界面再重开','ART_STORY_ENDINGS AUD_MUSIC_ENDINGS','119999/120000边界，未识破/觉醒/清场仍能过；重播不重结算')]
events=[]
for key,name,tag,start,end,method,assets,test in event_defs:
    events.append({'id':'EV_'+key,'name':name,'source':f'{tag}:P{start}–{end}','method':method,'assets':assets.split(),'validation':test,'status':'待实现或部分实现，见FEATURE_COVERAGE','branches_source':excerpt(tag,start,end) if key.startswith(('L4_','L5_')) else ''})
for npc in npcs:
    events.append({'id':f'EV_STREET_{npc["number"]:02}','name':npc['name']+' Street行为','source':npc['source'],'method':'按原文行为，准备/接近/接触/结束分阶段；稳定身份跨场景；实际动作决定结果','assets':[npc['group_id'],'ART_PROP_STREET'],'validation':'逐分支核对未触发/成功/抓空/中断/死亡/离场/往返/存读档；中立不擅加攻击，友方不擅加治疗','status':'待实现','branches_source':npc['street_event']})

systems=[
 ('SYS_AI','自主探索/战斗避险','S2:P11–24/68–82；S4:T6–9/24–26','目标锁定、导航/门/站位、公开观测评分；无资源不取消自主逃离','已有L1/L2搜索，NPC与战斗避险待实现','无输入/缺人/低资源/受阻能继续，不偷看钥匙'),
 ('SYS_SKILLS','十二神经技能/成长/应急重连','S2:T7–19；S4:T3/14；R1:T2','数据化12技能/前置/余额/强度严格大于抗性；升级只加强度，菜单提交原子化','SKIN部分已实现，11项及完整UI待实现','有效失败扣费/CD；无效不扣；3次实际反应登记下一休息提交；完全掌控另计'),
 ('SYS_ACTIONS','行动/归属/抓握/攻击','S3:P16–34；S4:P175–206/T17–23','共享动作时钟、距离/方向/LOS/部位检查；唯一物主/抓握者/完成收据','卧室隔离交互有旧证据，全NPC待接','接触前/后打断、暂停、旧回调/读档重放不重奖伤治；0.8s可行动抓握间隔'),
 ('SYS_LIFE','周目/休息/复活/跨关','S2:T2–4；S4:T24–27','总周目休息+1、死复活+3；同关实际尝试+1；只实际复活编号+1，NPC/RNG按边界刷新','实际返床/新尝试部分已接，死亡和跨后关待接','普通换房不加周目/不重抽/不交抗性；前三关指定床，L4起无休息'),
 ('SYS_GROWTH','性格/觉醒/第四面墙','S2:P25–42；S3:T59；S4:P29–39','独立状态与证据账；两正式觉醒/事件人格成长，未感知不发证据','待实现','同事件只进一级、存档一次觉醒；怀疑/识破/冷血/失我不互相替代'),
 ('SYS_CONTROL','合法掌控/失我','S2:P68–82/T14–15；R1:P12–19','成功6s窗口与control_ms拆开，方向/接触输入只在合法掌控；30/60/120s表现','待实现','暂停/抓住/硬直/失神时间不计失我；站立可计时但不解锁实际动作成就'),
 ('SYS_KNOWLEDGE','三类书签/事实账/机构伪造','R1:P39–42；S1:P9；S3:P16–34','人物/物品/角色，亲历/纸面/说法并列，未知不预填；已知免费，可选扩展5C','三槽基础已有，全事件和图书待接','读到!=拿到!=用过；全局档不把知识灌入新档'),
 ('SYS_ACHIEVEMENTS','十二全局成就','R1:T6/P43–49','独立全局档，只增不减，无资源奖，多项可同事件','待实现','新档/读档/重播不会减成就/重复奖励，正文事件先成立'),
 ('SYS_SAVE','存读档/备份/恢复','S4:T27；第五阶段R17–18；本次完整功能目标','Godot JSON快照校验+备份，原子节点保存，实例代际拒旧回调；扩展schema与迁移策略','已有单档/校验备份和L1/L2动作保存；全NPC/战斗/结局待测','动作半程/物权/半成品/RNG/待播/暂态/跨层追兵/Street入口/三主体状态往返'),
 ('SYS_SETTINGS','菜单/设置/摄像机','体验:P14–19；R1:P34–38；用户镜头指令','代码UI统一主题，音量独立总/音乐/音效，降震/闪/虚化，0.8–1.3缩放复位','标题建档/继续/主音量部分已有，其余待接','菜单滚动不动镜头；静音教程可玩；中文/英文/颜文字/乱码字体'),
 ('SYS_TIME','世界/界面/对白语音/效果暂停','S2:T21；S4:P246；用户反馈要求','统一世界游戏时钟，UI独立；正式对白冻世界但语音可续，手动/菜单再暂停语音；关屏点击隔离','基础分通道已有，正式听验待素材','速度/冷却/失我/抓握/伤害同钟；UI动画不推进逻辑；恢复不突播过时音'),
 ('SYS_PRESENT','可替换美术与音效映射','本次指令；现有presentation/audio_bindings','稳定ID→贴图/clip/锚点/声音与参数；表现只读动作阶段，不重写玩法','主角/活动柜A/B替换有历史GPU证据','不兼容规格报错；换资源前后玩法快照不变；视觉事件与规则时点一致'),
 ('SYS_EXPORT','目标平台与完整验收','本次完整游戏目标；现有Windows preset','尽早小包Windows导出，再逐关/全分支回归；无导出模板先记录阻塞','历史PCK成功，EXE缺4.7.2模板；本轮未运行','干净接手机导入、EXE启动/保存权限/中文/静音/全屏缩放；未测不写通过')]

# Complete source-linked dialogue cues, including table alternatives omitted by old VO table.
cues=[]
for tag in ['S2','S3','R1']:
    for b in docs[tag]['blocks']:
        if 'table' in b:
            head=b['table'][0]
            cols=[i for i,h in enumerate(head) if '对白' in h or ('左头' in h or '右头' in h)]
            for ri,row in enumerate(b['table'][1:],2):
                for ci in cols:
                    if ci<len(row):cues.append({'id':f'CUE_{tag}_{b["anchor"].split(":")[1]}R{ri}C{ci+1}','source':b['anchor']+f'R{ri}','scene':row[0],'speaker':head[ci],'text':row[ci],'kind':'现行原文，按表头双方/随机备选解析，不新增录制任务'})
        elif re.search(r'[“”]',b['text']) and re.search(r'角色|玩家|[\[【].*[\]】]|对白|原句|原文',b['text']):
            scene=tag+'共用规则'
            for e in events:
                m=re.fullmatch(re.escape(tag)+r':P(\d+)–(\d+)',e['source'])
                if m and int(m[1])<=b['p']<=int(m[2]):scene=e['name'];break
            cues.append({'id':f'CUE_{tag}_P{b["p"]}','source':b['anchor'],'scene':scene,'speaker':'按原文说话人/情绪标签','text':b['text'],'kind':'原文语境，含纸面引文的不能自动配音'})
for b in docs['体验']['blocks']:
    if re.search(r'对话框\d*[：:]|字幕[：:]|据资料我是|我叫_',b['text']):cues.append({'id':f'CUE_EXP_P{b["p"]}','source':b['anchor'],'scene':'开场/教程','speaker':'按原文标签','text':b['text'],'kind':'图文原句；与现行规则冲突的教学说明按明确修订覆盖，原句保留供核对'})
dump(DATA/'dialogue_cues.json',{'schema_version':1,'note':'台本核对，不是全量配音订单。/随机备选、&同框保留；纸面记载不自动念白。','cues':cues})

room_index=[{'id':key,'name':name,'source':f'S1:P{start}–{end}','asset_group':'ART_ENV_'+key,'batch':batch} for key,name,start,end,batch in rooms]
skills=[]
for b in docs['S2']['blocks']:
    if b['anchor']=='S2:T12':
        names=['SKIN','GUT','PORES','TEMP','TINNITUS','DRYMOUTH','KNEE','WITHDRAW','STARTLE','FEAR','JOY','CONTROL']
        skills=[{'id':'SKILL_'+names[i-1],'source':'S2:T12R'+str(i+1)+'；S4:T14对应行定值优先；CONTROL按R1','source_text':' | '.join(row),'method':'共用关键姿态+局部变形/Shader；真实效果按模式分支，解锁/升级/抵抗由规则处理','asset_groups':['ART_ANIM_MAIN','ART_CODE_UI','AUD_CODE_BODY'],'validation':'探索/战斗分别验证成功/抵抗/无效/前置/扣费/CD/中断/读档；不得仅播动画'} for i,row in enumerate(b['table'][1:],1)]
plan={'schema_version':1,'scope':'本轮仅规划与表单，交付后停止；完整游戏范围未缩减','sources':[{k:v for k,v in d.items() if k!='blocks'} for d in docs.values()],
 'batches':[
 {'id':'B0','name':'接手/依赖与交付合同','depends':[],'work':'核分支/快照；固定规格与映射，做完整覆盖矩阵；本轮完成后停工'},
 {'id':'B1','name':'共用系统与首关','depends':['B0'],'work':'后续制作轮：CRT/冰柜/书/存档/时钟/全部技能数据；完整教程、卧室11点和四人物分支；主角/活动柜替换回归'},
 {'id':'B2','name':'正式开场/医院/隐藏分支','depends':['B1'],'work':'十身份与转运/处方/用药/报告/带离；独立猎手路线到E1，分支可玩；优先Windows EXE导出'},
 {'id':'B3','name':'精神病院全两层','depends':['B2'],'work':'五同构房+八二层房、21身份/45候选14目标；举报/隔离/删录/遗物/角落/作业互斥并发'},
 {'id':'B4','name':'脑皮层/白质探索','depends':['B3'],'work':'11房/62候选16目标、补查、六人格与五房身份、唯一钥匙和二层实际出口'},
 {'id':'B5','name':'异化战斗与深部追逐','depends':['B4'],'work':'复用11房+深部7室、10人首层/6人格二层/唯一主体深部，跨门追踪/冷区/包扎/本身抓握'},
 {'id':'B6','name':'Street/全部结局/全局成长','depends':['B5'],'work':'七段固定45身份/7善良资格，L5返程快照；control_ms/三结局/尾声/12成就/重开整合'},
 {'id':'B7','name':'全分支验收与交接导出','depends':['B6'],'work':'正常玩与不利路线、全交付资源替换、跨层保存/声音暂停/目标Windows双机/分支矩阵；不把主线一次走通算全覆盖'}],
 'systems':[dict(zip(['id','name','source','method','current','validation'],s)) for s in systems], 'rooms':room_index,'events':events,'skills':skills,'identities':npcs,
 'graphs':{'L2':'候诊区↔病房/诊室/药房/办公室；病房无钥匙点，楼梯接L3','L3':'一层继承L2五室/门位；接待↔楼梯↔二层走廊；走廊↔其余六室，楼梯上端持钥匙→L4；可下楼返床','L4_L5':'中庭↔记忆/视觉/决策/身体；视觉↔记忆；决策后端↔胼胝桥；桥↔索引↔分岔↔核验；桥↔节律↔身份↔核验；分岔↔桥；L4核验持钥匙→L5中庭，L5核验无钥匙→海马','L5_DEEP':'海马↔丘脑↔其余六室；杏仁核↔小脑，基底核↔下丘脑；脑干出口→L6；杏仁核内警戒/安抚两室仍属同一场景包','L6':'广场→窄道→街道→节点→出口；侧室接广场/窄道交界，维护接街道/节点交界，两个单口原路返；不增商店内场景','HIDDEN':'卧室父亲血门→广场片段→独立出口E1；失败按L1复活，非L6'},
 'open_items':[
 {'id':'Q_ART_STYLE','topic':'主角发型/年龄、新小怪物母图、统一风格未最终确认','decision':'保持已确认帅气瘦弱男/浅蓝睡衣；新怪物整体重设。先画候选母图及无争议分层结构，不批量派生。','impact':'不阻塞规划；正式角色批量图等待设计确认'},
 {'id':'Q_VOICE','topic':'仓库没有完整正式配音约定/授权登记','decision':'既有候选按角色/场景保留；新抽取台本只作文本，不增加人工录制。默认人工任务仅美术和音乐。','impact':'录制前一次集中确定角色/场景范围；文字完整功能不依赖配音'},
 {'id':'Q_OUTFIT','topic':'Doctor早期衣装按总周目列表，后续复活+3可能跳过阶段且列表有上界','decision':'保留原总周目阈值，跳过未经历状态不补演；超表范围沿该场景最后已规定状态，不无限加血。新关初次衣装按明确初次解锁描述；不改变周目/因果。','impact':'最小必要显示建议，制作只交明确状态层；如创作方另有后段外观再定向补'},
 {'id':'Q_HOST','topic':'现实宿主具体面貌与借用人形是否完全同脸尚无充分图示定稿','decision':'先规划共享病床底景/眼手与视点差异，避免擅造两个新人物；尾声正式绘制前确认。','impact':'仅影响尾声近景，不改三主体事实或结局条件'},
 {'id':'Q_EXPORT','topic':'当前Windows4.7.2导出模板缺失','decision':'后续制作轮安装匹配官方免费模板后尽早导出测试；本轮不安装、不运行、不宣称EXE通过','impact':'技术待办，非新增费用；其他目标平台尚无约定'}]}
assert len(skills)==12,len(skills)
# A source-driven point inventory is independent of the inherited asset table.
point_tables={4:'L1',11:'L2',16:'L2',29:'L3',34:'L3',35:'L4',36:'L4',37:'L4',38:'L4',39:'L4',41:'L4',42:'L4',43:'L4',44:'L4',45:'L4',46:'L4'}
points=[]
for b in docs['S3']['blocks']:
    if 'table' not in b:continue
    number=int(b['anchor'].split('T')[1])
    if number not in point_tables:continue
    for ri,row in enumerate(b['table'][1:],2):
        points.append({'id':f'POINT_S3_T{number}R{ri}','level':point_tables[number],'source':b['anchor']+f'R{ri}','name':row[0],'action':row[1] if len(row)>1 else row[0],'dialogue':row[2:] if len(row)>2 else [],'method':'高/中/低通用搜寻配合该家具实际开合/挪动；准备/接触/翻查/收势，不能一挥手代表全流程','validation':'到达/开始占次/中断不奖/完成一次收入/有钥匙不播无钥匙句；保存开度/位置/所有权'})
assert collections.Counter(p['level'] for p in points)=={'L1':11,'L2':32,'L3':45,'L4':62}
plan['search_points']=points
plan['rule_tables']=[b for tag in ['S2','S4','R1'] for b in docs[tag]['blocks'] if 'table' in b]
plan['asset_group_index']=[{'id':g['id'],'name':g['name'],'owner':g['owner'],'batch':g['batch'],'children':g['children']} for kind in ['art','audio'] for g in groups[kind]]
dump(DATA/'production_plan.json',plan)

for kind,payload in [('art',art),('audio',audio)]:
    assert assigned[kind]==by[kind].keys(),assigned[kind]^by[kind].keys()
    payload.update(schema_version=3,revision='planning-only-20261015',groups=groups[kind],common_specs=COMMON,progress_schema=2,
        instructions='默认只显示我们负责的主要美术/音乐；Codex和配音候选折叠。子ID不删除，填写进度导出/连接data/progress.json。',
        dialogue_cues=cues if kind=='audio' else [],source_plan='data/production_plan.json')
    dump(DATA/f'{kind}_requirements.json',payload)
    template=(ROOT/'tools/planning_form_template.html').read_text('utf-8')
    encoded=json.dumps(payload,ensure_ascii=False).replace('</','<\\/')
    progress_encoded=json.dumps(progress,ensure_ascii=False).replace('</','<\\/')
    html=template.replace('__TITLE__','全游戏美术交付表' if kind=='art' else '全游戏音乐与台本表').replace('__DATA__',encoded).replace('__PROGRESS__',progress_encoded)
    (OUT/('01_全游戏提示词表单.html' if kind=='art' else '01_音频需求表.html')).write_text(html,encoding='utf-8')
dump(DATA/'planning_coverage.json',{'art':{'records':len(art['rows']),'groups':len(groups['art']),'human_groups':sum(g['owner']=='我们' for g in groups['art'])},'audio':{'records':len(audio['rows']),'groups':len(groups['audio']),'human_groups':sum(g['owner']=='我们' for g in groups['audio'])},'rooms_base_packs':len(rooms),'search_points':dict(collections.Counter(p['level'] for p in points)),'identities_street':len(npcs),'event_families_including_street':len(events),'systems':len(systems),'skills':len(skills),'source_dialogue_cues':len(cues),'old_ids_preserved':True,'unassigned_ids':[]})
migration=json.loads((HISTORY/'data/id_migration.json').read_text('utf-8'))
if isinstance(migration,dict):
    migration['planning_groups']={kind:{r['id']:r['group_id'] for r in payload['rows']} for kind,payload in [('art',art),('audio',audio)]}
    migration['canonical_reuse']={r['id']:r['alias_of'] for r in art['rows'] if r.get('alias_of')}
    migration['note_planning']='所有原子ID保留；交付包是分组引用，不重命名原进度ID；组ID另存进度。'
    dump(DATA/'id_migration.json',migration)
# One concise production document, with detailed traceability in the same file.
md=['# 全游戏制作规划 · 2026-10-15\n',
 '本轮仅规划、两份表单及交接；**交付后停止，等待下一轮制作指令**。不修改游戏运行代码/场景/正式音画，不运行引擎。本计划保留全部已确认内容，后续按依赖制作，不以占位或一条主线替代分支。\n',
 '当前仓库同一Godot工程 `neurons/project.godot`；main，HEAD与本地origin/main同为 `9d50abe3680ca875af37d455f3ae81ad54ef3cd4`。本轮开始已有未提交改动；未Fetch/Pull，不声称远端实时同步。已有结果见 [功能覆盖](FEATURE_COVERAGE.md)，本轮没有新增游戏通过项。\n',
 '## 制作顺序与依赖\n',
 '|批次|依赖|可玩交付与边界（后续轮执行）|\n|---|---|---|']
for b in plan['batches']:md.append(f'|{b["id"]} {b["name"]}|{", ".join(b["depends"]) or "无"}|{b["work"]}|')
md += ['\n## 分工与交付选择\n',
 '我们：主要场景/人物、真正改变轮廓或叙事的专属关键姿态/插图、配乐。Codex：全部UI、统一主题与图标、通用二维动效、基础Shader、材质音效组、合成加工/许可免费复用、切帧量锚/导入/验证。未约定的正式配音不扩大人工录制；候选与原台本仍完整保留。\n',
 '场景用完整墙地+固定远景+前景遮挡，活动家具/人物/物品独立。主角与NPC使用母图、衣装/异化差异层和通用动作；只有醒来、踢腿、扑抓、肉体变形等必要轮廓用专属关键姿态。门柜/搜寻/递物用图层位移、伸手锚点与真实接触节点。UI完全代码绘制；旋转人体复用4向视图/变形，星环用二维投影；CRT/冷气/血迹/灰暗/移轴为参数化效果，不更改玩法。\n',
 '医院与精神病院一层共五房型，第四/五关共十一房型：新图只画状态差异。深部七房与Street七段独立；隐藏Street取广场片段独立出口。39个基础房型包覆盖55个常规场景实例，另有独立隐藏片段；教程复用卧室。固定不动小物可合绘，移动件必须可露底。\n',
 '恐怖随原事件/周目加深：开场日常温度→医护伤害与记录矛盾→脑内肉体/血污/邪典异化→Street身份碰撞。低噪点只为动作/目标可读，不等于全程温和。血污衣装按原描述，实际新伤与失我不互相替代。候选v005未批准，小怪物v001被否决。\n',
 '## 可执行规格与资源合同\n']
for key in ['WORLD','ACTOR','UI_CHAR','PROP','STORY','MUSIC','VOICE']:
    spec=COMMON[key];md+=['### '+key+' · '+spec['name']+'\n',spec['spec']+'\n',spec['delivery']+'\n']
md += ['角色基础关键姿态/帧时详见表单 `ART_ANIM_MAIN`；每个NPC包写实际方向、循环、接触时刻与锚点。素材沿稳定子ID映射贴图/clip/表现参数，逻辑ID/物权/碰撞/触发不随美术重写。当前主角图集与活动柜已有替换证据；任意图片不承诺免调。后续改尺寸先提供兼容报告，不能静默缩放。\n',
 '血迹/伤口遮罩只读实际伤害与衣装状态；不可控世界时钟、UI动画、对白语音、效果时间独立。正式对白冻结世界；语音可续，手动/菜单暂停语音；关屏点击隔离。停帧/慢动作必须使用同一规则时钟。\n',
 '## 空间连接与数量\n']
for k,v in plan['graphs'].items():md.append(f'- {k}：{v}')
md += ['\n候选点：L1 11抽10/基准4s；L2 32抽12/5s；L3一层0、二层45抽14/6s；L4 62抽16/7s且耗尽可补查；L5/L6/隐藏无搜钥匙。150点逐点实际动作/原对白/验证在 [规划JSON](../deliverables/NEURONS_2D_资产需求_20261015/data/production_plan.json) 的 `search_points`，完整阶段参数在 `rule_tables`。同次取消/换房/读档不重抽，钥匙唯一；命名/编号/复活与总周目分开。\n',
 '## 系统对应与当前缺口\n',
 '|功能|文档依据|实现方式|当前结果|验证方法|\n|---|---|---|---|---|']
for s in plan['systems']:md.append('|'+ '|'.join(s[k].replace('|','／') for k in ['name','source','method','current','validation'])+'|')
md += ['\n## 场景/事件 → 实现 → 资产 → 验证\n',
 '下表按事件族展开；每族包括原文前提、成功/失败/中断/缺席/已知条件，不能只做成功动画。Street45人各有独立行。详细人物行为与需要原句在规划JSON/音频台本，书面引文不等于配音任务。\n',
 '|事件ID / 功能|依据|实现与分支|交付包ID|验证|\n|---|---|---|---|---|']
for e in events:md.append('|'+ ' | '.join([e['id']+' '+e['name'],e['source'],e['method'],', '.join(e['assets']),e['validation']]).replace('\n',' ')+'|')
md+=['\n## 待确认与最小方案\n','文档有依据直接遵从；明确替换只覆盖相应条款。以下是显示/生产缺口，不改核心创作。\n','|项|处理/依据|影响|\n|---|---|---|']
for q in plan['open_items']:md.append(f'|{q["id"]} {q["topic"]}|{q["decision"]}|{q["impact"]}|')
md+=['\n## 验收与停止条件\n',
 '后续每批按规则测试→真实Godot画面/声音→正常与不利操作→存读档/跨关→Windows导出验证。角色可自主通行，敌人不封死所有路径；攻击最多2人占位、起手间隔0.8s，单抓握且恢复可行动0.8s才新抓，误伤不提供无敌。事实/所知/伪记录分别保存；生命0优先于治疗/出口；一次性完成收据、读档代际与素材替换都要验证。\n',
 '全分支至少覆盖：L1全部猫狗/父母/食物组合，医院原稿10身份流程与缺席/拒服/报告等待，L3 21身份与举报/删录/隔离/遗物/作业并发，L4十一独立人物事件及原路回环，L5十八房与各追兵/友方/冷区，L6固定45人及7善良资格，12技能两模式/抗性/成长，E1/E2/E3含119999/120000ms、未识破/未觉醒路线和死亡同节点，重开/全局12成就/静音教程。当前未实现/未测绝不因列入表而变已完成。\n',
 '本轮交付仅验证表单浏览器行为、ID/引用/源文件与规划覆盖；不运行Godot，不增加游戏验收结论。Git提交由用户操作。下一轮接手先读HANDOFF，收到制作指令后才执行B1。\n']
(ROOT/'docs/PRODUCTION_PLAN.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
print(json.dumps(json.loads((DATA/'planning_coverage.json').read_text('utf-8')),ensure_ascii=False))
