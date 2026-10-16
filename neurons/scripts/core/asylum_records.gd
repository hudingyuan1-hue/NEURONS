extends RefCounted
## L3 documents, one guard and the inherited patient. All mutable state belongs
## to owner.data.records_state and uses the existing gameplay clock/save path.
const Map=preload("res://scripts/core/asylum_map.gd")
const FIRST_FLOOR=["ward","lobby","clinic","pharmacy","office"]
const PATIENT_ROUTE=["office","lobby","stairs","corridor","double_ward"]
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_records.json"))

func state() -> Dictionary:
 if not owner.data.has("records_state"):
  owner.data.records_state={"files":{},"read":[],"stopped":{},"serial":0,"reading":{},"archivist":{"phase":"idle","elapsed":0.0},"report":{},"guard":{"phase":"idle","target":"","done":false,"elapsed":0.0,"last_seen":[],"last_room":""},"patient_delivered":false,"patient_silenced":false,"patient_anomaly_seen":false}
 var result:Dictionary=owner.data.records_state
 for document in config.documents:
  var id:String=str(document.id)
  if not result.files.has(id):result.files[id]="office:%d"%int(document.index)
  if not owner.app.rules.owners.has(id):owner.app.rules.owners[id]=result.files[id]
 if not result.has("inherited_patient"):
  result.inherited_patient=owner.data.get("carry",{}).get("actors",{}).get("patient",{}).duplicate(true)
  result.inherited_patient_records=owner.data.get("carry",{}).get("records_state",{}).duplicate(true)
 return result

func xy(value:Vector2) -> Array:return [value.x,value.y]
func point(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func parameter(key:String) -> float:return float(config.parameters[key])
func timing(key:String) -> float:return float(config.timing[key])
func document_spec(id:String) -> Dictionary:
 for document in config.documents:
  if str(document.id)==id:return document
 return {}
func page_position(index:int) -> Vector2:return owner.layout_for("office").furniture[index].at
func file_available(document:Dictionary) -> bool:
 if document.is_empty():return false
 if document.get("requires_report",false) and state().report.is_empty():return false
 var location:String=str(owner.app.rules.owners.get(str(document.id),""))
 if document.get("requires_report",false):
  return str(state().report.get("location",""))=="office:10" or location=="hero"
 return location=="office:%d"%int(document.index) or location=="hero"

func read_candidates() -> Array:
 if owner.data.is_empty():return []
 var value:Dictionary=state();var result:Array=[]
 for document in config.documents:
  if str(document.id) in value.read or not file_available(document):continue
  if not int(document.index) in result:result.append(int(document.index))
 return result

func body_free(controlled:bool=false) -> bool:
 var rules=owner.app.rules
 return rules.hp>0 and not rules.loading and not rules.transitioning and not rules.absent and not rules.gripped and not rules.body_busy() and not rules.search_active and (controlled or rules.control_left<=0) and owner.data.body.is_empty() and str(owner.data.holder).is_empty() and float(owner.data.medicine_stop)<=0

func begin_read(index:int,page_id:String="",controlled:bool=false) -> bool:
 if owner.app.session.data.level!=3 or owner.app.room_id!="office" or not body_free(controlled) or not owner.app.dialogue_queue.is_empty():return false
 if controlled and owner.app.rules.control_left<=0:return false
 var value:Dictionary=state()
 if not value.reading.is_empty():return false
 var document:Dictionary=document_spec(page_id)
 if document.is_empty():
  for candidate in config.documents:
   if int(candidate.index)==index and not str(candidate.id) in value.read and file_available(candidate):document=candidate;break
 if document.is_empty() or int(document.index)!=index or not file_available(document):return false
 var at:Vector2=page_position(index)
 if owner.app.hero_pos.distance_to(at)>parameter("contact_distance") or not owner.app.layout.clear_segment(owner.app.hero_pos,at):return false
 value.serial+=1
 value.reading={"id":str(document.id),"index":index,"serial":int(value.serial),"elapsed":0.0,"phase":"prepare","phase_progress":0.0,"controlled":controlled,"room":"office","pos":xy(at)}
 owner.app.hero_route=PackedVector2Array();owner.app.target_index=-1
 var origin:String="controlled" if controlled else "autonomous"
 if not owner.app.rules.public_action.is_empty():owner.app.rules.finish_public_action(str(owner.app.rules.public_action.get("origin",origin)))
 owner.app.rules.begin_public_action("observe",str(document.id),origin,"office")
 return true

func cancel_read(reason:String="interrupted") -> void:
 if owner.data.is_empty() or not owner.data.has("records_state"):return
 var value:Dictionary=state()
 if value.reading.is_empty():return
 var id:String=str(value.reading.id);value.reading={}
 if owner.app.rules.public_action.get("kind","")=="observe" and owner.app.rules.public_action.get("target","")==id:
  owner.app.rules.finish_public_action(str(owner.app.rules.public_action.get("origin","autonomous")))
 value.last_read_cancel=reason
 if owner.app.action_phase=="asylum_reading":owner.app.action_phase="autonomy";owner.app.hero_state="idle"

func advance_read(delta:float) -> void:
 var value:Dictionary=state()
 if value.reading.is_empty():return
 var action:Dictionary=value.reading;var document:Dictionary=document_spec(str(action.id))
 if owner.app.room_id!="office" or not body_free(bool(action.controlled)) or not file_available(document) or owner.app.hero_pos.distance_to(page_position(int(action.index)))>parameter("contact_distance") or not owner.app.layout.clear_segment(owner.app.hero_pos,page_position(int(action.index))) or (action.controlled and owner.app.rules.control_left<=0):cancel_read("lost_contact");return
 var window:float=minf(delta,owner.app.rules.control_left) if action.controlled else delta
 action.elapsed+=window
 var elapsed:float=float(action.elapsed)
 action.phase="prepare" if elapsed<timing("prepare") else "contact" if elapsed<timing("prepare")+timing("contact") else "finish"
 action.phase_progress=clampf(elapsed/timing("prepare"),0,1) if action.phase=="prepare" else clampf((elapsed-timing("prepare"))/timing("contact"),0,1) if action.phase=="contact" else clampf((elapsed-timing("prepare")-timing("contact"))/timing("finish"),0,1)
 if elapsed+0.000001<timing("prepare")+timing("contact")+timing("finish"):return
 if owner.claim("document:"+str(action.id),"asylum_document_read",{"id":str(action.id),"source":str(document.source)}):
  if not str(action.id) in value.read:value.read.append(str(action.id))
  owner.observe(str(action.id),str(document.text))
  if action.controlled:owner.app.rules.controlled_execution("observe",str(action.id))
  check_document_links()
 cancel_read("completed")

func check_document_links() -> void:
 var value:Dictionary=state();var fields:Dictionary=config.fields
 if "asylum_scar_photo" in value.read and "asylum_no_external_injury" in value.read:
  var a=fields.scar_patient_number;var b=fields.no_injury_patient_number
  if a!=null and b!=null and not str(a).is_empty() and str(a)==str(b):owner.observe("asylum_injury_record_conflict","实际核对同一患者编号的伤痕照片与无外伤页，发现影像与书面记录矛盾。")

func current_file_index() -> int:
 var reading:Dictionary=state().reading
 if reading.is_empty() or owner.app.room_id!="office":return -1
 var document:Dictionary=document_spec(str(reading.id))
 return int(reading.index) if document.get("controlled",false) else -1

func visible(id:String,at:Vector2,room:String,limit:float=-1) -> bool:
 if not owner.present(id) or str(owner.actor(id).room)!=room:return false
 if limit>=0 and owner.position(id).distance_to(at)>limit:return false
 return owner.layout_for(room).clear_segment(owner.position(id),at)

func sees_hero() -> bool:
 if not owner.app.room_id in FIRST_FLOOR:return false
 if visible("guard",owner.app.hero_pos,owner.app.room_id,parameter("notice_distance")):return true
 if not owner.present("guard"):return false
 var room:String=str(owner.actor("guard").room)
 if not room in FIRST_FLOOR or not owner.app.room_id in Map.doors(room):return false
 var a:Vector2=owner.portal_for(room,owner.app.room_id).threshold;var b:Vector2=owner.portal_for(owner.app.room_id,room).threshold
 return owner.position("guard").distance_to(a)+owner.app.hero_pos.distance_to(b)<=parameter("notice_distance") and owner.layout_for(room).clear_segment(owner.position("guard"),a) and owner.app.layout.clear_segment(b,owner.app.hero_pos)

func say(key:String) -> void:
 if not owner.claim("records_line:"+key,"asylum_dialogue"):return
 for line in config.dialogue.get(key,[]):owner.app.add_dialogue(str(line.speaker),str(line.text))

func tick(delta:float) -> void:
 if owner.data.is_empty():return
 var value:Dictionary=state()
 if owner.app.rules.hp<=0:
  cancel_read("death");finish_guard(false);return
 if owner.app.session.data.level!=3 or not owner.enabled:cancel_read("level_left");return
 if not owner.app.dialogue_queue.is_empty():return
 advance_archivist(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_report(delta)
 advance_guard(delta)
 if owner.app.rules.hp<=0 or not owner.app.dialogue_queue.is_empty():return
 advance_read(delta)
 if not owner.app.dialogue_queue.is_empty():return
 if guard_free() and not value.patient_delivered and owner.present("patient") and visible("guard",owner.position("patient"),str(owner.actor("patient").room),parameter("notice_distance")):
  value.guard.phase="approach";value.guard.target="patient";value.guard.elapsed=0.0
  value.guard.last_seen=xy(owner.position("patient"));value.guard.last_room=str(owner.actor("patient").room)
  value.patient_silenced=true
  if owner.near("patient",2.0):say("PATIENT_STOP")
  return
 patient_dialogue()

func advance_archivist(delta:float) -> void:
 if not owner.present("archivist"):return
 var value:Dictionary=state();var event:Dictionary=value.archivist;var index:int=current_file_index()
 var sees:bool=visible("archivist",owner.app.hero_pos,owner.app.room_id,parameter("notice_distance"))
 if event.phase=="idle":
  if not value.report.is_empty() or index<0 or not sees:return
  var serial:int=int(value.reading.serial)
  if int(value.stopped.get(str(index),-1))==serial:return
  event.phase="approach";event.index=index;event.elapsed=0.0;event.last_seen=xy(owner.app.hero_pos)
 if event.phase=="approach":
  if not sees:
   if owner.move("archivist",point(event.last_seen),delta):event.phase="idle"
   return
  event.last_seen=xy(owner.app.hero_pos)
  if index<0:event.phase="idle";return
  if not owner.near("archivist",parameter("approach_distance")):owner.move("archivist",owner.app.hero_pos,delta);return
  event.phase="stop";event.index=index;event.serial=int(value.reading.serial);event.read_elapsed=float(value.reading.elapsed);event.elapsed=0.0
  event.report_pending=value.stopped.has(str(index));value.stopped[str(index)]=event.serial
  say("STOP_MATCHED" if "asylum_injury_record_conflict" in owner.app.rules.known else "STOP");return
 if event.phase=="stop":
  if index>=0 and sees:
   event.last_seen=xy(owner.app.hero_pos)
   if int(value.reading.serial)!=int(event.serial) or float(value.reading.elapsed)>float(event.read_elapsed)+0.000001:event.report_pending=true
  event.elapsed+=delta
  if float(event.elapsed)<timing("stop"):return
  var at:Vector2=page_position(int(event.index))
  if not visible("archivist",at,"office",parameter("contact_distance")):owner.move("archivist",at,delta);return
  for document in config.documents:
   if int(document.index)!=int(event.index) or not document.get("controlled",false) or document.get("requires_report",false):continue
   var id:String=str(document.id);var home:String="office:%d"%int(event.index)
   if str(owner.app.rules.owners.get(id,""))!=home:continue
   if owner.claim("file_collect:"+id,"asylum_archive_file_collected",{"file":id,"from":home}):
    value.files[id]="asylum_archive_storage";owner.app.rules.owners[id]="asylum_archive_storage"
  if not value.reading.is_empty() and not file_available(document_spec(str(value.reading.id))):cancel_read("file_collected")
  event.phase="write_route" if event.get("report_pending",false) else "idle";event.elapsed=0.0;return
 if event.phase=="write_route":
  if str(owner.actor("archivist").room)!="office":owner.travel("archivist","office",delta);return
  if not owner.move("archivist",page_position(10),delta):return
  event.phase="write";event.elapsed=0.0;return
 if event.phase=="write":
  if not visible("archivist",page_position(10),"office",parameter("contact_distance")):event.phase="write_route";event.elapsed=0.0;return
  event.elapsed+=delta
  if float(event.elapsed)<timing("paperwork"):return
  if owner.claim("archive_report","asylum_archive_report_written",{"index":int(event.index),"last_seen":event.last_seen}):
   value.report={"phase":"pending","location":"archivist","room":"office","pos":xy(owner.position("archivist")),"last_room":"office","last_seen":event.last_seen.duplicate(),"elapsed":0.0,"index":int(event.index)}
   owner.app.rules.owners.asylum_archive_report="archivist"
   owner.record("asylum_archive_report:"+str(owner.app.rules.actual_attempt),"档案员亲眼制止后仍见继续翻查；本次写成异常报告。与前关副本、实际攻击和角色所知分别保存。")
  event.phase="idle";event.report_pending=false

func guard_free() -> bool:
 return owner.present("guard") and state().guard.phase=="idle" and str(owner.data.holder)!="guard"

func advance_report(delta:float) -> void:
 var value:Dictionary=state();var report:Dictionary=value.report
 if report.is_empty() or report.phase!="pending":return
 if report.location=="archivist":
  if not owner.present("archivist"):
   report.location="office_floor";owner.app.rules.owners.asylum_archive_report="office_floor";report.elapsed=0.0
  else:
   report.pos=xy(owner.position("archivist"));report.room=str(owner.actor("archivist").room)
   if report.room!="office":owner.travel("archivist","office",delta);return
   if not owner.move("archivist",page_position(10),delta):report.elapsed=0.0;return
   report.elapsed+=delta
   if float(report.elapsed)<timing("handoff"):return
   report.location="office:10";report.pos=xy(page_position(10));report.elapsed=0.0;owner.app.rules.owners.asylum_archive_report="office:10"
   owner.app.rules.owners.asylum_current_report="office:10"
   return
 if not guard_free() or value.guard.done:return
 if str(owner.actor("guard").room)!="office":owner.travel("guard","office",delta);return
 var at:Vector2=point(report.pos)
 if not visible("guard",at,"office",parameter("contact_distance")):report.elapsed=0.0;owner.move("guard",at,delta);return
 report.elapsed+=delta
 if float(report.elapsed)<timing("handoff"):return
 if not owner.claim("archive_report_received","asylum_archive_report_received",{"last_room":report.last_room,"last_seen":report.last_seen}):return
 report.phase="accepted";report.location="guard";owner.app.rules.owners.asylum_archive_report="guard";owner.app.rules.owners.asylum_current_report="guard"
 value.guard.phase="approach";value.guard.target="hero";value.guard.elapsed=0.0;value.guard.last_seen=report.last_seen.duplicate();value.guard.last_room=report.last_room
 if sees_hero():value.guard.last_seen=xy(owner.app.hero_pos);value.guard.last_room=owner.app.room_id

func finish_guard(delivered:bool=false) -> void:
 var value:Dictionary=state();var event:Dictionary=value.guard;var was_hero:bool=event.target=="hero"
 if str(owner.data.holder)=="guard":
  owner.data.holder="";owner.app.rules.gripped=false;owner.data.regrab_elapsed=0.0
  if owner.data.body.get("kind","")=="records_guard_drag":owner.clear_body()
 if was_hero:
  event.done=true;owner.claim("guard_end","asylum_guard_disposition_ended",{"delivered":delivered})
 if event.target=="patient" and not value.patient_delivered and owner.present("patient"):owner.actor("patient").phase="idle"
 if event.target=="patient":value.patient_silenced=false
 event.phase="idle";event.target="";event.elapsed=0.0
 if owner.present("guard"):owner.actor("guard").phase="idle";owner.actor("guard").route=[]

func advance_guard(delta:float) -> void:
 var value:Dictionary=state();var event:Dictionary=value.guard
 if event.phase=="idle":return
 if not owner.present("guard"):finish_guard(false);return
 if event.phase=="return":
  if owner.travel("guard","office",delta):
   if owner.move("guard",page_position(10)+Vector2(0.4,0),delta):finish_guard(true)
  return
 var hero:bool=event.target=="hero"
 if not hero and not owner.present("patient"):finish_guard(false);return
 var target_room:String=owner.app.room_id if hero else str(owner.actor("patient").room)
 var target_pos:Vector2=owner.app.hero_pos if hero else owner.position("patient")
 var sees:bool=sees_hero() if hero else visible("guard",target_pos,target_room,parameter("notice_distance"))
 if event.phase=="approach":
  if hero and not target_room in FIRST_FLOOR:finish_guard(false);return
  if sees:event.last_seen=xy(target_pos);event.last_room=target_room
  if str(owner.actor("guard").room)!=str(event.last_room):owner.travel("guard",str(event.last_room),delta);return
  if not sees:
   if owner.move("guard",point(event.last_seen),delta):finish_guard(false)
   return
  if owner.position("guard").distance_to(target_pos)>parameter("approach_distance"):owner.move("guard",target_pos,delta);return
  if hero and not owner.can_begin_grip():return
  event.phase="reach";event.elapsed=0.0;event.evaded=false
  if hero and owner.near("guard",2.0):say("GUARD")
  return
 if event.phase=="reach":
  event.elapsed+=delta
  if float(event.elapsed)<timing("grab_prepare"):return
  if not sees or str(owner.actor("guard").room)!=target_room or owner.position("guard").distance_to(target_pos)>parameter("approach_distance") or event.get("evaded",false):finish_guard(false);return
  if hero:
   if not owner.can_begin_grip():finish_guard(false);return
   var prior:bool=previous_drag()
   if not owner.claim("guard_grip","asylum_guard_grip"):finish_guard(false);return
   cancel_read("guard_grip")
   if not owner.data.body.is_empty():owner.clear_body()
   owner.data.holder="guard";owner.app.rules.gripped=true;owner.set_body("records_guard_drag","guard")
   owner.damage("records_guard_damage",int(config.values.guard_hp),int(config.values.guard_sp))
   if owner.app.rules.hp<=0:finish_guard(false);return
   say("HELD_AGAIN" if prior else "HELD")
  else:
   if not owner.claim("patient_guard_grip","asylum_patient_guard_grip"):finish_guard(false);return
   owner.actor("patient").phase="guard_held";event.leg=0
   if owner.near("patient",2.0):say("PATIENT_HELD")
  event.phase="drag";event.elapsed=0.0;return
 if event.phase=="drag":
  event.elapsed+=delta
  if hero:drag_hero(delta)
  else:drag_patient(delta)

func previous_drag() -> bool:
 for fact in owner.app.rules.facts:
  if str(fact.get("kind","")) in ["guard_grip","asylum_guard_grip"]:return true
 return false

func advance_pair(to:Vector2,hero:bool,delta:float) -> bool:
 var room:String=str(owner.actor("guard").room)
 var follower:Vector2=owner.app.hero_pos if hero else owner.position("patient")
 if owner.position("guard").distance_to(follower)<=0.6:owner.move("guard",to,delta)
 var leader_arrived:bool=owner.position("guard").distance_to(to)<0.035
 var target:Vector2=to if leader_arrived else owner.position("guard")
 if hero:
  var floor_layout=owner.layout_for(room);var route:PackedVector2Array=floor_layout.path(owner.app.hero_pos,target)
  if route.is_empty() and owner.app.hero_pos.distance_to(target)>0.05:finish_guard(false);return false
  owner.app.hero_pos=floor_layout.move_path(owner.app.hero_pos,route,parameter("walk_speed")*delta).position
  owner.app.hero_state="hit"
 else:owner.move("patient",target,delta)
 follower=owner.app.hero_pos if hero else owner.position("patient")
 return leader_arrived and follower.distance_to(to)<0.05

func change_pair_room(room:String,hero:bool) -> void:
 var previous:String=str(owner.actor("guard").room);var entry:Vector2=owner.portal_for(room,previous).landing
 owner.actor("guard").room=room;owner.actor("guard").pos=xy(entry);owner.actor("guard").route=[]
 if hero:
  var body:Dictionary=owner.data.body.duplicate(true)
  owner.app.enter_room(room);owner.app.hero_pos=entry;owner.data.body=body;owner.data.holder="guard";owner.app.rules.gripped=true
 else:
  owner.actor("patient").room=room;owner.actor("patient").pos=xy(entry);owner.actor("patient").route=[]

func drag_hero(delta:float) -> void:
 var event:Dictionary=state().guard;var room:String=str(owner.actor("guard").room)
 if room!=owner.app.room_id or not room in FIRST_FLOOR:finish_guard(false);return
 if float(event.elapsed)>=timing("guard_max"):finish_guard(false);return
 var next:String="office" if room=="office" else Map.next_room(room,"office")
 var to:Vector2=owner.portal_for("office","lobby").at if room=="office" else owner.portal_for(room,next).threshold
 if owner.layout_for(room).path(owner.position("guard"),to).is_empty() and owner.position("guard").distance_to(to)>0.05:finish_guard(false);return
 if not advance_pair(to,true,delta):return
 if room=="office":finish_guard(true)
 else:change_pair_room(next,true)

func drag_patient(delta:float) -> void:
 var value:Dictionary=state();var event:Dictionary=value.guard;var room:String=str(owner.actor("guard").room)
 if str(owner.actor("patient").room)!=room:finish_guard(false);return
 while int(event.leg)<PATIENT_ROUTE.size()-1 and room==PATIENT_ROUTE[int(event.leg)]:event.leg+=1
 var destination:String=PATIENT_ROUTE[int(event.leg)]
 if room!=destination:
  var next:String=Map.next_room(room,destination)
  if next.is_empty() or next=="cortex_exit":finish_guard(false);return
  if advance_pair(owner.portal_for(room,next).threshold,false,delta):change_pair_room(next,false)
  return
 var at:Vector2=owner.layout_for("double_ward").furniture[2].at
 if not advance_pair(at,false,delta):return
 value.patient_delivered=true;owner.data.patient_brought_up=true;owner.actor("patient").phase="idle"
 value.patient_silenced=false
 owner.claim("patient_delivered","asylum_patient_delivered",{"room":"double_ward","bed":1,"pos":xy(owner.position("patient"))})
 event.phase="return";event.target="";event.elapsed=0.0

func medical_listener() -> bool:
 for id in ["ordinary_orderly","registration_nurse","doctor","assistant","pharmacist","med_nurse","archivist","guard","head_nurse","isolation_orderly","therapist","supervisor"]:
  if visible(str(id),owner.position("patient"),str(owner.actor("patient").room),2.0):return true
 return false

func patient_dialogue() -> void:
 var value:Dictionary=state()
 if owner.app.has_key() or owner.app.rules.sp<50:return
 if value.patient_silenced or not owner.near("patient") or medical_listener():return
 if value.patient_anomaly_seen and not owner.app.rules.settled.has("hospital_patient_anomaly_quote"):
  owner.app.rules.settled.hospital_patient_anomaly_quote="seen"
  say("PATIENT_AWARE" if owner.app.rules.awareness_stage>=3 else "PATIENT_ANOMALY");return
 if owner.app.rules.settled.has("asylum_patient_number_quote"):return
 for key in owner.data.get("carry",{}).get("receipts",{}):
  if str(key).ends_with(":line:PATIENT"):
   owner.app.rules.settled.asylum_patient_number_quote="heard_in_hospital";return
 # The protagonist's existing wristband is a visible physical reference,
 # not a fabricated readable number and not an automatic clue-page unlock.
 owner.app.rules.settled.asylum_patient_number_quote="heard_in_asylum"
 value.patient_pointed="hero_wristband";say("PATIENT_NUMBER")

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false) or owner.data.is_empty():return
 var value:Dictionary=state();var id:String=str(result.get("id",""));var event:Dictionary=value.guard
 if id in ["SKIN","GUT","WITHDRAW","STARTLE","FEAR","CONTROL","KNEE"]:cancel_read("skill:"+id)
 if event.target=="hero" and event.phase=="reach" and id=="WITHDRAW":event.evaded=true
 if owner.near("patient",2.0) and not value.patient_silenced and id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","PORES"]:value.patient_anomaly_seen=true

func kick_contact() -> void:
 if owner.data.is_empty():return
 for id in ["archivist","guard"]:
  if not owner.near(id,1.0):continue
  var offset:Vector2=owner.position(id)-owner.app.hero_pos
  if owner.app.rules.kick_contact("asylum_"+id,offset.length(),offset.normalized().dot(owner.app.hero_facing)>0.35,owner.app.layout.clear_segment(owner.app.hero_pos,owner.position(id))):
   owner.claim("kick:"+id,"asylum_staff_kicked",{"target":id})
   owner.record("asylum_records_attack:"+str(owner.app.rules.actual_attempt),"本次膝跳实际踢中工作人员："+id+"。不根据旧报告补造攻击。")

func on_search_complete(index:int,_found_key:bool) -> void:
 # L3 floor one has zero key searches. A legacy or external search callback
 # cannot grant file knowledge or silently count a reading as a search.
 pass

func blocks_hero() -> bool:
 if owner.data.is_empty():return false
 return not state().reading.is_empty() or str(owner.data.holder)=="guard"
