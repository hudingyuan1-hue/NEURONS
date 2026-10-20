"""Patch frozen forms for user-generated UI layers; never rescan or write game assets."""
from pathlib import Path
from datetime import datetime
import base64, copy, hashlib, importlib.util, io, json, re, shutil, sys, zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables/comprehensive_forms_20261019'
DESKTOP=Path('C:/Users/23623/Desktop/NEW/最终表单')
sys.path.insert(0,str(ROOT/'tools'))
import build_comprehensive_forms_20261019 as builder
PAGE=builder.PAGE; UI_PAGE=builder.UI_PAGE
STYLE=('沿所附已认可房间画法提取低饱和灰紫、石墨蓝绿、旧木褐与少量冷暖色块；'
       '采用克制的手绘油彩/水粉块面，边缘有选择地虚实变化，暗部保持整体。'
       '借《极乐迪斯科》的绘画笔触与信息层级、《死亡之门》的轮廓清晰度；'
       '不复制原作角色、版式或标志。材质转折处可见笔触，正文区域安静低纹理。'
       '不是奶油色办公后台、塑料拟物手游、霓虹科幻面板或均匀颗粒滤镜；无镜头光晕、过曝发光、夸张金边。')
FIRST=('为《NEURONS》制作供真实游戏界面组装的二维美术图层。'+STYLE+'\n\n'
       '每次只制作当前条目指定的一张：不是完整游戏截图，不把多个方案、多个状态或多个图标拼成联系表。'
       '附图1只供画法、颜色与材质参考，不继承卧室房型、家具、光束或斜俯视机位；'
       '若附图2是功能分区图，它只规定功能位置、留空与可裁切边缘，不沿用方框线、配色或注释。'
       'UI正对屏幕，保持平面阅读；仅CRT机壳和冰柜自身可有轻微体积。\n\n'
       '中文、数字、技能名、费用、字幕、按钮文字全部由程序排版，图中不写字、不画假字。'
       '外部透明按本项要求输出真alpha，不画棋盘格；需要显示游戏的中空区域也保持透明。'
       '程序负责点击、滚动、焦点、灰显、选中、进度填充、粒子、淡入淡出与打字效果，'
       '无需逐状态重复画图。既有已认可小怪物/人物/叙事图继续使用，不在UI底图中重画或烘焙。'
       '开场字幕直接叠画面，不套对白框；正常对白框另做。按本项画布和留空规格交PNG原图。')

def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def dump(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def base_id(k):return 'UI_DESIGN_'+k
def prompt(subject,canvas,body,alpha,slicing):
 return f'为《NEURONS》只画一张「{subject}」美术图层。\n\n{STYLE}\n\n{body}\n\n画布：{canvas}。\n透明与图层：{alpha}\n留空与切片：{slicing}\n所有中文、数字、字幕、按钮标签与可变信息由游戏程序添加，图中无可读文字和假字；不画鼠标、选中光圈、角色或完整游戏截图。功能分区图只规定使用位置和留空，不把它的矩形框和注释当最终画法。'

# Seven shared image layers, not 38 flattened interface screenshots.
ORDERS={
 'FOUNDATION':dict(title='共用暗墨面板母版',size='1536×1024 PNG，正视平面',
  body='一块深石墨蓝灰的旧纤维纸/涂绘板面，轮廓近矩形但边缘略有手工切边的自然起伏；四角轻微磨损不破碎，细窄铜锈灰边线，边沿少量干笔。中心是清洁沉静的深灰蓝低纹理面，能承载暖灰白正文。暗处不漆黑死板，局部极轻灰紫过渡。整体像严肃叙事游戏的信息载体，不像网页卡片、卷轴或厚相框。',
  alpha='主体外透明；中央为不透明、低纹理的暗色阅读面，不挖空。',
  slicing='四周96px作为可保留边角，中间96,96至1440,928可拉伸/平铺；边角不放不可裁切花纹。Codex据PNG提取9-slice，主辅色从此图统一。',guide='panel'),
 'HUD_VITALITY':dict(title='HP/SP共用细长状态轨道',size='1536×384 PNG，仅一条轨道',
  body='一条横向细长、冷灰蓝的状态槽，边缘细窄并有少量手绘磨损，像旧仪器印刷刻度的简洁线条；中央为干净的深暗轨道，两端有很小的方切口用于定位。只画空轨道，不画两条、不画心脏大徽章、不画红蓝填充，不加文字和数字。缩到游戏左上角仍能辨认，装饰不厚重。',
  alpha='轨道外透明，轨道内为深暗不透明；程序另绘HP/SP填充和损伤差值。',
  slicing='主体控制在x48–1488、y120–264，左右端各144px保留，中段可横拉；上下留透明安全边。由同图复用两条，不生成每个数值状态。',guide='vitality'),
 'CRT_SHELL':dict(title='老式神经终端CRT机壳',size='1024×1024 PNG，主体完整',
  body='一台老式桌面CRT显示器的独立机壳，近正视略见顶面和右侧厚度，低饱和灰绿金属与陈旧米灰塑料混合，少量使用磨痕与散热开槽，边缘厚薄可信。显示窗口占机壳正面大部分，圆角极轻、屏幕微凸，窗口内部纯净近黑蓝绿。下沿可有简洁旋钮和电源点，不画键盘，不画节点图、代码或文字。不要画巨大的破败工业装置，不把屏幕做成斜向强透视。',
  alpha='整台机壳外透明；屏幕内为干净近黑面，不烘焙玻璃反射/光束/屏幕文字。',
  slicing='机壳全部保留；期望屏幕内安全区约x145–855、y150–730，实际图由Codex量取并映射。仅界面左侧放此电脑，右侧程序显示复古代码式说明，不把右栏做进机壳。',guide='crt'),
 'TREE_SHELL':dict(title='底部星仓/冰柜主体',size='1536×640 PNG，横向独立物件',
  body='一只叙事游戏里的旧式低矮星仓，外形接近卧式冷藏柜而非墙面大机柜；冷灰蓝搪瓷、磨钝的金属护边，顶口有克制的浅冰霜，开口是可容纳投影的暗色内腔。正面少量铜锈和清楚的薄轮廓，不画夸张门柱、法阵或蓝色魔法水晶。独立柜体近正视略见顶部，姿态稳重。左上有一块小型无字电子读数面；右上留关闭控件的小空面，不烘焙按钮和字。',
  alpha='柜体外透明；顶口暗色实体内腔保留。冰雾、粒子、人体与星环全部另层由程序/既有素材接入。',
  slicing='柜体约占x64–1472、y240–592；上方y0–220保透明，避免遮住人体和星树。整体出现在屏幕底部，左人体右螺旋技能树是独立功能层，不能画在柜体上。',guide='tree'),
 'BOOK_SHELL':dict(title='资料书册展开底图',size='1536×1024 PNG，正视平面展开',
  body='一册被长期翻阅的薄旧资料夹/装订书摊开，深灰紫旧布封皮只在外沿窄窄露出，内页为压低明度的灰褐纸，不是亮奶油色。中缝微暗，页角轻微磨软，页边少量手写式干笔痕但不能形成字。左页偏窄负责分类与目录，右页宽负责档案/人物/证据内容。正文区域保持清楚平整，没有装饰贴纸、剪报照片、格子或一排排假字。',
  alpha='书册外透明；纸页实体不透明。已认可照片/人物来源图独立放置，底图中不画人和证据。',
  slicing='安全阅读区：左页x128–544、y128–896；右页x672–1408、y128–896。中缝x592–656不放正文。整书不做9-slice，仅按屏幕比例缩放，超长内容真实滚动。',guide='book'),
 'DIALOGUE':dict(title='下方三分之一对白框',size='1536×512 PNG，横向独立层',
  body='一块低矮横向的叙事对白框，深石墨蓝灰底，带灰紫和铜锈的细窄手绘边。边缘有自然干笔收束与轻微不对称，整体平稳克制；中部阅读面暗而干净，不铺满油画噪点。框体融入已认可场景的阴影和材质，不能做成厚黑漫画斜框、霓虹描边、聊天气泡或明亮纸张。只画空框与细分隔线，角色、姓名、自动播放和快进都不画入。',
  alpha='框体以外透明；正文阅读底为稳定暗色，透明度由程序统一控制。小怪物为独立已认可角色层，不画在框上。',
  slicing='框体显示约屏幕下1/3；左侧约23%宽（x42–392）预留独立玩家怪物完整站立区，脚落于框下缘，不能改成右上角头像；角色可自然探出框上沿，不要求画人物槽边框。正文在右侧x432–1296、y112–400；姓名位x432–1120、y48–96；右端x1320–1464预留自动/快进/继续。人物与文字不得互压。边角80px保留，可由Codex横向9-slice。',guide='dialogue'),
 'BUTTONS':dict(title='共用空白按钮底片',size='1024×256 PNG，只画一个按钮',
  body='一枚横向简洁的叙事游戏按钮空底片，细窄石墨灰轮廓，内部为略深灰紫涂绘面，短边是清楚轻微手切的直角。只在左右边沿有极少铜锈灰干笔，中心一大片低纹理清洁区域留给程序文字。无胶囊圆角、塑料高光、3D斜面、大金边或图标。画正常状态一个按钮，其他状态由程序换色、边线与位移处理。',
  alpha='按钮外透明，按钮内为低纹理实体暗面；无文字。',
  slicing='主体x32–992、y40–216；左右端96px保留，中部可横拉；文字安全区x144–880、y72–184。只生成一张，程序产生悬停/按下/禁用/焦点状态。',guide='button')
}

# The remaining functions reuse those layers. All IDs remain to preserve progress.
REUSE={
 'ATTEMPT_FEEDBACK':('程序效果',['FOUNDATION'],'休息、死亡、新尝试与Street返程仅在真实事件发生时显示短标题/遮幕；不猜测复活时机。'),
 'TITLE':('已有来源',['BUTTONS'],'已认可空房BASE可取门墙局部作标题气氛背景；标题NEURONS及继续/新档/设置/退出由程序排版。'),
 'PROFILE':('复用母版',['FOUNDATION','BUTTONS'],'姓名、随机ID、输入验证与确认/取消由程序排版。已有已认可小怪物沿原ID显示，不恢复文档旧五选形象。'),
 'SAVE_CONFIRM':('复用母版',['FOUNDATION','BUTTONS'],'存档槽、覆盖/取消、实际失败原因、成功反馈由程序显示；不画死文件名和时间。'),
 'PAUSE':('复用母版',['FOUNDATION','BUTTONS'],'继续、保存、读取、设置、存档回标题及可用状态由真实控件实现。'),
 'SETTINGS':('复用母版',['FOUNDATION','BUTTONS'],'音量、音效、UI停留/自动调出等设置用真实滑条/开关；不把数值烘焙进图。'),
 'HUD_RESOURCES':('程序效果',[],'资源、身份与章节用轻量印刷式文字/小图标；只保留实际可见字段，不永久堆满屏幕。'),
 'HUD_SEARCH':('程序效果',['HUD_VITALITY'],'搜寻、观察与活动的轨道复用；进度、当前对象、完成/取消由程序更新。'),
 'HUD_CONTROL':('程序效果',['HUD_VITALITY'],'掌控持续、夹具/追逐/战斗提示复用细轨道；危险必须同时有文字/轮廓区别，不新增血腥画面。'),
 'VIEW_TOOLS':('程序效果',[],'缩放/视野操作控件使用矢量小图标和真实热区；按当前功能，不另画全屏面板。'),
 'CRT_DESCRIPTION':('程序效果',['FOUNDATION','CRT_SHELL'],'保留左电脑右代码区域；右栏真实打印技能名、费用、效果与反馈，无悬停时保持空白。语言样式变化不能改技能事实。'),
 'DIRECTION_PICKER':('程序效果',['BUTTONS'],'方向候选/取消用同款按钮与清晰矢量箭头；仅合法方向可选，键盘焦点不能仅靠颜色。'),
 'CAST_FEEDBACK':('复用母版',['FOUNDATION'],'成功/抵抗/不可用/取消用程序文字与有限标记；不得用同一张成功贴图替代真实结算。'),
 'BODY_PREVIEW':('已有来源',[],'复用主角同一套服装正式四向/动作；独立预览时钟与旋转，菜单冻结世界。不另生成T姿整图或12张伤害海报，不用未就绪姿态冒充完成。'),
 'TREE_SPIRAL':('程序效果',['SKILL_ICONS'],'右侧螺旋星环节点和前置连线由程序绘制/旋转；图标来自12节点，亮/灰/选中依真实解锁，不烘焙成一张树图。'),
 'TREE_INSPECT':('复用母版',['FOUNDATION','BUTTONS'],'右侧电子说明面板保留小怪物单独出场区域；技能详情、前置、费用、解锁/返回由程序显示，不画雷达战力图。'),
 'TREE_EXCHANGE':('复用母版',['FOUNDATION','BUTTONS'],'兑换、应急重连、资源不足/成功/禁用只用程序真实值；不新增付费按钮或商店。'),
 'BOOK_EVIDENCE':('已有来源',['BOOK_SHELL'],'照片、作品、已认可人物画像按真实来源ID独立显示；亲历事实/他人说法/机构记录分清来源，不补造身份。'),
 'BOOK_DETAILS':('复用母版',['BOOK_SHELL','BUTTONS'],'抗性、物品、人物参数的未解锁/费用/已解锁内容用真实数据；已见名单/长文滚动由程序排版。'),
 'INVENTORY':('复用母版',['BOOK_SHELL','BUTTONS'],'既有物品图为独立缩略图；数量、选择、使用/禁用/确认由程序显示，不重画物品和格内假字。'),
 'OPENING_OVERLAY':('程序效果',[],'开场/尾声字幕直接叠画面，配克制字影/局部暗化保证可读；不设对白框、姓名条或大纸板。渐显隐、打字、继续/跳过由程序完成。'),
 'TUTORIAL':('已有来源',['DIALOGUE','POINTER_KEYS'],'床边站定约2秒后进入原文教学；对白与指引异步交替，小怪物教学/沉思等沿已有可用表情，鼠标提示由程序绘制/闪烁。不能把全部教学画进一张图。'),
 'FATHER_GUIDANCE':('复用母版',['DIALOGUE'],'父亲相关思考/救援提示使用正式对白框和已有父亲画像；实际内容与触发按当前剧情，不由图中造台词。'),
 'ENDING':('已有来源',['BUTTONS'],'E1–E3沿已有叙事来源/已供医院画面分阶段展示；字幕直接叠画面，返回/记录为真实按钮。不重复生成结局大图。'),
 'RUN_RECORDS':('复用母版',['BOOK_SHELL','BUTTONS'],'本次记录、历史/空态、阶段与来源均为真实数据；长记录滚动，读过/未读状态不烘焙。'),
 'TRANSITIONS':('程序效果',[],'开场渐隐显、CRT收屏、星仓缓动、普通界面淡入等由程序完成；提供降低动效，不下序列图订单。'),
 'PANELS_TABS_SCROLL':('复用母版',['FOUNDATION','BOOK_SHELL','BUTTONS'],'页签、分隔、列表、滚条复用母版和原生线条；选中/焦点/空态/滚动真实实现。'),
 'INPUTS_SLIDERS':('复用母版',['FOUNDATION','BUTTONS'],'输入框、复选/开关、滑条轨道和滑块使用真实控件/简单矢量；提供选中/禁用/错误状态。'),
 'TOOLTIPS_NOTICES':('复用母版',['FOUNDATION'],'提示/错误用共用低纹理暗面，小箭头由程序绘制；真实消息和自动消退由程序管理，不画一组带字贴片。'),
 'POINTER_KEYS':('程序效果',[],'鼠标左/右键、X、空格、箭头以原生矢量轮廓与真实文字实现，点击/悬停/淡入淡出由程序动画；不另向出图工具生成难读按键字。')
}
ICON_SHAPES={
 'SKIN':'前臂一小段轮廓，表面三条短触觉线；不画伤口',
 'GUT':'腹部内一条简化盘曲线，非写实内脏，无血液',
 'PORES':'一片皮肤表面三个微小孔点与两条短起伏线，避免密集恐惧',
 'TEMP':'同一温度计轮廓旁一条冷弧与一条暖弧，不只用红蓝分辨',
 'TINNITUS':'简洁耳廓和两条短声波，无尖锐刺穿物',
 'DRYMOUTH':'简洁口唇侧线与一滴中空小水滴，不画牙龈',
 'KNEE':'屈曲膝部侧面折线与一条小反射弧',
 'WITHDRAW':'张开的手掌往回收的一条弯曲轨迹，不画手断裂',
 'STARTLE':'肩颈轮廓上方两条短促放射线',
 'FEAR':'收紧的眼睛/眉线，外围一条克制阴影弧，不画骷髅',
 'JOY':'向上舒展的弧线与两点细小亮斑，不画表情包',
 'CONTROL':'一只简化手形与下方三条可辨认的引导线，不画受害人'
}

def guide_png(kind,title):
 # Functional zoning only; no old UI appearance is provided as a style master.
 im=Image.new('RGB',(1280,720),'#f2f2ef');dr=ImageDraw.Draw(im)
 font=ImageFont.truetype(str(ROOT/'neurons/assets/fonts/NotoSansCJKsc-Regular.otf'),23)
 small=ImageFont.truetype(str(ROOT/'neurons/assets/fonts/NotoSansCJKsc-Regular.otf'),19)
 dr.text((32,18),title+' · 只看功能分区，不照抄线框外观',fill='#263b47',font=font)
 def box(r,label,color='#dce5e8'):
  dr.rectangle(r,fill=color,outline='#61747d',width=2)
  dr.text((r[0]+14,r[1]+12),label,fill='#263b47',font=small)
 if kind=='crt':
  box((40,90,790,640),'左：电脑机壳');box((120,150,700,540),'屏幕留空：程序节点', '#f6f7f5');box((820,120,1240,640),'右：真实代码文字另层')
 elif kind=='tree':
  box((60,120,580,510),'左：主角正式预览 · 不画入');box((680,100,1220,510),'右：程序螺旋技能树 · 不画入');box((55,535,1225,680),'本项仅画底部星仓主体')
 elif kind=='book':
  box((50,85,1230,675),'展开书册');box((115,150,455,610),'左页目录留空','#f6f7f5');box((560,150,1150,610),'右页正文/画像留空','#f6f7f5')
 elif kind=='dialogue':
  box((25,455,1255,695),'仅画下方对白框');box((48,430,340,690),'怪物独立层≈23%','#e4e0da');box((380,510,1060,660),'右侧正文留空','#f6f7f5');box((1080,505,1230,660),'控制留空','#e4e0da')
 elif kind=='vitality':box((80,290,1200,430),'一条空轨道；HP/SP复用，填充值程序加')
 elif kind=='button':box((110,255,1170,475),'一个空白按钮；状态和文字程序加')
 else:box((100,130,1180,630),'低纹理暗色阅读面；四周可裁切/9-slice')
 dr.text((32,690),'框线、注释、临时配色不进入最终美术。文字/人物/粒子/动态数值由程序或既有独立素材提供。',fill='#53656c',font=small)
 b=io.BytesIO();im.save(b,format='PNG');return b.getvalue()

def apply_ui(d):
 by={a['id']:a for a in d['items']};style=d['styles'][0]['media']
 d['ui_generation']={'updated_at':datetime.now().astimezone().isoformat(),'functional_items':38,'image_orders':8,'expected_png':19,'shared_layers':7,'individual_node_icons':12,'source':'tmp/play_feedback_20261020/source.txt P134,P267–340,P523–545,P617–640','no_dialogue_frame_for_opening':True,'non_ui_unchanged':True}
 d['ui_first']=FIRST
 d['production_policy']['ui_exception']='用户生成本版UI必要底片/图标；Codex负责切片、透明、程序文字/控件/状态/接入。其余资产沿原Codex责任。'
 for a in d['items']:
  if a['category']!='UI与功能界面':continue
  k=a['id'].removeprefix('UI_DESIGN_');a['origin_role']=a.get('origin_role',a['role']);a['current_owner']='codex'
  a['ui_delivery_label']='复用／程序接入';a['generation_mode']='implementation';a['prompt']='';a['required_media']=[];a['reuse_media']=[];a['variants']=[]
  a['tasks']=[];a['parts_to_make']=[];a['audit_scope']='保留功能与全部状态；本轮仅修订生成说明，不把现有候选或功能检查当美术认可。'
  a['note']='已有功能继续保留；当前代码界面为候选，未获用户美术认可。只按本项明确需要的图层生成，文字与动态状态另层。'
  a['source']=list(dict.fromkeys(a.get('source',[])+['tmp/play_feedback_20261020/source.txt']))
  a['program_contract']='中文、数字、按钮、可用性、焦点/按下/禁用、点击与冻结、缩放和动效由Codex接入；不由PNG承担交互。'
  a['alpha_contract']='本项不新增位图。';a['slice_contract']='沿复用来源的切片规格。'
  if k in ORDERS:
   c=ORDERS[k];a['current_owner']='human';a['generation_mode']='generate';a['ui_delivery_label']='需生成一张共用图层'
   a['delivery_brief']='本次只生成：'+c['title']+'。'+c['size']+'；其他界面复用，不重复出图。'
   a['content']=c['body'];a['prompt']=prompt(c['title'],c['size'],c['body'],c['alpha'],c['slicing']);a['alpha_contract']=c['alpha'];a['slice_contract']=c['slicing']
   a['filename']=a['id']+'_v001.png';a['new_filename']=a['id']+'_v001.png';a['upload']='图1：下方已认可空房画法（只借笔触/色彩）；图2：本项功能分区图（只借位置与留空）。不上传旧UI截图或全套文档。'
   key='ui_guide_'+k.lower();raw=guide_png(c['guide'],a['name']);d['media'][key]={'url':'data:image/png;base64,'+base64.b64encode(raw).decode(),'filename':key+'.png','source_filename':'本表生成的功能分区示意，不是最终UI美术','kind':'ui_guide'}
   a['required_media']=[{'media':style,'label':'图1 · 已认可画法','note':'只借低饱和色彩、油彩块面与虚实边；不借房间结构、斜俯视镜头、家具和窗光。'},{'media':key,'label':'图2 · 本项功能分区','note':'只约束功能位置、可读留空与分层；图中的线框、注释和颜色不是需要照抄的设计。'}]
   a['checks']=list(dict.fromkeys(['没有烘焙文字、人物、数值或假控件','主体完整，要求透明处为真alpha且无棋盘格','阅读区低纹理，缩小后轮廓仍清楚',*a.get('checks',[])]))
  elif k=='SKILL_ICONS':
   a['current_owner']='human';a['generation_mode']='generate';a['ui_delivery_label']='12图标 · 每次选一张'
   a['delivery_brief']='12个节点各一张独立PNG；不要一次生成12格图集。先做SKIN确认笔触，后续附同一合格图保持整套一致。'
   a['content']='神经技能节点图标，12张独立源图。';a['upload']='首张只附下方画法图；之后另附已确认SKIN图标作全套母版。不附整张技能树截图，不让模型重写技能名。'
   a['required_media']=[{'media':style,'label':'图1 · 已认可画法','note':'只借色块与虚实笔触，图标仍采用正视清楚轮廓。'}]
   skills=read(ROOT/'neurons/data/skills.json')['skills']
   for s in skills:
    if s['id'] not in ICON_SHAPES:continue
    body='单个“'+s['name']+'”技能节点图标：'+ICON_SHAPES[s['id']]+ '。主体暖灰/旧铜灰，少量灰紫阴影，统一细窄线面结合；小尺寸64px下结构可辨。无圆形徽章大底、无标签、不画未解锁/发光等状态。'
    a['variants'].append({'key':s['id'],'name':s['id']+' · '+s['name'],'filename':'UI_SKILL_'+s['id']+'_v001.png','prompt':prompt(s['name']+'节点图标','512×512 PNG，中央独立图标',body,'外部透明；图标主体不透明。','主体在x64–448、y64–448内，四周留同等安全边，程序生成灰显/发光/选中轮廓。')})
   a['prompt']=a['variants'][0]['prompt'];a['alpha_contract']='12张独立真alpha图，无棋盘格。';a['slice_contract']='每张512方形，不切图集；主体留64px边，64px缩图辨识验收。'
   a['program_contract']='用相同图标跨CRT节点与星环复用；节点名、费用、锁定/灰显/已解锁/选中及连线由程序显示。'
  else:
   mode,refs,text=REUSE[k];a['generation_mode']='reuse' if mode!='程序效果' else 'implementation'
   a['reuse_from']=[base_id(x) for x in refs];a['delivery_brief']=text;a['content']=text;a['upload']='本项无需向出图工具上传资料或生成新图。';a['program_contract']=text+' '+a['program_contract']
  if k=='TITLE':a['reuse_media']=[{'media':style,'label':'已有可用来源 · 空房BASE','note':'这是已认可来源的门墙气氛局部；不等于当前标题页整体视觉已经认可。'}]
  if k in ['DIALOGUE','PROFILE','TUTORIAL']:
   player=by['CHR_PLAYER_MASTER_2D'];f=next(x for x in player['existing'] if x['status']=='accepted')
   a['reuse_media'].append({'media':f['media'],'label':'已有可用 · 小怪物母图','note':'保持此具体认可版本；人物另层接入，不在框底图中重画。'})
  if k=='OPENING_OVERLAY':a['checks']=['开场与尾声字幕没有对白框/姓名条/大阅读板','打字、渐隐显、继续/跳过由程序实现','角色和叙事画面独立，不把字幕烘焙入画']
  if k=='DIALOGUE':a['source'].append('新体验DOCX P267–269 / image2仅功能布局');a['checks'].insert(0,'下方约1/3屏；小怪物独立位不压正文，自动播放/快进是真控件')
  if k=='HUD_VITALITY':a['program_contract']='左上极简HP/SP；损伤后出现与X键切换按当前规则，停留跨一次行动/搜寻的时序由程序判定。轨道复用两条，数值/填充/差值/状态标签程序画。'
 return d

def main():
 data_path=OUT/'data/comprehensive_assets.json';old=read(data_path);d=copy.deepcopy(old)
 stamp=datetime.now().strftime('%Y%m%d_%H%M%S');backup=DESKTOP/'历史'/('UI生成说明修订前_'+stamp);backup.mkdir(parents=True)
 protected=[OUT/'data/approval_baseline.json',OUT/'data/inventory_snapshot.json',DESKTOP/'NEURONS_美术进度.json']
 hashes={str(p):sha(p) for p in protected if p.exists()}
 for p in [OUT/PAGE,OUT/UI_PAGE,data_path,OUT/'data/ui_items.json',OUT/'data/production_policy.json',OUT/'delivery_manifest.json']:
  if p.exists():shutil.copy2(p,backup/p.name)
 for p in [DESKTOP/PAGE,DESKTOP/UI_PAGE]:
  if p.exists():
   existing=builder.embedded(p,'form-data')
   if existing.get('user_progress'):d['user_progress']={**d.get('user_progress',{}),**existing['user_progress']}
 d=apply_ui(d);assert len(d['items'])==640
 assert [a for a in old['items'] if a['category']!='UI与功能界面']==[a for a in d['items'] if a['category']!='UI与功能界面']
 assert old['inventory_snapshot']==d['inventory_snapshot']
 for k in ['initial','source_progress','source_progress_files']:assert old[k]==d[k]
 dump(data_path,d);ui={'title':'NEURONS UI图层生成与全部功能复用表','scope':'用户生成必要图层；Codex接入；38功能ID保留。','first':FIRST,'items':[a for a in d['items'] if a['category']=='UI与功能界面'],'coverage':old.get('coverage',{}),'ui_generation':d['ui_generation']}
 dump(OUT/'data/ui_items.json',ui);dump(ROOT/'tmp/comprehensive_forms_20261019/ui_items.json',ui);dump(OUT/'data/production_policy.json',d['production_policy'])
 for name,only in [(PAGE,False),(UI_PAGE,True)]:
  html=builder.render(d,only);(OUT/name).write_text(html,encoding='utf-8');(DESKTOP/name).write_text(html,encoding='utf-8')
 info=('当前UI入口：'+UI_PAGE+'\n新对话先复制UI首次说明，再展开本次图层，上传本项所列参考图。\n'
       '默认只列8项图层订单：7张共用底片+12个独立节点图标，共19张PNG。先验母版，不需要逐状态/逐界面生成。\n'
       '查看完整清单保留38项功能与复用说明。开场字幕不生成对白框。旧候选UI未标认可。\n'
       '用户生成UI美术，Codex完成切片、文字、真实控件、状态与接入；其他资产分工保持。\n'
       '已有认可具体版本/345文件快照/旧进度保留；本次未重新扫描素材，也未修改游戏。\n')
 (DESKTOP/'UI表单_使用说明.txt').write_text(info,encoding='utf-8');(OUT/'UI表单_使用说明.txt').write_text(info,encoding='utf-8')
 manifest=read(OUT/'delivery_manifest.json');manifest['ui_generation_refresh']=d['ui_generation'];manifest['ui_generation_refresh']['backup']=str(backup);manifest['sha256']={name:sha(OUT/name) for name in [PAGE,UI_PAGE]};manifest['browser_verified']=False;manifest['previous_verification_checks']=manifest.pop('verification_checks',None);dump(OUT/'delivery_manifest.json',manifest)
 for path,h in hashes.items():assert sha(path)==h,path
 report={'updated_at':d['ui_generation']['updated_at'],'ui_items':38,'image_orders':8,'png_outputs':19,'non_ui_items_identical':602,'approved_hashes_unchanged':True,'inventory_snapshot_unchanged':True,'progress_sources_unchanged':True,'standalone_progress_sha256':hashes.get(str(DESKTOP/'NEURONS_美术进度.json')),'backup':str(backup),'game_written':False,'images_generated':False}
 dump(OUT/'data/ui_generation_refresh.json',report);print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':main()
