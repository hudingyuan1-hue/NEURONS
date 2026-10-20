extends "res://tests/street_belt_live_check.gd"
## Four declared actor/host scenes. Actual paid CONTROL and ordinary AI/process;
## no attack phase, contact, injury, holder or knowledge fields injected.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_hand_grips_20261019/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="四种真实手部闭合连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 for id:String in app.street.HandGrips.IDS:
  app.set_process(false);app.paused_manual=true;clear_lines();no_street();app.layout.furniture.clear();app.layout.rebuild_grid();app.street.data.erase("hand_grips");app.street.data.next_attack=0;app.street.data.grip_safe_until=0
  var a:Dictionary=place(id,Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0]
  app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.reaction_left=0;app.rules.reaction_skill="";app.hero_pos=Vector2(5.05,4);app.hero_facing=Vector2.RIGHT
  if id=="stitched":app.street.materials.state().stitched.tear=0
  var origin:Vector2=app.hero_pos
  check(takeover(),id+" declared cast/position and HP/SP reset pays actual CONTROL, no contact/hold injected")
  app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
  if id=="stitched":
   check(await wait_until(func():return a.phase=="tear" and app.street.materials.state().stitched.tear>.3,1),"ordinary stitched AI first tears the existing attached paper")
   await space_key();await capture(id+"_00_original_paper_before_grab");await space_key()
  var extended:bool=await wait_until(func():return a.phase=="attack" and a.elapsed>=.1,3)
  check(extended,id+" ordinary AI opens attached fingers/jaws and physically extends toward forearm")
  if not extended:continue
  await space_key();await capture(id+"_01_open_before_contact")
  check(app.rules.hp==100 and not app.rules.gripped and app.hero_pos.is_equal_approx(origin),id+" actual Space before closure preserves no premature charge or teleport")
  await space_key()
  var held:bool=await wait_until(func():return app.street.data.holder==id,1)
  check(held,id+" actual closure during ordinary process acquires sole forearm holder")
  if not held:continue
  check(app.rules.hp==90 and app.rules.sp==80 and app.hero_pos.is_equal_approx(origin),id+" actual attached closure pays original10HP/0SP once without body movement")
  if id=="archivist":
   await click_point(Vector2(846,58));var clock:float=app.street.data.clock;var deadline:float=app.street.data.grip_until;await frames(8)
   check(app.menu.visible and app.rules.gripped and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(deadline,float(app.street.data.grip_until)),"actual book click freezes original held fingers and deadline")
   await capture("archivist_02_menu_freezes_actual_hold");await tap_key(KEY_ESCAPE)
   await space_key();await capture("archivist_03_actual_hold_default");var zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
   check(app.zoom_index>zoom and app.street.data.holder==id,"actual running wheel enlarges display while preserving physical forearm hold")
   await capture("archivist_04_actual_hold_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
   check(app.zoom_index==zoom,"actual wheel restores camera without rescaling wrist geometry")
  else:
   await space_key();await capture(id+"_02_actual_closed_hold");await space_key()
  check(await wait_until(func():return not app.rules.gripped,2),id+" original bounded hold actually opens and releases")
  check(await wait_until(func():return a.phase=="idle",1),id+" same attached hands fully retract before original cooldown")
  check(app.rules.hp==90 and app.rules.sp==80 and app.street.data.holder=="",id+" completion retains exactly one injury and no residual owner")
  await space_key();await capture(id+"_03_released")
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Four explicitly placed actor/host scenes; each resets HP/SP and uses actual paid CONTROL. Ordinary AI/process, real Book click/Escape/Space/running wheel, actual preclosure extension/no injury, closure10HP0SP/sole holder, bounded release/retract. Stitched existing paper starts intact and tears through ordinary AI. No attack/contact/hold/knowledge injection; silent fixed30, not human natural crowds or final art/audio acceptance."},"  "));file.close()
 print("STREET_HAND_GRIPS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
