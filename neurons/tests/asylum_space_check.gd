extends "res://tests/asylum_ward_check.gd"
## New-space fixtures are explicit; production handlers earn every result.
const SpaceSession=preload("res://scripts/core/campaign_session.gd")
var baseline:Dictionary={}
var spatial_routes:Array=[]
var recording:Dictionary={}

func capture(label:String) -> void:
 app.keep_metric_actor_visible()
 await super.capture(label)

func metric_fixture(room:String="corridor",actors:bool=false) -> void:
 app.restore_snapshot(baseline)
 app.rules=Neural.new();app.menu.rules=app.rules;app.rules.neurons=50
 app.rules.search_limit=14;app.rules.search_duration=5
 app.session=SpaceSession.new();app.session.data.unlocked=[1,2,3];app.session.new_attempt(3,app.rng)
 app.session.data.key_discovery.discovered="space_fixture"
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.cortex.enabled=false
 app.asylum.enabled=actors;app.asylum.data.clear();app.asylum.start_attempt()
 for group in app.asylum.data.groups:app.asylum.data.groups[group].drawn=true
 app.room_id="";app.enter_room(room);app.hero_pos=app.layout.get_anchor("spawn") if app.metric_institution_room(room) else Vector2(2.8,1.4)
 app.hero_route=PackedVector2Array();app.completed.clear();app.target_index=-1;app.motion.clear();app.deferred_targets.clear()
 app.session.data.exploration_boundary=true;app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func actual_door(to:String) -> bool:
 var from:String=app.room_id
 app.session.data.exploration_boundary=false;app.route_to_door(to)
 var ok:bool=until3(func():return app.room_id==to,90)
 spatial_routes.append({"from":from,"to":to,"actual":app.room_id,"hero":[app.hero_pos.x,app.hero_pos.y]})
 check(ok and app.layout.walkable(app.hero_pos),"actual approach/opening/threshold/landing "+from+" -> "+to)
 app.session.data.exploration_boundary=true
 return ok

func metric_actor(id:String,room:String,at:Vector2) -> void:
 actor3(id,room,at);app.asylum.actor(id).stand_done=true

func actual_observation(id:String) -> bool:
 var module=app.asylum.observations;var target:Dictionary=module.specification(id)
 if target.is_empty():return false
 var at:Vector2=module.approach_position(target)
 if not at.is_finite() or not walk_hero(at,25):return false
 step3()
 return module.begin(id,false) and until3(func():return module.state().read.has(id) and module.state().active.is_empty(),4)

func remaining_room_events() -> void:
 metric_fixture("group_therapy",true);app.hero_pos=app.layout.get_anchor("observer_wait")
 metric_actor("therapist","group_therapy",app.layout.get_anchor("therapist_wait"));metric_actor("speaker","group_therapy",app.layout.get_anchor("speaker_wait"))
 check(until3(func():return ward_state().therapy.phase=="delete_recording",15),"actual ring-seat/device contacts produce original speech then separate physical recorder stop")
 check(ward_state().therapy.heard_original and not ward_state().therapy.recording and ward_state().therapy.segment_exists,"heard original remains a recorded segment until actual delete contact")
 check(roundtrip() and ward_state().therapy.segment_exists,"JSON at recorder stop never deletes segment or delivers a paper early")
 check(until3(func():return rec3("group_question_written") and ward_state().therapy.phase=="done",35),"actual deletion, paper handoff, retraction, standing release and questioned-record writing finish in new group room")
 check(not ward_state().therapy.segment_exists and ward_state().therapy.paper=="speaker" and ward_state().therapy.heard_retraction and "asylum_heard_original" in app.rules.known,"deletion never erases actual hearing or substitutes statement ownership/signature")
 check(actual_observation("asylum_statement_paper") and actual_observation("asylum_signature_record"),"two actual mobile paper holders remain separately approachable/readable after group movement")
 check(app.rules.hp==100 and app.rules.sp==100 and app.rules.neurons==50 and app.rules.search_attempts==0,"group paperwork and reading do not invent injury, search use or reward")
 await capture("09_group_actual_papers")
 metric_fixture("workshop",true);app.hero_pos=app.layout.get_anchor("observer_wait")
 metric_actor("labor_patient","workshop",app.layout.get_anchor("labor_patient_wait"))
 check(until3(func():return ward_state().work.phase=="fold",8),"same worker physically takes finite paper and reaches distinct folding table")
 step3(.25)
 check(roundtrip() and ward_state().work.phase=="fold" and ward_state().work.products==0,"new-table partial folding persists without early product")
 check(until3(func():return ward_state().work.phase=="done",25),"same worker returns to actual rack for label, pastes and places one box at table two")
 check(ward_state().work.products==1 and ward_state().work.paper=="box" and ward_state().work.label=="box" and ward_state().work.batch==null,"one original paper/label has one product; unknown batch remains unknown")
 check(actual_observation("asylum_product_label"),"actual placed product label is reachable at new table two")
 check(app.rules.neurons==50 and app.rules.search_attempts==0 and not "asylum_work_batch_matched" in app.rules.known,"worker and null-batch reading create no key search reward or invented batch match")
 await capture("10_workshop_actual_product")
 for withdraw in [false,true]:
  metric_fixture("workshop",true);app.hero_pos=app.layout.furniture[6].at
  metric_actor("supervisor","workshop",app.layout.get_anchor("supervisor_wait"))
  app.session.data.targets=["workshop:6"];app.session.data.exploration_boundary=false
  check(until3(func():return ward_state().clamp.phase=="windup",3),"real unlocked material drawer search reaches actual supervisor windup; withdrawal="+str(withdraw))
  if withdraw:
   give_skill("WITHDRAW");check(cast("WITHDRAW").get("success",false),"real paid withdrawal interrupts new material-drawer contact")
  check(until3(func():return ward_state().clamp.phase=="done",3),"actual drawer contact/release finishes at new cabinet without permanent hold")
  check(app.rules.hp==(100 if withdraw else 90) and app.rules.neurons==(48 if withdraw else 50) and not app.rules.gripped,"new cabinet preserves original hurt versus paid timely empty closure")
 await capture("11_actual_drawer_withdrawal")

func live_until_space(predicate:Callable,max_frames:int) -> bool:
 for frame in range(max_frames):
  if predicate.call():return true
  if not app.dialogue_queue.is_empty():await continue_live_line()
  else:await frames(1)
 return predicate.call()

func live_key_space(keycode:int) -> void:
 for down in [true,false]:
  var key:=InputEventKey.new();key.keycode=keycode;key.pressed=down
  Input.parse_input_event(key);await frames(2)

func record_upper_space() -> void:
 metric_fixture("corridor",true);app.hero_pos=app.layout.get_anchor("corridor_parking")
 metric_actor("transport_patient","corridor",Vector2(11,2.6));metric_actor("porter","corridor",Vector2(11.5,2.6));give_skill("CONTROL")
 app.keep_metric_actor_visible();var started:int=Engine.get_process_frames()
 recording={"initial_fixtures":"new metric corridor; original bed patient/porter at declared clear initial positions, 50N and unlocked CONTROL; no hand/brake/band/grip/delivery receipts injected","method":"ordinary campaign process, actual Space/Enter/CRT mouse and panned door mouse, no manual world ticks","fps":30}
 app.paused_manual=false;get_window().grab_focus()
 check(await live_until_space(func():return not ward_state().transfer.band_drop.is_empty(),180),"continuous normal process reaches real hand return and corridor band fall")
 var drop:Dictionary=ward_state().transfer.band_drop.duplicate(true)
 await live_key_space(KEY_SPACE)
 var stopped:float=app.rules.world_time;var at:Vector2=app.asylum.position("transport_patient")
 await frames(30)
 check(app.paused_manual and is_equal_approx(app.rules.world_time,stopped) and app.asylum.position("transport_patient").is_equal_approx(at),"actual Space input freezes moving bed and world in continuous recording")
 await live_key_space(KEY_SPACE)
 check(await live_until_space(func():return ward_state().transfer.delivered,600),"actual Space resume permits paired bed doorway and parking without a snap")
 app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 check(await live_until_space(func():return app.rules.control_left>0 and not app.world_paused() and app.input_lock_frames<=0,150),"actual CRT mouse pays for CONTROL before panned-room click")
 var portal:Dictionary=app.portal_for_room("corridor","quiet")
 var pixel:Vector2=app.layout.project(portal.wall_point)-Vector2(0,float(portal.height_m)*78*.5)
 var screen:Vector2=app.world_viewport.get_canvas_transform()*pixel
 app.session.data.exploration_boundary=false
 var motion:=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen;Input.parse_input_event(motion);await frames(2)
 for down in [true,false]:
  var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=down;mouse.position=screen;mouse.global_position=screen;Input.parse_input_event(mouse);await frames(2)
 check(await live_until_space(func():return app.room_id=="quiet",330),"actual panned metric door mouse remains aligned and crosses into versioned quiet room")
 app.paused_manual=true
 check(canonical3(ward_state().transfer.band_drop)==canonical3(drop) and app.rules.neurons==45 and app.rules.hp==100,"continuous segment retains original floor band and one five-neuron CONTROL fee without injury")
 await capture("08_live_bed_landing");await frames(20)
 recording.frames=Engine.get_process_frames()-started;recording.band_drop=drop;recording.door_screen=[screen.x,screen.y];recording.final_room=app.room_id

func record_workshop_space() -> void:
 metric_fixture("workshop",true);app.hero_pos=app.layout.furniture[6].at
 metric_actor("supervisor","workshop",app.layout.get_anchor("supervisor_wait"));give_skill("WITHDRAW")
 app.session.data.targets=["workshop:6"];app.session.data.exploration_boundary=false
 app.keep_metric_actor_visible();var started:int=Engine.get_process_frames()
 recording={"initial_fixtures":"new workshop geometry, clear actual drawer contact, one original supervisor at named stand, 50N and unlocked WITHDRAW; no clamp/completion/result injected","method":"ordinary campaign process after setup, actual Enter/CRT mouse; no manual world ticks","fps":30}
 app.paused_manual=false;get_window().grab_focus()
 check(await live_until_space(func():return ward_state().clamp.phase=="windup",150),"continuous autonomous search reaches actual supervisor drawer preparation")
 await capture("12_live_drawer_windup")
 while not app.dialogue_queue.is_empty():await continue_live_line()
 app.open_neuron_menu();await click(app.menu.nodes.WITHDRAW)
 check(await live_until_space(func():return ward_state().clamp.phase=="done",300),"actual CRT mouse withdrawal makes drawer close empty and releases original attempt")
 check(app.rules.hp==100 and app.rules.neurons==48 and not rec3("drawer_hurt") and not app.rules.gripped,"continuous paid withdrawal retains original two-neuron cost, no injury or holder")
 check(await live_until_space(func():return "workshop:6" in app.completed,450),"ordinary autonomous retry completes same six-second search after real interruption")
 app.paused_manual=true
 check(app.rules.hp==100 and app.rules.neurons==49 and app.rules.search_attempts==2,"one retry reward settles only at completion and never repeats consumed supervisor attempt")
 await capture("13_live_drawer_retry_complete");await frames(20)
 recording.frames=Engine.get_process_frames()-started;recording.final_room=app.room_id

func finish3() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"routes":spatial_routes,"recording":recording,"rendered":true,"scope":"Versioned L3 upper-room trials, original seven corridor links and 44 original search contacts; source-bound NPC/report/nurse/bed/therapy/work cases use declared initial actor/key/scheduling fixtures, production clocks and disk JSON. Optional continuous recording uses ordinary process and actual keyboard/mouse after declared actors/skill fixture. Not natural full playthrough, formal art or audio acceptance."},"  "));file.close()
 print("ASYLUM_SPACE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="二层空间真实试接";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.opening_ui!=null:app.opening_ui.skip()
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;baseline=app.snapshot_data()
 if "--upper-space-record" in OS.get_cmdline_user_args():
  await record_upper_space();finish3();return
 if "--upper-work-record" in OS.get_cmdline_user_args():
  await record_workshop_space();finish3();return
 metric_fixture()
 check(app.layout.world_size()==Vector2(16,5) and app.visible_doors.size()==7,"new corridor has real 16x5 floor and original seven connections")
 app.keep_metric_actor_visible();await capture("01_corridor_entry")
 for neighbour in ["stairs","activity","group_therapy","quiet","bathroom","double_ward","workshop"]:
  if not actual_door(neighbour):finish3();return
  check(app.layout.geometry_version==2,"new chapter activates configured upper geometry: "+neighbour)
  await capture("02_native_"+neighbour)
  if not actual_door("corridor"):finish3();return
  app.keep_metric_actor_visible()
 for room in SpaceSession.ASYLUM_METRIC_ROOMS:
  for index in range(SpaceSession.point_names(3,room).size()):
   metric_fixture(room)
   var target:String="%s:%d"%[room,index];app.session.data.targets=[target];app.session.data.exploration_boundary=false
   check(until3(func():return app.rules.search_active,35),"real autonomous walk reaches "+target)
   if not app.rules.search_active:finish3();return
   var before:int=app.rules.neurons
   check(is_equal_approx(app.rules.search_duration,6),"original six-second search retained: "+target)
   if index==0:
    step3(.5);var elapsed:float=app.rules.search_elapsed;var at:Vector2=app.hero_pos
    check(roundtrip() and app.hero_pos.is_equal_approx(at) and is_equal_approx(app.rules.search_elapsed,elapsed),"mid-search JSON keeps exact new-room contact: "+room)
    await frames(5);check(is_equal_approx(app.rules.search_elapsed,elapsed),"manual pause freezes contact: "+room)
   check(until3(func():return target in app.completed,8) and app.rules.neurons==before+1,"actual completion earns one original reward: "+target)
  app.keep_metric_actor_visible();await capture("search_"+room)
 # Real original-node report chain, no wound/witness/report receipt injected.
 metric_fixture("activity",true)
 var floor_layout=app.layout
 var patient:Vector2=floor_layout.get_anchor("postop_patient_wait")
 metric_actor("postop_patient","activity",patient)
 metric_actor("informer","activity",floor_layout.get_anchor("informer_wait"))
 metric_actor("head_nurse","corridor",app.asylum.layout_for("corridor").get_anchor("head_nurse_wait"))
 app.hero_pos=patient+Vector2(.6,0);app.hero_facing=Vector2.LEFT
 check(until3(func():return ward_state().postop.informer_saw_wound,35),"informer really leaves and returns during actual wound exposure")
 check(until3(func():return ward_state().postop.report_phase=="done",70),"existing informant physically reports, receives permission and reaches original waiting chairs")
 check(ward_state().reports.size()==1 and ward_state().reports[0].written and ward_state().reports[0].isolation_signed,"report/signature exist only after real contacts at new station")
 check(app.rules.hp==100 and app.rules.sp==100 and app.asylum.present("postop_patient"),"paper allegation does not itself injure or delete living patient")
 await capture("03_real_station_report")
 # Continue the earned paper through the actual one-per-ID escort. No
 # holding, delivery or isolation receipts are seeded by this fixture.
 metric_actor("ordinary_orderly","corridor",app.asylum.layout_for("corridor").get_anchor("ordinary_orderly_wait"))
 var escort_rooms:Array=[]
 for tick in range(ceili(100.0/.025)):
  var actor_room:String=str(app.asylum.actor("postop_patient").room)
  if escort_rooms.is_empty() or escort_rooms[-1]!=actor_room:escort_rooms.append(actor_room)
  if ward_state().reports[0].ordinary_outcome=="delivered":break
  step3()
 check(ward_state().reports[0].ordinary_outcome=="delivered" and escort_rooms.has("activity") and escort_rooms.has("corridor") and escort_rooms.has("quiet"),"real ordinary report pickup/grip/escort crosses three configured rooms")
 check(app.asylum.actor("postop_patient").room=="quiet" and app.asylum.position("postop_patient").distance_to(app.asylum.layout_for("quiet").get_anchor("ordinary_patient_stop"))<.04,"patient parks at quiet-room contact, never at corridor coordinates")
 check(not ward_state().ordinary_job.holding and app.rules.hp==100 and app.rules.sp==100 and app.asylum.data.holder=="","NPC escort releases its own hold without protagonist damage or substituted hero grip")
 metric_actor("isolation_orderly","corridor",app.asylum.layout_for("corridor").get_anchor("isolation_orderly_wait"))
 check(until3(func():return app.asylum.isolation.state().get("door_closed",false),60),"signed and actually delivered patient order leads to real quiet-room closure from new corridor")
 if app.asylum.isolation.state().get("door_closed",false):
  var saved:float=float(app.asylum.isolation.state().closed_elapsed)
  check(roundtrip() and is_equal_approx(float(app.asylum.isolation.state().closed_elapsed),saved),"JSON preserves new-corridor isolation observer and original closed-door clock")
  check(until3(func():return not app.asylum.isolation.state().door_closed and app.asylum.isolation.state().outcome=="completed",12) and float(app.asylum.isolation.state().closed_elapsed)>=8,"original eight-second observation and real opening finish without changing source duration")
 await capture("04_patient_escort_and_isolation")
 # An explicitly inherited archive paper is a source fixture; all later
 # physical source reading, stair travel, writing and clipping are earned.
 metric_fixture("corridor",true);app.hero_pos=app.layout.get_anchor("corridor_parking")
 metric_actor("med_nurse","pharmacy",app.asylum.portal_for("pharmacy","lobby").landing)
 app.rules.institutional_records.append({"id":"false_medicine:upper-space-source","text":"已服用（机构贴签；实际未服另账）。","source":"医院记录","attempt":4})
 app.asylum.data.carry.visit="upper-space-source"
 var nurse_rooms:Array=[]
 for tick in range(ceili(100.0/.025)):
  var nurse_room:String=str(app.asylum.actor("med_nurse").room)
  if nurse_rooms.is_empty() or nurse_rooms[-1]!=nurse_room:nurse_rooms.append(nurse_room)
  if not app.asylum.nurse_duty.state().entries.is_empty():break
  step3()
 var entries:Array=app.asylum.nurse_duty.state().entries
 check(not entries.is_empty() and nurse_rooms.has("pharmacy") and nurse_rooms.has("office") and nurse_rooms.has("lobby") and nurse_rooms.has("stairs") and nurse_rooms.has("corridor"),"one nurse actually reads archive source then walks all original floors to new station")
 if not entries.is_empty():
  check(entries[0].source_id=="false_medicine:upper-space-source" and entries[0].source_attempt==4 and entries[0].clipped and entries[0].number==null,"new station copy preserves exact inherited provenance/null number and actual clipping")
 check(app.asylum.position("med_nurse").distance_to(app.layout.get_anchor("station_write_pos"))<.04 and app.rules.hp==100 and app.rules.sp==100,"nurse writes at clear named stand without creating medication/body consequences")
 await capture("05_nurse_actual_station")
 # Occupying the actual threshold prevents a paired bed passage; the
 # dropped band must stay at the fall point while the same bed later moves.
 metric_fixture("corridor",true)
 app.hero_pos=app.asylum.portal_for("corridor","quiet").threshold
 var origin:Vector2=app.asylum.portal_for("corridor","double_ward").landing
 metric_actor("transport_patient","corridor",origin);metric_actor("porter","corridor",origin+Vector2(.5,0))
 check(until3(func():return not ward_state().transfer.band_drop.is_empty(),5),"real source order/check/brake/hand return creates band at new corridor fall point")
 var drop:Dictionary=ward_state().transfer.band_drop.duplicate(true)
 step3(20)
 check(app.asylum.actor("transport_patient").room=="corridor" and not ward_state().transfer.delivered,"occupied real quiet threshold blocks moving pair instead of teleporting it")
 check(walk_hero(app.layout.get_anchor("corridor_parking"),12),"protagonist physically clears threshold along new floor")
 check(until3(func():return ward_state().transfer.delivered,35) and app.asylum.actor("transport_patient").room=="quiet","original bed/patient/porter pair crosses actual threshold and parks only after path clears")
 check(roundtrip() and canonical3(ward_state().transfer.band_drop)==canonical3(drop) and app.rules.owners.asylum_transport_band=="ward_floor","JSON and bed travel retain exact corridor band fall position and unique floor owner")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"patient bed movement invents no protagonist injury/control")
 await capture("06_bed_passage_band_retained")
 metric_fixture("corridor",true);app.hero_pos=app.layout.get_anchor("corridor_parking")
 metric_actor("transport_patient","corridor",app.layout.get_anchor("transfer_station_bed"))
 metric_actor("porter","corridor",app.layout.get_anchor("transfer_station_bed")+Vector2(.5,0))
 metric_actor("head_nurse","corridor",app.layout.get_anchor("transfer_station_nurse"))
 check(until3(func():return ward_state().transfer.get("station_outcome","")=="signed_and_returned",12),"near-station initial bed actually completes optional handoff/check/write/sign/return within original eight-second detour")
 check(ward_state().reports.size()==1 and ward_state().reports[0].head_nurse_verified and ward_state().reports[0].patient_number==null and ward_state().transfer.order=="porter","station verification preserves original subject/null number and returns the unique source order")
 check(until3(func():return ward_state().transfer.delivered,40) and not ward_state().reports.is_empty() and ward_state().reports[0].delivery_outcome=="delivered","station-signed bed still needs real long-corridor delivery before isolation eligibility")
 # Actual original events use migrated relic/corpse coordinates, not old
 # positions hidden inside the source configuration.
 metric_fixture("bathroom",true);app.hero_pos=app.layout.get_anchor("observer_wait")
 metric_actor("cleaner","bathroom",app.layout.get_anchor("cleaner_wait"))
 await capture("14_bathroom_original_floor_body")
 check(until3(func():return app.asylum.trace_events.state().cleaner.phase=="board",15),"actual shower screen and cover finish before independent board loading")
 check(app.asylum.trace_events.state().corpse.covered and not app.asylum.trace_events.state().corpse.on_board,"covered corpse remains on floor until real board contact completes")
 await capture("15_bathroom_covered_before_loading")
 check(until3(func():return app.asylum.trace_events.state().cleaner.phase=="done",100),"same cleaner loads corpse, crosses into new corridor, parks, returns and finishes finite washing")
 var corpse:Dictionary=app.asylum.trace_events.state().corpse
 check(corpse.room=="corridor" and corpse.moved_out and Vector2(float(corpse.pos[0]),float(corpse.pos[1])).distance_to(app.asylum.layout_for("corridor").get_anchor("corridor_parking"))<.04,"single independent corpse parks at actual new-corridor anchor without a bathroom copy")
 check(roundtrip() and app.asylum.trace_events.state().washed.size()==3,"new-corridor corpse position and three finished local wash regions survive disk JSON")
 metric_fixture("double_ward",true);app.hero_pos=app.layout.get_anchor("observer_wait")
 metric_actor("corner_patient","double_ward",app.layout.get_anchor("corner_patient_wait"))
 check(until3(func():return app.asylum.trace_events.state().conversation.shown.get("asylum_corner_transfer_note",false),3),"original corner patient actually exposes own note before any new-corridor staff sighting")
 metric_actor("ordinary_orderly","corridor",app.asylum.layout_for("corridor").get_anchor("ordinary_orderly_wait"))
 for tick in range(ceili(80.0/.025)):
  if app.asylum.trace_events.state().corner.done:break
  if app.asylum.trace_events.state().corner.phase=="idle":app.asylum.travel("ordinary_orderly","double_ward",.025)
  step3()
 check(app.asylum.trace_events.state().corner.get("delivered",false) and app.asylum.actor("corner_patient").room=="corridor","same original orderly physically enters double ward, grips patient and returns to corridor waiting anchor")
 check(app.asylum.position("corner_patient").distance_to(app.asylum.layout_for("corridor").get_anchor("corner_waiting"))<.55 and app.rules.owners.asylum_corner_transfer_note=="corner_patient" and not app.rules.gripped,"corner release uses new corridor position while note owner and protagonist body remain independent")
 await remaining_room_events()
 # Original same-chapter geometry must survive real rest, not merely JSON.
 metric_fixture("corridor")
 app.asylum.enabled=true
 var attempt:int=app.rules.actual_attempt
 app.enter_room("ward");app.hero_pos=app.layout.bed_position();app.action_phase="resting";app.action_left=.1;app.session.data.exploration_boundary=false
 check(until3(func():return app.rules.actual_attempt>attempt,3),"new-space chapter completes actual rest through production clock")
 app.enter_room("corridor")
 check(app.layout.geometry_version==2 and app.layout.world_size()==Vector2(16,5),"same-chapter new-space rest retains both room version choices")
 metric_fixture("corridor")
 app.session.data.asylum_space_versions={};app.room_id="";app.enter_room("corridor");app.hero_pos=Vector2(2.8,1.4)
 var old:Dictionary=app.snapshot_data();old.session.erase("asylum_space_versions")
 check(app.restore_snapshot(old) and app.layout.geometry_version==1 and app.hero_pos.is_equal_approx(Vector2(2.8,1.4)),"old save without per-room version keeps exact legacy corridor and position")
 app.enter_room("activity")
 check(app.layout.geometry_version==1,"same old save retains original activity room instead of silently resizing it")
 app.asylum.enabled=true;app.enter_room("ward");app.hero_pos=app.layout.bed_position();app.action_phase="resting";app.action_left=.1;attempt=app.rules.actual_attempt;app.session.data.exploration_boundary=false
 check(until3(func():return app.rules.actual_attempt>attempt,3),"legacy upper chapter also completes actual rest")
 app.enter_room("corridor")
 check(app.layout.geometry_version==1 and app.session.data.asylum_space_versions.is_empty(),"legacy rest preserves old upper geometry without upgrading or resetting actors into new coordinates")
 # Prior two-room revision must not silently grow five new geometries on
 # load/rest while an old workshop search is in progress.
 metric_fixture("workshop");app.session.data.asylum_space_versions={"corridor":2,"activity":2};app.room_id="";app.enter_room("workshop")
 app.hero_pos=app.layout.furniture[6].at;app.target_index=6;app.rules.begin_search("workshop:6",5);app.rules.begin_public_action("search","workshop:6","autonomous","workshop")
 step3(.3);var partial_elapsed:float=app.rules.search_elapsed
 check(roundtrip() and app.layout.geometry_version==1 and is_equal_approx(app.rules.search_elapsed,partial_elapsed),"prior two-room revision retains old workshop mid-search position/timer on disk reload")
 app.rules.cancel_search();app.enter_room("ward");app.hero_pos=app.layout.bed_position();app.action_phase="resting";app.action_left=.1;app.session.data.exploration_boundary=false;attempt=app.rules.actual_attempt
 check(until3(func():return app.rules.actual_attempt>attempt,3),"prior two-room revision completes its actual original rest")
 app.enter_room("workshop");check(app.layout.geometry_version==1 and canonical3(app.session.data.asylum_space_versions)==canonical3({"corridor":2,"activity":2}),"same-chapter rest preserves precisely prior two-room revision, never force-upgrading five in-flight spaces")
 for room in SpaceSession.ASYLUM_METRIC_ROOMS:
  metric_fixture(room);app.hero_pos=app.layout.furniture[-1].at
  var before:Vector2=app.hero_pos
  for zoom in range(app.ZOOM_STEPS.size()):
   app.zoom_index=zoom;app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*app.ZOOM_STEPS[zoom];app.camera.force_update_scroll();app.keep_metric_actor_visible()
   var foot:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.hero_pos)
   check(Rect2(199,269,882,272).has_point(foot) and app.hero_pos==before,"unchanged body and visible foot after new-room pan at zoom %s/%s"%[room,app.ZOOM_STEPS[zoom]])
  app.reset_zoom();await capture("07_zoom_"+room)
 finish3()
