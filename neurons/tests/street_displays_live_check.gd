extends "res://tests/street_materials_live_check.gd"
## Three declared starting casts. Production _process, paid CONTROL and actual input afterward.
func floor_click(at:Vector2) -> void:
 var pixel:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(at)
 await click_position(pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_displays_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street可见动作连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 place("back",Vector2(4.5,4.5));place("register_nurse",Vector2(4.8,6));app.hero_pos=Vector2(3,4.5)
 check(takeover(),"first live exposure uses an actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return app.street.displays.state("back").front,1.2),"ordinary world process sees the front before the turn")
 await space_key();var elapsed:float=app.street.displays.state("back").elapsed;await frames(12)
 check(app.paused_manual and is_equal_approx(elapsed,app.street.displays.state("back").elapsed),"real Space freezes the incomplete front-to-back presentation")
 await capture("01_front_paused");await space_key()
 check(await wait_scene(func():return app.street.displays.state("back").back,2),"resuming completes the real turn and separately reads the reverse")
 await capture("02_two_sides_actual")

 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_node");no_street()
 place("blind",Vector2(5.8,5));app.hero_pos=Vector2(3.8,5);app.hero_state="idle"
 check(takeover(),"cloth scene also uses an actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(10)
 check(app.street.data.actors.blind.phase=="idle","ordinary stationary scene has no spontaneous cloth loop")
 await floor_click(Vector2(4.5,5))
 check(await wait_until(func():return app.street.data.actors.blind.phase=="cloth",1.4),"real viewport floor click creates footsteps that lift local cloth")
 await space_key();elapsed=app.street.displays.state("blind").elapsed;await frames(12)
 check(app.paused_manual and is_equal_approx(elapsed,app.street.displays.state("blind").elapsed),"real Space freezes the visible local cloth without advancing its hold")
 await capture("03_local_cloth_paused");await space_key()
 check(await wait_scene(func():return app.street.displays.state("blind").cooldown>0,3),"finite cloth hold closes under the ordinary clock")

 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_end");no_street()
 place("mimic",Vector2(8,5));app.hero_pos=Vector2(6,5);app.hero_state="idle";app.hero_facing=Vector2.RIGHT
 check(takeover(),"mimic scene starts from a real paid takeover, not a directly assigned action")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(8)
 var records:int=app.rules.institutional_records.size();var evidence:int=app.rules.evidence.size()
 await floor_click(Vector2(6,4))
 check(await wait_until(func():return app.street.data.actors.mimic.phase=="mimic",1),"actual clicked movement turns the host and supplies the visible local copy")
 check(app.rules.institutional_records.size()==records,"live mimic cannot generate a record before writing")
 evidence=app.rules.evidence.size() # Existing actual CONTROL navigation has now settled; the copy must add none.
 await capture("04_visible_copy")
 check(await wait_scene(func():return app.street.data.actors.mimic.phase=="mimic_write",2),"ordinary process enters actual board writing")
 await space_key();elapsed=app.street.displays.state("mimic").elapsed;await frames(12)
 check(app.paused_manual and app.rules.institutional_records.size()==records and is_equal_approx(elapsed,app.street.displays.state("mimic").elapsed),"real pause cannot finish writing or pre-grant the institutional claim")
 await capture("05_writing_paused");await space_key()
 check(await wait_scene(func():return app.rules.institutional_records.size()>records,2),"real resume completes one actual institutional label")
 check(app.rules.institutional_records.back().text=="自主行为" and app.rules.institutional_records.back().origin=="controlled" and app.rules.evidence.size()==evidence,"institutional classification preserves the actual controlled origin without extra intervention evidence")
 await capture("06_record_complete")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Three declared room/cast/position fixtures with actual paid CONTROL; ordinary _process plus viewport floor clicks, Space and Enter between them. Code placeholders, continuous silent 30FPS recording, not natural all-cast/human art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_DISPLAYS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
