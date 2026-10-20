extends "res://tests/street_belt_live_check.gd"
## Initial neutral/body setup only; ordinary AI and actual paid CONTROL/F,
## Book/Escape/Space/wheel inputs thereafter, no successful-state injection.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_double_face_retreat_20261019/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际F命中双面后中立退避";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street();app.layout.furniture.clear();app.layout.rebuild_grid()
 var a:Dictionary=place("double_face",Vector2(4,4));a.hp=60;a.hostile=false;a.direction=[1,0];a.face_turned=false;a.face_turn_progress=0.0;app.street.data.erase("double_face_retreat");app.street.data.face_pending={}
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(4.82,4);app.hero_facing=Vector2.LEFT;app.rules.skill_states.KNEE.unlocked=true
 check(takeover(),"explicit neutral double-face/body setup pays original actual CONTROL before input")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(12)
 check(a.hp==60 and not a.hostile and not app.street.double_face_retreat.state().pending and not a.face_turned,"ordinary neutral witness does not retreat or turn for an unexecuted control takeover")
 await space_key();await capture("01_neutral_before_actual_input");await space_key();await tap_key(KEY_F)
 var hit:bool=await wait_until(func():return a.hp==45,1)
 check(hit and not a.hostile,"actual F key finishes one original15HP knee body contact without creating counter hostility")
 if not hit:await finish_retreat();return
 var pushed:Vector2=app.street.position("double_face");await space_key();var clock:float=app.street.data.clock;var left:float=app.street.double_face_retreat.state().left;await frames(8)
 check(a.hurt>0 and a.phase=="idle" and is_equal_approx(clock,float(app.street.data.clock)) and pushed.is_equal_approx(app.street.position("double_face")) and is_equal_approx(left,.5),"real Space freezes original injury before any retreat displacement or timer use")
 check(app.street.data.face_pending.is_empty() and not a.face_turned and a.face_turn_progress==0,"same actual hit interrupts unfinished witnessed turn and does not queue it after recovery")
 await capture("02_actual_injury_before_retreat");await space_key()
 check(await wait_until(func():return a.phase=="display_retreat" and float(app.street.double_face_retreat.state().distance)>=.08,1),"ordinary original hurt recovery leads to visible continuous neutral retreat")
 check(app.street.position("double_face").distance_to(app.hero_pos)>pushed.distance_to(app.hero_pos),"actual body now moves farther from the physical knee source instead of returning or chasing")
 await click_point(Vector2(846,58));clock=app.street.data.clock;var at:Vector2=app.street.position("double_face");left=float(app.street.double_face_retreat.state().left);await frames(8)
 check(app.menu.visible and is_equal_approx(clock,float(app.street.data.clock)) and at.is_equal_approx(app.street.position("double_face")) and is_equal_approx(left,float(app.street.double_face_retreat.state().left)),"real book input freezes the same remaining retreat without jumping to its destination")
 await capture("03_actual_book_during_retreat");await tap_key(KEY_ESCAPE)
 check(await wait_until(func():return not app.street.double_face_retreat.state().pending,1),"real Escape resumes and completes only the same original .5s retreat episode")
 check(a.phase=="idle" and not a.hostile and a.hp==45 and app.rules.hp==100 and not app.rules.gripped and app.street.data.holder=="","ordinary retreat ends in neutral idle without an added counter, holder or damage")
 check(is_equal_approx(float(app.street.double_face_retreat.state().distance),.425),"actual continuous process uses original .85m/s for .5s after injury, not teleport or extended duration")
 at=app.street.position("double_face");await frames(30)
 check(at.is_equal_approx(app.street.position("double_face")) and not a.face_turned and app.street.data.face_pending.is_empty(),"standing nearby afterwards neither repeats retreat nor replays the interrupted head turn")
 await space_key();await capture("04_actual_neutral_after_retreat");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>zoom and at.is_equal_approx(app.street.position("double_face")),"actual running wheel changes display while preserving the same body destination")
 await capture("05_same_destination_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==zoom and app.rules.hp==100 and a.hp==45,"actual camera restoration cannot replay original contact or change body scale logic")
 await finish_retreat()
func finish_retreat() -> void:
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"One explicit neutral actor/body placement; actual paid CONTROL and F knee, ordinary process/AI original injury→local legal retreat→neutral. Actual Space/Book/Escape/running wheel, no injury/retreat/turn success fields filled after entry. Silent fixed30; not human full campaign, crowds or final art/audio."},"  "));file.close()
 print("STREET_DOUBLE_FACE_RETREAT_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
