extends Control
const Campaign=preload("res://scripts/campaign.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
const Opening=preload("res://scripts/ui/opening_flow.gd")
var store=Store.new()
var active:Control
var content:VBoxContainer
var message:Label
var name_field:LineEdit
var overwrite_armed:bool=false
var preferences:Dictionary={"master":0.8,"reduced":true,"auto_status":true,"channels":{"ui":0.7,"world":0.7,"ambience":0.5,"music":0.5,"voice":0.8}}
var volume_slider:HSlider
var status_box:CheckBox
var reduced_box:CheckBox
var pending_invader_id:int=0
var title_audio
var exiting:bool=false
var startup_opening

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 get_tree().auto_accept_quit=false
 get_window().close_requested.connect(request_exit)
 theme=Theme.new()
 theme.default_font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 theme.default_font_size=21
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--save-root="):store.root=argument.trim_prefix("--save-root=")
 var config:=ConfigFile.new()
 if config.load(store.root.path_join("preferences.cfg"))==OK:
  preferences.master=clampf(float(config.get_value("audio","master",0.8)),0,1)
  preferences.reduced=bool(config.get_value("visual","reduced",true))
  preferences.auto_status=bool(config.get_value("interface","auto_status",true))
  for channel in preferences.channels:preferences.channels[channel]=clampf(float(config.get_value("audio",channel,preferences.channels[channel])),0,1)
 if "--visual-check" in OS.get_cmdline_user_args() or "--bedside-check" in OS.get_cmdline_user_args():
  call_deferred("open_legacy_check")
  return
 create_title()
 if not is_check_run():
  startup_opening=Opening.new();startup_opening.reduced_effects=bool(preferences.reduced)
  add_child(startup_opening)
  startup_opening.completed.connect(func(_sequence,_skipped):startup_opening.queue_free();startup_opening=null)
  startup_opening.start("startup")
 var checks:Dictionary={
  "--campaign-check":"campaign_check", "--b1-check":"b1_check", "--b1-acceptance-check":"b1_acceptance_check", "--hospital-check":"hospital_check", "--hidden-campaign-check":"hidden_campaign_check", "--opening-campaign-check":"opening_campaign_check",
  "--animals-check":"animals_check", "--family-check":"family_check",
  "--story-record":"story_record", "--search-actions-check":"search_actions_check",
  "--tutorial-check":"tutorial_check", "--awareness-check":"awareness_check",
  "--natural-home-check":"natural_home_check", "--home-adverse-check":"home_adverse_check", "--feedback-check":"feedback_check", "--rest-input-check":"rest_input_check", "--family-sequence-check":"family_sequence_check", "--status-check":"status_check", "--tutorial-input-check":"tutorial_input_check", "--persistence-ui-check":"persistence_ui_check"}
 for argument in OS.get_cmdline_user_args():
  if checks.has(argument):
   if store.root=="user://profiles":store.root="res://../tmp/check_saves/"+str(checks[argument])
   var driver:=Node.new()
   driver.set_script(load("res://tests/%s.gd"%checks[argument]))
   add_child(driver)
   break

func is_check_run() -> bool:
 for argument in OS.get_cmdline_user_args():
  if argument.ends_with("-check") or argument=="--story-record":return true
 return false

func open_legacy_check() -> void:
 get_tree().change_scene_to_file("res://scenes/bedroom_sample.tscn")

func clear_title() -> void:
 for child in get_children():
  if child.name=="CampaignCheck":continue
  if child==active:continue
  remove_child(child)
  child.queue_free()

func create_title() -> void:
 clear_title()
 title_audio=Feedback.new()
 add_child(title_audio)
 title_audio.set_level("master",float(preferences.master))
 title_audio.cue("MUS_MENU","title")
 var bg:=ColorRect.new()
 bg.color=Color("17272a")
 bg.size=Vector2(1280,720)
 bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(bg)
 content=VBoxContainer.new()
 content.position=Vector2(360,110)
 content.size=Vector2(560,500)
 content.add_theme_constant_override("separation",16)
 add_child(content)
 var title:=Label.new()
 title.text="N E U R O N S"
 title.add_theme_font_size_override("font_size",42)
 content.add_child(title)
 message=Label.new()
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 message.text="自主行动与神经干预\n当前开发批次：开场、首关、医院人物与隐藏Street；画面使用标注占位，后续关卡继续制作。"
 content.add_child(message)
 add_button("CONTINUE / 继续",continue_game,not store.load_snapshot().ok)
 add_button("NEW GAME / 建立档案",show_profile)
 add_button("SETTING / 设置",show_settings)
 add_button("EXIT / 退出",request_exit)

func request_exit(exit_code:int=0) -> void:
 if exiting:return
 exiting=true
 if is_instance_valid(active):active.paused_manual=true
 for sound in get_tree().get_nodes_in_group("neurons_audio"):
  sound.reset_scene()
 # Audio mixing is asynchronous wall time, independent of fixed-FPS movie
 # capture. The world is already frozen; this is process teardown only.
 var retire_at:int=Time.get_ticks_msec()+100
 while Time.get_ticks_msec()<retire_at:await get_tree().process_frame
 get_tree().quit(exit_code)

func add_button(text:String,callback:Callable,disabled:bool=false) -> Button:
 var button:=Button.new()
 button.text=text
 button.custom_minimum_size=Vector2(560,43)
 button.disabled=disabled
 button.pressed.connect(callback)
 content.add_child(button)
 return button

func show_profile() -> void:
 for child in content.get_children():child.queue_free()
 await get_tree().process_frame
 var label:=Label.new()
 label.text="玩家姓名 / 入侵者档案"
 content.add_child(label)
 name_field=LineEdit.new()
 name_field.max_length=24
 pending_invader_id=randi_range(1000,9999)
 name_field.text="张%d"%pending_invader_id
 content.add_child(name_field)
 message=Label.new()
 message.text="统一玩家小怪物采用占位；正式造型由你制作。"
 content.add_child(message)
 overwrite_armed=false
 add_button("建立并开始",new_game)
 add_button("返回",create_title)

func new_game() -> void:
 if name_field.text.strip_edges().is_empty():
  message.text="请输入玩家姓名。"
  return
 if store.load_snapshot().ok and not overwrite_armed:
  overwrite_armed=true
  message.text="已有档案；再次点击“建立并开始”确认覆盖（保留上一份备份）。"
  return
 var profile:Dictionary={"name":name_field.text.strip_edges(),"invader_id":pending_invader_id,"tutorial_completed":false,"opening_completed":is_check_run() and not "--opening-campaign-check" in OS.get_cmdline_user_args()}
 launch(profile,{})
 active.save_requested=true

func continue_game() -> void:
 var result:Dictionary=store.load_snapshot()
 if not result.ok:
  message.text="存档无法读取"
  return
 launch(result.data.profile,result.data)

func launch(profile:Dictionary,snapshot:Dictionary) -> void:
 if is_instance_valid(title_audio):title_audio.reset_scene()
 clear_title()
 active=Campaign.new()
 active.name="Campaign"
 active.profile=profile
 active.loaded=snapshot
 active.reduced_effects=bool(preferences.reduced)
 active.auto_status_enabled=bool(preferences.auto_status)
 active.store.root=store.root
 active.return_to_title.connect(close_campaign)
 add_child(active)
 active.audio.set_level("master",float(preferences.master))
 for channel in preferences.channels:active.audio.set_level(channel,float(preferences.channels[channel]))
 active.audio.level_changed.connect(func(channel:String,value:float):
  if channel=="master":preferences.master=value
  else:preferences.channels[channel]=value
  save_preferences()
 )
 active.status_preferences_changed.connect(func(value:bool):preferences.auto_status=value;save_preferences())
 active.visual_preferences_changed.connect(func(value:bool):preferences.reduced=value;save_preferences())
 active.reduced_effects=bool(preferences.reduced)
 active.menu.reduced_effects=bool(preferences.reduced)

func close_campaign() -> void:
 if active!=null:
  active.audio.reset_scene()
  remove_child(active)
  active.queue_free()
  active=null
 create_title()

func show_settings() -> void:
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
 var heading:=Label.new()
 heading.text="SETTING / 设置\n主音量"
 content.add_child(heading)
 volume_slider=HSlider.new()
 volume_slider.min_value=0
 volume_slider.max_value=1
 volume_slider.step=0.01
 volume_slider.value=float(preferences.master)
 content.add_child(volume_slider)
 reduced_box=CheckBox.new()
 reduced_box.text="降低扫描线与界面动效"
 reduced_box.button_pressed=bool(preferences.reduced)
 content.add_child(reduced_box)
 status_box=CheckBox.new()
 status_box.text="受伤后自动显示角色状态（X可手动开关）"
 status_box.button_pressed=bool(preferences.auto_status)
 content.add_child(status_box)
 message=Label.new()
 message.text="游戏内还可分别调整音乐、环境、世界反馈和对白。"
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 content.add_child(message)
 add_button("应用并保存",apply_settings)
 add_button("返回",create_title)

func apply_settings() -> void:
 preferences.master=volume_slider.value
 preferences.reduced=reduced_box.button_pressed
 preferences.auto_status=status_box.button_pressed
 if is_instance_valid(title_audio):title_audio.set_level("master",float(preferences.master))
 AudioServer.set_bus_volume_db(0,0) # Per-channel master gain is applied once in FeedbackAudio.
 var config:=ConfigFile.new()
 config.set_value("audio","master",preferences.master)
 config.set_value("visual","reduced",preferences.reduced)
 config.set_value("interface","auto_status",preferences.auto_status)
 for channel in preferences.channels:config.set_value("audio",channel,preferences.channels[channel])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.root))
 var result:int=config.save(store.root.path_join("preferences.cfg"))
 message.text="设置已保存" if result==OK else "设置本次有效；文件无法写入：%s"%result

func save_preferences() -> void:
 var config:=ConfigFile.new()
 config.set_value("audio","master",preferences.master)
 config.set_value("visual","reduced",preferences.reduced)
 config.set_value("interface","auto_status",preferences.auto_status)
 for channel in preferences.channels:config.set_value("audio",channel,preferences.channels[channel])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.root))
 config.save(store.root.path_join("preferences.cfg"))

