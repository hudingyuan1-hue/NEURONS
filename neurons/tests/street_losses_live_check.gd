extends "res://tests/street_materials_live_check.gd"
## Real attack/death, declared later attacker-departure fixture, then real clamp cycle.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_losses_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street遇害反馈与腕臂扣合连续验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var father:Dictionary=place("father",Vector2(4,4));father.direction=[1,0];father.cooldown=0;father.elapsed=0
 var dog:Dictionary=place("dog",Vector2(4.5,4.1));dog.hp=60;app.hero_pos=Vector2(5,4);app.hero_facing=Vector2.RIGHT
 check(takeover(),"declared father/dog/host position fixture pays actual CONTROL without filling death or gain fields")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return dog.hp<=0,2),"ordinary autonomous father swing really hits and fragments existing guarding dog")
 check(app.street.data.speed_stacks==1 and app.street.losses.state().pending.size()==1 and app.dialogue_queue.is_empty(),"actual growth and bounded visible reaction exist immediately while hostile encounter postpones original line")
 await space_key();var left:float=app.street.losses.state().pose_left;await frames(10)
 check(app.paused_manual and is_equal_approx(left,float(app.street.losses.state().pose_left)),"real Space freezes the same loss-reaction clock")
 await capture("01_actual_dog_fragments_and_reaction")
 # Explicit departure fixture, not a natural escape claim: preserve real death,
 # receipts/knowledge/gain; only remove the attacker from this later safe gap.
 father.present=false;await space_key()
 check(await wait_until(func():return not app.dialogue_queue.is_empty(),7),"declared later attacker departure plus real CONTROL expiry lets ordinary safe-gap handler dispatch already-pending original sentence")
 check(not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text=="还没完……还没完……" and app.street.losses.state().pending.is_empty(),"actual source line acknowledges real earlier death without a second growth payout")
 await capture("02_original_madness_line")

 app.set_process(false);app.paused_manual=true;clear_lines();app.enter_room("street_narrow");no_street()
 var a:Dictionary=place("dislocated",Vector2(4,4));a.hp=60;a.cooldown=0;a.direction=[1,0];app.street.data.erase("dislocated_clamp");app.street.clamp.sync()
 app.rules.hp=100;app.rules.hurt_left=0;app.rules.stun_left=0;app.hero_pos=Vector2(4.9,4);app.hero_facing=Vector2.RIGHT;app.street.data.grip_safe_until=0
 check(takeover(),"second declared clamp/position fixture pays its own real CONTROL; no hold or damage flags filled")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true)
 check(await wait_until(func():return a.phase=="attack" and a.elapsed>=.05,2),"ordinary approach/one-shoulder preparation reaches visible open extension")
 await space_key();var elapsed:float=a.elapsed;await frames(8)
 check(app.paused_manual and is_equal_approx(elapsed,float(a.elapsed)) and app.rules.hp==100 and not app.rules.gripped,"real pause during open extension has no premature contact or grip")
 await capture("03_actual_open_forearm_clamp_paused");await space_key()
 check(await wait_until(func():return app.street.data.holder=="dislocated",1),"ordinary jaw closure establishes one real forearm holder")
 await space_key();var clock:float=app.street.data.clock;await frames(10)
 check(app.paused_manual and app.rules.hp==90 and app.rules.gripped and is_equal_approx(clock,float(app.street.data.clock)),"real paused one-arm hold preserves exactly ten HP injury and its deadline")
 await capture("04_actual_closed_forearm_hold_paused");await space_key()
 check(await wait_until(func():return a.phase=="recover" and not app.rules.gripped,2),"same real held arm opens at the original physical deadline")
 var side:int=app.street.clamp.state().side;await capture("05_same_arm_open_recovery")
 check(await wait_until(func():return a.phase=="idle",1),"ordinary full retraction finishes before side swap")
 check(int(app.street.clamp.state().side)==-side and app.rules.hp==90 and a.cooldown>1.2,"only completed recovery changes next arm, with no immediate second hit")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Two explicit NPC/position fixtures with actual paid CONTROL each; first real father contact/guarding dog death, then explicit attacker-departure safe-gap fixture (not natural escape), second real clamp closure/ten-HP/grip deadline/recovery. Ordinary _process and actual Space; second scene explicitly resets host HP. No death/gain/hold/hit/knowledge flags filled. Silent fixed30 placeholders, not human/full-game/art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_LOSSES_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
