extends "res://scripts/bedroom_sample.gd"
## First real campaign batch: profile, durable attempt, L1/L2 exploration.
## NPC branches and subsequent levels remain explicitly in the coverage list.
signal return_to_title
signal new_game_requested
signal visual_preferences_changed(value:bool)
signal status_preferences_changed(value:bool)
const BedroomLayout=preload("res://scripts/world/bedroom_layout.gd")
const InstitutionLayout=preload("res://scripts/world/institution_layout.gd")
const Session=preload("res://scripts/core/campaign_session.gd")
const Store=preload("res://scripts/core/save_store.gd")
const CampaignView=preload("res://scripts/world/campaign_view.gd")
const NeuralRules=preload("res://scripts/core/neural_rules.gd")
const CampaignMenu=preload("res://scripts/ui/campaign_menu.gd")
const HomeAnimals=preload("res://scripts/core/home_animals.gd")
const FamilyEvents=preload("res://scripts/core/family_events.gd")
const SearchActions=preload("res://scripts/presentation/search_actions.gd")
const FatherPrompt=preload("res://scripts/ui/father_prompt.gd")
const VitalityPanel=preload("res://scripts/ui/vitality_panel.gd")
const Tutorial=preload("res://scripts/ui/tutorial_overlay.gd")
const HospitalEvents=preload("res://scripts/core/hospital_events.gd")
const HospitalRecords=preload("res://scripts/core/hospital_records.gd")
const HospitalObservations=preload("res://scripts/core/hospital_observations.gd")
const HiddenStreet=preload("res://scripts/core/hidden_street.gd")
const HiddenLayout=preload("res://scripts/world/hidden_layout.gd")
const Achievements=preload("res://scripts/core/achievement_store.gd")
const Opening=preload("res://scripts/ui/opening_flow.gd")
const EndingPanel=preload("res://scripts/ui/ending_panel.gd")
const AsylumMap=preload("res://scripts/core/asylum_map.gd")
const AsylumLayout=preload("res://scripts/world/asylum_layout.gd")
const AsylumEvents=preload("res://scripts/core/asylum_events.gd")
const AsylumWardEvents=preload("res://scripts/core/asylum_ward_events.gd")
const AsylumRecords=preload("res://scripts/core/asylum_records.gd")
const AsylumTrace=preload("res://scripts/core/asylum_trace_events.gd")
const AsylumIsolation=preload("res://scripts/core/asylum_isolation.gd")
const AsylumObservations=preload("res://scripts/core/asylum_observations.gd")
const AsylumIntake=preload("res://scripts/core/asylum_intake.gd")
const AsylumNurseDuty=preload("res://scripts/core/asylum_nurse_duty.gd")
const CortexMap=preload("res://scripts/core/cortex_map.gd")
const CortexLayout=preload("res://scripts/world/cortex_layout.gd")
const CortexEvents=preload("res://scripts/core/cortex_events.gd")
const CortexUpperEvents=preload("res://scripts/core/cortex_upper_events.gd")
var session=Session.new()
var store=Store.new()
var profile:Dictionary={}
var loaded:Dictionary={}
var room_id:String="bedroom"
var visible_doors:Array=[]
var action_phase:String="autonomy"
var action_left:float=0.0
var destination:String=""
var status_note:String=""
var runtime_generation:int=1
var institution_layouts:Dictionary={}
var save_requested:bool=false
var title_requested:bool=false
var new_profile_requested:bool=false
var presentation_id:String="a"
var campaign_ready:bool=false
var request_load:bool=false
var deferred_targets:Dictionary={}
var motion:Dictionary={}
var controlled_route:bool=false
var control_end_button:Button
var footstep_left:float=0.0
var footstep_serial:int=0
var home
var family
var death_left:float=0.0
var first_damage_pending:bool=false
var search_actions
var route_action_origin:String="autonomous"
var search_action_origin:String="autonomous"
var tutorial_ui
var vitality_panel
var father_prompt
var auto_status_box:CheckBox
var auto_status_enabled:bool=true
var hospital
var hidden_route
var achievements
var restoring:bool=false
var opening_ui
var asylum
var cortex
var ending_panel

func make_menu() -> Control:
 return CampaignMenu.new()

func toggle_effects() -> void:
 super.toggle_effects()
 visual_preferences_changed.emit(reduced_effects)

func create_world() -> void:
 super.create_world()
 var previous:Node=view
 view=CampaignView.new()
 view.app=self
 view.layout=layout
 view.font=sample_font
 world_viewport.add_child(view)
 previous.remove_child(camera)
 view.add_child(camera)
 previous.queue_free()

func create_ui() -> void:
 var top:=ColorRect.new()
 top.color=Color("202a2f")
 top.size=Vector2(1280,100)
 top.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(top)
 label_at("N E U R O N S",Vector2(28,15),24)
 scenario_label=label_at("",Vector2(365,16),20)
 label_at("程序占位 · 自主探索与人物分支 · 后续关卡待接",Vector2(365,53),13)
 button_at("暂停",Vector2(1130,42),105,func():paused_manual=not paused_manual)
 button_at("设置",Vector2(900,42),95,toggle_audio_controls)
 button_at("图书",Vector2(795,42),95,func():open_system_page("book"))
 button_at("操作指引",Vector2(1005,42),115,func():open_tutorial(true))
 var footer:=ColorRect.new()
 footer.position=Vector2(0,589)
 footer.size=Vector2(1280,131)
 footer.color=Color("202a2f")
 footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(footer)
 button_at("保存",Vector2(24,603),110,func():save_requested=true)
 button_at("读取",Vector2(145,603),110,func():request_load=true)
 button_at("保存并回标题",Vector2(266,603),130,request_title_return)
 button_at("设置",Vector2(410,603),100,toggle_audio_controls)
 button_at("复位视野",Vector2(522,603),130,reset_zoom)
 button_at("降低反馈",Vector2(665,603),130,toggle_effects)
 button_at("图书",Vector2(805,603),100,func():open_system_page("book"))
 button_at("冰柜",Vector2(915,603),100,func():open_system_page("tree"))
 control_end_button=button_at("交回控制",Vector2(1030,603),125,func():rules.end_control();cancel_control_route())
 control_end_button.hide()
 state_label=label_at("",Vector2(24,649),14)
 event_label=label_at("",Vector2(24,679),13)
 for bounds in [Rect2(16,106,650,34),Rect2(765,106,490,34)]:
  var plate:=ColorRect.new()
  plate.position=bounds.position
  plate.size=bounds.size
  plate.color=Color(0.12,0.17,0.18,0.94)
  plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(plate)
 vitality_panel=VitalityPanel.new()
 vitality_panel.auto_enabled=auto_status_enabled
 add_child(vitality_panel)
 father_prompt=FatherPrompt.new();father_prompt.app=self
 father_prompt.node_requested.connect(func(id:String):
  open_neuron_menu()
  if menu.visible:menu.describe(id)
 )
 add_child(father_prompt)
 status_label=label_at("",Vector2(26,112),16)
 debug_label=label_at("",Vector2(785,112),13)
 startle_button=Button.new()
 add_child(startle_button)
 startle_button.hide()
 dialogue_panel=PanelContainer.new()
 dialogue_panel.position=Vector2(155,405)
 dialogue_panel.size=Vector2(970,168)
 dialogue_panel.add_theme_stylebox_override("panel",panel_style(Color("283332"),Color("869a8d")))
 add_child(dialogue_panel)
 var column:=VBoxContainer.new()
 dialogue_panel.add_child(column)
 dialogue_text=Label.new()
 dialogue_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 column.add_child(dialogue_text)
 var next:=Button.new()
 next.text="继续 / Enter"
 next.pressed.connect(request_dialogue_advance)
 column.add_child(next)
 dialogue_panel.hide()

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 super._ready()
 rules=NeuralRules.new()
 bind_status_rules()
 home=HomeAnimals.new(self)
 family=FamilyEvents.new(self)
 hospital=HospitalEvents.new(self)
 hospital.records=HospitalRecords.new(hospital)
 hospital.observations=HospitalObservations.new(hospital)
 asylum=AsylumEvents.new(self)
 asylum.ward_events=AsylumWardEvents.new(asylum)
 asylum.records=AsylumRecords.new(asylum)
 asylum.trace_events=AsylumTrace.new(asylum)
 asylum.isolation=AsylumIsolation.new(asylum)
 asylum.observations=AsylumObservations.new(asylum)
 asylum.intake=AsylumIntake.new(asylum)
 asylum.nurse_duty=AsylumNurseDuty.new(asylum)
 cortex=CortexEvents.new(self)
 cortex.upper_events=CortexUpperEvents.new(cortex)
 hidden_route=HiddenStreet.new(self)
 ending_panel=EndingPanel.new(self)
 add_child(ending_panel)
 ending_panel.return_to_title_requested.connect(request_title_return)
 ending_panel.new_game_requested.connect(func():new_profile_requested=true;request_title_return())
 achievements=Achievements.new();achievements.root=store.root
 search_actions=SearchActions.new(self)
 menu.rules=rules
 menu.context_provider=skill_context
 menu.skill_requested.connect(cast_skill)
 menu.feedback_requested.connect(func(id:String):audio.cue_ui(id))
 menu.food_requested.connect(func(kind:String):
  var accepted:bool=family.request_gift() if kind=="gift" else family.request_food(kind)
  if accepted:close_neuron_menu()
  else:menu._status.text="没有可用物品，或身体当前不能完成使用；没有扣除物品"
 )
 demo_mode=false
 dialogue_queue.clear()
 dialogue_panel.hide()
 if profile.is_empty():profile={"name":"张%d"%invader_id,"invader_id":invader_id}
 invader_id=int(profile.invader_id)
 session.data.profile=profile.duplicate(true)
 campaign_ready=true
 if loaded.is_empty():
  session.new_attempt(1,rng)
  rules.owners["key"]=session.data.key_owner
  enter_room("bedroom")
  family.start_attempt()
  home.start_attempt()
  home.start_exploration_line()
 else:
  restore_snapshot(loaded)
 if not bool(profile.get("opening_completed",true)):open_parasite(loaded.get("opening_state",{}))
 elif not bool(profile.get("tutorial_completed",true)):open_tutorial(false)

func open_parasite(saved:Dictionary={}) -> void:
 if opening_ui!=null:return
 opening_ui=Opening.new();opening_ui.reduced_effects=reduced_effects
 add_child(opening_ui)
 opening_ui.state_changed.connect(func(_state):save_requested=true)
 opening_ui.completed.connect(func(_sequence,_skipped):
  profile.opening_completed=true;session.data.profile=profile.duplicate(true)
  opening_ui.queue_free();opening_ui=null;save_requested=true
  if not bool(profile.get("tutorial_completed",false)):open_tutorial(false)
 )
 opening_ui.start("parasite",profile,saved)
 if opening_ui.finished:
  profile.opening_completed=true;opening_ui.queue_free();opening_ui=null
  if not bool(profile.get("tutorial_completed",false)):open_tutorial(false)

func open_tutorial(guide:bool) -> void:
 if tutorial_ui!=null or rules.hp<=0:return
 tutorial_ui=Tutorial.new(self)
 tutorial_ui.guide_only=guide
 add_child(tutorial_ui)

func world_paused() -> bool:
 return opening_ui!=null or tutorial_ui!=null or (hidden_route!=null and hidden_route.blocks_hero()) or super.world_paused()

func sync_audio_pause() -> void:
 if audio==null:return
 var hard_pause:bool=paused_manual or menu.visible or closing_left>0 or audio_panel.visible or tutorial_ui!=null or opening_ui!=null
 audio.set_world_paused(world_paused(),hard_pause,hard_pause)

func _process(delta:float) -> void:
 if not campaign_ready:return
 process_requests()
 if not campaign_ready:return
 ending_panel.sync_from_game()
 if hidden_route!=null and hidden_route.data.get("status","")=="ending":
  input_lock_frames=maxi(0,input_lock_frames-1)
  closing_left=maxf(0,closing_left-delta)
  hidden_route.advance_ending(delta)
  if not hidden_route.data.pending_achievements.is_empty():
   var result:Dictionary=achievements.grant_e1(hidden_route.event_id("exit"))
   if result.ok:hidden_route.data.pending_achievements=[]
   else:status_note="结局已成立；全局成就保存失败，保留待重试："+str(result.get("error",""))
  sync_audio_pause();update_ui();view.queue_redraw();return
 if family.data.get("hidden_pending",false) and not world_paused():
  enter_hidden_street()
 if family.collapse_active() or rules.hp<=0:
  input_lock_frames=maxi(0,input_lock_frames-1)
  closing_left=maxf(0.0,closing_left-delta)
  audio.set_world_paused(true,paused_manual or menu.visible or closing_left>0 or audio_panel.visible)
 if family.collapse_active():
  sync_audio_pause()
  if not paused_manual and not menu.visible and closing_left<=0 and not audio_panel.visible:
   if family.advance_collapse(delta):restart_attempt(3,true)
  update_ui();view.queue_redraw();return
 if rules.hp<=0:
  if session.data.level==3 and asylum!=null:asylum.release_all()
  if session.data.level==4 and cortex!=null:
   cortex.release_all();cortex.upper_events.release_all("death")
  if death_left<=0:death_left=float(family.config.test_parameters.death_presentation)
  if not paused_manual and not menu.visible and not audio_panel.visible:
   death_left-=delta
   if death_left<=0:restart_attempt(3,true)
  update_ui();view.queue_redraw();return
 super._process(delta)
 if not world_paused():
  audio.cue("MUS_ROOM","music:%d:%d"%[session.data.level,rules.actual_attempt])
  if room_id=="bedroom":audio.cue("AMB_FAN","fan:%d"%rules.actual_attempt)

func request_title_return() -> void:
 title_requested=true
 save_requested=true
 request_load=false

func process_requests() -> void:
 if save_requested:
  save_requested=false
  var result:Dictionary=store.save_snapshot(snapshot_data())
  status_note="已保存（动作、钥匙、随机状态与暂停均保留）" if result.ok else str(result.error)
  if title_requested:
   title_requested=false
   if result.ok:
    campaign_ready=false
    if new_profile_requested:new_game_requested.emit()
    else:return_to_title.emit()
    return
   paused_manual=true
   status_note="保存失败，已暂停并留在当前游戏："+str(result.error)
 if request_load:
  request_load=false
  var result:Dictionary=store.load_snapshot()
  if result.ok:
   restore_snapshot(result.data)
   status_note=("旧档已载入，下次保存将保留schema1原件；" if int(result.data.schema)==1 else "已读档；旧运行回调失效")+("；恢复备份" if result.get("recovered_backup",false) else "")
  else:status_note=str(result.error)

func bind_status_rules() -> void:
 if not rules.vitality_lost.is_connected(on_vitality_lost):rules.vitality_lost.connect(on_vitality_lost)

func on_vitality_lost() -> void:
 if not first_damage:first_damage=true;first_damage_pending=true
 vitality_panel.damaged()

func create_audio_controls() -> void:
 super.create_audio_controls()
 var column:VBoxContainer=audio_panel.get_child(0)
 column.get_child(0).text="设置 · 界面与声音"
 auto_status_box=CheckBox.new()
 auto_status_box.text="受伤后自动显示角色状态"
 auto_status_box.button_pressed=auto_status_enabled
 auto_status_box.add_theme_font_size_override("font_size",16)
 auto_status_box.toggled.connect(set_auto_status)
 column.add_child(auto_status_box);column.move_child(auto_status_box,1)

func set_auto_status(value:bool) -> void:
 auto_status_enabled=value
 vitality_panel.set_automatic(value)
 if auto_status_box!=null:auto_status_box.set_pressed_no_signal(value)
 status_preferences_changed.emit(value)

func room_title(id:String) -> String:
 if int(session.data.level)==4:return str(CortexMap.ROOM_NAMES.get(id,"异化脑部出口" if id=="combat_exit" else id))
 if int(session.data.level)==3:return str(AsylumMap.ROOM_NAMES.get(id,"第四关出口" if id=="cortex_exit" else id))
 return {"bedroom":"卧室","ward":"小病房","lobby":"候诊区","clinic":"诊室","pharmacy":"药房","office":"医护办公室","stairs":"楼梯","hidden_street":"隐藏Street · 广场"}.get(id,id)

func advance_dialogue() -> void:
 var line:Dictionary=dialogue_queue[0].duplicate(true) if not dialogue_queue.is_empty() else {}
 super.advance_dialogue()
 if cortex!=null and int(session.data.level)==4 and not line.is_empty():cortex.upper_events.on_dialogue_advanced(line)

func layout_for_room(id:String):
 if int(session.data.level)==4:return CortexLayout.new(id)
 if id=="hidden_street":return HiddenLayout.new()
 if id=="bedroom" and int(session.data.get("room_geometry_version",1))>=2:return BedroomLayout.new()
 if metric_institution_room(id):
  var cache_id:String="%d:%s"%[int(session.data.level),id]
  if not institution_layouts.has(cache_id):institution_layouts[cache_id]=InstitutionLayout.new(id,int(session.data.level))
  return institution_layouts[cache_id]
 if int(session.data.level)==3 and id in AsylumMap.UPPER_ROOMS:return AsylumLayout.new(id)
 var floor_layout=Layout.new()
 if id!="bedroom" and id!="ward":
  floor_layout.furniture.clear()
  for i in range(Session.ROOM_POINTS[id].size()):
   var side:int=i%2
   var row:int=i/2
   var p:=Vector2(0.25 if side==0 else 4.85,0.65+row*0.51)
   var at:=p+Vector2(0.75 if side==0 else -0.3,0.2)
   floor_layout.furniture.append({"id":"%s:%d"%[id,i],"name":Session.ROOM_POINTS[id][i],"rect":Rect2(p,Vector2(0.5,0.35)),"at":at,"height":25.0,"color":Color("819593"),"kind":"drawer"})
  floor_layout._init()
 return floor_layout

func metric_institution_room(id:String) -> bool:
 return int(session.data.level) in [2,3] and int(session.data.get("institution_geometry_version",1))>=2 and id in ["ward","lobby","clinic","pharmacy","office","stairs"]

func enter_room(id:String) -> void:
 var previous:String=room_id
 if not room_id.is_empty():session.data.rooms[room_id]={"drawer":drawer_open.duplicate(true)}
 room_id=id
 layout=layout_for_room(id)
 view.layout=layout
 configure_room_viewport()
 hero_pos=layout.bed_position() if id=="bedroom" or id=="ward" else Vector2(2.8,1.4)
 if int(session.data.level)==3 and not restoring and previous in AsylumMap.GRAPH.get(id,[]):hero_pos=AsylumMap.doorway(id,previous)
 if metric_institution_room(id):
  var arrival:Dictionary=layout.portal(previous)
  hero_pos=arrival.landing if not restoring and not arrival.is_empty() else layout.get_anchor("hero_entry")
 if int(session.data.level)==4:
  hero_pos=CortexMap.doorway(id,previous) if not restoring and previous in CortexMap.GRAPH.get(id,[]) else CortexMap.SPAWN
 hero_route=PackedVector2Array()
 target_index=-1
 hero_state="idle"
 drawer_open=session.data.rooms.get(id,{}).get("drawer",{}).duplicate(true)
 visible_doors=[]
 if id=="bedroom":visible_doors=["lobby"]
 else:visible_doors=session.doors(id)
 input_lock_frames=3
 action_phase="autonomy"
 status_note="进入"+room_title(id)
 if search_actions!=null:search_actions.enter_room()
 if audio!=null:
  if id!="bedroom":audio.stop_channel("ambience")
 if hospital!=null and not restoring:hospital.on_enter(previous,id)
 if asylum!=null and not restoring:asylum.on_enter(previous,id)
 if cortex!=null and not restoring:cortex.on_enter(previous,id)

func configure_room_viewport() -> void:
 # New metric rooms use a native world viewport, never a smaller actor to
 # fit the old low-resolution box. UI remains in the 1280x720 screen canvas.
 var metric:bool=int(layout.geometry_version)>=2
 var container:SubViewportContainer=world_viewport.get_parent()
 container.stretch_shrink=1 if metric else 2
 container.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if metric else CanvasItem.TEXTURE_FILTER_NEAREST
 world_viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR if metric else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 camera.position=layout.project(layout.world_size()*0.5)+Vector2(0,-84) if metric else Vector2(320,196)
 camera.reset_smoothing()
 camera.force_update_scroll()

func enter_hidden_street() -> void:
 family.data.hidden_pending=false;family.data.pressure=0;family.data.blood_door=false
 family.data.father.present=false;family.data.father.phase="absent"
 hidden_route.start();view.layout=layout;visible_doors=[]
 configure_room_viewport()
 menu.close_menu();dialogue_queue.clear();show_dialogue()
 status_note="隐藏Street · 自主逃离；猎手与场景均为程序占位"
 audio.stop_channel("ambience")

func point_id(index:int) -> String:
 return "%s:%d"%[room_id,index]

func door_point(id:String) -> Vector2:
 return door_point_for(room_id,id)

func door_point_for(room:String,id:String) -> Vector2:
 return portal_for_room(room,id).at

func portal_for_room(room:String,id:String) -> Dictionary:
 if metric_institution_room(room):
  var portal:Dictionary=layout_for_room(room).portal(id)
  if not portal.is_empty():return portal
 var at:Vector2
 if int(session.data.level)==4:at=CortexMap.doorway(room,id)
 elif int(session.data.level)==3:at=AsylumMap.doorway(room,id)
 elif room=="bedroom":at=layout.door_position() if room_id=="bedroom" else layout_for_room(room).door_position()
 elif room=="ward":at=Layout.DOOR
 else:
  var doors:Array=Session.GRAPH.get(room,[]).duplicate()
  if room=="lobby":doors.append("stairs")
  at=Vector2(1.25+maxi(0,doors.find(id))*0.78,0.24)
 return {"at":at,"threshold":at,"landing":at,"inward":Vector2.DOWN,"toward":id,"wall":"north","width_m":0.95,"height_m":2.15}

func finish_door_crossing() -> void:
 # Called only after the active room's actual doorway action has completed.
 if destination=="stairs" and session.data.level==2:unlock_asylum()
 elif destination=="cortex_exit" and session.data.level==3:unlock_cortex()
 elif destination=="combat_exit" and session.data.level==4:
  cortex.upper_events.release_all("crossed_exit")
  session.data.cortex_exit_crossed=true
  session.data.exploration_boundary=true;action_phase="autonomy";hero_state="idle"
  status_note="已到第四关持钥匙出口；第五关异化战斗待接入，此处不是结局"
 elif room_id=="bedroom":unlock_hospital()
 else:
  if int(session.data.level)==4 and not cortex_arrival_clear(destination):
   action_left=0.0;hero_state="idle"
   status_note="门口有人经过，等待实际通路空出"
   return
  enter_room(destination)

func has_key() -> bool:
 return session.has_key()

func key_visible() -> bool:
 if room_id=="hidden_street":return false
 if str(session.data.key_target).is_empty() or str(session.data.key_owner) in ["hero","dog",""]:return false
 return bool(session.data.key_seen) and str(session.data.key_target).get_slice(":",0)==room_id

func key_position() -> Vector2:
 if str(session.data.key_target).is_empty():return Vector2.INF
 if home!=null and not home.data.is_empty() and not home.data.key_drop.is_empty():
  return Vector2(float(home.data.key_drop[0]),float(home.data.key_drop[1]))
 var index:int=str(session.data.key_target).get_slice(":",1).to_int()
 return layout.furniture[index].at if index<layout.furniture.size() else hero_pos

func resolve_completed_key(target:String,receipt:String,finder:String="hero") -> Dictionary:
 # The caller must own a settled real search and be at the actual contact.
 # A label, timer preview, cancellation or arbitrary callback cannot roll.
 if rules.hp<=0 or rules.settled.get(receipt,"")!="completed" or not rules._completed_targets.has(target):return {"accepted":false,"newly_found":false,"reason":"unsettled_search"}
 if str(target).get_slice(":",0)!=room_id:return {"accepted":false,"newly_found":false,"reason":"different_room"}
 var index:int=target.get_slice(":",1).to_int()
 if index<0 or index>=layout.furniture.size():return {"accepted":false,"newly_found":false,"reason":"invalid_target"}
 var contact:Vector2=layout.furniture[index].at
 var at:Vector2=hero_pos
 if finder=="dog":
  if home==null or not home.present("dog") or not home.data.dog.alive or home.data.dog.phase!="search":return {"accepted":false,"newly_found":false,"reason":"dog_not_searching"}
  at=home.position("dog")
 elif finder!="hero" or rules.search_target!=target:return {"accepted":false,"newly_found":false,"reason":"wrong_search"}
 if at.distance_to(contact)>0.065 or not layout.clear_segment(at,contact):return {"accepted":false,"newly_found":false,"reason":"no_contact"}
 var result:Dictionary=session.resolve_key(target,receipt,finder)
 if result.get("newly_found",false):
  rules.owners.key=str(session.data.key_owner)
  rules._record("key_discovered","key_discovery:%d:%d"%[session.data.level,rules.actual_attempt],{"target":target,"finder":finder,"search_receipt":receipt})
 return result

func advance_world(delta:float) -> void:
 bind_status_rules()
 if room_id=="hidden_street":
  rules.tick(delta);world_visual_time+=delta
  hidden_route.tick(delta)
  return
 if home!=null:home.tick(delta)
 if family!=null:family.tick(delta)
 if hospital!=null:hospital.tick(delta)
 if asylum!=null:asylum.tick(delta)
 if cortex!=null:cortex.tick(delta)
 if session.data.level in [3,4] and rules.search_active and target_index>=0:
  var descriptor:Dictionary=layout.furniture[target_index].get("data",{})
  var ratio:float=rules.search_elapsed/rules.search_duration
  search_actions.pose=str(descriptor.get("pose","mid")) if ratio>=0.08 and ratio<0.9 else "mid"
  search_actions.action_label="准备" if ratio<0.08 else "收手" if ratio>=0.9 else {"low":"低位翻查","high":"高位查看"}.get(search_actions.pose,"翻查")
  status_note=str(descriptor.get("action","搜寻中"))
 if not rules.search_active and rules.public_action.get("kind","")=="search" and rules.settled.has(rules._search_id):rules.finish_public_action(search_action_origin)
 world_visual_time+=delta
 var was_controlled:bool=rules.control_left>0
 var result:Dictionary=rules.tick(delta)
 var completed_index:int=target_index
 search_actions.tick(bool(result.search_completed))
 if rules.hp<=0:return
 if home!=null:home.settle_key_contact()
 if result.search_completed:
  vitality_panel.action_completed("search:"+str(result.event_id))
  rules.finish_public_action(search_action_origin)
  var id:String=result.target_id
  if not id in completed:completed.append(id)
  var key_result:Dictionary=resolve_completed_key(id,str(result.event_id))
  var found_key:bool=bool(key_result.get("newly_found",false))
  if found_key:
   session.data.key_seen=true
   if not id in rules.known:rules.known.append(id)
   action_phase="pickup"
   action_left=0.4
   hero_state="give"
   status_note="已实际发现钥匙；伸手拿取中"
  else:
   action_phase="autonomy"
   hero_state="idle"
   status_note="搜寻完成：+1神经元；此处无钥匙" if result.get("rewarded",true) else "搜寻结束：此处已由大黄查完，不重复奖励"
  if completed_index>=0:search_actions.on_complete(completed_index,found_key)
  if completed_index>=0 and session.data.level==2:hospital.on_search_complete(completed_index,found_key)
  if completed_index>=0 and session.data.level==3:asylum.on_search_complete(completed_index,found_key)
  if completed_index>=0 and session.data.level==3:asylum_search_feedback(completed_index,found_key)
  if completed_index>=0 and session.data.level==4:
   cortex.on_search_complete(completed_index,found_key)
   cortex_search_feedback(completed_index,found_key)
  target_index=-1
  return

 if not dialogue_queue.is_empty():return
 if not rules.control_feedback.is_empty() and not rules.body_busy() and not rules.gripped and not rules.search_active and action_phase=="autonomy":
  var stage:int=int(rules.control_feedback.pop_front())
  if stage==rules.control_stage and stage in [1,2]:
   var line:String="刚才……是我想动的吗？" if stage==1 else "我记得想说什么……却说不出来。"
   rules.observe("角色","control_stage_%d"%stage,line)
   add_dialogue("角色 · 疑虑" if stage==1 else "角色 · 低声",line)
   return
 if was_controlled and rules.control_left<=0:cancel_control_route()
 if not rules.action.is_empty():
  var attack:Dictionary=rules.advance_kick(delta)
  family.kick_contact()
  if hospital!=null and session.data.level==2:hospital.kick_contact()
  if asylum!=null and session.data.level==3:asylum.kick_contact()
  if cortex!=null and session.data.level==4:cortex.kick_contact()
  hero_state="grab" if attack.get("phase","")=="prepare" else "give"
  return
 if not motion.is_empty():
  if rules.hurt_left>0 or rules.stun_left>0:
   motion.clear();hero_route=PackedVector2Array();return
  if not rules.body_busy() and (not rules.gripped or motion.get("allow_gripped",false)):
   var moved:Dictionary=layout.move_path(hero_pos,hero_route,float(motion.speed)*delta)
   if session.data.level==4 and not cortex_segment_clear(hero_pos,moved.position):
    motion.clear();hero_route=PackedVector2Array();hero_state="idle";return
   hero_pos=moved.position;hero_route=moved.route
   family.after_motion_step()
   hero_state="walk"
   if hero_route.is_empty():
    motion.clear();hero_state="idle"
    if not family.data.is_empty() and not family.data.startle.is_empty() and family.data.startle.held:family.reward_startle(true)
  return
 if rules.reaction_left>0:hero_state="hit" if rules.reaction_skill=="GUT" else "give" if rules.reaction_skill=="WITHDRAW" else "scratch"
 elif rules.stun_left>0 or rules.hurt_left>0:hero_state="hit"
 elif hero_state in ["scratch","hit","eat"]:hero_state="idle"
 if rules.body_busy() or rules.gripped:return
 if hospital!=null and session.data.level==2 and hospital.blocks_hero():return
 if asylum!=null and session.data.level==3 and asylum.blocks_hero():return
 if cortex!=null and session.data.level==4 and cortex.blocks_hero():return
 if action_phase=="cortex_observing":action_phase="autonomy";hero_state="idle"
 if action_phase=="cortex_observation_route":
  advance_cortex_observation_route(delta)
  return
 if action_phase=="asylum_item":
  var item:Dictionary=asylum.data.get("band_action",{})
  var band:Dictionary=asylum.ward_events.state().transfer.band_drop
  var held:bool=rules.owners.get("asylum_transport_band","")=="hero"
  if item.is_empty() or band.is_empty() or rules.control_left<=0 or (not held and room_id!=str(band.room)):cancel_asylum_read();return
  var at:Vector2=hero_pos if held else Vector2(float(band.pos[0]),float(band.pos[1]))
  if hero_pos.distance_to(at)>0.65 or not layout.clear_segment(hero_pos,at):cancel_asylum_read();return
  item.elapsed+=minf(delta,rules.control_left)
  search_actions.pose="mid";search_actions.action_label="翻看腕带" if item.kind=="band_read" else "伸手拾取"
  var finished:bool=false
  if item.kind=="band_read":finished=float(item.elapsed)>=1.0 if band.get("read",false) else asylum.ward_events.read_band(minf(delta,rules.control_left))
  elif float(item.elapsed)>=0.55:finished=asylum.ward_events.take_band()
  if finished:
   rules.controlled_execution("observe" if item.kind=="band_read" else "take","asylum_transport_band")
   cancel_asylum_read()
  return
 if action_phase=="asylum_reading":action_phase="autonomy";hero_state="idle"
 if action_phase=="asylum_read_route":
  var request:Dictionary=asylum.data.get("read_route",{})
  if request.is_empty() or request.get("controlled",false) and rules.control_left<=0:cancel_asylum_read();return
  if request.kind=="observation":
   var spec:Dictionary=asylum.observations.specification(str(request.id))
   if spec.is_empty() or not asylum.observations.available(spec) or asylum.observations.target_room(spec)!=room_id:cancel_asylum_read();return
   var current:Vector2=asylum.observations.target_position(spec)
   var original:Array=request.get("subject_pos",request.pos)
   var prior:=Vector2(float(original[0]),float(original[1]))
   if current.distance_to(prior)>0.08:
    var stand:Vector2=asylum.observations.approach_position(spec)
    if not stand.is_finite():cancel_asylum_read();return
    hero_route=layout.path(hero_pos,stand);request.pos=[stand.x,stand.y];request.subject_pos=[current.x,current.y]
  var at:Vector2=Vector2(float(request.pos[0]),float(request.pos[1]))
  move_hero(delta)
  if hero_pos.distance_to(at)<=0.035:
   hero_route=PackedVector2Array();action_phase="asylum_reading"
   if request.kind in ["band_read","band_take"]:
    asylum.data.band_action=request.duplicate(true);asylum.data.band_action.elapsed=0.0;asylum.data.erase("read_route")
    action_phase="asylum_item";hero_state="search"
    rules.begin_public_action("observe" if request.kind=="band_read" else "take","asylum_transport_band","controlled",room_id)
    return
   var accepted:bool=asylum.begin_ward_window(bool(request.controlled)) if request.kind=="ward_window" else asylum.begin_registration_followup(bool(request.controlled)) if request.kind=="registration_followup" else asylum.observations.begin(str(request.id),bool(request.controlled)) if request.kind=="observation" else asylum.records.begin_read(int(request.index),"",bool(request.controlled)) if request.kind=="record" else asylum.trace_events.begin_read(str(request.id)) if request.kind=="trace" else asylum.trace_events.take_relic(str(request.id))
   if not accepted:cancel_asylum_read()
   else:asylum.data.erase("read_route");hero_state="search"
  return
 if action_phase=="hospital_observing":action_phase="autonomy";hero_state="idle"
 if action_phase=="hospital_observation_route":
  var request:Dictionary=hospital.data.get("observation_route",{})
  var spec:Dictionary=hospital.observations.specification(str(request.get("id","")))
  if spec.is_empty() or not hospital.observations.available(spec) or hospital.observations.target_room(spec)!=room_id or (request.get("controlled",false) and rules.control_left<=0):
   cancel_hospital_observation();return
  var at:Vector2=hospital.observations.target_position(spec)
  if hero_pos.distance_to(at)>0.035:
   if hero_route.is_empty() or hero_route[-1].distance_to(at)>0.08:hero_route=layout.path(hero_pos,at)
   if hero_route.is_empty():cancel_hospital_observation();return
   move_hero(delta)
  if hero_pos.distance_to(at)<=0.035:
   hero_route=PackedVector2Array()
   action_phase="hospital_observing" if hospital.observations.begin(str(spec.id),bool(request.get("controlled",false))) else "autonomy"
   if action_phase=="autonomy" and rules.public_action.get("target","")==spec.id:rules.finish_public_action(route_action_origin)
   hospital.data.erase("observation_route")
  return
 if family!=null and family.blocks_hero():
  var pose:String=family.hero_pose()
  if not pose.is_empty():hero_state=pose
  return
 if not rules.awareness_feedback.is_empty() and action_phase=="autonomy" and not rules.search_active:
  var line:String=str(rules.awareness_feedback.pop_front())
  rules.observe("角色","awareness:%d"%rules.awareness_stage,line)
  add_dialogue("角色 · 疑惑" if rules.awareness_stage<3 else "角色 · 冷淡",line)
  return
 if not rules.body_feedback.is_empty() and action_phase=="autonomy" and not rules.search_active and rules.mode=="exploration":
  var feedback:Dictionary=rules.body_feedback.pop_front()
  add_dialogue("角色",str(feedback.lines[0]));add_dialogue("玩家",str(feedback.lines[1]))
  return
 if action_phase=="observe_cuff":
  hero_state="search";action_left-=delta
  if action_left<=0:
   search_actions.finish_cuff();action_phase="autonomy";hero_state="idle"
  return
 if first_damage_pending and action_phase=="autonomy" and not rules.search_active:
  first_damage_pending=false
  add_dialogue("玩家 · 捧腹大笑","这算不算咎由自取呢 哈哈哈")
  return
 vitality_panel.present_after_feedback()
 if session.data.exploration_boundary:return
 if rules.search_active:
  hero_state="search"
  if target_index>=0:
   var id:String=layout.furniture[target_index].id
   var contact:bool=hero_pos.distance_to(layout.furniture[target_index].at)<0.04
   var opens:bool=id!="bedside" or search_actions.state("bedside").get("drawer_started",false)
   if contact and opens and rules.search_elapsed>=0.18:
    var before_open:float=float(drawer_open.get(id,0))
    drawer_open[id]=minf(1,before_open+delta*2)
    if before_open==0:audio.cue("SFX_DRAWER","drawer:%d:%s:%s"%[rules.actual_attempt,room_id,id])
  return
 if action_phase=="controlled_pickup":
  move_hero(delta)
  if hero_pos.distance_to(key_position())<=0.035:
   action_phase="pickup";action_left=0.4;hero_state="give"
  return
 if action_phase=="controlled_observe_cuff":
  move_hero(delta)
  if hero_pos.distance_to(layout.furniture[6].at)<=0.035:
   action_phase="observe_cuff";action_left=float(search_actions.config.test_parameters.cuff_observation_seconds)
  return
 if action_phase=="controlled_search":
  move_hero(delta)
  if target_index>=0 and hero_pos.distance_to(layout.furniture[target_index].at)<=0.035:
   rules.begin_public_action("search",point_id(target_index),"controlled",room_id)
   if rules.begin_search(point_id(target_index)):
    search_action_origin="controlled"
    rules.controlled_execution("search",point_id(target_index))
    rules.search_duration*=search_level_factor()
    hero_state="search"
   action_phase="autonomy"
  return
 if rules.control_left>0 and action_phase=="autonomy":
  if controlled_route:move_hero(delta)
  return
 if action_phase=="pickup":
  action_left-=delta
  if action_left<=0 and key_visible() and hero_pos.distance_to(key_position())<=0.05:
   var event_id:String="key:%d:%d"%[session.data.level,rules.actual_attempt]
   if rules.commit_transfer(event_id,"key",str(session.data.key_owner),"hero",hero_pos.distance_to(key_position()),layout.clear_segment(hero_pos,key_position()),true,true):
    session.data.key_owner="hero"
    audio.cue("SFX_KEY",event_id)
    status_note="钥匙已实际取得，前往出口"
   action_phase="autonomy"
  return
 if action_phase in ["door","opening","crossing"] and session.data.level==3 and not asylum.isolation.can_exit(room_id,destination):
  hero_route=PackedVector2Array();action_phase="autonomy";hero_state="idle"
  status_note="门已实际关闭；离房动作取消，室内仍可行动与查看"
  return
 if action_phase=="crossing":
  move_hero(delta)
  if hero_pos.distance_to(portal_for_room(room_id,destination).threshold)<=0.035:finish_door_crossing()
  return
 if action_phase=="door" or action_phase=="return_bed":
  move_hero(delta)
  var point:Vector2=door_point(destination) if action_phase=="door" else layout.bed_position()
  if hero_pos.distance_to(point)>0.035:return
  action_phase="opening" if action_phase=="door" else "resting"
  action_left=0.6 if action_phase=="opening" else 1.2
  hero_state="give" if action_phase=="opening" else "idle"
  if action_phase=="opening":audio.cue("SFX_DOOR_OPEN","door:%d:%s:%s"%[rules.actual_attempt,room_id,destination])
  if action_phase=="opening" and session.data.level==4 and destination=="combat_exit":cortex.upper_events.on_exit_open_started()
  if action_phase=="resting" and family.present("mother"):
   family.on_node("mother_return_bed")
  return
 if action_phase in ["opening","resting"]:
  action_left-=delta
  if action_phase=="resting" and action_left<=0.9 and family.present("mother") and not family.data.mother.get("bed_line_shown",false):
   family.data.mother.bed_line_shown=true
   add_dialogue("母亲 · 剪影","乖孩子...")
   return
  if action_left>0:return
  if action_phase=="resting":finish_rest()
  elif metric_institution_room(room_id):
   action_phase="crossing";hero_state="walk"
   hero_route=layout.path(hero_pos,portal_for_room(room_id,destination).threshold)
  else:finish_door_crossing()
  return
 if has_key():
  if session.data.level==4:route_to_door("combat_exit" if room_id=="verify" else session.next_room(room_id,"verify"))
  elif session.data.level==3:route_to_door("cortex_exit" if room_id=="stairs" else session.next_room(room_id,"stairs"))
  else:route_to_door("lobby" if room_id=="bedroom" or room_id!="lobby" else "stairs")
  return
 if key_visible():
  if hero_pos.distance_to(key_position())<=0.035:
   action_phase="pickup";action_left=0.4;hero_state="give"
  else:
   if hero_route.is_empty():hero_route=layout.path(hero_pos,key_position())
   move_hero(delta)
  return
 if session.data.level<4 and (rules.search_attempts>=rules.search_limit or rules.sp<50 or sampled_searches_completed()):
  if family!=null and family.try_auto_food():return
  if home!=null and home.present("dog") and home.data.dog.phase in ["walk","search","bring"]:return
  if room_id not in ["bedroom","ward"]:
   route_to_door(session.next_room(room_id,"ward"))
  else:
   action_phase="return_bed"
   hero_route=layout.path(hero_pos,layout.bed_position())
  return
 if action_phase=="autonomy" and family!=null and family.try_auto_food():return
 if action_phase=="autonomy" and target_index<0 and session.data.level==2 and not has_key() and rules.control_left<=0:
  var observation:Dictionary=hospital.observations.candidate(room_id)
  if not observation.is_empty() and hero_pos.distance_to(observation.pos)<=1.2:
   if route_hospital_observation(observation,false):return
 if action_phase=="autonomy" and target_index<0 and session.data.level==3 and room_id=="office" and not has_key() and rules.control_left<=0:
  for index in asylum.records.read_candidates():
   var at:Vector2=layout.furniture[int(index)].at
   if hero_pos.distance_to(at)<=1.2 and route_asylum_read({"kind":"record","index":int(index),"pos":[at.x,at.y]},false):return
 if action_phase=="autonomy" and target_index<0 and session.data.level==3 and not has_key() and rules.control_left<=0:
  var observation:Dictionary=asylum.observations.candidate(room_id)
  if not observation.is_empty() and hero_pos.distance_to(observation.pos)<=1.2:
   if route_asylum_read({"kind":"observation","id":str(observation.id),"pos":[observation.pos.x,observation.pos.y]},false):return
 if action_phase=="autonomy" and session.data.level==4 and rules.control_left<=0:
  var diversion:String=cortex.upper_events.forced_route_target()
  if not diversion.is_empty():route_to_door(session.next_room(room_id,diversion));return
  if target_index<0 and not has_key():
   var observation:Dictionary=cortex.candidate(room_id)
   if not observation.is_empty() and hero_pos.distance_to(observation.pos)<=1.2:
    if route_cortex_observation(observation,false):return
 choose_public_target(delta)

func cortex_arrival_clear(room:String) -> bool:
 var arrival:Vector2=CortexMap.doorway(room,room_id)
 for id in cortex.data.get("actors",{}):
  if not cortex.present(str(id)) or str(cortex.actor(str(id)).room)!=room:continue
  var radius:float=0.42 if str(id)=="twitch" else 0.32
  if arrival.distance_to(cortex.position(str(id)))<radius:return false
 return true

func search_level_factor() -> float:
 return 1.75 if session.data.level==4 else 1.5 if session.data.level==3 else 1.25 if session.data.level==2 else 1.0

func route_cortex_observation(spec:Dictionary,controlled:bool) -> bool:
 if spec.is_empty() or not cortex.available(spec):return false
 var at:Vector2=cortex.approach_position(spec)
 if not at.is_finite() or not layout.walkable(at):return false
 var path:PackedVector2Array=layout.path(hero_pos,at)
 if path.is_empty() and hero_pos.distance_to(at)>0.035:return false
 cortex.cancel_observation("new_route");rules.cancel_search();target_index=-1
 cortex.data.observation_route={"id":str(spec.id),"controlled":controlled,"pos":[at.x,at.y]}
 hero_route=path;action_phase="cortex_observation_route";controlled_route=false
 route_action_origin="controlled" if controlled else "autonomous"
 rules.begin_public_action("navigation",str(spec.id),route_action_origin,room_id)
 return true

func advance_cortex_observation_route(delta:float) -> void:
 var request:Dictionary=cortex.data.get("observation_route",{})
 var spec:Dictionary=cortex.specification(str(request.get("id","")))
 if spec.is_empty() or not cortex.available(spec) or str(spec.room)!=room_id or (request.get("controlled",false) and rules.control_left<=0):cancel_cortex_observation();return
 var at:Vector2=cortex.approach_position(spec)
 if not at.is_finite():cancel_cortex_observation();return
 if hero_pos.distance_to(at)>0.035:
  if hero_route.is_empty() or hero_route[-1].distance_to(at)>0.08:hero_route=layout.path(hero_pos,at)
  if hero_route.is_empty():cancel_cortex_observation();return
  move_hero(delta)
 if hero_pos.distance_to(at)<=0.035:
  hero_route=PackedVector2Array()
  var target:Vector2=cortex.target_position(spec)
  if hero_pos.distance_to(target)>0.001:hero_facing=(target-hero_pos).normalized()
  action_phase="cortex_observing" if cortex.begin_observation(str(spec.id),bool(request.get("controlled",false))) else "autonomy"
  cortex.data.erase("observation_route")

func cancel_cortex_observation() -> void:
 if cortex==null:return
 cortex.cancel_observation("interrupted");cortex.data.erase("observation_route")
 if action_phase in ["cortex_observing","cortex_observation_route"]:
  hero_route=PackedVector2Array();target_index=-1;action_phase="autonomy";hero_state="idle"

func cortex_search_feedback(index:int,found_key:bool) -> void:
 if found_key:return
 var descriptor:Dictionary=layout.furniture[index].get("data",{})
 for pair in [["角色","failure_hero"],["玩家","failure_player"]]:
  var line:String=str(descriptor.get(pair[1],""))
  if not line.is_empty():add_dialogue(str(pair[0]),line)

func route_asylum_read(request:Dictionary,controlled:bool) -> bool:
 var at:Vector2=Vector2(float(request.pos[0]),float(request.pos[1]))
 if request.kind=="observation":
  var spec:Dictionary=asylum.observations.specification(str(request.id))
  if spec.is_empty() or not asylum.observations.available(spec):return false
  request.subject_pos=[at.x,at.y]
  at=asylum.observations.approach_position(spec)
  if not at.is_finite():return false
  request.pos=[at.x,at.y]
 var path:PackedVector2Array=layout.path(hero_pos,at)
 if path.is_empty() and hero_pos.distance_to(at)>0.035:return false
 cancel_asylum_read();rules.cancel_search()
 request.controlled=controlled;asylum.data.read_route=request.duplicate(true)
 hero_route=path;target_index=-1;controlled_route=false;action_phase="asylum_read_route"
 route_action_origin="controlled" if controlled else "autonomous"
 rules.begin_public_action("navigation",str(request.get("id",request.get("index",""))),route_action_origin,room_id)
 status_note="接近病房门外侧；伸手接触后才切换观察窗" if request.kind=="ward_window" else "接近并翻看实物；完成前不取得信息"
 return true

func route_registration_followup() -> bool:
 var request:Dictionary=asylum.registration_interaction(true)
 if request.is_empty():return false
 var subject:Vector2=Vector2(float(request.pos[0]),float(request.pos[1]))
 for offset in [Vector2(0.6,0),Vector2(-0.6,0),Vector2(0,0.6),Vector2(0,-0.6)]:
  var stand:Vector2=subject+offset
  if not layout.walkable(stand) or not layout.clear_segment(stand,subject):continue
  if hero_pos.distance_to(stand)>0.035 and layout.path(hero_pos,stand).is_empty():continue
  request.pos=[stand.x,stand.y]
  return route_asylum_read(request,true)
 return false

func cancel_asylum_read() -> void:
 if session.data.level!=3 or asylum==null:return
 asylum.records.cancel_read("new_action");asylum.trace_events.cancel_read();asylum.data.erase("read_route")
 if asylum.observations!=null:asylum.observations.cancel()
 asylum.cancel_ward_window("new_action")
 asylum.cancel_registration_interaction()
 if asylum.data.has("band_action"):
  var band:Dictionary=asylum.ward_events.state().transfer.band_drop
  if not band.is_empty() and not band.get("read",false):band.read_elapsed=0.0
  asylum.data.erase("band_action")
  if rules.public_action.get("target","")=="asylum_transport_band":rules.finish_public_action(str(rules.public_action.get("origin","controlled")))
 if action_phase in ["asylum_reading","asylum_read_route","asylum_item"]:
  if rules.public_action.get("kind","")=="navigation":rules.finish_public_action(str(rules.public_action.get("origin","autonomous")))
  action_phase="autonomy";hero_route=PackedVector2Array()

func asylum_search_feedback(index:int,found_key:bool) -> void:
 if found_key:
  add_dialogue("角色 · 得意","哈！找到了！")
  return
 var spec:Dictionary=layout.furniture[index].get("data",{})
 if spec.is_empty() or not asylum.claim("search_comment:"+point_id(index),"asylum_search_feedback"):return
 if room_id=="quiet" and index==2:asylum.observe("asylum_quiet_scratches","实际掀开活动软垫并查看缝隙、座面下方的抓痕；未认定是角色自己留下。")
 var visible:bool=not spec.get("failure_requires_observation",false) or (room_id=="quiet" and "asylum_quiet_scratches" in rules.known) or (room_id=="workshop" and "asylum_display_label_back_seen" in rules.known)
 add_dialogue("角色",str(spec.get("failure_hero","这里没有钥匙。")) if visible else str(spec.get("failure_unobserved","这里没有钥匙。")))
 if visible:add_dialogue("玩家",str(spec.get("failure_player","")))

func route_hospital_observation(target:Dictionary,controlled:bool) -> bool:
 var path:PackedVector2Array=layout.path(hero_pos,target.pos)
 if path.is_empty() and hero_pos.distance_to(target.pos)>0.035:return false
 cancel_hospital_observation()
 hospital.data.observation_route={"id":str(target.id),"controlled":controlled}
 hero_route=path;target_index=-1;controlled_route=false;action_phase="hospital_observation_route"
 route_action_origin="controlled" if controlled else "autonomous"
 rules.begin_public_action("navigation",str(target.id),route_action_origin,room_id)
 status_note="接近并翻看："+str(target.name)
 return true

func cancel_hospital_observation() -> void:
 if hospital==null or session.data.level!=2:return
 var request:Dictionary=hospital.data.get("observation_route",{})
 hospital.observations.cancel();hospital.data.erase("observation_route")
 if not request.is_empty() and rules.public_action.get("kind","")=="navigation" and rules.public_action.get("target","")==request.id:rules.finish_public_action(str(rules.public_action.get("origin","autonomous")))
 if action_phase in ["hospital_observing","hospital_observation_route"]:action_phase="autonomy";hero_route=PackedVector2Array()

func sampled_searches_completed() -> bool:
 # Dog searches do not spend the host's attempt allowance. An exhausted
 # actual target set still requires the normal physical return/rest path.
 if session.data.targets.is_empty():return false
 for target in session.data.targets:
  if not rules._completed_targets.has(str(target)):return false
 return true

func choose_public_target(delta:float) -> void:
 # Sampled public targets first; L4 can supplement from all remaining legal
 # candidates. No route reads a future key location or probability draw.
 if target_index<0:
  var pools:Array=[session.data.targets]
  if int(session.data.level)==4:pools.append(Session.all_candidates(4))
  for pool in pools:
   var closest:float=INF
   for i in range(layout.furniture.size()):
    var id:String=point_id(i)
    if not id in pool or not public_target_available(id):continue
    if int(session.data.level)==1 and home!=null and home.reserved(i):continue
    var at:Vector2=layout.furniture[i].at
    if hero_pos.distance_to(at)>0.035 and layout.path(hero_pos,at).is_empty():continue
    if int(session.data.level)==4 and cortex_target_occupied(at):continue
    var distance:float=hero_pos.distance_to(at)
    if distance<closest:closest=distance;target_index=i
   if target_index>=0:break
   for id in pool:
    if not public_target_available(str(id)):continue
    var room:String=str(id).get_slice(":",0)
    if room==room_id:continue
    var next:String=session.next_room(room_id,room)
    if not next.is_empty():route_to_door(next);return
  if target_index<0:return
 var target:Dictionary=layout.furniture[target_index]
 if hero_route.is_empty() and hero_pos.distance_to(target.at)>0.035:
  hero_route=layout.path(hero_pos,target.at)
  if not hero_route.is_empty():
   route_action_origin="autonomous";rules.begin_public_action("navigation",point_id(target_index),"autonomous",room_id)
 var before:Vector2=hero_pos
 move_hero(delta)
 if int(session.data.level)==4 and hero_pos.distance_to(target.at)>0.035:
  var watch:Dictionary=session.data.get("search_route_watch",{})
  var id:String=point_id(target_index)
  var stalled:float=float(watch.get("stalled",0)) if watch.get("target","")==id else 0.0
  stalled=stalled+delta if hero_pos.distance_to(before)<0.0001 else 0.0
  session.data.search_route_watch={"target":id,"stalled":stalled}
  if stalled>=1.5:
   deferred_targets[id]=rules.world_time+3.0
   hero_route=PackedVector2Array();target_index=-1
   rules.finish_public_action(route_action_origin)
   return
 if hero_pos.distance_to(target.at)<=0.035:
  hero_facing=(target.rect.get_center()-hero_pos).normalized()
  rules.begin_public_action("search",point_id(target_index),"autonomous",room_id)
  if rules.begin_search(point_id(target_index)):
   search_action_origin="autonomous"
   rules.search_duration*=search_level_factor()
   hero_state="search"

func public_target_available(id:String) -> bool:
 return not id in completed and float(deferred_targets.get(id,0))<=rules.world_time

func cortex_target_occupied(at:Vector2) -> bool:
 if cortex==null:return false
 for id in cortex.data.get("actors",{}):
  if cortex.present(str(id)) and str(cortex.actor(str(id)).room)==room_id and at.distance_to(cortex.position(str(id)))<(0.42 if id=="twitch" else 0.32):return true
 return false

func route_to_door(id:String) -> void:
 if not id in visible_doors:return
 if id in ["cortex_exit","combat_exit"] and not has_key():status_note="门尚未具备开锁条件";return
 if session.data.level==3 and not asylum.isolation.can_exit(room_id,id):status_note="隔离门尚未实际打开；室内仍可行动与查看";return
 if room_id=="bedroom" and id=="lobby" and family!=null and not family.data.is_empty() and family.data.blood_door:
  status_note="血门仍由父亲事件控制；钥匙不能将其当作普通医院出口"
  return
 destination=id
 action_phase="door"
 hero_route=layout.path(hero_pos,door_point(id))

func unlock_hospital() -> void:
 rules.end_control()
 rules.intervention_lock=false;rules.trial.clear();rules.public_action.clear()
 rules.body_feedback.clear()
 if not 2 in session.data.unlocked:
  session.data.unlocked.append(2)
  rules.neurons+=3
  rules.plexus+=2
 rules.cancel_search()
 rules.search_attempts=0
 rules.search_limit=12
 completed.clear()
 session.new_attempt(2,rng)
 rules.actual_attempt=int(session.data.attempts["2"])
 rules.owners["key"]=session.data.key_owner
 hospital.start_attempt()
 enter_room("lobby")

func unlock_asylum() -> void:
 # S1:P98/S4:T24: same first floor changes; the existing stairs stay open.
 # Pass facts as a copy, never replay old treatment, samples or reports.
 rules.end_control();rules.intervention_lock=false;rules.trial.clear();rules.public_action.clear()
 rules.body_feedback.clear();rules.cancel_search()
 if not 3 in session.data.unlocked:
  session.data.unlocked.append(3);rules.neurons+=3;rules.plexus+=2
 rules.search_attempts=0;rules.search_limit=14;rules._completed_targets.clear()
 completed.clear();deferred_targets.clear();motion.clear()
 session.new_attempt(3,rng);rules.actual_attempt=int(session.data.attempts["3"])
 rules.owners.key=session.data.key_owner
 asylum.start_attempt(hospital.data.duplicate(true))
 asylum.intake.arrive_from_hospital()
 # The first floor changes in place before the already-open staircase is
 # traversed. This transition is not a direct teleport to the upper floor.
 if metric_institution_room("lobby"):
  enter_room("lobby")
  hero_pos=portal_for_room("lobby","stairs").threshold
  route_to_door("stairs")
 else:enter_room("stairs")

func unlock_cortex() -> void:
 # S4:T24R5: one real keyed departure, one first-unlock reward; no cycle.
 rules.end_control();rules.intervention_lock=false;rules.trial.clear();rules.public_action.clear()
 rules.body_feedback.clear();rules.cancel_search();rules.gripped=false
 if not 4 in session.data.unlocked:
  session.data.unlocked.append(4);rules.neurons+=3;rules.plexus+=2
 rules.search_attempts=0;rules.search_limit=16;rules.allow_supplemental_search=true
 rules._completed_targets.clear();completed.clear();deferred_targets.clear();motion.clear()
 session.new_attempt(4,rng);rules.actual_attempt=int(session.data.attempts["4"])
 rules.owners.key=session.data.key_owner;rules.mode="exploration"
 cortex.start_attempt({"hospital":hospital.data.duplicate(true),"asylum":asylum.data.duplicate(true)})
 room_id="";enter_room("atrium")

func finish_rest() -> void:
 if int(session.data.level)>=4:return
 restart_attempt(1,false)

func restart_attempt(cycle_increment:int,revival:bool) -> void:
 if int(session.data.level)>=4 and not revival:return
 # Presentation duration is not an extra mechanical cooldown.
 var mother_unlock:bool=family!=null and not family.data.is_empty() and family.data.mother_rest and not revival
 session.data.cycle+=cycle_increment
 if revival:
  invader_id+=1;profile.invader_id=invader_id;session.data.profile=profile.duplicate(true)
 death_left=0
 vitality_panel.clear_transient()
 rules.pending_skin.clear();rules.pending_neural.clear();rules.cancel_search()
 rules.reaction_left=0;rules.stun_left=0;rules.hurt_left=0;rules.transitioning=false
 var key:String=str(int(session.data.level))
 session.data.attempts[key]=int(session.data.attempts.get(key,1))+1
 rules.actual_attempt=int(session.data.attempts[key])
 rules.next_actual_attempt()
 deferred_targets.clear()
 rules.hp=100
 rules.sp=100
 rules.neurons=maxi(5,rules.neurons)
 rules._sp_depleted=false
 rules.search_attempts=0
 rules.allow_supplemental_search=int(session.data.level)==4
 rules.search_limit=16 if session.data.level==4 else 14 if session.data.level==3 else 12 if session.data.level==2 else 10
 rules._completed_targets.clear()
 completed.clear()
 session.new_attempt(int(session.data.level),rng)
 rules.owners["key"]=session.data.key_owner
 hidden_route.data.clear();rules.mode="exploration"
 if session.data.level==2:hospital.start_attempt()
 if session.data.level==3:asylum.start_attempt(asylum.data.get("carry",{}).duplicate(true))
 if session.data.level==4:cortex.start_attempt(cortex.data.get("carry",{}).duplicate(true))
 enter_room("atrium" if session.data.level==4 else "bedroom" if session.data.level==1 else "ward")
 family.start_attempt()
 if mother_unlock:unlock_hospital()
 elif session.data.level==1:
  home.start_attempt();home.start_exploration_line()
 status_note=("死亡后实际复活" if revival else "休息实际完成")+"：新尝试；抗性增长提交；冷却不清零"

func apply_cast() -> void:
 var index_before:int=target_index if rules.search_active else -1
 var target_before:String=point_id(target_index) if target_index>=0 else ""
 var result:Dictionary=rules.apply_pending()
 if not result.ok:return
 if not result.success:
  status_note="抵抗或中断：已付费，原行动保留；%s"%str(result.reason)
  audio.cue("invalid")
  return
 var id:String=result.id
 if index_before>=0:session.note_search_interference(target_before,result)
 if home!=null:home.anomaly(index_before,result)
 if session.data.level==2:hospital.on_skill(result)
 if session.data.level==3:asylum.on_skill(result)
 if session.data.level==4:cortex.on_skill(result)
 if room_id=="hidden_street":hidden_route.on_skill(result)
 var interrupted:bool=result.search_cancelled or id in ["CONTROL","STARTLE","FEAR"]
 if action_phase=="observe_cuff" and id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  action_phase="autonomy";search_actions.observing_index=-1
 if interrupted:
  if not rules.public_action.is_empty():rules.finish_public_action(str(rules.public_action.origin))
  hero_route=PackedVector2Array();target_index=-1
  if action_phase in ["pickup","door","opening","crossing","return_bed","resting"]:action_phase="autonomy"
 if id=="FEAR" and not target_before.is_empty():
  deferred_targets[target_before]=rules.world_time+float(rules.config.timing.fear_retry)
 if id=="DRYMOUTH" and action_phase=="pickup":action_left+=float(rules.config.timing.drymouth_transfer_delay)
 if id=="STARTLE":start_motion(-hero_facing,float(rules.config.test_parameters.exploration_startle_distance) if rules.mode=="exploration" else float(rules.config.timing.combat_startle_distance),0.0 if rules.mode=="exploration" else float(rules.config.timing.combat_startle_duration))
 if id=="SKIN" and rules.mode=="combat":
  var direction:Array=result.context.get("direction",[1,0])
  start_motion(Vector2(float(direction[0]),float(direction[1])),float(rules.config.timing.combat_skin_distance),float(rules.config.timing.combat_skin_duration))
 family.on_skill(result)
 family.after_motion_started()
 hero_state="scratch" if id=="SKIN" else "hit" if id in ["GUT","TINNITUS"] else "idle"
 rules.observe("角色",str(result.event_id),str(rules.spec(id).name)+"的身体反应已实际发生")
 status_note="%s：实际反应；%s"%[id,"未完成搜寻取消，无收入" if result.search_cancelled else "保留已成立结果"]
 var cue:String={"SKIN":"SFX_SKIN","GUT":"SFX_GUT","WITHDRAW":"SFX_SEARCH_CLOTH","STARTLE":"SFX_SEARCH_CLOTH","TEMP":"SFX_SEARCH_CLOTH","PORES":"SFX_SEARCH_CLOTH"}.get(id,"")
 if not cue.is_empty():audio.cue(cue,str(result.event_id))

func cast_skin() -> void:
 cast_skill("SKIN",{})

func cast_skill(id:String,context:Dictionary) -> void:
 context.merge(skill_context(),false)
 if id=="KNEE":context.direction=[hero_facing.x,hero_facing.y]
 var result:Dictionary=rules.submit_skill(id,context)
 if not result.ok:
  menu._status.text=menu.reason_text(str(result.reason))
  audio.cue("invalid")
  return
 status_note="%s 已提交；反应等待关屏完成"%id
 close_neuron_menu()

func skill_context() -> Dictionary:
 var target:String=point_id(target_index) if target_index>=0 else "self"
 var kind:String="search" if target_index>=0 else "navigation" if not hero_route.is_empty() else action_phase
 if family!=null and family.present("father"):target="father";kind="father_event"
 elif family!=null and family.present("mother"):target="mother";kind="mother_event"
 var intended:Vector2=layout.furniture[target_index].at if target_index>=0 else hero_route[-1] if not hero_route.is_empty() else hero_pos
 var medical_rescue:bool=(session.data.level==2 and hospital.data.get("holder","")=="doctor") or (session.data.level==3 and asylum.data.get("holder","") in ["doctor","assistant"])
 var context:Dictionary={"father_rescue":family!=null and family.rescue_context(),"medical_rescue":medical_rescue,"room":room_id,"action":kind,"target":target,"intent_point":[intended.x,intended.y]}
 if room_id=="hidden_street":context.merge(hidden_route.skill_context(),true)
 return context

func world_rate() -> float:
 if room_id=="hidden_street":return 1.0
 return family.world_rate() if family!=null else 1.0

func close_neuron_menu() -> void:
 var growth:bool=menu.refund_note=="growth"
 menu.refund_note=""
 super.close_neuron_menu()
 if growth:
  add_dialogue("角色 · 疑惑","似乎 身体有些变化???")
  add_dialogue("角色","不管了 继续想办法逃出去吧")

func start_motion(direction:Vector2,distance:float,duration:float=0.0) -> void:
 var endpoint:Vector2=hero_pos
 for i in range(1,ceili(distance/0.02)+1):
  var p:Vector2=hero_pos+direction.normalized()*minf(distance,i*0.02)
  if not layout.walkable(p) or not layout.clear_segment(endpoint,p,layout.body_radius):break
  if session.data.level==4 and not cortex_segment_clear(endpoint,p):break
  endpoint=p
 if endpoint.distance_to(hero_pos)<=0.001:
  hero_route=PackedVector2Array();motion.clear();return
 hero_route=layout.path(hero_pos,endpoint)
 motion={"kind":"neural_step","endpoint":[endpoint.x,endpoint.y],"speed":distance/duration if duration>0 else 1.15}

func move_hero(delta:float) -> void:
 var before:Vector2=hero_pos
 var had_route:bool=not hero_route.is_empty()
 if session.data.level==4 and had_route:
  var proposed:Dictionary=layout.move_path(hero_pos,hero_route,1.15*delta*rules.movement_rate())
  var obstruction:Dictionary=cortex.upper_events.movement_block(hero_pos,proposed.position)
  if obstruction.is_empty():
   for id in cortex.data.get("actors",{}):
    if not cortex.present(str(id)) or str(cortex.actor(str(id)).room)!=room_id:continue
    var at:Vector2=cortex.position(str(id))
    if Geometry2D.get_closest_point_to_segment(at,hero_pos,proposed.position).distance_to(at)<0.32:
     obstruction={"body":at,"radius":0.32};break
  if not obstruction.is_empty():
   hero_state="idle"
   if obstruction.get("wait",false):return
   var detour:PackedVector2Array=cortex_detour(hero_route[-1],obstruction.body,float(obstruction.get("radius",0.42)))
   if detour.is_empty():return
   hero_route=detour
 super.move_hero(delta*rules.movement_rate())
 if hero_pos.distance_to(before)>0.0001:
  if controlled_route:
   var intended:Array=rules.control_context.get("intent_point",[before.x,before.y])
   var endpoint:Vector2=hero_route[-1] if not hero_route.is_empty() else hero_pos
   rules.controlled_execution("navigation","floor",endpoint.distance_to(Vector2(float(intended[0]),float(intended[1])))>0.08)
  footstep_left-=delta
  if footstep_left<=0:
   footstep_serial+=1;footstep_left=0.45
   audio.cue("SFX_FOOTSTEP","foot:%d"%footstep_serial)
 if had_route and hero_route.is_empty() and rules.public_action.get("kind","")=="navigation":
  vitality_panel.action_completed("navigation:%d"%rules.public_action.serial)
  rules.finish_public_action(route_action_origin)

func cortex_detour(target:Vector2,body:Vector2,radius:float=0.42) -> PackedVector2Array:
 # Temporary occupied grid cells; actual walls and actor spacing stay intact.
 var changed:Array=[]
 var obstacles:Array=[{"pos":body,"radius":radius}]
 for id in cortex.data.get("actors",{}):
  if not cortex.present(str(id)) or str(cortex.actor(str(id)).room)!=room_id:continue
  obstacles.append({"pos":cortex.position(str(id)),"radius":0.42 if id=="twitch" else 0.32})
 var start:Vector2i=Vector2i((hero_pos/layout.CELL).round())
 for y in range(39):
  for x in range(57):
   var cell:=Vector2i(x,y)
   if cell==start or layout.grid.is_point_solid(cell):continue
   for obstacle in obstacles:
    if (Vector2(cell)*layout.CELL).distance_to(obstacle.pos)<float(obstacle.radius)+0.04:
     changed.append(cell);layout.grid.set_point_solid(cell,true);break
 var route:PackedVector2Array=layout.path(hero_pos,target)
 for cell in changed:layout.grid.set_point_solid(cell,false)
 var previous:Vector2=hero_pos
 for step in route:
  for obstacle in obstacles:
   if Geometry2D.get_closest_point_to_segment(obstacle.pos,previous,step).distance_to(obstacle.pos)<float(obstacle.radius):return PackedVector2Array()
  if not layout.clear_segment(previous,step,layout.body_radius):return PackedVector2Array()
  previous=step
 return route

func cortex_segment_clear(from:Vector2,to:Vector2) -> bool:
 if cortex==null or not cortex.enabled:return true
 for id in cortex.data.get("actors",{}):
  if not cortex.present(str(id)) or str(cortex.actor(str(id)).room)!=room_id:continue
  var at:Vector2=cortex.position(str(id));var radius:float=0.42 if id=="twitch" else 0.32
  # If an existing contact pose starts close, retreat is allowed; pushing
  # farther through the same actor is not.
  if from.distance_to(at)<radius and to.distance_to(at)>from.distance_to(at):continue
  if Geometry2D.get_closest_point_to_segment(at,from,to).distance_to(at)<radius:return false
 return true

func cancel_control_route() -> void:
 if session.data.level==4 and action_phase in ["cortex_observing","cortex_observation_route"]:cancel_cortex_observation()
 if session.data.level==3 and action_phase in ["asylum_reading","asylum_read_route","asylum_item"]:cancel_asylum_read()
 if controlled_route:
  hero_route=PackedVector2Array()
  controlled_route=false
 if action_phase in ["controlled_search","controlled_pickup","controlled_observe_cuff"]:
  hero_route=PackedVector2Array();target_index=-1;action_phase="autonomy"

func open_system_page(key:String) -> void:
 if world_paused():return
 menu.open_page(key)
 sync_audio_pause()

func world_mouse_position(screen:Vector2) -> Vector2:
 return world_viewport.get_canvas_transform().affine_inverse()*(screen*Vector2(world_viewport.size)/Vector2(1280,720))

func _unhandled_input(event:InputEvent) -> void:
 if input_lock_frames>0 or tutorial_ui!=null or opening_ui!=null:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_X:
  if first_damage and not menu.visible and not audio_panel.visible:vitality_panel.toggle_manual()
  get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and not menu.visible and dialogue_queue.is_empty():
  paused_manual=not paused_manual;return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F and room_id=="hidden_street" and not world_paused():
  rules.begin_kick({"direction":[hero_facing.x,hero_facing.y]},true)
  get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.pressed and not world_paused():
  var pixel:Vector2=world_mouse_position(event.position)
  var actor_screen:Vector2=layout.project(hero_pos)
  var item_click:bool=false
  if session.data.level==3 and rules.control_left>0 and event.button_index==MOUSE_BUTTON_LEFT:
   for item in view.asylum_props():
    if item.room!=room_id or str(item.kind) not in ["corpse","relic","note","band","box","bag","ward_window"]:continue
    if pixel.distance_to(view.asylum_item_pixel(item))<=13:item_click=true;break
  if view.hero_body_rect().has_point(pixel) and not item_click:
   if event.button_index==MOUSE_BUTTON_RIGHT:open_system_page("tree");return
   if event.button_index==MOUSE_BUTTON_LEFT:open_neuron_menu();return
  if rules.control_left>0 and not rules.body_busy() and not rules.gripped:
   var point:Vector2=layout.unproject(pixel)
   if event.button_index==MOUSE_BUTTON_RIGHT:
    hero_facing=(point-hero_pos).normalized();return
   if event.button_index==MOUSE_BUTTON_LEFT and (item_click or not view.hero_body_rect().has_point(pixel)):
    for door in visible_doors:
     if view.door_hit(door,pixel):
      if (room_id=="bedroom" and door=="lobby") or (session.data.level==2 and door=="stairs") or door in ["cortex_exit","combat_exit"]:
       if not has_key():status_note="门尚未具备开锁条件";return
      cancel_cortex_observation();cancel_hospital_observation();cancel_asylum_read();rules.cancel_search();route_to_door(door);controlled_route=false;return
    if key_visible() and not has_key() and pixel.distance_to(layout.project(key_position())+Vector2(0,-12))<18:
     cancel_cortex_observation()
     cancel_hospital_observation()
     cancel_asylum_read()
     rules.cancel_search()
     hero_route=layout.path(hero_pos,key_position());action_phase="controlled_pickup";controlled_route=false;return
    if session.data.level==3:
     if room_id=="lobby" and asylum.present("registration_nurse") and (Rect2(layout.project(asylum.position("registration_nurse"))+Vector2(-24,-136),Vector2(48,136)).has_point(pixel) if metric_institution_room(room_id) else pixel.distance_to(layout.project(asylum.position("registration_nurse"))+Vector2(0,-25))<=18):
      if route_registration_followup():return
     for item in view.asylum_props():
      if item.room!=room_id or str(item.kind) not in ["corpse","relic","note","band","box","bag","ward_window"]:continue
      var at:=Vector2(float(item.pos[0]),float(item.pos[1]))
      if pixel.distance_to(view.asylum_item_pixel(item))>13:continue
      if item.kind=="ward_window":
       var window_request:Dictionary=asylum.ward_window_request(true)
       if window_request.is_empty():status_note="观察窗只能从病房门外侧靠近操作";return
       if not route_asylum_read(window_request,true):status_note="观察窗外侧操作位不可达"
       return
      var id:String="corpse_tag" if item.kind=="corpse" else str(item.id)
      var observation_request:Dictionary=asylum.observations.for_item(id)
      if not observation_request.is_empty() and not event.shift_pressed:
       if route_asylum_read(observation_request,true):return
      if event.shift_pressed and rules.owners.get(id,"")=="hero":status_note="已经持有；普通点击可查看";return
      var kind:String="band_take" if event.shift_pressed else "band_read"
      if id!="asylum_transport_band":kind="take" if event.shift_pressed and asylum.trace_events.config.relics.has(id) else "trace"
      if route_asylum_read({"id":id,"kind":kind,"pos":[at.x,at.y]},true):return
      status_note="该实物当前不可接近；未读取、未取得";return
    if session.data.level==4:
     for observation in cortex.observation_markers():
      if str(observation.room)!=room_id:continue
      var subject:Vector2=cortex.target_position(observation)
      if pixel.distance_to(layout.project(subject)+Vector2(0,-12))<15:
       if route_cortex_observation(observation,true):return
    var clicked_furniture:int=view.furniture_at_pixel(pixel) if layout.geometry_version>=2 else -1
    for i in range(layout.furniture.size()):
     if (i==clicked_furniture if layout.geometry_version>=2 else layout.furniture[i].rect.has_point(point)):
      if session.data.level==4 and not event.shift_pressed:
       var observation:Dictionary=cortex.candidate(room_id,i)
       if not observation.is_empty() and route_cortex_observation(observation,true):return
      if session.data.level==2 and (i>=Session.ROOM_POINTS[room_id].size() or point_id(i) in completed):
       var observation:Dictionary=hospital.observations.candidate(room_id,i)
       if not observation.is_empty() and route_hospital_observation(observation,true):return
      if session.data.level==3 and room_id=="office" and i in asylum.records.read_candidates():
       var at:Vector2=layout.furniture[i].at
       if route_asylum_read({"kind":"record","index":i,"pos":[at.x,at.y]},true):return
      if session.data.level==3 and room_id=="lobby" and i==0 and route_registration_followup():return
      if session.data.level==3:
       var observation:Dictionary=asylum.observations.candidate(room_id,i)
       if not observation.is_empty() and route_asylum_read({"kind":"observation","id":str(observation.id),"pos":[observation.pos.x,observation.pos.y]},true):return
      if room_id=="bedroom" and i==6 and point_id(i) in completed and not "cuff_seam" in rules.known:
       hero_route=layout.path(hero_pos,layout.furniture[i].at)
       search_actions.observing_index=i;controlled_route=false;action_phase="controlled_observe_cuff";return
      if room_id=="hidden_street" or i>=Session.point_names(int(session.data.level),room_id).size() or point_id(i) in completed or (rules.search_attempts>=rules.search_limit and not rules.allow_supplemental_search):
       status_note="此处当前没有可执行搜寻";return
      rules.cancel_search()
      cancel_cortex_observation()
      cancel_hospital_observation()
      cancel_asylum_read()
      target_index=i
      hero_route=layout.path(hero_pos,layout.furniture[i].at)
      controlled_route=false
      action_phase="controlled_search"
      return
    rules.cancel_search()
    cancel_cortex_observation()
    family.data.eating.clear()
    var path:PackedVector2Array=layout.path(hero_pos,point)
    if path.is_empty():status_note="目标不可达";return
    cancel_hospital_observation()
    cancel_asylum_read()
    hero_route=path;controlled_route=true;target_index=-1;action_phase="autonomy"
    route_action_origin="controlled";rules.begin_public_action("navigation","floor","controlled",room_id)
    return
 super._unhandled_input(event)

func update_ui() -> void:
 if not campaign_ready:return
 control_end_button.visible=rules.control_left>0
 if rules.control_left>0:control_end_button.text="交回 %.1fs"%rules.control_left
 scenario_label.text="第%d关 · %s · 实际尝试%d"%[session.data.level,room_title(room_id),rules.actual_attempt]
 status_label.text="神经元 %d   神经簇 %d    %s #%d"%[rules.neurons,rules.plexus,profile.name,int(profile.invader_id)]
 view.self_modulate=Color.WHITE.lerp(Color("63716b"),float(view.rest_pose().t)*0.6)
 if not family.data.is_empty() and family.data.blood_door:view.self_modulate=view.self_modulate.lerp(Color("aaa0a2"),0.28)
 vitality_panel.set_reduced_effects(reduced_effects)
 vitality_panel.refresh(rules.hp,rules.sp)
 father_prompt.refresh()
 status_visible=vitality_panel.visible
 debug_label.text="钥匙%s · 视野%.2f×"%["已携带" if has_key() else "未取得",ZOOM_STEPS[zoom_index]]
 state_label.text="%s / %s    搜寻 %d/%d    左键身体：神经菜单 · 空格：暂停"%[action_phase,hero_state,rules.search_attempts,rules.search_limit]
 if session.data.level==4:state_label.text="%s / %s    搜寻 %d（初始16，可补查）  掌控：左键查看 / Shift搜寻"%[action_phase,hero_state,rules.search_attempts]
 event_label.text=status_note

func snapshot_data() -> Dictionary:
 var saved_rules:Dictionary={}
 for info in rules.get_property_list():
  if int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved_rules[info.name]=rules.get(info.name)
 return {"schema":3,"profile":profile.duplicate(true),"session":session.data.duplicate(true),"rules":saved_rules.duplicate(true),
  "room_id":room_id,"hero_pos":[hero_pos.x,hero_pos.y],"hero_facing":[hero_facing.x,hero_facing.y],
  "route":Array(hero_route).map(func(p):return [p.x,p.y]),"completed":completed.duplicate(),"target_index":target_index,
  "drawer_open":drawer_open.duplicate(true),"world_visual_time":world_visual_time,"hero_state":hero_state,
  "action_phase":action_phase,"action_left":action_left,"destination":destination,"rng_state":str(rng.state),
  "paused_manual":paused_manual,"closing_left":closing_left,"dialogue":dialogue_queue.duplicate(true),
  "menu_open":menu.visible,"menu_page":menu.panel_mode,"zoom_index":zoom_index,"presentation_id":presentation_id,
  "deferred_targets":deferred_targets.duplicate(true),"motion":motion.duplicate(true),"controlled_route":controlled_route,
  "audio_state":audio.snapshot_playback(),"footstep_left":footstep_left,"footstep_serial":footstep_serial,"home_state":home.data.duplicate(true),"family_state":family.data.duplicate(true),"death_left":death_left,"first_damage":first_damage,"status_visible":status_visible,"first_damage_pending":first_damage_pending,"vitality_display":vitality_panel.snapshot(),
  "search_props":search_actions.states.duplicate(true),"prop_receipts":search_actions.receipts.duplicate(true),"observing_index":search_actions.observing_index,"route_action_origin":route_action_origin,"search_action_origin":search_action_origin,
  "hospital_state":hospital.data.duplicate(true),"asylum_state":asylum.data.duplicate(true),"cortex_state":cortex.data.duplicate(true),"hidden_state":hidden_route.data.duplicate(true),"opening_state":opening_ui.snapshot() if opening_ui!=null else {}}
 # Animal actions and their unique search/transfer receipts survive loads.

func restore_snapshot(data:Dictionary) -> bool:
 if int(data.get("schema",0)) not in [1,2,3] or not data.has("session") or not data.has("rules"):return false
 var proposed:Dictionary=data.session
 if int(proposed.get("level",0)) not in [1,2,3,4]:return false
 var saved_room:String=str(data.get("room_id",""))
 if int(proposed.level)==4:
  if not CortexMap.ROOM_NAMES.has(saved_room):return false
 elif int(proposed.level)==3:
  if not AsylumMap.ROOM_NAMES.has(saved_room):return false
 elif not Session.ROOM_POINTS.has(saved_room) and saved_room!="hidden_street":return false
 restoring=true
 if opening_ui!=null:opening_ui.queue_free();opening_ui=null
 runtime_generation+=1
 profile=data.profile.duplicate(true)
 invader_id=int(profile.invader_id)
 session.data=data.session.duplicate(true)
 # Continue an in-flight legacy action in its original geometry. The next
 # real rest/revival constructs the new room; no saved contact is teleported.
 if not session.data.has("room_geometry_version"):session.data.room_geometry_version=1
 if not session.data.has("institution_geometry_version"):session.data.institution_geometry_version=1
 session.normalize_restored_numbers()
 home.data=data.get("home_state",{}).duplicate(true)
 search_actions.states=data.get("search_props",{}).duplicate(true)
 search_actions.receipts=data.get("prop_receipts",{}).duplicate(true)
 search_actions.observing_index=int(data.get("observing_index",-1))
 rules=NeuralRules.new()
 var restored_rules:Dictionary=data.rules.duplicate(true)
 for key in restored_rules:
  if key=="config":continue
  if key=="facts":rules.facts.assign(restored_rules[key])
  else:rules.set(key,restored_rules[key])
 rules.sync_skin()
 rules.allow_supplemental_search=int(session.data.level)==4
 family.restore_state(data.get("family_state",{}))
 hospital.restore(data.get("hospital_state",{}))
 asylum.restore(data.get("asylum_state",{}))
 cortex.restore(data.get("cortex_state",{}))
 hidden_route.data=data.get("hidden_state",{}).duplicate(true)
 if family.data.is_empty():family.start_attempt()
 death_left=float(data.get("death_left",0))
 first_damage=bool(data.get("first_damage",false))
 status_visible=bool(data.get("status_visible",false))
 vitality_panel.restore(data.get("vitality_display",{}),status_visible)
 bind_status_rules()
 first_damage_pending=bool(data.get("first_damage_pending",false))
 menu.rules=rules
 room_id=""
 enter_room(str(data.room_id))
 hero_pos=Vector2(float(data.hero_pos[0]),float(data.hero_pos[1]))
 hero_facing=Vector2(float(data.hero_facing[0]),float(data.hero_facing[1]))
 # Saved B3 development stops are not story locks. Release only the proven
 # old keyed stair endpoint; normal door logic performs the new transition.
 if int(session.data.level)==3 and room_id=="stairs" and has_key() and bool(session.data.exploration_boundary) and hero_pos.distance_to(AsylumMap.doorway("stairs","cortex_exit"))<=0.06:
  session.data.exploration_boundary=false
 hero_route=PackedVector2Array()
 for p in data.route:hero_route.append(Vector2(float(p[0]),float(p[1])))
 completed.assign(data.completed)
 if session.migrate_key_discovery(completed,str(data.get("rng_state",""))):
  rules.owners.key=str(session.data.key_owner)
 target_index=int(data.target_index)
 drawer_open=data.drawer_open.duplicate(true)
 world_visual_time=float(data.world_visual_time)
 hero_state=str(data.hero_state)
 action_phase=str(data.action_phase)
 action_left=float(data.action_left)
 destination=str(data.destination)
 deferred_targets=data.get("deferred_targets",{}).duplicate(true)
 motion=data.get("motion",{}).duplicate(true)
 controlled_route=bool(data.get("controlled_route",false))
 route_action_origin=str(data.get("route_action_origin","autonomous"))
 search_action_origin=str(data.get("search_action_origin","autonomous"))
 footstep_left=float(data.get("footstep_left",0))
 footstep_serial=int(data.get("footstep_serial",0))
 rng.state=str(data.rng_state).to_int()
 paused_manual=bool(data.paused_manual)
 closing_left=float(data.closing_left)
 dialogue_queue.assign(data.dialogue)
 show_dialogue()
 zoom_index=int(data.zoom_index)
 camera.zoom=Vector2.ONE*BASE_ZOOM*ZOOM_STEPS[zoom_index]
 presentation_id=str(data.get("presentation_id","a"))
 view.catalog.select_set(presentation_id)
 if data.menu_open:menu.open_page(str(data.get("menu_page","cast")))
 else:menu.close_menu()
 sync_audio_pause()
 audio.restore_playback(data.get("audio_state",{}))
 restoring=false
 if not bool(profile.get("opening_completed",true)):open_parasite(data.get("opening_state",{}))
 if int(data.schema)==1:status_note="已载入旧版存档；下次保存升级，原有效档单独保留为profile.schema1.json"
 return true
