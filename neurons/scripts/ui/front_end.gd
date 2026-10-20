extends Control
const Campaign=preload("res://scripts/campaign.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
const Opening=preload("res://scripts/ui/opening_flow.gd")
const UIStyle=preload("res://scripts/ui/ui_style.gd")
const UIPaint=preload("res://scripts/ui/ui_paint.gd")
const UIPresentation=preload("res://scripts/ui/ui_presentation.gd")
var store=Store.new()
var active:Control
var content:VBoxContainer
var message:Label
var name_field:LineEdit
var overwrite_armed:bool=false
var preferences:Dictionary={"master":0.8,"reduced":true,"auto_status":true,"auto_dialogue":true,"channels":{"ui":0.7,"world":0.7,"ambience":0.5,"music":0.5,"voice":0.8}}
var volume_slider:HSlider
var status_box:CheckBox
var reduced_box:CheckBox
var dialogue_box:CheckBox
var pending_invader_id:int=0
var title_audio
var exiting:bool=false
var startup_opening
var title_paint

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 get_tree().auto_accept_quit=false
 get_window().close_requested.connect(request_exit)
 theme=UIStyle.theme_for()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--save-root="):store.root=argument.trim_prefix("--save-root=")
 var config:=ConfigFile.new()
 if config.load(store.root.path_join("preferences.cfg"))==OK:
  preferences.master=clampf(float(config.get_value("audio","master",0.8)),0,1)
  preferences.reduced=bool(config.get_value("visual","reduced",true))
  preferences.auto_status=bool(config.get_value("interface","auto_status",true))
  preferences.auto_dialogue=bool(config.get_value("interface","auto_dialogue",true))
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
  "--ui-design-check":"ui_visual_20261020",
  "--ui-narrative-check":"ui_narrative_20261020",
  "--all-spaces-live-check":"all_spaces_live_check",
  "--spatial-neural-sequence-check":"spatial_neural_sequence_check",
  "--street-hand-grips-check":"street_hand_grips_check",
  "--street-hand-grips-live-check":"street_hand_grips_live_check",
  "--street-double-head-check":"street_double_head_check",
  "--street-double-head-live-check":"street_double_head_live_check",
  "--street-double-face-retreat-check":"street_double_face_retreat_check",
  "--street-double-face-retreat-live-check":"street_double_face_retreat_live_check",
  "--street-mixed-crowd-check":"street_mixed_crowd_check",
  "--full-campaign-spatial-natural-check":"full_campaign_spatial_natural_check",
  "--metric-bedroom-check":"metric_bedroom_check",
  "--institution-space-check":"institution_space_check",
  "--institution-events-check":"institution_events_check",
  "--asylum-space-check":"asylum_space_check",
  "--fresh-flow-check":"fresh_flow_check",
  "--dialogue-playback-check":"dialogue_playback_check",
  "--key-discovery-check":"key_discovery_check",
  "--play-feedback-check":"play_feedback_check",
  "--combat-chapter-check":"combat_chapter_check",
  "--combat-natural-check":"combat_natural_check",
  "--combat-detail-check":"combat_detail_check",
  "--combat-evidence-check":"combat_evidence_check",
  "--street-chapter-check":"street_chapter_check",
  "--combat-noise-check":"combat_noise_check",
  "--audio-delivery-check":"audio_delivery_check",
  "--music-context-check":"music_context_check_20261019",
  "--street-natural-check":"street_natural_check",
  "--street-props-check":"street_props_check",
  "--street-materials-check":"street_materials_check",
  "--street-displays-check":"street_displays_check",
  "--street-records-check":"street_records_check",
  "--street-reports-check":"street_reports_check",
  "--street-reports-live-check":"street_reports_live_check",
  "--street-reunion-check":"street_reunion_check",
  "--street-laundry-check":"street_laundry_check",
  "--street-laundry-live-check":"street_laundry_live_check",
  "--street-losses-check":"street_losses_check",
  "--street-losses-live-check":"street_losses_live_check",
  "--street-clamp-check":"street_clamp_check",
  "--street-embrace-check":"street_embrace_check",
  "--street-embrace-live-check":"street_embrace_live_check",
  "--street-medicine-check":"street_medicine_check",
  "--street-medicine-live-check":"street_medicine_live_check",
  "--street-splash-check":"street_splash_check",
  "--street-splash-live-check":"street_splash_live_check",
  "--street-bottle-check":"street_bottle_check",
  "--street-belt-check":"street_belt_check",
  "--street-restraint-check":"street_restraint_check",
  "--street-grasp-check":"street_grasp_check",
  "--street-director-check":"street_director_check",
  "--street-limbs-check":"street_limbs_check",
  "--street-limbs-live-check":"street_limbs_live_check",
  "--street-director-live-check":"street_director_live_check",
  "--street-door-block-check":"street_door_block_check",
  "--street-grasp-live-check":"street_grasp_live_check",
  "--street-belt-live-check":"street_belt_live_check",
  "--street-records-live-check":"street_records_live_check",
  "--street-displays-live-check":"street_displays_live_check",
  "--street-bed-travel-check":"street_bed_travel_check",
  "--street-bed-travel-live-check":"street_bed_travel_live_check",
  "--street-materials-live-check":"street_materials_live_check",
  "--street-props-live-check":"street_props_live_check",
  "--achievement-events-check":"achievement_events_check",
  "--cortex-check":"cortex_check",
  "--cortex-navigation-check":"cortex_navigation_check",
  "--cortex-events-check":"cortex_events_check",
  "--cortex-upper-check":"cortex_upper_check",
  "--continue-cortex-check":"continue_cortex_check",
  "--cortex-sequence-check":"cortex_sequence_check",
  "--hospital-early-transfer-check":"hospital_early_transfer_check",
  "--asylum-window-check":"asylum_window_check",
  "--hospital-relic-retry-check":"hospital_relic_retry_check",
  "--asylum-intake-chain-check":"asylum_intake_chain_check",
  "--asylum-evidence-sequence-check":"asylum_evidence_sequence_check",
  "--asylum-details-check":"asylum_details_check",
  "--hospital-relic-packing-check":"hospital_relic_packing_check",
  "--asylum-ward-evidence-check":"asylum_ward_evidence_check", "--asylum-combinations-check":"asylum_combinations_check", "--asylum-intake-check":"asylum_intake_check",
  "--asylum-registration-mouse-check":"asylum_registration_mouse_check", "--asylum-chain-check":"asylum_chain_check", "--asylum-observation-check":"asylum_observation_check", "--asylum-registration-check":"asylum_registration_check", "--asylum-nurse-duty-check":"asylum_nurse_duty_check",
  "--natural-asylum-check":"natural_asylum_check", "--asylum-trace-check":"asylum_trace_check", "--asylum-ward-check":"asylum_ward_check", "--asylum-isolation-check":"asylum_isolation_check", "--asylum-record-check":"asylum_record_check", "--asylum-records-check":"asylum_records_check", "--asylum-ui-check":"asylum_ui_check", "--continue-asylum-check":"continue_asylum_check", "--asylum-check":"asylum_check", "--asylum-events-check":"asylum_events_check", "--campaign-check":"campaign_check", "--b1-check":"b1_check", "--b1-acceptance-check":"b1_acceptance_check", "--hospital-observation-check":"hospital_observation_check", "--hospital-edges-check":"hospital_edges_check", "--hospital-check":"hospital_check", "--hidden-campaign-check":"hidden_campaign_check", "--opening-campaign-check":"opening_campaign_check",
  "--animals-check":"animals_check", "--family-check":"family_check",
  "--story-record":"story_record", "--search-actions-check":"search_actions_check",
  "--tutorial-check":"tutorial_check", "--awareness-check":"awareness_check",
  "--natural-hospital-check":"natural_hospital_check", "--natural-home-check":"natural_home_check", "--home-adverse-check":"home_adverse_check", "--feedback-check":"feedback_check", "--rest-input-check":"rest_input_check", "--family-sequence-check":"family_sequence_check", "--status-check":"status_check", "--tutorial-input-check":"tutorial_input_check", "--persistence-ui-check":"persistence_ui_check"}
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
 title_audio.set_music("MUS_MENU")
 var bg:=UIPaint.new()
 title_paint=bg
 add_child(bg)
 var edition:=Label.new();edition.text="自主角色 / 神经干预";edition.position=Vector2(78,42)
 edition.add_theme_font_size_override("font_size",14);edition.add_theme_color_override("font_color",UIStyle.MUTED);add_child(edition)
 content=VBoxContainer.new()
 content.position=Vector2(78,116)
 content.size=Vector2(470,500)
 content.add_theme_constant_override("separation",18)
 add_child(content)
 var title:=Label.new()
 title.text="NEURONS"
 title.add_theme_font_size_override("font_size",58)
 content.add_child(title)
 message=Label.new()
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 message.text="他选择去路。\n你改变身体的回应。"
 message.add_theme_color_override("font_color",UIStyle.MUTED)
 message.add_theme_font_size_override("font_size",19)
 message.custom_minimum_size.y=82
 content.add_child(message)
 add_button("继续游戏",continue_game,not store.load_snapshot().ok)
 add_button("建立档案",show_profile)
 add_button("设置",show_settings)
 add_button("退出",request_exit)

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
 button.name=callback.get_method()
 button.text=text
 button.custom_minimum_size=Vector2(470,46)
 button.alignment=HORIZONTAL_ALIGNMENT_LEFT
 UIStyle.style_button(button)
 button.disabled=disabled
 button.pressed.connect(callback)
 content.add_child(button)
 return button

func show_profile() -> void:
 if is_instance_valid(title_paint):title_paint.variant="profile";title_paint.queue_redraw()
 for child in content.get_children():child.queue_free()
 await get_tree().process_frame
 var label:=Label.new()
 label.text="玩家姓名 / 入侵者档案"
 label.add_theme_font_size_override("font_size",26)
 content.add_child(label)
 name_field=LineEdit.new()
 name_field.max_length=24
 name_field.custom_minimum_size.y=48
 pending_invader_id=randi_range(1000,9999)
 name_field.text="张%d"%pending_invader_id
 content.add_child(name_field)
 var number:=Label.new();number.text="档案编号 / %04d"%pending_invader_id
 number.add_theme_font_size_override("font_size",14);number.add_theme_color_override("font_color",UIStyle.MUTED);content.add_child(number)
 message=Label.new()
 message.text="输入姓名，建立本次档案。"
 message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 message.custom_minimum_size.y=64
 message.add_theme_color_override("font_color",UIStyle.MUTED)
 content.add_child(message)
 overwrite_armed=false
 add_button("建立并开始",new_game)
 add_button("返回",create_title)
 name_field.grab_focus()

func new_game() -> void:
 if name_field.text.strip_edges().is_empty():
  message.text="请输入玩家姓名。"
  return
 if store.load_snapshot().ok and not overwrite_armed:
  overwrite_armed=true
  message.text="已有档案；再次点击“建立并开始”确认覆盖（保留上一份备份）。"
  return
 var profile:Dictionary={"name":name_field.text.strip_edges(),"invader_id":pending_invader_id,"tutorial_completed":false,"opening_completed":is_check_run() and not "--opening-campaign-check" in OS.get_cmdline_user_args() and not "--full-campaign-spatial-natural-check" in OS.get_cmdline_user_args()}
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
 active.auto_dialogue_enabled=bool(preferences.auto_dialogue)
 active.store.root=store.root
 active.return_to_title.connect(close_campaign)
 active.new_game_requested.connect(func():close_campaign();show_profile())
 add_child(active)
 var presentation:=UIPresentation.new();presentation.name="UIPresentation";presentation.app=active;active.add_child(presentation)
 active.audio.set_level("master",float(preferences.master))
 for channel in preferences.channels:active.audio.set_level(channel,float(preferences.channels[channel]))
 active.audio.level_changed.connect(func(channel:String,value:float):
  if channel=="master":preferences.master=value
  else:preferences.channels[channel]=value
  save_preferences()
 )
 active.status_preferences_changed.connect(func(value:bool):preferences.auto_status=value;save_preferences())
 active.dialogue_preferences_changed.connect(func(value:bool):preferences.auto_dialogue=value;save_preferences())
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
 heading.text="声音与界面\n总音量"
 heading.add_theme_font_size_override("font_size",24)
 content.add_child(heading)
 volume_slider=HSlider.new()
 volume_slider.min_value=0
 volume_slider.max_value=1
 volume_slider.step=0.01
 volume_slider.value=float(preferences.master)
 content.add_child(volume_slider)
 reduced_box=CheckBox.new()
 reduced_box.text="降低扫描线与界面动效"
 reduced_box.add_theme_font_size_override("font_size",16)
 reduced_box.button_pressed=bool(preferences.reduced)
 content.add_child(reduced_box)
 status_box=CheckBox.new()
 status_box.text="受伤后自动显示角色状态（X可手动开关）"
 status_box.add_theme_font_size_override("font_size",16)
 status_box.button_pressed=bool(preferences.auto_status)
 content.add_child(status_box)
 dialogue_box=CheckBox.new()
 dialogue_box.text="对白自动继续 (关闭后手动继续)"
 dialogue_box.add_theme_font_size_override("font_size",16)
 dialogue_box.button_pressed=bool(preferences.auto_dialogue)
 content.add_child(dialogue_box)
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
 preferences.auto_dialogue=dialogue_box.button_pressed
 if is_instance_valid(title_audio):title_audio.set_level("master",float(preferences.master))
 AudioServer.set_bus_volume_db(0,0) # Per-channel master gain is applied once in FeedbackAudio.
 var config:=ConfigFile.new()
 config.set_value("audio","master",preferences.master)
 config.set_value("visual","reduced",preferences.reduced)
 config.set_value("interface","auto_status",preferences.auto_status)
 config.set_value("interface","auto_dialogue",preferences.auto_dialogue)
 for channel in preferences.channels:config.set_value("audio",channel,preferences.channels[channel])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.root))
 var result:int=config.save(store.root.path_join("preferences.cfg"))
 message.text="设置已保存" if result==OK else "设置本次有效；文件无法写入：%s"%result

func save_preferences() -> void:
 var config:=ConfigFile.new()
 config.set_value("audio","master",preferences.master)
 config.set_value("visual","reduced",preferences.reduced)
 config.set_value("interface","auto_status",preferences.auto_status)
 config.set_value("interface","auto_dialogue",preferences.auto_dialogue)
 for channel in preferences.channels:config.set_value("audio",channel,preferences.channels[channel])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.root))
 config.save(store.root.path_join("preferences.cfg"))

