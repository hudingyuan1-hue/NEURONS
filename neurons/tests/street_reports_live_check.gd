extends "res://tests/street_materials_live_check.gd"
func knocks() -> int:
 var count:int=0
 for fact in app.rules.facts:
  if fact.kind=="street_board_knocked":count+=1
 return count
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_reports_20261018/live"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street实际敲板与接收响应";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var head:Dictionary=place("head_nurse",Vector2(4,4.3));head.report_left=0.0
 var receiver:Dictionary=place("warder",Vector2(6,4.3));receiver.cooldown=5.0;receiver.direction=[1,0]
 app.hero_pos=Vector2(3,5);check(takeover(),"one declared cast/position/cooldown fixture uses an actually paid CONTROL window")
 app.input_lock_frames=0;app.paused_manual=false;app.set_process(true);await frames(2)
 check(head.phase=="board_raise" and knocks()==0,"ordinary process raises the board without pre-playing contact sound")
 await space_key();var elapsed:float=head.report_elapsed;await frames(12)
 check(app.paused_manual and is_equal_approx(elapsed,head.report_elapsed) and knocks()==0,"real Space freezes preparation before the actual knock")
 await capture("01_raise_before_knock_paused");await space_key()
 check(await wait_until(func():return head.phase=="board_knock",1),"real resume reaches actual board contact")
 check(knocks()==1 and receiver.get("investigation",{}).is_empty(),"one actual knock is not already a received location")
 await capture("02_board_contact")
 check(await wait_until(func():return head.phase=="point",1),"ordinary clock proceeds from contact into pointing")
 await capture("03_pointing_original_position")
 check(await wait_until(func():return app.street.data.report_looks.has("warder") and float(app.street.data.report_looks.warder.progress)>.05,1),"real receiving actor begins an independent visible head turn")
 await space_key();var look:Dictionary=app.street.data.report_looks.get("warder",{});elapsed=float(look.get("elapsed",-1));await frames(12)
 check(app.paused_manual and not look.is_empty() and is_equal_approx(elapsed,float(look.elapsed)),"real pause freezes the partially executed response")
 check(app.street.materials.known("street_head_report_response"),"actual visible turn following this actual pointing produces the limited recognition")
 await capture("04_actual_head_response_paused");await space_key()
 check(await wait_until(func():return not app.street.data.report_looks.has("warder"),1),"resuming finishes the one visible response without a queued duplicate")
 check(knocks()==1 and app.dialogue_queue.is_empty(),"ongoing actual hostility suppresses retrospective speech and cannot replay the knock")
 await capture("05_response_complete")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"One declared room/cast/position/initial-five-second-receiver-cooldown fixture with actually paid CONTROL. Thereafter ordinary _process, real Space pause/resume, actual board/point/head/recognition; no report/hearing/knowledge flags filled. Silent fixed30; original retrospective safe-gap line separately finite-tested; not natural all-cast/human art/audio acceptance."},"  "));file.close()
 if not failures.is_empty():
  file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(app.snapshot_data(),"  "));file.close()
 print("STREET_REPORTS_LIVE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
