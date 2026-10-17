extends "res://tests/street_props_live_check.gd"
## Three declared cast/position fixtures, ordinary _process and real Space keys.
func place(id:String,at:Vector2) -> Dictionary:
 var a:Dictionary=app.street.data.actors[id]
 a.present=true;a.room=app.room_id;a.pos=app.street.xy(at);a.hp=40;a.hurt=0;a.phase="idle";a.follow="";a.route=[];a.goal=[]
 return a
func wait_scene(predicate:Callable,world_limit:float) -> bool:
 var elapsed:float=0.0;var wall:float=0.0
 while elapsed<world_limit and wall<20:
  if predicate.call():return true
  await get_tree().process_frame
  wall+=get_process_delta_time()
  if not app.world_paused():elapsed+=get_process_delta_time()
  if not app.dialogue_queue.is_empty():
   for down in [true,false]:
    var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=down;Input.parse_input_event(key);await frames(2)
 return predicate.call()
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_materials_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street专属动作连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 place("speaker",Vector2(13,4));app.hero_pos=Vector2(14,4);check(takeover(),"live strip scene uses an actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return float(app.street.materials.state().speaker.tear)>.25,1),"ordinary world process produces partial tearing")
 await space_key();var progress:float=app.street.materials.state().speaker.tear;await frames(12)
 check(app.paused_manual and is_equal_approx(progress,app.street.materials.state().speaker.tear),"real Space freezes the same partially damaged strip")
 await capture("01_partial_paper_paused");await space_key()
 check(await wait_until(func():return app.street.materials.state().speaker.holder=="hand",2),"real resume completes only the remaining tear")
 await capture("02_paper_held")

 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_maintenance");no_street()
 place("cleaner",Vector2(2.6,6.4));place("treatment_pharmacist",Vector2(6,4));app.hero_pos=Vector2(5.4,5.7)
 check(takeover(),"live cleaning scene pays for its own CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return app.street.materials.state().surfaces.street_maintenance_label.holder=="cleaner:hand",5),"ordinary movement reaches the floor label and completes actual pickup")
 await space_key();var holder:String=app.street.materials.state().surfaces.street_maintenance_label.holder;await frames(10)
 check(app.paused_manual and holder=="cleaner:hand" and app.street.materials.state().cleaner.bag.is_empty(),"paused hand-held label cannot teleport into the cart bag")
 await capture("03_label_in_hand_paused");await space_key()
 check(await wait_until(func():return app.street.materials.state().surfaces.street_maintenance_label.holder=="street_cleaner_bag",4),"real walk back deposits the one actual label at the cart")
 await capture("04_label_deposited")
 check(await wait_scene(func():return float(app.street.materials.state().surfaces.street_maintenance_scuff.progress)>=1,5),"same process subsequently wipes only the contacted ground scuff")
 if not failures.is_empty():
  var failed:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);failed.store_string(JSON.stringify(app.snapshot_data(),"  "));failed.close()
  await capture("failure_cleaner")
 check(app.street.materials.state().pharmacist.seen and not app.has_key(),"visible empty-box animation never grants a gate key")

 app.set_process(false);app.paused_manual=true;clear_lines();no_street();place("faceless",Vector2(9.25,1.125));app.hero_pos=Vector2(8,3)
 check(takeover(),"live debris scene uses its own paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return float(app.street.materials.state().faceless.shift)>.1,2),"ordinary contact moves the specified debris")
 await capture("05_debris_moving")
 check(await wait_until(func():return app.street.materials.state().faceless.done,3),"actual debris move finishes and remains in place")
 await frames(15);await capture("06_debris_retained")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Three explicit room/cast/position/resource fixtures, each with actually paid CONTROL. Between fixtures ordinary _process, injected real Space pause/resume and Enter through source dialogue; five-second wipe limit counts unfrozen world time with 20-second wall cap. Silent code-placeholder movie; not natural all-cast or human art/audio acceptance."},"  "));file.close()
 print("STREET_MATERIALS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
