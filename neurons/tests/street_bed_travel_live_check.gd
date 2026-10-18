extends "res://tests/street_props_live_check.gd"
## One declared near-door cast/HP/cooldown fixture, then real input and ordinary process.
func pan_left() -> void:
 var point:=Vector2(600,350)
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_MIDDLE;down.pressed=true;down.position=point;Input.parse_input_event(down);await frames(2)
 var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(500,0);motion.relative=Vector2(500,0);motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE;Input.parse_input_event(motion);await frames(2)
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_MIDDLE;up.pressed=false;up.position=motion.position;Input.parse_input_event(up);await frames(2)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_bed_travel_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="转运床真实过门连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");setup_bed(Vector2(18.3,6))
 app.hero_pos=Vector2(19,6.7);app.street.data.actors.transporter_asylum.cooldown=30
 check(takeover(),"live real-door demonstration pays for CONTROL, without directly setting follow or destination")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(3)
 var pixel:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.door_point("street_node"))
 await click_position(pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
 check(await wait_until(func():return app.room_id=="street_node",4),"real mouse command walks, opens and crosses existing door")
 check(not str(app.street.data.actors.transporter_asylum.follow).is_empty() or not app.street.lateral_bed.travel.phase().is_empty(),"actual last sight and host door crossing produce the real follow request")
 await wait_until(func():return app.input_lock_frames<=0,1)
 pixel=app.world_viewport.get_canvas_transform()*app.layout.project(Vector2(5.5,6))
 await click_position(pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
 check(await wait_until(func():return app.street.lateral_bed.travel.phase()=="turn",3),"ordinary process begins rigid bed turning")
 check(await wait_until(func():return app.input_lock_frames<=0,1),"existing close/room click-protection finishes before the pause key")
 await space_key();var axis:Array=app.street.data.lateral_bed.axis.duplicate();var center:Array=app.street.data.lateral_bed.center.duplicate();await frames(12)
 check(app.paused_manual and app.street.data.lateral_bed.axis==axis and app.street.data.lateral_bed.center==center,"real Space freezes partial travel pose and operator")
 await capture("01_turn_paused");await space_key();await pan_left()
 check(app.view_controls.manual_view,"real middle drag views current-room entry while host remains autonomous")
 check(await wait_until(func():return app.street.lateral_bed.travel.phase()=="cross",12),"resuming ordinary process reaches actual source doorway sweep")
 await capture("02_source_crossing")
 check(await wait_until(func():return app.street.data.actors.transporter_asylum.room=="street_node",6),"same carrier and bed enter target only after the actual portal sweep")
 await space_key();check(app.room_id=="street_node","entry is rendered in the host's real current room")
 await capture("03_target_entry_paused");await space_key()
 check(await wait_until(func():return app.street.lateral_bed.travel.phase().is_empty(),4),"ordinary remaining movement finishes inside the target room")
 check(app.street.data.actors.size()==45 and app.street.data.lateral_bed.id=="street_asylum_transport_bed","actual trip retains unique object and all original identities")
 await capture("04_trip_complete")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Declared near-door source pose/cast/HP and 30s initial carrier cooldown fixture to isolate transport. Actual paid CONTROL, viewport mouse door and floor movement commands, Space and middle drag. No direct follow/destination/room/position modifications after start; ordinary process throughout. Silent placeholder recording, not natural full game or human/art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_BED_TRAVEL_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
