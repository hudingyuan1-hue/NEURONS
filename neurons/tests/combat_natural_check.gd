extends "res://tests/opening_campaign_check.gd"
## Only the L5 entry is selected. No actor/seed/route/resource fixtures follow.

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/feedback_20261017/combat_natural"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 await frontend.show_profile();frontend.name_field.text="第五关自然自主观察";frontend.overwrite_armed=true;frontend.new_game()
 await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 app.unlock_combat()
 var visits:Array=[];var observed:Array=[];var elapsed:float=0.0;var still:float=0.0
 var last:Vector2=app.hero_pos;var previous:String=app.room_id;var next_capture:float=0.0
 while elapsed<300.0 and not app.combat.data.boundary:
  await get_tree().process_frame
  var delta:float=get_process_delta_time();elapsed+=delta
  if not app.room_id in visits:
   visits.append(app.room_id);await capture("room_%02d_%s"%[visits.size(),app.room_id])
  for id in app.combat.data.actors:
   if app.combat.data.actors[id].present and not id in observed:observed.append(id)
  if app.room_id==previous and app.hero_pos.distance_to(last)<.0001 and not app.rules.body_busy() and not app.rules.gripped and not app.world_paused():still+=delta
  else:still=0.0
  if elapsed>=next_capture:
   next_capture+=15.0
   print("COMBAT_NATURAL %.1fs room=%s hp=%d attempt=%d pos=%s"%[elapsed,app.room_id,app.rules.hp,app.rules.actual_attempt,app.hero_pos])
  if still>15.0:break
  last=app.hero_pos;previous=app.room_id
 check(app.combat.data.boundary,"natural NPC rolls and autonomous host reach actual L5 exit")
 check(still<=15.0,"no fifteen-second unexplained autonomous stall")
 check(app.rules.search_attempts==0 and app.session.data.level==6,"L5 naturally reaches real Street entry without resuming key search")
 check(app.audio.assets.has("MUS_DANGER") and str(app.audio.channels.music[0].get_meta("cue_id",""))=="MUS_DANGER","actual combat scene selects supplied danger music stream")
 if not app.combat.data.boundary:
  var snapshot:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("unmodified_stall_snapshot.json"),FileAccess.WRITE)
  snapshot.store_string(JSON.stringify(app.snapshot_data(),"  "));snapshot.close()
 await capture("final")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"ordinary _process after declared direct L5 entry; no RNG seed, NPC, resources, positions, routes, damage or success fixtures after entry; accelerated fixed30 automated window, not human full game or all combinations","elapsed_game_seconds":elapsed,"visited":visits,"observed_actor_ids":observed,"attempt":app.rules.actual_attempt,"hp":app.rules.hp,"boundary":app.combat.data.boundary},"  "));f.close()
 print("COMBAT_NATURAL_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
