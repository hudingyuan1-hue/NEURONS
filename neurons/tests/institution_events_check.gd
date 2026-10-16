extends "res://tests/hospital_relic_packing_check.gd"
## Explicit starting actors/held key only; all contact/packing/arrival receipts
## below are earned by the production clock. Not a natural full playthrough.
var baseline:Dictionary={}
var cases:Array=[]

func hospital_fixture(room:String="ward",geometry:int=2) -> void:
 app.restore_snapshot(baseline)
 app.rules=Neural.new();app.menu.rules=app.rules
 app.rules.neurons=50;app.rules.search_limit=12
 app.session=Session.new();app.session.data.unlocked=[1,2]
 app.session.new_attempt(2,app.rng);app.session.data.institution_geometry_version=geometry
 app.session.data.key_discovery.discovered="event_fixture"
 app.home.enabled=false;app.family.enabled=false;app.asylum.enabled=false
 app.hospital.enabled=true;app.hospital.data.clear();app.hospital.start_attempt()
 for group in app.hospital.data.groups:app.hospital.data.groups[group].drawn=true
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.room_id="";app.enter_room(room)
 app.hero_pos=app.layout.get_anchor("spawn") if geometry>=2 else Vector2(3.5,2.2)
 app.hero_route=PackedVector2Array();app.target_index=-1
 app.session.data.exploration_boundary=true
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func put(id:String,room:String,at:Vector2) -> void:
 var actor:Dictionary=app.hospital.actor(id)
 actor.phase="idle";actor.room=room;actor.pos=app.hospital.xy(at);actor.route=[];actor.elapsed=0

func originals_fixture(geometry:int) -> void:
 hospital_fixture("lobby",geometry)
 var floor_layout=app.layout
 app.hero_pos=Vector2(5.35,1.25) if geometry>=2 else Vector2(3.5,2.2)
 put("guide","lobby",floor_layout.get_anchor("guide_wait") if geometry>=2 else Vector2(2.4,1.4))
 put("wheelchair","lobby",floor_layout.get_anchor("wheelchair_wait") if geometry>=2 else Vector2(2.8,1.4))
 put("porter","lobby",floor_layout.get_anchor("porter_wait") if geometry>=2 else Vector2(3.15,1.4))
 app.rules.owners.family_photo="wheelchair"

func isolate3() -> void:
 for group in app.asylum.data.groups:
  app.asylum.data.groups[group].drawn=true;app.asylum.data.groups[group].pending=false
 app.session.data.exploration_boundary=true

func original_chain(geometry:int) -> void:
 originals_fixture(geometry)
 check(hospital_until(func():return photo_phase()=="photo_contact",60),"v%d actual trio reaches original photograph contact"%geometry)
 if photo_phase()!="photo_contact":return
 check(app.rules.owners.family_photo=="wheelchair_footplate" and roundtrip(),"v%d contact save keeps original photograph on visible support"%geometry)
 if geometry==1:
  var source:int=app.hospital.known_source_attempt()
  app.restart_attempt(1,false);clear_lines()
  for group in app.hospital.data.groups:app.hospital.data.groups[group].drawn=true
  app.session.data.exploration_boundary=true
  check(app.layout.geometry_version==1 and app.hospital.source_geometry_version()==1 and app.hospital.known_source_attempt()==source,"old chapter restart retains in-flight original coordinates and source attempt")
 check(hospital_until(func():return delivery().get("ready",false),35),"v%d same porter actually packs both originals and exits"%geometry)
 if not delivery().get("ready",false):return
 var original:Dictionary=delivery().duplicate(true)
 check(original.items.size()==2 and app.rules.owners.family_photo=="hospital_relic_container" and app.rules.owners.patient_shoe=="hospital_relic_container","v%d two actual pickups preserve unique original owners"%geometry)
 app.asylum.enabled=true;app.rules.owners.key="hero";app.session.data.key_owner="hero"
 app.session.data.exploration_boundary=false;app.route_to_door("stairs")
 check(hospital_until(func():return int(app.session.data.level)==3,65),"v%d actual key route/opening/threshold enters next chapter"%geometry)
 if int(app.session.data.level)!=3:return
 isolate3()
 var arrival_evidence:Dictionary={"phase":app.asylum.intake.state().phase,"source":original.duplicate(true),"carry":app.asylum.data.carry.get("relic_delivery",{}).duplicate(true)}
 var arrival_file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("arrival_v%d.json"%geometry),FileAccess.WRITE)
 arrival_file.store_string(JSON.stringify(arrival_evidence,"  "));arrival_file.close()
 check(app.room_id=="lobby" and app.layout.geometry_version==2 and app.hospital.source_geometry_version()==geometry,"v%d same-floor transformation adopts new space without moving hospital provenance"%geometry)
 check(app.asylum.intake.state().phase=="approach" and canonical_relic(original)==canonical_relic(app.asylum.data.carry.relic_delivery),"v%d real chapter hook passes unchanged source container once"%geometry)
 var nurse:Dictionary=app.asylum.actor("registration_nurse")
 nurse.phase="idle";nurse.room="lobby";nurse.pos=app.asylum.xy(app.layout.get_anchor("registration_nurse_wait"));nurse.route=[]
 check(hospital_until(func():return app.asylum.intake.state().phase=="receive",30),"v%d existing nurse physically reaches incoming container"%geometry)
 hospital_step(.2)
 check(roundtrip() and app.hospital.source_geometry_version()==geometry,"v%d mid-receive disk save preserves source geometry"%geometry)
 check(hospital_until(func():return app.asylum.intake.state().phase=="stored",30),"v%d nurse contact/carry/place completes actual intake"%geometry)
 var after:String=canonical_relic(app.asylum.intake.state())
 hospital_step(2)
 check(app.asylum.intake.bag_holder()=="asylum_registration_desk" and app.asylum.intake.current_items().size()==2 and after==canonical_relic(app.asylum.intake.state()),"v%d later clocks retain two originals without repeating handoff"%geometry)
 cases.append({"source_geometry":geometry,"source":original,"intake":app.asylum.intake.state().duplicate(true)})
 await capture("source_v%d_actual_intake"%geometry)

func guard_door() -> void:
 hospital_fixture("lobby")
 app.session.new_attempt(3,app.rng);app.asylum.enabled=true;app.hospital.enabled=false
 app.asylum.data.clear();app.asylum.start_attempt();app.room_id="";app.enter_room("lobby");isolate3()
 var portal:Dictionary=app.portal_for_room("lobby","office")
 app.hero_pos=portal.at+portal.inward*.3
 var guard:Dictionary=app.asylum.actor("guard")
 guard.phase="idle";guard.room="lobby";guard.pos=app.asylum.xy(app.hero_pos+Vector2(0,.25));guard.route=[]
 check(app.layout.walkable(app.hero_pos) and app.layout.walkable(app.asylum.position("guard")),"guard test starts with two legal bodies near existing office portal")
 # Existing accepted report/last-seen target is the stated starting fixture.
 # No grip, damage, delivery or completed disposition is injected.
 var event:Dictionary=app.asylum.records.state().guard
 event.phase="approach";event.target="hero";event.last_room="lobby";event.last_seen=app.asylum.xy(app.hero_pos);event.elapsed=0;event.done=false
 app.rules.hp=100;app.rules.sp=100
 check(hospital_until(func():return app.rules.gripped,3),"guard closes real reach and establishes actual single holder")
 check(app.rules.hp==95 and app.rules.sp==90,"guard damage settles once at actual grip")
 check(roundtrip() and app.rules.gripped,"paired drag survives actual disk save before doorway crossing")
 check(hospital_until(func():return app.room_id=="office",6),"guard and held protagonist physically cross existing office threshold")
 check(hospital_until(func():return not app.rules.gripped,2),"existing office landing completes disposition and releases holder")
 check(app.layout.walkable(app.hero_pos) and app.layout.walkable(app.asylum.position("guard")) and app.rules.hp==95 and app.rules.sp==90,"both bodies finish on legal destination floor without repeated damage")
 await capture("guard_actual_office_landing")

func real_window_click() -> bool:
 for item in app.view.asylum_props():
  if str(item.id)!=app.asylum.WARD_WINDOW_ID or str(item.room)!=app.room_id:continue
  var pixel:Vector2=app.view.asylum_item_pixel(item)
  var screen:Vector2=(app.world_viewport.get_canvas_transform()*pixel)*Vector2(1280,720)/Vector2(app.world_viewport.size)
  cases.append({"window_click_before":{"pixel":pixel,"screen":screen,"lock":app.input_lock_frames,"paused":app.world_paused(),"room":app.room_id,"phase":app.action_phase}})
  var movement:=InputEventMouseMotion.new();movement.position=screen;movement.global_position=screen;Input.parse_input_event(movement);await frames(2)
  for down in [true,false]:
   var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=screen;event.global_position=screen;Input.parse_input_event(event);await frames(2)
  return true
 return false

func window_input() -> void:
 hospital_fixture("lobby")
 app.session.new_attempt(3,app.rng);app.asylum.enabled=true;app.hospital.enabled=false
 app.asylum.data.clear();app.asylum.start_attempt();app.room_id="";app.enter_room("lobby");isolate3()
 var portal:Dictionary=app.portal_for_room("lobby","ward")
 app.hero_pos=app.asylum.ward_window_position("lobby")+portal.inward*.45
 give_skill("CONTROL");app.paused_manual=false;app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 check(await chain_live_until_local(func():return app.rules.control_left>0 and app.closing_left<=0,3),"metric exterior window obtains CONTROL through actual CRT mouse and normal fee")
 await frames(5)
 check(await chain_live_until_local(func():return not app.world_paused() and app.input_lock_frames<=0,3),"CONTROL closing feedback and input shield finish before actual window click")
 check(app.rules.neurons==45 and await real_window_click(),"real native-viewport click targets rendered elevated exterior shutter")
 check(await chain_live_until_local(func():return app.asylum.ward_window_state().open and app.asylum.ward_window_state().action.is_empty(),4),"metric mouse request really approaches and opens the exterior shutter at contact")
 cases.append({"window_after_first":{"state":app.asylum.ward_window_state().duplicate(true),"phase":app.action_phase,"request":app.asylum.data.get("read_route",{}).duplicate(true),"status":app.status_note,"pos":app.hero_pos,"control":app.rules.control_left}})
 check(await chain_live_until_local(func():return not app.world_paused() and app.input_lock_frames<=0,3),"actual feedback and input shield finish before next shutter click")
 check(await real_window_click() and await chain_live_until_local(func():return not app.asylum.ward_window_state().open and app.asylum.ward_window_state().action.is_empty(),4),"same actual exterior marker closes the shutter with normal process")
 check(app.rules.neurons==45 and app.rules.search_attempts==0,"two real metric window actions neither duplicate CONTROL charge nor add search income")
 app.paused_manual=true;await capture("metric_actual_window_mouse")
 app.enter_room("ward");app.session.data.exploration_boundary=true
 app.hero_pos=app.asylum.ward_window_position("ward")+app.portal_for_room("ward","lobby").inward*.45
 app.paused_manual=false;await frames(5)
 check(await real_window_click(),"inside actual metric shutter uses its own room marker")
 await frames(8)
 check(app.room_id=="ward" and not app.asylum.ward_window_state().open and app.asylum.ward_window_state().action.is_empty() and app.status_note.contains("外侧"),"inside shutter click is explicitly rejected and never falls through to underlying door")
 app.paused_manual=true;await capture("metric_actual_window_inside_rejected")

func chain_live_until_local(predicate:Callable,seconds:float) -> bool:
 var elapsed:float=0
 while elapsed<seconds:
  if predicate.call():return true
  var before:int=Engine.get_process_frames()
  if not app.dialogue_queue.is_empty():await continue_live_line()
  else:await frames(1)
  elapsed+=float(maxi(1,Engine.get_process_frames()-before))*get_process_delta_time()
 return predicate.call()

func finish_suite() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 var recorded:bool="--institution-record" in OS.get_cmdline_user_args()
 var scope:String="Production metric clinic contacts, v2 original-object transport and legacy v1 in-flight rest-to-new-L3 source provenance, actual intake and paired guard threshold. Explicit initial actors/key/accepted report. Fixed world ticks, not normal-speed natural full playthrough or art/audio acceptance."
 if recorded:scope="One declared metric clinic doctor/assistant, initial 50N/unlocked KNEE fixture. Afterwards ordinary process, real Enter/CRT mouse, actual needle/contact, interruption and prescription. Continuous 30FPS MovieMaker; not a natural-RNG full playthrough, human pacing or listening/art acceptance."
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"cases":cases,"recording":recorded,"matrix":matrix,"scope":scope},"  "));file.close()
 print("INSTITUTION_EVENTS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="机构新空间实际事件验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.opening_ui!=null:app.opening_ui.skip()
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;baseline=app.snapshot_data()
 if "--institution-record" in OS.get_cmdline_user_args():
  await record_representative();finish_suite();return
 hospital_fixture("clinic")
 app.hero_pos=app.layout.get_anchor("exam_hero")
 put("doctor","clinic",app.layout.get_anchor("doctor_wait"));put("assistant","clinic",app.layout.get_anchor("assistant_wait"))
 check(hospital_until(func():return app.hospital.actor("doctor").phase=="sample",4),"metric doctor really reaches exam point, prepares grab and contacts needle")
 check(app.rules.hp==95 and app.rules.gripped and not app.hospital.data.sample,"actual needle costs five HP without premature sample completion")
 check(roundtrip() and app.rules.gripped and app.rules.hp==95,"mid-sample disk save preserves holder and prior one-time needle injury")
 check(hospital_until(func():return app.hospital.data.sample,3),"two real sampling seconds finish one valid sample")
 check(hospital_until(func():return app.rules.owners.get("hospital_prescription","")=="hero",3),"independent prescription reaches real handover in metric clinic")
 await capture("metric_clinic_sample_and_prescription")
 await original_chain(2)
 await original_chain(1)
 await guard_door()
 await window_input()
 finish_suite()
