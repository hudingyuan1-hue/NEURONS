extends "res://tests/asylum_events_check.gd"
## Finite initial/mid-action fixtures; all tested event results are produced
## by the actual campaign's fixed game-time update and real JSON roundtrips.
## This is not a natural-RNG full playthrough, human audio or formal-art QA.
var observed_ordinary_rooms:Array=[]

func ward_fixture(room:String) -> void:
 # Production attempts intentionally retain real workshop inventory. Each
 # independent test case starts a fresh test world rather than refilling it.
 app.asylum.data={}
 fixture3(room,true)
 app.session.data.exploration_boundary=true
 app.asylum.ward_events.state()

func ward_state() -> Dictionary:return app.asylum.ward_events.state()

func canonical3(value) -> String:
 # JSON has one number type: integer counters load as numeric doubles. Check
 # the real persisted value, never raw in-memory Variant integer/float tags.
 return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true)

func same_point3(first:Array,second:Array) -> bool:
 return first.size()==2 and second.size()==2 and Vector2(float(first[0]),float(first[1])).is_equal_approx(Vector2(float(second[0]),float(second[1])))

func drain_real_dialogue() -> void:
 while not app.dialogue_queue.is_empty():app.advance_dialogue()

func start_drawer() -> bool:
 ward_fixture("workshop")
 app.hero_pos=app.layout.furniture[6].at
 actor3("supervisor","workshop",app.hero_pos+Vector2(0,-0.35))
 app.target_index=6;app.hero_route=PackedVector2Array()
 var begun:bool=app.rules.begin_search("workshop:6",1.5)
 if begun:app.rules.begin_public_action("search","workshop:6","autonomous","workshop")
 return begun and until3(func():return ward_state().clamp.phase=="windup",3)

func walk_hero(to:Vector2,seconds:float=8.0) -> bool:
 app.hero_route=app.layout.path(app.hero_pos,to)
 if app.hero_route.is_empty():return false
 app.motion={"speed":1.2}
 return until3(func():return app.hero_pos.distance_to(to)<0.04,seconds)

func therapy_fixture(offscreen:bool=false) -> void:
 ward_fixture("stairs" if offscreen else "group_therapy")
 app.hero_pos=Vector2(2.8,1.05) if not offscreen else Vector2(2.8,1.4)
 actor3("therapist","group_therapy",app.asylum.layout_for("group_therapy").furniture[5].at)
 actor3("speaker","group_therapy",app.asylum.layout_for("group_therapy").furniture[2].at)

func transfer_fixture() -> void:
 ward_fixture("corridor")
 # The blocker occupies the actual destination door. A legal detour cannot
 # cross that occupied threshold until the protagonist really walks away.
 app.hero_pos=app.door_point_for("corridor","quiet")
 var origin:Vector2=app.door_point_for("corridor","double_ward")
 actor3("transport_patient","corridor",origin)
 actor3("porter","corridor",origin+Vector2(0.5,0))

func start_hero_report() -> bool:
 ward_fixture("corridor")
 app.hero_pos=app.layout.furniture[0].at
 actor3("head_nurse","corridor",app.hero_pos+Vector2(0.35,0))
 actor3("ordinary_orderly","corridor",Vector2(3.5,1.1))
 app.target_index=0;app.hero_route=PackedVector2Array()
 if not app.rules.begin_search("corridor:0",1.5):return false
 app.rules.begin_public_action("search","corridor:0","autonomous","corridor")
 return until3(func():return ward_state().ordinary_job.phase=="reach",10)

func station_transfer_fixture(nurse:bool=true) -> void:
 transfer_fixture()
 # A clear initial observer corner keeps this success fixture independent of
 # the separate actual door-blocker test above.
 app.hero_pos=Vector2(4.35,3.2)
 if nurse:actor3("head_nurse","corridor",Vector2(0.5,2.4))
 actor3("ordinary_orderly","ward",Vector2(2.55,1.2))

func record_count(id:String) -> int:
 var count:int=0
 for record in app.rules.institutional_records:
  if str(record.get("id",""))==id:count+=1
 return count

func finish3() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 second-floor finite actor/contact fixtures: real drawer timing and paid skills, workshop material conservation/JSON, recording-device and paper nodes, dynamic moving-bed obstruction/actual doors/band ownership, onsite porter-order handoff/wrist verification/independent isolation signature versus absent/departed head nurse, private wound exposure/informer delivery/ordinary escort, and actual internal-folder search/head-nurse report/ordinary hero grip/release/timeout. Explicit late-observer, pre-existing other-holder, staff-departure, blocked-side and busy-staff combination fixtures are not natural gameplay claims. Not all twenty-one identities, all random combinations, final art or subjective audio acceptance.",
  "ordinary_actual_rooms":observed_ordinary_rooms,
  "methods":{"world_step_seconds":0.025,"normal_campaign_update":true,"actual_checksummed_json":true,"human_natural_rng_playthrough":false,"formal_art_accepted":false,"audio_listened":false}}
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("ASYLUM_WARD_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/ward_events"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院二层事件验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 check(start_drawer(),"supervisor sees actual material-drawer search and approaches before one visible windup")
 check(app.rules.hp==100 and app.rules.search_active and not app.rules.gripped,"drawer preparation does not injure, finish search or establish grip early")
 var neurons:int=app.rules.neurons
 step3(0.2)
 var clamp_before:String=canonical3(ward_state().clamp)
 check(roundtrip() and canonical3(ward_state().clamp)==clamp_before,"checksummed JSON preserves a real mid-windup drawer without resetting remaining time")
 await capture("01_drawer_preparation")
 check(until3(func():return rec3("drawer_hurt"),1.2),"unwithdrawn hand is injured only by actual drawer closure")
 check(app.rules.hp==90 and app.rules.sp==100 and app.rules.search_attempts==1 and app.rules.neurons==neurons,"one actual clamp costs ten HP, no SP and no interrupted-search reward")
 check(until3(func():return ward_state().clamp.phase=="done",1.1) and not app.rules.gripped and app.asylum.data.holder=="","drawer releases within original one-second cap and clears only its own holder")
 step3(1);check(app.rules.hp==90,"continued frames and completed clamp cannot duplicate injury")

 check(start_drawer(),"withdrawal case starts a new actual drawer windup")
 give_skill("WITHDRAW");neurons=app.rules.neurons
 check(cast("WITHDRAW").get("success",false) and app.rules.neurons==neurons-2,"real unlocked WITHDRAW submission pays its original two-neuron cost once")
 check(not app.rules.search_active and app.rules.hp==100,"withdrawal cancels unfinished search without granting instant injury or completion")
 check(until3(func():return ward_state().clamp.phase=="done",2.0) and app.rules.hp==100,"timely actual hand retraction makes drawer close empty")
 check(ward_state().clamp.attempted and rec3("drawer_close") and not rec3("drawer_hurt"),"a miss consumes this attempt without inventing a hit receipt")
 app.target_index=6
 check(app.rules.begin_search("workshop:6",1.5),"same point remains legally searchable after missed clamp")
 step3(2);check(app.rules.hp==100 and ward_state().clamp.phase=="done","reopening same drawer cannot regenerate supervisor's used attempt")

 check(start_drawer(),"PORES case starts actual search and physical windup")
 give_skill("PORES");check(cast("PORES").get("success",false) and app.rules.search_active,"real PORES feedback leaves searching hand in its actual position")
 check(until3(func():return rec3("drawer_hurt"),1.3) and app.rules.hp==90,"successful unrelated PORES effect does not grant invented clamp immunity")

 check(start_drawer(),"other-holder case begins a genuine supervisor windup")
 # Explicit middle-state combination fixture: another actor has already
 # established the sole grip. This does not claim to retest guard acquisition.
 actor3("guard","workshop",Vector2(2.8,2.1))
 app.asylum.data.holder="guard";app.rules.gripped=true
 app.asylum.data.body={"kind":"fixture_other_hold","actor":"guard","elapsed":0.0,"delay":0.0}
 check(until3(func():return rec3("drawer_hurt"),1.3),"true drawer collision may still hurt while an independent existing holder remains")
 check(app.rules.hp==90 and app.asylum.data.holder=="guard" and app.asylum.data.body.kind=="fixture_other_hold","drawer contact never replaces another real holder with a second grip")
 step3(1.2);check(app.asylum.data.holder=="guard" and app.rules.gripped,"supervisor's release cannot release another actor's grip")

 ward_fixture("workshop");app.hero_pos=Vector2(2.8,2.2)
 actor3("labor_patient","workshop",app.layout.furniture[7].at)
 neurons=app.rules.neurons;var clusters:int=app.rules.plexus
 check(until3(func():return ward_state().work.phase=="fold" and float(ward_state().work.elapsed)>0,3),"labor patient really takes existing paper then walks to separate table two")
 step3(0.3)
 var work_before:String=canonical3(ward_state().work)
 check(ward_state().work.box=="unfolded" and ward_state().work.label=="rack" and int(ward_state().work.products)==0,"partial folding has neither a label nor a finished product")
 check(roundtrip() and canonical3(ward_state().work)==work_before,"JSON preserves exact partial folding and material locations")
 check(until3(func():return ward_state().work.phase=="done",12),"real take-fold-flatten-fetch-label-paste-place chain reaches completed product")
 check(ward_state().work.paper=="box" and ward_state().work.label=="box" and int(ward_state().work.products)==1,"one paper and one label form one real product with no refilling loop")
 check(app.rules.neurons==neurons and app.rules.plexus==clusters and app.rules.search_attempts==0,"NPC work creates no protagonist search reward, clusters or search-count use")
 await capture("02_real_workshop_product")
 step3(3);check(int(ward_state().work.products)==1,"finished material instance cannot endlessly duplicate boxes")

 ward_fixture("workshop");app.hero_pos=app.layout.furniture[7].at
 check(app.asylum.ward_events.take_material("paper"),"protagonist can physically take still-present paper only at real rack contact")
 actor3("labor_patient","workshop",app.layout.furniture[7].at)
 step3(1)
 check(ward_state().work.phase=="waiting_materials" and ward_state().work.paper=="hero" and int(ward_state().work.products)==0,"worker waits when actual paper was removed instead of inventing replacement material")
 check(roundtrip() and app.rules.owners.get("asylum_work_paper","")=="hero" and ward_state().work.paper=="hero","saved paper ownership stays separate from unfinished NPC work")

 therapy_fixture()
 check(until3(func():return ward_state().therapy.phase=="say_stop",3),"actual recorder starts before source original statement and oral stop")
 check(ward_state().therapy.recording and ward_state().therapy.segment_exists and ward_state().therapy.heard_original,"saying stop leaves recorder running and preserves genuinely heard original speech")
 drain_real_dialogue();step3()
 check(ward_state().therapy.phase=="stop_recording" and ward_state().therapy.recording,"oral instruction has ended but device has not yet physically stopped")
 check(until3(func():return ward_state().therapy.phase=="delete_recording",2),"director physically presses stop after oral instruction")
 check(not ward_state().therapy.recording and ward_state().therapy.segment_exists,"stopping device alone does not erase the existing recorded segment")
 check(until3(func():return ward_state().therapy.phase=="approach_paper",2),"separate real deletion operation removes only corresponding segment")
 check(not ward_state().therapy.segment_exists and ward_state().therapy.saw_deletion and "asylum_heard_original" in app.rules.known,"deletion cannot erase protagonist's previously heard original information")
 check(ward_state().therapy.paper=="therapist" and not ward_state().therapy.retraction_spoken,"deleted recording does not pretend paper was delivered or statement already retracted")
 await capture("03_real_recording_deletion")
 check(until3(func():return ward_state().therapy.phase=="give_paper",5),"director actually walks from device to speaker before paper handoff")
 step3(0.2)
 check(ward_state().therapy.paper=="therapist" and not rec3("statement_given"),"paper remains with director before contact completion")
 check(roundtrip() and ward_state().therapy.paper=="therapist","mid-handoff JSON cannot deliver paper early")
 check(until3(func():return ward_state().therapy.paper=="speaker",2),"actual handoff completion transfers one statement sheet to speaker")
 check(until3(func():return bool(ward_state().therapy.retraction_spoken),2),"source retraction is actually spoken after receiving statement paper")
 check(rec3("statement_given") and rec3("speaker_retraction") and ward_state().therapy.heard_retraction,"delivery and original retraction sentence have separate once-only receipts and hearing")
 check(until3(func():return ward_state().therapy.phase=="question_write",6),"only heard-original plus seen-deletion branch asks source question")
 check(not rec3("group_question_written"),"formal question does not remotely finish director's writing")
 check(until3(func():return rec3("group_question_written"),7),"director really returns to writing position and writes questioned deletion once")
 check(record_count("asylum_group_question:1")==1 and app.rules.hp==100 and app.rules.sp==100,"written question produces one paper record without invented injury or mental drain")
 step3(2);check(record_count("asylum_group_question:1")==1,"continued frames do not duplicate question record")

 therapy_fixture(true)
 check(until3(func():return ward_state().therapy.phase=="delete_recording",4),"offscreen NPCs perform actual original statement and physical stop without protagonist hearing it")
 check(not ward_state().therapy.heard_original and not "asylum_heard_original" in app.rules.known,"an absent protagonist does not receive original-statement knowledge")
 # Explicit late-observer fixture; this tests knowledge gating after the
 # already executed original speech, not a claim about this entry route.
 app.enter_room("group_therapy");app.hero_pos=Vector2(2.8,1.05);app.session.data.exploration_boundary=true
 check(until3(func():return bool(ward_state().therapy.retraction_spoken),9),"late observer genuinely sees deletion and later hears only the retraction")
 check(ward_state().therapy.saw_deletion and ward_state().therapy.heard_retraction and not ward_state().therapy.heard_original,"hearing withdrawal cannot substitute for missing original speech")
 check(until3(func():return ward_state().therapy.phase=="done",7) and not rec3("group_question_written"),"without original hearing, deletion question and its record are not fabricated")

 transfer_fixture()
 check(until3(func():return not ward_state().transfer.band_drop.is_empty(),5),"real order checking, brake release, visible patient hand and return precede dropped wristband")
 var drop:Dictionary=ward_state().transfer.band_drop.duplicate(true)
 check(drop.room=="corridor" and drop.number==null and app.rules.owners.asylum_transport_band=="ward_floor","wristband exists only at actual fall position without invented visible number")
 var minimum:float=10.0
 for index in range(160):
  step3()
  if app.asylum.actor("transport_patient").room=="corridor":minimum=minf(minimum,app.asylum.position("transport_patient").distance_to(app.hero_pos))
 check(not ward_state().transfer.delivered and app.asylum.actor("transport_patient").room=="corridor" and minimum>=0.40,"moving bed stops or routes safely and cannot cross hero occupying destination door")
 check(ward_state().transfer.band_drop.room==drop.room and same_point3(ward_state().transfer.band_drop.pos,drop.pos),"bed motion and obstruction never drag a dropped band along")
 check(roundtrip() and same_point3(ward_state().transfer.band_drop.pos,drop.pos),"JSON preserves actual bed progress and independent wristband fall location")
 check(walk_hero(Vector2(2.6,1.0),3),"blocking protagonist actually walks away along normal collision-checked route")
 check(until3(func():return bool(ward_state().transfer.delivered),12),"same bed resumes through real quiet-room door and physically parks")
 check(app.asylum.actor("porter").room=="quiet" and app.asylum.actor("transport_patient").room=="quiet","one porter and one original live patient remain paired in delivered room")
 check(ward_state().transfer.band_drop.room=="corridor" and same_point3(ward_state().transfer.band_drop.pos,drop.pos),"delivered bed leaves fallen wristband back at its original corridor location")
 check(not ward_state().transfer.isolation_authorized and rec3("transport_delivered") and app.rules.hp==100 and app.rules.sp==100,"mere delivery is neither isolation, treatment, death nor extra harm")
 check(not app.asylum.ward_events.pair_travel("stairs",0.025) and app.asylum.actor("transport_patient").room=="quiet","ordinary transfer bed never climbs stairs or converts return passage into transport route")
 check(not app.asylum.ward_events.take_band(),"remote band pickup is rejected without changing floor ownership")
 check(walk_hero(Vector2(float(drop.pos[0]),float(drop.pos[1])),5),"protagonist physically walks to actual wristband fall point")
 for index in range(20):step3();app.asylum.ward_events.read_band(0.025)
 check(not ward_state().transfer.band_drop.read and app.rules.owners.asylum_transport_band=="ward_floor","half-finished reading is neither known detail nor item acquisition")
 for index in range(20):step3();app.asylum.ward_events.read_band(0.025)
 check(ward_state().transfer.band_drop.read and app.rules.owners.asylum_transport_band=="ward_floor","actual completed reading leaves the wristband physically on floor")
 neurons=app.rules.neurons
 check(app.asylum.ward_events.take_band() and app.rules.owners.asylum_transport_band=="hero","actual separate near-contact pickup transfers the same wristband once")
 check(not app.asylum.ward_events.take_band() and app.rules.neurons==neurons and ward_state().transfer.band_drop.number==null,"repeated pickup cannot reward, duplicate or invent a readable patient number")
 await capture("04_original_band_location_after_delivery")

 station_transfer_fixture()
 check(rec3("transport_initial_order")==false and ward_state().reports.is_empty(),"initial transfer fixture has no pre-completed onsite nurse receipt or isolation sheet")
 check(until3(func():return ward_state().transfer.phase=="station_handoff",10),"same porter, bed and patient physically push to station while same free head nurse actually approaches")
 check(app.asylum.actor("porter").room=="corridor" and app.asylum.actor("transport_patient").room=="corridor" and app.asylum.actor("head_nurse").room=="corridor" and app.asylum.ward_events.transfer_station_contact(),"all three original entities are in actual station contact before the new handoff")
 check(ward_state().transfer.order=="porter" and not ward_state().transfer.isolation_authorized and app.asylum.ward_events.pending_isolation_orders().is_empty(),"original initially signed order does not itself become an onsite isolation authorization")
 step3(0.3)
 check(ward_state().transfer.order=="porter" and not rec3("transfer_order_to_nurse"),"head nurse does not receive original order before real handoff completion")
 check(roundtrip() and ward_state().transfer.order=="porter" and ward_state().transfer.phase=="station_handoff","mid-station-handoff JSON retains actual document holder and unfinished action")
 check(until3(func():return rec3("transfer_order_to_nurse"),1.1),"same original order really changes to head nurse at station handoff completion")
 check(ward_state().transfer.order=="head_nurse" and ward_state().reports.size()==1 and not ward_state().reports[0].written and not ward_state().reports[0].isolation_signed,"received document, unwritten additional sheet and actual authorization remain distinct states")
 check(until3(func():return rec3("transfer_nurse_verified"),1.2),"head nurse physically checks patient and attached wristband while bed remains beside station")
 check(ward_state().reports[0].head_nurse_verified and ward_state().reports[0].patient_number==null and not ward_state().transfer.delivered,"onsite subject check invents no visible number and is not transport delivery")
 await capture("07_actual_transfer_nurse_check")
 check(until3(func():return rec3("transfer_isolation_written"),1.2),"head nurse really writes independent additional isolation sheet after physical check")
 check(ward_state().reports[0].written and not ward_state().reports[0].isolation_signed and app.asylum.ward_events.pending_isolation_orders().is_empty(),"written but unsigned sheet does not prematurely authorize isolation")
 check(until3(func():return rec3("transfer_isolation_signed"),1.1),"separate actual nurse signature finally creates additional isolation authorization")
 check(ward_state().transfer.isolation_authorized and not ward_state().transfer.delivered and app.asylum.ward_events.pending_isolation_orders().is_empty(),"signed additional sheet still waits for original bed's real delivery before isolation handoff")
 check(until3(func():return bool(ward_state().transfer.delivered),12),"porter receives original paper back and really completes the same bed's quiet-room path")
 check(rec3("transfer_order_to_porter") and ward_state().transfer.order=="porter" and ward_state().transfer.station_outcome=="signed_and_returned","original paper is physically returned rather than copied or remotely fetched from delivered patient")
 var transfer_report:Dictionary=ward_state().reports[0]
 check(transfer_report.event=="transport" and transfer_report.actual_delivery_actor=="porter" and transfer_report.delivery_outcome=="delivered" and transfer_report.ordinary_outcome=="" and not transfer_report.ordinary_taken,"porter delivery never fabricates an ordinary-orderly report receipt or duplicate transport")
 check(app.asylum.actor("ordinary_orderly").room=="ward" and ward_state().ordinary_job.phase=="idle","ordinary orderly ignores porter-delivered patient's additional sheet and keeps its unique original entity")
 check(app.asylum.ward_events.pending_isolation_orders().size()==1 and not transfer_report.isolation_taken,"only actual onsite signing plus actual porter delivery exposes one separate pending isolation handoff")
 check(app.rules.hp==100 and app.rules.sp==100,"optional paperwork and patient transfer do not manufacture protagonist injury or mental damage")

 station_transfer_fixture(false)
 check(until3(func():return bool(ward_state().transfer.delivered),15),"without head nurse original valid transport still really reaches quiet room")
 check(rec3("transport_initial_order") and not rec3("transfer_order_to_nurse") and not ward_state().transfer.isolation_authorized and app.asylum.ward_events.pending_isolation_orders().is_empty(),"head nurse absence leaves only delivered transport, never an invented onsite check or isolation permission")
 actor3("head_nurse","corridor",Vector2(0.5,2.4));step3(3)
 check(not rec3("transfer_order_to_nurse") and not rec3("transfer_isolation_signed") and app.asylum.actor("porter").room=="quiet","late nurse cannot remotely receive an original order still held by porter in quiet room")

 station_transfer_fixture()
 check(until3(func():return rec3("transfer_order_to_nurse"),10),"staff-departure boundary first executes actual onsite original-order handoff")
 # Explicit physical-departure middle-state fixture; arrival and handoff above
 # are real, and no final written/signed/delivered state is supplied here.
 app.asylum.actor("head_nurse").phase="gone"
 check(until3(func():return bool(ward_state().transfer.delivered),15),"head nurse leaving before wrist verification does not block original transport's real delivery")
 check(ward_state().reports[0].received and not ward_state().reports[0].written and not ward_state().reports[0].isolation_signed and not ward_state().transfer.isolation_authorized,"unfinished onsite sheet remains honestly received but unverified/unsigned after real recipient leaves")
 check(ward_state().transfer.order=="head_nurse" and not rec3("transfer_order_to_porter") and app.asylum.ward_events.pending_isolation_orders().is_empty(),"departed nurse retains actual received paper without magical remote return or authorization")

 ward_fixture("activity");app.hero_pos=Vector2(2.8,1.4)
 actor3("postop_patient","activity",Vector2(3.15,1.4));actor3("guard","activity",Vector2(3.5,1.4))
 step3(1.5)
 check(not rec3("postop_wound_exposed") and not ward_state().postop.wound_visible,"nearby medical/security observer prevents a supposedly private wound display")

 ward_fixture("activity");app.hero_pos=Vector2(2.8,1.4)
 actor3("postop_patient","activity",Vector2(3.15,1.4))
 actor3("informer","corridor",app.door_point_for("corridor","activity"))
 check(until3(func():return ward_state().postop.wound_visible,3),"with nobody watching, source invitation is followed by actual lifting of clothes")
 check(not ward_state().postop.informer_saw_wound and app.rules.sp==100,"private wound starts without retroactive informant witness or added mental damage")
 check(until3(func():return bool(ward_state().postop.informer_saw_wound),5),"informer really enters during still-exposed wound and acquires its own actual witness")
 check(ward_state().postop.hero_saw_wound and "asylum_postop_wound_seen" in app.rules.known,"protagonist's actual wound observation is saved separately from informant's")
 check(until3(func():return ward_state().postop.informer_phase=="at_station",7),"informer really leaves activity room and reaches corridor to report")
 step3(1.5)
 check(ward_state().reports.is_empty() and not rec3("postop_isolation_signed"),"absent head nurse cannot receive report, issue permit or sign isolation authorization")
 check(roundtrip() and ward_state().postop.informer_saw_wound,"JSON retains actual informant witness while report waits for its real recipient")
 check(walk_hero(Vector2(2.8,2.3),4),"protagonist actually makes space before a later patient escort")
 actor3("head_nurse","corridor",app.asylum.layout_for("corridor").furniture[0].at)
 actor3("ordinary_orderly","ward",Vector2(2.55,1.2))
 # Explicit pre-existing busy-staff combination fixture. The independent
 # corner suite validates how its own actual grab/escort acquired this job.
 app.asylum.data.staff_targets.ordinary_orderly="corner_patient"
 check(until3(func():return not ward_state().reports.is_empty() and bool(ward_state().reports[0].permit_given),12),"informer approaches head nurse, actually reports, waits for written report/signature and receives permit")
 var report:Dictionary=ward_state().reports[0]
 check(report.received and report.written and report.isolation_signed and not report.head_nurse_witnessed,"head nurse receiving a report does not become a fabricated eyewitness")
 check(app.rules.owners.get("asylum_informer_permit:1","")=="informer" and not app.has_key(),"permission is really owned only by informer and never replaces protagonist's key")
 check(not report.ordinary_taken and app.asylum.actor("ordinary_orderly").room=="ward","ordinary orderly already busy with another target is not duplicated or remotely assigned a second report")
 step3(1);check(not ward_state().reports[0].ordinary_taken,"waiting report remains unaccepted while shared staff reservation stays busy")
 app.asylum.data.staff_targets.erase("ordinary_orderly")
 observed_ordinary_rooms=[str(app.asylum.actor("ordinary_orderly").room)]
 for index in range(2400):
  if ward_state().ordinary_job.phase=="drag":break
  step3()
  var room:String=str(app.asylum.actor("ordinary_orderly").room)
  if observed_ordinary_rooms[-1]!=room:observed_ordinary_rooms.append(room)
 check(ward_state().ordinary_job.phase=="drag" and ward_state().ordinary_job.holding,"released orderly really traverses old floor/stairs, receives paper, finds target and closes its actual grasp")
 check(observed_ordinary_rooms.has("ward") and observed_ordinary_rooms.has("lobby") and observed_ordinary_rooms.has("stairs") and observed_ordinary_rooms.has("corridor") and observed_ordinary_rooms.has("activity"),"same original orderly crosses real first-floor rooms and stair connection instead of spawning upstairs")
 check(roundtrip() and ward_state().ordinary_job.holding,"mid-patient-escort JSON keeps original two actors and same held target")
 await capture("05_actual_postop_patient_grasp")
 for index in range(2400):
  if str(ward_state().reports[0].ordinary_outcome)=="delivered":break
  step3()
  var room:String=str(app.asylum.actor("ordinary_orderly").room)
  if observed_ordinary_rooms[-1]!=room:observed_ordinary_rooms.append(room)
 check(str(ward_state().reports[0].ordinary_outcome)=="delivered" and app.asylum.actor("postop_patient").room=="quiet","actual paired path crosses activity/corridor/quiet doors and only then records delivery")
 check(not ward_state().ordinary_job.holding and not app.asylum.data.staff_targets.has("ordinary_orderly"),"delivered patient is really released and unique orderly becomes available")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"patient's escort does not invent protagonist damage, physical control or mental drain")
 check(app.asylum.ward_events.pending_isolation_orders().size()==1,"only written, signed and actually delivered disposition becomes eligible for later isolation handoff")
 check(not ward_state().postop.wound_visible and app.asylum.actor("postop_patient").room!="activity","same removed patient does not return to original seat and replay wound event")

 ward_fixture("corridor");app.hero_pos=app.layout.furniture[0].at
 actor3("head_nurse","corridor",app.hero_pos+Vector2(0.35,0))
 step3(1.5)
 check(ward_state().reports.is_empty() and not rec3("chief_internal_seen"),"standing at nurse station or looking at its public duty board without internal search cannot create a report")

 check(start_hero_report(),"actual internal-folder search causes real chief approach/stop/write/sign and ordinary paper receipt before visible hero reach")
 check(app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"chief's report, signature and ordinary visible reach do not themselves injure or grip hero")
 check(rec3("chief_internal_seen") and rec3("chief_internal_report_written") and rec3("hero_isolation_signed"),"actual witnessed search, written report and independent isolation authorization retain separate receipts")
 check(ward_state().reports.size()==1 and ward_state().reports[0].target=="hero" and ward_state().reports[0].head_nurse_witnessed,"same report queue binds internal-search report to hero and real head-nurse eyewitness")
 check(until3(func():return rec3("ordinary_hero_grip"),2),"ordinary orderly actually closes in-range grip after original visible preparation")
 check(app.rules.hp==95 and app.rules.sp==90 and app.asylum.data.holder=="ordinary_orderly" and app.rules.gripped,"one actual ordinary wrist twist costs exactly original five HP and ten SP")
 var hero_drag:Vector2=app.hero_pos
 check(roundtrip() and app.rules.gripped and app.asylum.data.body.get("kind","")=="ward_ordinary_hero_drag","real mid-hero-drag JSON keeps single holder and remaining game-time transport")
 give_skill("JOY");check(cast("JOY").get("success",false) and app.rules.gripped,"real JOY restores mental state without automatically opening an established ordinary grip")
 check(until3(func():return str(ward_state().reports[0].ordinary_outcome)=="delivered",6.1),"ordinary really walks hero to nurse-station side and releases within original six-second transport cap")
 check(not app.rules.gripped and app.asylum.data.holder=="" and app.hero_pos.distance_to(Vector2(1.9,2.3))<0.05 and app.hero_pos.distance_to(hero_drag)>0.1,"successful escort changes actual hero position and clears only own holder at real destination")
 check(app.rules.hp==95 and app.asylum.ward_events.pending_isolation_orders().size()==1,"drag/release do not repeat damage and only actual released delivery exposes later isolation handoff")
 await capture("06_actual_ordinary_hero_delivery")
 step3(2);check(app.rules.hp==95 and ward_state().reports.size()==1,"same internal report and continued proximity cannot repeat ordinary punishment")
 check(app.asylum.position("ordinary_orderly").distance_to(app.hero_pos)>=0.4,"released ordinary orderly really steps away instead of standing permanently over protagonist")

 check(start_hero_report(),"withdrawal report case reaches real ordinary pre-grip window")
 give_skill("WITHDRAW");check(cast("WITHDRAW").get("success",false),"paid actual WITHDRAW is accepted before ordinary hand closes")
 check(until3(func():return not str(ward_state().reports[0].ordinary_outcome).is_empty(),2),"actual withdrawal closes original ordinary attempt as a miss")
 check(str(ward_state().reports[0].ordinary_outcome)=="missed" and app.rules.hp==100 and app.rules.sp==100 and not app.rules.gripped,"missed ordinary grip creates no injury, held body or snap to station side")
 check(ward_state().reports[0].isolation_signed and app.asylum.ward_events.pending_isolation_orders().is_empty(),"signed paper survives missed ordinary attempt but cannot immediately authorize a second isolation chase")
 step3(2);check(ward_state().reports.size()==1 and app.rules.hp==100,"miss consumes this report disposition without immediate repeated ordinary grabbing")

 check(start_hero_report() and until3(func():return rec3("ordinary_hero_grip"),2),"blocked-side case first establishes a genuine ordinary grip and damage")
 # Explicit middle-action obstacle fixture; the actual six-second drag timer
 # and physical collision decide whether arrival happens, not this placement.
 actor3("guard","corridor",Vector2(1.9,2.3))
 check(until3(func():return str(ward_state().reports[0].ordinary_outcome)=="timeout",6.2),"unreachable occupied destination makes timed ordinary transport expire rather than teleport through actor")
 check(not app.rules.gripped and app.asylum.data.holder=="" and app.hero_pos.distance_to(Vector2(1.9,2.3))>0.1,"expired actual drag releases hero at real current position and does not claim destination")
 check(app.rules.hp==95 and app.asylum.ward_events.pending_isolation_orders().is_empty(),"timeout neither repeats wrist damage nor treats failed delivery as ready isolation handoff")
 finish3()
