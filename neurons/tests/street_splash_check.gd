extends "res://tests/street_embrace_check.gd"
## Declared poses/partial blockers, real autonomous hand and released liquid.
func splash_scene(offset:Vector2=Vector2(1.75,0)) -> Dictionary:
 embrace_scene(offset);app.street.data.actors.isolation.present=false;app.street.data.erase("pharmacist_splash")
 var a:Dictionary=actor_at("pharmacist",Vector2(4,4));a.hp=60;a.portions=2;a.direction=[1,0];a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_splash:"+str(passes.size()+failures.size());app.street.splash.sync();return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_splash_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="局部泼洒与有限药量验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_twisted");no_street()
 var a:Dictionary=splash_scene();step(.975)
 check(a.phase=="windup" and a.portions==2 and app.street.splash.state().shots.is_empty() and app.rules.sp==80,"original full one-second cup telegraph cannot pre-consume a dose or splash the host")
 await capture("01_cup_direction_before_release");step(.025)
 check(a.phase=="attack" and a.portions==1 and app.street.splash.state().shots.size()==1 and app.rules.sp==80,"actual cup release consumes one of two portions without hitting a distant host immediately")
 var shot:Dictionary=app.street.splash.state().shots[0];var receipt:String=a.attack_id;var age:float=shot.age
 app.street.splash.launch()
 check(a.portions==1 and app.street.splash.state().shots.size()==1,"same launch receipt cannot consume another portion or duplicate airborne liquid")
 step(.075)
 check(app.rules.sp==80 and shot.age<float(app.street.config.attacks.splash.active),"liquid must actually travel through local space rather than hit the whole forward rectangle on its first frame")
 check(disk() and app.street.splash.state().shots.size()==1 and app.street.data.actors.pharmacist.portions==1,"real mid-flight JSON preserves original liquid, remaining cup and one launch")
 shot=app.street.splash.state().shots[0];a=app.street.data.actors.pharmacist;age=shot.age;var at:Vector2=app.street.vector(shot.rays[0].pos);app._process(.5)
 check(is_equal_approx(age,float(shot.age)) and app.street.vector(shot.rays[0].pos).is_equal_approx(at) and app.rules.sp==80,"manual pause freezes actual airborne positions and does not pre-pay their effect")
 await capture("02_real_liquid_mid_flight");step(.225)
 check(app.rules.sp==70 and app.rules.hp==100 and app.rules.stun_left==0 and not app.rules.gripped,"actual local droplet contact pays one original ten-SP hit with zero HP, oral stun or restraint")
 check(app.rules.settled.has(receipt) and shot.hits.has("hero") and count_fact("street_medicine_swallowed")==0,"all droplets share the original one-hit receipt and cannot masquerade as oral swallowing")
 var ground:Vector2=app.street.vector(shot.rays[3].pos);app.hero_pos=ground;step(.25)
 check(app.rules.sp==70 and app.rules.hp==100,"standing on real leftover droplets cannot create recurring ground damage")
 await capture("03_short_ground_visual_only");step(1)
 check(app.street.splash.state().shots.is_empty() and a.portions==1,"short ground residue expires on the world clock without refilling its original cup")
 a.phase="windup";a.elapsed=0;a.attack_id="declared_second_splash";a.hits={};a.direction=[1,0];app.hero_pos=app.street.position("pharmacist")+Vector2(.9,0);step(1.4)
 check(a.portions==0 and app.rules.sp==60 and app.street.splash.state().launched.size()==2,"second actual pour exhausts the same cup and has its own single ten-SP receipt")
 step(4)
 check(a.portions==0 and app.street.splash.state().shots.is_empty() and a.phase=="idle","empty hand-held cup cannot start another attack after full recovery and cooldown")
 app.enter_room("street_maintenance");app.enter_room("street_twisted")
 check(app.street.data.actors.pharmacist.portions==0,"ordinary room return cannot refill two already released portions")
 a=splash_scene(Vector2(.95,.65));step(1.35)
 check(app.rules.sp==80 and a.portions==1,"body inside the old forward rectangle but outside actual liquid lanes is not falsely splashed")
 a=splash_scene(Vector2(2.6,0));step(1.35)
 check(app.rules.sp==80 and a.portions==1,"liquid cannot cover the entire road beyond original two-metre physical reach")
 var bounded:bool=true
 for ray in app.street.splash.state().shots[0].rays:
  if app.street.vector(ray.end).distance_to(Vector2(4,4))+float(app.street.config.test_parameters.splash_drop_radius_m)>2.0001:bounded=false
 check(bounded,"every real droplet endpoint and radius stays inside original two-metre liquid reach")
 a=splash_scene();app.layout.furniture.append({"id":"declared_splash_wall","name":"实际挡液柜体","rect":Rect2(4.95,3,.15,2),"height":120});app.layout.rebuild_grid();step(1.35)
 var blocked:bool=true
 for ray in app.street.splash.state().shots[0].rays:
  if not ray.blocked or float(ray.pos[0])>=4.95:blocked=false
 check(blocked and app.rules.sp==80,"solid cabinet stops all actual liquid on the near side without hitting a host behind it")
 await capture("04_actual_cabinet_stops_liquid")
 a=splash_scene(Vector2(1.7,.45));app.layout.furniture.append({"id":"declared_partial_splash_box","name":"只挡下侧药液的箱体","rect":Rect2(4.95,3.78,.15,.24),"height":90});app.layout.rebuild_grid();step(1.3)
 var count:int=0
 for ray in app.street.splash.state().shots[0].rays:
  if ray.blocked:count+=1
 check(count>0 and count<int(app.street.config.test_parameters.splash_ray_count) and app.rules.sp==70,"partial box blocks only corresponding liquid while actually clear upper lanes still reach the host")
 a=splash_scene();step(.5);app.street.damage_actor("father","pharmacist",15,"declared_cup_interrupted_before_release");step(.5)
 check(a.portions==2 and app.street.splash.state().shots.is_empty() and app.rules.sp==80,"actual hurt before cup release cancels the unfinished pour without consuming its fluid")
 a=splash_scene();step(1.025);app.street.damage_actor("father","pharmacist",15,"declared_cup_interrupted_after_release");step(.3)
 check(a.portions==1 and app.rules.sp==70,"actual hurt after release cannot undo already airborne liquid or refund its portion")
 a=splash_scene(Vector2(.8,0));step(1.025);app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0;app.hero_facing=Vector2.LEFT
 check(app.rules.begin_kick({"direction":[-1,0]},true).ok,"actual paid CONTROL permits an original legal kick after this cup has released")
 app.rules.advance_kick(float(app.rules.config.timing.kick_prepare)+.025);app.street.kick_contact();step(.2)
 check(a.hp<60 and app.street.position("pharmacist").x<4 and app.rules.sp==70 and a.portions==1,"real kick moves/stops the carrier while its already-released liquid still contacts from original position")
 a=splash_scene(Vector2(.8,0));a.portions=1;step(1.025);app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0
 app.rules.begin_kick({"direction":[-1,0]},true);app.rules.advance_kick(float(app.rules.config.timing.kick_prepare)+.025);app.street.kick_contact();var stopped:Vector2=app.street.position("pharmacist");step(.2)
 check(a.portions==0 and a.hurt>0 and app.street.position("pharmacist").is_equal_approx(stopped),"actually kicked empty-cup carrier remains physically stopped during original hurt instead of yielding while hurt")
 step(.9)
 check(a.hurt==0 and a.portions==0 and app.rules.sp==70,"original empty-cup hurt expires without permanent frozen injury or a fresh liquid portion")
 a=splash_scene();step(1.025);app.street.damage_actor("father","pharmacist",100,"declared_liquid_owner_death");step(.3)
 check(a.hp==0 and a.portions==1 and app.rules.sp==70,"actual carrier death cannot freeze or delete liquid already physically released")
 a=splash_scene();step(1.025);a.present=false;step(.3)
 check(app.rules.sp==70 and a.portions==1,"released liquid has its own original room and clock after carrier absence")
 a=splash_scene();step(1.025);var origin:Array=app.street.splash.state().shots[0].origin.duplicate();a.room="street_maintenance";a.pos=[7,4];step(.3)
 check(app.rules.sp==70 and app.street.splash.state().shots[0].origin==origin and app.street.splash.state().shots[0].room=="street_twisted","released splash stays at its true source instead of following a relocated carrier across rooms")
 a=splash_scene();app.rules.reaction_skill="GUT";app.rules.reaction_left=3;step(1.35)
 check(app.rules.sp==70,"combat ducking does not turn liquid-height splash into an oral refusal or chest-swipe immunity")
 a=splash_scene();app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=3;step(1.35)
 check(app.rules.sp==70 and not app.rules.gripped,"arm withdrawal does not erase physically contacted liquid or create control")
 a=splash_scene();a.phase="idle";app.hero_pos=Vector2(6.6,4);step(4)
 check(app.rules.sp==70 and a.portions==1,"ordinary autonomous approach reaches actual liquid range rather than repeatedly pouring too far away")
 a=splash_scene();a.phase="attack";a.elapsed=.1;a.portions=1;app.street._damage_hero(str(a.attack_id),0,10,"pharmacist");app.street.data.erase("pharmacist_splash");var saved:Dictionary=app.snapshot_data();saved.street_state.erase("pharmacist_splash")
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(saved))),"legacy active-attack save without liquid fields still restores")
 step(.6)
 check(app.rules.sp==70 and app.street.data.actors.pharmacist.portions==1 and app.street.splash.state().shots.is_empty(),"legacy unknown released path is not fabricated or repaid from an old rectangular hit")
 a=splash_scene();a.phase="windup";a.elapsed=.5;saved=app.snapshot_data();saved.street_state.erase("pharmacist_splash");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.85)
 check(app.rules.sp==70 and app.street.data.actors.pharmacist.portions==1,"legacy cup still in preparation can complete one new actual release from its remaining dose")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared cast/position and full/partial cabinet fixtures; actually paid CONTROL, real cup telegraph/release/local liquid travel/shared single SP-only hit/two portions/world-clock ground fade; JSON/manual pause, actual hurt/death and explicitly relocated/absent owner, legacy no-path negative. Not natural crowd, final art/audio or full-game acceptance."},"  "));file.close()
 print("STREET_SPLASH_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
