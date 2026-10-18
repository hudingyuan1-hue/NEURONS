extends "res://tests/street_laundry_live_check.gd"
## One declared NPC/position scene, actual paid CONTROL and ordinary process/input.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_embrace_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="双臂围合连续实机验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_narrow");no_street()
 var a:Dictionary=place("isolation",Vector2(4,4));a.hp=60;a.direction=[1,0];a.cooldown=0
 app.street.data.erase("isolation_embrace");app.street.data.grip_safe_until=0;app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0
 app.hero_pos=Vector2(5.5,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"declared single guard/host scene uses actual paid CONTROL, not injected grip or SP loss")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup",2),"ordinary autonomous approach reaches its own full preparation inside actual padded-arm reach")
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.1,2),"ordinary process produces two closing arms before torso capture")
 await space_key();var clock:float=app.street.data.clock;await frames(10)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.sp==80 and not app.rules.gripped,"actual Space pauses the unfinished enclosure without early SP settlement")
 await capture("01_two_arms_closing_paused");await space_key()
 check(await wait_until(func():return app.street.data.holder=="isolation",1),"ordinary two-sided closure establishes the one actual torso holder")
 await space_key();clock=app.street.data.clock;await frames(10)
 check(app.paused_manual and app.rules.hp==100 and app.rules.sp==65 and is_equal_approx(clock,float(app.street.data.clock)),"actual paused torso hold preserves exactly fifteen SP, zero HP damage and its deadline")
 await capture("02_actual_torso_hold_paused")
 var default_zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP)
 check(app.zoom_index>default_zoom,"actual running-time wheel selects an existing enlarged camera step without changing embrace geometry")
 await space_key();await capture("03_actual_hold_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==default_zoom,"actual wheel returns to original view size while the same torso remains restrained")
 check(await wait_until(func():return a.phase=="recover" and not app.rules.gripped,2),"original real-time hold deadline opens the same pair of arms")
 await capture("04_both_arms_opening")
 check(await wait_until(func():return a.phase=="idle",1),"original recovery finishes before a fresh independent embrace can start")
 check(app.street.embrace.state().arms.is_empty() and app.rules.sp==65 and app.rules.hp==100 and a.cooldown>1.2,"recovered arms leave no fixed body/door residue or repeated charge")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"One explicit isolation guard/host fixture with actually paid CONTROL. Ordinary _process approach/preparation/two-arm closure/SP-only hold/deadline/open recovery, actual Space and running-time wheel. No attack/hit/hold/knowledge fields filled. Silent fixed30, placeholders, not natural crowds, manual full-game or final art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_EMBRACE_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
