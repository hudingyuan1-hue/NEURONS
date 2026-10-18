extends "res://tests/street_splash_live_check.gd"
## Two explicitly placed scenes; all attacks/contacts advance through ordinary process.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_belt_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="真实挥带与套腕连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var a:Dictionary=place("warder",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];app.street.data.erase("warder_belt")
 app.rules.hp=100;app.rules.sp=80;app.hero_pos=Vector2(5.25,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"declared warder/host scene uses actual paid CONTROL, with no contact/holder/attack phase injection")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.25,2),"ordinary pursuit starts original visible side draw")
 await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var elapsed:float=a.elapsed;await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(elapsed,float(a.elapsed)) and app.rules.hp==100,"actual book click freezes unfinished strap without early damage")
 await capture("01_actual_menu_freezes_draw");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return not app.menu.visible and a.phase=="windup" and a.elapsed>=.6,2),"real Escape resumes same original preparation")
 await space_key();await capture("02_actual_uncoil_default");await space_key()
 check(await wait_until(func():return app.rules.hp==85,1),"ordinary physical strip actually commits original fifteen HP once")
 await space_key();clock=app.street.data.clock;var tip:Vector2=app.street.vector(app.street.belt.state().profile[-1]);await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and tip.is_equal_approx(app.street.vector(app.street.belt.state().profile[-1])) and app.rules.sp==75,"real Space freezes same strip after one fifteen/five hit")
 check(not app.rules.gripped and app.street.data.holder=="","real waist strike adds no physical fixation")
 await capture("03_actual_waist_sweep_paused");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP)
 check(app.zoom_index>zoom,"actual unpaused wheel uses existing enlarged view")
 await space_key();await capture("04_same_strap_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==zoom,"running wheel restores original display without scaling contact geometry")
 check(await wait_until(func():return a.phase=="idle",2),"same original recovery fully wraps strap")
 check(app.rules.hp==85 and app.rules.sp==75 and a.cooldown>1.1,"retracting strip pays no second contact")

 # Independent scene; explicitly reset resources and placements before ordinary ticks.
 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_narrow");no_street()
 a=place("assistant_asylum",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];app.street.data.erase("assistant_restraint");app.street.data.next_attack=0
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(5.04,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"second declared assistant/host scene explicitly resets HP/SP and pays separate actual CONTROL, without filling grip or settled fields")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.1,2),"ordinary world opens and extends actual wrist loop")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.hp==100 and not app.rules.gripped,"real Space before closure freezes an open loop without false restraint")
 await capture("05_actual_open_loop_paused");await space_key()
 check(await wait_until(func():return app.street.data.holder=="assistant_asylum",1),"ordinary actual tightened loop acquires one physical forearm holder")
 await space_key();clock=app.street.data.clock;var deadline:float=app.street.data.grip_until;await frames(8)
 check(app.rules.hp==90 and app.rules.sp==70 and app.rules.gripped and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(deadline,float(app.street.data.grip_until)),"actual pause preserves original ten/ten injury and remaining1.2s physical hold")
 await capture("06_actual_wrist_fixed_default");zoom=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>zoom and app.street.data.holder=="assistant_asylum","existing enlarged view retains the same live wrist holder")
 await capture("07_actual_wrist_fixed_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(await wait_until(func():return not app.rules.gripped,2),"ordinary original hold expires and actually releases")
 await capture("08_actual_loop_release")
 check(await wait_until(func():return a.phase=="idle",2),"actual loop finishes full retract before next preparation")
 check(app.rules.hp==90 and app.rules.sp==70 and app.street.data.holder=="" and app.street.restraint.state().pose.is_empty(),"same recovery leaves no persistent line, extra injury or owner")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two explicit cast/position scenes, second resets HP/SP, actual paid CONTROL each. Ordinary process/AI/real Book click/Escape/Space/running wheel; actual belt sweep15HP5SP without grip, actual forearm loop10HP10SP1.2s, full recovery. No attack/contact/grip/knowledge fields filled. Silent fixed30 film, not natural crowds/human pacing/final art or audio audition."},"  "));file.close()
 print("STREET_BELT_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
