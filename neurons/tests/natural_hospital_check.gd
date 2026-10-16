extends "res://tests/natural_home_check.gd"
## Ordinary title/profile/world input, continued beyond L1 into the hospital.
## Only observations and output metadata differ from the natural-home driver.
## A sampled alternate route or actual attempt end is retained, never forced
## into a hospital success. No gameplay field or random state is written.
var hospital_seen:bool=false
var hospital_entry_frame:int=-1
var progress_report_frame:int=-1

func _ready() -> void:
 folder="res://../docs/validation/takeover_20261016/natural-hospital"
 await super._ready()

func npc_state() -> Dictionary:
 var result:Dictionary=super.npc_state()
 if app.hospital!=null and not app.hospital.data.is_empty():
  for id in app.hospital.data.get("actors",{}):
   var actor:Dictionary=app.hospital.actor(str(id)).duplicate(true)
   actor.present=app.hospital.present(str(id))
   result["hospital_"+str(id)]=actor
 return result

func record_state(label:String) -> void:
 super.record_state(label)
 if observations.is_empty() or app.hospital==null:return
 var entry:Dictionary=observations[-1]
 entry.hospital_body=app.hospital.data.get("body",{}).duplicate(true)
 entry.hospital_holder=app.hospital.data.get("holder","")
 entry.hospital_transport=app.hospital.data.get("transport",{}).duplicate(true)
 entry.hospital_groups=app.hospital.data.get("groups",{}).duplicate(true)
 entry.hospital_receipt_count=app.hospital.data.get("receipts",{}).size()

func stage_signature() -> String:
 var data:Dictionary=app.hospital.data if app.hospital!=null else {}
 var body:Dictionary=data.get("body",{})
 var transport:Dictionary=data.get("transport",{})
 var records:Dictionary=data.get("records_state",{})
 return JSON.stringify([super.stage_signature(),body.get("kind",""),body.get("actor",""),
  data.get("holder",""),transport.get("kind",""),transport.get("phase",""),
  records.get("archivist",{}).get("phase",""),records.get("guard",{}).get("phase",""),
  data.get("receipts",{}).size(),bool(app.session.data.exploration_boundary)])

func progress_signature() -> String:
 var data:Dictionary=app.hospital.data if app.hospital!=null else {}
 var body:Dictionary=data.get("body",{})
 var transport:Dictionary=data.get("transport",{})
 var records:Dictionary=data.get("records_state",{})
 var reading:Dictionary=data.get("observation_state",{}).get("active",{})
 if elapsed_frames()%300==0 and progress_report_frame!=elapsed_frames():
  progress_report_frame=elapsed_frames()
  write_json("progress.json",{"frame":elapsed_frames(),"room":app.room_id,"hero":[app.hero_pos.x,app.hero_pos.y],"phase":app.action_phase,"hospital_reading":reading,"body":body,"transport":transport,"guard":records.get("guard",{}),"world_time":app.rules.world_time})
  print("NATURAL_PROGRESS ",elapsed_frames()," ",app.room_id," ",app.action_phase," ",app.rules.world_time)
 # Timers are capped so a broken never-ending timer cannot mask a stall.
 # Hospital clocks and audio/decorative time are deliberately excluded.
 var timers:Array=[]
 for value in [body.get("elapsed",0),transport.get("elapsed",0),data.get("bandage",0),
  data.get("medicine_stop",0),records.get("archivist",{}).get("elapsed",0),
  records.get("guard",{}).get("elapsed",0),records.get("report",{}).get("elapsed",0)]:
  timers.append(snappedf(clampf(float(value),0,30),0.05))
 return JSON.stringify([super.progress_signature(),timers,reading.get("id",""),reading.get("phase",""),snappedf(float(reading.get("elapsed",0)),0.05),data.get("bag",""),
  data.get("records_state",{}).get("report",{}).get("phase","")])

func endpoint() -> String:
 if int(app.session.data.level)==2 and not hospital_seen:
  hospital_seen=true;hospital_entry_frame=elapsed_frames()
  record_state("hospital_first_entry")
  write_json("hospital_entry_snapshot.json",app.snapshot_data())
  call_deferred("capture","02_hospital_entered")
 if app.rules.hp<=0:return "actual_death"
 if int(app.session.data.cycle)>first_cycle or int(app.session.data.attempts.get("1",1))>1 or int(app.session.data.attempts.get("2",1))>1:
  return "actual_attempt_restarted"
 if app.room_id=="hidden_street" or bool(app.family.data.get("hidden_pending",false)):
  return "natural_hidden_route_selected"
 if int(app.session.data.level)==2 and bool(app.session.data.exploration_boundary):
  return "hospital_stairs_development_boundary"
 return ""

func finish(kind:String,reason:String) -> void:
 if finished:return
 finished=true
 if is_instance_valid(app):
  observe_facts();record_state("terminal_observation")
  last_snapshot=app.snapshot_data()
  write_json("final_snapshot.json",last_snapshot)
  await capture("03_terminal_"+kind)
 var descriptions:Dictionary={
  "hospital_stairs_development_boundary":"Actual L2 exit opening completed; L3 remains a development boundary, not an ending.",
  "actual_death":"Actual HP reached zero during the natural route; no revival, resources or route were forced by the driver.",
  "actual_attempt_restarted":"Normal game logic completed the first actual rest/revival and started a new attempt.",
  "natural_hidden_route_selected":"Natural L1 events selected the existing hidden route instead of the hospital; this observation is not hospital completion or E1 completion."}
 var result:Dictionary={"passes":passes,"failures":failures,"no_gameplay_fixture":true,
  "scope":"automated viewport mouse title/profile/tutorial-skip/dialogue input; natural RNG and ordinary _process from L1 into L2 when naturally selected; no seed, actors, resources, positions, routes, probabilities or event fixtures; not human play, all hospital branches, audio acceptance or game completion",
  "engine_time_scale":Engine.time_scale,"accelerated_engine_time":Engine.time_scale>1.0,
  "elapsed_process_frames":elapsed_frames(),"frame_limit":FRAME_LIMIT,"stall_frame_limit":STALLED_FRAME_LIMIT,
  "endpoint":{"kind":kind,"reason":descriptions.get(kind,reason),"is_game_completion":false},
  "hospital_entered":hospital_seen,"hospital_entry_frame":hospital_entry_frame,
  "hospital_exit_reached":kind=="hospital_stairs_development_boundary",
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
 print("NATURAL_HOSPITAL_CHECK %d passed %d failed / %s"%[passes.size(),failures.size(),kind])
 frontend.request_exit(0 if failures.is_empty() else 1)
