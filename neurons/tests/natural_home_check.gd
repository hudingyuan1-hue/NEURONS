extends Node
## Natural first-attempt observation through the normal title and world loop.
## Only viewport clicks are submitted: create profile, skip tutorial, next line.
## No seed, actor, resource, probability, route, counter or story fixtures.
const FRAME_LIMIT:int=12000
const STALLED_FRAME_LIMIT:int=900
var frontend
var app
var folder:String="res://../docs/validation/feedback_20261015/natural-home"
var start_frame:int=0
var first_cycle:int=0
var first_attempt:int=0
var first_level:int=0
var dialogue_advances:int=0
var passes:Array=[]
var failures:Array=[]
var screenshots:Array=[]
var observations:Array=[]
var seen_facts:Array=[]
var fact_keys:Dictionary={}
var initial_snapshot:Dictionary={}
var last_snapshot:Dictionary={}
var npc_seen:bool=false
var finished:bool=false
var last_progress_frame:int=0
var last_progress:String=""
var last_stage:String=""

func elapsed_frames() -> int:
 return Engine.get_process_frames()-start_frame

func frames(count:int=1) -> void:
 for index in range(count):
  if elapsed_frames()>=FRAME_LIMIT:return
  await get_tree().process_frame

func button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text) and child.is_visible_in_tree() and not child.disabled:return child
  var found:Button=button(child,text)
  if found!=null:return found
 return null

func click(target:Button) -> bool:
 if target==null or not is_instance_valid(target) or not target.is_visible_in_tree() or target.disabled:return false
 var point:Vector2=target.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point
 Input.parse_input_event(move)
 await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(2)
 return true

func write_json(name:String,data) -> bool:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join(name),FileAccess.WRITE)
 if output==null:
  failures.append("Cannot write observation file: "+name)
  return false
 output.store_string(JSON.stringify(data,"  "));output.close()
 return true

func capture(name:String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path:String=ProjectSettings.globalize_path(folder).path_join(name+".png")
 var error:int=get_viewport().get_texture().get_image().save_png(path)
 if error==OK:screenshots.append({"name":name+".png","frame":elapsed_frames()})
 else:failures.append("Screenshot could not be saved: "+name)

func resources() -> Dictionary:
 return {"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"plexus":app.rules.plexus,
  "owners":app.rules.owners.duplicate(true),"inventory":app.family.data.get("inventory",[]).duplicate()}

func record_state(label:String) -> void:
 observations.append({"label":label,"frame":elapsed_frames(),"world_time":app.rules.world_time,
  "level":app.session.data.level,"room":app.room_id,"cycle":app.session.data.cycle,
  "actual_attempt":app.rules.actual_attempt,"search_attempts":app.rules.search_attempts,
  "search_completed":app.rules.search_count,"hero_pos":[app.hero_pos.x,app.hero_pos.y],
  "action_phase":app.action_phase,"hero_state":app.hero_state,"resources":resources(),
  "npcs":npc_state(),"status_note":app.status_note})

func npc_state() -> Dictionary:
 var state:Dictionary={}
 for id in ["dog","cat"]:state[id]=app.home.data.get(id,{}).duplicate(true)
 for id in ["mother","father"]:state[id]=app.family.data.get(id,{}).duplicate(true)
 return state

func observe_facts() -> void:
 for fact in app.rules.facts:
  var key:String=JSON.stringify(fact)
  if not fact_keys.has(key):
   fact_keys[key]=true;seen_facts.append(fact.duplicate(true))

func has_npc() -> bool:
 for actor in npc_state().values():
  if bool(actor.get("present",false)):return true
 return false

func stage_signature() -> String:
 var phases:Array=[]
 var actors:Dictionary=npc_state()
 for id in actors:
  phases.append([id,bool(actors[id].get("present",false)),str(actors[id].get("phase",""))])
 return JSON.stringify([app.room_id,app.action_phase,app.hero_state,app.target_index,
  app.rules.search_attempts,app.rules.search_count,app.rules.hp,app.rules.sp,
  app.session.data.key_owner,phases,app.family.data.get("collapse",{}).get("index",-1)])

func progress_signature() -> String:
 # Exclude world time, audio positions and decorative motion: those advance
 # even if navigation or an action is stuck. Timers saturate to expose waits
 # which should already have completed, rather than hiding them indefinitely.
 var positions:Array=[]
 var actors:Dictionary=npc_state()
 for id in actors:
  var actor:Dictionary=actors[id]
  var pos:Array=actor.get("pos",[])
  positions.append([id,pos.map(func(value):return snappedf(float(value),0.02)),
   snappedf(clampf(float(actor.get("elapsed",0)),0,30),0.05),
   snappedf(clampf(float(actor.get("left",0)),0,30),0.05)])
 var line:String="" if app.dialogue_queue.is_empty() else JSON.stringify(app.dialogue_queue[0])
 return JSON.stringify([stage_signature(),snappedf(app.hero_pos.x,0.02),snappedf(app.hero_pos.y,0.02),
  snappedf(app.rules.search_elapsed,0.05),snappedf(maxf(0,app.action_left),0.05),
  snappedf(maxf(0,app.rules.reaction_left),0.05),snappedf(maxf(0,app.rules.hurt_left),0.05),
  app.rules.facts.size(),app.rules.owners,app.dialogue_queue.size(),line,positions,
  snappedf(clampf(float(app.family.data.get("collapse",{}).get("elapsed",0)),0,30),0.05),
  snappedf(clampf(float(app.family.data.get("eating",{}).get("elapsed",0)),0,30),0.05)])

func endpoint() -> String:
 if int(app.session.data.level)>=2 and app.room_id in ["ward","lobby","clinic","pharmacy","office"]:return "hospital_entered"
 if bool(app.family.data.get("hidden_pending",false)):return "hidden_street_development_boundary"
 if int(app.session.data.cycle)>first_cycle or int(app.rules.actual_attempt)>first_attempt:return "first_attempt_finished"
 return ""

func finish(kind:String,reason:String) -> void:
 if finished:return
 finished=true
 if is_instance_valid(app):
  observe_facts();record_state("terminal_observation")
  last_snapshot=app.snapshot_data()
  write_json("final_snapshot.json",last_snapshot)
  await capture("03_terminal_"+kind)
 var result:Dictionary={"passes":passes,"failures":failures,"no_gameplay_fixture":true,
  "scope":"automated viewport mouse input; natural RNG and ordinary _process; not human play, all branches, audio acceptance or game completion",
  "engine_time_scale":Engine.time_scale,"accelerated_engine_time":Engine.time_scale>1.0,
  "elapsed_process_frames":elapsed_frames(),"frame_limit":FRAME_LIMIT,"stall_frame_limit":STALLED_FRAME_LIMIT,
  "endpoint":{"kind":kind,"reason":reason,"is_game_completion":false},
  "initial_cycle":first_cycle,"initial_actual_attempt":first_attempt,"initial_level":first_level,
  "dialogue_advance_clicks":dialogue_advances,"first_npc_observed":npc_seen,
  "screenshots":screenshots,"observations":observations,"actual_event_facts":seen_facts,
  "last_snapshot_file":"final_snapshot.json" if not last_snapshot.is_empty() else "",
  "rendered":not screenshots.is_empty()}
 if is_instance_valid(app):
  result.final_resources=resources()
  result.final_search_attempts=app.rules.search_attempts;result.final_search_completed=app.rules.search_count
  result.final_known_information=app.rules.known.duplicate(true)
  result.final_institutional_records=app.rules.institutional_records.duplicate(true)
  result.final_cycle=app.session.data.cycle;result.final_actual_attempt=app.rules.actual_attempt
  result.cycle_delta=int(app.session.data.cycle)-first_cycle
  result.actual_attempt_delta=int(app.rules.actual_attempt)-first_attempt
  result.final_level=app.session.data.level;result.final_room=app.room_id
 write_json("result.json",result)
 print("NATURAL_HOME_CHECK %d passed %d failed / %s"%[passes.size(),failures.size(),kind])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();start_frame=Engine.get_process_frames()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 var directory_error:int=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if directory_error!=OK:
  print("NATURAL_HOME_CHECK output directory unavailable");frontend.request_exit(1);return
 if frontend.store.root=="user://profiles":
  failures.append("Natural check requires the registered isolated test save directory or an explicit --save-root")
  await finish("unsafe_save_root","No profile button was clicked and no player save was overwritten");return
 await frames(8);get_window().grab_focus();await frames(3)
 if not await click(button(frontend,"建立档案")):
  failures.append("Normal new-profile button unavailable");await finish("startup_failed","Cannot enter profile UI");return
 await frames(3)
 if frontend.name_field==null:
  failures.append("Profile UI did not open through actual click");await finish("startup_failed","Profile UI absent");return
 # Keep the ordinary randomly generated name and invader number. A previous
 # test save, if present, is overwritten only by its ordinary confirmation UI.
 for attempt in range(2):
  if frontend.active!=null:break
  if not await click(button(frontend,"建立并开始")):break
  await frames(3)
 if frontend.active==null:
  failures.append("Actual create/confirmation clicks did not launch campaign")
  await finish("startup_failed","Campaign was not created");return
 app=frontend.active
 initial_snapshot=app.snapshot_data()
 write_json("initial_profile_snapshot.json",initial_snapshot)
 first_cycle=int(app.session.data.cycle);first_attempt=int(app.rules.actual_attempt);first_level=int(app.session.data.level)
 if first_level!=1 or first_attempt!=1 or first_cycle!=1:
  failures.append("Normal new profile did not start at the first home attempt")
  await finish("unexpected_initial_state","No gameplay state was corrected by the driver");return
 passes.append("Actual title/profile UI starts an ordinary random first home attempt")
 if app.tutorial_ui!=null:
  if not await click(button(app.tutorial_ui,"跳过练习")):
   failures.append("Tutorial skip button could not be clicked");await finish("startup_failed","Tutorial remains open");return
  await frames(3)
 if app.tutorial_ui!=null:
  failures.append("Tutorial skip click did not close practice");await finish("startup_failed","Practice did not close");return
 passes.append("Practice is skipped through its visible button; the driver writes no gameplay fields")
 write_json("initial_world_snapshot.json",app.snapshot_data())
 record_state("initial_world");observe_facts();await capture("01_initial_world")
 if has_npc():
  npc_seen=true;record_state("first_npc");await capture("02_first_npc")
 last_progress=progress_signature();last_progress_frame=elapsed_frames();last_stage=stage_signature()
 while elapsed_frames()<FRAME_LIMIT:
  if not is_instance_valid(app) or frontend.active!=app:
   failures.append("Campaign unexpectedly left normal play before an observed endpoint")
   await finish("campaign_disappeared","No attempt-end, hospital or Street boundary was observed");return
  observe_facts()
  var reached:String=endpoint()
  if not reached.is_empty():
   passes.append("Natural first attempt reaches an actual observed endpoint without gameplay fixtures")
   await finish(reached,"Street, if reached, is a development boundary and is not a completed level or ending");return
  if not npc_seen and has_npc():
   npc_seen=true;record_state("first_npc");await capture("02_first_npc")
  var stage:String=stage_signature()
  if stage!=last_stage:
   record_state("stage_change");last_stage=stage
  var progress:String=progress_signature()
  if progress!=last_progress:
   last_progress=progress;last_progress_frame=elapsed_frames()
  elif elapsed_frames()-last_progress_frame>=STALLED_FRAME_LIMIT:
   failures.append("No meaningful action, movement, contact, timer or dialogue progress for %d process frames"%STALLED_FRAME_LIMIT)
   await finish("stalled","World-clock or decorative progression alone cannot count as playable progress");return
  if not app.dialogue_queue.is_empty() and app.dialogue_panel.visible:
   var before:String=JSON.stringify(app.dialogue_queue)
   var next:Button=button(app.dialogue_panel,"继续")
   if next!=null and await click(next):
    if JSON.stringify(app.dialogue_queue)!=before:dialogue_advances+=1
  # Always yield, including when a visible dialogue unexpectedly has no usable
  # next button; a broken UI must fail the watchdog rather than block the loop.
  await frames(1)
 failures.append("No real first-attempt endpoint before the finite %d-frame limit"%FRAME_LIMIT)
 await finish("frame_limit","Actual current state retained; no forced advance or success claim")
