extends "res://tests/street_grasp_live_check.gd"
## Actual world and real menu/Space/wheel/F, two declared actor/blocker poses.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_director_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="真实椅架闭合与膝跳中断连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=place("director",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];app.street.data.erase("director_frame")
 app.rules.hp=100;app.rules.sp=80;app.hero_pos=Vector2(4.84,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"declared director/host fixture pays actual CONTROL, with no closure/contact/holder fields injected")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.25,2),"ordinary pursuit produces original visible opening preparation")
 await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var elapsed:float=a.elapsed;await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(elapsed,float(a.elapsed)) and app.rules.hp==100,"actual book button freezes opening rails and recorder world clock before any injury")
 await capture("01_actual_menu_freezes_opening");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.1,2),"real Escape resumes original preparation into actual closing rails")
 await space_key();await capture("02_actual_closing_not_yet_fixed")
 check(app.rules.hp==100 and not app.rules.gripped,"actual pause before complete enclosure shows no early rectangular grip")
 await space_key()
 check(await wait_until(func():return app.street.data.holder=="director",1),"ordinary bilateral rail contact actually fixes the host")
 await space_key();clock=app.street.data.clock;var pos:Vector2=app.hero_pos;await frames(8)
 check(app.rules.hp==90 and app.rules.sp==70 and app.rules.gripped and is_equal_approx(clock,float(app.street.data.clock)) and app.hero_pos.is_equal_approx(pos),"real Space holds attached chair and host with one original ten/ten effect")
 await capture("03_actual_torso_fixed_default");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>zoom and app.street.data.holder=="director","actual running wheel enlarges same physical enclosure without changing owner")
 await capture("04_actual_torso_fixed_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==zoom,"actual running wheel restores original view without changing collision scale")
 check(await wait_until(func():return not app.rules.gripped,2),"original actual1.2s deadline opens the same attached rails")
 await capture("05_actual_rails_release")
 check(await wait_until(func():return a.phase=="idle",1),"same recovery folds both rails before next preparation")
 check(app.rules.hp==90 and app.rules.sp==70 and app.street.director.state().frames.is_empty(),"release/retraction/recorder cannot add injury, a new chair or statement")

 # Independent scene: reset HP/SP, one real solid obstacle and an unlocked existing KNEE.
 app.set_process(false);app.paused_manual=true;clear_lines();no_street();app.street.data.next_attack=0
 a=place("director",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];app.street.data.erase("director_frame")
 app.layout.furniture.append({"id":"live_one_rail_blocker","name":"实际阻挡一侧椅架","rect":Rect2(4.5,3.53,.14,.18),"height":110});app.layout.rebuild_grid()
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0;app.hero_pos=Vector2(4.8,4);app.hero_facing=Vector2.LEFT
 check(takeover(),"second declared one-rail obstacle scene resets HP/SP and pays separate CONTROL; KNEE merely unlocked, no kick result injected")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.35,2),"ordinary body and attached rail approach the actual one-sided cabinet")
 await space_key();await capture("06_actual_one_rail_obstacle");await space_key();await tap_key(KEY_F)
 check(await wait_until(func():return a.hp==45,.6),"actual unpaused F executes original legal knee and physically damages carrier")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.hp==100 and app.rules.sp==80 and not app.rules.gripped and app.street.director.state().frames.is_empty(),"actual kick interrupts before closure and immediately leaves no old rail capture or stale original-position image")
 await capture("07_actual_knee_interrupt_no_old_frame");await space_key()
 check(await wait_until(func():return a.hurt<=0,1.2),"original hurt recovers without pending ghost clamp")
 await capture("08_actual_hurt_recovered")
 check(app.rules.hp==100 and app.rules.sp==80 and app.street.data.holder=="","same interrupted closure cannot pay later or generate detention")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two explicit actor/host scenes; second resets HP/SP, declares one solid rail obstacle and unlocks original KNEE. Actual paid CONTROL each, ordinary AI/process and real Book/Escape/Space/running wheel/F, true10HP10SP torso enclosure/original1.2s/release, actual body kick and no stale rail image. No hit/closure/holder/knowledge fields injected. Silent fixed30, not natural mixed crowds/manual full-game/final art or audio audition."},"  "));file.close()
 print("STREET_DIRECTOR_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
