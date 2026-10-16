extends "res://tests/hospital_check.gd"
## Finite, explicit actor/location/skill fixtures through real campaign APIs.
## Every observed interval advances at most one 0.025s step before inspecting
## dialogue; remote lines cannot disappear inside a multi-step helper.
var observed_lines:Array=[]
var cross_room_patient_grip:bool=false

func edge_step() -> void:
 clear_lines()
 app.advance_world(0.025)
 for line in app.dialogue_queue:observed_lines.append(line.duplicate(true))
 var state:Dictionary=app.hospital.data.get("records_state",{})
 var guard:Dictionary=state.get("guard",{})
 if guard.get("target","")=="patient" and guard.get("phase","") in ["reach","drag"]:
  if app.hospital.actor("guard").room!=app.hospital.actor("patient").room:cross_room_patient_grip=true

func edge_for(seconds:float) -> void:
 for i in range(ceili(seconds/0.025)):edge_step()

func edge_until(predicate:Callable,seconds:float=20.0) -> bool:
 for i in range(ceili(seconds/0.025)):
  if predicate.call():return true
  edge_step()
 return predicate.call()

func edge_fixture(room:String="pharmacy") -> void:
 hospital_fixture(room);observed_lines.clear();cross_room_patient_grip=false

func record_present(prefix:String) -> bool:
 for entry in app.rules.institutional_records:
  if str(entry.get("id","")).begins_with(prefix):return true
 return false

func prepare_cup(nurse:bool=true) -> bool:
 pharmacy_fixture(nurse);observed_lines.clear();cross_room_patient_grip=false
 # Nurse has completed her existing ward check; the actual prescription,
 # mixing and cup transfer still execute through their ordinary timed nodes.
 app.hospital.data.nurse_checked=true
 return edge_until(func():return app.hospital.data.body.get("kind","")=="raise_cup",8.0)

func refuse_cup() -> void:
 give_skill("GUT");cast("GUT");clear_lines();observed_lines.clear()

func finish_suite() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"matrix":matrix,
  "scope":"formal campaign/contact/navigation/JSON with explicit actor, room, position, blocker, prior nurse-check and skill fixtures; every observed delta is 0.025 seconds with dialogue inspected before the next clear; not natural probability coverage, human play, final art or subjective audio acceptance"},"  "));file.close()
 print("HOSPITAL_EDGES_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/takeover_20261016/hospital-edges"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="医院边界验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 check(prepare_cup(),"actual prescription/mix/contact reaches separate raise-cup window before refusal fixture")
 refuse_cup()
 check(app.hospital.data.has("false_sticker") and app.hospital.data.refused and not app.hospital.data.swallowed,"actual GUT refusal creates pending nurse sticker, not drug consumption")
 # Explicit room departure fixture immediately after refusal; no forged
 # completed sticker, timer or witness state is supplied.
 app.enter_room("clinic");app.session.data.exploration_boundary=true;clear_lines();observed_lines.clear()
 check(edge_until(func():return not app.hospital.data.has("false_sticker"),4.0),"nurse physically finishes refused-cup sticker while protagonist is in another room")
 check(record_present("false_medicine:") and receipt("false_sticker:"+app.hospital.current_visit()),"remote sticker creates actual institutional record and one physical receipt")
 check(not "false_medicine_seen" in app.rules.known and observed_lines.is_empty(),"unwitnessed sticker gives neither complete-view knowledge nor cross-room dialogue")

 check(prepare_cup(),"second refusal fixture obtains an actual cup")
 refuse_cup();edge_for(0.2)
 check(app.hospital.data.has("false_sticker") and float(app.hospital.data.false_sticker.left)>0,"visible initial sticker interval cannot finish prematurely")
 app.enter_room("clinic");app.session.data.exploration_boundary=true;edge_step()
 check(app.hospital.data.has("false_sticker") and not app.hospital.data.false_sticker.witness_complete,"one actual unseen interval permanently breaks full-view evidence")
 check(roundtrip() and app.hospital.data.has("false_sticker") and not app.hospital.data.false_sticker.witness_complete,"actual JSON preserves incomplete continuous witness")
 var placement:Array=app.hospital.data.false_sticker.pos.duplicate()
 app.enter_room("pharmacy");app.hero_pos=Vector2(float(placement[0]),float(placement[1]));app.session.data.exploration_boundary=true
 check(edge_until(func():return not app.hospital.data.has("false_sticker"),4.0),"returning protagonist observes real completion after interrupted view")
 check(record_present("false_medicine:") and not "false_medicine_seen" in app.rules.known,"return and completion cannot retroactively reconstruct the missing sticker view")

 check(prepare_cup(),"third refusal fixture obtains an actual cup for reach/occlusion checks")
 refuse_cup()
 var cup_at:=Vector2(float(app.hospital.data.cup_place.pos[0]),float(app.hospital.data.cup_place.pos[1]))
 app.hospital.actor("nurse").pos=app.hospital.xy(cup_at+Vector2(1.0,0));app.hospital.actor("nurse").route=[]
 var left:float=float(app.hospital.data.false_sticker.left)
 edge_for(0.2)
 check(app.hospital.data.has("false_sticker") and is_equal_approx(float(app.hospital.data.false_sticker.left),left),"nurse outside cup contact range approaches without advancing sticker timer")
 app.hospital.actor("nurse").pos=app.hospital.xy(cup_at+Vector2(0.6,0));app.hospital.actor("nurse").route=[]
 app.layout.movable_blockers.append(Rect2(cup_at.x+0.25,0,0.08,app.layout.SIZE.y))
 edge_for(1.0)
 check(app.hospital.data.has("false_sticker") and is_equal_approx(float(app.hospital.data.false_sticker.left),left) and not record_present("false_medicine:"),"LOS wall blocks nearby nurse contact and cannot pre-apply institutional sticker")
 app.layout.movable_blockers.clear();app.hospital.actor("nurse").route=[]
 check(edge_until(func():return not app.hospital.data.has("false_sticker"),8.0) and record_present("false_medicine:"),"restored physical access permits actual approach and sticker completion")
 await capture("01_sticker_after_access_restored")

 edge_fixture("clinic");spawn_actor("porter",Vector2(3.05,1.3),"ward")
 app.hospital.data.bag_order=true;app.rules.owners.hospital_laundry_manifest="ward_tray"
 check(edge_until(func():return app.hospital.data.bag=="removed",20.0),"unobserved porter actually lifts and removes remote ward laundry bag")
 check(receipt("bag_removed") and observed_lines.is_empty(),"every remote laundry step produces no dialogue in another room")
 edge_fixture("clinic")
 spawn_actor("guide",Vector2(2.4,1.4),"lobby");spawn_actor("wheelchair",Vector2(2.8,1.4),"lobby");spawn_actor("porter",Vector2(3.15,1.4),"lobby")
 check(edge_until(func():return app.hospital.data.get("wheelchair_gone",false),35.0),"unobserved wheelchair paperwork/frame/fingers/exit finishes physically in remote lobby")
 check(receipt("patient_transport") and observed_lines.is_empty() and not "forced_transfer_seen" in app.rules.known,"every remote wheelchair step gives no cross-room lines or fabricated complete witness")

 check(prepare_cup(false),"ordinary swallowing fixture receives actual full cup")
 check(edge_until(func():return app.hospital.data.swallowed,2.0),"ordinary full one-second raise completes actual swallow")
 var sp_after:int=app.rules.sp
 check(app.rules.owners.get("hospital_cup","")=="hero" and not app.hospital.data.get("cup_full",true),"swallow leaves the unique empty cup owned by protagonist")
 check(roundtrip() and app.rules.owners.get("hospital_cup","")=="hero" and not app.hospital.data.get("cup_full",true),"actual JSON preserves protagonist empty-cup ownership")
 edge_for(2.0)
 check(app.rules.sp==sp_after and receipt("swallow"),"continued frames cannot consume an empty cup or repeat medicine SP loss")
 var legacy:Dictionary=app.snapshot_data()
 legacy.rules.owners.hospital_cup="empty_cup";legacy.hospital_state.erase("cup_full")
 check(app.store.save_snapshot(legacy).ok,"explicit old empty-cup representation is written through actual checksummed JSON")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data) and app.rules.owners.get("hospital_cup","")=="hero" and not app.hospital.data.get("cup_full",true),"old empty-cup JSON migrates to same protagonist owner with empty content")
 edge_for(2.0)
 check(app.rules.sp==sp_after and app.hospital.data.swallowed,"migrated empty cup cannot replay medicine effects")
 await capture("02_empty_cup_retained")

 for listener in ["nurse","guide","doctor","assistant","pharmacist"]:
  edge_fixture("lobby");spawn_actor("patient");spawn_actor(listener,app.hero_pos+Vector2(-0.35,0))
  app.hospital.data.registered=true;app.hospital.data.nurse_checked=true;app.hospital.data.healed=true;app.hospital.data.exam_done=true
  edge_step()
  check(not receipt("line:PATIENT"),"patient with nearby "+listener+" does not issue ordinary private warning")
  app.hospital.actor(listener).phase="gone";edge_step()
  check(receipt("line:PATIENT"),"same patient alone after "+listener+" leaves may issue original private warning")

 for variant in ["visible_assistant","no_assistant","resisted"]:
  edge_fixture("clinic");app.hero_pos=app.layout.furniture[3].at;spawn_actor("doctor")
  if variant!="no_assistant":spawn_actor("assistant",app.hero_pos+Vector2(-0.3,0))
  check(edge_until(func():return app.hospital.actor("doctor").phase=="grab",2.0),"doctor reaches actual pre-needle grab for withdrawal / "+variant)
  edge_for(0.35);give_skill("WITHDRAW")
  if variant=="resisted":app.rules.skill_states.WITHDRAW.resistance=app.rules.skill_states.WITHDRAW.power
  var neurons:int=app.rules.neurons;var submitted:Dictionary=cast("WITHDRAW")
  check(submitted.get("ok",false) and app.rules.neurons==neurons-int(app.rules.spec("WITHDRAW").cost),"ordinary withdrawal submission pays once / "+variant)
  check(record_present("refusal:")==(variant=="visible_assistant"),"only effective pre-needle withdrawal seen by assistant records refusal / "+variant)
  edge_for(0.2)
  check((app.rules.hp==100)==(variant!="resisted"),"actual withdrawal avoids needle only when effective / "+variant)

 edge_fixture("clinic");app.hero_pos=app.layout.furniture[3].at;spawn_actor("doctor");spawn_actor("assistant",app.hero_pos+Vector2(-0.3,0))
 check(edge_until(func():return app.hospital.actor("doctor").phase=="sample",2.0),"post-contact negative case starts only after actual needle and established hold")
 give_skill("WITHDRAW");var post_neurons:int=app.rules.neurons;var post:Dictionary=cast("WITHDRAW")
 check(not post.get("ok",false) and app.rules.neurons==post_neurons and not record_present("refusal:"),"already-established medical hold rejects late withdrawal without fee or invented prior refusal")

 edge_fixture("pharmacy")
 spawn_actor("patient",Vector2(2.8,1.4),"lobby")
 var inside:Vector2=app.door_point_for("office","lobby")
 spawn_actor("guard",inside+Vector2(0.3,0),"office")
 var patient_initial:Vector2=app.hospital.position("patient")
 check(edge_until(func():return app.hospital.records.state().guard.get("target","")=="patient",20.0),"ordinary patient walk from lobby center reaches office doorway sight of ordinary office guard")
 check(app.hospital.position("patient").distance_to(patient_initial)>0.1 and app.hospital.actor("guard").room=="office" and app.hospital.records.state().guard.phase=="approach","doorway discovery requires actual patient movement and does not remotely reach or grip")
 var guard_before:Dictionary=app.hospital.records.state().guard.duplicate(true)
 var patient_before:Vector2=app.hospital.position("patient")
 check(roundtrip() and JSON.stringify(app.hospital.records.state().guard)==JSON.stringify(guard_before) and app.hospital.position("patient").distance_to(patient_before)<0.000001,"pursuit actual JSON retains doorway target and patient position without teleport")
 var clock:float=app.hospital.data.clock;var guard_at:Vector2=app.hospital.position("guard")
 await frames(12)
 check(app.hospital.data.clock==clock and app.hospital.position("guard")==guard_at,"manual pause freezes the doorway pursuit")
 check(edge_until(func():return app.hospital.records.state().guard.phase=="reach",12.0),"guard traverses actual office doorway before starting patient reach")
 check(app.hospital.actor("guard").room=="lobby" and not receipt("patient_guard_grip") and not cross_room_patient_grip,"same-room reach has no premature cross-room grip receipt")
 check(edge_until(func():return receipt("patient_guard_grip"),3.0),"same-room preparation completes one actual patient grip")
 # Explicit late-observer fixture for the rendered paired hold. It does not
 # retroactively make the previously unseen grip a complete witnessed event.
 app.enter_room("lobby");clear_lines();app.hero_pos=app.hospital.position("patient")+Vector2(0.55,0.55)
 edge_for(0.3);await capture("03a_actual_paired_patient_drag")
 check(edge_until(func():return app.hospital.data.get("patient_gone",false),20.0),"same guard physically takes patient to existing exit before removal")
 check(receipt("patient_removed") and not cross_room_patient_grip and not app.rules.gripped,"patient removal has one actual receipt and never grips remote protagonist")
 check(not "patient_removed_seen" in app.rules.known,"late arrival at the visible drag never invents a complete witnessed removal")
 await capture("03_patient_actual_removal")

 edge_fixture("office");app.hero_pos=app.layout.furniture[5].at;spawn_actor("archivist",app.hero_pos+Vector2(-0.35,0))
 app.target_index=5;app.rules.begin_search("office:5")
 check(edge_until(func():return not app.hospital.records.state().report.is_empty(),8.0),"priority case builds actual continued-search report")
 spawn_actor("guard",app.hospital.position("archivist")+Vector2(0.3,0))
 check(edge_until(func():return app.hospital.records.state().report.get("phase","")=="accepted",25.0),"priority case physically hands report to existing guard")
 spawn_actor("patient",app.hospital.position("guard")+Vector2(0.3,0),"office");edge_step()
 check(app.hospital.records.state().guard.target=="hero" and not receipt("patient_guard_grip"),"already-accepted protagonist report retains priority over newly visible patient")
 finish_suite()
