extends "res://tests/street_laundry_live_check.gd"
## One declared nurse/host scene; autonomous complete cup sequence, real input.
func count_fact(kind:String) -> int:
 var count:int=0
 for fact in app.rules.facts:
  if str(fact.kind)==kind:count+=1
 return count
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_embrace_20261018/medicine_live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际扣头移杯吞咽连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 var a:Dictionary=place("ward_nurse",Vector2(4,4));a.hp=60;a.portions=1;a.direction=[1,0];a.cooldown=0;app.street.data.erase("ward_medicine")
 app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.street.data.grip_safe_until=0;app.hero_pos=Vector2(5.5,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"one explicit nurse/host scene pays real CONTROL without filling head-hold, poured-dose or effect fields")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="drug_hold",3),"ordinary autonomous approach and actual reaching hand establish only head fixation")
 check(app.rules.sp==80 and app.rules.hp==100 and a.portions==1,"head contact alone does not charge oral medicine")
 await space_key();await capture("01_actual_head_fixed_full_cup");await space_key()
 check(await wait_until(func():return app.street.medicine.state().phase=="cup_tilt",1),"ordinary other hand moves the same cup to the actual mouth before tipping")
 await space_key();var clock:float=app.street.data.clock;await frames(10)
 check(app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.sp==80 and a.portions==1,"real Space freezes lip contact with no premature swallow or dose consumption")
 await capture("02_actual_lip_contact_paused");var initial_zoom:int=app.zoom_index;await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_UP);await space_key()
 check(app.zoom_index>initial_zoom and app.rules.sp==80,"actual running-time wheel magnifies the unfinished cup sequence without changing effect timing")
 await capture("03_cup_contact_zoomed");await space_key()
 check(await wait_until(func():return app.street.medicine.state().dose=="pouring",1),"ordinary tilt sends the one real dose out of the cup")
 await space_key();clock=app.street.data.clock;await frames(8)
 check(app.rules.sp==80 and a.portions==0 and app.paused_manual and is_equal_approx(clock,float(app.street.data.clock)),"paused actual pouring is separate from swallowing and cannot refill the cup")
 await capture("04_poured_not_swallowed_paused");await space_key();await pointer_key(MOUSE_BUTTON_WHEEL_DOWN)
 check(app.zoom_index==initial_zoom,"real wheel restores original view scale during the same physical sequence")
 check(await wait_until(func():return app.street.medicine.state().dose=="swallowed",1),"ordinary mouth sequence completes one actual swallow")
 check(app.rules.sp==60 and app.rules.hp==100 and app.rules.stun_left>0 and not app.rules.gripped,"real swallow alone pays original twenty SP, pauses1.5s and immediately releases head")
 await capture("05_actual_swallow_withdrawal")
 check(await wait_until(func():return a.phase=="idle",1),"same nurse withdraws hands and empty cup through original recovery")
 var count:int=count_fact("street_medicine_swallowed");await frames(14)
 check(a.portions==0 and app.rules.sp==60 and count==1 and count_fact("street_medicine_swallowed")==count,"empty cup and completed physical event cannot repeat the oral effect")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"One explicit nurse/host/full cup scene with actual paid CONTROL; ordinary process approach/head grip/other-hand cup/lip contact/pour/actual swallow/SP-only1.5s pause/release/recovery, actual Space and wheel. No attack/hit/hold/pour/effect/knowledge fields filled. Silent fixed30 placeholders, not full natural crowd/human/art/audio acceptance."},"  "));file.close()
 print("STREET_MEDICINE_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
