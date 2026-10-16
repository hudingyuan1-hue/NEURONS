extends "res://tests/asylum_intake_chain_check.gd"
## An already-started physical trip continues after the real L2 door.
## Never turn an old departed flag or a later same-name room into history.
var cases:Array=[]

func early_fixture(attempt:int=2) -> void:
 app.hospital.data={};app.asylum.data={};relic_fixture();app.asylum.enabled=true
 app.rules.actual_attempt=attempt;app.session.data.attempts["2"]=attempt
 app.hospital.data.hospital_attempt=attempt
 app.hero_pos=app.door_point_for("lobby","stairs")+Vector2(0,0.45)
 app.rules.owners.key="hero";app.session.data.key_owner="hero"

func isolate_arrivals() -> void:
 for group in app.asylum.data.groups:
  app.asylum.data.groups[group].drawn=true;app.asylum.data.groups[group].pending=false
 app.session.data.exploration_boundary=true

func exit_normally() -> bool:
 app.session.data.exploration_boundary=false;app.route_to_door("stairs")
 var reached:bool=hospital_until(func():return int(app.session.data.level)==3,8)
 if reached:isolate_arrivals()
 return reached

func place_receiver_fixture() -> void:
 var nurse:Dictionary=app.asylum.actor("registration_nurse")
 var at:Vector2=app.asylum.layout_for("lobby").furniture[0].at
 nurse.phase="idle";nurse.room="lobby";nurse.pos=[at.x,at.y];nurse.route=[]

func assert_received(label:String) -> void:
 place_receiver_fixture()
 check(hospital_until(func():return intake_chain().state().phase=="stored",20),label+": existing nurse actually approaches, receives, carries and places original bag")
 check(facts_of("asylum_relic_delivery_arrived")==1 and facts_of("asylum_relic_container_received")==1 and facts_of("asylum_relic_container_stored")==1,label+": exactly one arrival, handoff and placement")
 check(intake_chain().current_items().size()==2 and app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container",label+": both unique originals survive delayed transfer")
 var before:String=canonical_relic(intake_chain().state())
 check(roundtrip(),label+": completed intake survives actual checksummed disk save")
 hospital_step(2)
 check(canonical_relic(intake_chain().state())==before and facts_of("hospital_relic_packed")==2,label+": later frames and reload do not replay any physical pickup or intake")

func finish_early() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"cases":cases,
  "scope":"Actual L2 keyed-door exit requested during original paperwork and photo contact; later source navigation/contact continues only for that started trip on the shared world clock. Pause, disk JSON and real L3 restart retain provenance. Also restore an unmodified observed natural L3-entry snapshot with a real carry-exit job, then receive the same originals with the existing nurse. Absent nurse is never spawned by intake; negative unstarted/gone cases never create a job.",
  "fixtures":"Two finite cases declare original L2 trio, source attempt 2, initial nearby walkable exit stand and held key. L3 random groups isolated; receiver presence is an explicit fixture after genuine late arrival. Carry-exit case uses the existing untouched continued-final/asylum_entry_snapshot.json, then isolates scheduling for observation. These are not all natural-RNG branches or human/audio/art acceptance."},"  "));f.close()
 print("HOSPITAL_EARLY_TRANSFER_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_finish_20261016/early-transfer"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="先离场原运输续接验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 for starting_phase in ["paperwork","photo_contact"]:
  early_fixture()
  check(hospital_until(func():return photo_phase()==starting_phase,35),starting_phase+": original patient transport really reaches the declared departure-request phase")
  var source_start:Dictionary=app.hospital.data.duplicate(true)
  check(exit_normally(),starting_phase+": real key route and door contact enter L3 without directly calling unlock")
  var at_entry:Dictionary=app.hospital.data.duplicate(true)
  check(app.hospital.known_source_attempt()==2 and app.rules.actual_attempt==1,starting_phase+": original L2 attempt remains distinct from new L3 attempt")
  var before:String=canonical_relic(app.hospital.data)
  await frames(8)
  check(before==canonical_relic(app.hospital.data),starting_phase+": manual pause freezes the actual departed source route and contacts")
  check(roundtrip() and before==canonical_relic(app.hospital.data),starting_phase+": actual disk JSON preserves exact unfinished source state")
  if starting_phase=="paperwork":
   app.restart_attempt(1,false);isolate_arrivals()
   check(app.rules.actual_attempt==2 and app.hospital.known_source_attempt()==2 and before==canonical_relic(app.hospital.data),"real L3 restart does not reset the earlier hospital trip or manufacture a completion")
  var hp:int=app.rules.hp;var sp:int=app.rules.sp
  var medical_before:String=canonical_relic([app.hospital.data.get("body",{}),app.hospital.data.get("groups",{}),app.hospital.data.get("medicine_stop",0),app.hospital.data.clock])
  check(hospital_until(func():return delivery().get("ready",false) and facts_of("asylum_relic_delivery_arrived")==1,35),starting_phase+": original actors really reach source exit before one late chapter arrival")
  check(app.hospital.position("porter").distance_to(Vector2(1.25,0.2))<0.035 and delivery().bag_departed,starting_phase+": ready manifest is backed by actual porter exit coordinates")
  check(medical_before==canonical_relic([app.hospital.data.get("body",{}),app.hospital.data.get("groups",{}),app.hospital.data.get("medicine_stop",0),app.hospital.data.clock]),starting_phase+": no old clinical body, spawn probability, medicine or hospital clock resumes")
  check(app.rules.hp==hp and app.rules.sp==sp and not "forced_transfer_seen" in app.rules.known,starting_phase+": offscreen transfer cannot create new harm or witnessed knowledge")
  check(not app.asylum.present("registration_nurse") and intake_chain().bag_holder()=="asylum_intake_delivery" and facts_of("asylum_relic_container_received")==0,starting_phase+": arrival waits for original nurse without spawning or faking handoff")
  var offscreen_facts:Array=[]
  for fact in app.rules.facts:
   if str(fact.get("kind","")) in ["hospital_relic_packed","patient_transport_completed"] and int(fact.get("occurrence_level",0))==3:offscreen_facts.append(fact.duplicate(true))
  check(not offscreen_facts.is_empty() and offscreen_facts.all(func(f):return int(f.get("source_level",0))==2 and int(f.get("source_attempt",0))==2),starting_phase+": fact source level/attempt and actual occurrence level stay separate")
  assert_received(starting_phase)
  cases.append({"requested_at":starting_phase,"source_start":source_start,"source_at_actual_entry":at_entry,"final_source":app.hospital.data.duplicate(true),"intake":intake_chain().state().duplicate(true),"offscreen_facts":offscreen_facts})

 var original_path:String="res://../docs/validation/b3_finish_20261016/continued-final/asylum_entry_snapshot.json"
 var original=JSON.parse_string(FileAccess.get_file_as_string(original_path))
 check(original is Dictionary and app.restore_snapshot(original),"restore unchanged genuine observed L3-entry snapshot rather than seed a carry-exit result")
 app.paused_manual=true;clear_lines();isolate_arrivals()
 check(app.hospital.data.get("relic_packing",{}).get("phase","")=="carry_exit" and not delivery().get("ready",false),"observed source is genuinely short of its exit with both originals already in the carried bag")
 var old_position:Vector2=app.hospital.position("porter")
 # L3 has a lobby with the same identifier. Place the observer there as an
 # explicit collision fixture; the source's actual L2 space stays independent.
 app.enter_room("lobby");isolate_arrivals();app.hero_pos=Vector2(1.25,0.2)
 app.layout.movable_blockers.append(Rect2(Vector2(0.8,0.14),Vector2(0.8,0.5)))
 check(hospital_until(func():return delivery().get("ready",false) and facts_of("asylum_relic_delivery_arrived")==1,4),"same-name L3 lobby hero/blocker cannot freeze or replace the actual L2 route")
 check(app.hospital.position("porter").distance_to(old_position)>0.035 and app.hospital.position("porter").distance_to(Vector2(1.25,0.2))<0.035,"saved carry-exit actor physically traverses remaining original distance")
 app.layout.movable_blockers.clear();app.hero_pos=Vector2(2.8,1.4)
 assert_received("observed carry_exit")
 await capture("01_late_original_container_actually_stored")

 early_fixture();app.hospital.data.transport={};app.hospital.data.erase("relic_context")
 # All original actors exist but no transport has started. The production
 # bridge must never draw or start one just because the chapter is now L3.
 app.session.data.level=3;app.asylum.start_attempt(app.hospital.data.duplicate(true));app.enter_room("lobby");isolate_arrivals()
 var untouched:String=canonical_relic(app.hospital.data)
 hospital_step(12)
 check(untouched==canonical_relic(app.hospital.data) and facts_of("asylum_relic_delivery_arrived")==0 and intake_chain().state().phase=="waiting_source","present but unstarted old actors cannot create a new hospital trip after leaving")
 app.hospital.actor("wheelchair").phase="gone";app.hospital.data.wheelchair_gone=true
 app.asylum.data.carry=app.hospital.data.duplicate(true);untouched=canonical_relic(app.hospital.data)
 hospital_step(12)
 check(untouched==canonical_relic(app.hospital.data) and delivery().is_empty() and facts_of("hospital_relic_packed")==0,"old gone/support history without actual original transport cannot create a bag or receipt")
 finish_early()
