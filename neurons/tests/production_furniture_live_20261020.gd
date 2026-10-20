extends "res://tests/opening_campaign_check.gd"
## Actual bedroom renderer with opt-in furniture layers; declared visual states,
## not a claimed natural whole-game playthrough or formal animation acceptance.
const Painted=preload("res://scripts/world/production_props.gd")
const Materials=preload("res://scripts/world/spatial_materials.gd")
var entries:Array=[]

func render_state(id:String,art:bool,materials:bool) -> void:
 Painted.force_preview=art;Materials.force_preview=materials
 app.view.queue_redraw();await frames(3)
 await capture(id)
 if DisplayServer.get_name()!="headless":
  var world_path:String=ProjectSettings.globalize_path(folder).path_join(id+"_world.png")
  app.world_viewport.get_texture().get_image().save_png(world_path)
 entries.append({"id":id,"painted_furniture_override":art,"material_override":materials})

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/asset_production_20261020/furniture/live"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 frontend.launch({"name":"家具组合检查","invader_id":0,"tutorial_completed":true,"opening_completed":true},{})
 await frames(3);app=frontend.active
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0;app.paused_manual=true
 var frozen:Dictionary={"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"world_time":app.rules.world_time,"rng":str(app.rng.state),"targets":app.session.data.targets.duplicate(true),"owners":app.rules.owners.duplicate(true)}
 await render_state("01_original_slots",false,false)
 await render_state("02_painted_furniture_existing_surfaces",true,false)
 await render_state("03_painted_furniture_materials_candidate",true,true)
 var drawer_before:Dictionary=app.drawer_open.duplicate(true)
 var states_before:Dictionary=app.search_actions.states.duplicate(true)
 app.drawer_open["bedside"]=.85
 app.search_actions.states["bedroom:bed"]={"bedding_lifted":true}
 await render_state("04_separate_drawer_and_blanket",true,true)
 app.drawer_open=drawer_before;app.search_actions.states=states_before
 for key:String in frozen:
  var now=app.rules.get(key) if key in ["hp","sp","neurons","world_time"] else str(app.rng.state) if key=="rng" else app.session.data.targets if key=="targets" else app.rules.owners
  check(now==frozen[key],"visual overrides preserve "+key)
 var covered:int=0
 for item:Dictionary in app.layout.furniture:
  if Painted.available(app.layout,item):covered+=1
 check(covered==8,"eight original bedroom IDs use calibrated painted layers")
 check(not bool(Painted.document().get("enabled",false)),"global furniture switch remains off pending combination review")
 check(not bool(Materials.document().get("enabled",false)),"global material switch remains off pending painting review")
 Painted.force_preview=false;Materials.force_preview=false
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","entries":entries,"scope":"Actual bedroom renderer, existing draw slots and declared drawer/blanket visual states. No natural gameplay/rig/action or all-assets formal-art acceptance claimed."},"  "));file.close()
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
