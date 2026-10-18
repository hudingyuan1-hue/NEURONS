extends "res://tests/street_belt_check.gd"
## Explicit wrist/blocker/owner fixtures. Real shared contact then paired physical movement.
func grasp_scene(id:String="psychiatrist",offset:Vector2=Vector2(1.05,0),heading:Vector2=Vector2.RIGHT) -> Dictionary:
 var room:String="street_node" if id=="psychiatrist" else "street_end"
 if app.room_id!=room:app.enter_room(room)
 belt_scene(offset,heading);app.street.data.actors.warder.present=false;app.street.data.erase("grasp_motion");app.street.data.grip_until=0;app.street.data.ending={};app.street.data.boundary=false
 var a:Dictionary=actor_at(id,Vector2(4,4));a.hp=60;a.direction=app.street.xy(heading);a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_grasp:"+id+":"+str(passes.size()+failures.size());app.hero_facing=heading;app.street.grasp_motion.sync(id);return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_grasp_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际抓腕连续拖推与释放验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=grasp_scene();var origin:Vector2=app.hero_pos;var carrier:Vector2=app.street.position("psychiatrist");step(.8)
 check(a.phase=="attack" and app.rules.hp==100 and not app.rules.gripped,"full original preparation raises clasp without damage, fixation or displacement")
 step(.2)
 check(app.rules.hp==100 and not app.rules.gripped and app.hero_pos.is_equal_approx(origin),"actual extending hand has not yet closed on forearm")
 await capture("01_actual_clasp_before_contact");step(.1)
 check(app.rules.hp==90 and app.rules.sp==80 and app.rules.gripped and app.street.data.holder=="psychiatrist","true closed clasp on forearm commits original ten HP and no SP once")
 check(app.hero_pos.is_equal_approx(origin) and app.street.position("psychiatrist").is_equal_approx(carrier),"contact itself does not teleport host or carrier one metre")
 var receipt:String=a.attack_id;step(.125);var moved:Vector2=app.hero_pos;var m:Dictionary=app.street.grasp_motion.state("psychiatrist").motion
 check(moved.x<origin.x and moved.distance_to(origin)<.13 and (app.street.position("psychiatrist")-carrier).is_equal_approx(moved-origin),"each ordinary pull step moves host and carrier together at existing actor speed")
 var distance:float=m.distance;var clock:float=app.street.data.clock;var deadline:float=app.street.data.grip_until
 check(disk() and app.street.data.holder=="psychiatrist" and app.rules.settled.has(receipt),"real JSON stores sole holder, paid injury and actual partial distance")
 a=app.street.data.actors.psychiatrist;app._process(.8)
 check(app.hero_pos.is_equal_approx(moved) and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(distance,float(app.street.grasp_motion.state("psychiatrist").motion.distance)),"manual pause freezes actual two-body movement after disk restore")
 await capture("02_actual_partial_pull_paused");app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(.1)
 check(app.rules.gripped and app.hero_pos.x<moved.x and app.rules.hp==90,"withdraw after established clasp cannot retroactively undo physical hold")
 var bounded:bool=true
 for i in range(55):
  var old:Vector2=app.hero_pos;var old_body:Vector2=app.street.position("psychiatrist");step(.025)
  if app.street.data.holder=="psychiatrist":bounded=bounded and old.distance_to(app.hero_pos)<=.022501 and old_body.distance_to(app.street.position("psychiatrist"))<=.022501
 check(bounded and origin.distance_to(app.hero_pos)<=1.00001 and not app.rules.gripped and app.street.data.holder=="","continuous paired pull is bounded by original one metre and1.2s deadline, then releases")
 check(app.rules.hp==90 and app.rules.sp==80 and app.street.data.grip_until<=deadline,"moving/releasing/recovery cannot add another contact charge or extend deadline")
 await capture("03_actual_pull_released")
 a=grasp_scene("guard_hospital");origin=app.hero_pos;var owners:Dictionary=app.rules.owners.duplicate(true);var records:Array=app.rules.institutional_records.duplicate(true);step(1.1)
 check(app.rules.hp==90 and app.rules.sp==70 and app.street.data.holder=="guard_hospital" and app.hero_pos.is_equal_approx(origin),"guard actual stable wrist commits original ten/ten before any push")
 step(.1)
 check(app.hero_pos.is_equal_approx(origin) and app.street.grasp_motion.state("guard_hospital").phase=="turn_inward","guard actually turns before translating instead of contact-time teleport")
 step(.2)
 check(app.hero_pos.x<origin.x and origin.distance_to(app.hero_pos)<.3,"guard pushes toward real gate's interior even when original grab faced toward exit")
 await capture("04_actual_guard_inward_push");step(1.2)
 check(not app.rules.gripped and origin.distance_to(app.hero_pos)<=1.00001 and app.rules.hp==90 and app.rules.sp==70,"guard bounded physical push releases without extra HP/SP or endless fixation")
 check(app.rules.owners==owners and app.rules.institutional_records==records,"embedded guard key and doctor label do not create inventory, hospital records or new story facts")
 for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  a=grasp_scene("psychiatrist",d*1.05,d);origin=app.hero_pos;step(1.2)
  check(app.rules.hp==90 and app.street.data.holder=="psychiatrist" and (app.hero_pos-origin).dot(-d)>0,"actual closed wrist pulls along original backward heading "+str(d))
 for offset in [Vector2(.5,.5),Vector2(-.3,0),Vector2(1.5,0)]:
  a=grasp_scene("psychiatrist",offset);origin=app.hero_pos;step(1.15)
  check(app.rules.hp==100 and not app.rules.gripped and app.hero_pos.is_equal_approx(origin),"side/rear/far hand miss never starts movement "+str(offset))
 a=grasp_scene();app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(1.15)
 check(app.rules.hp==100 and not app.rules.gripped,"original timely arm withdrawal avoids an unestablished clasp")
 a=grasp_scene();app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.1)
 check(app.rules.hp==90 and app.rules.gripped,"chest duck does not remove a forearm that actually enters clasp")
 a=grasp_scene();app.layout.furniture.append({"id":"declared_clasp_cabinet","name":"实际挡扣柜体","rect":Rect2(4.6,3.3,.12,1.4),"height":120});app.layout.rebuild_grid();step(1.15)
 check(app.street.grasp_motion.state("psychiatrist").blocked and app.rules.hp==100 and not app.rules.gripped,"real cabinet stops hand before a far-side wrist, without remote grip")
 a=grasp_scene();step(1.1);origin=app.hero_pos;app.layout.furniture.append({"id":"declared_drag_wall","name":"真实拖行后方墙","rect":Rect2(3.45,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(.6)
 check(not app.rules.gripped and app.street.grasp_motion.state("psychiatrist").motion.blocked and origin.distance_to(app.hero_pos)<.3 and app.street.position("psychiatrist").x>3.76,"carrier's blocked rear path stops both bodies and releases at actual accepted side")
 await capture("05_actual_drag_stopped_by_wall")
 a=grasp_scene("guard_hospital");step(1.1);origin=app.hero_pos;app.layout.furniture.append({"id":"declared_push_wall","name":"推离中的实体栏杆","rect":Rect2(4.6,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(.7)
 check(not app.rules.gripped and app.street.grasp_motion.state("guard_hospital").motion.blocked and app.hero_pos.x>4.91 and origin.distance_to(app.hero_pos)<.2,"host's newly blocked push path stops pair instead of clipping host through railing")
 a=grasp_scene();step(1.1);origin=app.hero_pos;carrier=app.street.position("psychiatrist");app.layout.furniture.append({"id":"declared_grasp_arm_blocker","name":"实际进入持握手臂的实体","rect":Rect2(4.6,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(.025)
 check(not app.rules.gripped and origin.is_equal_approx(app.hero_pos) and carrier.is_equal_approx(app.street.position("psychiatrist")) and app.rules.hp==90,"new solid object interrupting established arm stops before either clear-footed body moves through it")
 a=grasp_scene();step(1.1);var chair:Dictionary=actor_at("wheelchair",Vector2(3.3,4));chair.hp=0;step(.4)
 check(not app.rules.gripped and app.street.grasp_motion.state("psychiatrist").motion.blocked and app.rules.hp==90,"same real wheelchair remains solid after rider death and stops paired movement")
 a=grasp_scene();app.street.layouts.erase("street_node");app.room_id="";app.enter_room("street_node");var core:Rect2
 for prop in app.layout.furniture:
  if str(prop.name).contains("核心"):core=prop.rect;break
 check(core.has_area(),"actual production collapsed core exists for drag boundary verification")
 a.pos=app.street.xy(Vector2(core.end.x+.5,core.get_center().y));app.hero_pos=app.street.position("psychiatrist")+Vector2(1.05,0);app.street.grasp_motion.sync("psychiatrist");step(1.7)
 check(not app.rules.gripped and app.street.grasp_motion.state("psychiatrist").motion.blocked and app.street.position("psychiatrist").x>core.end.x+.21,"original collapsed core boundary stops real backward carrier and releases without moving either body through core")
 a=grasp_scene();step(.8);app.street.damage_actor("father","psychiatrist",15,"declared_clasp_windup_hurt");step(.35)
 check(app.rules.hp==100 and not app.rules.gripped,"actual carrier injury before closure cancels unestablished clasp")
 a=grasp_scene("psychiatrist",Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body();step(.5)
 check(a.hp==45 and app.rules.hp==100 and a.phase not in ["windup","attack"],"actual legal kick damages carrier and interrupts unfinished clasp")
 a=grasp_scene();step(1.2);origin=app.hero_pos;app.street.damage_actor("father","psychiatrist",15,"declared_holder_hurt");step(.2)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(origin) and app.rules.hp==90,"actual holder injury stops further drag and preserves already-paid injury")
 a=grasp_scene();step(1.2);origin=app.hero_pos;app.street.damage_actor("father","psychiatrist",100,"declared_holder_death");step(.2)
 check(a.hp==0 and not app.rules.gripped and app.hero_pos.is_equal_approx(origin),"dead carrier cannot retain invisible moving clasp")
 a=grasp_scene();step(1.2);a.present=false;app.street._actor("psychiatrist",.025)
 check(not app.rules.gripped and app.street.data.holder=="","absent carrier immediately releases its own hold")
 a=grasp_scene();step(1.2);a.room="street_twisted";app.street._actor("psychiatrist",.025)
 check(not app.rules.gripped and app.room_id=="street_node","invalid cross-room hold releases locally without transporting host")
 a=grasp_scene();var other:Dictionary=actor_at("isolation",Vector2(8,6));other.phase="grip";app.street.data.holder="isolation";app.street.data.grip_until=2;app.rules.gripped=true;step(1.1)
 check(app.street.data.holder=="isolation" and app.rules.hp==100 and not a.hits.has("hero"),"prepared clasp cannot steal another actual holder or charge a queued grab")
 app.street.damage_actor("father","psychiatrist",15,"declared_nonholder_hurt")
 check(app.street.data.holder=="isolation" and app.rules.gripped,"injuring non-owner clasp carrier does not release another hold")
 a=grasp_scene();step(1.2);origin=app.hero_pos;var saved:Dictionary=app.snapshot_data();saved.street_state.erase("grasp_motion");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.2)
 check(app.rules.hp==90 and app.rules.gripped and app.hero_pos.is_equal_approx(origin) and app.street.grasp_motion.state("psychiatrist").motion.legacy_static,"legacy existing injury/deadline loads as static hold without inventing a missing past trajectory")
 a=grasp_scene("guard_hospital");step(1.1);app.hero_pos+=Vector2(1,0);saved=app.snapshot_data();saved.street_state.erase("grasp_motion");saved.street_state.actors.guard_hospital.displacement_done=true;app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));origin=app.hero_pos;step(.1)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(origin) and app.rules.hp==90 and app.rules.sp==70,"legacy old one-metre teleport outside actual hand reach releases inconsistent hold without replaying movement or injury")
 a=grasp_scene();a.phase="idle";app.hero_pos=Vector2(5.7,4);step(3)
 check(app.rules.hp==90 and app.street.grasp_motion.state("psychiatrist").motion.has("distance"),"autonomous pursuit actually gets inside physical wrist reach and starts bounded movement")
 a=grasp_scene("guard_hospital");origin=app.hero_pos;app.rules.owners.erase("street_gate_key");app.hero_pos=app.layout.portal("ending_gate").threshold;app.street.exit_crossed();var end_receipt:String=app.street.data.ending.receipt;origin=app.hero_pos
 app.street._actor("guard_hospital",1.2);app.street.tick(.5)
 check(not app.street.data.ending.is_empty() and app.street.data.ending.receipt==end_receipt and app.hero_pos.is_equal_approx(origin) and app.rules.hp==100 and not app.rules.gripped,"actual committed ending accepts no new grip or push, without requiring guard defeat or embedded key")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Explicit wrist/pose/blocker/wheelchair/old-holder and valid ending threshold fixtures; actual paid CONTROL/legal knee, shared HP/SP/receipt, bounded paired movement, real JSON/manual pause/legacy and original collapsed core. Last ending uses actual exit_crossed at declared valid threshold, not natural gate approach. Not all crowds/full B6/B7 or formal character art."},"  "));file.close()
 print("STREET_GRASP_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
