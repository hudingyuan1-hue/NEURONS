extends "res://tests/street_belt_check.gd"
## Actual paid knee triggers counter; pose/wall/other-actor fixtures are explicit.
func counter_scene() -> Dictionary:
 if app.room_id!="street_node":app.enter_room("street_node")
 embrace_scene(Vector2(.82,0));app.street.data.actors.isolation.present=false;app.street.data.erase("double_head_arms");app.street.data.ending={};app.street.data.boundary=false
 var a:Dictionary=actor_at("double_head",Vector2(4,4));a.hp=60;a.hostile=false;a.direction=[1,0];a.phase="idle";a.elapsed=0;a.cooldown=0;a.hits={};a.last_seen=[];a.home=[4,4];a.attack_id="";app.street.double_head.sync();return a
func actual_knee(direction:Vector2=Vector2.LEFT) -> bool:
 app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0
 var result:Dictionary=app.rules.begin_kick({"direction":app.street.xy(direction)},true)
 if not result.ok:return false
 app.rules.advance_kick(float(app.rules.config.timing.kick_prepare)+.025);app.street.kick_contact();return true
func advance_until(predicate:Callable,limit:float) -> bool:
 for i in range(ceili(limit/.025)):
  if predicate.call():return true
  step(.025)
 return predicate.call()
func begin_real_counter() -> Dictionary:
 var a:Dictionary=counter_scene();check(actual_knee(),"actual paid CONTROL permits original legal player knee toward living neutral body")
 check(a.hp==45 and a.hostile and a.hurt>0,"real knee body contact alone establishes one counter eligibility after original injury")
 check(advance_until(func():return a.phase=="windup",3),"actual hurt ends and body autonomously returns inside physical arm reach before counter preparation")
 return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_double_head_20261019/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="双头单体实际反击与中立恢复";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=counter_scene();step(3)
 check(a.hp==60 and not a.hostile and app.rules.hp==100 and a.phase=="idle","mutual neck-hold placeholder never causes automatic self damage or attacks a passing body")
 await capture("01_two_heads_one_neutral_body")
 a=counter_scene();check(actual_knee(Vector2.RIGHT),"declared legal knee can actually miss in original opposite direction");step(2)
 check(a.hp==60 and not a.hostile and app.rules.hp==100,"actual player kick miss cannot authorize counterattack")
 a=counter_scene();app.street.damage_actor("father","double_head",15,"declared_enemy_damage");step(2)
 check(a.hp==45 and not a.hostile and app.rules.hp==100,"actual other-enemy injury cannot be attributed to player or authorize retaliation")
 a=begin_real_counter();step(.2)
 check(app.street.double_head.state().phase=="release_necks" and app.rules.hp==100,"original windup first releases mutual neck hold without premature counter damage")
 await capture("02_actual_knee_then_neck_release");step(.25)
 check(app.street.double_head.state().phase=="heads_turn" and app.street.double_head.state().turn>0,"same original windup visibly turns both heads before actual arm strike")
 check(advance_until(func():return a.phase=="attack",1),"full original .8 windup ends before actual double-arm movement")
 step(.025)
 check(app.rules.hp==100 and app.street.double_head.state().arms.size()==2,"early actual forward arms have not yet reached distant target, unlike old filled rectangle")
 check(advance_until(func():return app.rules.hp<100,.4),"actual local forward arm/body contact commits the counter")
 check(app.rules.hp==85 and app.rules.sp==80 and not app.rules.gripped and app.street.data.holder=="","two arms/two heads share one original15HP receipt without SP/grip multiplication")
 var receipt:String=a.attack_id;var hp:int=app.rules.hp
 check(disk() and app.rules.settled.has(receipt),"real JSON preserves actual two-arm pose and paid single counter receipt")
 a=app.street.data.actors.double_head;var clock:float=app.street.data.clock;var arms:Array=app.street.double_head.state().arms.duplicate(true);app._process(.7)
 check(is_equal_approx(clock,float(app.street.data.clock)) and app.street.double_head.state().arms==arms and app.rules.hp==hp,"actual pause freezes same arms and cannot repeat injury")
 await capture("03_actual_two_arm_contact");check(advance_until(func():return a.phase=="idle",2),"same original strike/recovery actually completes")
 check(not a.hostile and app.rules.hp==85 and a.hp==45,"completed one counter restores neutral body, unchanged self HP and no duplicated hit")
 step(2)
 check(not a.hostile and app.rules.hp==85,"standing near neutral recovered body does not queue or repeat counter")
 await capture("04_neutral_after_one_counter")
 a=begin_real_counter();app.layout.furniture.append({"id":"declared_counter_wall","name":"实际挡前臂柜体","rect":Rect2((app.street.position("double_head").x+app.hero_pos.x)*.5,3.3,.1,1.4),"height":120});app.layout.rebuild_grid();step(1.5)
 check(app.rules.hp==100 and true in app.street.double_head.state().blocked,"actual solid cabinet stops both attached arms without a through-wall counter")
 a=begin_real_counter();check(advance_until(func():return a.phase=="attack",1),"separate real hit reaches launched fixed-direction counter")
 var heading:Array=a.direction.duplicate();app.hero_pos+=Vector2(0,1.2);step(.4)
 check(a.direction==heading and app.rules.hp==100,"moving to flank after preparation cannot turn already-launched arms or fill old rectangle")
 a=begin_real_counter();check(advance_until(func():return a.phase=="attack",1),"declared legacy scenario reaches actual active counter before archive")
 app.hero_pos+=Vector2(0,1.2);step(.175);app.hero_pos=app.street.position("double_head")+app.street.double_head.direction()*.55
 var legacy:Dictionary=app.snapshot_data();legacy.street_state.erase("double_head_arms");app.restore_snapshot(JSON.parse_string(JSON.stringify(legacy)));step(.025)
 check(app.rules.hp==100 and app.street.double_head.state().arms.size()==2,"old mid-strike JSON reconstructs current arms only; missing past sweep cannot retroactively hit a new near-side body")
 a=begin_real_counter();app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.2)
 check(app.rules.hp==100,"existing timely chest-height duck avoids original chest counter without new immunity")
 a=begin_real_counter();app.street.damage_actor("father","double_head",100,"declared_fatal_before_counter");step(2)
 check(a.hp==0 and app.rules.hp==100 and app.street.double_head.state().arms.is_empty(),"actual lethal interruption stops body without posthumous counter")
 a=counter_scene();a.hp=15;check(actual_knee(),"same legal player knee reaches declared fatal-health body");step(2)
 check(a.hp==0 and app.rules.hp==100,"player's fatal hit terminates instead of queuing retaliation from death")
 a=begin_real_counter();app.hero_pos=Vector2(15,10);step(3)
 check(not a.hostile and app.rules.hp==100,"lost actual target leads to last-seen check then neutral instead of remote retaliation")
 var file=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared body/wall/target movement fixtures; counters initiated only by actual paid CONTROL and legal knee contact. Real original hurt, AI approach/windup, swept two arms,15HP once, JSON/pause/neutral/loss/death. Not human crowds/final art or full B7."},"  "));file.close()
 print("STREET_DOUBLE_HEAD_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
