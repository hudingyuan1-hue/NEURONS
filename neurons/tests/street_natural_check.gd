extends "res://tests/opening_campaign_check.gd"
## Direct L5 entry only. Natural NPCs, no subsequent gameplay fixtures.
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_20261017/natural"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="L5至Street自然流程";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0;app.unlock_combat()
 if "--street-entry-only" in OS.get_cmdline_user_args():app.unlock_street()
 var deadline:float=300
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--natural-limit="):deadline=float(argument.trim_prefix("--natural-limit="))
 var elapsed:float=0;var still:float=0;var last:Vector2=app.hero_pos;var previous:String=app.room_id;var visits:Array=[];var next_log:float=0
 while elapsed<deadline and app.street.data.get("ending",{}).is_empty():
  await get_tree().process_frame
  var delta:float=get_process_delta_time();elapsed+=delta
  if not app.room_id in visits:
   visits.append(app.room_id);print("STREET_VISIT ",app.room_id," hp ",app.rules.hp);await capture("visit_%02d_%s"%[visits.size(),app.room_id])
  if app.room_id==previous and app.hero_pos.distance_to(last)<.0001 and not app.rules.body_busy() and not app.rules.gripped and not app.world_paused() and app.rules.hp>0:still+=delta
  else:still=0
  if app.rules.hp<=0:
   var death_file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("latest_death.json"),FileAccess.WRITE);death_file.store_string(JSON.stringify(app.snapshot_data(),"  "));death_file.close()
  if elapsed>=next_log:
   next_log+=20;print("STREET_NATURAL %.1fs L%d %s hp%d attempts%s pos%s"%[elapsed,app.session.data.level,app.room_id,app.rules.hp,app.session.data.attempts,app.hero_pos])
  if still>15:break
  last=app.hero_pos;previous=app.room_id
 check(not app.street.data.get("ending",{}).is_empty(),"natural L5 and Street process reaches real main ending")
 check(still<=15,"no fifteen-second unexplained movement stall")
 check(app.session.data.unlocked.has(6) and app.street.data.actors.size()==45,"selected Street entry retains fixed forty-five identities" if "--street-entry-only" in OS.get_cmdline_user_args() else "real L5 doorway unlocks fixed forty-five Street identities")
 check(app.rules.search_attempts==0,"battle route never returns to key-search gameplay")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"elapsed_game_seconds":elapsed,"visits":visits,"hp":app.rules.hp,"attempts":app.session.data.attempts,"ending":app.street.data.get("ending",{}),"rendered":DisplayServer.get_name()!="headless","scope":"Declared direct L5 entry (or explicit --street-entry-only); after entry no seed/NPC/resource/position/route/damage fixtures. Fixed30 automatic real window, not human pacing or all branches."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 await capture("final")
 print("STREET_NATURAL_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
