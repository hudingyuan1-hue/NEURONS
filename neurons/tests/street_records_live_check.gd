extends "res://tests/street_materials_live_check.gd"
## Real input/process; one existing label and one declared content/actor fixture.
func shift_click(point:Vector2) -> void:
 var shift:=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.pressed=true;Input.parse_input_event(shift);await frames(2)
 var pixel:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(point)
 await click_position(pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
 shift=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.pressed=false;Input.parse_input_event(shift);await frames(2)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_records_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street实际读纸与收取";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_maintenance");no_street()
 app.hero_pos=Vector2(4.1,5.9);check(takeover(),"existing-floor-label fixture uses an actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(4)
 await shift_click(Vector2(3.3,5.9))
 check(await wait_until(func():return app.street.data.inspection.get("phase","")=="original",2),"actual Shift+viewport click approaches the existing label and begins reading")
 await space_key();var elapsed:float=app.street.data.inspection.get("elapsed",-1);await frames(12)
 check(app.paused_manual and is_equal_approx(elapsed,float(app.street.data.inspection.get("elapsed",-2))),"real Space freezes incomplete paper reading")
 await capture("01_existing_label_read_paused");await space_key()
 check(await wait_scene(func():return app.street.materials.state().surfaces.street_maintenance_label.seen,2),"real resume completes the existing label view")
 check(not app.street.materials.state().surfaces.street_maintenance_label.read_complete and app.street.materials.state().surfaces.street_maintenance_label.holder=="floor","unknown label glyph remains incomplete content and the physical original stays on the floor")
 await capture("02_existing_unknown_glyph")

 # Explicit second content fixture; reading is still done by the real mouse path.
 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_end");no_street();app.hero_pos=Vector2(5.5,5)
 var key:String="fixture:live_numbered_paper"
 app.street.materials.state().surfaces[key]={"id":key,"kind":"number_paper","room":app.room_id,"pos":[7,5],"holder":"floor","progress":0.0,"seen":false,"number_glyph":null,"readable_text":"测试编号纸：仅验证读完后的同一原件收取，不是正式故事内容。","original_id":"fixture:live_original","source":"declared live content fixture"}
 app.rules.owners["fixture:live_original"]="street_floor:"+key
 check(takeover(),"declared readable-paper fixture pays CONTROL before the actual observe command")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(4);await shift_click(Vector2(7,5))
 check(await wait_scene(func():return app.street.materials.state().surfaces[key].get("read_complete",false),3),"ordinary approach and full reading establish this exact paper's known content")
 await capture("03_paper_actually_read")

 # Declared collection starting cast: same paper/knowledge/owner; no flag is filled in.
 app.set_process(false);app.paused_manual=true;clear_lines();app.hero_pos=Vector2(4.5,5)
 var archivist:Dictionary=place("archivist_asylum",Vector2(7,5));archivist.last_seen=[];archivist.cooldown=2
 check(takeover(),"collection cast uses a separate actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return app.street.data.actors.archivist_asylum.phase=="paper_pick",1),"ordinary actor process starts contact with the same actual floor paper")
 await space_key();elapsed=app.street.archivist.state().elapsed;await frames(12)
 check(app.paused_manual and app.street.materials.state().surfaces[key].holder=="floor" and is_equal_approx(elapsed,app.street.archivist.state().elapsed),"real pause prevents an early ownership transfer")
 await capture("04_pickup_contact_paused");await space_key()
 check(await wait_until(func():return app.street.materials.state().surfaces[key].holder=="street_archivist:hand",1),"real remaining contact lifts the one original into the hand")
 await capture("05_original_in_hand")
 check(await wait_until(func():return app.street.materials.state().surfaces[key].holder=="street_archivist:folder",1),"ordinary remaining motion files the same paper")
 check(app.rules.owners["fixture:live_original"]=="street_archivist:folder" and app.street.archivist.state().witnessed_read.has(key),"actual witnessed filing preserves original ownership and prior real reading")
 await capture("06_filed_not_respawned")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Existing unmodified maintenance label; one explicit readable-paper content fixture and later collector starting-cast/position fixture using the very same actually read original. Each stage paid CONTROL; ordinary _process and actual Shift-click/Space/Enter afterward. Silent fixed30; not natural all-cast or authored identity glyph/art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_RECORDS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
