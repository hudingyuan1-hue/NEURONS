extends "res://tests/street_director_check.gd"
## Explicit body/blocker poses; real shared processing, paid CONTROL/knee and disk.
func limb_scene(id:String,offset:Vector2=Vector2(.84,0),heading:Vector2=Vector2.RIGHT) -> Dictionary:
 director_scene(offset,heading);app.street.data.actors.director.present=false
 app.street.data.erase("mother_arms");app.street.data.erase("local_sweeps")
 var a:Dictionary=actor_at(id,Vector2(4,4));a.hp=80;a.phase="windup";a.elapsed=0;a.cooldown=0;a.direction=app.street.xy(heading);a.hits={};a.attack_id="declared_limbs:"+id+":"+str(passes.size()+failures.size())
 if id=="mother":app.street.mother.sync()
 else:app.street.local_sweeps.sync(id)
 return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_limbs_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="母亲实际夹击与局部刀路横扫验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=limb_scene("mother");var owners:Dictionary=app.rules.owners.duplicate(true);var records:Array=app.rules.institutional_records.duplicate(true);step(.8)
 check(a.phase=="attack" and app.rules.hp==100 and not app.rules.gripped,"original full mother preparation raises attached four-arm placeholder with no early injury or grip")
 step(.15)
 check(app.rules.hp==100 and not app.rules.gripped,"still-open real arms do not act as a filled rectangular damage zone")
 await capture("01_actual_mother_open");step(.1)
 check(app.rules.hp==90 and app.rules.sp==80 and not app.rules.gripped and a.hits.has("hero"),"actual near-arm impact pays original ten HP before any completed torso enclosure")
 await capture("02_actual_impact_not_yet_fixed");step(.05)
 check(app.rules.hp==90 and app.street.data.holder=="mother" and app.rules.gripped,"completed bilateral enclosure then fixes torso without a second arm charge")
 var receipt:String=a.attack_id;var clock:float=app.street.data.clock;var deadline:float=app.street.data.grip_until;var pos:Vector2=app.hero_pos;var hits:int=count_fact("combat_hit")
 check(disk() and app.rules.settled.has(receipt) and app.street.data.holder=="mother","real JSON preserves one paid impact and later sole torso holder")
 a=app.street.data.actors.mother;app._process(.5)
 check(is_equal_approx(clock,float(app.street.data.clock)) and app.hero_pos.is_equal_approx(pos),"manual pause freezes attached arms and holder after disk restore")
 await capture("03_actual_mother_fixed");app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(.1)
 check(app.rules.gripped and app.hero_pos.is_equal_approx(pos),"late withdrawal cannot erase already-enclosed torso")
 step(deadline-float(app.street.data.clock)+.025)
 check(not app.rules.gripped and a.phase=="recover" and app.rules.hp==90,"original1.2s releases same physical arms without refund or second injury")
 step(.65)
 check(a.phase=="idle" and app.street.mother.state().arms.is_empty() and count_fact("combat_hit")==hits,"full original recovery folds all arms without a reverse hit")
 check(app.rules.owners==owners and app.rules.institutional_records==records,"mother action creates no food, old collapse, institutional claim or acquired item")
 a=limb_scene("mother",Vector2(.84,.32));step(1.15)
 check(app.rules.hp==90 and not app.rules.gripped and app.street.data.holder=="","one-sided actual arm contact hurts but cannot become a torso grip")
 for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  a=limb_scene("mother",d*.84,d);step(1.1)
  check(app.rules.hp==90 and app.street.data.holder=="mother","same torso geometry respects fixed heading "+str(d))
 for skill in ["GUT","WITHDRAW"]:
  a=limb_scene("mother");app.rules.reaction_skill=skill;app.rules.reaction_left=2;step(1.1)
  check(app.rules.hp==90 and app.rules.gripped,"original "+skill+" does not automatically erase torso-level multi-arm impact")
 a=limb_scene("mother");app.layout.furniture.append({"id":"declared_mother_wall","name":"挡住真实臂路","rect":Rect2(4.46,3.4,.14,1.2),"height":120});app.layout.rebuild_grid();step(1.15)
 check(app.street.mother.state().blocked and app.rules.hp==100 and not app.rules.gripped,"solid cabinet blocks arm path before far-side body and enclosure")
 await capture("04_actual_mother_blocked")
 a=limb_scene("mother");step(1.1);app.street.damage_actor("father","mother",15,"actual_parent_hit_releases")
 check(a.hp==65 and not app.rules.gripped and app.street.data.holder=="" and app.rules.hp==90,"real parent damage releases only mother's holder and preserves paid injury")
 a=limb_scene("mother");step(1.1);app.hero_pos+=Vector2(0,.6);pos=app.hero_pos;app.street._actor("mother",.025)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(pos),"declared external displacement outside enclosure releases instead of snapping body back")
 a=limb_scene("mother");step(1.1);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("mother_arms");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.1)
 check(app.rules.hp==90 and app.street.data.holder=="mother","valid old paid grip reconstructs actual attached arms without replay")
 a=limb_scene("mother");step(1.1);app.hero_pos=Vector2(5.35,4);saved=app.snapshot_data();saved.street_state.erase("mother_arms");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));pos=app.hero_pos;step(.1)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(pos) and app.rules.hp==90,"old generic out-of-range torso hold releases locally without recharge or teleport")
 a=limb_scene("mother",Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body()
 check(a.hp==65 and app.street.mother.state().arms.is_empty(),"actual paid legal knee clears interrupted mother arms in the same contact frame")
 step(.5)
 check(app.rules.hp==100 and not app.rules.gripped,"interrupted multi-arm preparation cannot pay or grip later")
 a=limb_scene("mother");var other:Dictionary=actor_at("isolation",app.hero_pos+Vector2(.85,0));other.phase="grip";app.street.data.holder="isolation";app.street.data.grip_until=app.street.data.clock+1.2;app.rules.gripped=true;step(1.1)
 check(app.street.data.holder=="isolation" and app.rules.hp==100,"prepared mother cannot steal another sole holder or stack a reserved clamp")
 app.street.damage_actor("father","mother",100,"declared_nonholder_death")
 check(app.street.data.holder=="isolation" and app.rules.gripped,"nonholder death cannot release another person's grip")
 a=limb_scene("mother");step(1.1);a.present=false;app.street._actor("mother",.025)
 check(not app.rules.gripped and app.street.mother.state().arms.is_empty(),"absent mother leaves no independent arms behind host")
 a=limb_scene("mother");step(1.1);app.layout.furniture.append({"id":"declared_new_arm_solid","name":"新实体打断围合","rect":Rect2(4.4,3.69,.1,.12),"height":110});app.layout.rebuild_grid();step(.025)
 check(not app.rules.gripped and app.rules.hp==90,"new solid breaking an established arm enclosure releases without replay or refund")
 a=limb_scene("mother");step(1.1);app.street.damage_actor("father","mother",100,"actual_maternal_holder_death")
 check(a.hp==0 and not app.rules.gripped and app.street.data.holder=="" and app.rules.hp==90,"actual holder death releases all attached arms and preserves settled injury")
 a=limb_scene("mother");step(1.1);a.room="street_end";app.street._actor("mother",.025)
 check(not app.rules.gripped and app.room_id=="street_node","cross-room mother cannot keep remote torso fixation")
 a=limb_scene("mother");a.phase="idle";a.last_seen=[];a.last_seen_at=-100;a.investigation={};app.layout.furniture.append({"id":"declared_vision_core","name":"实际视线遮挡核心","rect":Rect2(4.4,2.5,.3,3),"height":140});app.layout.rebuild_grid();step(.5)
 check(a.phase=="idle" and a.last_seen.is_empty() and app.rules.hp==100,"apron eye appearance grants no vision through a real core")

 for id in ["doctor","skinface"]:
  a=limb_scene(id,Vector2(1.05,0));step(.8)
  check(app.rules.hp==100 and a.phase=="attack","original full visible preparation without rectangular damage "+id)
  step(.025)
  check(app.rules.hp==100,"early local blade/arm path has not yet reached distant body "+id)
  await capture("05_"+id+"_before_contact");step(.275)
  check(app.rules.hp==85 and app.rules.sp==80 and not app.rules.gripped,"same actual sweep pays original fifteen HP once without a grip "+id)
  hits=count_fact("combat_hit");clock=app.street.data.clock
  check(disk() and app.rules.settled.has(str(a.attack_id)),"disk stores settled actual swing "+id)
  a=app.street.data.actors[id];app._process(.4)
  check(is_equal_approx(clock,float(app.street.data.clock)) and app.rules.hp==85,"pause after real JSON cannot advance blade or repay "+id)
  await capture("06_"+id+"_actual_contact");step(.7)
  check(a.phase=="idle" and count_fact("combat_hit")==hits and app.rules.hp==85,"full retraction cannot inflict a second hit "+id)
  for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
   a=limb_scene(id,d*1.05,d);step(1.15)
   check(app.rules.hp==85,"same local shape follows original heading "+id+str(d))
  a=limb_scene(id,Vector2(1.05,0));step(.8);var fixed:Array=a.direction.duplicate();app.hero_pos=Vector2(4,5.05);step(.35)
  check(app.rules.hp==100 and a.direction==fixed,"already-launched attack cannot follow side-changing host "+id)
  a=limb_scene(id,Vector2(1.05,0));app.layout.furniture.append({"id":"declared_blade_wall","name":"实际刀路障碍","rect":Rect2(4.55,3.3,.13,1.4),"height":120});app.layout.rebuild_grid();step(1.15)
  check(app.rules.hp==100 and app.street.local_sweeps.state(id).blocked,"real cabinet blocks blade/arm before distant host "+id)
  await capture("07_"+id+"_actual_blocker")
  a=limb_scene(id,Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body()
  check(a.hp==65 and app.street.local_sweeps.state(id).limbs.is_empty(),"actual carrier knee immediately clears local attack "+id)
  step(.5)
  check(app.rules.hp==100,"interrupted carrier cannot deliver delayed local injury "+id)
 a=limb_scene("doctor",Vector2(1.05,0));app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.15)
 check(app.rules.hp==85,"true downward blade descends into crouched body; duck is not unconditional immunity")
 a=limb_scene("skinface",Vector2(1.05,0));app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.15)
 check(app.rules.hp==100,"original chest-height skinface sweep still permits effective duck")
 a=limb_scene("doctor",Vector2(1.05,.2));app.layout.furniture.append({"id":"declared_one_blade_solid","name":"只挡一条刀路","rect":Rect2(4.55,3.76,.2,.12),"height":120});app.layout.rebuild_grid();step(1.15)
 check(app.rules.hp==85 and app.street.local_sweeps.state("doctor").stopped==[true,false],"one independently blocked blade does not erase the other actual clear lane or double-pay")
 a=limb_scene("doctor",Vector2(1.05,-.3));app.layout.furniture.append({"id":"declared_one_blade_solid","name":"只挡一条刀路","rect":Rect2(4.55,3.76,.2,.12),"height":120});app.layout.rebuild_grid();step(.95)
 check(disk() and app.street.local_sweeps.state("doctor").stopped==[true,false],"real partial-swing JSON preserves which actual blade stopped")
 app.layout.furniture.clear();app.layout.rebuild_grid();step(.2)
 check(app.rules.hp==100,"declared blocker removal cannot restart a stopped blade during the same swing")
 var envelope_ok:bool=true
 a=limb_scene("mother")
 for n in range(101):
  for arm in app.street.mother.shape(float(n)/100):
   for p in arm:
    var delta:Vector2=app.street.vector(p)-app.street.position("mother");var radius:float=app.street.mother.param("mother_arm_m")
    envelope_ok=envelope_ok and delta.x+radius<=1.20001 and absf(delta.y)+radius<=.40001
 check(envelope_ok,"configured mother arms fit original1.2m reach and .4m lateral envelope without changing body radius")
 for id in ["doctor","skinface"]:
  a=limb_scene(id);envelope_ok=true
  for n in range(101):
   for limb in app.street.local_sweeps.profile(id,float(n)/100):
    for p in limb:
     var delta:Vector2=app.street.vector(p)-app.street.position(id);var radius:float=app.street.local_sweeps.param("sweep_edge_m")
     envelope_ok=envelope_ok and delta.x+radius<=1.20001 and absf(delta.y)+radius<=.55001
  check(envelope_ok,"local blade/arm points remain inside original attack envelope "+id)
 a=limb_scene("doctor",Vector2(1.05,0));var neutral:Dictionary=actor_at("register_nurse",app.hero_pos);app.hero_pos=Vector2(7,4);step(1.15)
 check(neutral.hp==25 and a.hits.has("register_nurse"),"two coordinated real blades share original once-per-neutral-target HP handler")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared poses/walls/external displacement/legacy fixtures, ordinary shared actor processing, actual paid CONTROL/legal knee, real JSON and paused _process. Mother once10HP impact separate from actual torso grip; doctor/skinface local15HP paths. No full natural crowds, complete character clauses, final art or human whole-game/audio acceptance."},"  "));file.close()
 print("STREET_LIMBS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
