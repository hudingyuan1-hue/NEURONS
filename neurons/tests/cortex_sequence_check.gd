extends "res://tests/cortex_events_check.gd"
## One declared initial actor/target fixture. Ordinary _process and actual
## keyboard/CRT mouse input drive all later movement, contact and settlement.

func tap_key(keycode:int) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=keycode;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func _ready() -> void:
 folder="res://../docs/validation/b4_20261016/recording"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="触觉测试台干预实机"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture4("body")
 app.session.data.targets=["body:5","identity:6"]
 app.session.data.key_target="identity:6";app.session.data.key_owner="identity:6";app.rules.owners.key="identity:6"
 app.session.data.exploration_boundary=false
 app.hero_pos=Vector2(2.8,1.2);spawn4("misaligned",Vector2(3.0,2.0));give_skill("WITHDRAW")
 var initial:Dictionary=app.snapshot_data()
 var first_position:Vector2=app.hero_pos;var actor_position:Vector2=app.cortex.position("misaligned")
 var started:int=Engine.get_process_frames();var stage:int=0;var timeline:Array=[];var previous:String=""
 var first_search:String="";var second_search:String="";var second_started:float=-1
 var first_progress:float=-1;var saw_hand_retraction:bool=false;var recorded_search_duration:float=0
 app.paused_manual=false;get_window().grab_focus()
 # 4,200 captured frames are an explicit bounded recorder timeout; no manual
 # world tick, search start, contact, completion or movement writes follow.
 for index in range(4200):
  var state:Dictionary=app.cortex.data.clamp
  var signature:String=JSON.stringify([stage,state.phase,state.hand_out,app.rules.search_active,app.rules._search_id,app.rules.reaction_left>0,app.menu.visible,app.action_phase,app.dialogue_queue.size()])
  if signature!=previous:
   timeline.append({"frame":Engine.get_process_frames()-started,"world_time":app.rules.world_time,"stage":stage,
    "clamp":state.duplicate(true),"hero":[app.hero_pos.x,app.hero_pos.y],"actor":app.cortex.actor("misaligned").duplicate(true),
    "action":app.action_phase,"menu":app.menu.visible,"hp":app.rules.hp,"neurons":app.rules.neurons,
    "search_active":app.rules.search_active,"search_id":app.rules._search_id,"search_elapsed":app.rules.search_elapsed,"search_duration":app.rules.search_duration,"search_attempts":app.rules.search_attempts})
   previous=signature
  if app.rules.search_active and app.rules.search_target=="body:5":
   recorded_search_duration=app.rules.search_duration
   if first_search.is_empty():first_search=app.rules._search_id
   elif app.rules._search_id!=first_search and second_search.is_empty():second_search=app.rules._search_id;second_started=app.rules.world_time-app.rules.search_elapsed
  if not app.dialogue_queue.is_empty():await continue_live_line();continue
  if stage==0 and state.phase=="windup":
   check(not first_search.is_empty() and app.rules.search_active,"autonomy physically approaches and begins the original touch-table search before the operator acts")
   check(app.hero_pos.distance_to(first_position)>.2 and app.cortex.position("misaligned").distance_to(actor_position)>.1,"hero and operator genuinely move from their stated initial stands")
   check(app.rules.hp==100 and not state.hurt and not state.hand_out,"visible handle preparation has neither early damage nor an already-retracted hand")
   await capture("01_actual_search_and_handle_preparation")
   first_progress=app.rules.search_elapsed
   await tap_key(KEY_TAB)
   check(app.menu.visible,"actual Tab input opens the CRT neural menu during the original closing window")
   var frozen_clock:float=app.rules.world_time;var frozen_clamp:float=state.elapsed;var frozen_search:float=app.rules.search_elapsed
   await frames(36)
   check(is_equal_approx(app.rules.world_time,frozen_clock) and is_equal_approx(float(state.elapsed),frozen_clamp) and is_equal_approx(app.rules.search_elapsed,frozen_search),"real open CRT freezes world clock, closing window and search while its interface continues")
   await capture("02_crt_withdraw_before_contact")
   await click(app.menu.nodes.WITHDRAW)
   stage=1
  elif stage==1 and state.hand_out:
   saw_hand_retraction=true
   check(app.rules.neurons==int(initial.rules.neurons)-int(app.rules.spec("WITHDRAW").cost),"actual CRT mouse submits WITHDRAW once and pays its original cost without an interrupted-search reward")
   check(not app.rules.settled.has(first_search) or app.rules.settled[first_search]!="completed","withdrawal cancels the unfinished original search without a completion receipt")
   await capture("03_hand_retracted_before_empty_clamp")
   stage=2
  elif stage==2 and state.phase=="done" and app.rules.reaction_left<=0:
   check(app.rules.hp==100 and not app.rules.gripped and app.cortex.data.holder=="" and not state.hurt and not state.pain_light,"actual clamp closes empty, resets and releases without invented injury, grip or pain light")
   await capture("04_empty_clamp_then_autonomy")
   stage=3
  elif stage==3 and "body:5" in app.completed:
   await capture("05_resumed_seven_second_search_completed")
   stage=4;await frames(12);break
  await frames(1)
 app.paused_manual=true
 check(stage==4 and saw_hand_retraction,"ordinary process plus real CRT input completes prepare, intervention, visible withdrawal, empty clamp and autonomous search recovery")
 check(first_progress>0 and first_progress<7.0 and not second_search.is_empty() and second_search!=first_search,"real interrupted progress is abandoned and recovery begins a new search instance")
 check(is_equal_approx(recorded_search_duration,7.0) and second_started>=0 and app.rules.world_time-second_started>=7.0-0.04,"recovered touch-table search actually runs the required seven world seconds")
 check(app.rules.search_count==1 and app.rules.search_attempts>=2 and app.rules.settled.get(second_search,"")=="completed","only the later completed search is settled, with both actual starts preserved")
 check(app.cortex.data.receipts.has("cortex:1:clamp_attempt") and app.cortex.data.receipts.has("cortex:1:clamp_missed") and not app.cortex.data.receipts.has("cortex:1:clamp_damage"),"one spent clamp opportunity and one genuine miss survive resumed searching without a second attack")
 check(app.rules.neurons==int(initial.rules.neurons)-int(app.rules.spec("WITHDRAW").cost)+1,"final balance contains exactly one paid intervention and one completed-search neuron")
 check(app.rules.owners.key=="identity:6" and app.session.data.key_owner=="identity:6","interruption and recovery do not move or reroll the unique hidden key")
 var material_cues:Array=[]
 for cue in app.audio.starts:
  if str(cue.event) in ["cortex:1:clamp_handle","cortex:1:clamp_missed"]:material_cues.append(cue)
 check(material_cues.size()==2 and material_cues.all(func(cue):return cue.id=="SFX_DRAWER" and cue.channel=="world" and not cue.provisional),"handle preparation and actual empty closure each play one existing world material cue; no listening claim")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless",
  "frames":Engine.get_process_frames()-started,"timeline":timeline,"initial_fixture":initial,"material_cues":material_cues,
  "scope":"One explicit L4 body-room/body:5 and identity:6 public-target/unique-key-at-identity:6/misaligned-at-(3,2)/hero-at-(2.8,1.2)/50N/unlocked-WITHDRAW fixture with unrelated random NPC draws suppressed. After setup: ordinary _process, actual Enter and Tab keyboard events and CRT mouse input only; no manual advance_world, debug completion or contact mutation. Continuous MovieMaker capture when invoked by recorder; not natural-RNG/full human play/formal-art/audio acceptance."},"  "));file.close()
 print("CORTEX_SEQUENCE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
