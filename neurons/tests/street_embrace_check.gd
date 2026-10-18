extends "res://tests/street_materials_check.gd"
## Declared poses/blocker/owner fixtures, real attack, costs, save and release.
func embrace_scene(offset:Vector2=Vector2(.85,0),facing:Vector2=Vector2.RIGHT) -> Dictionary:
 no_street();app.street.data.erase("isolation_embrace");app.street.data.next_attack=0;app.street.data.grip_safe_until=0;app.street.data.clock=0
 app.layout.furniture.clear();app.layout.rebuild_grid();app.rules.hp=100;app.rules.sp=80;app.rules.mode="combat";app.rules.transitioning=false;app.rules.intervention_lock=false
 app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.reaction_left=0;app.rules.reaction_skill="";app.rules.action.clear();app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.settled.clear();app.rules.effects.clear()
 app.rules.end_control();app.rules.neurons=50;app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.power=1;app.rules.skill_states.CONTROL.resistance=0;app.rules.skill_states.CONTROL.until=0
 app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 app.hero_pos=Vector2(4,4)+offset;app.hero_facing=Vector2.RIGHT;app.hero_route=PackedVector2Array()
 var a:Dictionary=actor_at("isolation",Vector2(4,4));a.hp=60;a.direction=app.street.xy(facing);a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_embrace:"+str(passes.size());app.street.embrace.sync();return a
func step(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.advance_world(.025)
func disk() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var loaded:Dictionary=app.store.load_snapshot();return loaded.ok and app.restore_snapshot(loaded.data)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_embrace_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="双臂实际围合验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_narrow");no_street()
 var a:Dictionary=embrace_scene();var embrace=app.street.embrace;step(.8)
 check(a.phase=="attack" and app.rules.sp==80 and not app.rules.gripped,"original full preparation opens both arms without pre-paying spirit or control")
 step(.225)
 check(a.phase=="attack" and app.rules.sp==80 and not app.rules.gripped and embrace.state().arms.size()==2,"two still-open arms do not count as a completed torso enclosure")
 await capture("01_both_arms_closing_before_contact");step(.05)
 check(a.phase=="grip" and app.street.data.holder=="isolation" and app.rules.gripped and app.rules.sp==65 and app.rules.hp==100,"both actual padded arms enclose torso before exactly fifteen SP and no HP commit")
 var receipt:String=a.attack_id;var pos:Vector2=app.hero_pos;var clock:float=app.street.data.clock;var until:float=app.street.data.grip_until
 check(disk() and app.street.data.holder=="isolation" and app.rules.settled.has(receipt),"real held-embrace JSON preserves sole owner, original deadline and paid receipt")
 a=app.street.data.actors.isolation;embrace=app.street.embrace;app._process(.6)
 check(is_equal_approx(clock,float(app.street.data.clock)) and app.rules.sp==65 and app.rules.hp==100,"manual pause freezes the established hold without additional spirit loss")
 app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;app.hero_route=app.layout.path(app.hero_pos,Vector2(7,4));step(.1)
 check(app.rules.gripped and app.street.data.holder=="isolation" and app.hero_pos.is_equal_approx(pos),"WITHDRAW and an ordinary route do not undo torso restraint or teleport the host")
 await capture("02_both_arms_actual_torso_hold")
 check(app.room_id=="street_narrow" and app.street.data.ending.is_empty() and count_fact("asylum_isolated")==0,"moving frame and embrace create no quiet room, detention or ending")
 step(until-float(app.street.data.clock)+.025)
 check(not app.rules.gripped and app.street.data.holder=="" and a.phase=="recover" and embrace.state().phase=="opening","original 1.2-second deadline releases both arms into the existing recovery")
 await capture("03_arms_open_recovery");step(.65)
 check(a.phase=="idle" and embrace.state().arms.is_empty() and a.cooldown>1.3,"full recovery folds both arms and retains an independent next preparation")
 a=embrace_scene(Vector2(.85,.36));step(1.15)
 check(app.rules.sp==80 and app.rules.hp==100 and not app.rules.gripped and a.phase=="recover","single-side body grazing cannot magnetically become a complete hug")
 a=embrace_scene(Vector2(1.4,0));step(1.15)
 check(app.rules.sp==80 and not app.rules.gripped,"open arms cannot acquire a torso beyond the original attack reach")
 for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  a=embrace_scene(d*.85,d);step(1.1)
  check(app.street.data.holder=="isolation" and app.rules.hp==100 and app.rules.sp==65,"both-arm enclosure follows real direction "+str(d))
 a=embrace_scene();app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(1.1)
 check(app.street.data.holder=="isolation" and app.rules.sp==65,"arm-withdrawal before contact still cannot negate a torso hug under original skill rules")
 a=embrace_scene();app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.1)
 check(app.street.data.holder=="isolation" and app.rules.sp==65,"chest-height ducking does not turn a body-height embrace into a dodge")
 a=embrace_scene();app.layout.furniture.append({"id":"declared_one_arm_cabinet","name":"单侧软垫阻挡柜","rect":Rect2(4.5,4.35,.18,.4),"height":80});app.layout.rebuild_grid();step(1.15)
 check(app.rules.sp==80 and not app.rules.gripped and embrace.state().blocked and a.phase=="recover","blocking only one actual arm prevents a complete enclosure while central torso ray stays clear")
 check(app.layout.clear_segment(Vector2(4,4),app.hero_pos) and embrace.clear_arms(embrace.state().arms),"blocked padded arms remain on accepted furniture side rather than clipping through the cabinet")
 a=embrace_scene();step(1.1);app.street.damage_actor("father","isolation",15,"declared_embrace_third_party_hurt")
 check(app.street.data.holder=="" and not app.rules.gripped and app.rules.sp==65 and a.phase=="recover","actual owner hurt releases only its established hug without refunding spirit")
 a=embrace_scene();step(1.1);app.street.damage_actor("father","isolation",100,"declared_embrace_owner_death")
 check(a.hp==0 and not app.rules.gripped and app.street.data.holder=="","actual holder death releases restraint without another queued pair of arms")
 a=embrace_scene();step(1.1);a.room="street_twisted";app.street._actor("isolation",.025)
 check(not app.rules.gripped and app.street.data.holder=="" and app.room_id=="street_narrow","invalid cross-room holder releases locally without changing room topology")
 # Reachable legacy grip; missing trajectory stays static within original1.2s.
 a=embrace_scene();app.street.data.erase("grasp_motion");var other:Dictionary=actor_at("guard_hospital",app.hero_pos+Vector2(0,1.05));other.phase="grip";app.street.data.holder="guard_hospital";app.street.data.grip_until=app.street.data.clock+1.2;app.rules.gripped=true;step(1.1)
 check(app.street.data.holder=="guard_hospital" and app.rules.sp==80 and not a.hits.has("hero"),"already-prepared embrace cannot steal another holder or pre-pay a queued restraint")
 app.street.damage_actor("father","isolation",15,"declared_non_owner_hurt")
 check(app.street.data.holder=="guard_hospital" and app.rules.gripped,"hurting a non-owner hugger cannot release a different established grip")
 a=embrace_scene();step(1.1);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("isolation_embrace")
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(saved))) and app.street.data.holder=="isolation","old existing-grip save loads without the new double-arm pose field")
 step(.1)
 check(app.rules.sp==65 and app.rules.hp==100 and app.street.embrace.state().phase=="held","old hold reconstructs its visual arms without new injury or settlement")
 a=embrace_scene();a.phase="idle";app.hero_pos=Vector2(5.6,4)
 step(3)
 print("EMBRACE_APPROACH ",JSON.stringify({"actor":a,"hero":app.street.xy(app.hero_pos),"pose":app.street.embrace.state(),"sp":app.rules.sp}))
 check(app.street.data.holder=="isolation" and app.rules.sp==65,"ordinary autonomous approach gets inside actual embrace reach instead of repeating far-away empty hugs")
 a=embrace_scene(Vector2(.85,.36));step(1.15);var safe:float=app.street.data.grip_safe_until;step(.65)
 check(not app.rules.gripped and app.rules.sp==80 and a.phase=="idle" and app.street.data.grip_safe_until==safe,"missed hug fully reopens and folds without inventing a hold, spirit charge or blocked exit")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared aligned/one-side/range/four-direction/cabinet/other-holder scenes with actual paid CONTROL. Shared real attack/SP-only settlement/grip deadline, real damage/death/room invalidation, disk/manual pause and legacy save. Trial torso/arm geometry, not final art, natural crowd or full-game acceptance."},"  "));file.close()
 print("STREET_EMBRACE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
