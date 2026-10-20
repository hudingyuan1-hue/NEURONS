extends PanelContainer
const UIStyle=preload("res://scripts/ui/ui_style.gd")
## Read-only live guidance. Buttons focus existing CRT nodes; never cast/pay.
signal node_requested(id:String)
var heading:Label
var body:Label
var grid:GridContainer
var buttons:Dictionary={}
var app

func _ready() -> void:
 position=Vector2(816,147)
 custom_minimum_size=Vector2(430,0)
 mouse_filter=Control.MOUSE_FILTER_STOP
 theme=UIStyle.theme_for()
 var box:=UIStyle.surface("paper",true)
 box.border_color=UIStyle.OXIDE
 box.set_border_width_all(1);box.set_content_margin_all(10)
 add_theme_stylebox_override("panel",box)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);add_child(column)
 heading=Label.new();heading.add_theme_font_size_override("font_size",18);column.add_child(heading)
 body=Label.new();body.custom_minimum_size.x=408;body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body.add_theme_font_size_override("font_size",14);column.add_child(body)
 grid=GridContainer.new();grid.columns=3;column.add_child(grid)
 for id in ["SKIN","GUT","PORES","TEMP","TINNITUS","DRYMOUTH","KNEE","WITHDRAW","STARTLE","FEAR","JOY","CONTROL"]:
  var button:=Button.new();button.custom_minimum_size=Vector2(130,29)
  button.add_theme_font_size_override("font_size",14)
  UIStyle.style_button(button)
  button.pressed.connect(func():node_requested.emit(id))
  grid.add_child(button);buttons[id]=button
 hide()

func refresh() -> void:
 var info:Dictionary=app.family.prompt_info()
 visible=not info.is_empty() and not app.paused_manual and not app.menu.visible and not app.audio_panel.visible and app.tutorial_ui==null and app.dialogue_queue.is_empty() and app.closing_left<=0
 if not visible:return
 heading.text="思考 · 神经干预" if info.mode=="think" else "救援 · 神经干预"
 body.text="\n".join(info.lines)+"\n点亮项可在神经菜单中查看；提交仍需费用与实际生效。"
 for id in buttons:
  var unlocked:bool=app.rules.skill_states[id].unlocked
  var eligible:bool=id in info.skills and unlocked
  var reason:String=app.rules.availability(id,app.skill_context()) if eligible else "locked"
  buttons[id].visible=eligible
  buttons[id].disabled=not reason.is_empty()
  buttons[id].text=str(app.rules.spec(id).name)
  buttons[id].tooltip_text="查看节点" if reason.is_empty() else app.menu.reason_text(reason)
 size.y=0 # Let the content shrink when the active branch changes.
