extends "res://tests/street_embrace_check.gd"
## Declared strip/contact/blocker poses; real shared damage, legal kick and disk.
func belt_scene(offset:Vector2=Vector2(1.25,0),heading:Vector2=Vector2.RIGHT) -> Dictionary:
 embrace_scene(offset);app.street.data.actors.isolation.present=false;app.street.data.erase("warder_belt")
 var a:Dictionary=actor_at("warder",Vector2(4,4));a.hp=60;a.direction=app.street.xy(heading);a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_belt:"+str(passes.size()+failures.size());app.street.belt.sync();return a
func kick_body() -> void:
 app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0
 check(app.rules.begin_kick({"direction":[-1,0]},true).ok,"actually paid CONTROL permits original legal knee toward the preparing carrier")
 app.rules.advance_kick(float(app.rules.config.timing.kick_prepare)+.025);app.street.kick_contact()
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_belt_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="普通护工实际束带与中断验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_plaza");no_street()
 var a:Dictionary=belt_scene();step(.8)
 check(a.phase=="attack" and app.rules.hp==100 and app.rules.sp==80 and not a.hits.has("hero"),"full original .8s draw and uncoil pays no premature belt damage")
 step(.025)
 check(app.rules.hp==100,"early local strip is not an already-filled forward damage rectangle")
 await capture("01_actual_strip_before_contact");step(.1)
 check(app.rules.hp==85 and app.rules.sp==75 and a.hits.has("hero"),"actual waist strip commits original fifteen HP and five SP once")
 check(not app.rules.gripped and app.street.data.holder=="" and app.street.data.grip_until==0,"ordinary belt adds no restraint, transport or persistent holder")
 var receipt:String=a.attack_id;var elapsed:float=a.elapsed;var pose:Array=app.street.belt.state().profile.duplicate(true);var hit_count:int=count_fact("combat_hit")
 check(disk() and app.rules.settled.has(receipt),"actual JSON stores the same attached strip and paid contact")
 a=app.street.data.actors.warder;app._process(.6)
 check(is_equal_approx(elapsed,float(a.elapsed)) and app.street.vector(pose[-1]).is_equal_approx(app.street.vector(app.street.belt.state().profile[-1])) and app.rules.hp==85,"manual pause after disk freezes actual belt pose and settled damage")
 await capture("02_actual_waist_hit_paused");step(.3)
 check(a.phase=="recover" and app.rules.hp==85 and app.rules.sp==75 and count_fact("combat_hit")==hit_count,"two arms and every remaining strip segment cannot pay the same swing twice")
 step(.65)
 check(a.phase=="idle" and a.cooldown>1.1 and app.street.belt.state().owner=="warder" and app.rules.hp==85,"full .6 recovery wraps the same strap with original1.5 cooldown and no reverse hit")
 a=belt_scene();app.rules.reaction_skill="GUT";app.rules.reaction_left=2;step(1.15)
 check(app.rules.hp==85 and app.rules.sp==75,"chest duck cannot automatically avoid waist-height belt")
 a=belt_scene();app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;step(1.15)
 check(app.rules.hp==85 and not app.rules.gripped,"arm withdrawal neither erases waist contact nor creates a grip")
 for offset in [Vector2(.5,.6),Vector2(-.3,0),Vector2(1.9,0)]:
  a=belt_scene(offset);step(1.15)
  check(app.rules.hp==100 and app.rules.sp==80,"actual fixed fan misses side/rear/out-of-reach host "+str(offset))
 for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  a=belt_scene(d*1.25,d);step(1.15)
  check(app.rules.hp==85 and app.rules.sp==75,"same local strip uses original fixed direction "+str(d))
 a=belt_scene();var fixed:Array=a.direction.duplicate();step(.8);app.hero_pos=Vector2(4,5.25);step(.35)
 check(a.direction==fixed and app.rules.hp==100,"moving to the flank after preparation does not rotate the launched belt")
 a=belt_scene();var envelope_ok:bool=true
 for n in range(101):
  for p in app.street.belt.profile(float(n)/100):
   var delta:Vector2=app.street.vector(p)-app.street.position("warder")
   envelope_ok=envelope_ok and delta.length()+float(app.street.config.test_parameters.belt_radius_m)<=1.60001 and absf(delta.y)+float(app.street.config.test_parameters.belt_radius_m)<=.60001
 check(envelope_ok,"all actual strip points stay within original1.6 reach and .6 lateral envelope")
 app.layout.furniture.append({"id":"declared_belt_cabinet","name":"实际挡带柜体","rect":Rect2(4.7,3.3,.15,1.4),"height":120});app.layout.rebuild_grid();step(1.15)
 check(app.street.belt.state().blocked and a.phase=="recover" and app.rules.hp==100,"real cabinet stops belt before far-side victim, never continuing behind it")
 var stopped_ok:bool=true
 for p in app.street.belt.state().profile:stopped_ok=stopped_ok and app.street.vector(p).x<4.7
 check(stopped_ok,"blocked strip remains on actual accepted side while retracting")
 await capture("03_actual_belt_stopped_by_cabinet")
 a=belt_scene(Vector2(.58,-.16));app.layout.furniture.append({"id":"declared_nearside_cabinet","name":"近侧接触仍有遮挡","rect":Rect2(4.9,3.3,.15,1.4),"height":120});app.layout.rebuild_grid();step(1.15)
 check(app.rules.hp==85,"accepted near-side strip may still contact a body before its far end is obstructed")
 a=belt_scene(Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body();step(.5)
 check(a.hp==45 and a.phase not in ["windup","attack"] and app.rules.hp==100,"actual kick to carrier body cancels an unfinished belt and uses original displacement")
 a=belt_scene();step(.8);app.hero_facing=Vector2.LEFT;kick_body()
 check(a.hp==60 and a.phase=="attack" and app.rules.action.hit_receipts.is_empty(),"kick at extended strap beyond original1m body range does not count as hitting its carrier")
 app.hero_pos=Vector2(4,5.25);step(.35)
 check(a.phase=="recover" and app.rules.hp==100,"missed body kick leaves the original fixed swing, which host can avoid by actual movement")
 a=belt_scene();step(.925);app.rules.skill_states.KNEE.unlocked=true;app.rules.kick_until=0
 check(not app.rules.begin_kick({"direction":[-1,0]},true).ok and app.rules.hurt_left>0,"existing actual injury correctly prevents an immediate self-hit counter-kick")
 step(.3);app.hero_pos=Vector2(4.8,4);app.hero_facing=Vector2.LEFT;kick_body();step(.4)
 check(a.hp==45 and app.rules.hp==85 and app.rules.sp==75 and a.hits.has("hero"),"legal kick after original hurt expires preserves already-settled fifteen/five injury")
 a=belt_scene();step(.8);app.street.damage_actor("mother","warder",15,"declared_belt_hurt");step(.35)
 check(a.phase=="recover" and app.rules.hp==100,"actual carrier injury cancels active strip before first contact")
 a=belt_scene();step(.8);app.street.damage_actor("mother","warder",100,"declared_belt_death");step(.35)
 check(a.hp==0 and app.rules.hp==100 and app.street.belt.state().owner=="warder" and app.street.belt.state().sweep.is_empty(),"dead carrier retains its attached strap without independent damage or loot clone")
 a=belt_scene();step(.8);a.present=false;step(.35)
 check(app.rules.hp==100 and app.street.belt.state().sweep.is_empty(),"absent carrier leaves no independent airborne belt attack")
 a=belt_scene();step(.925);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("warder_belt");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.25)
 check(app.rules.hp==85 and app.rules.sp==75 and app.street.belt.state().owner=="warder","legacy missing pose cannot replay an already-paid shared belt receipt")
 a=belt_scene();a.phase="idle";app.hero_pos=Vector2(6,4);step(2.8)
 check(app.rules.hp==85 and a.hits.has("hero"),"autonomous approach stops inside actual strap reach rather than extra rectangle margin")
 a=belt_scene();app.hero_pos=Vector2(7,4);var neutral:Dictionary=actor_at("register_nurse",Vector2(5.25,4));step(1.15)
 check(neutral.hp==25 and a.hits.has("register_nurse"),"one actual strip uses existing once-per-target neutral contact and damage handler")
 a=belt_scene();app.street.layouts.erase("street_plaza");app.room_id="";app.enter_room("street_plaza");a.pos=[5.85,5.5];a.direction=[1,0];app.hero_pos=Vector2(10,5.5);app.street.belt.sync();step(1.15)
 check(app.street.belt.state().blocked and app.rules.hp==100,"original production fountain blocks the same belt and both arms")
 check(not app.layout.path(Vector2(5.8,3.5),Vector2(10,3.5)).is_empty() and not app.layout.path(Vector2(5.8,7.5),Vector2(10,7.5)).is_empty(),"actual fountain retains both existing bypass routes")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Explicit aligned/flank/direction/cabinet/neutral poses; paid CONTROL, effective/ineffective body kick, real JSON/manual pause/legacy, original production fountain. Same original15HP/5SP waist belt with no grip. Trial geometry, not natural crowd/manual/full B6/B7 or formal art acceptance."},"  "));file.close()
 print("STREET_BELT_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
