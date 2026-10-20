extends "res://tests/street_belt_check.gd"
## Declared cast/forearm/obstacle fixtures; real original attack, costs and JSON.
func hand_scene(id:String,offset:Vector2=Vector2(1.05,0),heading:Vector2=Vector2.RIGHT) -> Dictionary:
 if app.room_id!="street_twisted":app.enter_room("street_twisted")
 embrace_scene(offset,heading);app.street.data.actors.isolation.present=false;app.street.data.erase("hand_grips");app.street.data.ending={};app.street.data.boundary=false
 app.street.materials.state().stitched.tear=float(app.street.config.test_parameters.paper_tear_s)
 var a:Dictionary=actor_at(id,Vector2(4,4));a.hp=60;a.direction=app.street.xy(heading);a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_hand_grip:"+id+":"+str(passes.size()+failures.size());app.hero_facing=heading;app.street.hand_grips.sync(id);return a

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_hand_grips_20261019/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="四种真实腕臂合拢与释放";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 for id:String in app.street.HandGrips.IDS:
  var a:Dictionary=hand_scene(id);var owners:Dictionary=app.rules.owners.duplicate(true);var facts:Array=app.rules.institutional_records.duplicate(true);var pos:Vector2=app.hero_pos
  step(.8)
  check(a.phase=="attack" and app.rules.hp==100 and not app.rules.gripped,id+" original .8 preparation opens attached fingers/jaws without injury")
  step(.225)
  check(app.rules.hp==100 and not app.rules.gripped and app.street.hand_grips.state(id).open>.2,id+" visibly incomplete closure cannot settle a body-box graze")
  await capture(id+"_01_open_not_contact");step(.075)
  check(app.rules.hp==90 and app.rules.sp==80 and app.rules.gripped and app.street.data.holder==id,id+" true forearm enclosure commits original10HP/0SP once and one holder")
  check(app.hero_pos.is_equal_approx(pos) and app.rules.owners==owners and app.rules.institutional_records==facts,id+" closure neither teleports body nor steals evidence or creates a record")
  var receipt:String=a.attack_id;var deadline:float=app.street.data.grip_until;var clock:float=app.street.data.clock
  check(disk() and app.street.data.holder==id and app.rules.settled.has(receipt),id+" real JSON preserves actual closed hand, sole owner and original receipt")
  a=app.street.data.actors[id];var hands:Array=app.street.hand_grips.state(id).hands.duplicate(true);app._process(.5)
  check(app.street.hand_grips.state(id).hands==hands and is_equal_approx(clock,float(app.street.data.clock)) and app.rules.hp==90,id+" manual pause freezes physical hand and original deadline without recharging")
  app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(.1)
  check(app.rules.gripped and app.street.data.holder==id and app.rules.hp==90,id+" withdrawal after actual closure cannot undo established hold")
  await capture(id+"_02_closed_hold");step(deadline-float(app.street.data.clock)+.025)
  check(not app.rules.gripped and app.street.data.holder=="" and a.phase=="recover" and app.rules.hp==90,id+" original1.2 deadline opens same hand without extra injury")
  step(.65)
  check(a.phase=="idle" and a.cooldown>1.3 and app.street.hand_grips.state(id).open==1,id+" complete .6 recovery restores open hand before original1.5 cooldown")
  for offset:Vector2 in [Vector2(.55,0),Vector2(1.05,.55),Vector2(-.3,0),Vector2(1.55,0)]:
   a=hand_scene(id,offset);step(1.15)
   check(app.rules.hp==100 and not app.rules.gripped,id+" actual wrist miss gives no rectangular body hit "+str(offset))
  a=hand_scene(id);app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(1.15)
  check(app.rules.hp==100 and not app.rules.gripped,id+" timely original withdrawal physically retracts candidate forearms before closure")
  a=hand_scene(id);app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.1)
  check(app.rules.hp==90 and app.rules.gripped,id+" chest duck does not erase an actually reachable forearm")
  a=hand_scene(id);app.layout.furniture.append({"id":"declared_hand_wall","name":"实际挡手柜","rect":Rect2(4.6,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(1.15)
  var s:Dictionary=app.street.hand_grips.state(id);var stopped:bool=true
  for hand:Array in s.hands:stopped=stopped and app.street.vector(hand).x<4.6
  check(app.rules.hp==100 and not app.rules.gripped and true in s.blocked and stopped,id+" actual cabinet stops attached fingers/jaws at near side without wall grip")
  a=hand_scene(id);step(.8);app.street.damage_actor("father",id,15,"declared_prepare_hurt:"+id);step(.35)
  check(app.rules.hp==100 and not app.rules.gripped,id+" real injury before closure cancels unpaid grab")
  a=hand_scene(id);step(1.1);app.street.damage_actor("father",id,15,"declared_holder_hurt:"+id)
  check(not app.rules.gripped and app.street.data.holder=="" and app.rules.hp==90,id+" real holder injury releases immediately without refund")
  a=hand_scene(id);step(1.1);app.street.damage_actor("father",id,100,"declared_holder_death:"+id)
  check(a.hp==0 and not app.rules.gripped and app.street.data.holder=="",id+" actual holder death leaves no invisible restraint")
  a=hand_scene(id);step(1.1);a.present=false;app.street._actor(id,.025)
  check(not app.rules.gripped and app.street.data.holder=="",id+" absent holder releases only its own hold")
  a=hand_scene(id);step(1.1);a.room="street_plaza";app.street._actor(id,.025)
  check(not app.rules.gripped and app.room_id=="street_twisted",id+" cross-room hold cannot transport or remotely fix host")
  a=hand_scene(id);step(1.1);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("hand_grips");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.05)
  check(app.rules.hp==90 and app.rules.gripped and app.street.data.holder==id,id+" valid legacy forearm hold rebuilds locally without replaying injury")
  a=hand_scene(id);step(1.1);saved=app.snapshot_data();saved.street_state.erase("hand_grips");saved.hero_pos=[7.5,4];app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.05)
  check(app.rules.hp==90 and not app.rules.gripped and app.hero_pos.distance_to(Vector2(7.5,4))<.01,id+" inconsistent legacy long-range hold releases in place without pulling host back")
  a=hand_scene(id);step(1.1);app.layout.furniture.append({"id":"declared_new_arm_wall","name":"实际进入持握手臂的新障碍","rect":Rect2(4.6,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(.025)
  check(not app.rules.gripped and app.rules.hp==90,id+" new obstruction breaks actual arm geometry without cancelling prior damage")
  for heading:Vector2 in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
   a=hand_scene(id,heading*1.05,heading);step(1.1)
   check(app.rules.hp==90 and app.street.data.holder==id,id+" exact attached forearm closure rotates with fixed attack "+str(heading))
  a=hand_scene(id);var envelope:bool=true
  for index in range(app.street.hand_grips.hand_sides(id).size()):
   for n in range(101):
    var offset:Vector2=app.street.hand_grips.hand_goal(id,index,float(n)/100)-app.street.position(id)
    envelope=envelope and offset.length()+app.street.hand_grips.outer_radius(id)<=1.20001 and absf(offset.y)+app.street.hand_grips.outer_radius(id)<=.40001
  check(envelope,id+" every actual finger/jaw pose stays inside original1.2m/.4m attack envelope")
 var a:Dictionary=hand_scene("supervisor");app.layout.furniture.append({"id":"declared_one_jaw_block","name":"只挡一侧夹具","rect":Rect2(4.6,3.65,.1,.12),"height":120});app.layout.rebuild_grid();step(1.1)
 var s:Dictionary=app.street.hand_grips.state("supervisor")
 check(app.rules.hp==90 and app.street.data.holder=="supervisor" and true in s.blocked and false in s.blocked,"one real free clamp can capture one forearm; blocked companion cannot double-charge or add second holder")
 a=hand_scene("supervisor");step(1.1);a.pos=[6.1,4];a.direction=[-1,0];app.street.hand_grips.sync("supervisor")
 var second:Dictionary=actor_at("archivist",Vector2(4,4));second.hp=60;second.direction=[1,0];second.phase="windup";second.elapsed=0;second.cooldown=0;second.hits={};second.attack_id="declared_second_gripper";app.street.hand_grips.sync("archivist");step(1.1)
 check(app.street.data.holder=="supervisor" and app.rules.hp==90 and not second.hits.has("hero"),"second real prepared gripper cannot steal a valid existing actual clamp or charge another hit")
 app.street.damage_actor("father","archivist",15,"declared_nonowner_grip_hurt")
 check(app.street.data.holder=="supervisor" and app.rules.gripped,"injuring non-owner fingers never releases another identity's physical clamp")
 a=hand_scene("archivist",Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body();step(.5)
 check(a.hp==45 and app.rules.hp==100 and a.phase not in ["windup","attack"],"actually paid CONTROL and legal knee hit cancels unfinished archivist fingers")
 a=hand_scene("stitched");a.phase="idle";app.street.materials.state().stitched.tear=0.0;step(.6)
 var partial:float=app.street.materials.state().stitched.tear;app.street.damage_actor("father","stitched",15,"declared_original_paper_interrupted");step(.2)
 check(partial>.5 and is_equal_approx(partial,float(app.street.materials.state().stitched.tear)) and app.rules.hp==100,"existing stitched paper tearing retains real partial progress while hurt, without early grab")
 step(.9);var done:float=app.street.materials.state().stitched.tear;step(2)
 print("HAND_GRIP_PAPER_PROGRESS ",JSON.stringify({"partial":partial,"done_before_later_attack":done,"after_later_attack":app.street.materials.state().stitched.tear,"duration":app.street.config.test_parameters.paper_tear_s}))
 check(done+.000001>=float(app.street.config.test_parameters.paper_tear_s) and is_equal_approx(float(app.street.materials.state().stitched.tear),done),"existing paper completes remaining portion once and is not regenerated for later grabs")
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Four explicitly placed forearm/cast fixtures, original attack timing/damage, exact attached geometry, real paid CONTROL/knee, JSON/pause/legacy/interruption and existing stitched paper progress. No all-crowd/human balance/formal animation approval."},"  "));file.close()
 print("STREET_HAND_GRIPS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
