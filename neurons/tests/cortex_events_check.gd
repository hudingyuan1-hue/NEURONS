extends "res://tests/asylum_check.gd"
## Finite declared L4 actor/contact/history fixtures, then real campaign
## routing, world-clock actions, paid skills and checksummed JSON. Not an
## assertion that every natural-RNG or authored unknown field is verified.
const CortexMap=preload("res://scripts/core/cortex_map.gd")

func fixture4(room:String="atrium") -> void:
 app.cortex.data={}
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=[1,2,3,4];app.session.new_attempt(4,app.rng)
 app.rules.actual_attempt=1;app.rules.search_limit=16;app.rules.allow_supplemental_search=true;app.rules.owners.key=app.session.data.key_owner
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=true
 app.cortex.start_attempt()
 for group in app.cortex.data.groups:app.cortex.data.groups[group].drawn=true
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.room_id="";app.enter_room(room);app.hero_pos=Vector2(2.8,1.2)
 app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy"
 app.session.data.exploration_boundary=true
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func spawn4(id:String,at:Vector2=Vector2.INF) -> void:
 var who:Dictionary=app.cortex.actor(id);var room:String=str(who.room)
 who.phase="idle";who.stand_done=true;who.route=[]
 who.pos=app.cortex.xy(app.cortex.beside(room,app.cortex.point(room,int(app.cortex.config.stand_furniture[id]))) if not at.is_finite() else at)

func begin4(id:String,route:bool=false) -> bool:
 var spec:Dictionary=app.cortex.specification(id)
 if route:return app.route_cortex_observation(spec,false)
 var at:Vector2=app.cortex.target_position(spec)
 if at.distance_to(app.hero_pos)>0.001:app.hero_facing=(at-app.hero_pos).normalized()
 var accepted:bool=app.cortex.begin_observation(id,false)
 if accepted:app.action_phase="cortex_observing"
 return accepted

func step4(seconds:float=0.025) -> void:
 for i in range(ceili(seconds/0.025)):
  while not app.dialogue_queue.is_empty():app.advance_dialogue()
  app.advance_world(minf(0.025,seconds-i*0.025))

func until4(predicate:Callable,seconds:float=20.0) -> bool:
 for i in range(ceili(seconds/0.025)):
  if predicate.call():return true
  step4()
 return predicate.call()

func begin_touch() -> bool:
 app.hero_pos=app.cortex.point("body",5);app.hero_facing=(app.cortex.touch_anchor()-app.hero_pos).normalized()
 app.target_index=5;app.action_phase="autonomy"
 app.rules.begin_public_action("search","body:5","controlled" if app.rules.control_left>0 else "autonomous","body")
 return app.rules.begin_search("body:5",1.75)

func right_turn(point:Vector2) -> void:
 clear_lines();app.input_lock_frames=0;app.paused_manual=false
 var screen:Vector2=(app.world_viewport.get_canvas_transform()*app.layout.project(point))*2.0
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=down
  Input.parse_input_event(event);await frames(1)
 app.paused_manual=true

func marker4(id:String) -> Dictionary:
 for marker in app.cortex.presentation_markers():
  if str(marker.id)==id:return marker
 return {}
func event_count4(id:String) -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.get("event_id",""))==id:count+=1
 return count

func history_fixture() -> void:
 # Declared prior completed original hospital trip, not a generated B4
 # outcome. Negative cases below prove a bag receipt cannot fill this role.
 app.rules._record("patient_transport_completed","hospital:1:patient_transport",{"source_level":2,"source_attempt":1})
 app.cortex.bind_evidence()

func finish4() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"L4 lower five event families and 11-identity scheduling; declared actor/contact/earlier-transport fixtures, actual approach/read/tear/mask/clamp/mimic, paid skills and schema2 JSON; not natural RNG combinations, final art or sound acceptance"},"  "));file.close()
 print("CORTEX_EVENTS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b4_20261016/events"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="皮层事件有限验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 check(not app.rules.owners.has("cortex_original_page"),"L1 initialization does not create an unvisited L4 original page")

 fixture4("atrium")
 check(app.cortex.data.actors.size()==11 and app.cortex.data.groups.size()==11,"five lower and six upper identities retain eleven independent rolls")
 for id in app.cortex.data.groups:app.cortex.data.groups[id]={"checks":0,"pending":false,"drawn":false}
 app.rng.seed=seed_for_range(0.45,1.0);app.cortex.on_enter("","atrium")
 check(app.cortex.data.groups.backward.checks==1 and not app.cortex.data.groups.backward.drawn,"first-attempt 45 percent roll does not use hospital 50 percent")
 app.cortex.on_enter("atrium","memory");app.cortex.on_enter("memory","atrium")
 check(app.cortex.data.groups.backward.checks==1,"instant room return consumes no extra appearance check")
 app.cortex.data.clock+=20.0;app.rng.seed=seed_for_range(0.225,0.45);app.cortex.on_enter("memory","atrium")
 check(app.cortex.data.groups.backward.checks==2 and not app.cortex.data.groups.backward.drawn,"after twenty game seconds second roll is half first probability")

 fixture4("atrium");spawn4("backward")
 app.hero_pos=app.cortex.beside("atrium",app.cortex.position("backward"),Vector2(0,-0.5));app.hero_facing=Vector2(0,-1)
 var hp:int=app.rules.hp;var sp:int=app.rules.sp
 step4(1.0)
 check(app.cortex.data.back.phase=="done" and not "cortex_back_face" in app.rules.known,"real head/body turn without protagonist looking does not grant a seen-face result")
 check(begin4("cortex_back_face"),"front-face observation requires actual nearby facing contact")
 check(until4(func():return app.cortex.data.completed_observations.has("cortex_back_face"),3),"finished physical observation reveals the faceless front")
 check(app.rules.hp==hp and app.rules.sp==sp and app.cortex.config.glyphs.shared_number==null,"turn and unknown number add neither damage nor fabricated identity")
 await capture("01_back_face_after_actual_turn")

 fixture4("memory");spawn4("stitched")
 app.hero_pos=app.cortex.point("memory",1);app.target_index=1
 check(app.rules.begin_search("memory:1",1.75),"ordinary table-bottom search starts as a genuine search")
 step4(1.0)
 check(not app.cortex.data.paper.attempted and app.cortex.data.paper.remaining=="whole","searching table underside does not trigger original-page destruction")
 app.rules.cancel_search();app.target_index=-1;app.hero_route=PackedVector2Array()
 check(begin4("cortex_original_page"),"separate original-page reading begins at the real table")
 check(until4(func():return app.cortex.data.paper.phase=="tear",4),"stitched actor actually approaches and pinches before two-second tearing")
 var tear_time:float=app.cortex.data.paper.elapsed;var world_time:float=app.rules.world_time
 await frames(12)
 check(app.rules.world_time==world_time and app.cortex.data.paper.elapsed==tear_time,"manual pause freezes tear and physical contact clock")
 check(roundtrip() and app.cortex.data.paper.phase=="tear" and app.cortex.data.paper.elapsed==tear_time,"checksummed JSON retains same partly active original and actor")
 step4(0.5);await capture("02_original_page_actual_tear")
 check(until4(func():return app.cortex.data.paper.phase=="collect",4),"real two-second tear leaves physical scraps before collecting")
 var tear_position:Vector2=app.cortex.position("stitched")
 check(app.rules.owners.cortex_page_scraps=="memory_table" and app.rules.owners.cortex_page_fragment=="hero","tear leaves remainder on table without stealing the held corner")
 check(roundtrip() and app.cortex.data.paper.phase=="collect","JSON preserves unfinished physical gathering without transferring scraps early")
 check(until4(func():return app.cortex.data.paper.phase=="retreat",2),"timed gathering actually transfers table scraps at contact")
 check(app.rules.owners.cortex_page_scraps=="stitched" and app.rules.owners.cortex_page_fragment=="hero","NPC collects only the remainder; protagonist keeps the corner")
 check(until4(func():return app.cortex.data.paper.phase=="done",4),"after gathering stitched actor actually retreats to table side")
 check(app.cortex.position("stitched").distance_to(tear_position)>0.4 and event_count4("cortex:1:paper_collected")==1,"retreat moves real body and scraps transfer has one receipt")
 await capture("02b_paper_gathered_and_retreat_complete")
 check(app.cortex.data.paper.remaining=="corner" and app.rules.owners.cortex_page_fragment=="hero" and app.rules.owners.cortex_original_page=="torn","still-gripped corner has one actual owner; original is not duplicated")
 var previous_key:String=app.session.data.key_target
 check(app.cortex.data.paper.read_fields.get("name",null)==null and app.session.data.key_target==previous_key,"unknown page text stays unknown and tearing cannot destroy the key")
 var attempt:int=app.rules.actual_attempt
 app.restart_attempt(3,true);clear_lines();app.session.data.exploration_boundary=true
 check(app.rules.actual_attempt==attempt+1 and app.cortex.data.paper.remaining=="corner" and app.rules.owners.cortex_page_fragment=="hero","actual L4 death restart retains the same acquired corner without restoring the original")
 check(roundtrip() and app.rules.owners.cortex_page_fragment=="hero","retained original fragment survives JSON after retry")

 fixture4("memory");spawn4("stitched");app.hero_pos=app.cortex.point("memory",1)
 begin4("cortex_original_page")
 check(until4(func():return app.cortex.data.paper.phase=="tear",4),"second declared fixture reaches actual pinched page")
 step4(0.2);give_skill("WITHDRAW");var neurons:int=app.rules.neurons;cast("WITHDRAW")
 check(not app.cortex.data.paper.gripped and app.cortex.data.observation.is_empty() and app.rules.neurons==neurons-int(app.rules.spec("WITHDRAW").cost),"paid withdrawal cancels page reading and actually drops the unacquired corner")
 check(until4(func():return app.cortex.data.paper.phase=="done",4),"stitched actor can only finish tearing material left on the table")
 check(app.rules.owners.cortex_page_fragment=="none" and app.rules.owners.cortex_page_scraps=="stitched" and not app.cortex.data.paper.taken,"cancelled read grants no corner while NPC gathers only actual abandoned scraps")

 fixture4("memory");app.hero_pos=app.cortex.point("memory",1)
 begin4("cortex_original_page")
 check(until4(func():return app.cortex.data.paper.taken,5),"without the destructive actor a real complete read retains the original")
 spawn4("stitched");step4(1)
 check(app.rules.owners.cortex_original_page=="hero" and not app.cortex.data.paper.attempted,"later actor presence cannot steal an already-acquired original")

 fixture4("memory");history_fixture();app.hero_pos=app.cortex.point("memory",3)
 var before_replay_facts:int=app.rules.facts.size();var old_snapshot:Dictionary=app.cortex.data.duplicate(true);old_snapshot.erase("playbacks")
 app.cortex.restore(old_snapshot)
 check(app.cortex.data.playbacks.is_empty() and app.rules.facts.size()==before_replay_facts,"older B4 save gets empty replay state without starting playback or creating facts")
 var replay_hp:int=app.rules.hp;var replay_neurons:int=app.rules.neurons
 check(begin4("cortex_memory_replay"),"source-bound television playback begins through actual contact")
 step4(0.6)
 var replay_time:float=app.cortex.data.playbacks.cortex_memory_replay.elapsed
 check(replay_time>0 and replay_time<3.5 and not app.cortex.data.completed_observations.has("cortex_memory_replay"),"clip has real elapsed playback before any completed viewing knowledge")
 await frames(12)
 check(app.cortex.data.playbacks.cortex_memory_replay.elapsed==replay_time,"manual pause freezes source clip playback clock")
 var replay_before:Dictionary=app.cortex.data.playbacks.cortex_memory_replay.duplicate(true)
 var saved_replay:bool=roundtrip()
 var replay_after:Dictionary=app.cortex.data.playbacks.cortex_memory_replay
 var same_source:bool=JSON.stringify(JSON.parse_string(JSON.stringify(replay_before.source)),"",true)==JSON.stringify(JSON.parse_string(JSON.stringify(replay_after.source)),"",true)
 check(saved_replay and is_equal_approx(float(replay_after.elapsed),replay_time) and replay_after.phase=="playing" and same_source,"JSON retains in-progress clip time, playing phase and original source instead of restarting the event")
 if not saved_replay or not is_equal_approx(float(replay_after.elapsed),replay_time) or replay_after.phase!="playing" or not same_source:print("REPLAY_DIAGNOSTIC ",JSON.stringify({"saved":saved_replay,"before":replay_before,"after":replay_after,"same_source":same_source}))
 check(marker4("cortex_memory_replay").progress>0 and not marker4("cortex_memory_replay").voice_available,"screen exposes real source frame progression and explicitly lacks formal voice")
 await capture("02c_existing_event_playback_in_progress")
 check(until4(func():return app.cortex.data.completed_observations.has("cortex_memory_replay"),5),"television must finish actual source playback before completion")
 check(app.rules.hp==replay_hp and app.rules.neurons==replay_neurons and event_count4("hospital:1:patient_transport")==1,"replay cannot duplicate source damage, material reward or transfer event")
 check(begin4("cortex_memory_replay"),"manual replay is repeatable without reopening autonomous infinite reads")
 check(until4(func():return app.cortex.data.observation.is_empty(),5) and event_count4("cortex:1:observation:cortex_memory_replay:1")==1,"playing again does not duplicate completed-observation settlement")
 app.hero_pos=app.cortex.point("memory",4)
 check(begin4("cortex_audio_replay"),"recorder starts its own real playback control without fabricating recorded speech")
 step4(0.5);app.cortex.cancel_observation("test_cancel")
 var stopped_time:float=app.cortex.data.playbacks.cortex_audio_replay.elapsed;step4(1)
 check(app.cortex.data.playbacks.cortex_audio_replay.elapsed==stopped_time and not app.cortex.data.completed_observations.has("cortex_audio_replay"),"interrupted recorder stops playback and grants no unseen completion")

 fixture4("visual");spawn4("blindfold")
 check(not app.cortex.available(app.cortex.specification("cortex_visual_watch")),"no actual transfer history means no invented patient footage")
 app.rules._record("hospital_relic_container_arrived","hospital:1:bag_arrived",{"item":"hospital_relic_container"});app.cortex.bind_evidence()
 check(app.cortex.data.video.source.is_empty(),"bag or shoe transport never becomes footage of a patient")
 history_fixture();app.hero_pos=app.cortex.point("visual",3)
 check(begin4("cortex_visual_watch"),"viewing starts only with a bound original patient event and screen contact")
 check(until4(func():return app.cortex.data.video.mask_count>=1,5),"blindfold actor reaches console and completes actual one-second first mask")
 var mask_count:int=app.cortex.data.video.mask_count
 var first_faces:Array=marker4("cortex_video").faces
 check(first_faces.size()==3 and first_faces[0].masked and not first_faces[1].masked and not first_faces[2].masked,"first mask renders only first perpetrator face; second and patient stay visible")
 check(roundtrip() and app.cortex.data.video.mask_count==mask_count,"JSON preserves already-applied image mask")
 check(until4(func():return app.cortex.data.video.mask_count==2,5),"second original actor face is masked only after its own one-second operation")
 var second_faces:Array=marker4("cortex_video").faces
 check(second_faces.size()==3 and second_faces[0].masked and second_faces[1].masked and not second_faces[2].masked,"second operation has two distinct face masks while patient depiction remains unmasked")
 check(app.cortex.data.video.source.subject=="hospital_wheelchair_patient" and app.rules.hp==100,"overlay and masking preserve original patient identity and add no damage")
 await capture("03_real_bound_clip_masking")
 app.restart_attempt(3,true);clear_lines();app.session.data.exploration_boundary=true
 check(app.cortex.data.video.mask_count==2 and app.cortex.data.video.phase=="done","retry does not restore a modified original clip to replay the erasure")

 fixture4("decision");app.hero_pos=app.cortex.point("decision",2);spawn4("repeater")
 app.cortex.face_target("repeater",app.cortex.position("repeater")+(app.cortex.position("repeater")-app.hero_pos))
 give_skill("GUT");cast("GUT");step4(0.7)
 check(app.cortex.visible("repeater",app.hero_pos,app.room_id,2) and not app.cortex.data.mimic.attempted,"geometric proximity and LOS cannot grant sight to a back-facing repeater")
 fixture4("decision");app.hero_pos=app.cortex.point("decision",2);spawn4("repeater");app.cortex.face_target("repeater",app.hero_pos)
 var before_actions:int=app.rules.facts.size();app.cortex.on_skill({"success":false,"id":"GUT","event_id":"negative-resisted"});step4(0.2)
 check(not app.cortex.data.mimic.attempted,"resisted neural input cannot cause imitation")
 give_skill("GUT");cast("GUT");step4(0.025)
 check(app.cortex.data.mimic.attempted and app.cortex.data.mimic.source.origin=="neural_intervention","actual visible successful reaction captures its true intervention source")
 check(not app.cortex.data.mimic.written,"seeing or imitating an action does not pre-write the institution record")
 check(until4(func():return app.cortex.data.mimic.written,8),"repeater finishes imitation, approaches board and physically writes")
 check(app.cortex.data.mimic.source.skill=="GUT" and app.rules.facts.size()>before_actions and app.rules.hp==100,"institutional autonomous label never replaces original neural source or repeats harm")
 check(roundtrip() and app.cortex.data.mimic.written,"saved completed imitation cannot replay its actual write")
 await capture("04_mimic_actual_written_record")
 fixture4("decision");app.hero_pos=app.cortex.point("decision",2);spawn4("repeater");app.cortex.face_target("repeater",app.hero_pos);give_skill("CONTROL");cast("CONTROL");step4(0.2)
 check(not app.cortex.data.mimic.attempted,"entering CONTROL alone has no visible action for imitation")
 var control_start:Vector2=app.hero_pos
 app.hero_route=app.layout.path(app.hero_pos,app.hero_pos+Vector2(0,-0.3));app.move_hero(0.15);step4(0.025)
 check(app.hero_pos.distance_to(control_start)>0.001,"controlled test actually moves into clear floor, not into the board collider")
 check(app.cortex.data.mimic.attempted and app.cortex.data.mimic.source.origin=="controlled","only actual controlled movement is a valid imitation source")

 fixture4("body");spawn4("misaligned");check(begin_touch(),"touch-table physical search actually begins")
 check(until4(func():return app.cortex.data.clamp.phase=="windup",5),"operator approaches side handle before clamp windup")
 var elapsed:float=app.cortex.data.clamp.elapsed;step4(0.5)
 check(app.rules.hp==100 and app.cortex.data.clamp.elapsed>=elapsed,"clamp does not inflict damage before 0.8-second close")
 await capture("05_clamp_visible_windup")
 check(roundtrip() and app.rules.hp==100,"clamp windup JSON creates no early contact settlement")
 check(until4(func():return app.cortex.data.clamp.phase=="release",2),"actual close reaches held-hand contact")
 check(app.rules.hp==90 and app.rules.gripped and app.cortex.data.clamp.pain_light and not app.rules.search_active,"actual clamp contact damages ten, lights pain and interrupts current search")
 give_skill("JOY");cast("JOY")
 check(app.rules.gripped,"mental joy cannot release an already-closed physical clamp")
 check(until4(func():return app.cortex.data.clamp.phase=="done",1.1),"fixed at-most-one-second reset releases without another fee or answer")
 check(not app.rules.gripped and app.rules.hp==90 and app.cortex.data.holder=="","release clears unique physical holder without refunding injury")
 check(roundtrip(),"completed clamp can round-trip via actual JSON")
 begin_touch();step4(2)
 check(app.rules.hp==90 and app.cortex.data.clamp.phase=="done","same attempt does not start a second clamp on retry search")

 fixture4("body");spawn4("misaligned");begin_touch();until4(func():return app.cortex.data.clamp.phase=="windup",5)
 give_skill("WITHDRAW");cast("WITHDRAW")
 check(until4(func():return app.cortex.data.clamp.phase=="done",2.2),"paid early withdrawal has time for visible retraction and empty reset")
 check(app.rules.hp==100 and not app.cortex.data.clamp.hurt and app.cortex.data.clamp.hand_out,"empty clamp has no fabricated hand injury or pain light")

 fixture4("body");spawn4("misaligned");give_skill("CONTROL");cast("CONTROL");step4(0.2);begin_touch()
 await right_turn(app.hero_pos+Vector2(-1.0,0))
 step4(0.35)
 check(app.hero_facing.x< -0.9 and not app.cortex.searching_touch() and not app.cortex.data.clamp.attempted,"actual CONTROL right click away before touch prevents a backwards hand-contact trigger")
 await right_turn(app.hero_pos+Vector2(1.0,0))
 check(app.hero_facing.x>0.9 and until4(func():return app.cortex.data.clamp.phase=="windup",3),"actual right click toward table permits the physically facing touch")
 await right_turn(app.hero_pos+Vector2(-1.0,0))
 var hand:Dictionary=app.cortex.clamp_hand_state()
 check(hand.contact and hand.extension>0 and hand.extension<1,"turning after touch starts visible withdrawal rather than instant hand immunity")
 check(roundtrip() and app.cortex.data.clamp.retract_left>0,"active turn-away hand retraction survives actual JSON")
 step4(0.25)
 check(not app.cortex.clamp_hand_state().contact and app.cortex.data.clamp.hand_out,"after full 0.2 second withdrawal the physical hand leaves the clamp")
 check(until4(func():return app.cortex.data.clamp.phase=="done",2.5) and app.rules.hp==100,"early real right-click withdrawal leaves an empty clamp")

 fixture4("body");spawn4("misaligned");give_skill("CONTROL");cast("CONTROL");step4(0.2);begin_touch()
 until4(func():return app.cortex.data.clamp.phase=="windup",3);step4(0.65)
 await right_turn(app.hero_pos+Vector2(-1.0,0))
 check(app.hero_facing.x< -0.9 and app.cortex.data.clamp.retract_left>0,"late physical right-click turn still has unfinished withdrawal")
 check(until4(func():return app.cortex.data.clamp.phase=="done",2) and app.rules.hp==90,"late turn cannot evade a close that reaches the still-withdrawing hand first")

 fixture4("body");spawn4("misaligned");begin_touch();until4(func():return app.cortex.data.clamp.phase=="windup",5)
 app.hero_facing=Vector2(1,0);give_skill("KNEE");cast("KNEE")
 check(until4(func():return app.cortex.data.clamp.phase=="done",2.5),"wrong-facing knee cannot remotely cancel a physically closing clamp")
 check(app.rules.hp==90,"a successful neural knee with no operator hit does not grant automatic clamp immunity")

 fixture4("body");spawn4("misaligned");begin_touch();until4(func():return app.cortex.data.clamp.phase=="windup",5)
 app.hero_facing=(app.cortex.position("misaligned")-app.hero_pos).normalized();give_skill("KNEE");cast("KNEE")
 check(until4(func():return app.cortex.data.clamp.phase=="done",2.5),"front-facing actual knee contact interrupts operator before closure")
 check(app.rules.hp==100 and app.cortex.data.clamp.hand_out,"actual in-range knee contact prevents only the unfinished clamp")
 finish4()
