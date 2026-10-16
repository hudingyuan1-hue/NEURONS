extends RefCounted
## S3:P560–607/T14–17, S4:T15R4. Hospital owns scheduling and pause.
## No file, report, grip or removal is settled by an animation frame.
var _hospital:WeakRef
var owner:
 get:return _hospital.get_ref()

const FILES:Dictionary={
 0:["archive_index"],5:["case_removal"],6:["laundry_stub"],
 7:["complaint_original","complaint_rewrite"],
 10:["case_death","case_fees","case_discharge"]}
const PAGE_TEXT:Dictionary={
 "archive_index":"读到办公室资料架的既往患者索引；未把既往死者认作仍活着的病友。",
 "case_removal":"实际读到一份既往病例的摘除记录。",
 "case_death":"实际读到同一既往病例的死亡记录。",
 "case_fees":"实际读到同一既往病例的费用页。",
 "case_discharge":"实际读到同一既往病例的离院页。",
 "laundry_stub":"实际读到污衣交接存根；只保留纸面袋号与已完成状态，不补造未发生的搬运。",
 "complaint_original":"实际读到原投诉文件。",
 "complaint_rewrite":"实际读到同一人的异常报告；机构标签与投诉内容分开保留。"}

func _init(hospital) -> void:_hospital=weakref(hospital)

func state() -> Dictionary:
 if not owner.data.has("records_state"):
  owner.data.records_state={"files":{},"read":[],"stopped":{},"archivist":{"phase":"idle","index":-1,"elapsed":0.0},"report":{},"guard":{"phase":"idle","target":"","done":false,"elapsed":0.0,"last_seen":[],"last_room":""},"patient_gone":false,"patient_silenced":false}
 var result:Dictionary=owner.data.records_state
 for index in FILES:
  for id in FILES[index]:
   if not result.files.has(id):result.files[id]="office:%d"%index
   if not owner.app.rules.owners.has(id):owner.app.rules.owners[id]=result.files[id]
 return result

func xy(value:Vector2) -> Array:return [value.x,value.y]
func point(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func parameter(key:String,fallback:float) -> float:return float(owner.config.test_parameters.get(key,fallback))

func visible(id:String,at:Vector2,room:String,limit:float=-1) -> bool:
 if not owner.present(id) or str(owner.actor(id).room)!=room:return false
 if limit>=0 and owner.position(id).distance_to(at)>limit:return false
 return owner.layout_for(room).clear_segment(owner.position(id),at)

func sees_hero(id:String) -> bool:
 return visible(id,owner.app.hero_pos,owner.app.room_id,parameter("notice_distance",1.2))

func current_file_index() -> int:
 if owner.app.room_id!="office" or not owner.app.rules.search_active:return -1
 var index:int=owner.app.target_index
 return index if FILES.has(index) else -1

func point_position(index:int) -> Vector2:
 var room_layout=owner.layout_for("office")
 return room_layout.furniture[index].at

func guard_free() -> bool:
 var value:Dictionary=state().guard
 return owner.present("guard") and value.phase=="idle" and str(owner.data.get("holder",""))!="guard"

func sees_patient() -> bool:
 if not owner.present("guard") or not owner.present("patient"):return false
 var room:String=str(owner.actor("patient").room)
 if visible("guard",owner.position("patient"),room,parameter("notice_distance",1.2)):return true
 # The patient stays outside the office. An actual open doorway can be seen
 # from both sides; the guard still has to walk through it before reaching.
 if str(owner.actor("guard").room)!="office" or room!="lobby":return false
 var inside:Vector2=owner.source_portal("office","lobby").threshold
 var outside:Vector2=owner.source_portal("lobby","office").threshold
 return owner.position("guard").distance_to(inside)+owner.position("patient").distance_to(outside)<=parameter("notice_distance",1.2) and owner.layout_for("office").clear_segment(owner.position("guard"),inside) and owner.layout_for("lobby").clear_segment(outside,owner.position("patient"))

func advance_patient(delta:float) -> void:
 var value:Dictionary=state()
 if value.patient_gone or not owner.present("patient") or str(owner.actor("patient").room)!="lobby":return
 if value.guard.target=="patient" and value.guard.phase!="idle":return
 if not value.has("patient_walk"):value.patient_walk={"leg":"center","left":parameter("patient_pause",3.0)}
 var walk:Dictionary=value.patient_walk
 walk.left=maxf(0,float(walk.left)-delta)
 if float(walk.left)>0:return
 var office_portal:Dictionary=owner.source_portal("lobby","office")
 var target:Vector2=owner.source_anchor("lobby","patient_walk_center",Vector2(2.8,1.4)) if walk.leg=="center" else office_portal.at+office_portal.inward*0.45
 if owner.move("patient",target,delta):
  walk.leg="office" if walk.leg=="center" else "center"
  walk.left=parameter("patient_pause",3.0)

func tick(delta:float) -> void:
 if owner.data.is_empty():return
 var value:Dictionary=state()
 if owner.app.rules.hp<=0:
  if str(owner.data.get("holder",""))=="guard":
   owner.data.holder="";owner.app.rules.gripped=false;owner.clear_body()
  if value.guard.phase!="idle":value.guard.phase="idle";value.guard.done=true
  return
 if owner.app.session.data.level!=2 or not owner.app.dialogue_queue.is_empty():return
 advance_archivist(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_report(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_guard(delta)
 if not owner.app.dialogue_queue.is_empty():return
 if guard_free() and not value.patient_gone and owner.present("patient"):
  var room:String=str(owner.actor("patient").room)
  if sees_patient():
   value.guard.phase="approach";value.guard.target="patient";value.guard.elapsed=0.0
   value.guard.last_seen=xy(owner.position("patient"));value.guard.last_room=room
   value.patient_silenced=true
   if owner.near("patient",2.0):owner.say("PATIENT_STOP")
 if not owner.app.dialogue_queue.is_empty():return
 advance_patient(delta)

func advance_archivist(delta:float) -> void:
 if not owner.present("archivist"):return
 var value:Dictionary=state();var event:Dictionary=value.archivist
 var index:int=current_file_index()
 if event.phase=="idle":
  if not value.report.is_empty():return
  if index<0 or not sees_hero("archivist"):return
  if str(value.stopped.get(str(index),""))==str(owner.app.rules._search_id):return
  event.phase="approach";event.index=index;event.elapsed=0.0
  event.last_seen=xy(owner.app.hero_pos)
 if event.phase=="approach":
  if index<0 and not sees_hero("archivist"):event.phase="idle";return
  if not sees_hero("archivist"):
   if owner.move("archivist",point(event.last_seen),delta):event.phase="idle"
   return
  event.last_seen=xy(owner.app.hero_pos)
  if not owner.near("archivist",parameter("approach_distance",0.55)):
   owner.move("archivist",owner.app.hero_pos,delta);return
  if index<0:event.phase="idle";return
  event.phase="stop";event.index=index;event.elapsed=0.0
  event.search_id=str(owner.app.rules._search_id)
  event.search_elapsed=owner.app.rules.search_elapsed
  event.report_pending=value.stopped.has(str(index))
  value.stopped[str(index)]=str(owner.app.rules._search_id)
  owner.say("STOP_FILE")
  if "complaint_original" in value.read and "complaint_rewrite" in value.read:
   # Replace only the conditional question, preserving source wording.
   for line in owner.app.dialogue_queue:
    if line.text=="这是什么记录？":line.text="同一个号码，怎么写了两种结果？"
  return
 if event.phase=="stop":
  if sees_hero("archivist") and index>=0:
   event.last_seen=xy(owner.app.hero_pos)
   var continued:bool=str(owner.app.rules._search_id)!=str(event.search_id) or owner.app.rules.search_elapsed>float(event.search_elapsed)+0.000001
   if continued and value.report.is_empty():event.report_pending=true
  elif index<0 and owner.app.hero_pos.distance_to(owner.position("archivist"))>parameter("notice_distance",1.2):
   event.phase="idle";return
  event.elapsed+=delta
  if float(event.elapsed)<parameter("handoff",0.55):return
  # Only files that were never taken may be collected. Search/key receipts
  # and already-read pages are left intact.
  var at:Vector2=point_position(int(event.index))
  if not visible("archivist",at,"office") or owner.position("archivist").distance_to(at)>0.65:
   owner.move("archivist",at,delta);return
  for id in FILES[int(event.index)]:
   if str(owner.app.rules.owners.get(id,""))=="office:%d"%int(event.index):
    if owner.claim("collect:"+id,"archive_file_collected",{"file":id,"from":"office:%d"%int(event.index)}):
     value.files[id]="archive_storage";owner.app.rules.owners[id]="archive_storage"
  event.phase="write" if event.get("report_pending",false) else "idle"
  event.elapsed=0.0
  return
 if event.phase=="write":
  event.elapsed+=delta
  if float(event.elapsed)>=parameter("paperwork",0.75):
   write_report(int(event.index),event.last_seen)
   event.report_pending=false;event.phase="idle"

func write_report(index:int,last_seen:Array=[]) -> void:
 var value:Dictionary=state()
 if not value.report.is_empty():return
 var seen:Array=xy(owner.app.hero_pos) if last_seen.is_empty() else last_seen.duplicate()
 if not owner.claim("archive_report","archive_report_written",{"point":"office:%d"%index,"last_seen":seen}):return
 var location:String="archivist" if owner.present("archivist") else "office:10"
 value.report={"phase":"pending","location":location,"last_seen":seen,"last_room":"office","index":index,"elapsed":0.0}
 owner.app.rules.owners.hospital_archive_report=location
 owner.record("archive_report:"+str(owner.app.rules.actual_attempt),"档案员：制止后仍继续翻查办公室文件。仅为机构对实际目击行为的记载。")

func advance_report(delta:float) -> void:
 var value:Dictionary=state();var report:Dictionary=value.report
 if report.is_empty() or report.phase!="pending":return
 var available:bool=guard_free() and not value.guard.done and str(owner.actor("guard").room)=="office"
 if not available:
  if report.location=="archivist" and owner.present("archivist"):
   var desk:Vector2=point_position(10)
   if owner.position("archivist").distance_to(desk)>parameter("approach_distance",0.55) or not visible("archivist",desk,"office"):
    report.elapsed=0.0;owner.move("archivist",desk,delta);return
   report.elapsed+=delta
   if float(report.elapsed)>=parameter("handoff",0.55):
    report.location="office:10";report.elapsed=0.0;owner.app.rules.owners.hospital_archive_report="office:10"
  return
 # S5 R3: an absent/busy recipient leaves a persistent desk report, never
 # destroys it and never summons a guard or freezes the protagonist.
 if owner.present("archivist") and str(owner.actor("archivist").room)=="office":
  if report.location=="office:10":
   var desk:Vector2=point_position(10)
   if owner.position("archivist").distance_to(desk)>parameter("approach_distance",0.55) or not visible("archivist",desk,"office"):
    report.elapsed=0.0;owner.move("archivist",desk,delta);return
   report.elapsed+=delta
   if float(report.elapsed)<parameter("handoff",0.55):return
   report.location="archivist";report.elapsed=0.0;owner.app.rules.owners.hospital_archive_report="archivist"
   return
  if not visible("archivist",owner.position("guard"),"office"):
   report.elapsed=0.0;owner.move("archivist",owner.position("guard"),delta);return
  if owner.position("archivist").distance_to(owner.position("guard"))>parameter("approach_distance",0.55):
   report.elapsed=0.0;owner.move("archivist",owner.position("guard"),delta);return
 else:
  var desk:Vector2=point_position(10)
  if owner.position("guard").distance_to(desk)>parameter("approach_distance",0.55) or not visible("guard",desk,"office"):
   report.elapsed=0.0;owner.move("guard",desk,delta);return
 report.elapsed+=delta
 if float(report.elapsed)<parameter("handoff",0.55):return
 if not owner.claim("archive_report_received","archive_report_received",{"last_seen":report.last_seen,"room":report.last_room}):return
 report.phase="accepted";report.location="guard";owner.app.rules.owners.hospital_archive_report="guard"
 value.guard.phase="approach";value.guard.target="hero";value.guard.elapsed=0.0
 value.guard.last_seen=report.last_seen.duplicate();value.guard.last_room=report.last_room
 if sees_hero("guard"):
  value.guard.last_seen=xy(owner.app.hero_pos);value.guard.last_room=owner.app.room_id
 if owner.near("archivist",2.0) or owner.near("guard",2.0):owner.say("REPORT")

func finish_guard(missed:bool=false) -> void:
 var value:Dictionary=state();var event:Dictionary=value.guard
 var was_hero:bool=event.target=="hero"
 if str(owner.data.get("holder",""))=="guard":
  owner.data.holder="";owner.app.rules.gripped=false;owner.data.regrab_elapsed=0.0;owner.clear_body()
 if was_hero:event.done=true
 event.phase="idle";event.target="";event.elapsed=0.0
 if owner.present("guard"):owner.actor("guard").phase="idle";owner.actor("guard").route=[]
 if was_hero and owner.app.rules.hp>0 and (not missed or owner.near("guard",2.0)):owner.say("GUARD_MISS" if missed else "GUARD_RELEASE")

func advance_guard(delta:float) -> void:
 var value:Dictionary=state();var event:Dictionary=value.guard
 if event.phase=="idle" or not owner.present("guard"):return
 var hero:bool=event.target=="hero"
 var target_room:String=owner.app.room_id if hero else str(owner.actor("patient").room)
 var target_pos:Vector2=owner.app.hero_pos if hero else owner.position("patient")
 var can_see:bool=visible("guard",target_pos,target_room,parameter("notice_distance",1.2)) if hero else sees_patient()
 if event.phase=="approach":
  if can_see:event.last_seen=xy(target_pos);event.last_room=target_room
  if str(owner.actor("guard").room)!=str(event.last_room):
   if hero or not can_see:finish_guard(true);return
   owner.travel("guard",str(event.last_room),delta)
   return
  var at:Vector2=point(event.last_seen)
  if not can_see:
   if owner.move("guard",at,delta):finish_guard(true)
   return
  if owner.position("guard").distance_to(target_pos)>parameter("approach_distance",0.55):
   owner.move("guard",target_pos,delta);return
  if hero and not owner.can_begin_grip():return
  event.phase="reach";event.elapsed=0.0;event.evaded=false
  if hero:owner.say("GUARD")
  return
 if event.phase=="reach":
  event.elapsed+=delta
  if float(event.elapsed)<parameter("grab_prepare",0.5):return
  if not can_see or owner.position("guard").distance_to(target_pos)>parameter("approach_distance",0.55) or event.get("evaded",false):
   finish_guard(true);return
  if hero:
   if not str(owner.data.get("holder","")).is_empty():return
   if not owner.claim("guard_grip","guard_grip"):finish_guard(true);return
   owner.data.holder="guard";owner.app.rules.gripped=true;owner.set_body("guard_drag","guard")
   owner.damage("guard_grip_damage",int(owner.config.values.guard_hp),int(owner.config.values.guard_sp))
   if owner.app.rules.hp<=0:finish_guard();return
   owner.say("GUARD_DRAG")
  else:
   if not owner.claim("patient_guard_grip","patient_guard_grip"):finish_guard();return
   value.patient_witness=owner.near("guard",2.0)
   owner.actor("patient").phase="guard_held"
   if owner.near("patient",2.0):owner.say("PATIENT_HELD")
  event.phase="drag";event.elapsed=0.0
  return
 if event.phase=="drag":
  event.elapsed+=delta
  var room:String=str(owner.actor("guard").room)
  var doorway:Vector2=owner.source_portal(room,"lobby" if room!="lobby" else "ward").threshold
  if hero:
   # Persisted established grip is not reset merely by room navigation.
   # Any unavailable path releases at the actual position; no wall teleport.
   var floor_layout=owner.layout_for(owner.app.room_id)
   # Normal scene navigation is blocked during an established hold. A damaged
   # or external mismatched-room state must never teleport either actor.
   if room!=owner.app.room_id:finish_guard();return
   var route:PackedVector2Array=floor_layout.path(owner.app.hero_pos,doorway)
   if route.is_empty() and owner.app.hero_pos.distance_to(doorway)>0.05:finish_guard();return
   var moved:Dictionary=floor_layout.move_path(owner.app.hero_pos,route,parameter("walk_speed",0.9)*delta)
   owner.app.hero_pos=moved.position;owner.actor("guard").pos=xy(moved.position)
   owner.app.hero_state="hit"
   if owner.app.hero_pos.distance_to(doorway)<0.05 or float(event.elapsed)>=float(owner.config.timing.guard_max):finish_guard()
  else:
   value.patient_witness=bool(value.get("patient_witness",false)) and owner.near("guard",2.0)
   var leader_arrived:bool=owner.position("guard").distance_to(doorway)<0.035
   if owner.position("guard").distance_to(owner.position("patient"))<=0.6:leader_arrived=owner.move("guard",doorway,delta)
   # Once the leader reaches the doorway, the follower walks its last few
   # centimetres to that same exit, rather than stopping at the leader's
   # movement tolerance and leaving the pair permanently short of the door.
   owner.move("patient",doorway if leader_arrived else owner.position("guard"),delta)
   if owner.position("patient").distance_to(doorway)<0.05:
    value.patient_gone=true;owner.data.patient_gone=true;owner.actor("patient").phase="gone"
    owner.claim("patient_removed","patient_removed",{"room":room})
    if bool(value.get("patient_witness",false)):owner.observe("patient_removed_seen","完整目击保安实际抓住病人并将他带离；未说完的话仍未知。" );owner.say("PATIENT_GONE")
    finish_guard()

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false):return
 var value:Dictionary=state();var event:Dictionary=value.guard
 # The skill acts only on the protagonist. It cannot release the patient or
 # erase a report; normal body reactions never undo an established grip.
 if event.target=="hero" and event.phase=="reach" and result.get("id","")=="WITHDRAW":event.evaded=true
 # An assistant may record an observed refusal, never a resisted cast or a
 # mere reaction after injury. This does not imply an attack or valid sample.
 if result.get("id","")=="WITHDRAW" and owner.data.body.get("kind","")=="exam" and owner.present("doctor") and owner.actor("doctor").phase=="grab" and owner.near("doctor",0.65) and owner.near("assistant",2.0):
  owner.record("refusal:"+owner.current_visit(),"不配合检查")

func kick_contact() -> void:pass

func on_search_complete(index:int,key_found:bool) -> void:
 if owner.app.room_id!="office" or not FILES.has(index):return
 var value:Dictionary=state()
 for id in FILES[index]:
  var location:String=str(owner.app.rules.owners.get(id,""))
  if location!="office:%d"%index and location!="hero":continue
  if not id in value.read:
   value.read.append(id)
   if id=="laundry_stub" and owner.data.get("bag","")!="removed":
    owner.observe(id,"实际读到污衣交接存根；搬运尚未完成，没有已完成交接结论。")
   else:owner.observe(id,str(PAGE_TEXT[id]))
   if id=="case_removal":owner.observe("removal_record","实际读到既往病例的摘除记录；不自动认作当前角色或术后病友。")
   if not id in owner.data.known_pages:owner.data.known_pages.append(id)
  if id=="laundry_stub" and owner.data.get("bag","")=="removed" and not value.get("laundry_completed",false):
   value.laundry_completed=true;owner.observe("laundry_handoff_complete","实际完成污衣搬运后再次核对存根；交接对象与完成记载分别保留。")
 if "complaint_original" in value.read and "complaint_rewrite" in value.read:owner.observe("complaint_changed","已分别读到同一人的投诉和异常报告，发现投诉被改写；机构表述不替代事实。")
 if index==10 and not value.report.is_empty():owner.observe("archive_report_read","实际读到本次档案员报告的指控；不倒推未发生的行为。")

func blocks_hero() -> bool:
 return not owner.data.is_empty() and str(owner.data.get("holder",""))=="guard"
