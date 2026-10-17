extends "res://tests/street_props_check.gd"
## Two declared scene fixtures; between them ordinary process and real keys.
func wait_until(predicate:Callable,limit:float) -> bool:
 var elapsed:float=0
 while elapsed<limit:
  if predicate.call():return true
  await get_tree().process_frame;elapsed+=get_process_delta_time()
 return predicate.call()
func space_key() -> void:
 for down in [true,false]:
  var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=down;Input.parse_input_event(key);await frames(2)
func takeover() -> bool:
 app.rules.end_control();app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.power=1;app.rules.skill_states.CONTROL.resistance=0;app.rules.skill_states.CONTROL.until=0
 app.rules.neurons=30
 var result:Dictionary=app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 return result.ok and result.success and app.rules.control_left>0

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_props_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street连续交互验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_maintenance");no_street()
 var labor:Dictionary=app.street.data.actors.labor;labor.present=true;labor.room=app.room_id;labor.pos=[5,4.8];labor.hp=40;labor.hurt=0
 app.street.data.box={};app.street.box.normalize();app.hero_pos=Vector2(8,2.5)
 var seeker:Dictionary=app.street.data.actors.self;seeker.present=true;seeker.room=app.room_id;seeker.pos=[4,2.5];seeker.hp=80;seeker.hostile=true;seeker.last_seen=[4,4];seeker.phase="idle"
 check(takeover(),"live fixture uses an actually paid successful CONTROL window")
 clear_lines();app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return app.street.data.box.phase=="prepare",1),"ordinary world process starts the only box preparation")
 await space_key();var elapsed:float=app.street.data.box.elapsed;await frames(12)
 check(app.paused_manual and app.street.data.box.elapsed==elapsed,"real Space key holds preparation without early sound")
 await capture("01_box_prepare_paused");await space_key()
 check(await wait_until(func():return app.street.data.box.phase=="flight",2),"resuming real input continues into visible box flight")
 await frames(6);await capture("02_box_flight")
 check(await wait_until(func():return app.street.data.box.phase=="ground",2),"ordinary motion reaches actual box impact")
 await capture("03_box_landing")
 check(sounds()==1 and app.street.data.box.heard.has("self"),"real moving seeker hears exactly one actual impact")
 await frames(40)

 # Explicit second fixture; no hidden seed, invulnerability or forced hit.
 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_twisted");setup_bed();check(takeover(),"second fixture pays for its own CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return app.street.data.lateral_bed.phase=="windup",1),"ordinary process starts visible sideways bed windup")
 await frames(10);await space_key();elapsed=app.street.data.lateral_bed.elapsed;await frames(12)
 check(app.paused_manual and app.street.data.lateral_bed.elapsed==elapsed,"real Space also holds bed's locked windup")
 await capture("04_bed_windup_paused");await space_key()
 check(await wait_until(func():return app.rules.hp==80,3),"ordinary moving bed makes one actual twenty-HP contact")
 await capture("05_bed_real_contact");await frames(40)
 check(app.rules.hp==80 and app.street.data.lateral_bed.phase!="attack","real stopped/retreating bed does not repeat injury")
 await capture("06_bed_retreat")
 app.paused_manual=true
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two explicitly selected room/actor/resource fixtures, actual paid CONTROL and Space input, ordinary world process between fixtures. Continuous silent fixed30 recording; not natural full-game or subjective audio acceptance."},"  "));file.close()
 print("STREET_PROPS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
