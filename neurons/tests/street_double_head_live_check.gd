extends "res://tests/street_belt_live_check.gd"
## One declared neutral body/host setup; real paid CONTROL, actual F key,
## ordinary AI/process, real pause/menu/zoom and natural neutral recovery.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_double_head_20261019/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="真实F命中后的单次双头反击";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street();app.layout.furniture.clear();app.layout.rebuild_grid()
 var a:Dictionary=place("double_head",Vector2(4,4));a.home=a.pos.duplicate();a.hp=60;a.hostile=false;a.cooldown=0;a.direction=[1,0];app.street.data.erase("double_head_arms")
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(4.82,4);app.hero_facing=Vector2.LEFT;app.rules.skill_states.KNEE.unlocked=true
 check(takeover(),"declared neutral two-head/body scene pays actual CONTROL before any counter eligibility")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(12)
 check(a.hp==60 and not a.hostile and app.rules.hp==100,"ordinary mutual neck pose stays neutral without self damage or proximity aggression")
 await space_key();await capture("01_neutral_two_heads_one_body");await space_key();await tap_key(KEY_F)
 var hit:bool=await wait_until(func():return a.hp==45,1)
 check(hit and a.hostile,"actual F key completes original legal knee contact and alone authorizes counter")
 if not hit:await finish_counter();return
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.15,3),"actual hurt and autonomous physical approach precede original counter preparation")
 await space_key();await capture("02_actual_injury_then_release_necks")
 check(app.rules.hp==100 and not app.rules.gripped,"real Space during release freezes without premature arm damage or grasp")
 await space_key();check(await wait_until(func():return app.street.double_head.state().phase=="heads_turn" and app.street.double_head.state().turn>.2,1),"ordinary original windup visibly turns both heads")
 await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var elapsed:float=a.elapsed;await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(elapsed,float(a.elapsed)),"actual book input freezes head turn and the one original attack timeline")
 await capture("03_actual_book_freezes_two_head_turn");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.025,1),"real Escape resumes same preparation into actual two-arm extension")
 await space_key();await capture("04_actual_early_forward_arms")
 check(app.rules.hp==100,"early local hands short of target cannot behave as old fully filled forward rectangle")
 await space_key();check(await wait_until(func():return app.rules.hp==85,.6),"ordinary actual forward arm contact commits one original fifteen HP")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.rules.hp==85 and app.rules.sp==80 and not app.rules.gripped and app.street.data.holder=="" and is_equal_approx(clock,float(app.street.data.clock)),"actual paused two-arm strike pays once without second-head injury or added grip")
 await capture("05_actual_two_arm_contact_default");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>zoom and app.rules.hp==85,"actual running wheel changes display without changing contact receipt")
 await capture("06_actual_counter_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==zoom,"real wheel restores camera without scaling arm geometry")
 check(await wait_until(func():return a.phase=="idle" and not a.hostile,2),"same original recovery returns shared body to neutral")
 await frames(30)
 check(app.rules.hp==85 and a.hp==45 and not a.hostile,"ordinary post-counter proximity does not inflict self damage or repeat retaliation")
 await space_key();await capture("07_actual_neutral_restored")
 await finish_counter()
func finish_counter() -> void:
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"One explicit neutral actor/body/host placement, actual paid CONTROL and actual F-key knee. Ordinary AI/process injury→approach→neck release→two-head turn→local two-arm15HP contact→original neutral recovery; real Book/Escape/Space/running wheel. No hostile/attack/hit/receipt fields injected after initial neutral setup. Silent fixed30, not human full game/final art/audio."},"  "));file.close()
 print("STREET_DOUBLE_HEAD_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
