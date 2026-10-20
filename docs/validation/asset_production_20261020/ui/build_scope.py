"""Record the frozen 38-item UI order against the actual native UI first pass.
Read-only toward source forms and assets. No acceptance statuses are changed.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
items = json.loads((ROOT/'deliverables/comprehensive_forms_20261019/data/ui_items.json').read_text(encoding='utf-8'))['items']
partial = {
 'UI_DESIGN_ATTEMPT_FEEDBACK': '现有真实事件文字已继承统一样式；专属有限过渡尚未逐关视觉验收。',
 'UI_DESIGN_PROFILE': '姓名、编号、空值和覆盖原语义保留；已认可玩家身份预览待角色资产接入，不采用旧否决图。',
 'UI_DESIGN_BODY_PREVIEW': '四向与12种反应仍是原有程序人体；需后续使用主角实际分层，不能称正式人物验收。',
 'UI_DESIGN_BOOK_EVIDENCE': '事实/机构来源文本完整保留；尚未将全部来源种类做成独立卡片层级。',
 'UI_DESIGN_TUTORIAL': '真实教学操作、隔离练习和遮罩保留，面板/按钮已改；演示身体与家具仍待正式角色接入。',
 'UI_DESIGN_TRANSITIONS': '保留原关屏、淡变和降低动效语义；全部关卡转场的正式视觉仍待组合通玩。',
 'UI_DESIGN_POINTER_KEYS': '按钮手形、可见键盘焦点及X键图块已改；世界热区光标分类尚未改写。',
}
shots = {
 'TITLE':'01_title.png', 'PROFILE':'02_profile.png', 'SAVE_CONFIRM':'07g_save_failure.png',
 'PAUSE':'04_pause.png','SETTINGS':'05_campaign_settings.png','HUD_RESOURCES':'03b_dialogue.png',
 'CRT_SHELL':'06_cast.png','SKILL_ICONS':'06_cast.png','CRT_DESCRIPTION':'06_cast.png',
 'TREE_SHELL':'06_tree.png','BODY_PREVIEW':'07_tree_inspect.png','TREE_SPIRAL':'06_tree.png',
 'TREE_INSPECT':'07_tree_inspect.png','TREE_EXCHANGE':'07_tree_inspect.png',
 'BOOK_SHELL':'06_book.png','BOOK_EVIDENCE':'06_book.png','BOOK_DETAILS':'06_book.png',
 'INVENTORY':'06_inventory.png','DIALOGUE':'03b_dialogue.png','OPENING_OVERLAY':'07c_opening_controls.png',
 'TUTORIAL':'07b_guide.png','ENDING':'07d_ending_E1.png','RUN_RECORDS':'07e_ending_records_empty.png',
}
entries = []
for item in items:
 key = item['id']; short = key.removeprefix('UI_DESIGN_')
 entries.append({
  'id':key,'name':item['name'],'group':item['group'],
  'actual_source':item.get('source',[]),
  'first_pass_status':'partial_existing_visuals' if key in partial else 'native_first_pass_integrated',
  'formal_art_accepted':False,
  'required_states_preserved':item['states'],
  'evidence':shots.get(short),
  'remaining':partial.get(key,'原生控件与共享视觉已接入；本批不替代全部状态人工通玩验收。'),
 })
changed = [
 'ui_style.gd','ui_paint.gd','ui_presentation.gd','front_end.gd','neuron_menu.gd',
 'campaign_menu.gd','vitality_panel.gd','father_prompt.gd','intervention_feedback.gd',
 'ending_panel.gd','opening_flow.gd','tutorial_overlay.gd',
]
payload = {
 'scope':'actual native UI first pass; no world/rule/form changes; no formal art acceptance',
 'items':entries,'item_count':len(entries),
 'files':[{ 'path':'neurons/scripts/ui/'+name,
            'sha256':hashlib.sha256((ROOT/'neurons/scripts/ui'/name).read_bytes()).hexdigest() } for name in changed],
 'guardrails':['原版素材不覆盖','存档语义不变','菜单/对白冻结世界','模态控件真实可点击且不穿透',
               'hover不改变选中/不付费','字体、数字、按钮均由Godot真实控件显示'],
 'verification':{'driver':'neurons/tests/ui_visual_20261020.gd','result':'result.json','gpu':'gpu.log'},
}
(OUT/'ui_scope.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf-8')
lines = [
 '# UI 原生视觉首版 · 2026-10-20',
 '',
 '本批已实际接入游戏：暖纸、石墨蓝绿、暗朱红和黄铜强调色；方角薄线、清楚正文层级、12枚原创技能矢量图标。CRT保留屏幕媒介，其余系统页采用纸张阅读层级。没有用整页图片冒充可交互控件。',
 '',
 '暂停改为真实遮罩与操作面板，原保存/读取/回标题入口移至暂停；重复HUD按钮隐藏，原回调保留。设置遮罩包含真实音量控件、数值及低动效开关。对白保留原Label/继续回调，长句进入滚动正文，不再向屏底无限撑开。原世界结算、冷却、来源、对白和存档均未改写。',
 '',
 '验证仅证明隔离档中的真实原生控件、GPU绘制与相关冻结/输入行为；不等于全局B7或所有美术状态通过。E2/E3截图使用只读结果预览夹具，不能作为自然结局达成证据。详细结果见 result.json，首次调试记录保留在 gpu_debug.log。',
 '',
 '| 原UI资产ID | 名称 | 本批状态 | 后续范围 |',
 '|---|---|---|---|',
]
for entry in entries:
 lines.append('|'+entry['id']+'|'+entry['name']+'|'+('部分改造' if entry['id'] in partial else '原生首版已接入')+'|'+entry['remaining']+'|')
lines += ['', '后续须接入主角正式分层、教学身体、开场/尾声正式画面，并在实际美术组合后复核小尺寸图标、长姓名、所有来源长列表和降低动效。当前人体/叙事画面程序占位仍明确留在剩余项，未冒充已验收素材。', '',
 '本批只改 ui/ 脚本及独立验证驱动；不改 campaign.gd、人物目录、世界数据、冻结表单和 HANDOFF。并行声音代理对 feedback_audio.gd 的改动不属于本批UI视觉工作。', '']
(OUT/'REVIEW.md').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps({'ui_items':len(entries),'partial':len(partial),'native_first_pass':len(entries)-len(partial),'manifest':str(OUT/'ui_scope.json')},ensure_ascii=False))
