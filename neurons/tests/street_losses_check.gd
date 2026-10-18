extends "res://tests/street_materials_check.gd"
## Declared aligned combat fixtures use the actual shared hit/death pipeline.
func loss_scene(host_hp:int=100) -> Dictionary:
 no_street();app.street.data.speed_stacks=0;app.street.data.speed_deaths={};app.street.data.erase("loss_reactions");app.street.data.ending={};app.street.data.boundary=false
 app.layout.furniture.clear();app.layout.rebuild_grid();app.rules.hp=host_hp;app.rules.sp=75;app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.effects.clear();app.rules.end_control();app.rules.action.clear();app.rules.settled.clear();app.rules.kick_until=0
 # Each independent fixture starts in combat, including the one following
 # the real ending case below. Do not bypass production transition guards.
 app.rules.mode="combat";app.rules.transitioning=false;app.rules.intervention_lock=false
 var source:Dictionary=actor_at("father",Vector2(4,4));source.phase="windup";source.elapsed=0.0;source.direction=[1,0];source.hits={};source.attack_id="declared_loss:"+str(passes.size());source.cooldown=0
 actor_at("dog",Vector2(4.95,4.1));app.hero_pos=Vector2(4.9,4);app.hero_route=PackedVector2Array();return source
func roundtrip_loss() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var saved:Dictionary=app.store.load_snapshot();return saved.ok and app.restore_snapshot(saved.data)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_losses_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street真实遇害与反馈验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var father:Dictionary=loss_scene();var losses=app.street.losses;var before:int=count_fact("street_good_death");var evidence:int=app.rules.evidence.size();var neurons:int=app.rules.neurons;var resistance:int=app.rules.global_resistance
 advance_actor("father",.8)
 check(app.street.data.actors.dog.hp>0 and app.street.data.speed_stacks==0 and losses.state().pending.is_empty(),"father appearing and completing windup alone cannot fragment the dog or trigger loss feedback")
 # Actual glass must reach the victim inside the unchanged .3s active window.
 advance_actor("father",.3)
 check(app.street.data.actors.dog.hp==0 and app.street.data.speed_stacks==1 and losses.state().pending.size()==1,"actual effective father contact fragments existing dog and records one real loss before delayed speech")
 check(app.street.data.speed_deaths.has("dog") and app.street.data.speed_deaths.dog.witnessed and known_id("street_loss_seen:%d:dog"%app.rules.actual_attempt),"actual local sight records witnessed death separately from the physical speed gain")
 check(app.rules.hp==85 and app.rules.sp==75 and app.rules.neurons==neurons and app.rules.evidence.size()==evidence and app.rules.global_resistance==resistance,"loss feedback invents no healing, resources, spirit, fourth-wall evidence or repeat formal awakening")
 losses.tick(.1)
 check(app.dialogue_queue.is_empty() and losses.state().pending.size()==1,"ongoing actual hostile attack delays the source madness sentence without delaying existing speed gain")
 var left:float=losses.state().pose_left;app._process(.5)
 check(is_equal_approx(left,float(losses.state().pose_left)),"actual manual pause freezes bounded body-feedback clock")
 await capture("01_actual_loss_during_threat")
 check(roundtrip_loss() and app.street.losses.state().pending.size()==1 and app.street.data.speed_stacks==1,"real disk JSON retains pending original reaction and already-paid physical layer")
 losses=app.street.losses;father=app.street.data.actors.father;father.present=false;app.rules.hurt_left=0;app.rules.stun_left=0
 losses.tick(.025)
 check(app.dialogue_queue.size()==1 and app.dialogue_queue[0].text=="还没完……还没完……","actual safe gap dispatches the exact source sentence once")
 check(roundtrip_loss() and app.dialogue_queue.size()==1,"mid-dialogue real save restores existing speech without re-awarding the loss")
 losses=app.street.losses;clear_lines();losses.tick(.1)
 check(app.dialogue_queue.is_empty() and count_fact("street_good_death")==before+1,"closed/reloaded speech cannot duplicate death or queue a second line")
 app.street.damage_actor("father","dog",20,"declared_corpse_again")
 check(app.street.data.speed_stacks==1 and losses.state().pending.is_empty(),"corpse damage never repeats speed layers or madness feedback")
 loss_scene();app.street.data.actors.dog.present=false;var unseen:Dictionary=actor_at("corner",Vector2(4.95,4.1));unseen.hp=10
 app.enter_room("street_side");advance_actor("father",1.1);losses=app.street.losses
 check(app.street.data.speed_stacks==1 and not app.street.data.speed_deaths.corner.witnessed and losses.state().pending.size()==1,"real off-room attack keeps actual death/layer and pending general reaction without inventing witness")
 check(not known_id("street_loss_seen:%d:corner"%app.rules.actual_attempt),"actual off-room death cannot add a new witnessed victim observation")
 app.rules.hurt_left=0;losses.tick(.025)
 check(app.dialogue_queue.size()==1 and not str(app.dialogue_queue[0].text).contains("父亲") and not str(app.dialogue_queue[0].text).contains("大黄"),"unwitnessed reaction says only the original general sentence, never identifying an unseen killer or victim")
 clear_lines();app.enter_room("street_plaza");loss_scene()
 app.street.data.actors.dog.present=false
 for spec in [["corner",-.3],["wheelchair",-.1],["transport_patient",.1],["postop",.3]]:
  var victim:Dictionary=actor_at(str(spec[0]),Vector2(4.9,4+float(spec[1])));victim.hp=10
 advance_actor("father",1.1);losses=app.street.losses
 check(app.street.data.speed_stacks==3 and app.street.data.speed_deaths.size()==4 and losses.state().pending.size()==4,"one declared aligned attack fixture records four actual deaths even above existing three-layer cap")
 app.street.data.actors.father.present=false;app.rules.hurt_left=0;losses.tick(.025)
 check(losses.state().acknowledged.size()==4 and losses.state().pending.is_empty() and app.dialogue_queue.size()==1,"one safe-gap source line acknowledges every independently recorded pending loss without four identical modal repetitions")
 clear_lines();loss_scene();app.street.data.actors.dog.present=false;var nurse:Dictionary=actor_at("nurse",Vector2(4.9,4.1));nurse.hp=10;advance_actor("father",1.1)
 check(nurse.hp==0 and app.street.data.speed_stacks==0 and app.street.losses.state().pending.is_empty(),"actual current friendly nurse death does not silently expand the original seven-person eligibility list")
 loss_scene();app.street.data.actors.father.present=false;app.street.data.actors.dog.present=false;var victim:Dictionary=actor_at("corner",Vector2(4.9,4));victim.hp=10
 app.street.damage_actor("register_nurse","corner",15,"declared_no_attack_source")
 check(victim.hp==0 and app.street.data.speed_stacks==0 and not app.street.data.speed_deaths.has("corner"),"declared source without an attack can cause no qualified loss/layer merely because a damage caller exists")
 # Explicit simultaneous-contact fixture: both bodies meet this same local
 # glass segment, rather than assuming every forward-rectangle point hits now.
 loss_scene(15);app.street.data.actors.dog.pos=[5.02,3.95];advance_actor("father",1.1)
 check(app.rules.hp==0 and app.street.data.actors.dog.hp==0 and app.street.data.speed_deaths.has("dog"),"same actual attack can kill host and dog while preserving genuine death history")
 check(app.street.data.speed_stacks==0 and app.street.losses.state().pending.is_empty(),"same-tick host death receives no posthumous speed, pose or next-life pending line")
 loss_scene();advance_actor("father",1.1);app.rules.hurt_left=0;app.rules.gripped=true;app.street.data.holder="guard_hospital";app.street.data.actors.father.present=false;losses=app.street.losses;losses.tick(.1)
 check(app.rules.gripped and app.street.data.holder=="guard_hospital" and app.dialogue_queue.is_empty(),"loss response never releases an unrelated established grip or interrupts its owner")
 app.rules.gripped=false;app.street.data.holder="";app.street.exit_crossed();losses.tick(.1)
 check(not app.street.data.ending.is_empty() and app.street.data.speed_stacks==0 and losses.state().pending.is_empty(),"real ending crossing never waits for pending madness and clears this attempt's transient gain/reaction")
 var saved:Dictionary=app.snapshot_data();saved.street_state.erase("loss_reactions")
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(saved))) and app.street.losses.state().pending.is_empty(),"old JSON with prior deaths but no reaction field does not fabricate replayable pending speech")
 app.enter_room("street_plaza");loss_scene();app.street.data.actors.father.present=false;app.street.data.actors.dog.present=false
 app.hero_pos=Vector2(5,5);victim=actor_at("corner",Vector2(5.8,5));victim.hp=10
 app.rules.neurons=30;app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.power=1;app.rules.skill_states.CONTROL.resistance=0;app.rules.skill_states.CONTROL.until=0;app.rules.submit_skill("CONTROL",{});app.rules.apply_pending();app.rules.skill_states.KNEE.unlocked=true
 check(app.rules.begin_kick({"direction":[1,0]},true).ok,"declared skill/resource fixture pays real CONTROL and starts actual legal player kick")
 app.rules.advance_kick(float(app.rules.config.timing.kick_prepare)+.025);app.street.kick_contact()
 check(victim.hp==0 and app.street.data.speed_stacks==0 and app.street.losses.state().pending.is_empty(),"actual player kick kill cannot generate qualified madness or speed bonus")
 app.rules.action.clear();loss_scene();advance_actor("father",1.1);before=count_fact("street_good_death");var old_attempt:int=app.rules.actual_attempt
 app.restart_street(1)
 check(app.rules.actual_attempt==old_attempt+1 and app.session.data.level==5 and app.street.data.speed_stacks==0 and app.street.losses.state().pending.is_empty() and count_fact("street_good_death")==before,"real Street revival clears transient gains/pending lines while retaining actual earlier death history")
 app.unlock_street();loss_scene();advance_actor("father",1.1)
 check(app.street.data.speed_stacks==1 and count_fact("street_good_death")==before+1 and app.rules.global_resistance==resistance,"same actual identity in a new real attempt can qualify once again without replaying global awakening")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared aligned real attack fixtures, including one four-victim collision fixture and one non-attacking-source negative. Shared attack contact/death, off-room outcome, actual disk JSON/manual pause, original safe-gap line, no rewards/awakening and real ending. Not natural crowd positioning/full-game or formal art/audio acceptance."},"  "));file.close()
 print("STREET_LOSSES_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
