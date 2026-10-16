extends RefCounted
## B4 upper floor. Source: S3:P1166–1284, S4:T17; R10 action/witness fixes.
## Parent owns movement/read input; this module owns saved causal event state.
var _owner:WeakRef
var owner:
 get:return _owner.get_ref()
var config:Dictionary={}

func _init(events) -> void:
 _owner=weakref(events)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/cortex_upper_events.json"))

func state() -> Dictionary:
 if not owner.data.has("upper_state"):owner.data.upper_state={}
 var result:Dictionary=owner.data.upper_state
 var defaults:Dictionary={
  "bridge":{"phase":"idle","elapsed":0.0,"source":{},"spoken":[],"heard":[],"playback":0},
  "rhythm":{"phase":"gap","elapsed":0.0,"count":0,"direction":1,"from":[],"to":[],"waiting":false,"wait_cycle":-1,"bypass":false},
  "index":{"phase":"idle","elapsed":0.0,"attempted":false,"open":false,"seen_start":false,"seen_removed":false},
  "switch":{"phase":"idle","elapsed":0.0,"attempted":false,"steps":[],"route":[],"await_landmark":false},
  "face":{"phase":"idle","elapsed":0.0,"attempted":false,"contact":false,"had_body":false},
  "identity":{"phase":"idle","elapsed":0.0,"turn_started":false,"front":false,"back":false,"left_result":false,"right_result":false}}
 for key in defaults:
  if not result.has(key):result[key]=defaults[key].duplicate(true)
 persistent()
 return result

func persistent() -> Dictionary:
 if not owner.app.session.data.has("cortex_upper_persistent"):
  owner.app.session.data.cortex_upper_persistent={"losses":{},"identity_read":{},"route_known":false,"index_removed":false,"index_holder":"index_slot","bridge_heard":{},"fields":{}}
 return owner.app.session.data.cortex_upper_persistent

func vector(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func stage(event:Dictionary,phase:String) -> void:event.phase=phase;event.elapsed=0.0
func elapsed(event:Dictionary,delta:float,seconds:float) -> bool:
 event.elapsed=float(event.get("elapsed",0.0))+delta
 return float(event.elapsed)+0.000001>=seconds
func active() -> bool:return owner!=null and owner.enabled and not owner.data.is_empty() and int(owner.app.session.data.level)==4 and not owner.app.session.data.get("cortex_exit_crossed",false)
func line(key:String) -> void:
 if not owner.claim("upper_line:"+key,"cortex_dialogue"):return
 for entry in config.dialogue.get(key,[]):owner.app.add_dialogue(str(entry.speaker),str(entry.text))
func pose(id:String,value:String) -> void:
 if owner.present(id):owner.actor(id).action=value
func point(room:String,index:int) -> Vector2:
 var furniture:Array=owner.layout_for(room).furniture
 return furniture[index].at if index>=0 and index<furniture.size() else Vector2.ZERO
func read_field(key:String,value:Dictionary) -> void:
 persistent().fields[key]=value.duplicate(true)
 owner.observe(key,JSON.stringify(value))
func loss_once(id:String,amount:int,details:Dictionary={}) -> bool:
 var ledger:Dictionary=persistent().losses
 if ledger.has(id) or owner.app.rules.hp<=0:return false
 ledger[id]={"sp":amount,"details":details.duplicate(true)}
 owner.app.rules.change_sp(-amount)
 owner.app.rules._record("cortex_conflict_loss",id,{"sp_damage":amount,"source":details})
 return true

func observation_defs() -> Array:
 return config.observations.duplicate(true)

func observation_available(id:String) -> bool:
 if not active():return false
 match id:
  "cortex_bridge_listen":return owner.present("dual_head") and not source_material().is_empty()
  "cortex_identity_faces":return owner.present("double_face")
  "cortex_switch_landmark":return bool(state().switch.await_landmark)
 return true

func observation_revision(id:String) -> String:
 match id:
  "cortex_bridge_listen","cortex_bridge_left","cortex_bridge_right":return str(source_material().get("id","unavailable"))
  "cortex_index_query","cortex_index_number":return "removed" if persistent().index_removed else "present"
  "cortex_switch_landmark":return str(state().switch.await_landmark)
  "cortex_identity_faces":return "back" if persistent().identity_read.get("back",false) else "front"
 return "1"

func on_observation(id:String,_fields:Dictionary={}) -> void:
 if not active() or owner.app.rules.hp<=0:return
 var value:Dictionary=state()
 match id:
  "cortex_bridge_listen":begin_bridge()
  "cortex_bridge_left","cortex_bridge_right":
   var material:Dictionary=source_material()
   read_field(id,{"material":material,"side":"true" if id.ends_with("left") else "institutional","heard":false})
  "cortex_index_original":
   value.index.open=true
   read_field(id,{"original_present":true,"name":null,"body_number":null,"billing_number":null,"source":"S3:P1201–1215"})
   if not value.index.attempted and not persistent().index_removed and owner.actor_sees("faceless",owner.app.hero_pos,"index",2.5):
    value.index.attempted=true;value.index.seen_start=owner.hero_sees("faceless",2.5)
    owner.actor("faceless").stand_done=true
    stage(value.index,"approach");pose("faceless","approach_label")
    owner.claim("index_start","cortex_index_attempt")
  "cortex_index_query":
   read_field(id,{"result":"查无此人" if persistent().index_removed else "姓名索引仍在","actual_name":null,"source":"S3:P1202"})
   if persistent().index_removed and value.index.seen_removed:line("INDEX_REMOVED")
  "cortex_index_number":
   read_field(id,{"original_present":true,"body_number":null,"linkage_verified":false})
   if persistent().index_removed:line("INDEX_ORIGINAL")
  "cortex_index_billing":
   read_field(id,{"billing_intact":true,"billing_number":null,"amounts":null});line("INDEX_BILLING")
  "cortex_identity_left","cortex_identity_right":
   var side:String="left" if id.ends_with("left") else "right"
   persistent().identity_read[side]=true
   value.identity[side+"_result"]=true
   read_field(id,{"document_id":"identity_"+side,"status":"已注销" if side=="left" else "当前使用","match_result":"通过","number":null,"name":null,"same_face_group":"S3:P1261–1267","actual_identity_merged":false})
   if persistent().identity_read.get("left",false) and persistent().identity_read.get("right",false):line("IDENTITY_RECORDS")
   complete_identity()
  "cortex_identity_faces":
   if owner.near("double_face",2.5) and not value.identity.turn_started:
    owner.actor("double_face").stand_done=true
    value.identity.turn_started=true;value.identity.front=true
    persistent().identity_read.front=true
    stage(value.identity,"turn");pose("double_face","turn_front_to_back")
  "cortex_switch_landmark":
   if value.switch.await_landmark and owner.app.room_id=="switch" and value.switch.steps==["switch","bridge","index","switch"]:
    persistent().route_known=true;value.switch.await_landmark=false;stage(value.switch,"done")
    owner.claim("route_recognized","cortex_route_recognized",{"steps":value.switch.steps.duplicate()})
    owner.observe("cortex_route_known","实际沿分岔→胼胝桥→索引→原分岔返回并看清同一门框地纹。")
    line("ROUTE_RETURN")
  "cortex_exit_application":
   read_field(id,{"application":"本人申请","input_field":false});line("EXIT_APPLICATION")
  "cortex_exit_proxy":
   read_field(id,{"proxy_confirmation_stamped":true,"signer":null});line("EXIT_PROXY")
  "cortex_rhythm_counter":read_field(id,{"actual_twitches":int(value.rhythm.count),"hero_injury":false})

func source_material() -> Dictionary:
 # Select a genuine previous refusal and its actual false-writing receipt;
 # one source attempt is an event identity, not a freely combinable number.
 var injected:Dictionary=owner.data.get("materials",{}).get("bridge",{})
 if valid_material(injected):
  var material:Dictionary=injected.duplicate(true)
  material.true_text="拒绝服药。" if material.kind=="refusal" else "已经死亡。"
  material.false_text="已服用。" if material.kind=="refusal" else "已离院。"
  return material
 for fact in owner.app.rules.facts:
  if str(fact.get("kind",""))!="asylum_medicine_refused":continue
  var original:String=str(fact.get("event_id",""));var segments:PackedStringArray=original.split(":")
  if segments.size()<3:continue
  var attempt:String=str(int(float(segments[1])))
  var forged_id:String="asylum:"+attempt+":false_medicine"
  var forged:Dictionary={}
  for candidate in owner.app.rules.facts:
   if str(candidate.get("kind",""))=="asylum_false_medicine_written" and str(candidate.get("event_id",""))==forged_id:forged=candidate;break
  if forged.is_empty():continue
  var record:Dictionary={}
  for candidate in owner.app.rules.institutional_records:
   if str(candidate.get("id",""))=="asylum_false_medicine:"+attempt:record=candidate;break
  if record.is_empty():continue
  return {"id":original,"subject":"hero","number":null,"kind":"refusal","true_receipt":original,"false_receipt":forged_id,"record_id":str(record.id),"true_text":"拒绝服药。","false_text":"已服用。","source":"S3:T40R3 / actual L3 receipts","number_pending":true}
 return {}

func valid_material(material:Dictionary) -> bool:
 if material.is_empty() or str(material.get("id","" )).is_empty() or str(material.get("subject","" )).is_empty():return false
 var actual:String=str(material.get("true_receipt",""));var forged:String=str(material.get("false_receipt",""));var doc:String=str(material.get("record_id",""))
 if actual.is_empty() or forged.is_empty() or doc.is_empty():return false
 var a:Dictionary={};var b:Dictionary={};var document:Dictionary={}
 for fact in owner.app.rules.facts:
  if str(fact.get("event_id",""))==actual:a=fact
  if str(fact.get("event_id",""))==forged:b=fact
 for record in owner.app.rules.institutional_records:
  if str(record.get("id",""))==doc:document=record
 if a.is_empty() or b.is_empty() or document.is_empty():return false
 if material.get("kind","")=="refusal":
  return a.get("kind","")=="asylum_medicine_refused" and b.get("kind","")=="asylum_false_medicine_written" and actual.get_slice(":",1)==forged.get_slice(":",1) and doc=="asylum_false_medicine:"+actual.get_slice(":",1) and material.subject=="hero"
 if material.get("kind","")=="death":
  return a.get("kind","")=="confirmed_death" and b.get("kind","")=="false_departure_written" and a.get("subject",null)!=null and a.get("subject")==b.get("subject") and a.get("subject")==material.subject and a.get("source_event",null)!=null and a.get("source_event")==b.get("source_event") and a.get("source_event")==document.get("source_event")
 return false

func begin_bridge() -> bool:
 var event:Dictionary=state().bridge
 if not owner.near("dual_head",2.5) or event.phase not in ["idle","done","interrupted"]:return false
 var material:Dictionary=source_material()
 if material.is_empty():return false
 owner.actor("dual_head").stand_done=true
 event.source=material;event.spoken=[];event.heard=[];event.playback=int(event.playback)+1
 stage(event,"left_turn");pose("dual_head","left_turn")
 return true

func speak_bridge(side:String) -> void:
 var event:Dictionary=state().bridge
 if not owner.near("dual_head",2.5):stage(event,"interrupted");return
 var material:Dictionary=event.source
 var text:String=str(material.true_text if side=="left" else material.false_text)
 # Missing authored number stays explicitly unknown in the physical display;
 # never substitute the player's unrelated intruder number into a patient ID.
 if material.get("number",null)!=null:text=str(material.number)+"。"+text
 owner.app.add_dialogue("双头连体人 · "+("左头" if side=="left" else "右头"),text)
 var line_data:Dictionary=owner.app.dialogue_queue[-1]
 line_data.cortex_upper={"event_id":str(material.id),"side":side,"attempt":int(owner.app.rules.actual_attempt),"playback":int(event.playback)}
 event.spoken.append(side);stage(event,side+"_speaking");pose("dual_head",side+"_speaking")

func on_dialogue_advanced(line_data:Dictionary) -> void:
 if not active() or owner.app.rules.hp<=0 or not line_data.has("cortex_upper"):return
 var token:Dictionary=line_data.cortex_upper;var event:Dictionary=state().bridge
 if not owner.near("dual_head",2.5) or int(token.get("attempt",-1))!=int(owner.app.rules.actual_attempt) or int(token.get("playback",-1))!=int(event.playback):return
 if str(token.get("event_id",""))!=str(event.source.get("id","")):return
 var side:String=str(token.get("side",""))
 if side not in event.spoken or side in event.heard:return
 event.heard.append(side)
 var heard:Dictionary=persistent().bridge_heard
 if not heard.has(str(event.source.id)):heard[str(event.source.id)]=[]
 if not side in heard[str(event.source.id)]:heard[str(event.source.id)].append(side)
 read_field("cortex_bridge_heard_"+side,{"source_event":str(event.source.id),"side":side,"text":str(event.source.true_text if side=="left" else event.source.false_text)})
 stage(event,"right_turn" if side=="left" else "complete")

func tick(delta:float) -> void:
 if not active():return
 state()
 if owner.app.rules.hp<=0:
  release_face("death");cancel_route("death");return
 # Called only by the parent's campaign world clock, like the lower events.
 if owner.app.rules.loading or owner.app.rules.transitioning or not owner.app.dialogue_queue.is_empty():return
 advance_bridge(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_rhythm(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_index(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_switch(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_face(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_identity(delta)

func advance_bridge(delta:float) -> void:
 var event:Dictionary=state().bridge
 if event.phase in ["idle","done","interrupted"]:return
 if not owner.present("dual_head") or owner.app.room_id!="bridge":stage(event,"interrupted");return
 if event.phase in ["left_speaking","right_speaking"] and owner.app.dialogue_queue.is_empty():stage(event,"interrupted");return
 if event.phase in ["left_turn","right_turn"]:
  if elapsed(event,delta,float(config.presentation.turn_seconds)):speak_bridge("left" if event.phase=="left_turn" else "right")
 elif event.phase=="complete":
  if event.heard==["left","right"]:
   loss_once("bridge:"+str(event.source.id),10,event.source)
   owner.observe("cortex_bridge_conflict:"+str(event.source.id),"实际完整听到同一患者同一次事件的两种矛盾陈述；陈述不改写真实结果。")
   if event.source.get("number",null)!=null:line("BRIDGE_COMPLETE")
  stage(event,"done");pose("dual_head","idle_screens")

func advance_rhythm(delta:float) -> void:
 var event:Dictionary=state().rhythm
 if not owner.present("twitch"):
  event.waiting=false;return
 if owner.app.room_id!="rhythm":event.waiting=false
 var actor:Dictionary=owner.actor("twitch")
 if not actor.get("stand_done",false):return
 if event.from.is_empty():
  event.from=owner.xy(owner.position("twitch"));event.to=owner.xy(owner.position("twitch")+Vector2(0.0,1.5))
 if event.phase=="gap":
  pose("twitch","shoulder_twitch")
  if elapsed(event,delta,1.5):
   event.count=int(event.count)+1;stage(event,"crossing")
   actor.route=[]
 else:
  pose("twitch","feet_still_brace_pull")
  var target:Vector2=vector(event.to if int(event.direction)>0 else event.from)
  var origin:Vector2=vector(event.from if int(event.direction)>0 else event.to)
  event.elapsed=float(event.elapsed)+delta
  var proposed:Vector2=origin.lerp(target,minf(float(event.elapsed)/1.2,1.0))
  var at:Vector2=owner.position("twitch")
  var hero_blocks:bool=owner.app.room_id=="rhythm" and Geometry2D.get_closest_point_to_segment(owner.app.hero_pos,at,proposed).distance_to(owner.app.hero_pos)<0.42
  if not hero_blocks and owner.layout_for("rhythm").clear_segment(at,proposed):actor.pos=owner.xy(proposed)
  else:event.elapsed=maxf(0.0,float(event.elapsed)-delta)
  if owner.hero_sees("twitch",2.5):line("RHYTHM_PULL")
  if float(event.elapsed)+0.000001>=1.2:
   stage(event,"gap");event.direction=-int(event.direction);event.waiting=false

func movement_block(from:Vector2,to:Vector2) -> Dictionary:
 if not active() or owner.app.room_id!="rhythm" or not owner.present("twitch"):return {}
 var at:Vector2=owner.position("twitch")
 if Geometry2D.get_closest_point_to_segment(at,from,to).distance_to(at)>=0.42:return {}
 var event:Dictionary=state().rhythm
 if event.phase=="crossing" and int(event.wait_cycle)!=int(event.count):
  event.waiting=true;event.wait_cycle=int(event.count);return {"wait":true,"body":at}
 event.waiting=false;event.bypass=true
 return {"wait":false,"body":at,"bypass":true}

func advance_index(delta:float) -> void:
 var event:Dictionary=state().index
 owner.app.rules.owners.cortex_name_label=str(persistent().index_holder)
 if event.phase in ["idle","done","interrupted"]:return
 if not owner.present("faceless") or str(owner.actor("faceless").room)!="index":stage(event,"interrupted");return
 if event.phase in ["approach","pinch","extract"]:event.seen_start=bool(event.seen_start) and owner.hero_sees("faceless",2.5)
 if event.phase=="approach":
  var target:Vector2=point("index",3)
  if owner.move("faceless",target,delta):stage(event,"pinch");pose("faceless","pinch_name_label")
 elif event.phase=="pinch":
  if elapsed(event,delta,float(config.presentation.prepare_seconds)):stage(event,"extract");pose("faceless","extract_name_label")
 elif event.phase=="extract":
  if elapsed(event,delta,1.0):
   if not persistent().index_removed:
    persistent().index_removed=true;persistent().index_holder="faceless"
    owner.app.rules.owners.cortex_name_label="faceless"
    event.seen_removed=event.seen_start and owner.hero_sees("faceless",2.5)
    owner.claim("index_removed","cortex_name_label_extracted",{"holder":"faceless","query":"查无此人","name":null,"body_number":null,"billing_number":null})
   stage(event,"put_away");pose("faceless","put_label_inside_clothing")
 elif event.phase=="put_away" and elapsed(event,delta,float(config.presentation.finish_seconds)):
  stage(event,"retreat");pose("faceless","return_to_cabinet")
 elif event.phase=="retreat":
  if owner.move("faceless",owner.beside("index",point("index",2)),delta):stage(event,"done");pose("faceless","idle_cabinet")

func advance_switch(delta:float) -> void:
 var event:Dictionary=state().switch
 if event.phase in ["done","cancelled","route"]:return
 if not owner.near("reverse",2.4):return
 if event.phase=="idle" and not event.attempted and owner.eligible():
  if not owner.hero_sees("reverse",2.4):return
  event.attempted=true;owner.actor("reverse").stand_done=true
  stage(event,"point");pose("reverse","point_to_bridge");return
 if event.phase=="point" and elapsed(event,delta,float(config.presentation.point_seconds)):
  if not owner.hero_sees("reverse",2.4) or owner.app.has_key():stage(event,"done");return
  line("ROUTE_POINT")
  var reliable:bool=owner.app.session.data.get("rooms",{}).has("verify") or "cortex_exit_route" in owner.app.rules.known
  if persistent().route_known or reliable:
   stage(event,"done")
   if persistent().route_known:line("ROUTE_KNOWN")
   return
  event.steps=["switch"];event.route=["bridge","index","switch"]
  stage(event,"route")
  owner.app.hero_route=PackedVector2Array();owner.app.target_index=-1
  owner.app.rules.cancel_search();owner.app.action_phase="autonomy"
  owner.claim("route_start","cortex_false_route_started")

func forced_route_target() -> String:
 if not active():return ""
 var event:Dictionary=state().switch
 if event.phase!="route" or event.route.is_empty():return ""
 return str(event.route[0])

func cancel_route(reason:String) -> void:
 if owner.data.is_empty():return
 var event:Dictionary=state().switch
 if event.phase=="route":
  stage(event,"cancelled");event.route=[];event.await_landmark=false
  owner.claim("route_cancel","cortex_false_route_interrupted",{"reason":reason,"steps":event.steps.duplicate()})

func on_enter(from:String,room:String) -> void:
 if not active():return
 var value:Dictionary=state()
 value.rhythm.waiting=false
 if value.bridge.phase not in ["idle","done"] and room!="bridge":stage(value.bridge,"interrupted")
 if value.face.phase not in ["idle","done"] and room!="verify":release_face("room_left")
 var event:Dictionary=value.switch
 if event.phase=="route":
  if not event.route.is_empty() and room==str(event.route[0]) and from==str(event.steps[-1]):
   event.steps.append(room);event.route.pop_front()
   if event.route.is_empty():event.await_landmark=true;stage(event,"landmark")
  elif from!=room:cancel_route("different_actual_door")

func on_exit_open_started() -> bool:
 if not active() or owner.app.room_id!="verify" or not owner.app.has_key() or not owner.actor_sees("face_press",owner.app.hero_pos,"verify",3.5):return false
 var event:Dictionary=state().face
 if event.attempted or not owner.data.body.is_empty() or not str(owner.data.get("holder","")).is_empty():return false
 event.attempted=true;owner.actor("face_press").stand_done=true
 stage(event,"approach");pose("face_press","turn_and_approach")
 owner.claim("face_start","cortex_face_interception_started")
 return true

func release_face(reason:String) -> void:
 if owner.data.is_empty():return
 var event:Dictionary=state().face
 if event.phase in ["idle","done","retreat"]:return
 if str(owner.data.body.get("actor",""))=="face_press":owner.clear_body()
 if str(owner.data.get("holder",""))=="face_press":owner.data.holder="";owner.app.rules.gripped=false
 owner.data.regrab_elapsed=0.0
 stage(event,"retreat" if reason not in ["death","crossed_exit"] and owner.present("face_press") else "done");pose("face_press","release_and_step_aside")
 owner.claim("face_release","cortex_face_released",{"reason":reason,"actual_contact":bool(event.contact)})
 if event.contact and reason!="death" and owner.near("face_press",2.5):line("FACE_RELEASE")

func advance_face(delta:float) -> void:
 var event:Dictionary=state().face
 if event.phase in ["idle","done"]:return
 if event.phase=="retreat":
  if not owner.present("face_press"):stage(event,"done");return
  if owner.move("face_press",owner.beside("verify",point("verify",0)),delta):stage(event,"done");pose("face_press","idle_side")
  return
 if not owner.present("face_press") or owner.app.room_id!="verify" or str(owner.actor("face_press").room)!="verify":release_face("actor_or_room_left");return
 if event.phase!="hold" and (not str(owner.data.get("holder","")).is_empty() or (not owner.data.body.is_empty() and str(owner.data.body.get("actor",""))!="face_press")):
  release_face("other_body_holder");return
 if event.phase=="approach":
  if owner.approach_contact("face_press",delta):
   stage(event,"raise");pose("face_press","raise_hand")
   event.aim=owner.xy(owner.app.hero_pos)
   event.aim_direction=owner.xy((owner.app.hero_pos-owner.position("face_press")).normalized())
   owner.actor("face_press").facing=event.aim_direction.duplicate()
 elif event.phase=="raise" and elapsed(event,delta,0.8):
  var reach:Vector2=owner.app.hero_pos-owner.position("face_press")
  var aim:Vector2=vector(event.get("aim_direction",owner.actor("face_press").get("facing",[0,1])))
  if not owner.near("face_press",0.68) or (reach.length()>0.035 and aim.dot(reach.normalized())<0.35):release_face("miss");return
  if owner.damage("face_contact",0,15):
   event.contact=true;owner.set_body("face_press","face_press")
   owner.data.holder="face_press";owner.app.rules.gripped=true
   stage(event,"hold");pose("face_press","press_face")
  else:release_face("already_settled")
 elif event.phase=="hold":
  if str(owner.data.get("holder",""))!="face_press":release_face("actual_release");return
  if elapsed(event,delta,1.2):release_face("finished")

func advance_identity(delta:float) -> void:
 var event:Dictionary=state().identity
 if event.phase not in ["turn","back"]:return
 if not owner.present("double_face"):stage(event,"interrupted");return
 if event.phase=="turn" and elapsed(event,delta,float(config.presentation.turn_seconds)):
  stage(event,"back");pose("double_face","show_second_face")
 if event.phase=="back" and owner.hero_sees("double_face",2.5):
  event.back=true;persistent().identity_read.back=true
  if persistent().identity_read.get("front",false):line("IDENTITY_FACES")
  stage(event,"done");complete_identity()

func complete_identity() -> void:
 if not active() or owner.app.rules.hp<=0:return
 var read:Dictionary=persistent().identity_read
 for item in ["left","right","front","back"]:
  if not read.get(item,false):return
 if loss_once("identity:S3:P1261–1267",10,{"left":"已注销","right":"当前使用","same_face":true,"scars_differ":true,"original_numbers":[null,null]}):
  owner.observe("cortex_identity_conflict","实际核对两套各自独立档案、两项通过结果及同脸不同旧伤；不合并真实身份。")
  line("IDENTITY_COMPLETE")

func on_search_complete(_index:int,_found_key:bool) -> void:pass

func on_skill(result:Dictionary) -> void:
 if not active() or not result.get("success",false):return
 var id:String=str(result.get("id",result.get("skill","")))
 if id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:cancel_route("neural_intervention")

func kick_contact() -> void:
 if not active():return
 for id in ["faceless","face_press"]:
  if not owner.near(id,0.95):continue
  var toward:Vector2=owner.position(id)-owner.app.hero_pos
  if toward.length()>0.01 and owner.app.hero_facing.dot(toward.normalized())<0.35:continue
  if not owner.app.rules.kick_contact("cortex_"+id,toward.length(),toward.length()<0.035 or owner.app.hero_facing.dot(toward.normalized())>0.35,owner.app.layout.clear_segment(owner.app.hero_pos,owner.position(id))):continue
  owner.claim("kick:"+id,"cortex_actor_kicked",{"actor":id})
  if id=="faceless" and state().index.phase in ["approach","pinch","extract"]:
   state().index.interrupted=true;stage(state().index,"retreat");pose(id,"return_to_cabinet")
   owner.claim("index_kicked","cortex_index_interrupted")
  elif id=="face_press" and state().face.phase in ["approach","raise"]:release_face("actual_kick")

func release_all(reason:String="context_ended") -> void:
 if owner.data.is_empty():return
 release_face(reason);cancel_route(reason)
 var value:Dictionary=state()
 if value.bridge.phase not in ["idle","done"]:stage(value.bridge,"interrupted")
 if value.index.phase not in ["idle","done"]:stage(value.index,"interrupted")
 value.rhythm.waiting=false

func action_label(id:String) -> String:
 var key:String={"dual_head":"bridge","twitch":"rhythm","faceless":"index","reverse":"switch","face_press":"face","double_face":"identity"}.get(id,"")
 if key.is_empty():return "待机"
 var phase:String=str(state()[key].phase)
 return {"idle":"待机","done":"收手待机","left_turn":"左头转向","right_turn":"右头转向","left_speaking":"左头陈述","right_speaking":"右头陈述","complete":"两侧听取完成","interrupted":"动作已中断","gap":"肩部抽动 · 等待空档","crossing":"脚停 · 支架牵引","approach":"真实接近","pinch":"捏住姓名标签","extract":"抽取姓名标签","put_away":"收入衣内","retreat":"实际退回侧方","point":"指向回环","route":"正在指引回环","landmark":"回环已走完","cancelled":"指引已中断","raise":"抬手按脸前摇","hold":"实际按住面部","turn":"转身展示第二面","back":"另一面已朝外"}.get(phase,phase)

func markers() -> Array:
 var result:Array=[]
 if not active():return result
 var value:Dictionary=state()
 if owner.app.room_id=="index":result.append({"id":"cortex_name_label","room":"index","pos":owner.xy(owner.position("faceless") if persistent().index_removed and owner.present("faceless") else point("index",3)),"label":"姓名标签 · 衣内" if persistent().index_removed else "姓名标签 · 索引位","kind":"note"})
 if owner.app.room_id=="rhythm":result.append({"id":"cortex_rhythm_count","room":"rhythm","pos":owner.xy(point("rhythm",0)),"label":"实际抽动 %d 次"%int(value.rhythm.count),"kind":"note"})
 return result
