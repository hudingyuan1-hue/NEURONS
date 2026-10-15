extends Node
const Neural=preload("res://scripts/core/neural_rules.gd")
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/family"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(n:int=3) -> void:
 for i in range(n):await get_tree().process_frame

func clear_lines() -> void:
 app.dialogue_queue.clear();app.show_dialogue()

func step(delta:float=0.025) -> void:
 clear_lines();app.advance_world(delta)

func until(predicate:Callable,steps:int=2500) -> bool:
 for i in range(steps):
  if predicate.call():return true
  step()
 return predicate.call()

func fixture(dog:bool=false,cat:bool=false) -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.family.data={};app.family.enabled=true
 app.family.config=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_rules.json"))
 app.family.config.probabilities.ordinary_nodes=[2,4,6,8]
 app.session.data.level=1;app.session.data.cycle=1;app.session.data.unlocked=[1];app.session.data.attempts={"1":1,"2":1}
 app.session.new_attempt(1,app.rng)
 app.session.data.targets=[]
 for i in range(10):app.session.data.targets.append("bedroom:%d"%i)
 app.session.data.key_target="bedroom:9";app.session.data.key_owner="bedroom:9"
 app.rules.owners.key="bedroom:9"
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.enter_room("bedroom");app.home.enabled=true
 app.home.start_attempt({"dog":dog,"cat":cat,"cat_point":1})
 app.family.start_attempt();app.family.data.extra_checked=true
 # Ordinary rolls disabled only to isolate specified parent branches below.
 app.family.config.probabilities.mother_base=0.0;app.family.config.probabilities.father_base=0.0
 app.hero_pos=app.layout.furniture[1].at
 app.paused_manual=true;clear_lines();app.menu.close_menu();app.closing_left=0

func capture(name:String) -> void:
 await frames();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func give_skill(id:String) -> void:
 app.rules.skill_states[id].unlocked=true
 app.rules.neurons=50

func cast(id:String) -> Dictionary:
 var context:Dictionary=app.skill_context()
 if id=="KNEE":context.direction=[app.hero_facing.x,app.hero_facing.y]
 var result:Dictionary=app.rules.submit_skill(id,context)
 app.apply_cast();return result

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames()
 frontend.name_field.text="父母规则验证";frontend.overwrite_armed=true;frontend.new_game();await frames()
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 fixture()
 app.rules.sp=80;app.family.spawn("mother")
 until(func():return app.family.data.mother.phase=="transfer")
 var pending_item:String=app.family.food_id("porridge")
 cast("SKIN")
 check(app.rules.owners[pending_item]=="mother" and app.family.data.inventory.is_empty(),"pre-contact intervention preserves mother's unique food ownership")
 check(until(func():return app.family.data.mother.phase=="request_rest"),"interrupted mother handoff retries approach and contact without cloning food")
 var delivered_item:String=app.family.data.inventory[0]
 give_skill("GUT");cast("GUT")
 check(app.rules.owners[delivered_item]=="hero" and app.family.data.inventory.size()==1,"post-handoff interruption preserves already-owned food")
 check(not app.family.data.mother_rest and app.family.data.mother.phase=="leave","GUT can interrupt current persuasion without premature rest unlock")
 fixture()
 app.rules.sp=80;app.family.spawn("mother")
 check(until(func():return app.family.data.mother.phase=="request_rest"),"low-SP mother actually approaches and completes handoff")
 check(app.family.data.inventory.size()==1 and app.rules.neurons==5 and app.rules.plexus==3 and app.rules.sp==80,"porridge receipt is inventory, never premature eating reward")
 check(app.session.data.level==1 and app.session.data.cycle==1,"mother entry and handoff do not unlock hospital early")
 await capture("01_mother_handoff")
 var item:String=app.family.data.inventory[0]
 check(app.rules.owners[item]=="hero","food has exactly one actual owner after handoff")
 check(app.family.request_food("porridge"),"player may request owned food before auto threshold")
 app.family.advance_eating(1.499)
 check(app.rules.sp==80 and app.rules.owners[item]=="hero","food is not consumed before 1.5-second completion")
 app.family.advance_eating(0.001)
 check(app.rules.sp==100 and app.rules.neurons==10 and app.rules.plexus==4 and app.rules.owners[item]=="consumed","porridge completion gives 5N and 1C exactly once")
 app.family.advance_eating(0.1) if not app.family.data.eating.is_empty() else null
 check(not app.family.request_food("porridge"),"consumed item cannot replay rewards")
 check(until(func():return app.session.data.level==2),"mother rest path reaches bed, completes actual rest, then unlocks hospital")
 check(app.session.data.cycle==2 and app.rules.actual_attempt==1 and app.rules.plexus==6,"rest adds one total cycle and hospital unlock reward once")
 fixture(true,false)
 app.family.data.gift_roll=0.65;app.family.spawn("mother")
 check(until(func():return not app.family.data.mother.present and not app.family.data.gift.is_empty()),"dog-only mother drops fixed gift then actually leaves")
 item=app.family.data.gift[0]
 check(app.family.data.food_types[item]=="chocolate" and app.rules.owners[item]=="floor","gift weights are fixed on placement; no automatic inventory")
 check(app.rules.neurons==5 and app.rules.plexus==3 and app.session.data.level==1,"door gift does not award resources or unlock level")
 check(app.family.request_gift(),"door gift can be requested through legal interaction")
 check(until(func():return app.family.data.gift.is_empty()),"hero actually walks to door and picks up gift")
 check(app.rules.owners[item]=="hero" and app.family.data.inventory.has(item),"gift transfers once from floor to hero")
 await capture("02_door_gift")
 fixture()
 app.family.spawn("mother")
 check(until(func():return not app.family.data.mother.present),"full-SP/no-animal mother refusal ends without invented gift")
 check(app.family.data.inventory.is_empty() and app.family.data.gift.is_empty(),"refusal creates no food")
 fixture(false,true)
 app.family.spawn("mother")
 check(until(func():return app.family.data.mother.phase=="request_rest"),"full-SP/cat mother approaches cat then gives chocolate")
 check(app.rules.hp==100 and not app.home.data.fighting and app.home.data.cat.phase=="leave","mother eviction never triggers player scare damage")
 await capture("03_mother_cat")
 fixture(true,false)
 app.family.spawn("father")
 check(until(func():return not app.home.data.dog.alive),"dog-only father plot effect kills dog from doorway, no combat HP gate")
 check(not app.family.data.father.present and app.rules.pending_global_growth==1 and app.rules.global_resistance==0,"dog awakening queues global resistance for next actual attempt only")
 app.rules.record_awakening("dog_death")
 check(app.rules.pending_global_growth==1,"dog awakening cannot duplicate")
 await capture("04_dog_plot")
 fixture(false,true)
 app.family.spawn("father")
 check(until(func():return app.family.data.father.phase=="think"),"father actually reaches and holds cat before persuasion")
 check(app.home.data.cat.phase=="held" and app.family.data.blood_door,"persuasion preserves one held cat and blood-door state")
 give_skill("GUT");cast("GUT")
 check(app.family.data.father.phase=="leave" and not app.family.data.blood_door,"successful body reaction interrupts thought and expels father")
 check(app.rules.awakening_receipts.is_empty(),"speculative awakening dialogue cannot create formal awakening")
 check(until(func():return not app.family.data.father.present),"father actually leaves with same held cat")
 check(not app.home.present("cat"),"held cat is not duplicated as window departure")
 fixture()
 app.hero_pos=Vector2(2.9,2.3)
 app.family.spawn("father")
 check(until(func():return app.family.data.father.phase=="grab"),"father approaches for at least preparation window before grab windup")
 check(not app.rules.gripped and app.family.world_rate()==0.5,"windup not immediate grip and all world actions use half-rate clock")
 check(until(func():return app.rules.gripped),"actual in-range grab closes after visible windup")
 await capture("05_father_grip")
 var balance:int=app.rules.neurons
 give_skill("WITHDRAW");balance=app.rules.neurons
 check(not app.rules.submit_skill("WITHDRAW",app.skill_context()).ok and app.rules.neurons==balance,"ordinary withdraw cannot undo established father grip or charge invalid action")
 give_skill("STARTLE")
 app.hero_facing=(app.family.position("father")-app.hero_pos).normalized()
 var sp:int=app.rules.sp
 check(cast("STARTLE").ok,"father-specific held startle remains an eligible paid rescue")
 check(app.rules.gripped,"submitted reflex does not free body before actual motion")
 check(until(func():return app.motion.is_empty()),"special escape finishes actual backward movement")
 check(not app.rules.gripped and app.rules.sp>=mini(100,sp+5)-1 and app.family.data.blood_door,"startle buys one real escape and SP, keeps blood-door threat")
 fixture()
 app.family.spawn("father");until(func():return app.rules.gripped)
 app.hero_pos=Vector2(0.905,1.85) # Explicit flush-to-cabinet fixture: next 2cm step is blocked.
 give_skill("STARTLE");app.hero_facing=Vector2.RIGHT
 sp=app.rules.sp;cast("STARTLE");step(0.05)
 check(app.rules.gripped and app.rules.sp<=sp,"blocked actual backward path grants neither free release nor SP reward")
 for successful in [true,false]:
  fixture();app.hero_pos=Vector2(2.9,2.3)
  app.family.spawn("father");until(func():return app.rules.gripped)
  give_skill("KNEE");app.hero_facing=(app.family.position("father")-app.hero_pos).normalized()
  var probe:=RandomNumberGenerator.new()
  for seed_value in range(100):
   probe.seed=seed_value
   var state:int=probe.state
   if (probe.randf()<0.7)==successful:app.rng.state=state;break
  sp=app.rules.sp;cast("KNEE")
  check(until(func():return app.rules.settled.has("kick:1:1:father")),"knee reaches actual directional contact before rescue probability")
  check((not app.rules.gripped)==successful,"seventy-percent father knockback has both real success and failure paths")
  check(app.rules.sp>=mini(100,sp+10)-1 if successful else app.rules.sp<=sp,"only successful knee knockback restores ten SP")
 fixture()
 app.family.spawn("father");until(func():return app.rules.gripped)
 give_skill("JOY");cast("JOY")
 check(not app.rules.gripped and not app.family.data.blood_door and app.family.data.rescued,"actual high-level rescue releases father grip and restores ordinary door")
 check(until(func():return app.session.data.level==2),"rescued protagonist actually reaches ordinary exit without requiring key")
 fixture()
 app.family.spawn("father")
 check(until(func():return app.family.data.hidden_pending),"unrescued father follows real route until hero reaches blood door")
 check(app.hero_pos.distance_to(app.layout.DOOR)<0.13 and app.session.data.level==1,"hidden route is explicit B2 boundary, never fake hospital transfer")
 await capture("06_blood_door_boundary")
 fixture()
 app.family.spawn("mother");clear_lines();app.family.spawn("father")
 check(app.family.collapse_active() and app.rules.hp==0 and app.rules.sp==0,"only actual co-present parents lock exclusive collapse")
 var saved:Dictionary=app.snapshot_data();var original_id:int=app.invader_id
 check(app.restore_snapshot(saved) and app.family.collapse_active(),"mid-collapse save/load restores exclusive presentation without reroll")
 app.family.advance_collapse(1.5)
 await capture("07_collapse")
 var complete:bool=false
 for i in range(100):
  if app.family.advance_collapse(0.1):complete=true;break
 check(complete,"eight original collapse captions finish exclusive sequence")
 app.restart_attempt(3,true)
 check(app.session.data.cycle==4 and app.rules.actual_attempt==2 and app.invader_id==original_id+1,"collapse revival adds three total cycles, one attempt, one invader ID")
 check(app.rules.hp==100 and app.rules.sp==100 and app.rules.global_resistance==1,"collapse awakening commits once on real revival, not twice")
 fixture()
 app.family.config.probabilities.mother_base=1.0;app.family.config.probabilities.father_base=1.0
 app.family.on_node("forced_ordinary",true)
 check(app.family.data.queued.size()==1 and not app.family.collapse_active(),"same-node two successes queue second parent, not imaginary co-presence")
 var rng_state:String=str(app.rng.state)
 app.family.on_node("forced_ordinary",true)
 check(str(app.rng.state)==rng_state,"replayed probability node never rerolls")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"formal entry with deterministic parent/animal fixtures; original RNG table retained in production; not human playthrough"},"  "))
 print("FAMILY_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
