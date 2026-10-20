extends "res://tests/opening_campaign_check.gd"
## Actual new-profile flow. No seed/NPC/resource/key/route/position/level fixtures.
## Intro and dialogue run through their presentation clocks, not cleared queues.
var elapsed:float=0.0
var deadline:float=2400.0
var timeline:Array=[]
var level_segments:Array=[]
var room_transitions:Array=[]
var attempts:Array=[]
var searches:Array=[]
var endings:Array=[]
var seen_receipts:Dictionary={}
var seen_attempts:Dictionary={}
var visited_levels:Array=[]
var seen_rooms:Dictionary={}
var last_level:int=0
var level_started:float=0.0
var last_room:String=""
var last_state:String=""
var next_log:float=0.0
var stall:float=0.0
var maximum_stall:float=0.0
var previous_pos:=Vector2.INF
var previous_room:String=""
var first_frame:int=0
var last_frame:int=0
var fixed_delta:float=1.0/30.0
var reason:String=""
var opening_manual_auto:bool=false

func write_json(file_name:String,data:Variant) -> void:
 var file=FileAccess.open(folder.path_join(file_name),FileAccess.WRITE)
 file.store_string(JSON.stringify(data,"  "));file.close()

func ending_state() -> Dictionary:
 if app.street!=null and not app.street.data.get("ending",{}).is_empty():return app.street.data.ending
 if app.hidden_route!=null and not app.hidden_route.data.get("ending",{}).is_empty():return app.hidden_route.data.ending
 return {}

func completed_ending() -> bool:
 return bool(ending_state().get("complete",false)) and app.ending_panel!=null and app.ending_panel.visible

func current_state() -> Dictionary:
 return {"elapsed":elapsed,"world_time":app.rules.world_time,"level":app.session.data.level,"room":app.room_id,"attempt":app.rules.actual_attempt,"cycle":app.session.data.cycle,"pos":[app.hero_pos.x,app.hero_pos.y],"phase":app.action_phase,"pose":app.hero_state,"route_points":app.hero_route.size(),"target":app.target_index,"search_active":app.rules.search_active,"search_elapsed":app.rules.search_elapsed,"search_count":app.rules.search_count,"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"key_owner":app.session.data.key_owner,"gripped":app.rules.gripped,"paused":app.world_paused(),"dialogue_lines":app.dialogue_queue.size(),"ending":ending_state().duplicate(true)}

func legitimate_wait() -> bool:
 if app.opening_ui!=null or app.tutorial_ui!=null or app.world_paused():return true
 if app.rules.hp<=0 or app.rules.gripped or app.rules.body_busy() or app.rules.search_active:return true
 if not app.dialogue_queue.is_empty() or not ending_state().is_empty():return true
 if app.family.collapse_active() or app.action_left>0 or app.closing_left>0:return true
 # A phase name alone does not justify waiting forever: returning/opening
 # can themselves be blocked. Only a real running timer/busy state exempts it.
 return false

func sample() -> void:
 var level:int=int(app.session.data.level)
 if level!=last_level:
  if last_level>0:level_segments.append({"level":last_level,"entered":level_started,"left":elapsed,"duration":elapsed-level_started})
  last_level=level;level_started=elapsed
  if level not in visited_levels:visited_levels.append(level)
 if app.room_id!=last_room:
  room_transitions.append({"elapsed":elapsed,"level":level,"from":last_room,"to":app.room_id,"at":[app.hero_pos.x,app.hero_pos.y]})
  last_room=app.room_id
  print("FULL_CAMPAIGN_ROOM %.2f L%d %s"%[elapsed,level,app.room_id])
 var attempt_key:String="%d:%d:%d"%[level,app.rules.actual_attempt,app.session.data.cycle]
 if not seen_attempts.has(attempt_key):
  seen_attempts[attempt_key]=true;attempts.append(current_state())
 for fact:Dictionary in app.rules.facts:
  if str(fact.get("kind",""))!="search_completed":continue
  var receipt:String=str(fact.get("event_id",""))
  if seen_receipts.has(receipt):continue
  seen_receipts[receipt]=true
  searches.append({"elapsed":elapsed,"level":level,"room":app.room_id,"attempt":app.rules.actual_attempt,"fact":fact.duplicate(true)})
 var ending:Dictionary=ending_state()
 if not ending.is_empty():
  var marker:String=str(ending.get("id",""))+":"+str(ending.get("phase",""))
  if marker not in endings:endings.append(marker);print("FULL_CAMPAIGN_ENDING ",marker)
 var state:Dictionary=current_state()
 var signature:String=JSON.stringify([level,app.room_id,app.rules.actual_attempt,app.action_phase,app.hero_state,app.rules.search_count,app.session.data.key_owner,app.rules.hp,ending.get("phase","")])
 if signature!=last_state:timeline.append(state);last_state=signature
 if app.room_id==previous_room and app.hero_pos.distance_to(previous_pos)<.0001 and not legitimate_wait():stall+=fixed_delta
 else:stall=0.0
 maximum_stall=maxf(maximum_stall,stall)
 previous_pos=app.hero_pos;previous_room=app.room_id
 if elapsed>=next_log:
  next_log+=30.0
  print("FULL_CAMPAIGN %.1fs L%d %s hp%d sp%d attempt%d phase%s search%d pos%s"%[elapsed,level,app.room_id,app.rules.hp,app.rules.sp,app.rules.actual_attempt,app.action_phase,app.rules.search_count,app.hero_pos])
  write_json("latest_status.json",state)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/full_campaign_spatial_20261019/natural"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
  if arg.begins_with("--natural-limit="):deadline=minf(2400.0,float(arg.trim_prefix("--natural-limit=")))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 check(frontend.store.root.contains("tmp/"),"entire route uses isolated saves")
 await click(button(frontend,"建立档案"));await frames()
 if frontend.name_field==null:check(false,"real profile entry is available");await finish_check();return
 frontend.name_field.text="完整空间自然流程"
 await click(button(frontend,"建立并开始"));await frames()
 if frontend.active==null:await click(button(frontend,"建立并开始"));await frames()
 app=frontend.active
 if app==null:check(false,"actual new-profile button creates campaign");await finish_check();return
 write_json("initial_snapshot.json",app.snapshot_data())
 check(int(app.session.data.level)==1,"real new profile starts at L1")
 check(frontend.preferences.auto_dialogue,"default automatic dialogue preference is enabled")
 check(app.opening_ui!=null,"fresh profile displays the real opening")
 if app.opening_ui!=null:
  check(app.opening_ui.auto_play,"new-profile opening defaults to automatic playback")
  if not app.opening_ui.auto_play:
   opening_manual_auto=true
   write_json("opening_default_manual_snapshot.json",app.snapshot_data())
   await click(app.opening_ui.auto_button)
 # These counters observe ordinary _process. No advance_world/manual tick calls.
 first_frame=Engine.get_process_frames();last_frame=first_frame
 while elapsed<deadline:
  await get_tree().process_frame
  var current_frame:int=Engine.get_process_frames()
  var frame_delta:int=maxi(1,current_frame-last_frame);last_frame=current_frame
  fixed_delta=get_process_delta_time();elapsed+=fixed_delta*frame_delta
  if app.tutorial_ui!=null:
   await click(button(app.tutorial_ui,"跳过练习"))
   check(app.tutorial_ui==null and app.profile.tutorial_completed,"actual tutorial Skip enters autonomous campaign")
   last_frame=Engine.get_process_frames()
  sample()
  var room_key:String=str(app.session.data.level)+":"+app.room_id
  if not seen_rooms.has(room_key):
   seen_rooms[room_key]=true
   await capture("visit_%02d_L%d_%s"%[seen_rooms.size(),app.session.data.level,app.room_id])
  if completed_ending():reason="complete_ending";break
  if stall>15.0:reason="unexplained_stall";break
 if reason.is_empty():reason="time_limit"
 await finish_check()

func finish_check() -> void:
 if app!=null:
  if last_level>0:level_segments.append({"level":last_level,"entered":level_started,"left":elapsed,"duration":elapsed-level_started})
  check(completed_ending(),"ordinary new-profile process reaches an unskipped complete ending and result panel")
  check(stall<=15.0,"no fifteen-second unexplained autonomous stall")
  check(not searches.is_empty(),"actual autonomous searches settled through production receipts")
  var missing:Array=[]
  for level in range(1,7):
   if level not in visited_levels:missing.append(level)
  if str(ending_state().get("id",""))!="E1":check(missing.is_empty(),"main route visits every L1-L6 boundary without injected unlocks")
  write_json("final_snapshot.json",app.snapshot_data())
  if not failures.is_empty():write_json("failure_snapshot.json",app.snapshot_data())
  await capture("final")
  write_json("result.json",{"passes":passes,"failures":failures,"reason":reason,"elapsed_simulation_seconds":elapsed,"maximum_unexplained_still_seconds":maximum_stall,"level_segments":level_segments,"visited_levels":visited_levels,"coverage_missing_levels":missing,"room_transitions":room_transitions,"attempts":attempts,"search_completions":searches,"ending_phases":endings,"ending":ending_state().duplicate(true),"timeline":timeline,"rendered":DisplayServer.get_name()!="headless","opening_manual_auto_button_needed":opening_manual_auto,"scope":"Actual new-profile UI, automatic intro/dialogue (visible Auto click only if the recorded default is off), real tutorial Skip; ordinary _process thereafter. No seed/NPC/resource/key/route/position/level/death/completion writes. Fixed30 simulation may accelerate wall time; not human-paced acceptance, all branches or audio listening. Hidden E1 remains a genuine alternative and is reported with missing main-route coverage rather than forced into L2."})
  print("FULL_CAMPAIGN_SPATIAL_NATURAL_CHECK %d passed %d failed reason=%s"%[passes.size(),failures.size(),reason])
  app.audio.reset_scene()
 else:
  write_json("result.json",{"passes":passes,"failures":failures,"reason":"driver_profile_entry_failed","rendered":DisplayServer.get_name()!="headless","scope":"New-profile UI entry failed before campaign initialization; no gameplay exercised or overridden."})
 frontend.request_exit(0 if failures.is_empty() else 1)
