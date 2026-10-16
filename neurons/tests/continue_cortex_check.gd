extends "res://tests/natural_asylum_check.gd"
## Continue a genuine earlier normal-play save; do not edit any gameplay field.
const SOURCE="res://../docs/validation/b3_finish_20261016/continued-r2/final_snapshot.json"
var source_hash:String=""
var cortex_seen:bool=false
var cortex_entry_frame:int=-1

func capture(image_name:String) -> void:
 await frames(2);app.view.queue_redraw();RenderingServer.force_draw(false)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(image_name+".png"))
 screenshots.append({"name":image_name+".png","frame":elapsed_frames()})

func endpoint() -> String:
 if app.rules.hp<=0:return "actual_death"
 if int(app.session.data.cycle)>first_cycle:return "actual_attempt_restarted"
 if int(app.session.data.level)==4 and not cortex_seen:
  cortex_seen=true;cortex_entry_frame=elapsed_frames();record_state("cortex_first_entry")
  write_json("cortex_entry_snapshot.json",app.snapshot_data());call_deferred("capture","02_actual_cortex_entry")
 if int(app.session.data.level)==4 and bool(app.session.data.exploration_boundary):return "cortex_keyed_exit_development_boundary"
 return ""

func npc_state() -> Dictionary:
 var result:Dictionary=super.npc_state()
 if app.cortex!=null:
  for id in app.cortex.data.get("actors",{}):result["cortex_"+str(id)]=app.cortex.actor(str(id)).duplicate(true)
 return result

func stage_signature() -> String:
 return JSON.stringify([super.stage_signature(),app.cortex.data.get("body",{}).get("kind",""),app.cortex.data.get("observation",{}).get("id","")])

func progress_signature() -> String:
 var observation:Dictionary=app.cortex.data.get("observation",{})
 return JSON.stringify([super.progress_signature(),observation.get("id",""),snappedf(clampf(float(observation.get("elapsed",0)),0,15),0.05),app.cortex.data.get("receipts",{}).size()])

func write_json(filename:String,data) -> bool:
 if filename!="result.json":return super.write_json(filename,data)
 data.scope="real Continue and dialogue mouse input from the genuine earlier observed B3 keyed endpoint save; original saved RNG/actors/resources/positions retained, ordinary _process afterwards; fixed-clock automated observation, not a fresh L1 run, human all-branch or formal-art/audio acceptance"
 data.started_from_observed_save=true;data.source_snapshot=SOURCE;data.source_snapshot_text_sha256=source_hash
 data.cortex_entered=cortex_seen;data.cortex_entry_frame=cortex_entry_frame
 data.cortex_exit_reached=data.get("endpoint",{}).get("kind","")=="cortex_keyed_exit_development_boundary"
 data.original_relic_delivery=app.hospital.data.get("relic_delivery",{}).duplicate(true)
 data.asylum_relic_intake=app.asylum.data.get("intake_state",{}).duplicate(true)
 data.relic_source_scope="Observed original transport/packing and intake are retained verbatim; reaching the exit alone does not prove their completion."
 if data.cortex_exit_reached:data.endpoint.reason="Actual L4 unique key and second-floor door opening; L5 is a development boundary, not an ending."
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join(filename),FileAccess.WRITE)
 if output==null:return false
 output.store_string(JSON.stringify(data,"  "));output.close();return true

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();start_frame=Engine.get_process_frames()
 folder="res://../docs/validation/b4_20261016/continued"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 if frontend.store.root=="user://profiles":frontend.request_exit(1);return
 var source:String=FileAccess.get_file_as_string(SOURCE);source_hash=source.sha256_text()
 var snapshot=JSON.parse_string(source)
 if not snapshot is Dictionary or not frontend.store.save_snapshot(snapshot).ok:
  failures.append("Genuine prior observed save missing or cannot be written to isolated test root");await finish("startup_failed","Source not substituted");return
 frontend.create_title();await frames(5)
 if not await click(button(frontend,"继续")) or frontend.active==null:
  failures.append("Actual Continue button did not restore genuine earlier snapshot");await finish("startup_failed","No field correction");return
 app=frontend.active;initial_snapshot=app.snapshot_data()
 first_cycle=int(app.session.data.cycle);first_attempt=int(app.rules.actual_attempt);first_level=int(app.session.data.level)
 if first_level!=3:
  failures.append("Genuine source did not restore at L3");await finish("unexpected_initial_state","No level correction");return
 passes.append("Actual Continue restores genuine earlier L3 endpoint save with original actor/RNG/resource state")
 write_json("initial_world_snapshot.json",initial_snapshot);record_state("continued_world");observe_facts();await capture("01_actual_continue_from_B3_endpoint")
 last_progress=progress_signature();last_progress_frame=elapsed_frames();last_stage=stage_signature()
 while elapsed_frames()<FRAME_LIMIT:
  observe_facts()
  var reached:String=endpoint()
  if not reached.is_empty():
   passes.append("Ordinary continued process reaches an actual observed endpoint without gameplay field edits")
   await finish(reached,"Genuine save continuation");return
  var stage:String=stage_signature()
  if stage!=last_stage:record_state("stage_change");last_stage=stage
  var progress:String=progress_signature()
  if progress!=last_progress:last_progress=progress;last_progress_frame=elapsed_frames()
  elif elapsed_frames()-last_progress_frame>=STALLED_FRAME_LIMIT:
   failures.append("No meaningful progress within finite watchdog");await finish("stalled","Retained actual state");return
  if not app.dialogue_queue.is_empty() and app.dialogue_panel.visible:
   var before:String=JSON.stringify(app.dialogue_queue)
   var next:Button=button(app.dialogue_panel,"继续")
   if next!=null and await click(next) and JSON.stringify(app.dialogue_queue)!=before:dialogue_advances+=1
  await frames(1)
 failures.append("Finite frame limit reached");await finish("frame_limit","No forced progress")

