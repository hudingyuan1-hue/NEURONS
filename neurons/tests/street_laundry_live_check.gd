extends "res://tests/street_materials_live_check.gd"
## One actual approach/hit/recovery, then one actual report/side adjustment.
func pointer_key(index:int) -> void:
 var point:=Vector2(600,430)
 var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=index;event.pressed=true;Input.parse_input_event(event);await frames(2)
 event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=index;event.pressed=false;Input.parse_input_event(event);await frames(2)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_laundry_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street袋体与侧移连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var a:Dictionary=place("transporter_hospital",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];a.elapsed=0;app.street.data.erase("laundry_bag");app.street.laundry_bag.sync();app.hero_pos=Vector2(5.6,4)
 check(takeover(),"declared live cast/position fixture uses actually paid CONTROL, no attack or hit flags filled")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="windup",2),"ordinary world pursuit really drags the bag and stops inside actual reach")
 await frames(6);await space_key();var elapsed:float=a.elapsed;var bag:Dictionary=app.street.laundry_bag.state();var center:Array=bag.center.duplicate();await frames(10)
 check(app.paused_manual and is_equal_approx(elapsed,float(a.elapsed)) and center==bag.center and app.rules.hp==100,"real Space holds tightener and bag together before any damage")
 await capture("01_tighten_paused_default")
 await space_key()
 check(await wait_until(func():return a.phase=="attack",1),"real resume completes preparation and enters the actual swept bag")
 await capture("03_actual_bag_sweep")
 check(await wait_until(func():return app.rules.hp==85,1),"ordinary shared handler makes one real fifteen-HP body contact")
 check(await wait_until(func():return a.phase=="recover",1),"same bag drops into the existing recovery instead of a reverse strike")
 await space_key();elapsed=a.elapsed;center=bag.center.duplicate();await frames(10)
 check(app.paused_manual and is_equal_approx(elapsed,float(a.elapsed)) and center==bag.center and app.rules.hp==85,"real pause during lowering cannot repeat the settled contact")
 await capture("04_lowering_after_contact_paused");await space_key()
 check(await wait_until(func():return a.phase=="idle",1),"real recovery finishes regripping before original cooldown")
 check(app.rules.hp==85 and a.cooldown>1.2,"one complete ordinary swing settles only once")
 await capture("05_regripped_same_bag")
 var default_zoom:int=app.zoom_index;await pointer_key(MOUSE_BUTTON_WHEEL_UP)
 check(app.zoom_index>default_zoom,"actual unpaused mouse wheel changes to an existing enlarged camera step")
 await space_key();await capture("05b_regripped_zoomed");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==default_zoom,"actual wheel returns to the original camera step without scaling collision")

 app.set_process(false);app.paused_manual=true;clear_lines();no_street()
 var head:Dictionary=place("head_nurse",Vector2(4,4.3));head.report_left=0;head.report_event="";head.report_target=[];head.report_side_left=0
 var receiver:Dictionary=place("warder",Vector2(6,4.3));receiver.cooldown=5;receiver.direction=[1,0]
 app.hero_pos=Vector2(3,5);app.rules.hp=100;app.rules.hurt_left=0;app.rules.stun_left=0
 check(takeover(),"second declared live report fixture pays its own CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return head.phase=="report_side",2),"ordinary completed knock/point is followed by actual side adjustment")
 var before:Vector2=app.street.position("head_nurse");await frames(4)
 check(app.street.position("head_nurse").distance_to(before)>.03 and app.street.data.reports.head_nurse.receivers.has("warder"),"real side movement retains actual delivery even when the recipient independently reacquires the host")
 await space_key();elapsed=float(head.report_side_left);before=app.street.position("head_nurse");await frames(10)
 check(app.paused_manual and is_equal_approx(elapsed,float(head.report_side_left)) and before.is_equal_approx(app.street.position("head_nurse")),"real Space freezes finite post-report movement")
 await capture("06_head_side_adjustment_paused");await space_key()
 check(await wait_until(func():return head.phase=="idle",1),"resumed finite movement stops without replaying the original report")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two explicit NPC/position fixtures (second recipient initial cooldown5s), actually paid CONTROL each, then ordinary _process with actual Space and mouse-wheel inputs. No bag attack/contact/report/hearing/knowledge flags filled; second scene resets hero HP for independent report fixture. Silent fixed30 code placeholders; not natural full-game or subjective art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_LAUNDRY_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
