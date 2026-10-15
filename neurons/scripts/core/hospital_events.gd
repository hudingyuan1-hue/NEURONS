extends RefCounted
## S3 hospital events. Primitive JSON state; no asset frame decides a receipt.
const Layout=preload("res://scripts/world/room_layout.gd")
const Session=preload("res://scripts/core/campaign_session.gd")
var app
var config:Dictionary={}
var data:Dictionary={}
var enabled:bool=true
var records

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/hospital.json"))

func start_attempt() -> void:
 data={"actors":{},"groups":{},"room_left":{},"batches":{},"clock":0.0,"receipts":{},"body":{},"holder":"","visit":"","prescription_visit":"","bandage":0.0,"healed":false,"registered":false,"exam_done":false,"sample":false,"prescribed":false,"dispensed":false,"refused":false,"swallowed":false,"medicine_stop":0.0,"bag":"ward","bag_order":false,"transport":{},"known_pages":[],"suspended_body":{}}
 for id in config.rooms:
  data.actors[id]={"room":str(config.rooms[id]),"pos":[4.4,0.35],"route":[],"phase":"absent","left":0.0,"elapsed":0.0}
 for key in config.groups:data.groups[key]={"checks":0,"pending":false,"drawn":false}
 data.regrab_elapsed=0.8
 data.nurse_checked=false

func restore(saved:Dictionary) -> void:
 if saved.is_empty():start_attempt()
 else:data=saved.duplicate(true)

func actor(id:String) -> Dictionary:
 return data.actors[id]

func position(id:String) -> Vector2:
 var p:Array=actor(id).pos
 return Vector2(float(p[0]),float(p[1]))

func present(id:String) -> bool:
 return enabled and not data.is_empty() and actor(id).phase not in ["absent","gone"]

func layout_for(room:String):
 if room==app.room_id:return app.layout
 return app.layout_for_room(room)

func xy(p:Vector2) -> Array:return [p.x,p.y]

func near(id:String,distance:float=-1) -> bool:
 if not present(id) or actor(id).room!=app.room_id:return false
 return position(id).distance_to(app.hero_pos)<=(float(config.test_parameters.notice_distance) if distance<0 else distance) and app.layout.clear_segment(position(id),app.hero_pos)

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
 var step:String=app.session.next_room(str(a.room),room)
 if step.is_empty():return false
 var doorway:Vector2=app.door_point_for(str(a.room),step)
 if move(id,doorway,delta):
  var previous:String=str(a.room)
  a.room=step;a.pos=xy(app.door_point_for(step,previous));a.route=[]
 return a.room==room

func claim(id:String,kind:String,details:Dictionary={}) -> bool:
 var key:String="hospital:%d:%s"%[app.rules.actual_attempt,id]
 if data.receipts.has(key) or app.rules.hp<=0:return false
 data.receipts[key]=kind
 app.rules._record(kind,key,details)
 return true

func say(key:String) -> void:
 if not claim("line:"+key,"hospital_dialogue"):return
 for line in config.dialogue.get(key,[]):app.add_dialogue(str(line.speaker),str(line.text))

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
 return enabled and not data.is_empty() and (not data.body.is_empty() or not str(data.holder).is_empty() or float(data.medicine_stop)>0)

func eligible() -> bool:
 return not app.has_key() and not app.rules.search_active and app.action_phase=="autonomy" and not app.rules.body_busy() and not app.rules.gripped and app.rules.control_left<=0 and data.body.is_empty()

func on_enter(from:String,room:String) -> void:
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
  var entry:=Vector2(4.4,0.35)
  if app.hero_pos.distance_to(entry)<0.7:continue
  var occupied:bool=false
  for id in data.actors:
   if present(id) and actor(id).room==room and position(id).distance_to(entry)<0.5:occupied=true
  if occupied:continue
  for index in range(config.groups[group].size()):
   var id:String=config.groups[group][index];var a:Dictionary=actor(id)
   a.phase="idle";a.room=config.rooms[id];a.pos=[4.4-index*0.5,0.35];a.route=[]
   if id=="wheelchair":app.rules.owners.family_photo="wheelchair"
  state.pending=false;data.batches[room]=data.clock

func tick(delta:float) -> void:
 if not enabled or app.session.data.level!=2 or app.rules.hp<=0:return
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
  if near("patient") and not near("guard",2.0) and not data.get("records_state",{}).get("patient_silenced",false):say("PATIENT")
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
   else:
    data.registered=true;app.rules.owners["hospital_ticket"]="hero"
    record("registration:"+visit,"本次就诊登记完成；不是轮椅患者手续或污衣交接。")
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
    app.rules.owners.hospital_cup="pharmacist";body.kind="cup_transfer";body.elapsed=0;body.delay=0
  "cup_transfer":
   if float(body.elapsed)>=handoff:
    app.rules.owners.hospital_cup="hero";claim("cup","cup_received")
    if "medicine_harm" in app.rules.known or "false_medicine_seen" in app.rules.known:refuse_medicine()
    else:body.kind="raise_cup";body.elapsed=0;body.delay=0
  "raise_cup":
   if float(body.elapsed)+0.000001>=float(config.timing.cup_raise):
    if claim("swallow","medicine_swallowed",{"sp_damage":15}):
     app.rules.owners.hospital_cup="empty_cup";data.swallowed=true
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
 claim("refuse_medicine","medicine_refused");record("refuse_medicine:"+current_visit(),"明确拒服，原杯放回。")
 clear_body();say("REFUSE_MEDICINE")
 # The nurse must be here and see the actual refusal, before a later sticker.
 if near("nurse",2):data.false_sticker={"left":float(config.test_parameters.paperwork),"visit":current_visit()}

func advance_transport(delta:float) -> void:
 if data.has("false_sticker") and near("nurse",2):
  data.false_sticker.left-=delta
  if data.false_sticker.left<=0:
   record("false_medicine:"+str(data.false_sticker.visit),"已服用（机构贴签；实际未服另账）。")
   observe("false_medicine_seen","亲眼看见明确拒服之后，小护士仍贴上已服用标签。")
   data.erase("false_sticker");say("FALSE_MEDICINE")
 if not present("porter"):return
 var porter:Dictionary=actor("porter")
 if data.transport.is_empty():
  if present("guide") and present("wheelchair") and not data.get("wheelchair_gone",false):
   data.transport={"kind":"patient","phase":"paperwork","elapsed":0.0,"witness":[]};say("TRANSFER")
  elif data.bag_order and data.bag=="ward":data.transport={"kind":"bag","phase":"approach","elapsed":0.0,"witness":[]}
  else:return
 var event:Dictionary=data.transport
 var room:String="lobby" if event.kind=="patient" else "ward"
 if not travel("porter",room,delta):return
 if event.kind=="bag":
  if event.phase=="approach":
   if move("porter",Vector2(3.05,1.3),delta):event.phase="lift";event.elapsed=0;say("BAG")
  elif event.phase=="lift":
   event.elapsed+=delta
   if event.elapsed>=float(config.test_parameters.handoff):
    if app.rules.owners.get("hospital_laundry_manifest","")!="ward_tray":return
    app.rules.owners.hospital_laundry_manifest="porter"
    claim("laundry_order_received","laundry_order_received")
    data.bag="porter";event.phase="exit"
  elif move("porter",app.door_point_for(room,"lobby"),delta):
   data.bag="removed";record("bag_stub","污衣袋实际搬离，办公室保留交接存根。")
   claim("bag_removed","bag_removed");data.transport={}
  return
 if not data.body.is_empty() and data.body.actor=="guide":return
 if event.phase=="paperwork":
  if actor("guide").room!="lobby" or actor("wheelchair").room!="lobby":return
  var patient_pos:Vector2=position("wheelchair")
  if position("guide").distance_to(patient_pos)>float(config.test_parameters.approach_distance) or not layout_for("lobby").clear_segment(position("guide"),patient_pos):
   move("guide",patient_pos,delta);return
  if position("porter").distance_to(position("guide"))>float(config.test_parameters.approach_distance) or not layout_for("lobby").clear_segment(position("porter"),position("guide")):
   move("porter",position("guide"),delta);return
  event.elapsed+=delta
  if event.elapsed>=float(config.test_parameters.paperwork):event.phase="push";data.wheelchair_order=true;claim("patient_order","patient_transport_order",{"patient":"wheelchair"});record("wheelchair_order","导诊护士实际完成轮椅患者自己的转运手续；不使用角色核号表替代。")
 elif event.phase=="push":
  if not move("porter",position("wheelchair"),delta):return
  event.phase="frame";event.elapsed=0
 elif event.phase=="frame":
  var to:Vector2=app.door_point_for("lobby","ward")
  var reached:bool=move("porter",to,delta)
  actor("wheelchair").pos=porter.pos.duplicate()
  if reached:
   event.phase="fingers";event.elapsed=0;say("FRAME")
   if app.room_id=="lobby" and near("wheelchair",2) and not "frame" in event.witness:event.witness.append("frame")
 elif event.phase=="fingers":
  if not present("guide") or actor("guide").room!="lobby":return
  if not move("guide",position("wheelchair")+Vector2(0.35,0),delta):return
  event.elapsed+=delta
  if event.elapsed>=float(config.test_parameters.finger_release):
   event.phase="leave"
   if app.room_id=="lobby" and near("wheelchair",2) and not "fingers" in event.witness:event.witness.append("fingers")
 elif event.phase=="leave":
  var left_room:bool=move("porter",Vector2(1.25,0.2),delta)
  actor("wheelchair").pos=porter.pos.duplicate()
  if not left_room:return
  if app.room_id=="lobby" and near("wheelchair",2) and "frame" in event.witness and "fingers" in event.witness:
   if claim("witness_transport","witness_transport"):app.rules.change_sp(-int(config.values.witness_sp));observe("forced_transfer_seen","亲眼看见轮椅患者抓门框、护士掰指与强制推离。")
   say("TRANSFER_DONE")
  actor("wheelchair").phase="gone";data.wheelchair_gone=true
  app.rules.owners.family_photo="wheelchair_footplate";app.rules.owners.patient_shoe="lobby_floor"
  claim("patient_transport","patient_transport_completed");record("patient_departure","轮椅患者：自行离院（机构记载，与真实强制转运分账）。")
  data.transport={}

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false):return
 if records!=null:records.on_skill(result)
 var id:String=result.id
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
