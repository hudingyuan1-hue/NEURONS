extends "res://tests/street_materials_check.gd"
func reset_signal() -> Array:
 no_street();app.street.data.report_events={};app.street.data.report_looks={};app.street.data.report_speech={};app.street.data.reports={}
 app.rules.end_control();app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.effects.clear();app.hero_pos=Vector2(3,5)
 app.layout.furniture.clear();app.layout.rebuild_grid()
 var head:Dictionary=actor_at("head_nurse",Vector2(4,4));head.report_left=0.0;head.report_serial=0;head.signal_serial=0;head.report_event="";head.report_target=[];head.report_elapsed=0.0
 head.report_side_left=0.0;head.report_side_goal=[];head.report_hurt_seen=false
 var receiver:Dictionary=actor_at("warder",Vector2(5.5,5));receiver.cooldown=2;receiver.investigation={};receiver.direction=[1,0];receiver.last_seen=[]
 return [head,receiver]
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_reports_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street敲板与实际响应验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var signals=app.street.report_signals;var cast:Array=reset_signal();var head:Dictionary=cast[0];var receiver:Dictionary=cast[1]
 receiver.present=false;var knocks:int=count_fact("street_board_knocked")
 advance_actor("head_nurse",1.2)
 check(head.report_target.is_empty() and count_fact("street_board_knocked")==knocks,"no actual recipient starts no phantom signal or knock")
 receiver.present=true;advance_actor("head_nurse",.2)
 check(head.phase=="board_raise" and count_fact("street_board_knocked")==knocks and receiver.investigation.is_empty(),"raising the board is visible preparation, not sound or delivered information")
 await capture("01_before_actual_knock")
 head.hurt=.2;advance_actor("head_nurse",.1)
 check(head.report_target.is_empty() and count_fact("street_board_knocked")==knocks,"hurt before board contact cannot backfill a knock")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.275)
 var receipt:String=head.report_event;var event:Dictionary=app.street.data.report_events[receipt]
 check(count_fact("street_board_knocked")==knocks+1 and event.heard.has("warder") and receiver.investigation.is_empty(),"actual contact makes exactly one local audible knock before any pointing receipt")
 advance_actor("head_nurse",.05)
 check(count_fact("street_board_knocked")==knocks+1,"the same board contact cannot repeat its sound")
 head.hurt=.2;advance_actor("head_nurse",.1);signals.tick(.1)
 check(receiver.investigation.is_empty() and not event.delivered and not known_id("street_head_report_response"),"heard knock without completed pointing does not grant a location or protagonist recognition")

 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.3)
 var late:Dictionary=actor_at("transporter_hospital",Vector2(5.5,6));late.investigation={};advance_actor("head_nurse",.75)
 check(app.street.data.reports.head_nurse.receivers==["warder"] and late.investigation.is_empty(),"recipient arriving after the actual knock cannot be retroactively told it heard it")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.3)
 app.layout.furniture.append({"id":"fixture_wall","name":"明确视线夹具","height":90,"rect":Rect2(4.75,3.8,.1,2.7)});app.layout.rebuild_grid();advance_actor("head_nurse",.75)
 check(receiver.investigation.is_empty() and app.street.data.reports.head_nurse.receivers.is_empty(),"heard sound but actually blocked pointing supplies no position")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.3);receiver.room="street_side";advance_actor("head_nurse",.75)
 check(receiver.investigation.is_empty() and not app.street.data.report_looks.has("warder"),"recipient that actually leaves before pointing receives no remote location or queued response")

 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.45);var reported:Array=head.report_target.duplicate()
 app.hero_pos=Vector2(2.5,5);advance_actor("head_nurse",.6);receipt=app.street.data.reports.head_nurse.receipt;event=app.street.data.report_events[receipt]
 check(receiver.investigation.receipt==receipt and receiver.investigation.at==reported and app.street.vector(reported).distance_to(app.hero_pos)>.4,"only this actual gesture's frozen original point is delivered, with a unique receipt")
 check(not known_id("street_head_report_response") and event.responded.is_empty(),"received location alone is not a witnessed physical response")
 var hp:int=app.rules.hp;var sp:int=app.rules.sp;var neurons:int=app.rules.neurons;var evidence:int=app.rules.evidence.size();var direction:Array=receiver.direction.duplicate();var cooldown:float=receiver.cooldown
 signals.tick(.01)
 check(not known_id("street_head_report_response") and app.street.data.report_looks.has("warder"),"initial sub-threshold head motion is not already a seen turn")
 var elapsed:float=app.street.data.report_looks.warder.elapsed;app._process(.5)
 check(is_equal_approx(elapsed,app.street.data.report_looks.warder.elapsed),"manual pause freezes the partially executed response")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()));var knock_count:int=count_fact("street_board_knocked")
 check(app.restore_snapshot(snapshot),"partial head response restores through actual campaign JSON")
 app.set_process(false);app.paused_manual=true;clear_lines();signals=app.street.report_signals;receiver=app.street.data.actors.warder;head=app.street.data.actors.head_nurse;event=app.street.data.report_events[receipt]
 signals.tick(.06)
 check(known_id("street_head_report_response") and event.response_seen and event.responded.has("warder"),"actual visible head turn after this witnessed pointing grants only the limited recognition")
 check(app.street.vector(receiver.direction).is_equal_approx(app.street.vector(direction)) and is_equal_approx(receiver.cooldown,cooldown) and receiver.phase=="idle","independent glance does not change physical attack direction, cooldown or body action")
 check(count_fact("street_board_knocked")==knock_count and app.rules.hp==hp and app.rules.sp==sp and app.rules.neurons==neurons and app.rules.evidence.size()==evidence,"restoring/observing a response repeats no knock, cost, damage or fourth-wall evidence")
 check(app.dialogue_queue.is_empty(),"actual hostile pursuit defers the original recognition line")
 await capture("02_actual_partial_head_response")
 app.hero_pos=Vector2(13,9);signals.tick(.03)
 check(not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text=="她在指我的位置。","safe gap dispatches the original line only after actual signal and seen response")
 clear_lines();signals.tick(.1);check(app.dialogue_queue.is_empty(),"same witnessed report cannot repeat the original recognition line")

 # A new actor fixture cannot retroactively create a response for an attack.
 app.rules.observations=app.rules.observations.filter(func(o):return o.id!="street_head_report_response")
 cast=reset_signal();head=cast[0];receiver=cast[1];receiver.phase="windup";receiver.elapsed=.3;receiver.attack_id="declared:already_started";receiver.hits={"hero":true}
 direction=receiver.direction.duplicate();cooldown=receiver.cooldown;advance_actor("head_nurse",1.05);signals.tick(.5)
 check(not receiver.investigation.is_empty() and receiver.phase=="windup" and is_equal_approx(receiver.elapsed,.3) and receiver.hits.has("hero"),"actual already-launched attack keeps its phase/time/hit receipt while receiving old information")
 check(not app.street.data.report_looks.has("warder") and app.street.vector(receiver.direction).is_equal_approx(app.street.vector(direction)) and is_equal_approx(receiver.cooldown,cooldown),"signal cannot reset or rotate an active attack to manufacture a response")
 receiver.phase="idle";signals.tick(.5)
 check(not known_id("street_head_report_response") and not app.street.data.report_looks.has("warder"),"finished attack cannot replay a discarded late glance")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",1.05);receiver.hurt=.2;signals.tick(.1);receiver.hurt=0;signals.tick(.5)
 check(not known_id("street_head_report_response") and app.street.data.report_looks.is_empty(),"hurt cancels an unobserved response without post-injury queued replay")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",1.05);receiver.hp=0;signals.tick(.1)
 check(not known_id("street_head_report_response") and app.street.data.report_looks.is_empty(),"dead recipient cannot finish a response or grant recognition")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",1.05)
 app.layout.furniture.append({"id":"fixture_eye_wall","name":"明确宿主视线夹具","height":90,"rect":Rect2(3.7,4.4,.1,2)});app.layout.rebuild_grid();signals.tick(.2)
 check(not known_id("street_head_report_response"),"actual occlusion prevents recognition even when the remote response physically happens")

 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.275)
 snapshot=JSON.parse_string(JSON.stringify(app.snapshot_data()));knock_count=count_fact("street_board_knocked")
 check(app.restore_snapshot(snapshot),"actual already-knocked unfinished gesture restores")
 app.set_process(false);app.paused_manual=true;clear_lines();advance_actor("head_nurse",.8)
 check(count_fact("street_board_knocked")==knock_count and not app.street.data.actors.warder.investigation.is_empty(),"resume finishes only remaining pointing without replaying an already heard knock")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",1.0)
 var old_pos:Vector2=app.street.position("head_nurse");receipt=app.street.data.reports.head_nurse.receipt;knock_count=count_fact("street_board_knocked")
 advance_actor("head_nurse",.15)
 check(app.street.position("head_nurse").y<old_pos.y-.05 and head.phase=="report_side" and receiver.investigation.receipt==receipt,"completed original report is followed by real side adjustment without revoking received information")
 var side_left:float=head.report_side_left;old_pos=app.street.position("head_nurse");app._process(.5)
 check(is_equal_approx(side_left,float(head.report_side_left)) and old_pos.is_equal_approx(app.street.position("head_nurse")),"real manual pause freezes partial side movement")
 check(app.store.save_snapshot(app.snapshot_data()).ok,"partial report side adjustment writes real disk save")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data),"real disk restores the same remaining retreat rather than resetting the report")
 head=app.street.data.actors.head_nurse;advance_actor("head_nurse",.5)
 check(head.phase=="idle" and head.report_side_left<=0 and head.report_left>7 and count_fact("street_board_knocked")==knock_count,"resumed finite adjustment completes without replaying knock or refreshing original cooldown")
 cast=reset_signal();head=cast[0];receiver=cast[1];advance_actor("head_nurse",.2);old_pos=app.street.position("head_nurse")
 app.street.damage_actor("warder","head_nurse",15,"declared_source_hurt:head");advance_actor("head_nurse",.2)
 check(old_pos.is_equal_approx(app.street.position("head_nurse")) and head.report_target.is_empty() and receiver.investigation.is_empty(),"real damage cancels unfinished report and actual hurt prevents sliding away during the hit")
 advance_actor("head_nurse",.2)
 check(app.street.position("head_nurse").y<old_pos.y-.04 and head.phase=="report_retreat" and receiver.investigation.is_empty(),"after actual hurt the reporter physically retreats instead of resuming interrupted pointing")
 head.hp=0;old_pos=app.street.position("head_nurse");advance_actor("head_nurse",1)
 check(old_pos.is_equal_approx(app.street.position("head_nurse")),"dead reporter cannot finish side retreat or start another signal")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Explicit clear-floor, actor/position/cooldown, wall, late-arrival, launched-attack and safe-gap fixtures. Production knock/hearing/point/received-location/visible head response, actual pause and JSON. No perceptual FOV, damage, probability or attack rule changes. Not natural all-cast/human art/audio acceptance."},"  "));file.close()
 print("STREET_REPORTS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
