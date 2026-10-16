extends "res://tests/asylum_ui_check.gd"
## S1:P103 / PRODUCTION_PLAN EV_L3_WARD: the existing single-ward door's
## observation shutter opens only from its lobby side. No new room/exit,
## search point, reward, NPC opening scene or automatic knowledge is seeded.
var window_input_trace:Array=[]

func window3() -> Dictionary:return app.asylum.ward_window_state()
func window_changes() -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.get("kind",""))=="asylum_ward_window_changed":count+=1
 return count

func capture(image_name:String) -> void:
 await frames(2);app.view.queue_redraw();RenderingServer.force_draw(false)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(image_name+".png"))

func window_fixture(room:String="lobby") -> void:
 app.asylum.data={};fixture3(room,true)
 app.session.data.exploration_boundary=true;app.hero_route=PackedVector2Array();app.target_index=-1
 app.hero_pos=app.asylum.ward_window_position(room)+(Vector2(0,0.45) if room=="lobby" else Vector2.ZERO)
 app.hero_facing=Vector2.UP

func paid_window_control() -> bool:
 give_skill("CONTROL")
 var result:Dictionary=cast("CONTROL")
 clear_lines()
 return result.get("success",false) and app.rules.control_left>0 and app.rules.neurons==45

func live_window_until(predicate:Callable,seconds:float=4.0) -> bool:
 var elapsed:float=0.0
 while elapsed<seconds:
  if predicate.call():return true
  var start_frame:int=Engine.get_process_frames()
  if not app.dialogue_queue.is_empty():await continue_live_line()
  else:await frames(1)
  elapsed+=float(maxi(1,Engine.get_process_frames()-start_frame))*get_process_delta_time()
 return predicate.call()

func trace_window_input(label:String) -> void:
 window_input_trace.append({"label":label,"window":window3().duplicate(true),"room":app.room_id,"hero":[app.hero_pos.x,app.hero_pos.y],"phase":app.action_phase,
  "route":Array(app.hero_route).map(func(p):return [p.x,p.y]),"control_left":app.rules.control_left,"public_action":app.rules.public_action.duplicate(true),
  "dialogue":app.dialogue_queue.duplicate(true),"awareness_feedback":app.rules.awareness_feedback.duplicate(),"world_paused":app.world_paused(),"input_lock_frames":app.input_lock_frames})
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("window_input_trace.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(window_input_trace,"  "));f.close()

func finish3() -> void:
 var result:Dictionary={"passes":passes,"failures":failures,"rendered":true,
  "source":"S1:P103 and PRODUCTION_PLAN EV_L3_WARD; current topology ward<->lobby, no new edge. Gesture 0.2s prepare/0.2s contact/0.2s finish is an explicitly replaceable presentation parameter, not source-authored gameplay timing.",
  "scope":"Independent ward observation-window state: exterior-only physical contact, distance/LOS/control rejection, pre-contact cancellation and post-contact retention, checksummed mid-action/completed JSON, world/manual/CRT pause, no extra search/reward/room knowledge, shared inside/outside placeholder marker and actual paid CRT/world-mouse approach/open/close/cancel/inside rejection. Not natural-RNG whole B3, approved art or subjective audio.",
  "fixtures":"Explicit walkable lobby/ward starting stands; all random arrival groups held drawn, 50N/unlocked CONTROL fixture before genuine skill payment. One real blocker checks occlusion. Finite rules cases use 0.025s campaign steps; real mouse cases use ordinary _process and actual Enter for feedback. No successful opening, closing, touch receipt or inside knowledge is assigned.",
  "methods":{"actual_checksummed_json":true,"actual_mouse_sequences":true,"human_playthrough":false,"audio_listened":false}}
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("ASYLUM_WINDOW_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/window"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="病房门观察窗验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 window_fixture()
 check(Map.GRAPH.ward==["lobby"] and Map.GRAPH.lobby.has("ward") and Map.candidates().size()==45 and Session.point_names(3,"ward").is_empty(),"observation window uses the existing ward/lobby door and adds no room, exit or key-search candidate")
 check(app.layout.walkable(app.hero_pos) and not window3().open and window3().action.is_empty(),"new missing-state ward shutter starts closed with a genuine walkable exterior contact stand")
 check(not app.asylum.begin_ward_window(true) and app.asylum.ward_window_request(true).is_empty(),"exterior click without a legal CONTROL window cannot start a body operation")
 check(window_changes()==0 and app.rules.neurons==5 and app.rules.search_attempts==0,"rejected operation gives no state change, payment, reward or search use")
 check(paid_window_control(),"finite contact checks first pay the real CONTROL fee")
 app.hero_pos=Vector2(3.4,2.0)
 check(not app.asylum.begin_ward_window(true) and not window3().open,"distant exterior protagonist cannot remotely open the shutter")
 app.hero_pos=app.asylum.ward_window_position("lobby")+Vector2(0,0.45)
 var door:Vector2=app.asylum.ward_window_position("lobby")
 app.layout.movable_blockers.append(Rect2(door+Vector2(-0.2,0.16),Vector2(0.4,0.06)))
 check(app.layout.walkable(app.hero_pos) and not app.layout.clear_segment(app.hero_pos,door),"LOS fixture has a walkable near stand separated from the actual shutter by one real obstruction")
 check(not app.asylum.begin_ward_window(true) and window_changes()==0,"in-range contact cannot operate through that blocker")
 window_fixture("ward");check(paid_window_control(),"interior-side rejection also uses a genuinely paid CONTROL window")
 check(not app.asylum.begin_ward_window(true) and app.asylum.ward_window_request(true).is_empty() and not window3().open,"standing inside the ward cannot start an exterior-only shutter operation")
 await capture("01_inside_closed_exterior_only_label")

 window_fixture();check(paid_window_control(),"pause/interruption fixture obtains real legal body control")
 var known_before:Array=app.rules.known.duplicate()
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus
 check(app.asylum.begin_ward_window(true),"near clear exterior contact starts visible reach toward the existing shutter")
 step3(0.19)
 check(not window3().open and window3().action.phase=="prepare" and window_changes()==0,"unfinished preparation cannot open the aperture or settle contact")
 var elapsed:float=float(window3().action.elapsed);var world:float=app.rules.world_time
 check(roundtrip() and is_equal_approx(float(window3().action.elapsed),elapsed) and not window3().open,"partly reaching hand and closed state survive real checksummed JSON")
 await frames(12)
 check(is_equal_approx(app.rules.world_time,world) and is_equal_approx(float(window3().action.elapsed),elapsed),"manual pause freezes window gesture and world time together")
 app.paused_manual=false;app.open_neuron_menu();await frames(12)
 check(app.menu.visible and is_equal_approx(app.rules.world_time,world) and is_equal_approx(float(window3().action.elapsed),elapsed),"actual CRT menu freezes the in-flight operation while interface processing continues")
 app.paused_manual=true;app.close_neuron_menu();await get_tree().create_timer(0.25).timeout
 # Same production operations as the visible hand-back-control button.
 app.rules.end_control();app.cancel_control_route();step3(0.5)
 check(window3().action.is_empty() and not window3().open and window_changes()==0,"giving back control before contact cancels the reach without a delayed opening")
 check(roundtrip() and not window3().open and app.rules.known==known_before and app.rules.neurons==neurons and app.rules.plexus==clusters and app.rules.search_attempts==0,"cancelled-action JSON grants no hidden room knowledge, resources or extra search")

 window_fixture();check(paid_window_control(),"post-contact interruption fixture again pays real CONTROL")
 known_before=app.rules.known.duplicate();neurons=app.rules.neurons;clusters=app.rules.plexus
 check(app.asylum.begin_ward_window(true),"second real exterior operation begins from the unchanged doorway")
 step3(0.4)
 check(window3().open and window3().action.contact_done and window_changes()==1,"actual prepared contact opens the shutter once before the hand finishes retracting")
 check(roundtrip() and window3().open and window3().action.contact_done,"mid-retraction disk restore retains already-completed contact instead of replaying it")
 app.rules.end_control();app.cancel_control_route();step3(0.5)
 check(window3().open and window3().action.is_empty() and window_changes()==1,"post-contact interruption keeps the real open state without a second settlement")
 check(app.rules.known==known_before and app.rules.neurons==neurons and app.rules.plexus==clusters and app.rules.search_attempts==0 and app.asylum.isolation.can_exit("ward","lobby"),"opening reveals no unobserved content, grants no reward and leaves the actual ward doorway usable")
 var remaining:float=maxf(0.025,float(app.rules.skill_states.CONTROL.until)-app.rules.world_time+0.025)
 step3(remaining)
 check(cast("CONTROL").get("success",false),"second control period follows its existing world-clock cooldown")
 clear_lines();check(app.asylum.begin_ward_window(true),"open shutter can be closed only by another actual exterior hand action")
 step3(0.65)
 check(not window3().open and window3().action.is_empty() and window_changes()==2,"completed close gesture changes only the shutter and has exactly one separate contact")
 check(roundtrip() and not window3().open and window_changes()==2,"closed-state reload cannot repeat either previous open or close contact")
 await capture("02_exterior_real_contact_then_close")

 # Actual viewport mouse/normal process from here; no manual world steps or
 # direct begin/cancel API is used to manufacture the observed state changes.
 window_fixture();app.hero_pos=Vector2(2.9,1.4);app.session.data.targets=[];app.session.data.exploration_boundary=false
 check(await legal_control(),"real CRT mouse submits paid CONTROL for the exterior marker")
 var start:Vector2=app.hero_pos
 trace_window_input("before_first_marker_click")
 await world_click(app.asylum.ward_window_position("lobby"),false,Vector2(0,-49))
 trace_window_input("after_first_marker_click")
 check(app.action_phase in ["asylum_read_route","asylum_reading"] or not window3().action.is_empty(),"actual exterior window click requests the existing physical route/action interface")
 check(await live_window_until(func():return bool(window3().open),4),"ordinary process moves to the outside handle and really opens after mouse input")
 check(app.hero_pos.distance_to(start)>0.2 and app.room_id=="lobby" and window_changes()==1,"mouse opening physically approaches without traversing the door or switching rooms")
 check(await live_window_until(func():return window3().action.is_empty(),2),"first actual mouse gesture retracts normally instead of waiting on a texture frame")
 trace_window_input("first_retraction_done_before_existing_feedback")
 # First controlled body action may queue the existing formal awareness
 # feedback on this exact completion frame. Finish its visible lines through
 # Enter before another world click; never replay a click through that pause.
 check(await live_window_until(func():return not app.world_paused() and app.input_lock_frames<=0,2),"original first-action feedback is actually continued through Enter before the second world click")
 trace_window_input("before_second_marker_click_world_input_ready")
 await world_click(app.asylum.ward_window_position("lobby"),false,Vector2(0,-49))
 trace_window_input("after_second_marker_click")
 check(await live_window_until(func():return not bool(window3().open) and window3().action.is_empty(),3),"second real marker click closes the same shutter under the same paid control window")
 trace_window_input("after_second_close_wait")
 check(app.rules.neurons==45 and app.rules.search_attempts==0 and window_changes()==2,"two physical window gestures consume one original CONTROL fee and no search/reward")
 app.paused_manual=true;await capture("03_actual_mouse_exterior_open_and_close")

 window_fixture();app.session.data.targets=[];app.session.data.exploration_boundary=false
 check(await legal_control(),"new-command interruption starts through genuine CRT input")
 await world_click(app.asylum.ward_window_position("lobby"),false,Vector2(0,-49))
 check(await live_window_until(func():return not window3().action.is_empty(),1),"real marker click begins a genuine unfinished reach")
 await world_click(Vector2(2.7,1.4))
 check(await live_window_until(func():return app.hero_route.is_empty(),3),"actual new floor command walks away through the existing controlled movement path")
 check(window3().action.is_empty() and not window3().open and window_changes()==0,"pre-contact floor command cancels window reach without delayed opening or touch receipt")
 app.paused_manual=true;await capture("04_actual_mouse_new_command_cancels_reach")

 window_fixture("ward");app.session.data.targets=[];app.session.data.exploration_boundary=false
 check(await legal_control(),"final real-input case pays CONTROL while actually inside the ward")
 await world_click(app.asylum.ward_window_position("ward"),false,Vector2(0,-49))
 await frames(6)
 check(app.room_id=="ward" and not window3().open and window3().action.is_empty() and window_changes()==0,"inside-side actual marker click cannot open the shutter or fall through into a door transition")
 check(app.status_note.contains("外侧"),"inside rejection is explained by the exterior-side restriction")
 app.paused_manual=true;await capture("05_actual_mouse_inside_rejection")
 finish3()
