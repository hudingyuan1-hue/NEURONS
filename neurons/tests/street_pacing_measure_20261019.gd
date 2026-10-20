extends "res://tests/opening_campaign_check.gd"
## Observes ordinary _process only. The one declared fixture is direct L5
## entry, or an explicitly named Street entry. NPCs, RNG, resources, routes,
## damage, speeds and completion are never edited after that initial entry.
var elapsed:float=0.0
var deadline:float=480.0
var observing:bool=false
var street_entered:bool=false
var street_start:float=-1.0
var street_wall_started:int=0
var run_started:int=0
var previous_level:int=0
var previous_room:String=""
var previous_pos:=Vector2.ZERO
var segments:Array=[]
var events:Array=[]
var samples:Array=[]
var phase_events:Array=[]
var seen_facts:Dictionary={}
var actor_phases:Dictionary={}
var entry_snapshot:Dictionary={}
var pending_captures:Array=[]
var next_sample:float=0.0
var last_sample:float=0.0
var next_status:float=0.0
var stall:float=0.0
var max_stall:float=0.0
var reason:String=""
var entry_fixture:String="L5_atrium"
var replay_snapshot:String=""
var stop_after_entry_room:bool=false
var facts_file:FileAccess
var recorded_inputs:Array=[]

func write_json(filename:String,value:Variant) -> void:
 var file=FileAccess.open(folder.path_join(filename),FileAccess.WRITE)
 file.store_string(JSON.stringify(value,"  "));file.close()

func state() -> Dictionary:
 return {"elapsed_s":elapsed,"street_s":elapsed-street_start if street_entered else -1.0,"level":app.session.data.level,"room":app.room_id,"world_s":app.rules.world_time,"street_clock_s":app.street.data.get("clock",0),"pos_m":[app.hero_pos.x,app.hero_pos.y],"pose":app.hero_state,"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"clusters":app.rules.plexus,"control_ms":app.rules.control_ms,"paused":app.world_paused(),"gripped":app.rules.gripped,"route_points":app.hero_route.size(),"door_left_s":app.street.data.get("door_left",-1),"destination":app.street.data.get("destination",""),"ending":app.street.data.get("ending",{}).duplicate(true)}

func open_segment() -> void:
 if not segments.is_empty():
  var previous:Dictionary=segments[-1]
  previous.left_s=elapsed-street_start;previous.elapsed_s=float(previous.left_s)-float(previous.entered_s)
  previous.exit_hp=app.rules.hp;previous.exit_neurons=app.rules.neurons
  if stop_after_entry_room:reason="declared_branch_entry_exited"
 var segment:Dictionary={"room":app.room_id,"entered_s":elapsed-street_start,"left_s":-1.0,"elapsed_s":0.0,"distance_m":0.0,"walking_m":0.0,"forced_or_pose_displacement_m":0.0,"active_s":0.0,"paused_s":0.0,"moving_s":0.0,"body_busy_s":0.0,"gripped_s":0.0,"door_intent_s":0.0,"route_blocked_s":0.0,"entry_hp":app.rules.hp,"entry_neurons":app.rules.neurons,"entry_clusters":app.rules.plexus,"available_skill_s":{},"availability_reasons_s":{},"visible_actors":{},"hostile_visible_s":0.0,"hostile_windup_or_active_s":0.0,"actual_hero_hits":[],"actual_actor_hits":[],"damage_to_hero_hp":0,"damage_to_hero_sp":0,"facts":[]}
 segments.append(segment)
 events.append(state());pending_captures.append("visit_%02d_%s"%[segments.size(),app.room_id])
 print("PACING_ROOM ",app.room_id," street_s=",elapsed-street_start," hp=",app.rules.hp)

func observe_facts() -> void:
 for fact:Dictionary in app.rules.facts:
  var signature:String=JSON.stringify(fact)
  if seen_facts.has(signature):continue
  seen_facts[signature]=true
  if not street_entered:continue
  var record:Dictionary={"street_s":elapsed-street_start,"observed_room":app.room_id,"fact":fact.duplicate(true)}
  events.append(record)
  if facts_file!=null:facts_file.store_line(JSON.stringify(record))
  if segments.is_empty():continue
  var segment:Dictionary=segments[-1]
  segment.facts.append(record)
  if str(fact.get("kind",""))=="combat_hit":
   segment.actual_hero_hits.append(record)
   segment.damage_to_hero_hp+=int(fact.get("hp_damage",0));segment.damage_to_hero_sp+=int(fact.get("sp_damage",0))
  elif str(fact.get("kind",""))=="combat_actor_hit":segment.actual_actor_hits.append(record)

func sample_visible(period:float) -> void:
 if segments.is_empty():return
 var segment:Dictionary=segments[-1];var visible:Array=[];var hostile:bool=false;var threat:bool=false
 period=minf(period,maxf(0,elapsed-street_start-float(segment.entered_s)))
 var radius:float=float(app.street.config.test_parameters.hero_vision_m)
 for id in app.street.data.actors:
  var a:Dictionary=app.street.data.actors[id]
  if not a.present or a.hp<=0 or a.room!=app.room_id:continue
  var distance:float=app.street.position(str(id)).distance_to(app.hero_pos)
  var phase_key:String=app.room_id+":"+str(id)
  var phase:String=str(a.phase)
  if actor_phases.get(phase_key,"")!=phase:
   actor_phases[phase_key]=phase;phase_events.append({"street_s":elapsed-street_start,"room":app.room_id,"actor":id,"phase":phase,"distance_m":distance,"attack_target":a.get("attack_target",""),"attack_id":a.get("attack_id","")})
  if distance>radius or not app.street.can_see(app.room_id,app.hero_pos,app.street.position(str(id))):continue
  visible.append(id)
  if not segment.visible_actors.has(id):segment.visible_actors[id]={"first_s":elapsed-street_start,"last_s":elapsed-street_start,"visible_s":0.0,"minimum_distance_m":distance,"relation":app.street.spec(str(id)).relation,"attack":app.street.spec(str(id)).attack}
  var entry:Dictionary=segment.visible_actors[id]
  entry.last_s=elapsed-street_start;entry.visible_s+=period;entry.minimum_distance_m=minf(float(entry.minimum_distance_m),distance)
  if a.hostile:hostile=true
  if a.hostile and phase in ["windup","attack","grip"]:threat=true
 if hostile:segment.hostile_visible_s+=period
 if threat:segment.hostile_windup_or_active_s+=period
 var sample:Dictionary=state();sample.visible_actors=visible;sample.available_skills=[]
 var context:Dictionary=app.skill_context();context.direction=[-1.0,0.0]
 for id in app.rules.skill_states:
  if not app.rules.skill_states[id].unlocked:continue
  var unavailable:String="presentation_paused" if app.world_paused() or not app.street.data.get("ending",{}).is_empty() else app.rules.availability(str(id),context)
  var key:String=str(id)+":"+(unavailable if not unavailable.is_empty() else "available")
  segment.availability_reasons_s[key]=float(segment.availability_reasons_s.get(key,0))+period
  if unavailable.is_empty():
   segment.available_skill_s[id]=float(segment.available_skill_s.get(id,0))+period;sample.available_skills.append(id)
 samples.append(sample)

func _process(delta:float) -> void:
 if not observing or app==null:return
 elapsed+=delta
 var level:int=int(app.session.data.level)
 if level==6 and not street_entered:
  street_entered=true;street_start=elapsed;street_wall_started=Time.get_ticks_msec()
  entry_snapshot=app.snapshot_data();write_json("street_entry_snapshot.json",entry_snapshot)
  for fact:Dictionary in app.rules.facts:seen_facts[JSON.stringify(fact)]=true
 if street_entered and level==6:
  if previous_level!=6 or previous_room!=app.room_id:open_segment()
  var segment:Dictionary=segments[-1]
  var displacement:float=app.hero_pos.distance_to(previous_pos) if previous_level==6 and previous_room==app.room_id else 0.0
  segment.distance_m+=displacement
  if app.hero_state=="walk":segment.walking_m+=displacement
  else:segment.forced_or_pose_displacement_m+=displacement
  var paused:bool=app.world_paused() or not app.street.data.get("ending",{}).is_empty()
  if paused:segment.paused_s+=delta
  else:
   segment.active_s+=delta
   if displacement>.00001:segment.moving_s+=delta
   if app.rules.body_busy():segment.body_busy_s+=delta
   if app.rules.gripped:segment.gripped_s+=delta
   if float(app.street.data.get("door_left",-1))>=0:segment.door_intent_s+=delta
   if not app.hero_route.is_empty() and displacement<.00001 and not app.rules.body_busy() and not app.rules.gripped:segment.route_blocked_s+=delta
  if not paused and displacement<.00001 and not app.rules.body_busy() and not app.rules.gripped and app.hero_state!="give":stall+=delta
  else:stall=0.0
  max_stall=maxf(max_stall,stall)
  observe_facts()
  if elapsed>=next_sample:
   next_sample=elapsed+.25
   sample_visible(elapsed-last_sample if last_sample>0 else 0.0);last_sample=elapsed
 elif street_entered and level!=6 and app.rules.hp<=0:reason="street_death_return"
 previous_level=level;previous_room=app.room_id;previous_pos=app.hero_pos
 if elapsed>=next_status:
  next_status=elapsed+10.0;write_json("latest_status.json",state())

func geometry_summary() -> Array:
 var result:Array=[]
 for room:String in app.street.map.rooms():
  var floor=app.street.floor_for(room);var pairs:Array=[];var mouths:Array=[]
  for to:String in app.street.map.doors(room):mouths.append(floor.portal(to))
  for i in range(mouths.size()):
   for j in range(i+1,mouths.size()):
    var route:PackedVector2Array=floor.path(mouths[i].landing,mouths[j].threshold);var distance:float=0.0
    for index in range(1,route.size()):distance+=route[index-1].distance_to(route[index])
    pairs.append({"from":mouths[i].toward,"toward":mouths[j].toward,"static_route_m":distance,"route_points":route.size()})
  var visits:Array=[]
  for segment:Dictionary in segments:
   if str(segment.room)==room:visits.append(segment)
  var actors:Array=[]
  for spec:Dictionary in app.street.config.actors:
   if str(spec.room)==room:actors.append({"id":spec.id,"relation":spec.relation,"attack":spec.attack})
  result.append({"room":room,"size_m":[floor.world_size().x,floor.world_size().y],"portals":mouths,"static_portal_routes":pairs,"configured_actors":actors,"visits":visits,"actually_visited":not visits.is_empty(),"branch":room in ["street_side","street_maintenance"]})
 return result

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/campaign_pacing_20261019/street/natural_l5"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
  if arg.begins_with("--natural-limit="):deadline=minf(600.0,float(arg.trim_prefix("--natural-limit=")))
  if arg.begins_with("--pacing-entry="):entry_fixture=arg.trim_prefix("--pacing-entry=")
  if arg.begins_with("--pacing-replay-snapshot="):replay_snapshot=arg.trim_prefix("--pacing-replay-snapshot=")
  if arg=="--pacing-stop-after-entry-room":stop_after_entry_room=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street节奏测量";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app==null:check(false,"actual new-profile handler creates campaign");await finish_measure();return
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 if not replay_snapshot.is_empty():
  var snapshot:Variant=JSON.parse_string(FileAccess.get_file_as_string(replay_snapshot))
  if not snapshot is Dictionary or not app.restore_snapshot(snapshot):
   check(false,"actual checkpoint restore succeeds without editing snapshot fields");await finish_measure();return
  entry_fixture="actual_checkpoint:"+replay_snapshot
 else:
  app.unlock_combat()
  if entry_fixture!="L5_atrium":
   app.unlock_street()
   if entry_fixture!="street_plaza":
    if entry_fixture=="street_maintenance":app.enter_room("street_twisted")
    app.enter_room(entry_fixture)
 facts_file=FileAccess.open(folder.path_join("facts.jsonl"),FileAccess.WRITE)
 write_json("initial_entry_fixture.json",app.snapshot_data())
 write_json("fixture_declaration.json",{"entry":entry_fixture,"entry_actions":["actual new-profile handler","finish already-known tutorial for isolated chapter measurement","clear initial L1 dialogue before chapter fixture","production restore_snapshot of untouched saved checkpoint" if not replay_snapshot.is_empty() else "production unlock_combat and optional named Street unlock/enter_room fixture"],"after_entry":"Only ordinary _process and read-only observations, plus any explicitly recorded real input in recorded_inputs.json; no direct RNG/NPC/resource/skill/route/position/HP/ending changes or manual game ticks.","frame_sample":"Distance accumulated every actual process frame. Visible actor and available skill durations sampled at 0.25s and therefore approximate to one sample; crossing teleports excluded from metres.","scope":"Automatic autonomous host baseline or explicitly recorded real-input comparison, not human-paced acceptance. NPC obstruction is passive benefit to the opposing player, measured separately from player input opportunities."})
 run_started=Time.get_ticks_msec();observing=true
 while elapsed<deadline:
  await get_tree().process_frame
  if not pending_captures.is_empty():await capture(str(pending_captures.pop_front()))
  if not reason.is_empty():break
  if street_entered and not app.street.data.get("ending",{}).is_empty():reason="actual_ending_registration";break
  if street_entered and (app.rules.hp<=0 or int(app.session.data.level)!=6):reason="street_death_or_return";break
  if max_stall>15.0:reason="unexplained_stall";break
 if reason.is_empty():reason="time_limit"
 observing=false
 await finish_measure()

func finish_measure() -> void:
 if app==null:
  write_json("result.json",{"failures":failures,"reason":"profile_failed"});frontend.request_exit(1);return
 if not segments.is_empty():
  var segment:Dictionary=segments[-1];segment.left_s=elapsed-street_start;segment.elapsed_s=float(segment.left_s)-float(segment.entered_s)
  segment.exit_hp=app.rules.hp;segment.exit_neurons=app.rules.neurons
 if facts_file!=null:facts_file.close()
 write_json("final_snapshot.json",app.snapshot_data())
 write_json("recorded_inputs.json",recorded_inputs)
 var submissions:Array=[];var resolutions:Array=[]
 for event:Dictionary in events:
  var fact:Dictionary=event.get("fact",{})
  if str(fact.get("kind",""))=="skill_submitted":submissions.append(event)
  elif str(fact.get("kind","")) in ["skill_reacted","skill_resisted","skill_interrupted"]:resolutions.append(event)
 write_json("samples.json",samples);write_json("actor_phases.json",phase_events)
 write_json("result.json",{"reason":reason,"entry_fixture":entry_fixture,"elapsed_simulation_s":elapsed,"pre_street_s":street_start,"street_s":elapsed-street_start if street_entered else -1,"wall_s":(Time.get_ticks_msec()-run_started)/1000.0,"street_wall_s":(Time.get_ticks_msec()-street_wall_started)/1000.0 if street_entered else -1,"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"clusters":app.rules.plexus,"ending":app.street.data.get("ending",{}).duplicate(true),"segments":segments,"all_seven_rooms":geometry_summary(),"events":events,"max_unexplained_still_s":max_stall,"rendered":DisplayServer.get_name()!="headless","rules_unchanged":true,"interventions_applied":resolutions.size(),"skill_submissions":submissions,"skill_resolutions":resolutions,"recorded_inputs":recorded_inputs,"sampling_interval_s":.25,"player_goal":"Prevent the autonomous host escaping. More NPC damage is not automatically greater player difficulty.","limitations":["Declared direct chapter entry does not carry the full L1-L4 earned skill profile.","Unvisited branches have static portal distances only, not invented natural traversal duration.","Available skill windows are sampled; actual recorded input and receipts are separate.","No human or subjective audio/art acceptance claimed."]})
 await capture("final")
 print("STREET_PACING_MEASURE ",reason," total=",elapsed," street=",elapsed-street_start)
 app.audio.reset_scene();frontend.request_exit(0)
