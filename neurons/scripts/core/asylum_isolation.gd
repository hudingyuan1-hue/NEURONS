extends RefCounted
## A signed isolation order is distinct from ordinary delivery. The parent's
## gameplay clock pauses all stages; sprites/door frames do not settle them.
const Map=preload("res://scripts/core/asylum_map.gd")
const STAFF="isolation_orderly"
const UPPER=["stairs","corridor","activity","group_therapy","quiet","bathroom","double_ward","workshop"]
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_isolation.json"))

func state() -> Dictionary:
 if not owner.data.has("isolation_state"):
  owner.data.isolation_state={"phase":"idle","elapsed":0.0,"order":{},"target":"","last_room":"","last_pos":[],"handled":{},"hero_attempted":false,"hero_held":false,"door_closed":false,"door_progress":0.0,"open_from":0.0,"closed_elapsed":0.0,"evaded":false,"grab_invalidated":false,"was_closed":false,"outcome":"","waiting":""}
 if not owner.data.has("staff_targets"):owner.data.staff_targets={}
 return owner.data.isolation_state

func timing(key:String) -> float:return float(config.presentation_timing[key])
func parameter(key:String) -> float:return float(config.parameters[key])
func xy(at:Vector2) -> Array:return [at.x,at.y]
func point(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func observation_point() -> Vector2:return point(config.parameters.observation_pos)
func stage(phase:String) -> void:state().phase=phase;state().elapsed=0.0;state().waiting=""
func order_id() -> String:return str(state().order.get("id",""))
func hero_target() -> bool:return str(state().target)=="hero"

func target_present() -> bool:
 if hero_target():return owner.app.rules.hp>0 and not owner.app.rules.absent
 return owner.present(str(state().target))
func target_room() -> String:return owner.app.room_id if hero_target() else str(owner.actor(str(state().target)).get("room",""))
func target_position() -> Vector2:return owner.app.hero_pos if hero_target() else owner.position(str(state().target))
func sees_target(distance:float=-1) -> bool:
 if not owner.present(STAFF) or not target_present():return false
 var room:String=str(owner.actor(STAFF).room)
 if room!=target_room():return false
 if distance<0:distance=parameter("notice_distance")
 return owner.position(STAFF).distance_to(target_position())<=distance and owner.layout_for(room).clear_segment(owner.position(STAFF),target_position())

func local_say(key:String) -> void:
 if not hero_target() or not owner.near(STAFF,2.4) or owner.app.rules.hp<=0:return
 if not owner.claim("isolation_line:"+key,"asylum_dialogue",{"order":order_id()}):return
 for line in config.dialogue.get(key,[]):owner.app.add_dialogue(str(line.speaker),str(line.text))

func tick(delta:float) -> void:
 if owner.data.is_empty() or not is_finite(delta) or delta<=0:return
 var value:Dictionary=state()
 if owner.app.rules.hp<=0:
  abort("death");advance_open(delta);return
 if not owner.enabled or owner.app.session.data.level!=3:
  abort("level_left");advance_open(delta);return
 if not owner.app.dialogue_queue.is_empty():return
 if value.phase=="opening":advance_open(delta);return
 if value.phase=="idle":find_order();return
 if not owner.present(STAFF):abort("staff_left");advance_open(delta);return
 if not target_present() and value.phase not in ["fetch","receive","retreat"]:abort("target_absent");return
 if value.phase in ["clearing","closing","observing"] and target_room()!="quiet":abort("target_left");return
 match str(value.phase):
  "retreat":
   if str(owner.actor(STAFF).room)=="corridor" and owner.move(STAFF,point(config.parameters.staff_side_pos),delta):stage("idle")
  "fetch":advance_fetch(delta)
  "receive":advance_receive(delta)
  "locate":advance_locate(delta)
  "check":advance_check(delta)
  "reach":advance_reach(delta)
  "drag":advance_drag(delta)
  "clearing":advance_clearing(delta)
  "closing":advance_close(delta)
  "observing":advance_observation(delta)

func find_order() -> void:
 if owner.ward_events==null or not owner.present(STAFF):return
 var value:Dictionary=state()
 if owner.data.staff_targets.has(STAFF):return
 if owner.data.body.get("actor","")==STAFF:return
 for report in owner.ward_events.pending_isolation_orders():
  var id:String=str(report.get("id",""));var target:String=str(report.get("target",""))
  if id.is_empty() or target.is_empty() or value.handled.has(id):continue
  if int(report.get("attempt",-1))!=owner.app.rules.actual_attempt or not report.get("isolation_signed",false) or str(report.get("isolation_order","")).is_empty():continue
  if target=="hero" and value.hero_attempted:value.handled[id]="hero_attempt_already_used";continue
  value.order=report.duplicate(true);value.target=target
  value.last_room=str(report.get("last_room","quiet"));value.last_pos=report.get("last_pos",xy(observation_point())).duplicate()
  if value.last_pos.size()!=2:value.last_pos=xy(observation_point())
  value.outcome="";value.was_closed=false;value.evaded=false;value.grab_invalidated=false
  owner.data.staff_targets[STAFF]="isolation_order_fetch"
  stage("fetch");return

func advance_fetch(delta:float) -> void:
 var value:Dictionary=state();var at:Array=value.order.get("station_pos",[])
 if at.size()!=2:abort("order_has_no_physical_location");return
 if not owner.travel(STAFF,"corridor",delta):return
 var station:Vector2=point(at)
 if not owner.move(STAFF,station,delta):return
 if not owner.layout_for("corridor").clear_segment(owner.position(STAFF),station):return
 stage("receive")

func advance_receive(delta:float) -> void:
 var value:Dictionary=state();var station:Vector2=point(value.order.station_pos)
 if str(owner.actor(STAFF).room)!="corridor" or owner.position(STAFF).distance_to(station)>0.5 or not owner.layout_for("corridor").clear_segment(owner.position(STAFF),station):stage("fetch");return
 value.elapsed+=delta
 if float(value.elapsed)<timing("order_receive"):return
 if not owner.ward_events.take_isolation_order(order_id()):abort("order_unavailable");return
 owner.data.staff_targets[STAFF]=str(value.target)
 owner.claim("isolation_received:"+order_id(),"asylum_isolation_order_verified",{"report":order_id(),"order":str(value.order.isolation_order),"target":str(value.target),"issuer":"head_nurse"})
 stage("locate")

func advance_locate(delta:float) -> void:
 var value:Dictionary=state();var room:String=str(value.last_room)
 if not room in UPPER:abort("last_seen_outside_ward");return
 if not owner.travel(STAFF,room,delta):return
 if not sees_target():
  if owner.move(STAFF,point(value.last_pos),delta):abort("not_found_at_last_seen")
  return
 value.last_room=target_room();value.last_pos=xy(target_position())
 if not room_ready(delta):return
 if not sees_target(parameter("contact_distance")):owner.move(STAFF,target_position(),delta);return
 stage("check")

func advance_check(delta:float) -> void:
 var value:Dictionary=state()
 if not sees_target():stage("locate");return
 value.last_room=target_room();value.last_pos=xy(target_position())
 if not room_ready(delta):return
 if not sees_target(parameter("grab_distance")):owner.move(STAFF,target_position(),delta);value.elapsed=0.0;return
 value.elapsed+=delta
 if float(value.elapsed)<timing("target_check"):return
 if hero_target() and not owner.can_begin_grip():return
 if npc_held_elsewhere():value.waiting="目标正由另一人员控制";return
 if hero_target():
  if value.hero_attempted:abort("hero_attempt_already_used");return
  value.hero_attempted=true
 owner.claim("isolation_attempt:"+order_id(),"asylum_isolation_attempt_started",{"target":str(value.target),"report":order_id()})
 value.evaded=false;value.grab_invalidated=false
 stage("reach");local_say("NOTICE")

func advance_reach(delta:float) -> void:
 var value:Dictionary=state()
 if hero_target() and (not str(owner.data.holder).is_empty() or owner.app.rules.body_busy()):value.grab_invalidated=true
 if npc_held_elsewhere():value.grab_invalidated=true
 value.elapsed+=delta
 if float(value.elapsed)<timing("grab_prepare"):return
 if value.evaded or value.grab_invalidated or not sees_target(parameter("grab_distance")):abort("grab_missed");return
 if not room_ready(delta):abort("room_not_clear_at_contact");return
 if hero_target():
  if not owner.can_begin_grip():abort("grip_unavailable");return
  if owner.records!=null:owner.records.cancel_read("isolation_grip")
  if owner.app.has_method("cancel_asylum_read"):owner.app.cancel_asylum_read()
  if not owner.data.body.is_empty():owner.clear_body()
  owner.data.holder=STAFF;owner.app.rules.gripped=true;value.hero_held=true
  owner.set_body("ward_isolation_drag",STAFF)
 else:owner.actor(str(value.target)).phase="isolation_held"
 owner.claim("isolation_grip:"+order_id(),"asylum_isolation_grip",{"target":str(value.target),"hp_damage":0,"sp_damage":0})
 stage("drag")

func npc_held_elsewhere() -> bool:
 if hero_target():return false
 var target:String=str(state().target)
 for staff in owner.data.get("staff_targets",{}):
  if str(staff)!=STAFF and str(owner.data.staff_targets[staff])==target:return true
 if owner.ward_events!=null:
  var job:Dictionary=owner.ward_events.state().get("ordinary_job",{})
  if job.get("holding",false) and str(job.get("target",""))==target:return true
 return false

func room_has_space() -> bool:
 var layout=owner.layout_for("quiet");var at:Vector2=observation_point();var door:Vector2=Map.doorway("quiet","corridor")
 return layout.walkable(at) and layout.walkable(door) and not layout.path(door,at).is_empty() and not layout.path(at,door).is_empty()

func non_target_inside() -> bool:
 if not hero_target() and owner.app.room_id=="quiet":return true
 for id in owner.data.actors:
  if str(id) in [STAFF,str(state().target)]:continue
  if owner.present(str(id)) and str(owner.actor(str(id)).room)=="quiet":return true
 return false

func room_ready(delta:float) -> bool:
 var value:Dictionary=state()
 if not room_has_space():value.waiting="观察位或门口空间不足";return false
 var waiting:bool=false
 if not hero_target() and owner.app.room_id=="quiet":waiting=true;value.waiting="旁观角色需自行离开安静室"
 for id in owner.data.actors:
  if str(id) in [STAFF,str(value.target)] or not owner.present(str(id)) or str(owner.actor(str(id)).room)!="quiet":continue
  waiting=true
  var a:Dictionary=owner.actor(str(id))
  if owner.data.get("staff_targets",{}).has(str(id)) or str(a.phase) in ["guard_held","isolation_held"]:continue
  if str(id)=="transport_patient":
   # This person is still lying on the actual moving bed. Exit as the same
   # porter/bed/patient pair, never turn a supine patient into a walking prop.
   if owner.ward_events!=null and owner.present("porter") and str(owner.actor("porter").room)=="quiet" and not owner.data.staff_targets.has("porter"):
    owner.ward_events.npc_pair_travel("porter","transport_patient","corridor",delta)
   continue
  if str(id)=="porter" and str(value.target)!="transport_patient" and owner.present("transport_patient") and str(owner.actor("transport_patient").room)=="quiet":continue
  # A bystander can leave by the actual existing door; the protagonist is
  # never commanded or teleported out to make an NPC isolation possible.
  var door:Vector2=Map.doorway("quiet","corridor")
  if owner.move(str(id),door,delta):
   a.room="corridor";a.pos=xy(Map.doorway("corridor","quiet"));a.route=[]
 if waiting:
  if value.waiting.is_empty():value.waiting="等待非目标人员沿门口退出"
  return false
 value.waiting="";return true

func pair_move(to:Vector2,delta:float) -> bool:
 var room:String=str(owner.actor(STAFF).room)
 if target_room()!=room:return false
 if owner.position(STAFF).distance_to(target_position())<=0.6:owner.move(STAFF,to,delta)
 var leader_done:bool=owner.position(STAFF).distance_to(to)<0.035
 var follow:Vector2=to if leader_done else owner.position(STAFF)
 if hero_target():
  var layout=owner.layout_for(room);var route:PackedVector2Array=layout.path(owner.app.hero_pos,follow)
  if route.is_empty() and owner.app.hero_pos.distance_to(follow)>0.05:abort("no_follower_path");return false
  owner.app.hero_pos=layout.move_path(owner.app.hero_pos,route,parameter("walk_speed")*delta).position;owner.app.hero_state="hit"
 else:owner.move(str(state().target),follow,delta)
 return leader_done and target_position().distance_to(to)<0.05

func pair_travel(to:String,delta:float) -> bool:
 var room:String=str(owner.actor(STAFF).room)
 if room==to:return true
 var next:String=Map.next_room(room,to)
 if next.is_empty() or not next in UPPER:return false
 var door:Vector2=Map.doorway(room,next)
 if owner.layout_for(room).path(owner.position(STAFF),door).is_empty() and owner.position(STAFF).distance_to(door)>0.05:
  if hero_target():abort("no_drag_path")
  return false
 if not pair_move(door,delta):return false
 var entry:Vector2=Map.doorway(next,room)
 owner.actor(STAFF).room=next;owner.actor(STAFF).pos=xy(entry);owner.actor(STAFF).route=[]
 if hero_target():
  var body:Dictionary=owner.data.body.duplicate(true)
  owner.app.enter_room(next);owner.app.hero_pos=entry;owner.data.body=body;owner.data.holder=STAFF;owner.app.rules.gripped=true
 else:
  owner.actor(str(state().target)).room=next;owner.actor(str(state().target)).pos=xy(entry);owner.actor(str(state().target)).route=[]
 return next==to

func advance_drag(delta:float) -> void:
 var value:Dictionary=state()
 if target_room()!=str(owner.actor(STAFF).room):abort("pair_room_mismatch");return
 value.elapsed+=delta
 if hero_target() and float(value.elapsed)>=float(config.rules.hero_max_drag):abort("drag_timeout_undelivered");return
 if not pair_travel("quiet",delta):return
 if value.phase!="drag":return
 if not pair_move(observation_point(),delta):return
 release_grip()
 if not hero_target():owner.actor(str(value.target)).phase="isolation_waiting"
 owner.claim("isolation_delivered:"+order_id(),"asylum_isolation_delivered",{"target":str(value.target),"room":"quiet","pos":xy(target_position()),"isolated":false})
 stage("clearing")

func move_staff_to_outer_door(delta:float) -> bool:
 var room:String=str(owner.actor(STAFF).room)
 if room=="quiet":
  if not owner.move(STAFF,Map.doorway("quiet","corridor"),delta):return false
  owner.actor(STAFF).room="corridor";owner.actor(STAFF).pos=xy(Map.doorway("corridor","quiet"));owner.actor(STAFF).route=[]
  return true
 if room!="corridor":return false
 return owner.move(STAFF,Map.doorway("corridor","quiet"),delta)

func staff_observing_at_door() -> bool:
 if not owner.present(STAFF) or str(owner.actor(STAFF).room)!="corridor":return false
 var door:Vector2=Map.doorway("corridor","quiet")
 return owner.position(STAFF).distance_to(door)<=parameter("door_observe_distance") and owner.layout_for("corridor").clear_segment(owner.position(STAFF),door)

func advance_clearing(delta:float) -> void:
 if not room_ready(delta):return
 if not move_staff_to_outer_door(delta):return
 if non_target_inside():return
 stage("closing")

func advance_close(delta:float) -> void:
 var value:Dictionary=state()
 if not staff_observing_at_door():abort("staff_left_door");return
 if not room_has_space():abort("closing_space_blocked");return
 if non_target_inside():value.door_progress=0.0;stage("clearing");return
 value.elapsed+=delta
 var duration:float=minf(timing("close"),float(config.rules.close_limit))
 value.door_progress=clampf(float(value.elapsed)/duration,0,1)
 if float(value.elapsed)+0.000001<duration:return
 value.door_closed=true;value.door_progress=1.0;value.was_closed=true;value.closed_elapsed=0.0
 owner.claim("isolation_door_closed:"+order_id(),"asylum_isolation_started",{"target":str(value.target),"report":order_id(),"room":"quiet","hp_damage":0,"sp_damage":0})
 owner.record("asylum_isolation:"+order_id(),"隔离护工实际接收护士长签联、抓住并送达对应对象，门实际关闭后才记为本次已隔离。")
 stage("observing")
 # The observer is genuinely outside the quiet-room door. The hero can hear
 # this local exchange across that one doorway, never from another room.
 if hero_target() and owner.app.room_id=="quiet":
  if owner.claim("isolation_line:CLOSED","asylum_dialogue",{"order":order_id()}):
   for line in config.dialogue.CLOSED:owner.app.add_dialogue(str(line.speaker),str(line.text))

func advance_observation(delta:float) -> void:
 var value:Dictionary=state()
 if not staff_observing_at_door():abort("staff_left");return
 if non_target_inside():abort("bystander_entered");return
 value.closed_elapsed+=delta
 if float(value.closed_elapsed)+0.000001>=float(config.rules.closed_observation):begin_open("completed")

func release_grip() -> void:
 if str(owner.data.get("holder",""))==STAFF:
  owner.data.holder="";owner.app.rules.gripped=false;owner.data.regrab_elapsed=0.0
  if owner.data.body.get("kind","")=="ward_isolation_drag":owner.clear_body()
 if owner.data.has("isolation_state"):owner.data.isolation_state.hero_held=false

func begin_open(outcome:String) -> void:
 var value:Dictionary=state()
 release_grip();value.outcome=outcome
 if value.phase=="opening":return
 value.open_from=float(value.door_progress)
 stage("opening")

func abort(reason:String="cancelled") -> void:
 if owner.data.is_empty() or not owner.data.has("isolation_state"):return
 var value:Dictionary=state()
 if value.phase=="idle":release_grip();return
 if value.phase=="opening":release_grip();return
 release_grip()
 if value.door_closed or float(value.door_progress)>0:begin_open(reason)
 else:finish(reason)

func advance_open(delta:float) -> void:
 var value:Dictionary=state()
 if value.phase!="opening":return
 value.elapsed+=delta
 var duration:float=minf(timing("open"),float(config.rules.open_limit))
 value.door_progress=float(value.get("open_from",1.0))*maxf(0.0,1.0-float(value.elapsed)/duration)
 if float(value.elapsed)+0.000001<duration:return
 value.door_closed=false;value.door_progress=0.0
 var outcome:String=str(value.outcome)
 owner.claim("isolation_door_opened:"+order_id(),"asylum_isolation_door_opened",{"target":str(value.target),"outcome":outcome})
 if hero_target() and owner.app.rules.hp>0 and owner.app.room_id=="quiet" and bool(value.was_closed):
  if owner.claim("isolation_line:OPENED","asylum_dialogue",{"order":order_id()}):
   for line in config.dialogue.OPENED:owner.app.add_dialogue(str(line.speaker),str(line.text))
 finish(outcome,true)

func finish(outcome:String,retreat:bool=false) -> void:
 var value:Dictionary=state();var target:String=str(value.target);var id:String=order_id()
 release_grip();value.door_closed=false;value.door_progress=0.0
 if not hero_target() and owner.present(target) and str(owner.actor(target).phase) in ["isolation_held","isolation_waiting"]:owner.actor(target).phase="idle"
 if not id.is_empty():
  value.handled[id]=outcome
  owner.claim("isolation_end:"+id,"asylum_isolation_ended",{"target":target,"outcome":outcome,"was_closed":bool(value.was_closed),"pos":xy(target_position()) if target_present() else []})
 owner.data.staff_targets.erase(STAFF)
 value.outcome=outcome;value.target="";value.order={};value.last_room="";value.last_pos=[];value.hero_held=false
 stage("retreat" if retreat and owner.present(STAFF) and str(owner.actor(STAFF).room)=="corridor" else "idle")

func can_exit(room:String,to:String) -> bool:
 if owner.data.is_empty() or not owner.data.has("isolation_state"):return true
 var value:Dictionary=state()
 if (room=="quiet" and to=="corridor") or (room=="corridor" and to=="quiet"):
  if value.door_closed:return false
  if room=="corridor" and value.phase in ["closing","opening"]:return false
 return true

func blocks_hero() -> bool:
 return not owner.data.is_empty() and str(owner.data.get("holder",""))==STAFF

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false) or owner.data.is_empty():return
 var value:Dictionary=state()
 if hero_target() and value.phase=="reach" and str(result.get("id",""))=="WITHDRAW":value.evaded=true
 # Positive emotion changes SP through the normal skill bus. It cannot open
 # a door, remove an established grip or restart the observation timer.

func kick_contact() -> void:
 if owner.data.is_empty() or not owner.near(STAFF,1.0):return
 var offset:Vector2=owner.position(STAFF)-owner.app.hero_pos
 if owner.app.rules.kick_contact("asylum_"+STAFF,offset.length(),offset.normalized().dot(owner.app.hero_facing)>0.35,owner.app.layout.clear_segment(owner.app.hero_pos,owner.position(STAFF))):
  owner.claim("kick:"+STAFF,"asylum_staff_kicked",{"target":STAFF,"isolation_cancelled":false})

func markers() -> Array:
 if owner.data.is_empty() or not owner.data.has("isolation_state"):return []
 var value:Dictionary=state()
 if value.phase=="idle":return []
 var label:String="隔离处置 · "+str(value.phase)
 if not str(value.waiting).is_empty():label=str(value.waiting)
 if value.phase=="observing":label="隔离门已关 · 剩余 %.1f 秒"%maxf(0,float(config.rules.closed_observation)-float(value.closed_elapsed))
 return [{"id":"asylum_isolation_door","room":"quiet","pos":xy(Map.doorway("quiet","corridor")),"kind":"isolation_door","label":label,"closed":bool(value.door_closed),"progress":float(value.door_progress),"target":str(value.target)},
  {"id":"asylum_isolation_outer_door","room":"corridor","pos":xy(Map.doorway("corridor","quiet")),"kind":"isolation_door","label":label,"closed":bool(value.door_closed),"progress":float(value.door_progress),"target":str(value.target)}]
