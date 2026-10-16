extends "res://tests/natural_hospital_check.gd"
## No gameplay fixtures. Keep ordinary profile/input/Process from L1 to L3.
var asylum_seen:bool=false
var asylum_entry_frame:int=-1

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/natural"
 await super._ready()

func npc_state() -> Dictionary:
 var value:Dictionary=super.npc_state()
 if app.asylum!=null and not app.asylum.data.is_empty():
  for id in app.asylum.data.actors:
   var actor:Dictionary=app.asylum.actor(str(id)).duplicate(true);actor.present=app.asylum.present(str(id))
   value["asylum_"+str(id)]=actor
 return value

func stage_signature() -> String:
 return JSON.stringify([super.stage_signature(),app.session.data.level,app.asylum.data.get("body",{}).get("kind",""),app.asylum.data.get("holder",""),app.asylum.data.get("receipts",{}).size()])

func progress_signature() -> String:
 return JSON.stringify([super.progress_signature(),app.asylum.data.get("body",{}),app.asylum.data.get("exam",{}),app.asylum.data.get("records_state",{}).get("reading",{})])

func endpoint() -> String:
 var before:String=super.endpoint()
 if before in ["actual_death","actual_attempt_restarted","natural_hidden_route_selected"]:return before
 if int(app.session.data.level)==3 and not asylum_seen:
  asylum_seen=true;asylum_entry_frame=elapsed_frames();record_state("asylum_first_entry")
  write_json("asylum_entry_snapshot.json",app.snapshot_data());call_deferred("capture","04_asylum_entered")
 if int(app.session.data.level)==3 and bool(app.session.data.exploration_boundary):return "asylum_keyed_exit_development_boundary"
 return ""

func write_json(filename:String,data) -> bool:
 if filename=="result.json" and data is Dictionary:
  data.asylum_entered=asylum_seen;data.asylum_entry_frame=asylum_entry_frame
  data.asylum_exit_reached=data.get("endpoint",{}).get("kind","")=="asylum_keyed_exit_development_boundary"
  data.scope="normal title/profile/tutorial-skip/dialogue mouse input, natural RNG and ordinary _process through L1/L2/L3; no seed/actor/resource/position/route fixture; fixed game clock is automated observation, not human all-branch/art/audio acceptance"
  if data.asylum_exit_reached:data.endpoint.reason="Actual L3 unique key picked up and existing stair exit opened; L4 remains a development boundary, not an ending."
 return super.write_json(filename,data)
