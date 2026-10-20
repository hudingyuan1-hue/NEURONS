extends Control
## Real campaign controls are retained. This layer changes presentation only.
const Style=preload("res://scripts/ui/ui_style.gd")
const EndingArt=preload("res://scripts/ui/ending_art.gd")
const AttemptNotice=preload("res://scripts/ui/attempt_notice.gd")
var app
var pause_veil:ColorRect
var settings_veil:ColorRect
var pause_heading:Label
var pause_notice:Label
var dialogue_scroll:ScrollContainer
var dialogue_signature:String=""
var reduced_toggle:CheckBox

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=20
 apply_campaign()
 var ending_art:=EndingArt.new();ending_art.app=app;ending_art.name="EndingArtwork";add_child(ending_art)
 var attempt_notice:=AttemptNotice.new();attempt_notice.app=app;attempt_notice.name="AttemptNotice";add_child(attempt_notice)
 settings_veil=ColorRect.new();settings_veil.size=Vector2(1280,720)
 settings_veil.color=Color(0.08,0.12,0.11,.55)
 settings_veil.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(settings_veil)
 # GUI routing follows tree order, not z_index: the real controls belong inside
 # their shield so it blocks the world without swallowing its own buttons.
 if app.audio_panel!=null:
  app.audio_panel.reparent(settings_veil)
  app.audio_panel.z_index=2
 pause_veil=ColorRect.new();pause_veil.size=Vector2(1280,720)
 pause_veil.color=Color(0.08,0.12,0.11,.60)
 pause_veil.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(pause_veil)
 var paper:=Panel.new();paper.position=Vector2(420,83);paper.size=Vector2(440,554)
 paper.theme=Style.theme_for();paper.add_theme_stylebox_override("panel",Style.surface("paper",true));pause_veil.add_child(paper)
 var tag:=Label.new();tag.text="NEURONS / 暂停";tag.position=Vector2(32,24);tag.add_theme_font_size_override("font_size",14);tag.add_theme_color_override("font_color",Style.MUTED);paper.add_child(tag)
 pause_heading=Label.new();pause_heading.text="暂时停留";pause_heading.position=Vector2(32,58);pause_heading.add_theme_font_size_override("font_size",30);paper.add_child(pause_heading)
 pause_notice=Label.new();pause_notice.position=Vector2(32,108);pause_notice.size=Vector2(376,56)
 pause_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;pause_notice.add_theme_font_size_override("font_size",15);paper.add_child(pause_notice)
 var row:int=0
 for item in [["继续游戏",func():app.paused_manual=false],["声音与界面",func():app.toggle_audio_controls()],["保存进度",func():app.save_requested=true],["读取进度",func():app.request_load=true],["保存并返回标题",func():app.request_title_return()]]:
  var b:=Button.new();b.text=item[0];b.position=Vector2(32,174+row*57);b.size=Vector2(376,45)
  Style.style_button(b);b.pressed.connect(item[1]);paper.add_child(b);row+=1
 var foot:=Label.new();foot.text="Esc 继续 / Tab 选择";foot.position=Vector2(32,501);foot.add_theme_font_size_override("font_size",14);foot.add_theme_color_override("font_color",Style.MUTED);paper.add_child(foot)
 pause_veil.hide();settings_veil.hide()

func apply_campaign() -> void:
 app.theme=Style.theme_for()
 for child in app.get_children():
  if child is ColorRect:
   if child.size.y<=140:child.color=Style.PAPER
   if child.position.y==589:child.position.y=625;child.size.y=95
  elif child is Button:
   Style.style_button(child)
   if child.position.y==603:
    if child.text in ["保存","读取","保存并回标题","设置","图书"]:child.hide()
    else:
     child.position.y=637
     if child.text=="复位视野":child.position.x=24
     elif child.text=="降低反馈":child.position.x=170
     elif child.text=="星仓":child.position.x=316
  elif child is Label:
   child.add_theme_color_override("font_color",Style.INK)
   if child.text.begins_with("当前含程序占位"):
    child.text="自主角色 / 神经干预";child.position=Vector2(28,58)
    child.add_theme_color_override("font_color",Style.MUTED)
 if app.scenario_label!=null:app.scenario_label.add_theme_font_size_override("font_size",18)
 if app.status_label!=null:app.status_label.add_theme_font_size_override("font_size",15)
 if app.state_label!=null:app.state_label.position.y=674;app.state_label.add_theme_color_override("font_color",Style.MUTED)
 if app.event_label!=null:app.event_label.position.y=696;app.event_label.add_theme_color_override("font_color",Style.TEAL)
 if app.dialogue_panel!=null:
  app.dialogue_panel.theme=Style.theme_for();app.dialogue_panel.z_index=18
  app.dialogue_panel.add_theme_stylebox_override("panel",Style.surface("paper",true))
  app.dialogue_panel.position=Vector2(155,400);app.dialogue_panel.custom_minimum_size=Vector2(970,210)
  var dialogue_column:VBoxContainer=app.dialogue_panel.get_child(0)
  dialogue_scroll=ScrollContainer.new();dialogue_scroll.custom_minimum_size.y=110
  dialogue_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
  dialogue_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
  dialogue_column.add_child(dialogue_scroll);dialogue_column.move_child(dialogue_scroll,0)
  app.dialogue_text.reparent(dialogue_scroll)
  app.dialogue_text.custom_minimum_size.x=900
  app.dialogue_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  app.dialogue_text.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
  app.dialogue_panel.reset_size()
  app.dialogue_text.add_theme_font_size_override("font_size",21)
  app.dialogue_text.add_theme_color_override("font_color",Style.INK)
  for b in app.dialogue_panel.find_children("*","Button",true,false):Style.style_button(b)
 if app.audio_panel!=null:
  app.audio_panel.theme=Style.theme_for();app.audio_panel.z_index=22
  app.audio_panel.position=Vector2(770,134);app.audio_panel.custom_minimum_size=Vector2(450,0);app.audio_panel.size=Vector2(450,0)
  app.audio_panel.add_theme_stylebox_override("panel",Style.surface("paper",true))
  var column:VBoxContainer=app.audio_panel.get_child(0)
  var reduced:=CheckBox.new();reduced.text="降低扫描线与界面动效";reduced.button_pressed=app.reduced_effects
  reduced_toggle=reduced
  reduced.add_theme_font_size_override("font_size",16)
  reduced.toggled.connect(func(value:bool):
   if value!=app.reduced_effects:app.toggle_effects()
  )
  column.add_child(reduced);column.move_child(reduced,3)
  for row in column.get_children():
   if row is HBoxContainer:
    var sliders=row.find_children("*","HSlider",true,false)
    if not sliders.is_empty():
     var slider:HSlider=sliders[0]
     var amount:=Label.new();amount.custom_minimum_size.x=38;amount.add_theme_font_size_override("font_size",15)
     amount.text="%d"%roundi(slider.value*100);row.add_child(amount)
     slider.value_changed.connect(func(value:float):amount.text="%d"%roundi(value*100))
  for b in app.audio_panel.find_children("*","Button",true,false):Style.style_button(b)
  for label in app.audio_panel.find_children("*","Label",true,false):label.add_theme_color_override("font_color",Style.INK)
 if app.menu!=null:app.menu.z_index=25

func _process(_delta:float) -> void:
 if app==null or not is_instance_valid(app):return
 var settings:bool=app.audio_panel!=null and app.audio_panel.visible
 settings_veil.visible=settings
 if reduced_toggle!=null and reduced_toggle.button_pressed!=app.reduced_effects:reduced_toggle.set_pressed_no_signal(app.reduced_effects)
 if dialogue_scroll!=null and dialogue_signature!=app.dialogue_text.text:
  dialogue_signature=app.dialogue_text.text;dialogue_scroll.scroll_vertical=0
 pause_notice.text=app.status_note
 pause_notice.add_theme_color_override("font_color",Style.OXIDE if str(app.status_note).contains("失败") else Style.MUTED)
 var blocking:bool=settings or app.menu.visible or app.tutorial_ui!=null or app.opening_ui!=null or app.ending_panel.visible
 var show_pause:bool=app.paused_manual and not blocking
 if show_pause and not pause_veil.visible:
  # Focus remains on an actual control; showing a panel never changes the world.
  var choices=pause_veil.find_children("*","Button",true,false)
  if not choices.is_empty():choices[0].grab_focus()
 pause_veil.visible=show_pause
