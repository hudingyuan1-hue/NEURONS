extends "res://tests/asylum_check.gd"
## Declared initial/source fixtures, actual B4 world clock/physical read/doors;
## real JSON, no invented prior death, no claim of natural random full play.
const CMap=preload("res://scripts/core/cortex_map.gd")
var actual_route:Array=[]

func fixture4(room:String) -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=[1,2,3,4];app.session.new_attempt(4,app.rng)
 app.rules.actual_attempt=1;app.rules.search_limit=16;app.rules.owners.key=app.session.data.key_owner
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=true
 app.cortex.start_attempt()
 for group in app.cortex.data.groups:app.cortex.data.groups[group].drawn=true
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.room_id="";app.enter_room(room);app.hero_pos=Vector2(2.8,3.0)
 app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy"
 app.session.data.exploration_boundary=true;app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func upper():return app.cortex.upper_events
func actor4(id:String,at:Vector2) -> void:
 var actor:Dictionary=app.cortex.actor(id)
 actor.phase="idle";actor.room=app.room_id;actor.pos=[at.x,at.y];actor.route=[];actor.stand_done=true
func read4(id:String) -> bool:
 var target:Dictionary=app.cortex.specification(id)
 if target.is_empty():return false
 var at:Vector2=app.cortex.approach_position(target)
 app.hero_pos=at;app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 var offset:Vector2=app.cortex.target_position(target)-at
 if offset.length()>0.01:app.hero_facing=offset.normalized()
 if not app.cortex.begin_observation(id):return false
 return until3(func():return app.cortex.data.observation.is_empty(),8)
func source_fixture() -> void:
 # This is a declared past-event fixture, not a random playthrough or new plot.
 # Both receipts and the original actual written paper are required.
 app.rules._record("asylum_medicine_refused","asylum:2:refuse_medicine",{})
 app.rules._record("asylum_false_medicine_written","asylum:2:false_medicine",{})
 app.rules.institutional_records.append({"id":"asylum_false_medicine:2","text":"给药护士：已服用（实际拒服；造假落笔后才形成）。","attempt":2})
func drain() -> void:
 while not app.dialogue_queue.is_empty():app.advance_dialogue()
func finish4() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,"actual_route":actual_route,"scope":"B4 six upper events finite declared source/actor/read fixtures. Actual world timing, original dialogue acknowledgement, physical label ownership, real doors, grip/JSON/long-term loss conservation. Not natural RNG/full human play/formal art/audio acceptance.","source_fixture":"same actual L3 attempt2 refusal receipt + false-writing receipt + matching written original; no death fixture","step_seconds":0.025}
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("CORTEX_UPPER_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b4_20261016/upper"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="白质事件验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture4("bridge");app.hero_pos=Vector2(2.8,2.8);actor4("dual_head",Vector2(3.3,2.8))
 check(upper().source_material().is_empty() and not upper().begin_bridge(),"no genuine source cannot manufacture death/refusal contradiction")
 source_fixture()
 check(upper().source_material().get("id","")=="asylum:2:refuse_medicine","bridge binds real refusal and corresponding actual false paper to same original attempt")
 check(upper().source_material().get("number",null)==null,"unknown patient number stays null rather than adopting intruder number")
 check(upper().begin_bridge(),"actual nearby actor can begin left/right statements from existing source")
 for index in range(20):
  if not app.dialogue_queue.is_empty():break
  app.advance_world(0.025)
 check(upper().state().bridge.phase=="left_speaking" and app.rules.sp==100,"queuing first statement is not completed hearing or SP settlement")
 var time:float=app.rules.world_time;await frames(5)
 check(app.rules.world_time==time,"actual manual pause/official dialogue freezes world clock")
 app.advance_dialogue()
 check(upper().state().bridge.heard==["left"] and app.rules.sp==100,"actual acknowledgement records only the left statement")
 check(roundtrip() and upper().state().bridge.heard==["left"],"real checksummed JSON preserves half-heard event/source")
 check(until3(func():return upper().state().bridge.phase=="done",3),"right statement actually finishes before conflict settlement")
 check(app.rules.sp==90 and upper().persistent().losses.size()==1,"complete same-event pair loses exactly ten SP once per save")
 check(upper().begin_bridge(),"replay resets playback counters while retaining historical hearing")
 check(upper().state().bridge.heard.is_empty(),"new playback cannot reuse old left/right playback flags")
 until3(func():return upper().state().bridge.phase=="done",3)
 check(app.rules.sp==90,"replay same existing source cannot repeat ten-SP loss")
 await capture("01_bridge_real_partial_and_complete")

 fixture4("identity");actor4("double_face",Vector2(1.9,2.1))
 check(read4("cortex_identity_left"),"left original verification is actually read")
 drain();check(app.rules.sp==100 and not upper().persistent().identity_read.get("right",false),"one document cannot complete identity conflict")
 check(roundtrip(),"partial identity read survives real JSON")
 check(read4("cortex_identity_right"),"right independent original and passing result are actually read")
 drain();check(app.rules.sp==100,"two documents without two faces do not settle")
 check(read4("cortex_identity_faces"),"actual facing/contact starts first-to-second face turn")
 check(until3(func():return upper().state().identity.phase=="done",3),"second face becomes observed only after real turn completion")
 check(app.rules.sp==90 and upper().persistent().losses.has("identity:S3:P1261–1267"),"full two-doc/two-result/two-face comparison costs original ten SP")
 drain();var remembered:Dictionary=upper().persistent().duplicate(true)
 app.cortex.start_attempt();for group in app.cortex.data.groups:app.cortex.data.groups[group].drawn=true
 upper().complete_identity()
 check(app.rules.sp==90 and upper().persistent()==remembered,"new local actor attempt cannot repeat same saved identity loss or erase partial knowledge")
 await capture("02_identity_complete")

 fixture4("index");actor4("faceless",Vector2(4.0,1.2));app.cortex.actor("faceless").facing=[-1,0]
 check(read4("cortex_index_original"),"original can be genuinely opened while faceless actor is looking away")
 drain();step3(.6)
 check(not upper().state().index.attempted and not upper().persistent().index_removed,"nearby back-facing actor cannot witness the opening or spend an extraction attempt")

 fixture4("index");actor4("faceless",Vector2(3.2,.5));app.cortex.face_target("faceless",app.cortex.point("index",1))
 check(app.layout.walkable(app.cortex.position("faceless")) and not app.layout.clear_segment(app.cortex.position("faceless"),app.cortex.point("index",1)),"declared index witness stands legally on the far side of the original desk obstruction")
 check(read4("cortex_index_original"),"original is actually opened while its actor-facing sightline is blocked")
 drain();step3(.6)
 check(not upper().state().index.attempted and not upper().persistent().index_removed,"front-facing actor cannot see the original through its solid desk or extract remotely")

 fixture4("index");actor4("faceless",Vector2(4.0,1.2));app.cortex.face_target("faceless",app.cortex.point("index",1))
 check(read4("cortex_index_query"),"initial live index query physically readable")
 drain();check(not upper().persistent().index_removed,"querying exterior does not trigger extraction")
 check(read4("cortex_index_original"),"actual original opening seen by faceless actor starts extraction attempt")
 check(until3(func():return upper().state().index.phase=="extract",12),"faceless actor physically navigates to index and pinches before one-second extraction")
 check(not upper().persistent().index_removed,"pinching is not yet removal")
 step3(.45);check(roundtrip() and not upper().persistent().index_removed,"partial extraction JSON retains actual one-second window")
 check(until3(func():return upper().state().index.phase=="done",6),"original name label moves only on completed extraction, then actor physically retreats")
 check(upper().persistent().index_removed and app.rules.owners.cortex_name_label=="faceless","one label has one real holder and query changes at contact completion")
 check(app.cortex.position("faceless").distance_to(app.cortex.point("index",3))>.4,"retreated faceless actor clears the terminal's actual search/read stand")
 check(read4("cortex_index_query"),"changed query revision allows rereading the actual new result")
 check(upper().persistent().fields.cortex_index_query.result=="查无此人","new query accurately reflects missing label without deleting original")
 var owner_before:String=app.rules.owners.cortex_name_label
 upper().on_skill({"id":"GUT","success":true});step3(1)
 check(app.rules.owners.cortex_name_label==owner_before,"later hero intervention cannot undo completed NPC label extraction")
 await capture("03_index_extracted_and_query")

 fixture4("verify");app.hero_pos=Vector2(2.8,.5);actor4("face_press",Vector2(3.3,.5));app.cortex.actor("face_press").facing=[1,0]
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 check(not upper().on_exit_open_started() and not upper().state().face.attempted,"back-facing face actor cannot see keyed opening or consume an interception opportunity")
 app.cortex.actor("face_press").room="identity"
 check(not upper().on_exit_open_started() and not upper().state().face.attempted,"actor in another room cannot witness the same physical opening")

 fixture4("verify");app.hero_pos=Vector2(2.8,.5);actor4("face_press",Vector2(4.15,.3));app.cortex.face_target("face_press",app.hero_pos)
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 check(app.layout.walkable(app.cortex.position("face_press")) and not app.layout.clear_segment(app.cortex.position("face_press"),app.hero_pos),"declared face witness stands legally behind the existing door-panel obstruction")
 check(not upper().on_exit_open_started() and not upper().state().face.attempted,"facing the keyed door through an obstruction does not start remote interception")

 fixture4("verify");app.hero_pos=Vector2(2.8,.5);actor4("face_press",Vector2(3.3,.5));app.cortex.face_target("face_press",app.hero_pos)
 check(not upper().on_exit_open_started(),"without key no face interception begins")
 app.rules.owners.key="hero";app.session.data.key_owner="hero"
 check(upper().on_exit_open_started(),"actual keyed opening hook starts visible approach and immediately spends opportunity")
 check(not upper().on_exit_open_started() and app.cortex.data.receipts.keys().count("cortex:1:face_start")==1,"repeated waiting-opening notification cannot restart approach or duplicate its receipt")
 check(until3(func():return upper().state().face.phase=="raise",2),"nearby face actor reaches contact distance before raising hand")
 step3(.775);check(app.rules.sp==100 and not app.rules.gripped,"before original 0.8-second raise there is no contact or damage")
 step3(.025);check(app.rules.sp==85 and app.rules.gripped,"0.8-second actual face contact costs fifteen SP and holds body")
 check(roundtrip() and app.rules.gripped and app.has_key(),"face hold JSON preserves sole holder and original key")
 step3(1.175);check(app.rules.gripped,"original 1.2-second release has not happened early")
 step3(.025);drain()
 check(not app.rules.gripped and app.cortex.data.holder=="" and app.cortex.data.body.is_empty(),"actual release clears both parent body and holder synchronously")
 check(app.rules.hp==100 and app.rules.sp==85 and app.has_key() and not upper().on_exit_open_started(),"face gives no HP damage, preserves key and cannot repeat same attempt")
 await capture("04_face_release_key_retained")

 fixture4("verify");app.hero_pos=Vector2(2.8,.5);actor4("face_press",Vector2(3.3,.5));app.cortex.face_target("face_press",app.hero_pos);app.rules.owners.key="hero";app.session.data.key_owner="hero"
 upper().on_exit_open_started();until3(func():return upper().state().face.phase=="raise",2)
 app.hero_route=app.layout.path(app.hero_pos,Vector2(2.0,1.25));app.motion={"speed":2.0}
 step3(.8)
 check(upper().state().face.phase in ["done","retreat"] and app.rules.sp==100 and not app.rules.gripped,"actual physical movement out of reach makes face miss, opportunity remains consumed")
 check(not upper().on_exit_open_started(),"miss cannot restart interception")
 check(until3(func():return upper().state().face.phase=="done",5),"face actor really steps aside after missing rather than holding door stand")

 fixture4("verify");app.hero_pos=Vector2(2.6,1.4);actor4("face_press",Vector2(3.1,1.4));app.cortex.face_target("face_press",app.hero_pos);app.rules.owners.key="hero";app.session.data.key_owner="hero"
 upper().on_exit_open_started();until3(func():return upper().state().face.phase=="raise",2)
 app.hero_route=PackedVector2Array([Vector2(2.6,.9),Vector2(3.6,.9),Vector2(3.6,1.4)]);app.motion={"speed":6.0}
 step3(.8)
 check(app.hero_pos.distance_to(Vector2(3.6,1.4))<.04 and app.rules.sp==100 and not app.rules.gripped,"real movement around the fixed reaching direction cannot be hit behind the face actor")

 fixture4("verify");app.hero_pos=Vector2(2.8,.5);actor4("face_press",Vector2(3.3,.5));app.cortex.face_target("face_press",app.hero_pos)
 app.rules.owners.key="hero";app.session.data.key_owner="hero";app.session.data.cortex_exit_crossed=true
 check(not upper().on_exit_open_started() and not upper().state().face.attempted,"already-crossed actual exit prevents delayed interception even with a clear facing witness")

 fixture4("rhythm");app.hero_pos=Vector2(.85,2.9);actor4("twitch",Vector2(1.4,1.1));app.hero_facing=Vector2.UP
 var start:Vector2=app.cortex.position("twitch");step3(1.5)
 check(upper().state().rhythm.phase=="crossing" and int(upper().state().rhythm.count)==1,"rhythm counts actual shoulder start after original1.5 gap")
 step3(.6);drain()
 check(app.cortex.position("twitch").distance_to(start)>.5,"support actually pulls body during crossing")
 var count:int=app.rules.search_attempts;var money:int=app.rules.neurons
 var obstruction:Dictionary=upper().movement_block(app.cortex.position("twitch")+Vector2(-.5,0),app.cortex.position("twitch")+Vector2(.5,0))
 check(obstruction.get("wait",false),"first actual collision requests only current crossing wait")
 obstruction=upper().movement_block(app.cortex.position("twitch")+Vector2(-.5,0),app.cortex.position("twitch")+Vector2(.5,0))
 check(obstruction.get("bypass",false),"same crossing cannot impose an endless repeated wait")
 step3(.6);check(upper().state().rhythm.phase=="gap","original1.2 crossing completes and clears waiting")
 check(app.rules.hp==100 and app.rules.search_attempts==count and app.rules.neurons==money,"ordinary avoidance gives no damage, search expense or reward")
 await capture("05_rhythm_actual_position")

 fixture4("switch");app.session.data.exploration_boundary=false;app.session.data.targets=[]
 app.hero_pos=Vector2(2.8,2.5);actor4("reverse",Vector2(3.3,2.5));app.hero_facing=Vector2.RIGHT
 check(until3(func():return upper().state().switch.phase=="route",3),"seen pointing creates only existing three-leg loop")
 upper().on_skill({"id":"DRYMOUTH","success":true})
 check(upper().state().switch.phase=="route","dry mouth without an actual handover does not cancel existing walking guidance")
 actual_route=[app.room_id]
 for step in range(2500):
  if upper().state().switch.await_landmark:break
  step3()
  if actual_route[-1]!=app.room_id:actual_route.append(app.room_id)
 check(upper().state().switch.await_landmark and actual_route==["switch","bridge","index","switch"],"misdirection physically walks all three actual doors before returning")
 app.session.data.exploration_boundary=true;app.hero_route=PackedVector2Array();app.action_phase="autonomy"
 check(read4("cortex_switch_landmark"),"returned hero really examines original doorway landmark")
 check(upper().persistent().route_known and "cortex_route_known" in app.rules.known,"only completed physical loop plus landmark grants persistent route recognition")
 check(roundtrip() and upper().persistent().route_known,"recognized route persists through actual JSON")
 await capture("06_actual_loop_and_landmark")
 finish4()
