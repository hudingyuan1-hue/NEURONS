extends PanelContainer
## Observe committed cycle/attempt changes. No revival is inferred from a timer.
const Style=preload("res://scripts/ui/ui_style.gd")
var app
var title:Label
var detail:Label
var _generation:int=-1
var _cycle:int=-1
var _attempts:Dictionary={}
var _hp:int=100
var _pending:Dictionary={}
var remaining:float=0.0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;position=Vector2(410,154);custom_minimum_size=Vector2(460,0);z_index=-12
 theme=Style.theme_for();add_theme_stylebox_override("panel",Style.surface("paper",true))
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",7);add_child(column)
 title=Label.new();title.add_theme_font_size_override("font_size",22);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(title)
 detail=Label.new();detail.custom_minimum_size.x=430;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 detail.add_theme_font_size_override("font_size",15);detail.add_theme_color_override("font_color",Style.MUTED);detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(detail)
 hide()
func _process(delta:float) -> void:
 if app==null or not is_instance_valid(app) or app.rules==null or app.session==null:return
 var generation:int=int(app.runtime_generation);var cycle:int=int(app.session.data.cycle)
 var attempts:Dictionary=app.session.data.get("attempts",{})
 if _generation!=generation or _cycle<0:
  _generation=generation;_cycle=cycle;_attempts=attempts.duplicate(true);_hp=app.rules.hp;remaining=0;_pending.clear();hide();return
 if app.rules.hp<=0 and _hp>0:
  _pending={"title":"身体倒下","detail":"等待实际复活流程；尚未增加尝试次数。"}
 if cycle>_cycle and attempts!=_attempts:
  var note:String=str(app.status_note)
  var heading:String="复活 / 返回第五关" if note.begins_with("Street实际复活") else "休息完成 / 新尝试" if note.begins_with("休息实际完成") else "复活 / 新尝试" if note.contains("复活") else "新尝试"
  _pending={"title":heading,"detail":"当前第%d关 · 实际尝试%d\n%s"%[int(app.session.data.level),int(app.rules.actual_attempt),note]}
 _cycle=cycle;_attempts=attempts.duplicate(true);_hp=app.rules.hp
 var blocking:bool=app.paused_manual or app.menu.visible or app.audio_panel.visible or not app.dialogue_queue.is_empty() or app.opening_ui!=null or app.tutorial_ui!=null or app.ending_panel.visible
 if not blocking and not _pending.is_empty():
  title.text=str(_pending.title);detail.text=str(_pending.detail);remaining=3.0;_pending.clear();reset_size()
 if not blocking:remaining=maxf(0,remaining-delta)
 visible=remaining>0 and not blocking
 modulate.a=1.0 if app.reduced_effects else clampf(remaining/.18,0,1)
