extends "res://tests/street_double_head_check.gd"
## Explicit actor/body/solid fixtures; real injury and original paid legal knee.
func face_scene(at:Vector2=Vector2(4,4)) -> Dictionary:
 if app.room_id!="street_node":app.enter_room("street_node")
 embrace_scene(Vector2(.82,0));app.street.data.actors.isolation.present=false;app.street.data.erase("double_face_retreat");app.street.data.face_pending={};app.street.data.ending={};app.street.data.boundary=false
 var a:Dictionary=actor_at("double_face",at);a.hp=60;a.hostile=false;a.direction=[1,0];a.phase="idle";a.face_turned=false;a.face_turn_progress=0.0;a.follow="";a.last_seen=[];a.home=app.street.xy(at);a.route=[];a.goal=[];return a
func retreat_steps(seconds:float) -> void:
 for n in range(ceili(seconds/.025)):app.street._actor("double_face",.025)
func wound(source:String="hero",amount:int=1) -> void:app.street.damage_actor(source,"double_face",amount,"declared_retreat_hit:"+str(passes.size()+failures.size()))
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_double_face_retreat_20261019/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="双面受袭真实退避";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=face_scene();var at:Vector2=app.street.position("double_face");step(1)
 check(at.is_equal_approx(app.street.position("double_face")) and not a.hostile and app.rules.hp==100,"uninjured neutral witness does not retreat, counter or lose HP from proximity")
 check(actual_knee(),"original actually paid CONTROL permits legal player knee toward neutral double-face body")
 var pushed:Vector2=app.street.position("double_face")
 check(a.hp==45 and a.hurt>0 and not a.hostile and pushed.distance_to(at)>.7,"actual knee retains original15HP and .8m physical push without authorizing a new counter")
 step(.5)
 check(pushed.is_equal_approx(app.street.position("double_face")),"original .8s injury response finishes before any new retreat locomotion")
 check(advance_until(func():return a.phase=="display_retreat",.4),"after original injury the neutral body actually begins its bounded retreat")
 check(app.street.position("double_face").distance_to(app.hero_pos)>pushed.distance_to(app.hero_pos),"ordinary actual retreat increases distance from the frozen local contact origin")
 await capture("01_original_injury_then_actual_retreat")
 var clock:float=app.street.data.clock;at=app.street.position("double_face");var left:float=app.street.double_face_retreat.state().left
 check(disk(),"real JSON serializes ongoing retreat position, local origin and remaining time")
 a=app.street.data.actors.double_face;app._process(.7)
 check(is_equal_approx(clock,float(app.street.data.clock)) and at.is_equal_approx(app.street.position("double_face")) and is_equal_approx(left,float(app.street.double_face_retreat.state().left)),"actual pause after disk freezes the same retreat instead of consuming or replaying it")
 step(.6)
 check(is_equal_approx(float(app.street.double_face_retreat.state().distance),.425) and is_equal_approx(pushed.distance_to(app.street.position("double_face")),.425),"one existing .5s episode uses original .85m/s without teleport, duration extension or speed bonus")
 check(a.phase=="idle" and not a.hostile and not app.street.double_face_retreat.state().pending and a.hp==45 and app.rules.hp==100,"completed retreat restores neutral idle with original injury only and no counter")
 at=app.street.position("double_face");step(2)
 check(at.is_equal_approx(app.street.position("double_face")),"proximity after recovery does not queue repeated retreats or pursue the attacker")
 await capture("02_neutral_at_actual_retreat_destination")

 a=face_scene();a.face_turn_progress=.4;app.street.data.face_pending={"event":"declared_unfinished_turn","turning":true,"elapsed":.2};app.street.data.visible_casts={"already_witnessed":true};a.last_seen=[8,8];a.follow="";wound()
 check(app.street.data.face_pending.is_empty() and a.face_turn_progress==0 and app.street.data.visible_casts.has("already_witnessed"),"real injury discards unfinished head turn immediately but retains the already witnessed cast fact")
 retreat_steps(.7)
 check(not a.get("face_turned",false) and app.street.data.face_pending.is_empty() and a.last_seen==[8,8] and a.follow=="" and not a.hostile,"retreat neither replays interrupted turn nor invents target memory, following or hostility")
 a=face_scene();a.face_turned=true;a.face_turn_progress=1.0;app.street.data.visible_casts={"old_completed":true};wound();retreat_steps(.8)
 check(a.face_turned and a.face_turn_progress==1 and app.street.data.visible_casts.has("old_completed"),"a completed witnessed head turn remains true after hurt and movement")
 a=face_scene();at=app.street.position("double_face");app.street.reactions.on_skill({"success":false,"id":"PORES","event_id":"declared_resisted"});retreat_steps(1)
 check(at.is_equal_approx(app.street.position("double_face")) and not app.street.double_face_retreat.state().pending,"resisted/preview neural states and no injury do not trigger retreat")

 a=face_scene();app.layout.furniture.append({"id":"declared_retreat_wall","name":"退避实体柜体","rect":Rect2(3.65,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();wound();var legal:bool=true;var before:Vector2=app.street.position("double_face")
 for n in range(35):
  retreat_steps(.025);var now:Vector2=app.street.position("double_face");legal=legal and app.layout.walkable(now) and app.layout.clear_segment(before,now,app.layout.body_radius) and now.x>=3.96;before=now
 check(legal and float(app.street.double_face_retreat.state().distance)<=.425001,"each accepted retreat step stays on actual side of solid cabinet; blocked retreat has no bypass teleport")
 a=face_scene();actor_at("postop",Vector2(3.55,4));wound();legal=true
 for n in range(35):
  retreat_steps(.025);legal=legal and app.street.position("double_face").distance_to(app.street.position("postop"))>=.42999
 check(legal,"actual living body blocks the retreat path without overlap")
 a=face_scene();var chair:Dictionary=actor_at("wheelchair",Vector2(3.2,4));wound();legal=true
 for n in range(35):
  retreat_steps(.025);legal=legal and not app.street.bed_blocks(app.room_id,app.street.position("double_face"),app.layout.body_radius,"double_face")
 check(legal and chair.present,"complete actual wheelchair footprint is respected instead of testing only its center")
 a=face_scene();var occupied:Array=app.street.double_face_retreat.bodies();var portal:Dictionary=app.layout.portal("street_twisted");var edge:Vector2=portal.threshold
 check(not app.street.double_face_retreat.legal_step(edge+Vector2(portal.inward)*.5,edge,occupied),"short retreat cannot enter an existing portal aperture or become an unauthorized room transition")
 a=face_scene();wound();retreat_steps(.35);var first:float=app.street.double_face_retreat.state().distance;wound();at=app.street.position("double_face");retreat_steps(.15)
 check(at.is_equal_approx(app.street.position("double_face")) and is_equal_approx(float(app.street.double_face_retreat.state().left),.5),"a separate second real hit restarts injury reaction, not movement during hurt or a per-frame duration refresh")
 retreat_steps(.85)
 check(not app.street.double_face_retreat.state().pending and app.street.double_face_retreat.state().distance<=.425001 and first>0,"second injury receives one bounded episode rather than an endless per-frame retreat")
 a=face_scene();wound();retreat_steps(.15);at=app.street.position("double_face");a.present=false;retreat_steps(1)
 check(at.is_equal_approx(app.street.position("double_face")) and not app.street.double_face_retreat.state().pending,"absent body cancels retreat without queued offscreen movement")
 a=face_scene();wound();a.hp=0;at=app.street.position("double_face");retreat_steps(1)
 check(at.is_equal_approx(app.street.position("double_face")) and not app.street.double_face_retreat.state().pending,"death interrupts any pending movement and cannot counter posthumously")
 a=face_scene();wound();retreat_steps(.35);a.room="street_side";at=app.street.position("double_face");retreat_steps(1)
 check(at.is_equal_approx(app.street.position("double_face")) and not app.street.double_face_retreat.state().pending,"a different actor room cancels stale local-space origin instead of applying it across maps")
 a=face_scene();a.hurt=.25;app.street.data.erase("double_face_retreat");retreat_steps(.8)
 check(not app.street.double_face_retreat.state().pending and float(app.street.double_face_retreat.state().distance)>.2 and not a.hostile,"old JSON with actual hurt and no module reconstructs only current neutral recovery, with no damage replay")
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Explicit position/solid/body/old-snapshot fixtures. Real paid CONTROL/legal knee or named direct actual injury; original hurt first, bounded source-backed neutral retreat, physical walls/body/wheelchair/portal, JSON and pause. No new counter, source identity, timing or stats. Not human full B7 or final art."},"  "));file.close()
 print("STREET_DOUBLE_FACE_RETREAT_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
