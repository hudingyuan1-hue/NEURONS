extends "res://scripts/bedroom_sample.gd"
## First real campaign batch: profile, durable attempt, L1/L2 exploration.
## NPC branches and subsequent levels remain explicitly in the coverage list.
signal return_to_title
const Session=preload("res://scripts/core/campaign_session.gd")
const Store=preload("res://scripts/core/save_store.gd")
const CampaignView=preload("res://scripts/world/campaign_view.gd")
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
var presentation_id:String="a"
var campaign_ready:bool=false
var request_load:bool=false

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
 label_at("角色自主探索 · 美术占位可替换 · 本批NPC/第三关以后待接",Vector2(365,53),13)
 var footer:=ColorRect.new()
 footer.position=Vector2(0,589)
 footer.size=Vector2(1280,131)
 footer.color=Color("202a2f")
 footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(footer)
 button_at("保存",Vector2(24,603),110,func():save_requested=true)
 button_at("读取",Vector2(145,603),110,func():request_load=true)
 button_at("返回标题",Vector2(266,603),130,return_to_title.emit)
 button_at("音量",Vector2(410,603),100,toggle_audio_controls)
 button_at("复位视野",Vector2(522,603),130,reset_zoom)
 button_at("降低反馈",Vector2(665,603),130,toggle_effects)
 state_label=label_at("",Vector2(24,649),14)
 event_label=label_at("",Vector2(24,679),13)
 for bounds in [Rect2(16,106,650,34),Rect2(765,106,490,34)]:
  var plate:=ColorRect.new()
  plate.position=bounds.position
  plate.size=bounds.size
  plate.color=Color(0.12,0.17,0.18,0.94)
  plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(plate)
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
 super._ready()
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
  add_dialogue("角色 · 认真","总之继续行动吧!")
 else:
  restore_snapshot(loaded)

func _process(delta:float) -> void:
 if not campaign_ready:return
 super._process(delta)
 if save_requested:
  save_requested=false
  var result:Dictionary=store.save_snapshot(snapshot_data())
  status_note="已保存（动作、钥匙、随机状态与暂停均保留）" if result.ok else str(result.error)
 if request_load:
  request_load=false
  var result:Dictionary=store.load_snapshot()
  if result.ok:
   restore_snapshot(result.data)
   status_note="已读档；旧运行回调失效"+("；恢复备份" if result.get("recovered_backup",false) else "")
  else:status_note=str(result.error)

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
 var index:int=str(session.data.key_target).get_slice(":",1).to_int()
 return layout.furniture[index].at if index<layout.furniture.size() else hero_pos

func advance_world(delta:float) -> void:
 world_visual_time+=delta
 var result:Dictionary=rules.tick(delta)
 if result.search_completed:
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
  target_index=-1
  return
 if rules.reaction_left>0:hero_state="scratch"
 elif rules.stun_left>0 or rules.hurt_left>0:hero_state="hit"
 elif hero_state in ["scratch","hit"]:hero_state="idle"
 if rules.body_busy():return
 if session.data.exploration_boundary:return
 if rules.search_active:
  hero_state="search"
  if target_index>=0:
   var id:String=layout.furniture[target_index].id
   var contact:bool=hero_pos.distance_to(layout.furniture[target_index].at)<0.04
   if contact and rules.search_elapsed>=0.18:drawer_open[id]=minf(1,float(drawer_open.get(id,0))+delta*2)
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
  return
 if action_phase in ["opening","resting"]:
  action_left-=delta
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
  if room_id not in ["bedroom","ward"]:
   route_to_door(session.next_room(room_id,"ward"))
  else:
   action_phase="return_bed"
   hero_route=layout.path(hero_pos,layout.BED_STOP)
  return
 choose_public_target(delta)

func choose_public_target(delta:float) -> void:
 # Only public sampled targets and already-completed receipts are inspected.
 # This function never reads the hidden key_target field.
 if target_index<0:
  var closest:float=INF
  for i in range(layout.furniture.size()):
   var id:String=point_id(i)
   if not id in session.data.targets or id in completed:continue
   var distance:float=hero_pos.distance_to(layout.furniture[i].at)
   if distance<closest:closest=distance;target_index=i
  if target_index<0:
   for id in session.data.targets:
    if id in completed:continue
    var room:String=str(id).get_slice(":",0)
    var next:String=session.next_room(room_id,room)
    if not next.is_empty():route_to_door(next);return
   return
 var target:Dictionary=layout.furniture[target_index]
 if hero_route.is_empty() and hero_pos.distance_to(target.at)>0.035:hero_route=layout.path(hero_pos,target.at)
 move_hero(delta)
 if hero_pos.distance_to(target.at)<=0.035:
  hero_facing=(target.rect.get_center()-hero_pos).normalized()
  if rules.begin_search(point_id(target_index)):
   rules.search_duration*=1.25 if session.data.level==2 else 1.0
   hero_state="search"

func route_to_door(id:String) -> void:
 if not id in visible_doors:return
 destination=id
 action_phase="door"
 hero_route=layout.path(hero_pos,door_point(id))

func unlock_hospital() -> void:
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
 # Presentation duration is not an extra mechanical cooldown.
 session.data.cycle+=1
 var key:String=str(session.data.level)
 session.data.attempts[key]=int(session.data.attempts.get(key,1))+1
 rules.actual_attempt=int(session.data.attempts[key])
 if rules.skin_pending_resistance:
  rules.skin_resistance+=1
  rules.skin_pending_resistance=false
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
 status_note="休息实际完成：新尝试；抗性增长提交；冷却不清零"

func apply_cast() -> void:
 var prior:String=action_phase
 super.apply_cast()
 if rules.reaction_left>0 and prior in ["pickup","opening","resting"]:
  action_phase="autonomy"
  status_note="动作中断：未取得物品/开门/休息结果不补发"

func update_ui() -> void:
 if not campaign_ready:return
 scenario_label.text="第%d关 · %s · 实际尝试%d"%[session.data.level,room_title(room_id),rules.actual_attempt]
 status_label.text="N %d   C %d    %s #%d"%[rules.neurons,rules.plexus,profile.name,int(profile.invader_id)]
 debug_label.text="钥匙%s · 视野%.2f×"%["已携带" if has_key() else "未取得",ZOOM_STEPS[zoom_index]]
 state_label.text="%s / %s    搜寻 %d/%d    左键身体：神经菜单 · 空格：暂停"%[action_phase,hero_state,rules.search_attempts,rules.search_limit]
 event_label.text=status_note

func snapshot_data() -> Dictionary:
 var saved_rules:Dictionary={}
 for info in rules.get_property_list():
  if int(info.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved_rules[info.name]=rules.get(info.name)
 return {"schema":1,"profile":profile.duplicate(true),"session":session.data.duplicate(true),"rules":saved_rules.duplicate(true),
  "room_id":room_id,"hero_pos":[hero_pos.x,hero_pos.y],"hero_facing":[hero_facing.x,hero_facing.y],
  "route":Array(hero_route).map(func(p):return [p.x,p.y]),"completed":completed.duplicate(),"target_index":target_index,
  "drawer_open":drawer_open.duplicate(true),"world_visual_time":world_visual_time,"hero_state":hero_state,
  "action_phase":action_phase,"action_left":action_left,"destination":destination,"rng_state":str(rng.state),
  "paused_manual":paused_manual,"closing_left":closing_left,"dialogue":dialogue_queue.duplicate(true),
  "menu_open":menu.visible,"zoom_index":zoom_index,"presentation_id":presentation_id}

func restore_snapshot(data:Dictionary) -> bool:
 if data.get("schema",0)!=1 or not data.has("session") or not data.has("rules"):return false
 var proposed:Dictionary=data.session
 if int(proposed.get("level",0)) not in [1,2] or not Session.ROOM_POINTS.has(str(data.get("room_id",""))):return false
 runtime_generation+=1
 profile=data.profile.duplicate(true)
 invader_id=int(profile.invader_id)
 session.data=data.session.duplicate(true)
 rules=Rules.new()
 var restored_rules:Dictionary=data.rules.duplicate(true)
 for key in restored_rules:
  if key=="facts":rules.facts.assign(restored_rules[key])
  else:rules.set(key,restored_rules[key])
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
 rng.state=str(data.rng_state).to_int()
 paused_manual=bool(data.paused_manual)
 closing_left=float(data.closing_left)
 dialogue_queue.assign(data.dialogue)
 show_dialogue()
 zoom_index=int(data.zoom_index)
 camera.zoom=Vector2.ONE*BASE_ZOOM*ZOOM_STEPS[zoom_index]
 presentation_id=str(data.get("presentation_id","a"))
 view.catalog.select_set(presentation_id)
 if data.menu_open:menu.open_menu(rules.neurons,rules.neurons>=1 and rules.world_time>=rules.cooldown_until,false)
 else:menu.close_menu()
 return true
