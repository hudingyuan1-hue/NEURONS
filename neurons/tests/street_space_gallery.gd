extends SceneTree
## Explicit paused room fixtures for the actual GPU viewer. No save mutation,
## no gameplay acceptance claim; navigation has separate swept-movement checks.
var frontend
var app
var folder:String="res://../docs/validation/space_street_20261018/gallery"
var shots:Array=[]

func _initialize() -> void:call_deferred("run")
func frames(n:int=3) -> void:
 for i in range(n):await process_frame
func capture(id:String) -> void:
 await frames(3);app.view.queue_redraw();RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(id+".png"))
 shots.append(id)

func run() -> void:
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 frontend=load("res://scenes/front_end.tscn").instantiate();root.add_child(frontend)
 await frames();await frontend.show_profile();frontend.name_field.text="Street空间画面固定房间核查";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 app.unlock_combat();app.unlock_street();app.paused_manual=true
 for id:String in app.StreetMap.ROOMS:
  app.enter_room(id);app.paused_manual=true;app.camera.zoom=Vector2.ONE;app.camera.force_update_scroll()
  await capture(id+"_default")
  # Overview is a declared camera fixture; actors/collisions remain unchanged.
  app.camera.position=app.layout.project(app.layout.world_size()*.5)+Vector2(0,-70)
  app.camera.zoom=Vector2.ONE*.5;app.camera.force_update_scroll()
  await capture(id+"_overview")
 app.session.data.level=1;app.hidden_route.start();app.enter_room("hidden_street");app.paused_manual=true;app.camera.zoom=Vector2.ONE;app.camera.force_update_scroll()
 await capture("hidden_street_default")
 var result:Dictionary={"shots":shots,"rendered":DisplayServer.get_name()!="headless","scope":"Paused explicit room/camera fixtures to inspect actual current spatial viewer. Not a natural route, human balance, attack or audio acceptance. No NPC/resource/rule edits after normal chapter setup except declared hidden entry/level selection."}
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 app.audio.reset_scene();print(JSON.stringify(result));quit()
