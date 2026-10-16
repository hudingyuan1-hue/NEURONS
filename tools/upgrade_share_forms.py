"""Upgrade the existing simplified forms without running the old generators.

Source HTML is the preserved 730bd37 edition; stable IDs, text and source
progress come from the current art_form/audio_form JSON. Output is standalone.
"""
from pathlib import Path
import base64,hashlib,json,mimetypes,re

ROOT=Path(__file__).resolve().parents[1]
FORMS=ROOT/'deliverables/NEURONS_2D_资产需求_20261015'
HISTORY=FORMS/'history/20261016_offline_share_before'
RUNTIME=(ROOT/'tools/share_form_runtime.js').read_text(encoding='utf-8')
ROOMS=json.loads((ROOT/'neurons/data/institution_spaces.json').read_text(encoding='utf-8'))['rooms']
BEDROOM=json.loads((ROOT/'neurons/data/room_spaces.json').read_text(encoding='utf-8'))['rooms']['bedroom']
NAMES={'ward':'病房','lobby':'候诊/接待','clinic':'诊室','pharmacy':'药房','office':'办公室','stairs':'既有楼梯','corridor':'二层走廊','activity':'公共活动室','group_therapy':'团体治疗室','quiet':'安静室','bathroom':'卫生间与淋浴区','double_ward':'双人病房','workshop':'作业康复室','cortex_exit':'第四关出口'}
MAP={'ART_ENV_L1_ROOM':'bedroom','ART_ENV_L2_WARD':'ward','ART_ENV_L2_LOBBY':'lobby','ART_ENV_L2_CLINIC':'clinic','ART_ENV_L2_PHARMACY':'pharmacy','ART_ENV_L2_OFFICE':'office','ART_ENV_L3_STAIRS':'stairs','ART_ENV_L3_CORRIDOR':'corridor','ART_ENV_L3_ACTIVITY':'activity','ART_ENV_L3_GROUP':'group_therapy','ART_ENV_L3_QUIET':'quiet','ART_ENV_L3_BATH':'bathroom','ART_ENV_L3_DOUBLE':'double_ward','ART_ENV_L3_WORK':'workshop'}
def packed(value):return json.dumps(value,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c')
def contract(group,room):
 cfg=BEDROOM if room=='bedroom' else ROOMS[room]
 doors=cfg.get('portals',[])
 door_text='；'.join(f"{p.get('wall','')}墙{p['wall_point']}处，净宽{p['width_m']}米，通向{NAMES.get(p['toward'],p['toward'])}" for p in doors)
 furniture='、'.join(f.get('name',f['id']) for f in cfg['furniture'])
 points='；'.join(f"{f.get('name',f['id'])}：{f.get('at',f.get('approach_m','见独立接触点'))}" for f in cfg['furniture'])
 if room=='bedroom':door_text='一扇普通房门/父亲事件血门共用同一出口；一扇猫退场窗，窗下保留实体墙，不增入口'
 if room in ['ward','lobby']:
  door_text+='；病房门共用一扇观察窗，窗心起测离地1.35米、约0.52×0.32米，沿该门墙面投影；窗扇独立，只从接待区外侧开关，不新增房门手续'
 status='当前代码中的起测布局：卧室11点、机构门流程/32点搜寻与有限人物接触已在本机运行；正常速度完整游玩与最终美术仍待确认。只可先作比例草稿，不是正式生产合同。'
 if room in ['corridor','activity','group_therapy','quiet','bathroom','double_ward','workshop']:
  status='新进L3二层八房空间试接（含既有楼梯）：原45点、七连接、6秒搜寻及原事件规则保留；实际录音/递纸/折盒/抽手、报告带离/隔离、遗物清理与跨门已有限运行。旧本章保留各自版本；正式美术/人工通玩未验收，不批量派生。'
 return {'status':status,'fields':{
  '底图范围':'完整墙地、固定远景和空门框；不画活动角色、家具、物品与UI；可移动物移走处必须补齐背景。',
  '比例与显示':f"净地面起测{cfg['size_m'][0]}×{cfg['size_m'][1]}米；1280×720观察画面，大房由镜头平移，不缩小人物硬塞同屏；母版保留约2倍统一密度。",
  '投影':'纯2D固定斜俯视，起测屏幕位移(96x+30z,56z−78h)，x/z/h以米计；不引入运行时3D。',
  '门窗与通向':door_text+'。窗洞按原稿必要元素保留，未核的数量/局部位置不擅加。',
  '必要家具':furniture,
  '接近点与通路':'逻辑接触点起测：'+points+'；身体导航半径0.21米，已做精确连续碰撞和有限实跑，不靠缩小身体过测；全部人群组合仍待验。',
  '组合与站位':'分段足迹：'+('；'.join(f["name"]+' '+str(f['collision_rects_m']) for f in cfg['furniture'] if 'collision_rects_m' in f) or '普通家具按自身足迹')+'。环座入口/淋浴开口不得用整个外包矩形封死。人物站位与桌上成品位置分别配置；不能将角色、物品和活动门扇烘入底图。',
  '活动与分层':'柜/抽屉/门扇主体与内部、活动面、前景遮挡、内容物、接地阴影分别处理；动作前后共用画布原点。固定前沿可由同底图提取，不能承诺整图无损自动拆层。',
  '来源':str(cfg.get('source',cfg.get('authority','现有空间数据与S1原拓扑；局部摆位为起测建议')))}}

CSS='''\n/* Offline sharing and narrow displays */
html,body{max-width:100%;overflow-x:clip}.prompt,pre,.file,.source-record,.source{white-space:pre-wrap;overflow-wrap:anywhere;word-break:break-word}.count{float:none;display:block}.compact{max-width:100%}.fields input{min-width:0;width:100%}button{white-space:normal;min-height:42px}dialog{width:min(630px,94vw);max-height:88vh;overflow:auto;background:#fffef9;color:#242d2b;border:1px solid #6f8d83;border-radius:9px;padding:24px}dialog::backdrop{background:#15251fe0}dialog .row{display:flex;gap:10px;flex-wrap:wrap}#manual-copy-text{width:100%;min-height:40vh;font:15px/1.6 system-ui;resize:vertical}.source-record{color:#5d6863}.bottom{display:flex;flex-wrap:wrap;gap:10px}.share-status{padding:12px 16px;background:#e7eddf;border:1px solid #b4c4af}
@media(max-width:600px){main{padding:16px 12px 60px}h1{font-size:25px}.toolbar{position:static;display:grid;grid-template-columns:1fr 1fr}.toolbar input[type=search]{grid-column:1/-1;min-width:0;width:100%}.toolbar select{min-width:0;max-width:100%;width:100%;padding:7px 3px}.body{padding:0 12px 14px}.group>summary{padding:12px;font-size:17px}.fields{display:flex;flex-direction:column}.row{flex-wrap:wrap}table{width:100%;table-layout:fixed}td,th{overflow-wrap:anywhere}.bottom>button{flex:1 1 100%}dialog{padding:16px}}
'''
DIALOGS='''<dialog id="import-choice" aria-labelledby="import-title"><h2 id="import-title">导入填写有冲突</h2><p id="conflict-summary"></p><p id="conflict-items" class="note"></p><div class="row"><button data-choice="current" autofocus>保留当前填写</button><button data-choice="incoming">使用导入填写</button><button data-choice="cancel">取消导入</button></div></dialog><dialog id="manual-copy" aria-labelledby="copy-title"><h2 id="copy-title">手动复制提示词</h2><p>内容可选择。电脑按Ctrl/Cmd+C；手机长按文字复制。</p><textarea id="manual-copy-text" readonly aria-label="待复制提示词"></textarea><button id="manual-copy-close">关闭</button></dialog>'''
for kind,filename in [('art','01_全游戏提示词表单.html'),('audio','01_音频需求表.html')]:
 data_path=FORMS/'data'/f'{kind}_form.json'
 data=json.loads(data_path.read_text(encoding='utf-8'))
 if kind=='art':
  data.setdefault('previous_shared_specs',{}).setdefault('WORLD',data['shared_specs']['WORLD'])
  data['shared_specs']['WORLD']=data['shared_specs']['WORLD'].replace('其他房型尚未按新规格实施，不据此批量重画。','医院五室/精神病院共享一层及既有楼梯已作新空间试接，有限路径/动作已运行；二层其余空间及L4/后关仍保留原几何，不据此批量重画。')
  data['shared_specs']['WORLD']=data['shared_specs']['WORLD'].replace('二层其余空间及L4/后关仍保留原几何','二层走廊/活动室也已试接并运行原事件链；其他二层房及L4/后关仍保留原几何')
  data['shared_specs']['WORLD']=data['shared_specs']['WORLD'].replace('二层走廊/活动室也已试接并运行原事件链；其他二层房及L4/后关仍保留原几何','新进第三关的二层八房（含既有楼梯）已试接，原45点与事件仍按原规则；L4/隐藏及后关空间仍保留旧几何')
 data.setdefault('previous_validation_boundary',data.get('validation_boundary',''))
 data['validation_boundary']='本机已完成50项DOM/序列化契约检查；它不是浏览器渲染、真实下载、手机或异机测试。file://浏览器工具被安全策略拒绝，实际离线双击与跨设备验收仍待；游戏有限运行证据见HANDOFF，不等于美术/听验通过。'
 data['sharing']={'version':1,'single_html':True,'embedded_references':True,'progress_schema':4,'browser_acceptance':'pending: browser tool refuses file scheme; DOM contract tests recorded separately'}
 refs={}
 for group in data['groups']:
  if kind=='art' and group['id'] in MAP:
   group['share_layout']=contract(group,MAP[group['id']])
   if 'scale_trial' in group:
    group.setdefault('previous_scale_trial',group['scale_trial'].copy())
    group['scale_trial']['status']='空间试接及有限实跑已完成；正式美术和完整人工游玩未验收，先比例草稿，不批量派生。'
  for field in ['guide','original_guide','legacy_guide']:
   value=group.get('layout',{}).get(field)
   if value:refs[value]=None
  for item in group['items']:
   if item.get('reference_file'):refs[item['reference_file']]=None
 for relative in refs:
  path=(FORMS/relative).resolve()
  if not path.is_relative_to(FORMS.resolve()) or not path.is_file():raise ValueError(f'Missing/unsafe reference {relative}')
  refs[relative]={'mime':mimetypes.guess_type(path.name)[0] or 'application/octet-stream','base64':base64.b64encode(path.read_bytes()).decode(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 base=(HISTORY/filename).read_text(encoding='utf-8')
 base=re.sub(r'<script type="application/json" id="table-data">.*?</script>',lambda _: '<script type="application/json" id="table-data">'+packed(data)+'</script>',base,count=1,flags=re.S)
 base=base.replace('</style>',CSS+'</style>',1)
 base=re.sub(r'<nav>.*?</nav>','<nav>NEURONS · 两份表各自为独立HTML，无需工程或其他文件</nav>',base,count=1,flags=re.S)
 base=re.sub(r'<p><a href="../../docs/research/space_scale_review_20261016.html">.*?</a></p>','<p>各房当前起测范围、连接和分层要求已附在条目内；未经空间复验，不批量制作正式背景。</p>',base,count=1)
 base=base.replace('<h1>','<p id="share-status" class="share-status"></p><h1>',1)
 base=base.replace('<button id="import">','<button id="download-filled">下载当前填写版网页</button><button id="import">',1)
 base=base.replace('<footer>','<p id="source-records" class="note"></p><footer>',1)
 base=base.replace('页面不会自动覆盖仓库文件，不依赖浏览器缓存。','页面不会自动覆盖仓库文件，不依赖浏览器缓存。可下载当前填写版网页，将进度直接带在HTML里。')
 base=base.replace('</main></body></html>',DIALOGS+'<script type="application/json" id="share-references">'+packed(refs)+'</script><script type="application/json" id="progress-seed">{}</script><script>'+RUNTIME+'</script></main></body></html>')
 if 'id="download-filled"' not in base or 'id="share-references"' not in base:raise ValueError('Unexpected form template')
 data_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 (FORMS/filename).write_text(base,encoding='utf-8')
 print(kind,'items',sum(len(g['items']) for g in data['groups']),'embedded images',len(refs),'html bytes',len(base.encode()))
