extends "res://tests/street_grasp_live_check.gd"
## Three declared scenes; then ordinary AI, real input and shared contacts only.
func begin_scene(id:String,offset:Vector2) -> Dictionary:
 app.set_process(false);app.paused_manual=true;clear_lines();no_street();app.street.data.next_attack=0;app.street.data.grip_safe_until=0;app.street.data.holder="";app.rules.gripped=false
 app.layout.furniture.clear();app.layout.rebuild_grid();app.street.data.erase("mother_arms");app.street.data.erase("local_sweeps")
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.action.clear();app.rules.pending_neural.clear();app.rules.reaction_left=0;app.rules.reaction_skill=""
 app.hero_pos=Vector2(4,4)+offset;app.hero_facing=Vector2.LEFT
 var a:Dictionary=place(id,Vector2(4,4));a.hp=80;a.cooldown=0;a.direction=[1,0]
 check(takeover(),"declared "+id+" scene resets HP/SP and pays actual CONTROL without a hit/holder/attack-result fixture")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_limbs_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="母亲夹击和刀路横扫连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=begin_scene("mother",Vector2(.84,0))
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.3,2),"ordinary mother actually approaches/gathers visible arms")
 await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var elapsed:float=a.elapsed;await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(elapsed,float(a.elapsed)) and app.rules.hp==100,"actual book menu freezes gathering before any arm injury")
 await capture("01_actual_menu_freezes_gathering");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return app.rules.hp==90,2),"real resumed multi-arm contact pays one original ten HP")
 check(await wait_until(func():return app.street.data.holder=="mother",1),"actual closed torso, rather than mere contact, becomes sole holder")
 await space_key();clock=app.street.data.clock;var pos:Vector2=app.hero_pos;await frames(8)
 check(app.paused_manual and app.rules.hp==90 and app.rules.sp==80 and app.rules.gripped and app.hero_pos.is_equal_approx(pos) and is_equal_approx(clock,float(app.street.data.clock)),"real Space freezes completed enclosure and preserves one charge")
 await capture("02_actual_mother_fixed_default");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>zoom and app.street.data.holder=="mother","real running wheel enlarges same attached limbs without changing collision owner")
 await capture("03_actual_mother_fixed_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==zoom,"real wheel restores default view")
 check(await wait_until(func():return not app.rules.gripped,2),"ordinary original1.2s opens actual maternal enclosure")
 await capture("04_actual_mother_release")
 check(await wait_until(func():return a.phase=="idle",1),"actual complete recovery folds all maternal arms")
 check(app.rules.hp==90 and app.rules.sp==80,"multiple arms and recovery cannot repeat original injury")

 a=begin_scene("doctor",Vector2(.8,0));app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0
 check(await wait_until(func():return a.phase=="windup" and a.elapsed>=.4,2),"ordinary doctor visibly raises coordinated blades")
 await space_key();await capture("05_actual_doctor_raised");await space_key();await tap_key(KEY_F)
 check(await wait_until(func():return a.hp==65,.6),"actual unpaused F hits doctor's body using original legal knee")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.hp==100 and app.street.local_sweeps.state("doctor").limbs.is_empty(),"effective knee removes stale blade geometry immediately before any delayed injury")
 await capture("06_actual_doctor_knee_interrupt");await space_key()
 check(await wait_until(func():return a.hurt<=0,1),"original hurt recovers without a hidden blade continuing")

 a=begin_scene("skinface",Vector2(1.05,0))
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.025,2),"ordinary skinface raises arm and starts fixed local sweep")
 await space_key();await capture("07_actual_skinface_local_sweep");await space_key()
 check(await wait_until(func():return app.rules.hp==85,1),"actual arm-path contact pays original fifteen HP without old face/door script")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and not app.rules.gripped and app.rules.sp==80,"actual paused sweep has no grip or former face-opening SP fee")
 await capture("08_actual_skinface_contact");await space_key()
 check(await wait_until(func():return a.phase=="idle",1.5),"ordinary skinface retraction completes without another health bar or repeated injury")
 check(app.rules.hp==85 and app.rules.sp==80,"same completed local sweep cannot settle twice")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Three declared actor/host poses, each HP/SP reset and actual paid CONTROL; doctor existing KNEE unlocked. Thereafter ordinary _process/AI, actual Book/Escape/Space/running wheel/F, true maternal impact/enclosure/release, effective carrier knee, actual skinface sweep. No contact/holder/damage/knowledge result injection. Silent fixed30, not natural mixed crowds/manual whole-game/final art or audio audition."},"  "));file.close()
 print("STREET_LIMBS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
