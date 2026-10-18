extends "res://tests/street_materials_check.gd"
## Aligned/occluded/other-holder fixtures, real shared contact and release handlers.
func arm_scene() -> Dictionary:
 no_street();app.street.data.erase("dislocated_clamp");app.street.data.next_attack=0;app.street.data.grip_safe_until=0;app.street.data.clock=0
 app.layout.furniture.clear();app.layout.rebuild_grid();app.rules.hp=100;app.rules.sp=80;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.reaction_left=0;app.rules.reaction_skill="";app.rules.action.clear();app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.settled.clear();app.rules.effects.clear()
 app.rules.end_control();app.rules.neurons=50;app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.power=1;app.rules.skill_states.CONTROL.resistance=0;app.rules.skill_states.CONTROL.until=0
 app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 app.hero_pos=Vector2(4.9,4);app.hero_facing=Vector2.RIGHT;app.hero_route=PackedVector2Array()
 var a:Dictionary=actor_at("dislocated",Vector2(4,4));a.hp=60;a.direction=[1,0];a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_clamp:"+str(passes.size());app.street.clamp.sync();return a
func clamp_step(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.advance_world(.025)
func arm_disk() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var data:Dictionary=app.store.load_snapshot();return data.ok and app.restore_snapshot(data.data)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_losses_20261018/clamp"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="实际腕臂扣合与单侧释放验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_narrow");no_street()
 var a:Dictionary=arm_scene();var clamp=app.street.clamp;var side:int=clamp.state().side;clamp_step(.8)
 check(a.phase=="attack" and app.rules.hp==100 and not app.rules.gripped,"original .8-second one-shoulder preparation cannot pre-pay forearm contact")
 clamp_step(.1)
 check(a.phase=="attack" and clamp.state().phase=="extend" and app.rules.hp==100 and not app.rules.gripped,"extended open arm passing near the body is not a closed clamp")
 await capture("01_open_clamp_not_yet_contact")
 clamp_step(.125)
 check(a.phase=="attack" and app.rules.hp==100 and app.street.clamp.state().open>.25,"jaw closure still visibly open cannot settle the forearm hit merely because closing started")
 clamp_step(.05)
 check(a.phase=="grip" and app.street.data.holder=="dislocated" and app.rules.gripped and app.rules.hp==90,"actual same-side near-closed jaws on the forearm commit original ten HP and one short grip")
 check(count_fact("cortex_damage")==0 and app.street.data.appearance.marks.is_empty(),"Street clamp injury does not replay the old cortex test-table damage or invent a paired old hand scar")
 var receipt:String=a.attack_id;var time:float=app.street.data.clock;var left:float=app.street.data.grip_until-time
 check(arm_disk() and app.street.data.holder=="dislocated" and app.rules.settled.has(receipt),"real held-clamp JSON keeps one owner, existing injury and deadline")
 a=app.street.data.actors.dislocated;clamp=app.street.clamp;app._process(.5)
 check(is_equal_approx(time,float(app.street.data.clock)) and app.rules.hp==90 and app.street.data.holder=="dislocated","actual manual pause freezes held clamp and cannot repay injury")
 app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;clamp_step(.1)
 check(app.street.data.holder=="dislocated" and app.rules.gripped and app.rules.hp==90,"WITHDRAW after established closure cannot retroactively free an already clamped arm")
 await capture("02_actual_single_arm_hold")
 clamp_step(left+.025)
 check(not app.rules.gripped and app.street.data.holder=="" and a.phase=="recover" and clamp.state().open==1,"original actual grip deadline opens the same jaws before retraction")
 check(int(clamp.state().side)==side,"opposite arm is not activated while this arm is still recovering")
 clamp_step(.65)
 check(a.phase=="idle" and int(clamp.state().side)==-side and a.cooldown>1.3,"only complete original recovery switches the next arm and retains cooldown")
 clamp_step(1.55)
 check(a.phase=="windup" and int(clamp.state().side)==-side and app.rules.hp==90,"other arm begins its own full preparation instead of chaining an immediate second hold")
 a=arm_scene();app.hero_pos=Vector2(4.9,4.55);clamp_step(1.15)
 check(app.rules.hp==100 and not app.rules.gripped and a.phase=="recover","body-box grazing without either actual forearm in the closing jaws causes no grip or damage")
 a=arm_scene();app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;clamp_step(1.15)
 check(app.rules.hp==100 and not app.rules.gripped,"original timely WITHDRAW still avoids a not-yet-established arm grab")
 a=arm_scene();app.layout.furniture.append({"id":"fixture_cabinet","name":"明确前臂阻挡柜","rect":Rect2(4.6,3.4,.15,1.2),"height":90});app.layout.rebuild_grid();clamp_step(1.05)
 check(app.rules.hp==100 and not app.rules.gripped and app.street.clamp.state().blocked and a.phase=="recover","actual cabinet blocks extension and sends the same arm into original recovery without wall grip")
 check(app.street.vector(app.street.clamp.state().tip).x<4.6,"blocked claw retracts from its actual stopped side instead of snapping through the cabinet")
 a=arm_scene();clamp_step(1.1);app.street.damage_actor("father","dislocated",15,"declared_actual_third_party_hit")
 check(app.street.data.holder=="" and not app.rules.gripped and a.phase=="recover" and app.rules.hp==90,"real third-party hurt immediately opens this owner's existing grip without undoing paid injury")
 a=arm_scene();clamp_step(1.1);app.street.damage_actor("father","dislocated",100,"declared_actual_holder_death")
 check(a.hp==0 and app.street.data.holder=="" and not app.rules.gripped,"actual holder death immediately releases its own clamp with no queued opposite arm")
 a=arm_scene();clamp_step(1.1);a.room="street_twisted";app.street._actor("dislocated",.025)
 check(not app.rules.gripped and app.street.data.holder=="" and app.room_id=="street_narrow","invalid cross-room hold is released locally without transporting the hero")
 # Reachable legacy grip; missing trajectory stays static within original1.2s.
 a=arm_scene();app.street.data.erase("grasp_motion");var guard:Dictionary=actor_at("guard_hospital",app.hero_pos+Vector2(0,1.05));guard.phase="grip";app.street.data.holder="guard_hospital";app.street.data.grip_until=app.street.data.clock+1.2;app.rules.gripped=true;clamp_step(1.05)
 check(app.street.data.holder=="guard_hospital" and app.rules.hp==100 and not a.hits.has("hero"),"already-launched closing arm cannot steal another holder or queue damage/control behind it")
 app.street.damage_actor("father","dislocated",15,"declared_hurt_non_holder")
 check(app.street.data.holder=="guard_hospital" and app.rules.gripped,"hurting a non-owner clamp cannot release somebody else's established grip")
 a=arm_scene();clamp_step(1.1);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("dislocated_clamp")
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(saved))) and app.street.data.holder=="dislocated","legacy active-grip save loads without the new pose field")
 clamp_step(.1)
 check(app.rules.hp==90 and app.rules.gripped and app.street.clamp.state().phase=="held","legacy migration reconstructs a visible existing hold without a fresh contact or damage receipt")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Aligned forearm/side miss/cabinet/other-holder fixtures, each actually paid CONTROL to hold host position. Real shared attack/ten-HP/grip deadline, actual damage interruption/death, disk JSON/manual pause, timely versus late WITHDRAW. Test wrist/forearm profile, not final anatomy or natural crowd/full-game acceptance."},"  "));file.close()
 print("STREET_CLAMP_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
