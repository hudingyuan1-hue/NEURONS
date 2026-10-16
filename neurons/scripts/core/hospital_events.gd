extends RefCounted
## S3 hospital events. Primitive JSON state; no asset frame decides a receipt.
const Layout=preload("res://scripts/world/room_layout.gd")
const InstitutionLayout=preload("res://scripts/world/institution_layout.gd")
const Session=preload("res://scripts/core/campaign_session.gd")
var app
var config:Dictionary={}
var data:Dictionary={}
var enabled:bool=true
var records
var observations
var _source_layouts:Dictionary={}

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/hospital.json"))

func start_attempt() -> void:
 var relics:Dictionary=preserved_relic_checkpoint()
 _source_layouts.clear()
 data={"actors":{},"groups":{},"room_left":{},"batches":{},"clock":0.0,"hospital_attempt":app.rules.actual_attempt,"receipts":{},"body":{},"holder":"","visit":"","prescription_visit":"","bandage":0.0,"healed":false,"registered":false,"exam_done":false,"sample":false,"prescribed":false,"dispensed":false,"refused":false,"swallowed":false,"medicine_stop":0.0,"bag":"ward","bag_order":false,"transport":{},"known_pages":[],"suspended_body":{}}
 data.geometry_version=int(app.session.data.get("institution_geometry_version",1))
 for id in config.rooms:
  var room:String=str(config.rooms[id])
  var idle:Vector2=source_portal(room,"ward" if room=="lobby" else "lobby").landing if source_geometry_version()>=2 else Vector2(4.4,0.35)
  data.actors[id]={"room":room,"pos":xy(idle),"route":[],"phase":"absent","left":0.0,"elapsed":0.0}
 for key in config.groups:data.groups[key]={"checks":0,"pending":false,"drawn":false}
 data.regrab_elapsed=0.8
 data.nurse_checked=false
 if not relics.is_empty():
  # S4:T27R3 retains long-term originals. Only this already started physical
  # trip survives; clinical bodies, damage, medicine and ordinary rolls above
  # still reset. Never clone an actor that had not actually arrived.
  for key in relics.fields:data[key]=relics.fields[key].duplicate(true) if relics.fields[key] is Dictionary or relics.fields[key] is Array else relics.fields[key]
  for id in relics.actors:data.actors[id]=relics.actors[id].duplicate(true)
  data.receipts.merge(relics.receipts)
  data.groups.lobby.drawn=true;data.groups.lobby.pending=false

func preserved_relic_checkpoint() -> Dictionary:
 if data.is_empty():return {}
 var props:Dictionary=data.get("transport_relics",{});var delivery:Dictionary=data.get("relic_delivery",{})
 var retained:bool=false
 for id in ["family_photo","patient_shoe"]:
  var physical:Dictionary=props.get(id,{})
  var holder:String=str(app.rules.owners.get(id,""))
  if not physical.is_empty() and physical.get("pos",[]).size()==2 and holder in [str(physical.get("support","")),"hero","hospital_relic_container"]:retained=true
  if not delivery.is_empty() and id in delivery.get("items",[]) and holder==str(delivery.get("bag_id","")) and str(data.get("receipts",{}).get(str(delivery.get("packed_receipts",{}).get(id,"")),""))=="hospital_relic_packed":retained=true
 if not retained:return {}
 var source:int=int(data.get("relic_context",{}).get("source_attempt",delivery.get("source_attempt",0)))
 if source<=0:
  for item in props.values():
   source=int(item.get("source_attempt",0))
   if source>0:break
 if source<=0:return {} # No old gone/support string may manufacture history.
 var result:Dictionary={"fields":{"relic_context":{"source_attempt":source}},"actors":{},"receipts":{}}
 for key in ["transport_relics","relic_delivery","relic_packing","transport","wheelchair_gone","wheelchair_order"]:
  if data.has(key):result.fields[key]=data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key]
 for id in ["guide","wheelchair","porter"]:
  var prior:Dictionary=data.get("actors",{}).get(id,{})
  if not prior.is_empty() and str(prior.get("phase","absent"))!="absent":result.actors[id]=prior.duplicate(true)
 for suffix in ["patient_order","patient_relics_fell","patient_transport","witness_transport","line:TRANSFER","line:FRAME","line:TRANSFER_DONE","relic_packed:family_photo","relic_packed:patient_shoe"]:
  var key:String="hospital:%d:%s"%[source,suffix]
  if data.get("receipts",{}).has(key):result.receipts[key]=data.receipts[key]
 return result

func restore(saved:Dictionary) -> void:
 _source_layouts.clear()
 if saved.is_empty():start_attempt()
 else:
  data=saved.duplicate(true)
  if app.rules.owners.get("hospital_cup","")=="empty_cup":
   app.rules.owners.hospital_cup="hero";data.cup_full=false

func actor(id:String) -> Dictionary:
 return data.actors[id]

func position(id:String) -> Vector2:
 var p:Array=actor(id).pos
 return Vector2(float(p[0]),float(p[1]))

func present(id:String) -> bool:
 return enabled and not data.is_empty() and actor(id).phase not in ["absent","gone"]

func layout_for(room:String):
 if int(app.session.data.level)!=2:return source_layout(room)
 if room==app.room_id:return app.layout
 return app.layout_for_room(room)

func source_geometry_version() -> int:return int(data.get("geometry_version",1))

func source_layout(room:String):
 # Explicit L2 furniture/navigation. A later chapter's room with the same
 # identifier, current protagonist or movable blockers is another scene.
 var cache_key:String="%d:%s"%[source_geometry_version(),room]
 if _source_layouts.has(cache_key):return _source_layouts[cache_key]
 if source_geometry_version()>=2 and room in ["ward","lobby","clinic","pharmacy","office"]:
  var institution=InstitutionLayout.new(room,2)
  _source_layouts[cache_key]=institution
  return institution
 var floor_layout=Layout.new()
 if room not in ["bedroom","ward"]:
  floor_layout.furniture.clear()
  for i in range(Session.ROOM_POINTS.get(room,[]).size()):
   var side:int=i%2;var row:int=i/2
   var p:=Vector2(0.25 if side==0 else 4.85,0.65+row*0.51)
   var at:=p+Vector2(0.75 if side==0 else -0.3,0.2)
   floor_layout.furniture.append({"id":"%s:%d"%[room,i],"name":Session.ROOM_POINTS[room][i],"rect":Rect2(p,Vector2(0.5,0.35)),"at":at,"height":25.0,"kind":"drawer"})
  floor_layout._init()
 _source_layouts[cache_key]=floor_layout
 return floor_layout

func source_door(room:String,id:String) -> Vector2:
 return source_portal(room,id).at

func source_portal(room:String,id:String) -> Dictionary:
 # The hospital's saved version is provenance. The current asylum room may
 # have the same name but must not move an unfinished source trip into it.
 if source_geometry_version()>=2 and room in ["ward","lobby","clinic","pharmacy","office"]:return source_layout(room).portal(id)
 var at:Vector2=legacy_source_door(room,id)
 return {"at":at,"threshold":at,"landing":at,"inward":Vector2.DOWN}

func source_anchor(room:String,name:String,legacy:Vector2) -> Vector2:
 if source_geometry_version()>=2:return source_layout(room).get_anchor(name)
 return legacy

func source_tangent(room:String,toward:String) -> Vector2:
 var inward:Vector2=source_portal(room,toward).inward
 return Vector2(inward.y,-inward.x)

func legacy_source_door(room:String,id:String) -> Vector2:
 if room in ["bedroom","ward"]:return Layout.DOOR
 var doors:Array=Session.GRAPH.get(room,[]).duplicate()
 if room=="lobby":doors.append("stairs")
 var index:int=doors.find(id)
 return Vector2(1.25+index*0.78,0.24) if index>=0 else Vector2.INF

func source_next_room(from:String,to:String) -> String:
 if from==to:return from
 var pending:Array=[from];var visited:Dictionary={from:""}
 while not pending.is_empty():
  var current:String=pending.pop_front()
  for neighbor in Session.GRAPH.get(current,[]):
   if visited.has(neighbor):continue
   visited[neighbor]=current
   if neighbor==to:
    var step:String=to
    while visited[step]!=from:step=visited[step]
    return step
   pending.append(neighbor)
 return ""

func source_scene_visible(room:String) -> bool:return int(app.session.data.level)==2 and app.room_id==room

func xy(p:Vector2) -> Array:return [p.x,p.y]

func near(id:String,distance:float=-1) -> bool:
 if int(app.session.data.level)!=2 or not present(id) or actor(id).room!=app.room_id:return false
 return position(id).distance_to(app.hero_pos)<=(float(config.test_parameters.notice_distance) if distance<0 else distance) and app.layout.clear_segment(position(id),app.hero_pos)

func medical_listener() -> bool:
 for id in ["nurse","guide","doctor","assistant","pharmacist"]:
  if near(id,2.0):return true
 return false

func move(id:String,to:Vector2,delta:float) -> bool:
 var a:Dictionary=actor(id)
 var floor_layout=layout_for(str(a.room))
 if position(id).distance_to(to)<0.035:return true
 var path:PackedVector2Array=PackedVector2Array()
 for p in a.route:path.append(Vector2(float(p[0]),float(p[1])))
 if path.is_empty() or path[-1].distance_to(to)>0.08:path=floor_layout.path(position(id),to)
 var moved:Dictionary=floor_layout.move_path(position(id),path,float(config.test_parameters.walk_speed)*delta)
 a.pos=xy(moved.position);a.route=Array(moved.route).map(func(p):return xy(p))
 return position(id).distance_to(to)<0.035

func travel(id:String,room:String,delta:float) -> bool:
 var a:Dictionary=actor(id)
 if a.room==room:return true
 var step:String=source_next_room(str(a.room),room)
 if step.is_empty():return false
 var doorway:Vector2=source_portal(str(a.room),step).threshold
 if move(id,doorway,delta):
  var previous:String=str(a.room)
  a.room=step;a.pos=xy(source_portal(step,previous).landing);a.route=[]
 return a.room==room

func claim(id:String,kind:String,details:Dictionary={},receipt_attempt:int=0) -> bool:
 var key:String="hospital:%d:%s"%[receipt_attempt if receipt_attempt>0 else app.rules.actual_attempt,id]
 if data.receipts.has(key) or app.rules.hp<=0:return false
 data.receipts[key]=kind
 var record_details:Dictionary=details.duplicate(true)
 if receipt_attempt>0:
  record_details.source_attempt=receipt_attempt;record_details.occurrence_attempt=app.rules.actual_attempt
  record_details.source_level=2;record_details.occurrence_level=int(app.session.data.level)
 app.rules._record(kind,key,record_details)
 return true

func say(key:String,receipt_attempt:int=0) -> void:
 if not claim("line:"+key,"hospital_dialogue",{},receipt_attempt):return
 for line in config.dialogue.get(key,[]):app.add_dialogue(str(line.speaker),str(line.text))

func say_local(key:String,participants:Array) -> bool:
 # A remote event may finish without giving the protagonist its conversation.
 # Do not claim an unheard line, or replay it later after its contact node.
 for id in participants:
  if not near(str(id),2.0):return false
 var queued:int=app.dialogue_queue.size()
 say(key)
 return app.dialogue_queue.size()>queued

func observe(id:String,text:String) -> void:
 if not id in app.rules.known:app.rules.known.append(id)
 app.rules.observe("物品",id,text,"亲历事实","医院实际观察")

func record(id:String,text:String) -> void:
 for entry in app.rules.institutional_records:
  if entry.get("id","")==id:return
 app.rules.institutional_records.append({"id":id,"text":text,"source":"医院记录","attempt":app.rules.actual_attempt})

func damage(id:String,hp:int,sp:int) -> bool:
 if not claim(id,"hospital_damage",{"hp_damage":hp,"sp_damage":sp}):return false
 app.rules.hp=maxi(0,app.rules.hp-hp);app.rules.change_sp(-sp)
 if hp>0:app.rules.vitality_lost.emit()
 app.rules.cancel_search();app.family.data.eating.clear()
 if observations!=null:app.cancel_hospital_observation()
 if not app.rules.pending_neural.is_empty():
  app.rules.settled[app.rules.pending_neural.event_id]="interrupted"
  app.rules.pending_neural.clear();app.rules.pending_skin.clear()
 if app.rules.hp>0 and app.rules.hurt_left<=0:app.rules.hurt_left=0.25
 return true

func current_visit() -> String:
 if str(data.visit).is_empty():data.visit="H2-%d-%d"%[app.invader_id,app.rules.actual_attempt]
 return str(data.visit)

func set_body(kind:String,id:String) -> void:
 if data.body.is_empty():
  app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
  app.action_phase="autonomy";app.hero_state="give"
  data.body={"kind":kind,"actor":id,"elapsed":0.0,"delay":0.0}

func clear_body() -> void:
 data.body={}
 if str(data.holder).is_empty():app.rules.gripped=false

func can_begin_grip() -> bool:
 return str(data.holder).is_empty() and not app.rules.body_busy() and float(data.get("regrab_elapsed",0))>=0.8

func blocks_hero() -> bool:
 return enabled and not data.is_empty() and (not data.body.is_empty() or not str(data.holder).is_empty() or float(data.medicine_stop)>0 or (observations!=null and observations.blocks_hero()))

func eligible() -> bool:
 return not app.has_key() and not app.rules.search_active and app.action_phase=="autonomy" and not app.rules.body_busy() and not app.rules.gripped and app.rules.control_left<=0 and data.body.is_empty()

func on_enter(from:String,room:String) -> void:
 if observations!=null and from!=room:observations.cancel();data.erase("observation_route")
 if not enabled or app.session.data.level!=2:return
 if data.is_empty():start_attempt()
 if not from.is_empty():data.room_left[from]=float(data.clock)
 for group in config.groups:
  var home_room:String=str(config.rooms[config.groups[group][0]])
  if home_room!=room:continue
  var state:Dictionary=data.groups[group]
  if state.drawn or int(state.checks)>=3:continue
  if int(state.checks)>0 and (not data.room_left.has(room) or float(data.clock)-float(data.room_left[room])<float(config.timing.return_check)):continue
  var chance:float=(0.35 if group=="patient" else 0.5)+0.05*mini(app.rules.actual_attempt-1,4)
  if int(state.checks)>0:chance*=0.5
  state.checks+=1
  if app.rng.randf()<chance:state.drawn=true;state.pending=true

func spawn_pending() -> void:
 for group in config.groups:
  var state:Dictionary=data.groups[group]
  if not state.pending:continue
  var room:String=str(config.rooms[config.groups[group][0]])
  if room!=app.room_id or float(data.clock)-float(data.batches.get(room,-100))<float(config.timing.spawn_batch):continue
  var incoming:String="ward" if room=="lobby" else "lobby"
  var entry:Vector2=source_portal(room,incoming).landing
  var tangent:Vector2=source_tangent(room,incoming)
  var floor_layout=layout_for(room)
  if not floor_layout.walkable(entry) or app.hero_pos.distance_to(entry)<0.7:continue
  var occupied:bool=false
  for id in data.actors:
   if present(id) and actor(id).room==room and position(id).distance_to(entry)<0.5:occupied=true
  if occupied:continue
  # Keep one batch at the actual doorway. Choose only reachable 0.5m-spaced
  # positions; if the batch cannot fit, retain the pending draw and wait.
  var slots:Array[Vector2]=[]
  for offset in [0.0,-0.5,0.5,-1.0,1.0]:
   var at:Vector2=entry+tangent*float(offset)
   if not floor_layout.walkable(at) or app.hero_pos.distance_to(at)<0.5:continue
   if at.distance_to(entry)>0.001 and floor_layout.path(entry,at).is_empty():continue
   var free:bool=true
   for id in data.actors:
    if present(id) and actor(id).room==room and position(id).distance_to(at)<0.5:free=false
   if not free:continue
   slots.append(at)
   if slots.size()==config.groups[group].size():break
  if slots.size()<config.groups[group].size():continue
  for index in range(config.groups[group].size()):
   var id:String=config.groups[group][index];var a:Dictionary=actor(id)
   a.phase="idle";a.room=config.rooms[id];a.pos=xy(slots[index]);a.route=[]
   if id=="wheelchair" and str(app.rules.owners.get("family_photo","")) not in ["hero","hospital_relic_container"]:app.rules.owners.family_photo="wheelchair"
  state.pending=false;data.batches[room]=data.clock

func tick(delta:float) -> void:
 if not enabled or app.rules.hp<=0:return
 if int(app.session.data.level)==3:
  continue_source_trip(delta);return
 if app.session.data.level!=2:return
 if data.is_empty():start_attempt()
 data.clock+=delta;spawn_pending()
 data.regrab_elapsed=0.0 if app.rules.body_busy() or app.rules.gripped else float(data.get("regrab_elapsed",0))+delta
 var medicine_before:float=float(data.medicine_stop)
 data.medicine_stop=maxf(0,medicine_before-delta)
 app.rules.effects.MEDICINE=medicine_before
 # Harmful contacts are resolved before medical healing/consumption.
 if records!=null:records.tick(delta)
 if app.rules.hp<=0:clear_body();return
 if not app.dialogue_queue.is_empty():return
 advance_doctor(delta)
 if app.rules.hp<=0:return
 if not app.dialogue_queue.is_empty():return
 if observations!=null:observations.tick(delta)
 advance_body(delta)
 if not app.dialogue_queue.is_empty():return
 advance_transport(delta)
 if not app.dialogue_queue.is_empty():return
 if eligible():
  var suspended:Dictionary=data.get("suspended_body",{})
  if not suspended.is_empty() and near(str(suspended.actor)) and not data.refused and not data.swallowed:
   data.body=suspended.duplicate(true);data.suspended_body={};return
  if near("nurse") and (not data.get("nurse_checked",false) or (app.rules.hp<100 and not data.healed)):
   set_body("bandage" if app.rules.hp<100 and not data.healed else "nurse_register","nurse");say("NURSE");return
  if near("guide") and not data.registered:
   set_body("registration","guide");say("REGISTER");return
  if near("doctor") and not data.exam_done and app.hero_pos.distance_to(app.layout.furniture[3].at)<1.2:
   set_body("exam","doctor");actor("doctor").phase="approach";actor("doctor").elapsed=0;say("DOCTOR");return
  if near("pharmacist") and app.rules.owners.get("hospital_prescription","")=="hero" and data.get("prescription_visit","")==current_visit() and not data.dispensed:
   set_body("prescription_transfer","pharmacist");say("PHARMACY");return
  if near("patient") and not medical_listener() and not near("guard",2.0) and not data.get("records_state",{}).get("patient_silenced",false):say("PATIENT")
  if near("wheelchair"):say("WHEELCHAIR")
 # The same nurse can walk to the pharmacy; no second actor is manufactured.
 if present("nurse") and data.get("nurse_checked",false) and data.body.get("actor","")!="nurse":
  travel("nurse","pharmacy",delta)

func approach_contact(id:String,delta:float) -> bool:
 if not near(id,0.65):
  if actor(id).room!=app.room_id:return false
  move(id,app.hero_pos,delta)
 return near(id,0.65)

func advance_body(delta:float) -> void:
 if data.body.is_empty():return
 var body:Dictionary=data.body;var kind:String=body.kind;var who:String=body.actor
 if actor(who).room!=app.room_id:clear_body();return
 if not approach_contact(who,delta):return
 if app.rules.body_busy() or (app.rules.control_left>0 and kind not in ["exam","sample"]):return
 body.elapsed+=delta
 var handoff:float=float(config.test_parameters.handoff)+float(body.delay)
 match kind:
  "bandage":
   data.bandage=minf(float(config.timing.bandage),float(data.bandage)+delta)
   if float(data.bandage)+0.000001>=float(config.timing.bandage):
    if claim("bandage","healing",{"hp":10}):app.rules.hp=mini(100,app.rules.hp+int(config.values.heal));data.healed=true
    body.kind="nurse_register";body.elapsed=0;say("NURSE_DONE")
  "nurse_register","registration":
   if float(body.elapsed)<float(config.test_parameters.registration)+float(body.delay):return
   var visit:String=current_visit()
   if kind=="nurse_register":
    data.nurse_checked=true
    record("patient_check:"+visit,"腕带本次就诊号 "+visit+"；旧号字形未交付，未自动认作病服主人。")
    data.bag_order=true;app.rules.owners.hospital_laundry_manifest="ward_tray"
    record("laundry_order:"+visit,"小护士实际填写污衣袋交接单，留在病房交接托盘。")
    if observations!=null and observations.state().read.has("bed_card_old"):
     var hook:Dictionary=observations.config.event_hooks.nurse_old_card_question
     if claim("old_card_question","hospital_dialogue"):
      for line in hook.dialogue:app.add_dialogue(str(line.speaker),str(line.text))
   else:
    data.registered=true;app.rules.owners["hospital_ticket"]="hero"
    record("registration:"+visit,"本次就诊登记完成；不是轮椅患者手续或污衣交接。")
    observe("registration_cover_seen","实际看见导诊护士在本次登记接触中压住背面栏；遮挡未泄露批次、家属或签字内容。")
   clear_body()
  "prescription":
   if float(body.elapsed)>=handoff:
    app.rules.owners.hospital_prescription="hero";data.prescribed=true;data.prescription_visit=current_visit()
    record("prescription:"+current_visit(),"预签处方，实际填入本次就诊编号。")
    claim("prescription","prescription_delivered");clear_body()
  "prescription_transfer":
   if float(body.elapsed)>=handoff:
    if app.rules.owners.get("hospital_prescription","")!="hero" or data.get("prescription_visit","")!=current_visit():clear_body();return
    app.rules.owners.hospital_prescription="pharmacist";data.dispensed=true
    body.kind="mix";body.elapsed=0;claim("dispense_order","prescription_received")
  "mix":
   if float(body.elapsed)>=float(config.test_parameters.mix):
    app.rules.owners.hospital_cup="pharmacist";data.cup_full=true;body.kind="cup_transfer";body.elapsed=0;body.delay=0
  "cup_transfer":
   if float(body.elapsed)>=handoff:
    app.rules.owners.hospital_cup="hero";claim("cup","cup_received")
    if "medicine_harm" in app.rules.known or "false_medicine_seen" in app.rules.known:refuse_medicine()
    else:body.kind="raise_cup";body.elapsed=0;body.delay=0
  "raise_cup":
   if float(body.elapsed)+0.000001>=float(config.timing.cup_raise):
    if claim("swallow","medicine_swallowed",{"sp_damage":15}):
     app.rules.owners.hospital_cup="hero";data.cup_full=false;data.swallowed=true
     app.rules.change_sp(-int(config.values.medicine_sp));data.medicine_stop=float(config.timing.medicine_stop)
     # The swallow happens at this verdict node. NeuralRules will advance the
     # preceding interval once, so preserve the full newly-started second.
     app.rules.effects["MEDICINE"]=float(config.timing.medicine_stop)+delta
     observe("medicine_harm","实际吞服编号药液后精神下降，身体停顿。")
     record("medicine:"+current_visit(),"实际吞服完成。")
    clear_body();say("SWALLOW")

func advance_doctor(delta:float) -> void:
 if not present("doctor") or data.exam_done:return
 var doctor:Dictionary=actor("doctor")
 if doctor.phase not in ["approach","grab","sample"]:return
 if doctor.room!=app.room_id:finish_exam(false);return
 doctor.elapsed+=delta
 if float(doctor.elapsed)>=float(config.timing.exam_max):finish_exam(false);return
 match str(doctor.phase):
  "approach":
   if app.rules.control_left>0 or app.has_key() or app.action_phase in ["return_bed","resting"]:finish_exam(false);return
   if "doctor_harm" in app.rules.known or "donor_screening" in app.rules.known or "removal_record" in app.rules.known:
    if present("assistant") and near("assistant",2):record("refusal:"+current_visit(),"不配合检查");say("ASSIST_REFUSE")
    finish_exam(false);return
   if approach_contact("doctor",delta) and can_begin_grip():doctor.phase="grab";doctor.left=float(config.test_parameters.grab_prepare)
  "grab":
   doctor.left=maxf(0,float(doctor.left)-delta)
   if doctor.left>0:return
   if not near("doctor",0.65) or app.rules.reaction_skill=="WITHDRAW" and app.rules.reaction_left>0:finish_exam(false);say("AVOID");return
   if not str(data.holder).is_empty():finish_exam(false);return
   data.holder="doctor";app.rules.gripped=true
   if damage("needle",int(config.values.needle_hp),0):observe("doctor_harm","检查医生实际固定前臂并刺入针具；取样完成另记。")
   if app.rules.hp<=0:return
   doctor.phase="sample";doctor.left=float(config.timing.sample);say("NEEDLE")
  "sample":
   doctor.left=maxf(0,float(doctor.left)-delta)
   if not near("doctor",0.65):finish_exam(false);return
   if doctor.left<=0:
    data.sample=true;claim("sample","valid_sample",{"visit":current_visit()})
    if present("assistant") and near("assistant",2):record("sample:"+current_visit(),"实际样本核对完成。")
    finish_exam(true);say("SAMPLE")

func finish_exam(sample_completed:bool) -> void:
 data.exam_done=true;actor("doctor").phase="idle"
 if str(data.holder)=="doctor":data.holder="";app.rules.gripped=false;data.regrab_elapsed=0.0
 clear_body()
 if not sample_completed and data.receipts.has("hospital:%d:needle"%app.rules.actual_attempt):claim("sample_interrupted","sample_interrupted")
 if app.rules.hp>0 and present("doctor") and actor("doctor").room==app.room_id:
  set_body("prescription","doctor");current_visit();say("PRESCRIPTION")

func refuse_medicine() -> void:
 if data.swallowed or data.refused:return
 data.refused=true;app.rules.owners.hospital_cup="counter"
 # The contact location is the placement anchor for this same, unconsumed cup;
 # later presentation can map that anchor to a tray without changing ownership.
 data.cup_place={"room":app.room_id,"pos":xy(app.hero_pos)}
 claim("refuse_medicine","medicine_refused");record("refuse_medicine:"+current_visit(),"明确拒服，原杯放回。")
 clear_body();say("REFUSE_MEDICINE")
 # The nurse must be here and see the actual refusal, before a later sticker.
 if near("nurse",2):
  data.false_sticker={"left":float(config.test_parameters.paperwork),"visit":current_visit(),"room":app.room_id,"pos":xy(app.hero_pos),"witness_complete":true}

func advance_false_sticker(delta:float) -> void:
 if not data.has("false_sticker") or not present("nurse"):return
 var event:Dictionary=data.false_sticker
 # Old pending records did not retain the placement or continuous witness.
 # They may still be completed at the pharmacy, but cannot invent a full view.
 if not event.has("room"):
  event.room="pharmacy";event.pos=xy(layout_for("pharmacy").furniture[0].at)
  event.witness_complete=false
 var room:String=str(event.room)
 var at:=Vector2(float(event.pos[0]),float(event.pos[1]))
 var nurse:Dictionary=actor("nurse")
 var visible:bool=app.room_id==room and near("nurse",2.0) and layout_for(room).clear_segment(app.hero_pos,at)
 event.witness_complete=bool(event.get("witness_complete",false)) and visible
 if nurse.room!=room:
  travel("nurse",room,delta);return
 var floor_layout=layout_for(room)
 if position("nurse").distance_to(at)>0.65 or not floor_layout.clear_segment(position("nurse"),at):
  move("nurse",at,delta);return
 if app.rules.owners.get("hospital_cup","")!="counter" or data.swallowed:return
 event.left-=delta
 if float(event.left)>0:return
 record("false_medicine:"+str(event.visit),"已服用（机构贴签；实际未服另账）。")
 claim("false_sticker:"+str(event.visit),"false_medicine_sticker",{"visit":event.visit,"room":room,"pos":event.pos.duplicate()})
 var witnessed:bool=bool(event.witness_complete)
 data.erase("false_sticker")
 if witnessed:
  observe("false_medicine_seen","亲眼看见明确拒服之后，小护士仍贴上已服用标签。")
  say("FALSE_MEDICINE")

func advance_transport(delta:float,existing_trip_only:bool=false) -> void:
 if not existing_trip_only:advance_false_sticker(delta)
 if not app.dialogue_queue.is_empty():return
 if not present("porter"):return
 if advance_relic_packing(delta):return
 var porter:Dictionary=actor("porter")
 if data.transport.is_empty():
  if existing_trip_only:return
  if present("guide") and present("wheelchair") and not data.get("wheelchair_gone",false):
   if not data.has("relic_context"):data.relic_context={"source_attempt":app.rules.actual_attempt}
   data.transport={"kind":"patient","phase":"paperwork","elapsed":0.0,"witness":[],"source_attempt":relic_source_attempt()}
  elif data.bag_order and data.bag=="ward":data.transport={"kind":"bag","phase":"approach","elapsed":0.0,"witness":[]}
  else:return
 var event:Dictionary=data.transport
 if existing_trip_only and str(event.get("kind",""))!="patient":return
 var room:String="lobby" if event.kind=="patient" else "ward"
 if not travel("porter",room,delta):return
 if event.kind=="bag":
  if event.phase=="approach":
   if move("porter",source_anchor("ward","laundry_pickup",Vector2(3.05,1.3)),delta):
    event.phase="lift";event.elapsed=0;say_local("BAG",["porter","nurse"])
  elif event.phase=="lift":
   event.elapsed+=delta
   if event.elapsed>=float(config.test_parameters.handoff):
    if app.rules.owners.get("hospital_laundry_manifest","")!="ward_tray":return
    app.rules.owners.hospital_laundry_manifest="porter"
    claim("laundry_order_received","laundry_order_received")
    data.bag="porter";event.phase="exit"
  elif move("porter",source_portal(room,"lobby").threshold,delta):
   data.bag="removed";record("bag_stub","污衣袋实际搬离，办公室保留交接存根。")
   claim("bag_removed","bag_removed");data.transport={}
  return
 if not existing_trip_only and not data.body.is_empty() and data.body.actor=="guide":return
 if event.phase=="paperwork":
  if actor("guide").room!="lobby" or actor("wheelchair").room!="lobby":return
  var patient_pos:Vector2=position("wheelchair")
  if position("guide").distance_to(patient_pos)>float(config.test_parameters.approach_distance) or not layout_for("lobby").clear_segment(position("guide"),patient_pos):
   move("guide",patient_pos,delta);return
  if position("porter").distance_to(position("guide"))>float(config.test_parameters.approach_distance) or not layout_for("lobby").clear_segment(position("porter"),position("guide")):
   move("porter",position("guide"),delta);return
  if float(event.elapsed)<=0.000001 and say_local("TRANSFER",["guide","wheelchair","porter"]):return
  event.elapsed+=delta
  if event.elapsed>=float(config.test_parameters.paperwork):event.phase="push";data.wheelchair_order=true;claim("patient_order","patient_transport_order",{"patient":"wheelchair"},relic_source_attempt());record("wheelchair_order","导诊护士实际完成轮椅患者自己的转运手续；不使用角色核号表替代。")
 elif event.phase=="push":
  if not move("porter",position("wheelchair"),delta):return
  event.phase="frame";event.elapsed=0
 elif event.phase=="frame":
  var to:Vector2=source_anchor("lobby","transport_frame",source_door("lobby","ward"))
  var reached:bool=move("porter",to,delta)
  actor("wheelchair").pos=porter.pos.duplicate()
  if reached:
   drop_transport_relics()
   event.phase="fingers";event.elapsed=0;say_local("FRAME",["wheelchair"])
   if app.room_id=="lobby" and near("wheelchair",2) and not "frame" in event.witness:event.witness.append("frame")
 elif event.phase=="fingers":
  if not present("guide") or actor("guide").room!="lobby":return
  if not move("guide",position("wheelchair")+source_tangent("lobby","ward")*0.35,delta):return
  event.elapsed+=delta
  if event.elapsed>=float(config.test_parameters.finger_release):
   event.phase="leave"
   if app.room_id=="lobby" and near("wheelchair",2) and not "fingers" in event.witness:event.witness.append("fingers")
 elif event.phase=="leave":
  var left_room:bool=move("porter",source_anchor("lobby","transport_exit",Vector2(1.25,0.2)),delta)
  actor("wheelchair").pos=porter.pos.duplicate()
  update_footplate_anchor()
  if not left_room:return
  # Last visible doorway contact: collect the one photo from the actual
  # footplate before that chair disappears. Old already-gone chairs cannot
  # be recovered by inferring an anchor from their stale ownership string.
  if relic_contact("family_photo"):
   event.phase="photo_prepare";event.elapsed=0.0
  else:finish_patient_transport(event)
 elif event.phase in ["photo_prepare","photo_contact","photo_finish"]:
  if event.phase!="photo_finish" and not relic_contact("family_photo"):
   finish_patient_transport(event);return
  event.elapsed+=delta
  if event.phase=="photo_prepare" and float(event.elapsed)>=float(config.test_parameters.handoff)*0.4:
   event.phase="photo_contact";event.elapsed=0.0
  elif event.phase=="photo_contact" and float(event.elapsed)>=float(config.test_parameters.handoff)*0.6:
   pack_relic("family_photo");event.phase="photo_finish";event.elapsed=0.0
  elif event.phase=="photo_finish" and float(event.elapsed)>=float(config.test_parameters.handoff)*0.4:
   finish_patient_transport(event)

func positive_source_attempt(value) -> int:
 if value is int:return value if value>0 else 0
 if value is float and is_finite(value) and value>0 and floor(value)==value:return int(value)
 return 0

func known_source_attempt() -> int:
 for value in [data.get("relic_context",{}).get("source_attempt",0),data.get("relic_delivery",{}).get("source_attempt",0),data.get("transport",{}).get("source_attempt",0),data.get("hospital_attempt",0)]:
  var attempt:int=positive_source_attempt(value)
  if attempt>0:return attempt
 for key in data.get("receipts",{}):
  if str(data.receipts[key]) not in ["patient_transport_order","hospital_relics_fell","hospital_relic_packed","patient_transport_completed"]:continue
  var parts:PackedStringArray=str(key).split(":")
  if parts.size()>=3 and parts[0]=="hospital" and parts[1].is_valid_int() and parts[1].to_int()>0:return parts[1].to_int()
 return positive_source_attempt(app.session.data.get("attempts",{}).get("2",0))

func relic_source_attempt() -> int:
 var attempt:int=positive_source_attempt(data.get("relic_context",{}).get("source_attempt",0))
 if attempt>0:return attempt
 return app.rules.actual_attempt if int(app.session.data.level)==2 else known_source_attempt()

func has_started_source_trip() -> bool:
 if data.is_empty() or not present("porter"):return false
 var transport:Dictionary=data.get("transport",{})
 if str(transport.get("kind",""))=="patient" and str(transport.get("phase","")) in ["paperwork","push","frame","fingers","leave","photo_prepare","photo_contact","photo_finish"]:
  return present("wheelchair") and not data.get("wheelchair_gone",false)
 var packing:Dictionary=data.get("relic_packing",{})
 if str(packing.get("phase","")) not in ["shoe_route","shoe_prepare","shoe_contact","shoe_finish","carry_exit"]:return false
 if data.get("transport_relics",{}).is_empty():return false
 return "patient_transport_completed" in data.get("receipts",{}).values()

func continue_source_trip(delta:float) -> void:
 if not is_finite(delta) or delta<=0 or not app.dialogue_queue.is_empty() or not has_started_source_trip():return
 var attempt:int=known_source_attempt()
 if attempt<=0:data.relic_late_wait="unknown_original_attempt";return
 if not data.has("relic_context"):data.relic_context={"source_attempt":attempt}
 data.relic_late_wait="";data.relic_transit_elapsed=float(data.get("relic_transit_elapsed",0.0))+delta
 # Deliberately no general hospital clock, spawn, medicine, injury, body or
 # protagonist action update after chapter exit. Only this saved real trip.
 advance_transport(delta,true)

func relic_receipt(id:String) -> String:return "hospital:%d:%s"%[relic_source_attempt(),id]

func drop_transport_relics() -> void:
 if not present("wheelchair") or str(actor("wheelchair").room)!="lobby":return
 if not data.has("relic_context"):data.relic_context={"source_attempt":relic_source_attempt()}
 if not data.has("transport_relics"):data.transport_relics={}
 var props:Dictionary=data.transport_relics
 for id in ["family_photo","patient_shoe"]:
  var required:String="wheelchair_footplate" if id=="family_photo" else "lobby_floor"
  var previous:String=str(app.rules.owners.get(id,""))
  if props.has(id) or previous in ["hero","hospital_relic_container"]:continue
  if id=="family_photo" and previous!="wheelchair":continue
  if id=="patient_shoe" and previous not in ["","wheelchair","lobby_floor"]:continue
  app.rules.owners[id]=required
  props[id]={"room":"lobby","pos":xy(position("wheelchair")),"support":required,"accessible":true,"source_attempt":relic_source_attempt()}
 claim("patient_relics_fell","hospital_relics_fell",{"items":props.keys()},relic_source_attempt())

func update_footplate_anchor() -> void:
 var photo:Dictionary=data.get("transport_relics",{}).get("family_photo",{})
 if not photo.is_empty() and photo.accessible and app.rules.owners.get("family_photo","")=="wheelchair_footplate" and present("wheelchair"):
  photo.room=str(actor("wheelchair").room);photo.pos=xy(position("wheelchair"))

func relic_position(id:String) -> Dictionary:
 var item:Dictionary=data.get("transport_relics",{}).get(id,{})
 if item.is_empty() or not item.get("accessible",false):return {}
 if str(app.rules.owners.get(id,""))!=str(item.support):return {}
 if id=="family_photo" and (not present("wheelchair") or data.get("wheelchair_gone",false)):return {}
 return item

func relic_contact(id:String) -> bool:
 if not present("porter") or str(actor("porter").room)!="lobby":return false
 var item:Dictionary=relic_position(id)
 if item.is_empty():return false
 var at:Vector2=Vector2(float(item.pos[0]),float(item.pos[1]))
 return position("porter").distance_to(at)<=0.65 and layout_for("lobby").clear_segment(position("porter"),at)

func pack_relic(id:String) -> bool:
 if relic_source_attempt()<=0 or not relic_contact(id):return false
 var expected:String="wheelchair_footplate" if id=="family_photo" else "lobby_floor"
 if app.rules.owners.get(id,"")!=expected:return false
 var bag_owner:String=str(app.rules.owners.get("hospital_relic_container",""))
 if bag_owner not in ["","hospital_relic_carry"]:return false
 if not data.has("relic_delivery"):
  data.relic_delivery={"version":1,"source_attempt":relic_source_attempt(),"transport_receipt":relic_receipt("patient_transport"),"bag_id":"hospital_relic_container","items":[],"packed_receipts":{},"source_owners":{},"ready":false}
 var delivery:Dictionary=data.relic_delivery
 if int(delivery.source_attempt)!=relic_source_attempt() or id in delivery.items:return false
 var key:String=relic_receipt("relic_packed:"+id)
 if not claim("relic_packed:"+id,"hospital_relic_packed",{"item":id,"from":expected,"container":"hospital_relic_container","room":"lobby","pos":data.transport_relics[id].pos},relic_source_attempt()):return false
 app.rules.owners[id]="hospital_relic_container";app.rules.owners.hospital_relic_container="hospital_relic_carry"
 delivery.items.append(id);delivery.packed_receipts[id]=key;delivery.source_owners[id]=expected
 data.transport_relics[id].accessible=false
 if source_scene_visible("lobby") and app.get("audio")!=null:app.audio.cue("SFX_SEARCH_PAPER" if id=="family_photo" else "SFX_SEARCH_CLOTH",key)
 return true

func finish_patient_transport(event:Dictionary) -> void:
 if app.room_id=="lobby" and near("wheelchair",2) and "frame" in event.witness and "fingers" in event.witness:
  if claim("witness_transport","witness_transport",{},relic_source_attempt()):app.rules.change_sp(-int(config.values.witness_sp));observe("forced_transfer_seen","亲眼看见轮椅患者抓门框、护士掰指与强制推离。")
  say("TRANSFER_DONE",relic_source_attempt())
 actor("wheelchair").phase="gone";data.wheelchair_gone=true
 var photo:Dictionary=data.get("transport_relics",{}).get("family_photo",{})
 if not photo.is_empty():photo.accessible=false
 claim("patient_transport","patient_transport_completed",{},relic_source_attempt());record("patient_departure","轮椅患者：自行离院（机构记载，与真实强制转运分账）。")
 data.transport={}
 data.relic_packing={"phase":"shoe_route","elapsed":0.0,"actor":"porter","room":"lobby","last_cancel":""}

func packing_move(to:Vector2,delta:float) -> bool:
 # Ordinary fixed furniture navigation plus visible bodies. Never collect
 # through an occupied doorway by letting the packer walk through its body.
 var from:Vector2=position("porter")
 if from.distance_to(to)<0.035:return true
 var floor_layout=layout_for("lobby");var a:Dictionary=actor("porter")
 var route:PackedVector2Array=PackedVector2Array()
 for p in a.route:route.append(Vector2(float(p[0]),float(p[1])))
 if route.is_empty() or route[-1].distance_to(to)>0.08:route=floor_layout.path(from,to)
 var moved:Dictionary=floor_layout.move_path(from,route,float(config.test_parameters.walk_speed)*delta)
 var obstacles:Array=[]
 if source_scene_visible("lobby"):obstacles.append({"pos":app.hero_pos,"clearance":0.4})
 for other in data.actors:
  if str(other)=="porter" or not present(str(other)) or str(actor(str(other)).room)!="lobby":continue
  obstacles.append({"pos":position(str(other)),"clearance":0.32})
 if packing_step_blocked(from,moved.position,obstacles):
  route=packing_detour(floor_layout,from,to,obstacles)
  if route.is_empty():return false
  moved=floor_layout.move_path(from,route,float(config.test_parameters.walk_speed)*delta)
  if packing_step_blocked(from,moved.position,obstacles):return false
 a.pos=xy(moved.position);a.route=Array(moved.route).map(func(p):return xy(p))
 return position("porter").distance_to(to)<0.035

func packing_step_blocked(from:Vector2,to:Vector2,obstacles:Array) -> bool:
 for obstacle in obstacles:
  if packing_body_blocked(obstacle.pos,from,to,float(obstacle.clearance)):return true
 return false

func packing_detour(floor_layout,from:Vector2,to:Vector2,obstacles:Array) -> PackedVector2Array:
 # Find an actual route around present bodies. A rounded grid goal can fall
 # inside a body even when the exact doorway point is clear: approach via a
 # neighbouring clear cell, then validate the final exact segment as well.
 if packing_step_blocked(to,to,obstacles):return PackedVector2Array()
 var changed:Array[Vector2i]=[]
 var start_cell:=Vector2i((from/float(floor_layout.CELL)).round())
 var region:Rect2i=floor_layout.grid.region
 for y in range(region.position.y,region.end.y):
  for x in range(region.position.x,region.end.x):
   var cell:=Vector2i(x,y)
   if cell==start_cell or floor_layout.grid.is_point_solid(cell):continue
   var at:=Vector2(cell)*float(floor_layout.CELL)
   if packing_step_blocked(at,at,obstacles):
    changed.append(cell);floor_layout.grid.set_point_solid(cell,true)
 var end_cell:=Vector2i((to/float(floor_layout.CELL)).round())
 var best:=PackedVector2Array();var best_length:float=INF
 for y in range(-1,2):
  for x in range(-1,2):
   var cell:Vector2i=end_cell+Vector2i(x,y)
   if not floor_layout.grid.is_in_boundsv(cell) or floor_layout.grid.is_point_solid(cell):continue
   var stop:=Vector2(cell)*float(floor_layout.CELL)
   if not floor_layout.clear_segment(stop,to,float(floor_layout.RADIUS)) or packing_step_blocked(stop,to,obstacles):continue
   var candidate:PackedVector2Array=floor_layout.path(from,stop)
   if candidate.is_empty():continue
   candidate.append(to)
   var length:float=0;var previous:Vector2=from;var clear:bool=true
   for point in candidate:
    if point.distance_to(previous)>0.000001 and packing_step_blocked(previous,point,obstacles):clear=false;break
    length+=previous.distance_to(point);previous=point
   if clear and length<best_length:best=candidate;best_length=length
 for cell in changed:floor_layout.grid.set_point_solid(cell,false)
 return best

func packing_body_blocked(at:Vector2,from:Vector2,to:Vector2,clearance:float=0.4) -> bool:
 # Existing paired transport may leave the guide 0.35m from the porter.
 # Permit only an outward step from that inherited proximity; never move
 # deeper into it or pass through another body's occupied segment.
 var initial:float=from.distance_to(at)
 if initial<clearance and to.distance_to(at)>initial+0.000001:return false
 return Geometry2D.get_closest_point_to_segment(at,from,to).distance_to(at)<clearance

func finish_relic_packing() -> void:
 var job:Dictionary=data.relic_packing;job.phase="done";job.elapsed=0.0
 var delivery:Dictionary=data.get("relic_delivery",{})
 if delivery.is_empty():return
 delivery.bag_departed=true;delivery.exit_pos=xy(position("porter"));delivery.exit_room=str(actor("porter").room)
 delivery.ready=not delivery.items.is_empty() and str(data.receipts.get(str(delivery.transport_receipt),""))=="patient_transport_completed"
 for id in delivery.items:
  if app.rules.owners.get(str(id),"")!="hospital_relic_container" or str(data.receipts.get(str(delivery.packed_receipts.get(str(id),"")),""))!="hospital_relic_packed":delivery.ready=false

func advance_relic_packing(delta:float) -> bool:
 var job:Dictionary=data.get("relic_packing",{})
 if job.is_empty() or str(job.phase)=="done":return false
 if not present("porter"):return true
 if str(actor("porter").room)!="lobby":return true
 if job.phase=="carry_exit":
  if packing_move(source_anchor("lobby","transport_exit",Vector2(1.25,0.2)),delta):finish_relic_packing()
  return true
 if job.phase=="shoe_finish":
  job.elapsed=float(job.elapsed)+delta
  if float(job.elapsed)>=float(config.test_parameters.handoff)*0.4:job.phase="carry_exit";job.elapsed=0.0
  return true
 var shoe:Dictionary=relic_position("patient_shoe")
 if shoe.is_empty():
  job.last_cancel="shoe_not_present_or_taken";job.phase="carry_exit";job.elapsed=0.0;return true
 var at:Vector2=Vector2(float(shoe.pos[0]),float(shoe.pos[1]))
 var stand:Vector2=at+source_portal("lobby","ward").inward*0.5
 if not layout_for("lobby").walkable(stand):stand=at
 if job.phase=="shoe_route":
  if packing_move(stand,delta):job.phase="shoe_prepare";job.elapsed=0.0
  return true
 if not relic_contact("patient_shoe"):
  job.phase="shoe_route";job.elapsed=0.0;job.last_cancel="lost_contact";return true
 job.elapsed=float(job.elapsed)+delta
 if job.phase=="shoe_prepare" and float(job.elapsed)>=float(config.test_parameters.handoff)*0.4:
  job.phase="shoe_contact";job.elapsed=0.0
 elif job.phase=="shoe_contact" and float(job.elapsed)>=float(config.test_parameters.handoff)*0.6:
  pack_relic("patient_shoe");job.phase="shoe_finish";job.elapsed=0.0
 return true

func relic_markers() -> Array:
 var result:Array=[]
 for id in ["family_photo","patient_shoe"]:
  var item:Dictionary=relic_position(str(id))
  if item.is_empty():continue
  result.append({"id":str(id),"room":item.room,"pos":item.pos.duplicate(),"kind":"note" if id=="family_photo" else "shoe","label":"踏板照片" if id=="family_photo" else "遗留鞋子"})
 if app.rules.owners.get("hospital_relic_container","")=="hospital_relic_carry" and present("porter") and not data.get("relic_delivery",{}).get("bag_departed",false):
  result.append({"id":"hospital_relic_container","room":actor("porter").room,"pos":xy(position("porter")),"kind":"bag","label":"实际收存原物的袋","draw_offset":[11,-25]})
 return result

func relic_packing_action() -> Dictionary:
 var transport:Dictionary=data.get("transport",{})
 var packing:Dictionary=data.get("relic_packing",{})
 var phase:String=str(transport.get("phase",""))
 var elapsed:float=float(transport.get("elapsed",0.0))
 var id:String="family_photo"
 if not phase.begins_with("photo_"):
  phase=str(packing.get("phase",""));elapsed=float(packing.get("elapsed",0.0));id="patient_shoe"
 if phase.is_empty() or phase=="done" or not present("porter"):return {}
 if id=="patient_shoe" and phase=="carry_exit":
  return {"actor":"porter","room":str(actor("porter").room),"phase":phase,"target":"hospital_relic_container","pos":xy(source_anchor("lobby","transport_exit",Vector2(1.25,0.2))),"elapsed":0.0,"progress":0.0,"label":"实际携袋回到原转运出口"}
 if id=="patient_shoe" and not phase.begins_with("shoe_"):return {}
 var item:Dictionary=data.get("transport_relics",{}).get(id,{})
 if item.is_empty():return {}
 var seconds:float=float(config.test_parameters.handoff)*(0.6 if phase.ends_with("contact") else 0.4)
 return {"actor":"porter","room":str(actor("porter").room),"phase":phase,"target":id,"pos":item.pos.duplicate(),"elapsed":elapsed,"progress":clampf(elapsed/seconds,0,1),"label":"实际收存踏板照片" if id=="family_photo" else "实际收存遗留鞋子"}

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false):return
 if records!=null:records.on_skill(result)
 var id:String=result.id
 if observations!=null and id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  app.cancel_hospital_observation()
 if id=="DRYMOUTH" and not data.body.is_empty() and data.body.kind in ["registration","nurse_register","prescription","prescription_transfer","cup_transfer"]:data.body.delay+=float(config.timing.drymouth)
 if id=="GUT" and app.rules.owners.get("hospital_cup","")=="hero" and not data.swallowed:refuse_medicine()
 elif id in ["SKIN","GUT","WITHDRAW","STARTLE","FEAR","CONTROL"] and not data.body.is_empty() and data.body.kind not in ["exam","sample","guard_drag"]:
  data.suspended_body=data.body.duplicate(true);clear_body()
 if near("patient",2) and not app.rules.settled.has("hospital_patient_anomaly_quote") and not data.get("records_state",{}).get("patient_silenced",false) and id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","PORES"]:
  app.rules.settled.hospital_patient_anomaly_quote="seen"
  say("PATIENT_AWARE" if app.rules.awareness_stage>=3 else "PATIENT_ANOMALY")

func kick_contact() -> void:
 if records!=null:records.kick_contact()
 if not present("doctor") or actor("doctor").room!=app.room_id:return
 var offset:Vector2=position("doctor")-app.hero_pos
 if app.rules.kick_contact("hospital_doctor",offset.length(),offset.normalized().dot(app.hero_facing)>0.35,app.layout.clear_segment(app.hero_pos,position("doctor"))):
  if present("assistant") and near("assistant",2):record("attack:"+current_visit(),"攻击工作人员（实际踢中医生）。");say("ASSIST_KICK")
  finish_exam(false)

func on_search_complete(index:int,found_key:bool) -> void:
 if records!=null:records.on_search_complete(index,found_key)
 var points:Array=config.points.get(app.room_id,[])
 if index<0 or index>=points.size() or found_key:return
 var point:Dictionary=points[index]
 if not claim("no_key:"+str(point.id),"hospital_search_feedback"):return
 var lines:Array=point.lines
 if not lines.is_empty():app.add_dialogue("角色",str(lines[0]))
 if lines.size()>1:app.add_dialogue("玩家",str(lines[1]) if point.id!="clinic:0" or "presigned_form" in app.rules.known else "下一处。")

func actors() -> Array:
 var result:Array=[]
 if not enabled or data.is_empty() or app.session.data.level!=2:return result
 for id in data.actors:
  if present(id) and actor(id).room==app.room_id:result.append({"type":"actor","data":"hospital_"+str(id),"depth":app.layout.project(position(id)).y})
 return result
