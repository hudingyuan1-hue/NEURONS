extends PanelContainer
## Presentation only. Lifetime follows actual completed actions, never seconds.
var auto_enabled:bool=true
var manual_open:bool=false
var pending_damage:bool=false
var auto_open:bool=false
var hint_acknowledged:bool=false
var last_action:String=""
var values:Label
var hp_bar:ProgressBar
var sp_bar:ProgressBar
var hint:Label
var reduced_effects:bool=false
var hint_row:HBoxContainer
var keycap:PanelContainer
var hint_demo_seen:bool=false
var hint_demo_time:float=0.0
var hint_demo_running:bool=false
const HINT_PRESS_COUNT:int=3
const HINT_PRESS_CYCLE:float=1.1

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 set_process(false)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 position=Vector2(20,150)
 custom_minimum_size=Vector2(280,92)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("1b302eed");style.border_color=Color("8faaa0")
 style.set_border_width_all(1);style.set_content_margin_all(9)
 add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();add_child(column)
 values=Label.new();values.add_theme_font_size_override("font_size",16);column.add_child(values)
 for color in [Color("b46b64"),Color("86a9bc")]:
  var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(258,7)
  bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var fill:=StyleBoxFlat.new();fill.bg_color=color;bar.add_theme_stylebox_override("fill",fill)
  var base:=StyleBoxFlat.new();base.bg_color=Color("10201f");bar.add_theme_stylebox_override("background",base)
  column.add_child(bar)
  if hp_bar==null:hp_bar=bar
  else:sp_bar=bar
 hint_row=HBoxContainer.new();hint_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint_row.add_theme_constant_override("separation",10);column.add_child(hint_row)
 var key_area:=Control.new();key_area.custom_minimum_size=Vector2(44,40)
 key_area.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint_row.add_child(key_area)
 var key_base:=PanelContainer.new();key_base.position=Vector2(1,5);key_base.size=Vector2(40,32)
 key_base.mouse_filter=Control.MOUSE_FILTER_IGNORE;key_area.add_child(key_base)
 var base_style:=StyleBoxFlat.new();base_style.bg_color=Color("0d1c1c")
 base_style.border_color=Color("607b72");base_style.set_border_width_all(1)
 base_style.set_corner_radius_all(4);key_base.add_theme_stylebox_override("panel",base_style)
 keycap=PanelContainer.new();keycap.position=Vector2(1,1);keycap.size=Vector2(40,32)
 keycap.mouse_filter=Control.MOUSE_FILTER_IGNORE;key_area.add_child(keycap)
 var key_style:=StyleBoxFlat.new();key_style.bg_color=Color("405950")
 key_style.border_color=Color("c4d2b7");key_style.set_border_width_all(1)
 key_style.set_corner_radius_all(4);keycap.add_theme_stylebox_override("panel",key_style)
 var letter:=Label.new();letter.text="X";letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 letter.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;letter.add_theme_font_size_override("font_size",20)
 letter.add_theme_color_override("font_color",Color("e3e6ce"));keycap.add_child(letter)
 hint=Label.new();hint.text="按 X 调出或关闭\n角色状态";hint.add_theme_font_size_override("font_size",13);hint_row.add_child(hint)
 refresh(100,100)

func set_reduced_effects(value:bool) -> void:
 reduced_effects=value
 if value:_stop_hint_demo()

func _stop_hint_demo() -> void:
 hint_demo_running=false
 set_process(false)
 if keycap!=null:keycap.position=Vector2(1,1)

func _process(delta:float) -> void:
 # This bounded UI demonstration can run during world pause. It never changes
 # visibility lifetime, acknowledgement, damage, resources or action timing.
 if not is_visible_in_tree() or hint_acknowledged or reduced_effects:
  _stop_hint_demo();return
 hint_demo_time+=delta
 if hint_demo_time>=HINT_PRESS_CYCLE*HINT_PRESS_COUNT:
  _stop_hint_demo();return
 var phase:float=fmod(hint_demo_time,HINT_PRESS_CYCLE)
 var press:float=0.0
 if phase>=0.25 and phase<0.43:press=smoothstep(0.25,0.43,phase)
 elif phase>=0.43 and phase<0.58:press=1.0
 elif phase>=0.58 and phase<0.76:press=1.0-smoothstep(0.58,0.76,phase)
 keycap.position=Vector2(1,1+3.0*press)

func damaged() -> void:
 if auto_enabled and not manual_open:pending_damage=true

func present_after_feedback() -> void:
 if pending_damage and auto_enabled:
  pending_damage=false;auto_open=true

func action_completed(id:String) -> void:
 if id.is_empty() or id==last_action:return
 last_action=id
 auto_open=false

func toggle_manual() -> void:
 var was_open:bool=manual_open or auto_open
 manual_open=not was_open;auto_open=false;pending_damage=false
 hint_acknowledged=true

func set_automatic(value:bool) -> void:
 auto_enabled=value
 if not value:pending_damage=false;auto_open=false

func clear_transient() -> void:
 pending_damage=false;auto_open=false

func refresh(hp:int,sp:int) -> void:
 visible=manual_open or auto_open
 values.text="生命 %d / 100    精神 %d / 100"%[hp,sp]
 hp_bar.value=hp;sp_bar.value=sp
 hint.visible=not hint_acknowledged
 hint_row.visible=hint.visible
 if visible and hint.visible and not hint_demo_seen:
  hint_demo_seen=true
  if not reduced_effects:
   hint_demo_time=0.0;hint_demo_running=true;set_process(true)
 elif not visible or not hint.visible:
  _stop_hint_demo()

func snapshot() -> Dictionary:
 return {"manual":manual_open,"pending":pending_damage,"automatic":auto_open,"hint_acknowledged":hint_acknowledged,"last_action":last_action,"hint_demo_seen":hint_demo_seen}

func restore(state:Dictionary,legacy_visible:bool=false) -> void:
 manual_open=bool(state.get("manual",legacy_visible))
 pending_damage=bool(state.get("pending",false)) and auto_enabled
 auto_open=bool(state.get("automatic",false)) and auto_enabled
 hint_acknowledged=bool(state.get("hint_acknowledged",false))
 last_action=str(state.get("last_action",""))
 hint_demo_seen=bool(state.get("hint_demo_seen",false))
 _stop_hint_demo()
