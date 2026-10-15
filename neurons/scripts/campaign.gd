extends "res://scripts/bedroom_sample.gd"
## First real campaign batch: profile, durable attempt, L1/L2 exploration.
## NPC branches and subsequent levels remain explicitly in the coverage list.
signal return_to_title
signal visual_preferences_changed(value:bool)
signal status_preferences_changed(value:bool)
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
var save_requested:bool=false
var title_requested:bool=false
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
 next.pressed.connect(advance_dialogue)
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
 if not bool(profile.get("tutorial_completed",true)):open_tutorial(false)

func open_tutorial(guide:bool) -> void:
 if tutorial_ui!=null or rules.hp<=0:return
 tutorial_ui=Tutorial.new(self)
 tutorial_ui.guide_only=guide
 add_child(tutorial_ui)

func world_paused() -> bool:
 return tutorial_ui!=null or super.world_paused()

func sync_audio_pause() -> void:
 if audio==null:return
 audio.set_world_paused(world_paused(),paused_manual or menu.visible or closing_left>0 or audio_panel.visible or tutorial_ui!=null)

func _process(delta:float) -> void:
 if not campaign_ready:return
 process_requests()
 if not campaign_ready:return
 if family.collapse_active() or rules.hp<=0:
  closing_left=maxf(0.0,closing_left-delta)
  audio.set_world_paused(true,paused_manual or menu.visible or closing_left>0 or audio_panel.visible)
 if family.collapse_active():
  sync_audio_pause()
  if not paused_manual and not menu.visible and closing_left<=0 and not audio_panel.visible:
   if family.advance_collapse(delta):restart_attempt(3,true)
  update_ui();view.queue_redraw();return
 if rules.hp<=0:
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
    return_to_title.emit()
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
 return {"bedroom":"卧室","ward":"小病房","lobby":"候诊区","clinic":"诊室","pharmacy":"药房","office":"医护办公室","stairs":"楼梯"}.get(id,id)

func enter_room(id:String) -> void:
 if not room_id.is_empty():session.data.rooms[room_id]={"drawer":drawer_open.duplicate(true)}
 room_id=id
 layout=Layout.new()
 if id!="bedroom" and id!="ward":
  layout.furniture.clear()
  for i in range(Session.ROOM_POINTS[id].size()):
   var side:int=i%2
   var row:int=i/2
   var p:=Vector2(0.25 if side==0 else 4.85,0.65+row*0.51)
   var at:=p+Vector2(0.75 if side==0 else -0.3,0.2)
   layout.furniture.append({"id":"%s:%d"%[id,i],"name":Session.ROOM_POINTS[id][i],"rect":Rect2(p,Vector2(0.5,0.35)),"at":at,"height":25.0,"color":Color("819593"),"kind":"drawer"})
  layout._init()
 view.layout=layout
 hero_pos=layout.BED_STOP if id=="bedroom" or id=="ward" else Vector2(2.8,1.4)
 hero_route=PackedVector2Array()
 target_index=-1
 hero_state="idle"
 drawer_open=session.data.rooms.get(id,{}).get("drawer",{}).duplicate(true)
 visible_doors=[]
 if id=="bedroom":visible_doors=["lobby"]
 elif Session.GRAPH.has(id):visible_doors=Session.GRAPH[id].duplicate()
 if id=="lobby":visible_doors.append("stairs")
 input_lock_frames=3
 action_phase="autonomy"
 status_note="进入"+room_title(id)
 if search_actions!=null:search_actions.enter_room()
 if audio!=null:
  if id!="bedroom":audio.stop_channel("ambience")

func point_id(index:int) -> String:
 return "%s:%d"%[room_id,index]

func door_point(id:String) -> Vector2:
 if room_id in ["bedroom","ward"]:return layout.DOOR
 var index:int=maxi(0,visible_doors.find(id))
 return Vector2(1.25+index*0.78,0.24)

func has_key() -> bool:
 return session.has_key()

func key_visible() -> bool:
 return bool(session.data.key_seen) and str(session.data.key_target).get_slice(":",0)==room_id

func key_position() -> Vector2:
 if home!=null and not home.data.is_empty() and not home.data.key_drop.is_empty():
  return Vector2(float(home.data.key_drop[0]),float(home.data.key_drop[1]))
 var index:int=str(session.data.key_target).get_slice(":",1).to_int()
 return layout.furniture[index].at if index<layout.furniture.size() else hero_pos

func advance_world(delta:float) -> void:
 bind_status_rules()
 if home!=null:home.tick(delta)
 if family!=null:family.tick(delta)
 if not rules.search_active and rules.public_action.get("kind","")=="search" and rules.settled.has(rules._search_id):rules.finish_public_action(search_action_origin)
 world_visual_time+=delta
 var was_controlled:bool=rules.control_left>0
 var result:Dictionary=rules.tick(delta)
 var completed_index:int=target_index
 search_actions.tick(bool(result.search_completed))
 if rules.hp<=0:return
 if result.search_completed:
  vitality_panel.action_completed("search:"+str(result.event_id))
  rules.finish_public_action(search_action_origin)
  var id:String=result.target_id
  completed.append(id)
  if id==session.data.key_target:
   session.data.key_seen=true
   if not id in rules.known:rules.known.append(id)
   action_phase="pickup"
   action_left=0.4
   hero_state="give"
   status_note="已实际发现钥匙；伸手拿取中"
  else:
   action_phase="autonomy"
   hero_state="idle"
   status_note="搜寻完成：+1神经元；此处无钥匙"
  if completed_index>=0:search_actions.on_complete(completed_index,id==session.data.key_target)
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
  hero_state="grab" if attack.get("phase","")=="prepare" else "give"
  return
 if not motion.is_empty():
  if rules.hurt_left>0 or rules.stun_left>0:
   motion.clear();hero_route=PackedVector2Array();return
  if not rules.body_busy() and (not rules.gripped or motion.get("allow_gripped",false)):
   var moved:Dictionary=layout.move_path(hero_pos,hero_route,float(motion.speed)*delta)
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
    rules.search_duration*=1.25 if session.data.level==2 else 1.0
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
 if action_phase=="door" or action_phase=="return_bed":
  move_hero(delta)
  var point:Vector2=door_point(destination) if action_phase=="door" else layout.BED_STOP
  if hero_pos.distance_to(point)>0.035:return
  action_phase="opening" if action_phase=="door" else "resting"
  action_left=0.6 if action_phase=="opening" else 1.2
  hero_state="give" if action_phase=="opening" else "idle"
  if action_phase=="opening":audio.cue("SFX_DOOR_OPEN","door:%d:%s:%s"%[rules.actual_attempt,room_id,destination])
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
  elif destination=="stairs":
   session.data.exploration_boundary=true
   status_note="已到第二关出口；第三关及人物分支待接入，当前不宣称全游戏完成"
  elif room_id=="bedroom":unlock_hospital()
  else:enter_room(destination)
  return
 if has_key():
  route_to_door("lobby" if room_id=="bedroom" or room_id!="lobby" else "stairs")
  return
 if key_visible():
  if hero_pos.distance_to(key_position())<=0.035:
   action_phase="pickup";action_left=0.4;hero_state="give"
  else:
   if hero_route.is_empty():hero_route=layout.path(hero_pos,key_position())
   move_hero(delta)
  return
 if rules.search_attempts>=rules.search_limit or rules.sp<50:
  if family!=null and family.try_auto_food():return
  if home!=null and home.present("dog") and home.data.dog.phase in ["walk","search","bring"]:return
  if room_id not in ["bedroom","ward"]:
   route_to_door(session.next_room(room_id,"ward"))
  else:
   action_phase="return_bed"
   hero_route=layout.path(hero_pos,layout.BED_STOP)
  return
 if action_phase=="autonomy" and family!=null and family.try_auto_food():return
 choose_public_target(delta)

func choose_public_target(delta:float) -> void:
 # Only public sampled targets and already-completed receipts are inspected.
 # This function never reads the hidden key_target field.
 if target_index<0:
  var closest:float=INF
  for i in range(layout.furniture.size()):
   var id:String=point_id(i)
   if not id in session.data.targets or id in completed:continue
   if home!=null and home.reserved(i):continue
   if float(deferred_targets.get(id,0))>rules.world_time:continue
   var distance:float=hero_pos.distance_to(layout.furniture[i].at)
   if distance<closest:closest=distance;target_index=i
  if target_index<0:
   for id in session.data.targets:
    if id in completed:continue
    if float(deferred_targets.get(id,0))>rules.world_time:continue
    var room:String=str(id).get_slice(":",0)
    var next:String=session.next_room(room_id,room)
    if not next.is_empty():route_to_door(next);return
   return
 var target:Dictionary=layout.furniture[target_index]
 if hero_route.is_empty() and hero_pos.distance_to(target.at)>0.035:
  hero_route=layout.path(hero_pos,target.at)
  if not hero_route.is_empty():
   route_action_origin="autonomous";rules.begin_public_action("navigation",point_id(target_index),"autonomous",room_id)
 move_hero(delta)
 if hero_pos.distance_to(target.at)<=0.035:
  hero_facing=(target.rect.get_center()-hero_pos).normalized()
  rules.begin_public_action("search",point_id(target_index),"autonomous",room_id)
  if rules.begin_search(point_id(target_index)):
   search_action_origin="autonomous"
   rules.search_duration*=1.25 if session.data.level==2 else 1.0
   hero_state="search"

func route_to_door(id:String) -> void:
 if not id in visible_doors:return
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
 enter_room("lobby")

func finish_rest() -> void:
 restart_attempt(1,false)

func restart_attempt(cycle_increment:int,revival:bool) -> void:
 # Presentation duration is not an extra mechanical cooldown.
 var mother_unlock:bool=family!=null and not family.data.is_empty() and family.data.mother_rest and not revival
 session.data.cycle+=cycle_increment
 if revival:
  invader_id+=1;profile.invader_id=invader_id;session.data.profile=profile.duplicate(true)
 death_left=0
 vitality_panel.clear_transient()
 rules.pending_skin.clear();rules.pending_neural.clear();rules.cancel_search()
 rules.reaction_left=0;rules.stun_left=0;rules.hurt_left=0;rules.transitioning=false
 var key:String=str(session.data.level)
 session.data.attempts[key]=int(session.data.attempts.get(key,1))+1
 rules.actual_attempt=int(session.data.attempts[key])
 rules.next_actual_attempt()
 deferred_targets.clear()
 rules.hp=100
 rules.sp=100
 rules.neurons=maxi(5,rules.neurons)
 rules._sp_depleted=false
 rules.search_attempts=0
 rules._completed_targets.clear()
 completed.clear()
 session.new_attempt(int(session.data.level),rng)
 rules.owners["key"]=session.data.key_owner
 enter_room("bedroom" if session.data.level==1 else "ward")
 family.start_attempt()
 if mother_unlock:unlock_hospital()
 elif session.data.level==1:
  home.start_attempt();home.start_exploration_line()
 status_note="休息实际完成：新尝试；抗性增长提交；冷却不清零"

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
 if home!=null:home.anomaly(index_before,result)
 var interrupted:bool=result.search_cancelled or id in ["CONTROL","STARTLE","FEAR"]
 if action_phase=="observe_cuff" and id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  action_phase="autonomy";search_actions.observing_index=-1
 if interrupted:
  if not rules.public_action.is_empty():rules.finish_public_action(str(rules.public_action.origin))
  hero_route=PackedVector2Array();target_index=-1
  if action_phase in ["pickup","opening","resting"]:action_phase="autonomy"
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
 return {"father_rescue":family!=null and family.rescue_context(),"room":room_id,"action":kind,"target":target,"intent_point":[intended.x,intended.y]}

func world_rate() -> float:
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
  if not layout.walkable(p) or not layout.clear_segment(endpoint,p,layout.RADIUS):break
  endpoint=p
 if endpoint.distance_to(hero_pos)<=0.001:
  hero_route=PackedVector2Array();motion.clear();return
 hero_route=layout.path(hero_pos,endpoint)
 motion={"kind":"neural_step","endpoint":[endpoint.x,endpoint.y],"speed":distance/duration if duration>0 else 1.15}

func move_hero(delta:float) -> void:
 var before:Vector2=hero_pos
 var had_route:bool=not hero_route.is_empty()
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

func cancel_control_route() -> void:
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
 return world_viewport.get_canvas_transform().affine_inverse()*(screen/2.0)

func _unhandled_input(event:InputEvent) -> void:
 if input_lock_frames>0 or tutorial_ui!=null:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_X:
  if first_damage and not menu.visible and not audio_panel.visible:vitality_panel.toggle_manual()
  get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and not menu.visible and dialogue_queue.is_empty():
  paused_manual=not paused_manual;return
 if event is InputEventMouseButton and event.pressed and not world_paused():
  var pixel:Vector2=world_mouse_position(event.position)
  var actor_screen:Vector2=layout.project(hero_pos)
  if view.hero_body_rect().has_point(pixel):
   if event.button_index==MOUSE_BUTTON_RIGHT:open_system_page("tree");return
   if event.button_index==MOUSE_BUTTON_LEFT:open_neuron_menu();return
  if rules.control_left>0 and not rules.body_busy() and not rules.gripped:
   var point:Vector2=layout.unproject(pixel)
   if event.button_index==MOUSE_BUTTON_RIGHT:
    hero_facing=(point-hero_pos).normalized();return
   if event.button_index==MOUSE_BUTTON_LEFT and not view.hero_body_rect().has_point(pixel):
    for door in visible_doors:
     if pixel.distance_to(layout.project(door_point(door)))<18:
      if door in ["stairs","lobby"] and room_id=="bedroom" or door=="stairs":
       if not has_key():status_note="门尚未具备开锁条件";return
      rules.cancel_search();route_to_door(door);controlled_route=false;return
    if key_visible() and not has_key() and pixel.distance_to(layout.project(key_position())+Vector2(0,-12))<18:
     rules.cancel_search()
     hero_route=layout.path(hero_pos,key_position());action_phase="controlled_pickup";controlled_route=false;return
    for i in range(layout.furniture.size()):
     if layout.furniture[i].rect.has_point(point):
      if room_id=="bedroom" and i==6 and point_id(i) in completed and not "cuff_seam" in rules.known:
       hero_route=layout.path(hero_pos,layout.furniture[i].at)
       search_actions.observing_index=i;controlled_route=false;action_phase="controlled_observe_cuff";return
      if i>=Session.ROOM_POINTS[room_id].size() or point_id(i) in completed or rules.search_attempts>=rules.search_limit:
       status_note="此处当前没有可执行搜寻";return
      rules.cancel_search()
      target_index=i
      hero_route=layout.path(hero_pos,layout.furniture[i].at)
      controlled_route=false
      action_phase="controlled_search"
      return
    rules.cancel_search()
    family.data.eating.clear()
    var path:PackedVector2Array=layout.path(hero_pos,point)
    if path.is_empty():status_note="目标不可达";return
    hero_route=path;controlled_route=true;target_index=-1;action_phase="autonomy"
    route_action_origin="controlled";rules.begin_public_action("navigation","floor","controlled",room_id)
    return
 super._unhandled_input(event)

func update_ui() -> void:
 if not campaign_ready:return
 control_end_button.visible=rules.control_left>0
 if rules.control_left>0:control_end_button.text="交回 %.1fs"%rules.control_left
 scenario_label.text="第%d关 · %s · 实际尝试%d"%[session.data.level,room_title(room_id),rules.actual_attempt]
 status_label.text="N %d   C %d    %s #%d"%[rules.neurons,rules.plexus,profile.name,int(profile.invader_id)]
 view.self_modulate=Color.WHITE.lerp(Color("63716b"),float(view.rest_pose().t)*0.6)
 if not family.data.is_empty() and family.data.blood_door:view.self_modulate=view.self_modulate.lerp(Color("aaa0a2"),0.28)
 vitality_panel.set_reduced_effects(reduced_effects)
 vitality_panel.refresh(rules.hp,rules.sp)
 father_prompt.refresh()
 status_visible=vitality_panel.visible
 debug_label.text="钥匙%s · 视野%.2f×"%["已携带" if has_key() else "未取得",ZOOM_STEPS[zoom_index]]
 state_label.text="%s / %s    搜寻 %d/%d    左键身体：神经菜单 · 空格：暂停"%[action_phase,hero_state,rules.search_attempts,rules.search_limit]
 event_label.text=status_note

func snapshot_data() -> Dictionary:
 var saved_rules:Dictionary={}
 for info in rules.get_property_list():
  if int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved_rules[info.name]=rules.get(info.name)
 return {"schema":2,"profile":profile.duplicate(true),"session":session.data.duplicate(true),"rules":saved_rules.duplicate(true),
  "room_id":room_id,"hero_pos":[hero_pos.x,hero_pos.y],"hero_facing":[hero_facing.x,hero_facing.y],
  "route":Array(hero_route).map(func(p):return [p.x,p.y]),"completed":completed.duplicate(),"target_index":target_index,
  "drawer_open":drawer_open.duplicate(true),"world_visual_time":world_visual_time,"hero_state":hero_state,
  "action_phase":action_phase,"action_left":action_left,"destination":destination,"rng_state":str(rng.state),
  "paused_manual":paused_manual,"closing_left":closing_left,"dialogue":dialogue_queue.duplicate(true),
  "menu_open":menu.visible,"menu_page":menu.panel_mode,"zoom_index":zoom_index,"presentation_id":presentation_id,
  "deferred_targets":deferred_targets.duplicate(true),"motion":motion.duplicate(true),"controlled_route":controlled_route,
  "audio_state":audio.snapshot_playback(),"footstep_left":footstep_left,"footstep_serial":footstep_serial,"home_state":home.data.duplicate(true),"family_state":family.data.duplicate(true),"death_left":death_left,"first_damage":first_damage,"status_visible":status_visible,"first_damage_pending":first_damage_pending,"vitality_display":vitality_panel.snapshot(),
  "search_props":search_actions.states.duplicate(true),"prop_receipts":search_actions.receipts.duplicate(true),"observing_index":search_actions.observing_index,"route_action_origin":route_action_origin,"search_action_origin":search_action_origin}
 # Animal actions and their unique search/transfer receipts survive loads.

func restore_snapshot(data:Dictionary) -> bool:
 if int(data.get("schema",0)) not in [1,2] or not data.has("session") or not data.has("rules"):return false
 var proposed:Dictionary=data.session
 if int(proposed.get("level",0)) not in [1,2] or not Session.ROOM_POINTS.has(str(data.get("room_id",""))):return false
 runtime_generation+=1
 profile=data.profile.duplicate(true)
 invader_id=int(profile.invader_id)
 session.data=data.session.duplicate(true)
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
 family.restore_state(data.get("family_state",{}))
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
 hero_route=PackedVector2Array()
 for p in data.route:hero_route.append(Vector2(float(p[0]),float(p[1])))
 completed.assign(data.completed)
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
 if int(data.schema)==1:status_note="已载入旧版存档；下次保存升级，原有效档单独保留为profile.schema1.json"
 return true
