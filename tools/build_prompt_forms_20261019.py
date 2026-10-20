"""Revise generation briefs only. Never edits game, source art or old progress."""
from pathlib import Path
import base64, copy, hashlib, json, re, shutil

ROOT=Path(__file__).resolve().parents[1]
DESKTOP=Path('C:/Users/23623/Desktop/NEW/最终表单')
SOURCE=DESKTOP/'01_美术资产表_可分享.html'
OUT=ROOT/'deliverables/generation_forms_20261019'
CHAR_STYLE='采用本项目统一二维绘画语言：以大色块和明确冷暖塑造体积，衣褶、毛发按走向归并；脸、手、落脚与身份标记清楚，背光轮廓允许少量消隐。不要把每条边都描成同样黑线，也不铺满照片式细纹、塑料高光或描边光晕。'
PROP_STYLE='物件用成片明暗与冷暖色面塑造体积，木纹、金属和织物只在材质转折保留少量有方向的笔触。操作面、支点和轮廓清楚，背光边缘适度归并；不把每条边都描黑，也不铺满照片式细纹或油亮高光。'
STORY_STYLE='以叙事插画的明暗大形组织画面：一个视觉中心、两到三组主色，近处关键转折稍清晰，远处和暗部合并，保留疏密不同的干笔与色面。笔触服从形体与受光，不在全图平均覆盖颗粒、斑驳和装饰性细节；光源服务事件，不默认套夕阳、雾海或宣传海报式光柱。'
FIRST='''为《NEURONS》制作纯二维绘画游戏素材。艺术方向参考《极乐迪斯科》的色块组织、冷暖塑形、生活痕迹和选择性笔触；《死亡之门》只参考形体清楚、空间层次与动作节奏。保留本项目人物身份、衣装、物件用途和剧情，不临摹原作人物或布景。
先用大形、主色和明暗关系建立体积，再把细节放在脸、手、关节、材质转折和实际操作处；暗部与远处适当归并，边缘有清楚与消隐的变化。低饱和不等于整张灰褐，手绘不等于均匀噪点或满墙斑驳。不要用油亮皮肤、统一描边光、过量景深、密集碎纹和固定夕阳制造完成感。
每次只做本次条目。已确认母图负责身份、身体结构、衣装和画法；动作图只改明确姿态，不重新设计脸和体型。动作逐张制作，再对齐、补真正缺少的过渡并连续预览，姿势数量不是最终播放帧数。人物、可动道具和必要接触对象按该条说明分开，背景与投影不烘焙进独立物件。开场和结局是独立叙事构图，不套探索房间的斜俯视镜头。'''
SCENE_FIRST='''为《NEURONS》制作纯二维绘画场景。图示样板只负责绘画语言、观看高度、可见立面和近侧墙剖切；本条文字负责房间连接、门窗与必要通路。不要搬用样板中家具摆位，也不要从旧平面图照抄墙厚、墙高和顶视机位。
采用图示那种中等高度的斜侧观看：看得见墙的立面，也能读到地面纵深和家具侧面；后侧横边略有倾斜，不把整间房做成俯拍平面图、正面舞台或水平剪切的工程体块。远侧墙保留完整立面，贴近画面下沿的墙以及左下方挡住操作区的墙段用建筑剖切展示，保留必要墙脚、转角、门槛与窗台下实体；不是透明玻璃围栏，也不代表逻辑空间缺墙。具体哪一段剖切服从本条，不机械删除整条左墙。
以《极乐迪斯科》的绘画色块、冷暖与生活材质为主，《死亡之门》只参考光影层次和清楚体积。宽笔建立完整色面，细节集中在门窗、材质转折和叙事痕迹；不同房型保留各自材料，不把医院、卧室、脑内和街道全部做成同一灰水泥房。一次只输出当前场景的一张固定建筑底图；家具、人物、门扇和可动物件另行接入，移开后背景完整。'''

def script_json(text,id):
    return json.loads(re.search(r'<script[^>]*id="'+id+r'"[^>]*>([\s\S]*?)</script>',text).group(1))
def dump(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def png_url(path):return 'data:image/png;base64,'+base64.b64encode(Path(path).read_bytes()).decode()
def plain(s):return re.sub(r'\s+',' ',str(s or '')).strip()
def clean(s):
    s=str(s or '').replace('带缝线后脑面孔','保留已确认旧伤的后脸')
    s=re.sub(r'原记录：[\s\S]*','',s)
    s=re.sub(r'第[一二三四五六七八九十\d]+[帧格].*?(?:[；。]|$)','',s)
    return plain(s)

def revise_item(a,g,index):
    p=copy.deepcopy(a.get('production',{}));id=a['id'];clips=copy.deepcopy(a.get('clips',[]))
    cat='动作' if clips else '人物母图' if g['section']=='人物' else g['section']
    role=p.get('role','human' if a.get('owner')=='A' else 'codex')
    if id=='SLIDE_B05':role='defer'
    reason=p.get('pending','')
    if id=='SLIDE_B05':reason='当前开场已撤下飞船，尚无确认采用位置；保留ID与旧图，不新下制作单。'
    refs=copy.deepcopy(p.get('refs',[]))
    if id=='CHR_OTHER_NPCS_N19_ALTERED':
        refs += [{'id':'CHR_MAIN','name':'主角当前外貌与已经成立的旧伤参考','role':'只按已发生事实继承面貌/伤处，不能凭空添加缝线','required':True}]
    if id=='CHR_OTHER_NPCS_FATHER_ACTION_ALTERED':
        refs=[r for r in refs if r['id'] not in ['CHR_OTHER_NPCS_CAT']]
        p['contact_choices']=['CHR_MAIN','CHR_OTHER_NPCS_DOG_ALTERED','CHR_OTHER_NPCS_MOTHER_ALTERED']
    for c in clips:
        for k in ['frames','target_frames','cols','rows']:c.pop(k,None)
        c['contact']='接触/持有/释放与原游戏时钟对齐；下方姿势序号不是命中帧号。'
        c['action']=clean(c.get('action',''))
        poses=c.get('poses',[])
        if 'SEARCH_LOW' in id and c['key']=='reach' and len(poses)>2:
            poses[2]['label']='触点保持';poses[2]['text']='蹲姿稳定，指定手已经触及当前低位操作面并保持；另一手帮助平衡，尚未收手起身。'
        if 'WALK_D' in id and c['key']=='walk':
            c['play_order']=[0,4,2,5,1,6,3,7]
            c['guide']='先核左、右接触和左右经过四种不同承重；下沉、蹬地按连播缺口补。八种相位各不相同，不是让工具一次拼八个相似站姿。'
        else:c['play_order']=list(range(len(poses)))
        if id=='CHR_HUNTER_ACTION':
            c['action']='压肩蓄势→定向扑出→双手前伸到胸腹高度→落步收臂。'
            labels=[('压肩准备','双脚前后支撑，屈髋压肩，双肘弯曲向前引，头和躯干沿已经选定的扑击方向。'),('扑出过渡','后脚蹬地，躯干前倾，前腿向前接落，双臂从屈肘向前展开；保持原身体长度，不把整个人水平拉长。'),('前伸核心','双臂到达前方胸腹高度，肩肘腕连续，前脚接落承重；这是一次短扑的前伸姿态，不把它画成持续抱持。'),('落步收势','前脚落稳，膝髋吸收冲量，双臂回收，重心重新落在支撑面内。')]
            c['poses']=[{'label':l,'text':t,'filename':f'{id}__lunge__P{i+1:02d}_v005.png'} for i,(l,t) in enumerate(labels)];c['play_order']=[0,1,2,3]
        if id=='CHR_OTHER_NPCS_N19_ACTION_ALTERED':
            c['action']='原朝向→头颈与上躯转向→后脸朝镜头停留；旧伤仅来自已确认事实。'
            c['guide']='受伤后的退避复用本角色受伤与步态，保持中立；不另订反击或整套退避动画。'
        if id=='CHR_OTHER_NPCS_N35_ACTION_ALTERED':
            c['guide']='原受伤反应后才进入松颈、转向和前伸；收势后恢复互扼待机。始终同一躯干、两颗头、原有两臂，不多画第三头或额外肢体。'
        if id=='CHR_OTHER_NPCS_FATHER_ACTION_FIRST':
            c['guide']=c.get('guide','')+' 带行接触姿势不是完整步态；行走复用同父亲步态并保持手位，播放缺腿部经过时只补对应相位。'
        for i,pose in enumerate(c.get('poses',[])):
            pose['label']=clean(pose['label']);pose['text']=clean(pose.get('text',pose['label']))
            pose.setdefault('filename',f"{id}__{c['key']}__P{i+1:02d}_v005.png")
    content=a.get('prompt','')
    story={
      'SLIDE_A02':'街角中景的灾变快闪：受损楼体压住半条街，少量人与动物沿剩余道路逃离，远处来源不明的爆发烟尘遮住路口。近处暗形切入，中景逃离方向清楚，远楼合并为灰蓝色面；细节集中在身影与断口，其余用宽笔归并。不指定灾变原因。',
      'SLIDE_A03':'乡村灾变快闪：田埂斜穿画面，引向偏侧受损农舍，少量撤离身影出现在田埂与建筑交界。田块、草木与远天形成土褐、灰绿、冷灰大面；农舍断口稍清晰，远景边缘柔化，保留粗细有别的干笔。不新增灾变来源或仪式。',
      'SLIDE_A04':'灾变海面，一道斜向涌起的巨浪占主要画幅，浪后远海收成低沉水平带，浪体厚重与危险方向清楚。暗蓝灰大面承托少数灰白浪脊，近处转折保留断笔亮边，远处云水边界柔化。',
      'SLIDE_A06':'无人的神经实验室悬疑定格：偏侧实验台与神经信号设备构成主体，电极线集中连接操作面，门洞与暗背景简洁。冷光照亮实验台一角，金属和玻璃用少量硬边，暗处归并为低对比宽色面。不显示事故源头，不写可读仪表文字。'}
    content=story.get(id,content)
    support='沿同方向基姿的脚下基准线，身体尺度固定；相位需要的屈膝与重心起伏照常发生，不能把头顶锁死。'
    if any(s in id for s in ['DOG','CAT']):support='保留同一四足身体长度、四爪支撑和尾部空间；抬爪时其余支撑爪有可信承重。'
    elif any(s in plain(a.get('note',''))+plain(a.get('name',''))+plain(p.get('scope','')) for s in ['轮椅','躺卧','病床']):support='按本动作实际姿势保留臀部/座面或背部/床面支点；不可把站姿整张横转当坐卧。'
    note=plain(p.get('reuse',''))
    if id=='CHR_OTHER_NPCS_FATHER_ACTION_ALTERED':note+=' 粘连碎瓶属于身体母图，动作中保留；仅普通未粘连道具才另层。当前目标按实际相位选一项，不全附人物。'
    if id=='CHR_OTHER_NPCS_N19_ALTERED':note+=' 后期面孔关联主角当前外貌及已经成立的旧伤；资料未确认的伤处不画。'
    targets=p.get('contact_choices',p.get('pairs',[]))
    for c in clips:
        anchor=c.get('anchor','')
        if id=='CHR_MAIN_SLEEP_WAKE' or id=='CHR_OTHER_NPCS_N10_ACTION_FIRST':
            c['support']='本动作沿参考床长轴，按手掌、臀部、背部和枕头的实际接触转换支点；人体保持原尺度，扩画布容纳坐卧，床另层。'
        elif id=='CHR_OTHER_NPCS_N08_ACTION_FIRST':
            c['support']='保持母图坐姿，臀部与椅面接触、双脚自然落地；只有抬头与手部动作，不凭空离座。'
        elif id=='CHR_OTHER_NPCS_N10_ACTION_ALTERED':
            c['support']='保持裹床单靠墙坐姿，臀部由地面支撑、背部沿参考墙面；不是床上卧姿，也不是站姿。'
        elif any(t in anchor for t in ['床面','臀','座面','靠墙']):c['support']=anchor
        else:c['support']=support
    tasks=copy.deepcopy(a.get('production_tasks',[]))
    for t in tasks:t['filename']=f"{id}__{t['key']}_v005.png"
    direction=a.get('direction','')
    if not direction and re.search(r'_D[0-3]$',id):direction=['画面右','画面上','画面左','画面下'][int(id[-1])]
    return {'id':id,'name':a['name'],'filename':a.get('filename',id+'_v001.png'),'category':cat,'group':g['name'],'scope':p.get('scope',a.get('scope',g.get('scope',''))),'role':role,'pending':reason,'blocked':p.get('blocked',False),'content':content,'mother':p.get('mother'),'mother_choices':p.get('mother_choices',[]),'refs':refs,'target_choices':targets,'clips':clips,'tasks':tasks,'support':support,'direction':direction,'canvas':a.get('canvas_spec',''),'spec':a.get('spec_id',''),'type':p.get('type',''),'upload':p.get('upload',a.get('references','')),'quantity':p.get('quantity',a.get('quantity','')),'note':note,'source':a.get('source',g.get('source','')),'checks':p.get('check',[]),'source_ids':a.get('source_ids',[id])}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source_text=SOURCE.read_text(encoding='utf-8-sig');data=script_json(source_text,'table-data')
    index={a['id']:a for g in data['groups'] for a in g['items']}
    non=[]
    for g in data['groups']:
        if g['section']=='房间与街道':continue
        for a in g['items']:non.append(revise_item(a,g,index))
    effects=[]
    for e in data.get('effect_requirements',[]):
        effects.append({'id':e['id'],'name':e['name'],'scope':e.get('scope',''),'method':e.get('method',''),'manual':e.get('manual',''),'prompt':e.get('prompt',''),'reuse':e.get('reuse',[]),'acceptance':e.get('acceptance',''),'status':'沿最新程序占位继续加工；功能运行不等于正式画面验收。'})
    pack={'title':'NEURONS 人物动作及其他 · 生成表单','mode':'assets','first':FIRST,'items':non,'effects':effects,'names':{a['id']:a['name'] for a in index.values()},'initial':data.get('initial',{}),'source_progress':data.get('source_progress',{}),'style_links':data.get('approved_samples',[]),'char_style':CHAR_STYLE,'prop_style':PROP_STYLE,'story_style':STORY_STYLE,'version':'2026-10-19 提示词与操作修订'}
    # Expose an already existing conditional effect beside the affected actor.
    dog=next(a for a in non if a['id']=='CHR_OTHER_NPCS_DOG_ACTION_ALTERED')
    dog['effects']=['VIS_DOG_SHATTER']
    dump(OUT/'data/non_scene_items.json',pack)
    page=render(pack)
    dest=DESKTOP/'人物动作及其他';dest.mkdir(parents=True,exist_ok=True)
    path=dest/'01_人物动作及其他_生成表单_可分享.html';path.write_text(page,encoding='utf-8')
    (OUT/path.name).write_text(page,encoding='utf-8')
    scene_path=ROOT/'tmp/art_form_20261019/scene_editorial.json'
    if not scene_path.exists():scene_path=OUT/'data/scene_editorial.json'
    if scene_path.exists():build_scenes(scene_path,data)
    dump(OUT/'revision_manifest.json',{'source_form':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'non_scene_assets':len(non),'effects_existing':len(effects),'game_changed':False,'images_generated':False,'source_form_unchanged':True,'prior_scene_page_archived':True,'scene_page_updated':True,'changes':['恢复分类的充分艺术说明与完整复制文本','保留最新单张相位流程与有效八相步态，区分制作序号/播放顺序','修低搜触点、双面旧伤、父亲目标、猎手具体姿势','将已有大黄碎裂条件提示词直接露出，不增人工单','开场恢复原稿中的逃离人/动物及不明爆发，保留原3图','场景机位与墙面调整明确排入下一轮游戏制作首项']})
    print(json.dumps({'non_scene_assets':len(non),'effects':len(effects),'page':str(path),'scene_editorial_ready':scene_path.exists()},ensure_ascii=False))

def build_scenes(path,data):
    editorial=json.loads(path.read_text(encoding='utf-8'))
    dump(OUT/'data/scene_editorial.json',editorial)
    rows=editorial['items'] if isinstance(editorial,dict) else editorial
    runtime=json.loads((ROOT/'deliverables/space_templates_20261018/runtime_spaces.json').read_text(encoding='utf-8'))
    rt={r['id']:r for r in runtime['rooms']};items=[]
    for e in rows:
        r=rt[e['id']];id=e['asset_id']
        reference='附本页“空房画法与机位样板”（图三），只取观看方式、近墙剖切和绘画语言。门窗与材料按下方本房文字。不要再附旧程序体块或平面图锁机位。'
        reuse=r['chapter']==5 and r['room_id'] in {'atrium','memory','visual','decision','body','bridge','rhythm','index','switch','verify','identity'} or r['chapter']==3 and r['room_id'] in {'ward','lobby','clinic','pharmacy','office'}
        if reuse:reference='附已确认的对应前阶段同房底图，沿原画布、门窗与通路编辑；不重新生成一间房。尚无合格底图时先完成对应基础项。画法图只在建立基础图时附。'
        wall=r['config'].get('wall',{});door=r['config'].get('door',{})
        measure=f"比例起测：有效地面约{r['size_m'][0]:g}×{r['size_m'][1]:g}米；以成人约1.75米校核，人物只是比例尺，不画进本张。"
        if r['chapter'] in [1,2,3,4,5]:measure+=f"普通房门约{door.get('clear_width_m',0.95):g}米宽/{door.get('height_m',2.15):g}米高；原有特殊入口按本房连接说明，不统一换普通门。"
        if e['scope_kind'] not in ['街道建筑底图','隐藏街道建筑底图'] and r['config'].get('wall'):
            measure+=f"实体墙高约{wall.get('height_m',2.55):g}米，截面约{wall.get('thickness_m',0.15):g}米；近墙剖切只是显示方式，不改变实际墙高。"
        prompt='\n'.join([f"绘制《NEURONS》{e['title']}的固定建筑底图，一张画面。",e['material_prompt'],f"空间连接：{e['ports_text']}",measure,f"建筑与设施分区（明确的固定建筑画入，其余家具仅留位）：{e['furniture_zones']}",e['path_text'],e['boundary_view'],'视角与所附画法样板一致：中等高度的斜侧观看，墙面立面与地面纵深同时清楚；主要空间完整，长通道允许横向展开，不把人物尺度缩小凑全景。','以冷暖色面、选择性宽笔和材质转折塑形；细节集中在建筑连接与使用痕迹，不铺满同一种斑驳。','可互动家具、人物、门扇及可动物件本张不画，移走后墙地背景完整。'+('这是一张沿前阶段同房底图的状态编辑，不改变机位、门窗和可走边界。' if reuse else ''),'保留高分辨率原图，可从3072×2048起试；长通道按形状扩展画幅，不裁掉有效入口或压缩通路。'])
        items.append({'id':id,'runtime_id':e['id'],'name':e['title'],'filename':next((a['filename'] for g in data['groups'] for a in g['items'] if a['id']==id),id+'_v001.png'),'category':'场景','group':f"L{r['chapter']}" if r['chapter'] else '隐藏路线','scope':e.get('scope_kind',''),'role':'conditional' if reuse else 'human','pending':'','content':prompt,'upload':reference,'size':r['size_m'],'ports':e['ports_text'],'furniture_zones':e['furniture_zones'],'path_text':e['path_text'],'conflict_note':e.get('conflict_note',''),'source':e.get('source','当前原稿连接与逐房方案'),'clips':[]})
    known={a['id'] for a in items}
    for g in data['groups']:
        if g['section']!='房间与街道':continue
        for a in g['items']:
            if a['id'] in known:continue
            if a.get('production',{}).get('role')!='codex':raise ValueError('Unmapped manual scene '+a['id'])
            items.append({'id':a['id'],'runtime_id':None,'name':a['name'],'filename':a['filename'],'category':'场景','group':'Codex状态派生','scope':a.get('scope',''),'role':'codex','content':a['prompt'],'clips':[]})
    samples=[{'name':'图三 · 空房画法与机位样板','note':'用于观看方式、近墙剖切、冷暖色块。其他房型不照抄卧室木地板与门窗。','url':png_url('C:/Users/23623/AppData/Local/Temp/codex-clipboard-f5cfa759-f401-4e00-ae42-da2ca9bd1ac9.png'),'filename':'NEURONS_空房画法机位参考.png'}, {'name':'图二 · 有家具的表现参考','note':'只核画法、尺度观感与家具的可读侧面；摆位不采用，默认不上传生成底图。','url':png_url('C:/Users/23623/AppData/Local/Temp/codex-clipboard-1cbd2fd8-58fc-4d6a-9994-89dc050530ab.png'),'filename':'NEURONS_整体表现参考_不采纳摆位.png'}]
    pack={'title':'NEURONS 场景生成 · 画法与近墙剖切修订','mode':'scenes','first':SCENE_FIRST,'items':items,'samples':samples,'initial':data.get('initial',{}),'source_progress':data.get('source_progress',{}),'style_links':[x for x in data.get('approved_samples',[]) if x['section']=='房间与街道'],'version':'2026-10-19 提示词修订；游戏机位下一轮调整'}
    dump(OUT/'data/scene_items.json',pack)
    page=render(pack);dest=DESKTOP/'空间与家具模板';dest.mkdir(exist_ok=True)
    # The 00 entry belongs to the runtime-derived embedded geometry templates.
    # This editorial-only page must never replace its room/placement/prop PNGs.
    (dest/'02_场景文字说明_可分享.html').write_text(page,encoding='utf-8')
    (OUT/'02_场景生成表单_可分享.html').write_text(page,encoding='utf-8')

def render(data):return PAGE.replace('__PACK__',json.dumps(data,ensure_ascii=False).replace('</',r'<\/')).replace('</style>','[hidden]{display:none!important}</style>').replace('__ASSET_UI__',(ROOT/'tools/prompt_form_asset_ui_20261019.js').read_text(encoding='utf-8'))

PAGE=r'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEURONS 生成表单</title>
<style>:root{--ink:#263d3b;--accent:#32665d}*{box-sizing:border-box}body{margin:0;background:#f4f0e7;color:var(--ink);font:16px/1.7 system-ui,"Microsoft Yahei",sans-serif}main{max-width:1160px;margin:auto;padding:24px}h1{font-size:27px;margin:0}h2{font-size:20px}p{margin:9px 0}button,select,input,textarea{font:inherit;color:inherit}button,select,input{padding:8px 11px;background:white;border:1px solid #b7c3b8;border-radius:5px}button{cursor:pointer}button.primary{background:var(--accent);color:white}button:disabled{opacity:.45;cursor:default}textarea{display:block;width:100%;padding:12px;border:1px solid #b7c3b8;border-radius:5px;line-height:1.7;resize:vertical;background:#fff}header{padding:0 0 18px;border-bottom:1px solid #c2cbbb}nav,.actions,.selectors{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin:12px 0}.notice{background:#e3e9da;padding:12px;border-radius:6px}.warn{background:#f2e7d3;padding:10px}.meta{font-size:14px;color:#617469}article{background:#fff;border:1px solid #c8d1c3;border-radius:6px;margin:12px 0;padding:13px}summary{cursor:pointer;font-weight:650}.badge{font-size:12px;padding:3px 7px;background:#edf1e8;border-radius:4px;margin-left:8px}.panel{padding:12px 3px 0}.phase-order{font-size:14px;padding:9px;background:#edf1e8}.samples{display:grid;grid-template-columns:1fr 1fr;gap:12px}.samples img{width:100%;height:auto}.samples figure{margin:0}#toast{position:fixed;bottom:18px;right:20px;background:#263d3b;color:white;padding:8px 14px;display:none;border-radius:5px}.progress{margin-top:15px;border-top:1px solid #dde3d7;padding-top:10px}.progress textarea{min-height:55px}a{color:#32665d}@media(max-width:650px){main{padding:12px}.samples{grid-template-columns:1fr}nav{position:static}textarea{font-size:15px}h1{font-size:23px}}</style>
<main><header><h1 id="title"></h1><p id="version" class="meta"></p><div id="intro"></div><div class="actions"><button id="first" class="primary">复制新对话首次说明</button><button id="showfirst">查看首次说明</button><button id="export">导出进度JSON</button><button id="filled">下载填写版网页</button><button id="import">导入进度</button><input hidden type="file" accept="application/json" id="importfile"></div><textarea id="firsttext" hidden rows="9"></textarea></header>
<div id="samples"></div><details id="links"><summary>已认可的原作参考链接与借鉴范围</summary><div id="linkbody"></div></details>
<nav><select id="category"></select><select id="group"></select><input id="search" placeholder="搜角色、动作、物件或ID"><label><input id="defer" type="checkbox"> 包含暂缓项</label><label><input id="code" type="checkbox"> 查看Codex处理项</label><span id="count" class="meta"></span></nav><section id="items"></section><details id="effects"><summary>已有事件效果：优先由Codex复用，不增加整套人工订单</summary><div id="effectbody"></div></details><footer class="meta"><p>单个HTML内含提示词及所需样板，可转发后离线打开。母图与生成素材由你另附；填写版与进度JSON是跨设备交接文件，本地缓存不会自动同步。本表未生成或验收任何正式图像。</p></footer></main><div id="toast"></div>
<script id="prompt-data" type="application/json">__PACK__</script><script>
const D=JSON.parse(document.getElementById('prompt-data').textContent),$=s=>document.getElementById(s),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function progressMap(raw){if(Array.isArray(raw))return Object.fromEntries(raw.filter(x=>x?.id).map(x=>[x.id,x]));return raw&&typeof raw==='object'?raw:{}}
const initial={...progressMap(D.source_progress?.art),...progressMap(D.initial),...progressMap(D.source_progress?.form_progress)};let state=JSON.parse(JSON.stringify(initial)),storageKey='NEURONS_GENERATION_20261019_'+D.mode;
try{Object.assign(state,JSON.parse(localStorage.getItem(storageKey)||'{}'))}catch(e){}
function persist(){try{localStorage.setItem(storageKey,JSON.stringify(state))}catch(e){}}
function toast(s){$('toast').textContent=s;$('toast').style.display='block';setTimeout(()=>$('toast').style.display='none',2200)}
async function copy(s){try{await navigator.clipboard.writeText(s)}catch(e){const t=document.createElement('textarea');t.value=s;document.body.append(t);t.select();if(!document.execCommand('copy')){t.remove();toast('请选中提示词手动复制');return}t.remove()}toast('已复制')}
function download(url,name){const a=document.createElement('a');a.href=url;a.download=name;a.click()}
function blobSave(content,name,type='application/json'){const url=URL.createObjectURL(new Blob([content],{type}));download(url,name);setTimeout(()=>URL.revokeObjectURL(url),2000)}
$('title').textContent=D.title;document.title=D.title;$('version').textContent=D.version;$('firsttext').value=D.first;$('first').onclick=()=>copy(D.first);$('showfirst').onclick=()=>{$('firsttext').hidden=!$('firsttext').hidden};
$('intro').innerHTML=D.mode==='scenes'?'<p>本次修的是生成说明。按图二、图三的观看效果做近墙剖切；<b>游戏机位与墙面显示留作下一轮首项</b>，当前旧程序投影没有被当作已批准成品机位。</p><p class="notice">生成底图：新对话先复制首次说明 → 上传下方空房样板 → 复制本房完整提示词。不要再把全高透明墙体块当画法参考。房间连接写在每项；家具摆放只在该项说明中核对，图二的摆位不采用。</p>':'<p>用本页生成人物母图、动作相位、家具物品和开场/结局。新对话先复制首次说明，再按当前条目附图；同一角色沿已确认母图编辑。</p><p class="notice"><b>动作仍要做成动画。</b>下面一次生成一张明确相位，不是一张图代替动作。对齐后由Codex按正确顺序播放、补缺少的过渡并实机核接触；不能承诺靠提示词自动保证流畅或完全不变形。已有合格相位先复用，不按人数重订整套动画。</p>';
if(D.samples){$('samples').innerHTML='<div class="samples">'+D.samples.map((s,i)=>'<figure><h3>'+esc(s.name)+'</h3><img src="'+s.url+'"><p class="meta">'+esc(s.note)+'</p><button data-sample="'+i+'">下载此参考图</button></figure>').join('')+'</div>';$('samples').querySelectorAll('[data-sample]').forEach(b=>b.onclick=()=>{const s=D.samples[+b.dataset.sample];download(s.url,s.filename)})}
$('linkbody').innerHTML=(D.style_links||[]).map(s=>'<p><b>'+esc(s.section)+'</b> · '+s.links.map(l=>'<a target="_blank" rel="noopener" href="'+esc(l.url)+'">'+esc(l.name)+'</a>').join(' / ')+'<br>'+esc(s.take)+' '+esc(s.apply)+'</p>').join('');
const cats=D.mode==='scenes'?['场景']:['人物母图','动作','家具与物品','开场与结局'];$('category').innerHTML=cats.map(c=>'<option>'+esc(c)+'</option>').join('');
function groups(){const cat=$('category').value;const gs=[...new Set(D.items.filter(a=>a.category===cat).map(a=>a.group))];$('group').innerHTML='<option value="">全部分组</option>'+gs.map(g=>'<option>'+esc(g)+'</option>').join('')}
function role(a){return a.role==='defer'?'暂缓':a.role==='conditional'?'已有先复用 / 缺图再补':a.role==='codex'?'Codex处理':'正式主体'}
function progressUI(host,a){const box=document.createElement('div');box.className='progress';const p=state[a.id]||{};box.innerHTML='<div class="selectors"><span>我的进度</span><select class="status"><option>未开始</option><option>已有候选</option><option>已交付待验</option><option>需局部修改</option><option>已确认</option></select><input class="file" placeholder="文件名或交付位置"></div><textarea class="notes" placeholder="备注：当前母图、待修相位等"></textarea>';const st=box.querySelector('.status'),f=box.querySelector('.file'),n=box.querySelector('.notes');if(p.status&&!Array.from(st.options).some(o=>o.value===p.status)){const op=document.createElement('option');op.textContent=p.status;st.append(op)}st.value=p.status||'未开始';f.value=p.file||'';n.value=p.notes||'';[st,f,n].forEach(x=>x.onchange=()=>{state[a.id]={...p,status:st.value,file:f.value,notes:n.value};persist()});host.append(box)}
__ASSET_UI__
function renderScene(a,host){if(a.role==='codex'){renderAsset(a,host);return}host.innerHTML='<p class="meta">'+esc(a.id)+' · 当前尺寸参考 '+a.size.join(' × ')+' m；机位与可视墙面按本次样板修订，下一轮游戏对齐。</p><p><b>附图：</b>'+esc(a.upload)+'</p><p class="notice"><b>固定建筑与设施分区：</b>'+esc(a.furniture_zones)+'<br>'+esc(a.path_text)+'（固定建筑按说明画入，独立家具只留位。）</p><textarea class="prompt" rows="14" readonly></textarea><div class="actions"><button class="primary copy">复制本房完整提示词</button><button class="filename">复制文件名</button></div>'+(a.conflict_note?'<details><summary>与当前游戏的待对齐处</summary><p>'+esc(a.conflict_note)+'</p></details>':'');host.querySelector('.prompt').value=a.content;host.querySelector('.copy').onclick=()=>copy(a.content);host.querySelector('.filename').onclick=()=>copy(a.filename);progressUI(host,a)}
function render(){const cat=$('category').value,g=$('group').value,q=$('search').value.trim().toLowerCase(),show=$('defer').checked,showcode=$('code').checked;const list=D.items.filter(a=>a.category===cat&&(!g||a.group===g)&&(show||a.role!=='defer')&&(showcode||a.role!=='codex')&&(!q||[a.id,a.name,a.group,a.scope,a.content,...(a.clips||[]).map(c=>c.label)].join(' ').toLowerCase().includes(q)));$('items').replaceChildren();for(const a of list){const art=document.createElement('article');art.innerHTML='<details><summary>'+esc(a.name)+'<span class="badge">'+esc(role(a))+'</span></summary><div class="panel"></div></details>';const det=art.querySelector('details');det.addEventListener('toggle',()=>{if(!det.open||det.dataset.loaded)return;det.dataset.loaded='1';(D.mode==='scenes'?renderScene:renderAsset)(a,art.querySelector('.panel'))});$('items').append(art)}$('count').textContent=list.length+' 项'}$('category').onchange=()=>{groups();render()};$('group').onchange=render;$('search').oninput=render;$('defer').onchange=render;$('code').onchange=render;if(D.mode==='scenes')$('code').parentElement.hidden=true;groups();render();
if(D.effects){$('effectbody').innerHTML=D.effects.map(e=>'<p><b>'+esc(e.name)+'</b> · '+esc(e.scope)+'<br>'+esc(e.method)+'<br><span class="meta">'+esc(e.manual)+' '+esc(e.acceptance)+'</span></p>').join('')}else $('effects').hidden=true;
$('export').onclick=()=>blobSave(JSON.stringify({schema_version:3,kind:'NEURONS_GENERATION_PROGRESS',updated:new Date().toISOString(),form_progress:state},null,2),'NEURONS_生成进度_'+D.mode+'.json');
$('filled').onclick=()=>{const clone=document.documentElement.cloneNode(true);const next={...D,initial:state,source_progress:{...D.source_progress,form_progress:state}};clone.querySelector('#prompt-data').textContent=JSON.stringify(next).replaceAll('</','<'+String.fromCharCode(92)+'/');clone.querySelector('#items').replaceChildren();blobSave('<!doctype html>'+clone.outerHTML,'NEURONS_'+(D.mode==='scenes'?'场景':'人物动作及其他')+'_填写版.html','text/html')};
$('import').onclick=()=>$('importfile').click();$('importfile').onchange=async e=>{try{const raw=JSON.parse(await e.target.files[0].text()),data=progressMap(raw.form_progress||raw.initial||raw.art||raw);for(const [id,p]of Object.entries(data)){if(p&&typeof p==='object')state[id]={...(state[id]||{}),...p}}persist();render();toast('已导入；导出填写版后发送另一设备')}catch(e){toast('进度文件无法读取，原进度未删除')}};
</script></html>'''

if __name__=='__main__':main()
