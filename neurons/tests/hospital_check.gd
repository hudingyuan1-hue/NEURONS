extends "res://tests/feedback_check.gd"
## Real campaign/hospital/navigation/JSON handlers with finite actor/contact
## fixtures. No final-art, subjective sound or untested whole-game claim.
const Session=preload("res://scripts/core/campaign_session.gd")
var matrix:Array=[]

func check(value:bool,label:String) -> void:
 super.check(value,label)
 if value or app==null:return
 var actors:Dictionary={}
 for id in app.hospital.data.actors:
  if not app.hospital.present(id):continue
  var actor:Dictionary=app.hospital.actor(id)
  actors[id]={"phase":actor.phase,"room":actor.room,"position":actor.pos,"route":actor.route,"walkable":app.hospital.layout_for(str(actor.room)).walkable(app.hospital.position(id))}
 var diagnostic:Dictionary={"failed":label,"hero_room":app.room_id,"hero_position":[app.hero_pos.x,app.hero_pos.y],"hero_walkable":app.layout.walkable(app.hero_pos),"hero_action":app.action_phase,"body":app.hospital.data.body,"actors":actors,"hp":app.rules.hp,"sp":app.rules.sp,"control_ms":app.rules.control_ms,"control_left":app.rules.control_left,"medicine_stop":app.hospital.data.medicine_stop,"effects":app.rules.effects,"hospital":app.hospital.data}
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_%02d.json"%failures.size()),FileAccess.WRITE)
 file.store_string(JSON.stringify(diagnostic,"  "));file.close()

func hospital_fixture(room:String="ward") -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=[1,2];app.session.new_attempt(2,app.rng)
 app.rules.actual_attempt=1;app.rules.search_limit=12
 app.rules.owners.key=app.session.data.key_owner
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=true
 app.hospital.config=JSON.parse_string(FileAccess.get_file_as_string("res://data/hospital.json"))
 app.hospital.start_attempt()
 # Isolate the event under test from random batches and independent autonomous
 # searches. Explicit scheduling/exit sections below restore those conditions.
 for group in app.hospital.data.groups:app.hospital.data.groups[group].drawn=true
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.enter_room(room);app.hero_pos=Vector2(2.7,1.4);app.hero_route=PackedVector2Array()
 app.session.data.exploration_boundary=true
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func spawn_actor(id:String,at:Vector2=Vector2.INF,room:String="") -> void:
 var actor:Dictionary=app.hospital.actor(id)
 actor.phase="idle";actor.room=app.room_id if room.is_empty() else room
 var side:float=-1.0 if app.hero_pos.x>2.8 else 1.0
 actor.pos=app.hospital.xy(app.hero_pos+Vector2(0.35*side,0) if at==Vector2.INF else at)
 actor.route=[];actor.elapsed=0.0

func hospital_step(seconds:float=0.025) -> void:
 var left:float=seconds
 while left>0.000001:
  clear_lines();var delta:float=minf(0.025,left)
  app.advance_world(delta);left-=delta

func hospital_until(predicate:Callable,seconds:float=30.0) -> bool:
 var left:float=seconds
 while left>0.000001:
  if predicate.call():return true
  hospital_step();left-=0.025
 return predicate.call()

func roundtrip() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var loaded:Dictionary=app.store.load_snapshot()
 return loaded.ok and app.restore_snapshot(loaded.data)

func receipt(id:String) -> bool:
 return app.hospital.data.receipts.has("hospital:%d:%s"%[app.rules.actual_attempt,id])

func seed_for_range(low:float,high:float) -> int:
 var probe:=RandomNumberGenerator.new()
 for value in range(10000):
  probe.seed=value;var roll:float=probe.randf()
  if roll>=low and roll<high:return value
 return 0

func delivered_prescription() -> void:
 # A prescription contact fixture is independent of sampling, as S3 requires.
 # It still runs the actual timed physical transfer and ownership receipt.
 spawn_actor("doctor");app.hospital.data.exam_done=true
 app.hospital.set_body("prescription","doctor")
 hospital_until(func():return app.rules.owners.get("hospital_prescription","")=="hero",3.0)

func pharmacy_fixture(nurse:bool=false) -> void:
 hospital_fixture("clinic");delivered_prescription();app.enter_room("pharmacy")
 clear_lines();app.hero_pos=Vector2(2.7,1.4);app.session.data.exploration_boundary=true
 spawn_actor("pharmacist")
 app.hospital.data.registered=true;app.hospital.data.healed=true
 if nurse:spawn_actor("nurse",app.hero_pos+Vector2(-0.35,0))

func continue_live_line() -> void:
 await frames(6)
 for down in [true,false]:
  var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=down
  Input.parse_input_event(key);await frames(2)

func record_representative() -> void:
 hospital_fixture("clinic");app.hero_pos=app.layout.furniture[3].at
 spawn_actor("doctor");spawn_actor("assistant",app.hero_pos+Vector2(-0.3,0));give_skill("KNEE")
 var before:int=app.rules.neurons;var stage:int=0;var frames_started:int=Engine.get_process_frames()
 var started:float=app.rules.world_time;var needle_time:float=-1.0
 var observed:Array=[];var old_phase:String=""
 app.paused_manual=false;get_window().grab_focus()
 for i in range(900):
  var phase:String=str(app.hospital.actor("doctor").phase)
  if phase!=old_phase:
   observed.append({"frame":Engine.get_process_frames()-frames_started,"world_time":app.rules.world_time,"doctor_phase":phase,"holder":app.hospital.data.holder,"hp":app.rules.hp,"neurons":app.rules.neurons})
   old_phase=phase
  if not app.dialogue_queue.is_empty():await continue_live_line();continue
  if stage==0 and phase=="sample":
   needle_time=app.rules.world_time;stage=1
   await capture("08_live_needle_contact")
  elif stage==1 and app.rules.world_time-needle_time>=0.3:
   app.hero_facing=(app.hospital.position("doctor")-app.hero_pos).normalized()
   app.open_neuron_menu();await click(app.menu.nodes.KNEE);stage=2
  elif stage==2 and app.hospital.data.exam_done:
   await capture("09_live_knee_release");stage=3
  elif stage==3 and app.rules.owners.get("hospital_prescription","")=="hero":
   await capture("10_live_prescription");await frames(30);stage=4;break
  await frames(1)
 app.paused_manual=true
 check(stage==4,"continuous normal-process doctor/CRT/rescue/prescription segment reaches real completion")
 check(app.rules.hp==95 and receipt("sample_interrupted") and not app.hospital.data.sample,"continuous segment retains real needle injury and records actual interrupted sample")
 check(app.rules.neurons==before-int(app.rules.spec("KNEE").cost) and not app.rules.gripped,"continuous mouse CRT pays once and frees only after actual knee contact")
 check(app.rules.owners.get("hospital_prescription","")=="hero","continuous segment receives the independent prescription at contact")
 matrix.append({"recording":true,"initial_fixtures":"bedside clinic geometry, two existing placeholder actors, unlocked KNEE and 50N; ordinary campaign process afterwards; real Enter/CRT mouse events, no manual world ticks","start_frame":frames_started,"frames":Engine.get_process_frames()-frames_started,"world_seconds":app.rules.world_time-started,"observations":observed,"audio":"not subjectively auditioned"})

func finish_suite() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"matrix":matrix,"scope":"formal campaign with explicit actor/position/RNG/body-phase fixtures; actual hospital clock/contact/navigation, CRT mouse and JSON; recording branch uses ordinary process after one stated initial setup; no human full playthrough, final-art or subjective sound acceptance"},"  "));output.close()
 print("HOSPITAL_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/takeover_20261016/hospital"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="医院有限规则验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if "--hospital-record" in OS.get_cmdline_user_args():
  await record_representative();finish_suite();return

 hospital_fixture()
 check(app.hospital.data.actors.size()==10 and app.hospital.config.groups.size()==6,"hospital has ten unique identities in six independent scheduling groups")
 app.hospital.data.groups.nurse={"drawn":false,"pending":false,"checks":0}
 var middle_seed:int=seed_for_range(0.5,0.7)
 app.rng.seed=middle_seed;app.hospital.on_enter("","ward")
 check(app.hospital.data.groups.nurse.checks==1 and not app.hospital.data.groups.nurse.pending,"first-attempt nurse roll above 50 percent remains absent")
 hospital_fixture();app.rules.actual_attempt=5
 app.hospital.data.groups.nurse={"drawn":false,"pending":false,"checks":0}
 app.rng.seed=middle_seed;app.hospital.on_enter("","ward")
 check(app.hospital.data.groups.nurse.pending,"same actual roll succeeds at fifth-attempt 70 percent cap")
 hospital_fixture();app.hospital.data.groups.nurse={"drawn":false,"pending":false,"checks":0}
 app.rng.seed=seed_for_range(0.7,1.0);app.hospital.on_enter("","ward")
 app.hospital.on_enter("ward","lobby");app.hospital.data.clock=19.99;app.hospital.on_enter("lobby","ward")
 check(app.hospital.data.groups.nurse.checks==1,"return before twenty game seconds cannot add a scheduling roll")
 app.hospital.data.clock=20;app.rng.seed=seed_for_range(0.25,0.5);app.hospital.on_enter("lobby","ward")
 check(app.hospital.data.groups.nurse.checks==2 and not app.hospital.data.groups.nurse.pending,"legal return uses half initial chance, not the initial fifty percent")
 app.hospital.on_enter("ward","lobby");app.hospital.data.clock=40;app.rng.seed=seed_for_range(0.7,1.0);app.hospital.on_enter("lobby","ward")
 app.hospital.on_enter("ward","lobby");app.hospital.data.clock=60;app.hospital.on_enter("lobby","ward")
 check(app.hospital.data.groups.nurse.checks==3,"a group cannot roll more than three times per actual attempt")
 app.hospital.data.groups.nurse.pending=true;app.hospital.data.groups.nurse.drawn=true
 app.hero_pos=Vector2(4.4,0.35);app.hospital.spawn_pending()
 check(app.hospital.data.groups.nurse.pending and not app.hospital.present("nurse"),"pending arrival does not spawn against the protagonist at the doorway")
 app.hero_pos=Vector2(2.7,1.4);app.hospital.spawn_pending()
 check(app.hospital.present("nurse") and not app.hospital.data.groups.nurse.pending,"pending nurse enters when the physical doorway is clear")

 hospital_fixture("lobby")
 for group in ["lobby","patient"]:app.hospital.data.groups[group].pending=true
 app.hospital.spawn_pending()
 check(app.hospital.present("guide") and app.hospital.present("wheelchair") and app.hospital.present("porter") and app.hospital.data.groups.patient.pending,"required trio enters as one batch while next group remains pending")
 for id in ["guide","wheelchair","porter"]:app.hospital.actor(id).pos=[2.4,2.5]
 app.hospital.data.clock=9.99;app.hospital.spawn_pending()
 check(not app.hospital.present("patient"),"same doorway batch cannot repeat before ten game seconds")
 app.hospital.data.clock=10;app.hospital.spawn_pending()
 check(app.hospital.present("patient"),"clear doorway accepts another group after ten game seconds")

 hospital_fixture();app.rules.hp=80;spawn_actor("nurse");hospital_step()
 check(app.hospital.data.body.get("kind","")=="bandage" and app.rules.hp==80,"injured protagonist begins actual nurse approach/contact without immediate healing")
 hospital_step(1.0);var partial:float=app.hospital.data.bandage
 check(partial>0.9 and partial<1.1 and app.rules.hp==80,"partial bandaging accumulates real treatment time without early income")
 cast("SKIN");hospital_step(0.6)
 check(not app.hospital.data.healed and app.hospital.data.bandage>=partial,"actual neural interruption keeps cumulative completed bandage time")
 check(hospital_until(func():return app.hospital.data.healed,4.0),"nurse resumes and reaches exactly one three-second treatment")
 check(app.rules.hp==90 and receipt("bandage"),"completed treatment heals ten HP once and owns its receipt")
 var clock:float=app.rules.world_time;var nurse_state:Dictionary=app.hospital.data.duplicate(true)
 await frames(12)
 check(app.rules.world_time==clock and app.hospital.data==nurse_state,"manual pause freezes hospital clock, treatment and actor routes")
 check(roundtrip() and app.hospital.data.healed and app.rules.hp==90,"actual JSON preserves completed treatment and does not repay healing")
 hospital_step(4.0)
 check(app.rules.hp==90,"nurse and later frames cannot heal a second time this attempt")
 await capture("01_nurse_treatment")

 hospital_fixture();spawn_actor("nurse");hospital_step()
 check(app.hospital.data.body.get("kind","")=="nurse_register" and app.hospital.data.bandage==0,"full HP bypasses bandaging and proceeds to number verification")
 check(hospital_until(func():return app.hospital.data.nurse_checked,2.0),"real nurse number-check completes without treatment requirement")
 check(not app.hospital.data.registered and not app.rules.owners.has("hospital_ticket") and app.rules.owners.get("hospital_laundry_manifest","")=="ward_tray" and not app.hospital.data.healed and app.rules.hp==100,"nurse check delivers a laundry manifest without inventing guide registration or consuming healing")
 check(app.hospital.data.actors.size()==10 and hospital_until(func():return app.hospital.actor("nurse").room=="pharmacy",20.0),"the existing nurse actually walks between rooms instead of being cloned")

 hospital_fixture("lobby");spawn_actor("guide");hospital_step()
 check(app.hospital.data.body.get("kind","")=="registration" and not app.hospital.data.registered,"actual guide begins a separate registration contact")
 check(hospital_until(func():return app.hospital.data.registered,2.0) and app.rules.owners.get("hospital_ticket","")=="hero","only completed guide registration delivers the hero ticket")
 check(not app.hospital.data.nurse_checked and not app.rules.owners.has("hospital_laundry_manifest"),"guide ticket never substitutes for a nurse check or laundry order")

 hospital_fixture("clinic");app.hero_pos=app.layout.furniture[3].at;spawn_actor("doctor");spawn_actor("assistant",app.hero_pos+Vector2(-0.3,0));hospital_step()
 check(app.hospital.data.body.get("kind","")=="exam" and app.rules.hp==100,"doctor invites examination before actual needle contact")
 check(hospital_until(func():return app.hospital.actor("doctor").phase=="grab",2.0),"doctor physically approaches before visible grab preparation")
 hospital_step(0.45)
 check(app.rules.hp==100 and not app.rules.gripped,"unfinished needle/grab windup cannot pre-charge damage")
 check(hospital_until(func():return app.hospital.actor("doctor").phase=="sample",1.0),"needle actually enters and begins sampling")
 check(app.rules.hp==95 and app.rules.gripped and receipt("needle") and not app.hospital.data.sample,"one actual needle contact costs five HP but is not yet a valid sample")
 hospital_step(1.9)
 check(not app.hospital.data.sample,"sampling cannot complete before two full seconds after needle entry")
 check(hospital_until(func():return app.hospital.data.sample,0.3),"two-second sampling creates one valid sample")
 check(app.hospital.data.exam_done and not app.rules.gripped and receipt("sample"),"successful sample releases grip and ends this encounter")
 check(hospital_until(func():return app.rules.owners.get("hospital_prescription","")=="hero",2.0),"prescription uses its own later actual transfer")
 var before_hp:int=app.rules.hp;hospital_step(3.0)
 check(app.rules.hp==before_hp and app.hospital.data.sample,"passing the same doctor cannot repeat needle damage or sampling")
 await capture("02_valid_sample_prescription")

 hospital_fixture("clinic");app.hero_pos=app.layout.furniture[3].at;spawn_actor("doctor");hospital_step()
 app.hospital.config.test_parameters.walk_speed=0.1;app.hospital.actor("doctor").pos=[1.8,3.5]
 hospital_step(4.05)
 check(app.hospital.data.exam_done and not app.rules.gripped and not app.hospital.data.sample,"four-second maximum ends unreachable examination without locking the world")
 check(app.rules.hp==100 and hospital_until(func():return app.rules.owners.get("hospital_prescription","")=="hero",45.0),"no needle means no damage; independent prescription can still be handed over")

 hospital_fixture("clinic");app.hero_pos=app.layout.furniture[3].at;spawn_actor("doctor");spawn_actor("assistant",app.hero_pos+Vector2(-0.3,0));hospital_step()
 hospital_until(func():return app.hospital.actor("doctor").phase=="sample",2.0);hospital_step(0.3)
 give_skill("KNEE");app.hero_facing=(app.hospital.position("doctor")-app.hero_pos).normalized()
 var paid:int=app.rules.neurons;app.paused_manual=false;app.open_neuron_menu();get_window().grab_focus()
 await click(app.menu.nodes.KNEE)
 var kicked:bool=await await_live(func():return app.hospital.data.exam_done,3.0)
 app.paused_manual=true
 check(kicked and receipt("sample_interrupted") and not app.hospital.data.sample,"real CRT knee reaches actual doctor contact and interrupts unfinished sample")
 check(app.rules.hp==95 and app.rules.neurons==paid-int(app.rules.spec("KNEE").cost),"interruption retains needle damage and charges one ordinary neural fee")
 check(not app.rules.gripped and hospital_until(func():return app.rules.owners.get("hospital_prescription","")=="hero",3.0),"actual doctor release permits independent prescription transfer")
 await capture("03_doctor_actual_knee")

 hospital_fixture("clinic");spawn_actor("doctor");spawn_actor("nurse",app.hero_pos+Vector2(-0.3,0));app.rules.hp=5
 app.hospital.set_body("bandage","nurse");app.hospital.data.bandage=2.99
 app.hospital.actor("doctor").phase="grab";app.hospital.actor("doctor").left=0.01
 hospital_step(0.01)
 check(app.rules.hp==0 and not app.hospital.data.healed and not app.hospital.data.sample,"fatal needle contact wins over same-tick completed medical healing")

 hospital_fixture("pharmacy");spawn_actor("pharmacist");hospital_step(1.0)
 check(app.hospital.data.body.is_empty() and not app.hospital.data.dispensed,"no prescription cannot begin pharmacy dispensing or block searching")
 app.rules.owners.hospital_prescription="hero";app.hospital.data.prescription_visit="mismatched-visit";hospital_step(1.0)
 check(not app.hospital.data.dispensed and app.rules.owners.hospital_prescription=="hero","wrong-number prescription remains owned and cannot begin dispensing")

 pharmacy_fixture();hospital_step();give_skill("DRYMOUTH");paid=app.rules.neurons;cast("DRYMOUTH")
 hospital_step(2.54)
 check(app.rules.owners.hospital_prescription=="hero" and not app.hospital.data.dispensed,"DRYMOUTH adds two seconds only to unfinished prescription handoff")
 hospital_step(0.03)
 check(app.rules.owners.hospital_prescription=="pharmacist" and app.hospital.data.dispensed and app.rules.neurons==paid-1,"actual prescription receipt transfers once and pays configured neural fee")
 check(hospital_until(func():return app.hospital.data.body.get("kind","")=="cup_transfer",2.0),"real mixing finishes before a separately owned cup handoff")
 check(app.rules.owners.get("hospital_cup","")=="pharmacist" and not app.hospital.data.swallowed,"unreceived cup cannot mean swallowed or drug damage")
 cast("DRYMOUTH");hospital_step(2.54)
 check(app.rules.owners.hospital_cup=="pharmacist" and app.rules.sp==100,"unfinished cup handoff retains drug and mental state through its own delay")
 hospital_step(0.03)
 check(app.rules.owners.hospital_cup=="hero" and app.hospital.data.body.kind=="raise_cup","actual cup reception begins a separate raise-to-mouth window")
 hospital_step(0.99)
 check(not app.hospital.data.swallowed and app.rules.sp==100,"cup cannot swallow before one full second of raising")
 hospital_step(0.02)
 check(app.hospital.data.swallowed and app.rules.sp==85 and app.rules.hp==100 and app.hospital.data.medicine_stop>0.99,"actual swallow commits fifteen SP loss and independent one-second bodily stop")
 # Explicit overlap fixture tests the shared clock exclusion, rather than
 # claiming the unavailable CONTROL button can start during medicine stop.
 var control_ms:int=app.rules.control_ms;app.rules.control_left=0.25;hospital_step(0.26)
 check(app.rules.control_ms==control_ms and app.rules.control_left<=0,"medicine bodily stop consumes an existing control window without effective control milliseconds")
 var medicine_left:float=app.hospital.data.medicine_stop
 give_skill("JOY");cast("JOY")
 check(app.hospital.data.medicine_stop==medicine_left and app.hospital.blocks_hero(),"JOY may improve SP but cannot clear the already-established medicine stop")
 hospital_step(medicine_left-0.01)
 control_ms=app.rules.control_ms;app.rules.control_left=0.02;hospital_step(0.02)
 check(absi(app.rules.control_ms-control_ms-10)<=1,"control effective time excludes the final ten milliseconds of the actual medicine stop")
 hospital_step(0.05)
 check(app.hospital.data.medicine_stop<=0 and app.rules.hp==100,"medicine stop expires on world time without inventing HP loss")
 var sp:int=app.rules.sp;hospital_step(3.0)
 check(app.rules.sp==sp and receipt("swallow"),"later frames cannot repeat drug damage or swallow receipt")
 await capture("04_swallowed_medicine")

 pharmacy_fixture(true);hospital_step()
 hospital_until(func():return app.hospital.data.body.get("kind","")=="raise_cup",5.0)
 give_skill("GUT");cast("GUT")
 check(app.hospital.data.refused and not app.hospital.data.swallowed and app.rules.owners.hospital_cup=="counter" and app.rules.sp==100,"actual pre-swallow GUT places the same cup down and commits refusal without drug damage")
 check(app.hospital.data.has("false_sticker") and not "false_medicine_seen" in app.rules.known,"witnessing nurse prepares a sticker, without premature false-record knowledge")
 hospital_step(0.7)
 check(not "false_medicine_seen" in app.rules.known,"false medication record waits for real sticker duration")
 hospital_step(0.1)
 check("false_medicine_seen" in app.rules.known and not app.hospital.data.swallowed,"actual witnessed sticker preserves false institutional entry and true non-swallow separately")
 check(roundtrip() and app.hospital.data.refused and not app.hospital.data.swallowed,"actual JSON retains refusal, same cup and completed false-label knowledge")
 await capture("05_false_record_after_refusal")

 hospital_fixture();spawn_actor("nurse");hospital_step()
 check(hospital_until(func():return app.hospital.data.nurse_checked,2.0) and app.rules.owners.get("hospital_laundry_manifest","")=="ward_tray","actual nurse writing/contact supplies the required laundry order before porter task")
 spawn_actor("porter",Vector2(3.05,1.3))
 check(hospital_until(func():return not app.hospital.data.transport.is_empty() and app.hospital.data.transport.phase=="lift",5.0),"unique porter physically reaches the actual dirty-clothes bag before lifting")
 check(app.hospital.data.bag=="ward","unfinished bag lift cannot create a completed transfer record")
 hospital_step(0.56)
 check(app.hospital.data.bag=="porter" and app.hospital.data.actors.size()==10,"completed lift moves the bag to the same porter identity")
 check(roundtrip() and app.hospital.data.bag=="porter","actual JSON retains held bag and original porter route")
 check(hospital_until(func():return app.hospital.data.bag=="removed",15.0),"porter actually walks to exit before the bag is removed")
 check(receipt("bag_removed") and not "laundry_handoff_complete" in app.rules.known,"bag removal owns one receipt but unread office stub remains unknown")

 for witnessed in [true,false]:
  hospital_fixture("lobby");spawn_actor("guide",Vector2(2.4,1.4));spawn_actor("wheelchair",Vector2(2.8,1.4));spawn_actor("porter",Vector2(3.15,1.4))
  app.hero_pos=app.layout.furniture[0].at;app.target_index=0;app.rules.begin_search("lobby:0")
  check(hospital_until(func():return app.hospital.data.get("wheelchair_order",false),2.0) and not app.hospital.data.registered,"wheelchair uses actual independent patient paperwork without protagonist registration / "+str(witnessed))
  if not witnessed:app.enter_room("clinic");app.session.data.exploration_boundary=true
  var initial_sp:int=app.rules.sp
  check(hospital_until(func():return app.hospital.data.get("wheelchair_gone",false),35.0),"real paperwork/frame/fingers/exit transport completes / witnessed "+str(witnessed))
  check(("forced_transfer_seen" in app.rules.known)==witnessed and app.rules.sp==initial_sp-(10 if witnessed else 0),"only complete actual witness loses ten SP and learns forced transport / "+str(witnessed))
  check(app.rules.owners.get("family_photo","")=="wheelchair_footplate" and app.rules.owners.get("patient_shoe","")=="lobby_floor","actual patient's photo and dropped shoe keep distinct owners / "+str(witnessed))
  matrix.append({"wheelchair_complete_witness":witnessed,"hp":app.rules.hp,"sp":app.rules.sp,"receipt":receipt("patient_transport")})

 hospital_fixture("office");app.hero_pos=app.layout.furniture[5].at;spawn_actor("archivist",app.hero_pos+Vector2(-0.35,0))
 app.target_index=5;app.rules.begin_search("office:5")
 check(hospital_until(func():return not app.hospital.records.state().report.is_empty(),8.0),"real office search, visible warning and continued action produce an archive report")
 check(hospital_until(func():return app.hospital.records.state().report.location=="office:10",12.0),"absent guard causes actual navigation and deposition at office desk two")
 check(app.hospital.records.state().report.phase=="pending" and app.rules.owners.key==app.session.data.key_owner,"pending archive report neither summons guard nor confiscates key")
 check(roundtrip() and app.hospital.records.state().report.phase=="pending","actual JSON preserves report, removed document and last-seen target")
 spawn_actor("guard",Vector2(1.25,0.24))
 check(hospital_until(func():return app.hospital.records.state().report.phase=="accepted",25.0),"actual archive/guard navigation and contact receive the persisted report")
 check(hospital_until(func():return app.hospital.data.holder=="guard",25.0),"guard actually approaches, reaches and closes one grip")
 check(app.rules.hp==95 and app.rules.sp==90 and app.rules.gripped,"real guard grip commits exactly five HP and ten SP")
 check(roundtrip() and app.hospital.data.holder=="guard" and app.rules.gripped,"actual JSON retains established guard grip without new damage")
 clock=app.hospital.data.clock;var held_hp:int=app.rules.hp;var held_pos:Vector2=app.hero_pos
 await frames(12)
 check(app.hospital.data.clock==clock and app.rules.hp==held_hp and app.hero_pos==held_pos,"manual pause freezes actual drag, contact receipts and hospital clock")
 await capture("06_saved_guard_grip")
 check(hospital_until(func():return app.hospital.data.holder=="",7.0),"real guard releases at doorway or six-second maximum")
 check(app.rules.hp==95 and app.rules.sp==90 and app.hospital.records.state().guard.done,"later drag/reload cannot repay guard damage or open another disposition")
 app.session.data.key_owner="hero";app.rules.owners.key="hero";app.session.data.exploration_boundary=false
 app.route_to_door("lobby")
 check(hospital_until(func():return app.room_id=="lobby",20.0),"completed record disposition does not lock key route or ordinary office exit")
 await capture("07_office_exit_after_disposition")

 finish_suite()
