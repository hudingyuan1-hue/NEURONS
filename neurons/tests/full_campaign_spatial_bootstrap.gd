extends SceneTree
## Standalone runner, so the new audit does not require shared frontend edits.
func _initialize() -> void:
 call_deferred("launch")

func launch() -> void:
 var front=load("res://scenes/front_end.tscn").instantiate()
 root.add_child(front)
 current_scene=front
 await process_frame
 # A registered frontend flag may already have installed its one driver.
 # Do not launch a second campaign audit against the same profile UI.
 if front.get_node_or_null("CampaignCheck")!=null:return
 var script_path:String="res://tests/full_campaign_spatial_natural_check.gd"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--audit-script="):script_path=argument.trim_prefix("--audit-script=")
 var audit=load(script_path).new()
 front.add_child(audit)
