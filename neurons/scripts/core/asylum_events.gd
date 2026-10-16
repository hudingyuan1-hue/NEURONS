extends RefCounted
## S3:P614–777, S4:T10/11/15/16. Shared identities; gameplay clock only.
const Map=preload("res://scripts/core/asylum_map.gd")
var app
var config:Dictionary={}
var data:Dictionary={}
var enabled:bool=true
var ward_events
var records
var trace_events
var isolation
var observations
var nurse_duty

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum.json"))

func start_attempt(carry:Dictionary={}) -> void:
 var old_work:Dictionary=data.get("ward_events",{}).get("work",{}).duplicate(true)
 data={"actors":{},"groups":{},"room_left":{},"batches":{},"clock":0.0,"receipts":{},"body":{},"holder":"","regrab_elapsed":0.8,"carry":carry.duplicate(true),"wrist_checked":false,"wrist_done":false,"registered":false,"diagnosed":false,"order_written":false,"order_delivered":false,"order_source":"","dispensed":false,"cup_full":false,"refused":false,"swallowed":false,"medicine_stop":0.0,"exam":{},"ward_events":{}}
 if not old_work.is_empty():data.ward_events.work=old_work
 for id in config.rooms:
  data.actors[id]={"room":str(config.rooms[id]),"pos":[4.4,0.35],"route":[],"phase":"absent","elapsed":0.0,"left":0.0}
 for group in config.groups:data.groups[group]={"checks":0,"pending":false,"drawn":false}
 # Prior paper allegations are retained as paper only. An existing, genuinely
 # unexecuted prescription may transfer; prior completed medicine cannot replay.
 if app.rules.owners.get("hospital_prescription","")=="hero" and carry.get("prescribed",false) and not carry.get("dispensed",false) and not carry.get("swallowed",false) and not carry.get("refused",false) and carry.get("prescription_visit","")==carry.get("visit","") and not str(carry.get("visit","")).is_empty():
  data.order_source="hospital_prescription";data.order_delivered=true

func restore(saved:Dictionary) -> void:
 if saved.is_empty():
  data.clear();start_attempt()
 else:data=saved.duplicate(true)

func actor(id:String) -> Dictionary:return data.actors.get(id,{})
func xy(value:Vector2) -> Array:return [value.x,value.y]
func position(id:String) -> Vector2:
 var p:Array=actor(id).get("pos",[0.0,0.0])
 return Vector2(float(p[0]),float(p[1]))
func present(id:String) -> bool:
 return enabled and not data.is_empty() and not actor(id).is_empty() and actor(id).phase not in ["absent","gone"]
func layout_for(room:String):
 return app.layout if room==app.room_id else app.layout_for_room(room)
func near(id:String,distance:float=1.2) -> bool:
 return present(id) and str(actor(id).room)==app.room_id and position(id).distance_to(app.hero_pos)<=distance and app.layout.clear_segment(position(id),app.hero_pos)
func visible(id:String,at:Vector2,room:String,distance:float=2.0) -> bool:
 return present(id) and str(actor(id).room)==room and position(id).distance_to(at)<=distance and layout_for(room).clear_segment(position(id),at)
func move(id:String,to:Vector2,delta:float) -> bool:
 if not present(id):return false
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
 if not present(id):return false
 var a:Dictionary=actor(id)
 if str(a.room)==room:return true
 var step:String=Map.next_room(str(a.room),room)
 if step.is_empty() or step=="cortex_exit":return false
 if isolation!=null and not isolation.can_exit(str(a.room),step):return false
 var doorway:Vector2=Map.doorway(str(a.room),step)
 if move(id,doorway,delta):
  var previous:String=str(a.room)
  a.room=step;a.pos=xy(Map.doorway(step,previous));a.route=[]
 return str(a.room)==room

func claim(id:String,kind:String,details:Dictionary={}) -> bool:
 var key:String="asylum:%d:%s"%[app.rules.actual_attempt,id]
 if data.receipts.has(key) or app.rules.hp<=0:return false
 data.receipts[key]=kind;app.rules._record(kind,key,details)
 var cue:String={"asylum_document_read":"SFX_SEARCH_PAPER","asylum_medical_order_written":"SFX_SEARCH_PAPER","asylum_medical_order_delivered":"SFX_SEARCH_PAPER","asylum_work_partial":"SFX_SEARCH_PAPER","asylum_relic_taken":"SFX_SEARCH_CLOTH","asylum_band_dropped":"SFX_SEARCH_CLOTH","asylum_drawer_contact":"SFX_DRAWER","asylum_isolation_door_closed":"SFX_DOOR_CLOSE","asylum_isolation_door_opened":"SFX_DOOR_OPEN"}.get(kind,"")
 if not cue.is_empty():app.audio.cue(cue,key)
 return true
func say(key:String) -> void:
 if not claim("line:"+key,"asylum_dialogue"):return
 for line in config.dialogue.get(key,[]):app.add_dialogue(str(line.speaker),str(line.text))
func observe(id:String,text:String) -> void:
 if not id in app.rules.known:app.rules.known.append(id)
 app.rules.observe("物品",id,text,"亲历事实","精神病院实际观察")
func record(id:String,text:String) -> void:
 for entry in app.rules.institutional_records:
  if entry.get("id","")==id:return
 app.rules.institutional_records.append({"id":id,"text":text,"source":"精神病院记录","attempt":app.rules.actual_attempt})
func damage(id:String,hp:int,sp:int) -> bool:
 if not claim(id,"asylum_damage",{"hp_damage":hp,"sp_damage":sp}):return false
 app.rules.hp=maxi(0,app.rules.hp-hp);app.rules.change_sp(-sp)
 app.audio.cue("hit","asylum:%d:%s"%[app.rules.actual_attempt,id])
 if hp>0:app.rules.vitality_lost.emit()
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 if records!=null:records.cancel_read("hurt")
 if trace_events!=null:trace_events.cancel_read()
 if observations!=null:observations.cancel()
 cancel_registration_followup("hurt")
 if app.has_method("cancel_asylum_read"):app.cancel_asylum_read()
 if not app.rules.pending_neural.is_empty():
  app.rules.settled[app.rules.pending_neural.event_id]="interrupted"
  app.rules.pending_neural.clear();app.rules.pending_skin.clear()
 if app.rules.hp>0 and app.rules.hurt_left<=0:app.rules.hurt_left=0.25
 return true
func can_begin_grip() -> bool:
 return str(data.holder).is_empty() and not app.rules.body_busy() and float(data.regrab_elapsed)>=0.8
func set_body(kind:String,id:String) -> void:
 if not data.body.is_empty():return
 if observations!=null:observations.cancel()
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 app.action_phase="autonomy";app.hero_state="give"
 data.body={"kind":kind,"actor":id,"elapsed":0.0,"delay":0.0}
func clear_body() -> void:
 data.body={}
 if str(data.holder).is_empty():app.rules.gripped=false
func blocks_hero() -> bool:
 return enabled and not data.is_empty() and (not data.body.is_empty() or not str(data.holder).is_empty() or float(data.medicine_stop)>0 or (records!=null and records.blocks_hero()) or (trace_events!=null and trace_events.blocks_hero()) or (isolation!=null and isolation.blocks_hero()) or (observations!=null and observations.blocks_hero()))
func eligible() -> bool:
 return not app.has_key() and app.rules.sp>=50 and not app.rules.search_active and app.action_phase=="autonomy" and not app.rules.body_busy() and not app.rules.gripped and app.rules.control_left<=0 and not blocks_hero()
func approach_contact(id:String,delta:float) -> bool:
 if not near(id,0.65):
  if not present(id) or str(actor(id).room)!=app.room_id:return false
  move(id,app.hero_pos,delta)
 return near(id,0.65)

func on_enter(from:String,room:String) -> void:
 if not enabled or app.session.data.level!=3:return
 if data.is_empty():start_attempt()
 if not from.is_empty():data.room_left[from]=float(data.clock)
 if from!=room:
  if records!=null:records.cancel_read("room_left")
  if trace_events!=null:trace_events.cancel_read()
  if observations!=null:observations.cancel()
  cancel_registration_followup("room_left")
  data.erase("read_route")
 if from!=room and not data.body.is_empty():
  var kind:String=str(data.body.kind)
  if kind in ["wrist_check","wrist_reach","wrist_hold"]:finish_wrist(false)
  elif not kind.begins_with("ward_"):clear_body()
 if from!=room and not data.exam.is_empty():finish_exam()
 for group in config.groups:
  var home:String=str(config.rooms[config.groups[group][0]])
  if home!=room and not (group=="pharmacy" and room=="corridor"):continue
  var state:Dictionary=data.groups[group]
  if state.drawn or int(state.checks)>=3:continue
  if int(state.checks)>0:
   if group=="pharmacy":
    var prior:float=float(state.get("last_check_clock",data.room_left.get("pharmacy",data.room_left.get("corridor",0.0))))
    if float(data.clock)-prior<float(config.timing.return_check):continue
   elif not data.room_left.has(room) or float(data.clock)-float(data.room_left[room])<float(config.timing.return_check):continue
  var chance:float=(0.35 if group=="patient" else 0.5)+0.05*mini(app.rules.actual_attempt-1,4)
  if int(state.checks)>0:chance*=0.5
  state.checks+=1
  state.last_check_clock=float(data.clock)
  if app.rng.randf()<chance:state.drawn=true;state.pending=true

func spawn_pending() -> void:
 for group in config.groups:
  var state:Dictionary=data.groups[group]
  if not state.pending:continue
  var room:String=str(config.rooms[config.groups[group][0]])
  # Reused upstairs nurse shares the original pharmacy roll. Its linked pair
  # enters at the original pharmacy doorway even if that floor is offscreen;
  # the one nurse must then traverse actual rooms/stairs to report for duty.
  if (room!=app.room_id and group!="pharmacy") or float(data.clock)-float(data.batches.get(room,-100))<float(config.timing.spawn_batch):continue
  var doors:Array=Map.doors(room)
  if doors.is_empty():continue
  var entry:Vector2=Map.doorway(room,"double_ward" if group=="transport" else str(doors[0]))
  var floor_layout=layout_for(room)
  if not floor_layout.walkable(entry):continue
  var slots:Array[Vector2]=[]
  for offset in [0.0,-0.5,0.5,-1.0,1.0]:
   var at:Vector2=entry+Vector2(float(offset),0)
   if not floor_layout.walkable(at) or (room==app.room_id and app.hero_pos.distance_to(at)<0.5):continue
   if at.distance_to(entry)>0.001 and floor_layout.path(entry,at).is_empty():continue
   var free:bool=true
   for id in data.actors:
    if present(id) and str(actor(id).room)==room and position(id).distance_to(at)<0.5:free=false
   if not free:continue
   slots.append(at)
   if slots.size()==config.groups[group].size():break
  if slots.size()<config.groups[group].size():continue
  for index in range(config.groups[group].size()):
   var id:String=str(config.groups[group][index]);var a:Dictionary=actor(id)
   # A reused actor retains the one entity and cannot respawn upstairs.
   if a.phase!="absent":continue
   a.phase="idle";a.room=config.rooms[id];a.pos=xy(slots[index]);a.route=[]
  state.pending=false;data.batches[room]=data.clock

func tick(delta:float) -> void:
 if not enabled or app.session.data.level!=3:return
 if app.rules.hp<=0:release_all();return
 if data.is_empty():start_attempt()
 data.clock+=delta;spawn_pending()
 advance_pharmacy_stand(delta)
 data.regrab_elapsed=0.0 if app.rules.body_busy() or app.rules.gripped else float(data.regrab_elapsed)+delta
 var medicine_before:float=float(data.medicine_stop)
 data.medicine_stop=maxf(0,medicine_before-delta);app.rules.effects.MEDICINE=medicine_before
 # Ward contacts and actual assistant/wrist harm precede benign paperwork.
 if ward_events!=null:ward_events.tick(delta)
 if app.rules.hp<=0:release_all();return
 if not app.dialogue_queue.is_empty():return
 if records!=null:records.tick(delta)
 if app.rules.hp<=0:release_all();return
 if not app.dialogue_queue.is_empty():return
 if trace_events!=null:trace_events.tick(delta)
 if app.rules.hp<=0:release_all();return
 if not app.dialogue_queue.is_empty():return
 if isolation!=null:isolation.tick(delta)
 if app.rules.hp<=0:release_all();return
 if not app.dialogue_queue.is_empty():return
 advance_exam(delta)
 if app.rules.hp<=0:release_all();return
 if not app.dialogue_queue.is_empty():return
 advance_body(delta)
 if not app.dialogue_queue.is_empty():return
 advance_false_record(delta)
 if not app.dialogue_queue.is_empty():return
 if nurse_duty!=null:nurse_duty.tick(delta)
 if not app.dialogue_queue.is_empty():return
 advance_registration_reply()
 if observations!=null:observations.tick(delta)
 if not app.dialogue_queue.is_empty():return
 if eligible():
  var suspended:Dictionary=data.get("suspended_body",{})
  if not suspended.is_empty() and near(str(suspended.actor)) and not data.refused and not data.swallowed:
   data.body=suspended.duplicate(true);data.suspended_body={};return
  if app.room_id=="ward" and near("ordinary_orderly") and not data.wrist_done and not data.get("staff_targets",{}).has("ordinary_orderly") and not app.action_phase in ["resting","return_bed"]:
   set_body("wrist_check","ordinary_orderly");say("WRIST");return
  if near("registration_nurse") and not data.registered:
   set_body("registration","registration_nurse");return
  if near("registration_nurse") and data.registered and not registration_state().auto_started:
   if begin_registration_followup(false):return
  if near("doctor") and not data.diagnosed:
   set_body("diagnosis","doctor");data.diagnosis_basis=evidence_basis();say("DOCTOR_"+str(data.diagnosis_basis).to_upper())
   if app.room_id=="clinic" and app.hero_pos.distance_to(app.layout.furniture[3].at)<1.2 and present("assistant"):
    data.exam={"phase":"approach","elapsed":0.0,"evaded":false}
   return
  if near("pharmacist") and valid_order() and not data.dispensed and not data.refused and not data.swallowed:
   set_body("order_receive","pharmacist");say("PHARMACY");return

func advance_pharmacy_stand(delta:float) -> void:
 # Enter as a linked batch, then actually clear the pharmacy's sole doorway.
 # This also leaves the one upstairs nurse a physical passage to the stairs.
 if not present("pharmacist") or str(actor("pharmacist").room)!="pharmacy" or actor("pharmacist").get("work_stand_done",false):return
 if data.body.get("actor","")=="pharmacist" or data.get("staff_targets",{}).has("pharmacist"):return
 var at:Vector2=layout_for("pharmacy").furniture[0].at
 var arrived:bool=ward_events.bed_move("pharmacist",at,delta,["pharmacist"]) if ward_events!=null else move("pharmacist",at,delta)
 if arrived:actor("pharmacist").work_stand_done=true

func registration_state() -> Dictionary:
 if not data.has("registration_state"):
  var prior_reply:bool=false
  for suffix in ["REGISTER_RECORD","REGISTER_WITNESS"]:
   if data.get("receipts",{}).has("asylum:%d:line:%s"%[app.rules.actual_attempt,suffix]):prior_reply=true
  data.registration_state={"reply_pending":bool(data.get("registered",false) and data.get("departure_page",false) and prior_reply),"reply_received":false,"auto_started":false,"asked":false,"written":false,"read":false,"phase":"idle","last_interrupt":""}
 return data.registration_state

func advance_registration_reply() -> void:
 var event:Dictionary=registration_state()
 if event.reply_pending and app.dialogue_queue.is_empty():
  event.reply_pending=false;event.reply_received=true
  claim("registration_reply_received","asylum_registration_reply_received",{"actual_departure_copy":true})

func registration_body_free(controlled:bool) -> bool:
 if not enabled or data.is_empty() or app.session.data.level!=3 or app.room_id!="lobby" or app.rules.hp<=0:return false
 if app.rules.loading or app.rules.transitioning or app.rules.absent or app.rules.body_busy() or app.rules.gripped or not str(data.holder).is_empty() or not data.body.is_empty() or app.rules.search_active or not app.dialogue_queue.is_empty():return false
 if controlled and app.rules.control_left<=0:return false
 if not controlled and (app.rules.control_left>0 or app.has_key() or app.rules.sp<50 or app.action_phase in ["return_bed","resting"]):return false
 if records!=null and records.blocks_hero():return false
 if trace_events!=null and trace_events.blocks_hero():return false
 if observations!=null and observations.blocks_hero():return false
 return present("registration_nurse") and str(actor("registration_nurse").room)=="lobby" and not data.get("staff_targets",{}).has("registration_nurse")

func registration_interaction(controlled:bool=true) -> Dictionary:
 if not registration_body_free(controlled):return {}
 advance_registration_reply()
 var event:Dictionary=registration_state()
 if not event.reply_received or not data.get("departure_page",false) or event.read:return {}
 return {"id":"asylum_registration_followup","kind":"registration_followup","label":"查看追问记录" if event.written else "再次追问去向","pos":xy(position("registration_nurse")),"record_written":bool(event.written)}

func begin_registration_followup(controlled:bool=false) -> bool:
 if registration_interaction(controlled).is_empty() or not near("registration_nurse",1.2):return false
 var event:Dictionary=registration_state()
 if not controlled:event.auto_started=true
 set_body("registration_followup","registration_nurse")
 if data.body.get("kind","")!="registration_followup":return false
 data.body.phase="approach";data.body.controlled=controlled
 event.phase="approach";event.last_interrupt=""
 var origin:String="controlled" if controlled else "autonomous"
 if not app.rules.public_action.is_empty():app.rules.finish_public_action(str(app.rules.public_action.get("origin",origin)))
 app.rules.begin_public_action("observe" if event.written else "talk","asylum_registration_followup",origin,"lobby")
 return true

func registration_fragment(part:String) -> void:
 if not claim("registration_line:"+part,"asylum_dialogue"):return
 var indices:Array=config.registration_followup.question_indices if part=="question" else config.registration_followup.read_indices
 for index in indices:
  var line:Dictionary=config.dialogue.REGISTER_FOLLOWUP[int(index)]
  app.add_dialogue(str(line.speaker),str(line.text))

func cancel_registration_followup(reason:String="interrupted") -> void:
 if data.is_empty() or data.get("body",{}).get("kind","")!="registration_followup":return
 var event:Dictionary=registration_state()
 event.phase="idle";event.last_interrupt=reason
 if app.rules.public_action.get("target","")=="asylum_registration_followup":app.rules.finish_public_action(str(app.rules.public_action.get("origin","autonomous")))
 clear_body()

func cancel_registration_interaction() -> void:
 # Root's new valid world command calls this through cancel_asylum_read.
 # Do not call that helper back from here (it would recurse).
 cancel_registration_followup("new_action")

func advance_registration_followup(delta:float) -> void:
 var event:Dictionary=registration_state();var body:Dictionary=data.body
 if app.room_id!="lobby" or not present("registration_nurse") or str(actor("registration_nurse").room)!="lobby" or app.rules.gripped or app.rules.body_busy() or (body.get("controlled",false) and app.rules.control_left<=0):cancel_registration_followup("lost_interaction");return
 if body.phase=="approach":
  if not approach_contact("registration_nurse",delta):return
  body.phase="read" if event.written else "write";body.elapsed=0.0;event.phase=body.phase
  if not event.asked:
   event.asked=true;claim("registration_question","asylum_registration_followup_asked",{"target":"registration_nurse","after_actual_reply":true})
   registration_fragment("question")
   if body.get("controlled",false):app.rules.controlled_execution("talk","registration_nurse")
  return
 if not near("registration_nurse",0.65):cancel_registration_followup("lost_contact");return
 var window:float=minf(delta,app.rules.control_left) if body.get("controlled",false) else delta
 body.elapsed+=window
 if body.phase=="write":
  if float(body.elapsed)+0.000001<float(config.registration_followup.write_seconds):return
  if claim("registration_followup_written","asylum_registration_followup_written",{"target":"hero","label":"反复纠缠","after_actual_question":true}):
   record("asylum_registration_followup:"+str(app.rules.actual_attempt),"登记护士在得到答复后的再次追问发生后，实际写入：反复纠缠。未给出去向，不据此生成伤害、攻击或抓捕。")
   app.rules.owners.asylum_registration_followup="registration_nurse"
   event.written=true;event.record_room="lobby";event.record_pos=xy(position("registration_nurse"))
  body.phase="read";body.elapsed=0.0;event.phase="read"
  return
 if body.phase=="read":
  if float(body.elapsed)+0.000001<float(config.registration_followup.read_seconds):return
  if not event.written or app.rules.owners.get("asylum_registration_followup","")!="registration_nurse":cancel_registration_followup("record_unavailable");return
  if claim("registration_followup_read","asylum_registration_followup_read",{"record":"asylum_registration_followup"}):
   event.read=true;observe("asylum_registration_accusation_seen","实际看清登记护士把追问患者去向写为反复纠缠；机构标签不替代原提问和真实事件。")
   registration_fragment("read")
   if body.get("controlled",false):app.rules.controlled_execution("observe","asylum_registration_followup")
  cancel_registration_followup("completed");event.phase="done"

func evidence_basis() -> String:
 if "hospital_case_link" in app.rules.known:return "case"
 if "false_medicine_seen" in app.rules.known:return "false"
 if "forced_transfer_seen" in app.rules.known:return "transfer"
 for key in ["bed_card_old","uniform_label","hospital_cup_number","hospital_ticket_back"]:
  if key in app.rules.known:return "partial"
 return "none"

func valid_order() -> bool:
 var source:String=str(data.order_source)
 return not source.is_empty() and data.order_delivered and app.rules.owners.get(source,"")=="hero"

func advance_body(delta:float) -> void:
 if data.body.is_empty():return
 var body:Dictionary=data.body;var kind:String=str(body.kind);var who:String=str(body.actor)
 if kind=="registration_followup":advance_registration_followup(delta);return
 if not kind in ["wrist_check","wrist_reach","wrist_hold","registration","diagnosis","medical_order_write","order_transfer","order_receive","mix","cup_transfer","raise_cup"]:return
 if not present(who) or str(actor(who).room)!=app.room_id:
  if kind in ["wrist_check","wrist_reach","wrist_hold"]:finish_wrist(false)
  else:clear_body()
  return
 if kind=="wrist_hold":
  body.elapsed+=delta
  if float(body.elapsed)>=float(config.timing.wrist_max):finish_wrist(true)
  return
 if kind=="wrist_reach":
  body.elapsed+=delta
  if float(body.elapsed)<float(config.test_parameters.grab_prepare):return
  if body.get("evaded",false) or not near(who,0.65):finish_wrist(false);return
  if not can_begin_grip():return
  if not claim("wrist_grip","asylum_wrist_grip"):finish_wrist(false);return
  data.holder=who;app.rules.gripped=true;body.kind="wrist_hold";body.elapsed=0.0
  if damage("wrist_twist",int(config.values.wrist_hp),int(config.values.wrist_sp)):
   observe("asylum_wrist_hurt","护工实际抓住并扭转手腕；正常核号与本次伤情分开。")
  if app.rules.hp>0:say("WRIST_HURT")
  return
 if not approach_contact(who,delta):return
 if app.rules.body_busy() or app.rules.control_left>0:return
 body.elapsed+=delta
 var handoff:float=float(config.test_parameters.handoff)+float(body.delay)
 match kind:
  "wrist_check":
   if float(body.elapsed)>=handoff:finish_wrist(true)
  "registration":
   if float(body.elapsed)<float(config.test_parameters.paperwork)+float(body.delay):return
   data.registered=true
   var carry:Dictionary=data.carry
   if carry.get("wheelchair_gone",false):
    data.departure_page=true
    record("asylum_departure_copy:"+str(app.rules.actual_attempt),"前关对应患者离院单副本：自行离院。源为医院纸面记录；真实强制转运另账。")
    # Matching cannot be inferred from null glyphs or a generic witness flag.
    var matched:bool="wheelchair_identity_confirmed" in app.rules.known
    if matched and "forced_transfer_seen" in app.rules.known:say("REGISTER_WITNESS")
    else:say("REGISTER_RECORD")
    registration_state().reply_pending=true
   clear_body()
  "diagnosis":
   if float(body.elapsed)<float(config.test_parameters.paperwork)+float(body.delay):return
   data.diagnosed=true
   record("asylum_diagnosis:"+str(app.rules.actual_attempt),"症状栏转记本次陈述；依据："+str(data.diagnosis_basis)+"。这是机构诊断，不删改已知事实；未读表不自动知道诊断内容。")
   claim("diagnosis","asylum_diagnosis_written",{"basis":str(data.diagnosis_basis)})
   body.kind="medical_order_write";body.elapsed=0.0;body.delay=0.0
  "medical_order_write":
   if float(body.elapsed)<float(config.test_parameters.paperwork):return
   if not data.order_delivered and not data.refused and not data.swallowed:
    data.order_written=true;data.order_source="asylum_medical_order";app.rules.owners.asylum_medical_order="doctor"
    record("asylum_order:"+str(app.rules.actual_attempt),"精神科医生本次实际填写并签发的给药医嘱；与诊断落笔分别记账。")
    claim("order_written","asylum_medical_order_written")
    body.kind="order_transfer";body.elapsed=0.0;body.delay=0.0
   else:clear_body()
  "order_transfer":
   if float(body.elapsed)>=handoff:
    if app.rules.owners.get("asylum_medical_order","")!="doctor":clear_body();return
    app.rules.owners.asylum_medical_order="hero";data.order_delivered=true
    claim("order_received","asylum_medical_order_delivered");clear_body()
  "order_receive":
   if float(body.elapsed)>=handoff:
    if not valid_order():clear_body();return
    app.rules.owners[str(data.order_source)]="asylum_pharmacist";data.dispensed=true
    claim("order_to_pharmacist","asylum_order_received",{"order":str(data.order_source)})
    body.kind="mix";body.elapsed=0.0;body.delay=0.0
  "mix":
   if float(body.elapsed)>=float(config.test_parameters.mix):
    app.rules.owners.asylum_cup="asylum_pharmacist";data.cup_full=true;body.kind="cup_transfer";body.elapsed=0.0;body.delay=0.0
  "cup_transfer":
   if float(body.elapsed)>=handoff:
    if app.rules.owners.get("asylum_cup","")!="asylum_pharmacist":clear_body();return
    app.rules.owners.asylum_cup="hero";data.nurse_cup_witness=near("med_nurse",2.0);claim("cup_received","asylum_cup_received")
    if "medicine_harm" in app.rules.known or "false_medicine_seen" in app.rules.known or "asylum_medicine_harm" in app.rules.known or "asylum_false_medicine_seen" in app.rules.known:refuse_medicine()
    else:body.kind="raise_cup";body.elapsed=0.0;body.delay=0.0
  "raise_cup":
   data.nurse_cup_witness=bool(data.get("nurse_cup_witness",false)) and near("med_nurse",2.0)
   if float(body.elapsed)+0.000001<float(config.timing.cup_raise):return
   if app.rules.owners.get("asylum_cup","")!="hero" or not data.cup_full:clear_body();return
   if claim("swallow","asylum_medicine_swallowed",{"sp_damage":int(config.values.medicine_sp)}):
    data.swallowed=true;data.cup_full=false;data.medicine_stop=float(config.timing.medicine_stop)
    app.rules.change_sp(-int(config.values.medicine_sp));app.rules.effects.MEDICINE=float(config.timing.medicine_stop)+delta
    observe("asylum_medicine_harm","实际吞服本关编号药液后精神降低20并停顿1.5秒；医嘱、纸面已服与吞服事实分开。")
    record("asylum_medicine:"+str(app.rules.actual_attempt),"药师：实际吞服完成。")
    if nurse_duty!=null:nurse_duty.on_swallow(bool(data.nurse_cup_witness))
   clear_body()

func finish_wrist(success:bool) -> void:
 data.wrist_done=true;data.wrist_checked=success
 if success:record("asylum_wrist_check:"+str(app.rules.actual_attempt),"本次腕带核对实际完成；不补造旧姓名字形。")
 claim("wrist_end","asylum_wrist_check_ended",{"completed":success})
 if str(data.holder)=="ordinary_orderly":data.holder="";app.rules.gripped=false;data.regrab_elapsed=0.0
 if data.body.get("kind","") in ["wrist_check","wrist_reach","wrist_hold"]:clear_body()

func advance_exam(delta:float) -> void:
 if data.exam.is_empty():return
 var event:Dictionary=data.exam
 if not present("assistant") or not present("doctor") or str(actor("assistant").room)!=app.room_id or str(actor("doctor").room)!=app.room_id or app.room_id!="clinic":finish_exam();return
 event.elapsed+=delta
 if event.phase=="approach":
  if app.has_key() or app.rules.control_left>0 or app.action_phase in ["resting","return_bed"]:finish_exam();return
  if app.hero_pos.distance_to(app.layout.furniture[3].at)>1.2:finish_exam();return
  if not approach_contact("assistant",delta) or not can_begin_grip():return
  event.phase="reach";event.prepare=0.0;say("ASSIST_REACH");return
 if event.phase=="reach":
  event.prepare+=delta
  if float(event.prepare)<float(config.test_parameters.grab_prepare):return
  if event.evaded or not near("assistant",0.65):finish_exam();return
  if not can_begin_grip():return
  if not claim("assistant_grip","asylum_assistant_grip"):finish_exam();return
  data.holder="assistant";app.rules.gripped=true;event.phase="hold";event.held=0.0
  damage("assistant_tighten",int(config.values.assistant_hp),0)
  if app.rules.hp>0:say("ASSIST_HOLD")
 elif event.phase=="hold":
  event.held+=delta
  if float(event.held)>=float(config.timing.assistant_max) or data.diagnosed:finish_exam()

func finish_exam() -> void:
 if str(data.holder)=="assistant":
  data.holder="";app.rules.gripped=false;data.regrab_elapsed=0.0
  claim("assistant_release","asylum_assistant_released")
 data.exam={}

func release_all() -> void:
 cancel_registration_followup("death")
 data.holder="";app.rules.gripped=false;data.body={};data.exam={}
 if records!=null:records.cancel_read("death")
 if trace_events!=null:trace_events.cancel_read()
 if observations!=null:observations.cancel()
 if isolation!=null:
  isolation.abort("death")
  if app.rules.hp<=0:isolation.finish("death")

func refuse_medicine() -> void:
 if data.swallowed or data.refused or app.rules.owners.get("asylum_cup","")!="hero":return
 data.refused=true;app.rules.owners.asylum_cup="asylum_counter"
 data.cup_place={"room":app.room_id,"pos":xy(app.hero_pos)}
 claim("refuse_medicine","asylum_medicine_refused")
 record("asylum_refusal:"+str(app.rules.actual_attempt),"药师在原杯放回后登记本次明确拒服；实际未吞服。")
 clear_body();say("REFUSE")
 if near("med_nurse",2.0):data.false_record={"room":app.room_id,"pos":xy(app.hero_pos),"left":float(config.test_parameters.paperwork),"witness_complete":true}

func advance_false_record(delta:float) -> void:
 if not data.has("false_record") or not present("med_nurse"):return
 var event:Dictionary=data.false_record
 var room:String=str(event.room)
 var at:Vector2=Vector2(float(event.pos[0]),float(event.pos[1]))
 event.witness_complete=bool(event.witness_complete) and app.room_id==room and near("med_nurse",2.0) and layout_for(room).clear_segment(app.hero_pos,at)
 if str(actor("med_nurse").room)!=room:
  travel("med_nurse",room,delta);return
 if not visible("med_nurse",at,room,0.65):move("med_nurse",at,delta);return
 if app.rules.owners.get("asylum_cup","")!="asylum_counter" or data.swallowed:return
 event.left-=delta
 if float(event.left)>0:return
 record("asylum_false_medicine:"+str(app.rules.actual_attempt),"给药护士：已服用（实际拒服；造假落笔后才形成）。")
 claim("false_medicine","asylum_false_medicine_written")
 var witnessed:bool=event.witness_complete
 data.erase("false_record")
 if witnessed:observe("asylum_false_medicine_seen","亲见给药护士在明确拒服后仍实际填写已服；完整目击与后来读表分开。" );say("FALSE_MEDICINE")

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false) or data.is_empty():return
 if str(result.get("id","")) in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:app.cancel_asylum_read()
 if str(result.get("id","")) in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  cancel_registration_followup("skill:"+str(result.get("id","")))
  if observations!=null:observations.cancel()
 if ward_events!=null:ward_events.on_skill(result)
 if records!=null:records.on_skill(result)
 if trace_events!=null:trace_events.on_skill(result)
 if isolation!=null:isolation.on_skill(result)
 var id:String=str(result.id)
 if id=="WITHDRAW":
  if data.body.get("kind","")=="wrist_check":
   data.body.kind="wrist_reach";data.body.elapsed=0.0;data.body.evaded=false
  elif data.body.get("kind","")=="wrist_reach":data.body.evaded=true
  if data.exam.get("phase","")=="reach":data.exam.evaded=true
 if id=="DRYMOUTH" and data.body.get("kind","") in ["wrist_check","registration","order_transfer","order_receive","cup_transfer"]:data.body.delay+=float(config.timing.drymouth)
 if id=="GUT" and app.rules.owners.get("asylum_cup","")=="hero" and not data.swallowed:
  refuse_medicine();return
 if id in ["SKIN","GUT","WITHDRAW","STARTLE","FEAR","CONTROL"] and data.body.get("kind","") in ["order_transfer","order_receive","cup_transfer","raise_cup"]:
  data.suspended_body=data.body.duplicate(true);clear_body()

func kick_contact() -> void:
 if ward_events!=null:ward_events.kick_contact()
 if records!=null:records.kick_contact()
 if trace_events!=null:trace_events.kick_contact()
 if isolation!=null:isolation.kick_contact()
 # Knee can hit only an actual in-range body; it never unlocks a closed cuff.
 for id in ["assistant","doctor","ordinary_orderly"]:
  if not near(id,1.0):continue
  var offset:Vector2=position(id)-app.hero_pos
  if app.rules.kick_contact("asylum_"+id,offset.length(),offset.normalized().dot(app.hero_facing)>0.35,app.layout.clear_segment(app.hero_pos,position(id))):
   claim("kick:"+id,"asylum_staff_kicked",{"target":id})
   if near("doctor",2.0) or near("assistant",2.0):record("asylum_attack:"+str(app.rules.actual_attempt),"本次膝跳实际踢中工作人员："+str(config.names[id])+"；未触及腕扣。")

func on_search_complete(index:int,found_key:bool) -> void:
 if ward_events!=null:ward_events.on_search_complete(index,found_key)
 if records!=null:records.on_search_complete(index,found_key)
 if trace_events!=null:trace_events.on_search_complete(index,found_key)

func actors() -> Array:
 var result:Array=[]
 if not enabled or data.is_empty() or app.session.data.level!=3:return result
 for id in data.actors:
  if present(id) and str(actor(id).room)==app.room_id:result.append({"type":"actor","data":"asylum_"+str(id),"depth":app.layout.project(position(id)).y})
 return result
