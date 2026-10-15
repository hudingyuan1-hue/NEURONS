extends SceneTree
## Isolated records/contact state checks with explicit open-floor/actor fixtures.
## Not a rendered hospital playthrough or production navigation acceptance.
const Records=preload("res://scripts/core/hospital_records.gd")
const Hospital=preload("res://scripts/core/hospital_events.gd")
const Neural=preload("res://scripts/core/neural_rules.gd")
var passes:Array=[]
var failures:Array=[]
var app
var hospital
var records

class Floor extends RefCounted:
 var line_clear:bool=true
 var route_open:bool=true
 var furniture:Array=[]
 func _init() -> void:
  for i in range(11):furniture.append({"at":Vector2(2,2)})
 func clear_segment(_from:Vector2,_to:Vector2) -> bool:return line_clear
 func path(from:Vector2,to:Vector2) -> PackedVector2Array:
  return PackedVector2Array([to]) if route_open and from.distance_to(to)>0.001 else PackedVector2Array()
 func move_path(from:Vector2,route:PackedVector2Array,distance:float) -> Dictionary:
  if route.is_empty():return {"position":from,"route":route}
  var at:Vector2=from.move_toward(route[0],distance)
  return {"position":at,"route":PackedVector2Array() if at.distance_to(route[0])<0.001 else route}

class Session extends RefCounted:
 var data:Dictionary={"level":2}

class Family extends RefCounted:
 var data:Dictionary={"eating":{}}

class App extends RefCounted:
 var rules
 var room_id:String="office"
 var hero_pos:Vector2=Vector2(2,2)
 var hero_state:String="idle"
 var hero_route:PackedVector2Array=PackedVector2Array()
 var target_index:int=5
 var action_phase:String="autonomy"
 var dialogue_queue:Array=[]
 var session=Session.new()
 var family=Family.new()
 var layout=Floor.new()
 func layout_for_room(_room:String):return layout
 func door_point_for(_room:String,_next:String) -> Vector2:return Vector2(0,0)
 func add_dialogue(speaker:String,text:String) -> void:dialogue_queue.append({"speaker":speaker,"text":text})

func check(condition:bool,label:String) -> void:
 (passes if condition else failures).append(label)
 print(("PASS " if condition else "FAIL ")+label)

func fixture(archivist:bool=true,guard:bool=false,patient:bool=false) -> void:
 app=App.new();app.rules=Neural.new();hospital=Hospital.new(app);hospital.start_attempt()
 records=Records.new(hospital)
 for id in ["archivist","guard","patient"]:
  hospital.actor(id).room="office";hospital.actor(id).pos=[2.0,2.0]
 hospital.actor("archivist").phase="idle" if archivist else "absent"
 hospital.actor("guard").phase="idle" if guard else "absent"
 hospital.actor("patient").phase="idle" if patient else "absent"

func step(seconds:float=0.1) -> void:
 app.dialogue_queue.clear();records.tick(seconds)

func accepted_report() -> void:
 records.write_report(5)
 for i in range(8):step()

func reach_grip() -> void:
 accepted_report()
 for i in range(12):
  if hospital.data.holder=="guard" or app.rules.hp<=0:return
  step()

func _initialize() -> void:
 fixture()
 for i in range(10):step()
 check(records.state().report.is_empty() and records.state().archivist.phase=="idle","ordinary passage cannot create an archive report")
 app.rules.begin_search("office:5");hospital.actor("archivist").room="clinic";step()
 check(records.state().archivist.phase=="idle","archivist cannot see a search through another room")
 hospital.actor("archivist").room="office";step()
 check(records.state().archivist.phase=="stop" and records.state().report.is_empty(),"actual visible search causes stop speech before any report")
 app.rules.search_elapsed=0.1;step()
 for i in range(18):step()
 check(records.state().report.phase=="pending" and app.rules.owners.hospital_archive_report=="office:10","continued observed search writes one persistent desk report")
 var neurons:int=app.rules.neurons
 for i in range(20):step()
 check(records.state().report.phase=="pending" and hospital.data.holder=="" and app.rules.neurons==neurons,"missing guard retains report without remote grip, reward or world lock")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(hospital.data))
 hospital.restore(saved)
 check(records.state().report.phase=="pending" and records.state().report.last_seen==[2.0,2.0],"actual JSON state retains report and its historical location")
 var reports:int=app.rules.institutional_records.size();records.write_report(7)
 check(app.rules.institutional_records.size()==reports,"repeated report request preserves one institutional entry")
 check(not "archive_report_read" in app.rules.known,"report writing does not give the protagonist unread accusations")
 records.on_search_complete(10,false)
 check("archive_report_read" in app.rules.known,"only actual desk search reveals the written report")

 fixture(false,true)
 reach_grip()
 check(hospital.data.holder=="guard" and app.rules.gripped and app.rules.hp==95 and app.rules.sp==90,"accepted report plus actual reach/grip applies 5HP and 10SP once")
 var hp:int=app.rules.hp;var sp:int=app.rules.sp
 for id in ["WITHDRAW","STARTLE","JOY","CONTROL"]:records.on_skill({"success":true,"id":id})
 check(hospital.data.holder=="guard" and app.rules.gripped,"ordinary neural reactions do not undo established guard grip")
 for i in range(80):step()
 check(hospital.data.holder=="" and not app.rules.gripped and records.state().guard.done,"guard releases at real doorway or six-second bound")
 check(app.rules.hp==hp and app.rules.sp==sp,"dragging and later frames cannot repeat grip damage")
 records.state().report.phase="pending"
 for i in range(20):step()
 check(records.state().guard.phase=="idle" and app.rules.hp==95,"re-presented report cannot grant a second protagonist disposition")

 fixture(false,true)
 accepted_report()
 while records.state().guard.phase!="reach":step()
 records.on_skill({"success":true,"id":"WITHDRAW"})
 for i in range(8):step()
 check(records.state().guard.done and hospital.data.holder=="" and app.rules.hp==100 and app.rules.sp==100,"successful pre-contact withdrawal consumes one missed attempt without damage")

 fixture(false,true)
 accepted_report()
 while records.state().guard.phase!="reach":step()
 records.on_skill({"success":false,"id":"WITHDRAW"})
 for i in range(8):step()
 check(hospital.data.holder=="guard" and app.rules.hp==95,"resisted withdrawal cannot invent an evasion before contact")

 fixture(false,true)
 accepted_report()
 while records.state().guard.phase!="reach":step()
 app.hero_pos+=Vector2(1,0)
 for i in range(8):step()
 check(records.state().guard.done and hospital.data.holder=="" and app.rules.hp==100,"actual displacement out of reach ends one missed grab without damage")

 fixture(false,true)
 reach_grip();app.layout.route_open=false
 var before_position:Vector2=app.hero_pos;step()
 check(records.state().guard.done and hospital.data.holder=="" and app.hero_pos==before_position,"unavailable drag path releases in place instead of pulling through a wall")

 fixture(false,true)
 reach_grip();hospital.config.test_parameters.walk_speed=0.01
 for i in range(62):step()
 check(records.state().guard.done and hospital.data.holder=="" and app.hero_pos.distance_to(Vector2.ZERO)>1,"six-second maximum releases even when the exit has not yet been reached")

 fixture(false,true)
 reach_grip();before_position=hospital.position("guard");app.room_id="clinic";app.hero_pos=Vector2(4,4);step()
 check(hospital.data.holder=="" and app.hero_pos==Vector2(4,4) and hospital.position("guard")==before_position,"invalid cross-room state never teleports either actor to repair a grip")

 fixture(false,true)
 app.rules.hp=5;reach_grip()
 var living_line:bool=false
 for line in app.dialogue_queue:
  if line.text=="松手！我自己会走。":living_line=true
 check(app.rules.hp==0 and hospital.data.holder=="" and not app.rules.gripped,"fatal grip stops dragging and clears the shared holder immediately")
 check(not living_line,"fatal grip cannot present surviving pain dialogue")

 fixture(false,true)
 accepted_report();app.hero_pos=Vector2(4,4);app.layout.line_clear=false
 for i in range(20):step()
 check(records.state().guard.done and hospital.data.holder=="" and app.rules.hp==100,"lost target is sought only at last-seen point, not updated through walls")

 fixture(false,true,true)
 records.write_report(5)
 # Align actual report reception with patient visibility. Before reception an
 # unrelated patient event may legitimately start; after reception hero wins.
 records.state().report.elapsed=float(hospital.config.test_parameters.handoff)-0.01
 for i in range(20):
  step(0.02)
  if records.state().report.phase=="accepted":break
 check(records.state().guard.target=="hero","received protagonist report has priority over same-node patient removal")

 fixture(false,true,true)
 step()
 check(records.state().patient_silenced and records.state().guard.target=="patient" and not records.state().patient_gone,"real guard encounter silences patient but does not declare early removal")
 for i in range(15):
  step()
  if hospital.actor("patient").phase=="guard_held":break
 check(hospital.actor("patient").phase=="guard_held" and hospital.data.holder=="","patient grip uses the same guard without gripping the protagonist")
 records.on_skill({"success":true,"id":"STARTLE"})
 check(hospital.actor("patient").phase=="guard_held","protagonist skill cannot release an already-held patient")
 for i in range(100):
  app.hero_pos=hospital.position("patient")
  step()
  if records.state().patient_gone:break
 check(records.state().patient_gone and hospital.actor("patient").phase=="gone","patient disappears only after actual movement reaches the existing exit")
 check("patient_removed_seen" in app.rules.known and app.rules.awakening_receipts.is_empty(),"complete explicit witness fixture records removal without formal awakening")

 fixture(false,true,true);app.room_id="clinic"
 var remote_dialogue:bool=false
 for i in range(100):
  step()
  if not app.dialogue_queue.is_empty():remote_dialogue=true
  if records.state().patient_gone:break
 check(records.state().patient_gone and not "patient_removed_seen" in app.rules.known and not remote_dialogue,"unseen removal persists as fact without remote dialogue or protagonist knowledge")

 fixture()
 records.state();app.rules.owners.case_removal="archive_storage"
 records.on_search_complete(5,false)
 check(not "case_removal" in app.rules.known,"collected unread file cannot grant knowledge when its old point completes")
 app.rules.owners.case_removal="hero";records.on_search_complete(5,false)
 check("case_removal" in app.rules.known and app.rules.owners.case_removal=="hero","already-owned file remains readable and is never forcibly reclaimed")
 records.on_search_complete(7,false)
 check("complaint_changed" in app.rules.known,"contradiction requires actual reading of both documents")
 records.on_search_complete(6,false)
 check(not "laundry_handoff_complete" in app.rules.known,"unfinished laundry transport cannot be read as a completed handoff")
 hospital.data.bag="removed";records.on_search_complete(6,false)
 check("laundry_handoff_complete" in app.rules.known and "removal_record" in app.rules.known,"actual later completion can be checked and removal-page identity is exposed to doctor rules")

 var folder:String="res://../docs/validation/takeover_20261016/hospital-records-unit"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":false,"scope":"isolated real hospital APIs with explicit open-floor/LOS/actor fixtures; records/receipts/JSON/contact logic only, not engine navigation or full hospital acceptance"},"  "));file.close()
 print("HOSPITAL_RECORDS_UNIT %d passed %d failed"%[passes.size(),failures.size()])
 quit(0 if failures.is_empty() else 1)
