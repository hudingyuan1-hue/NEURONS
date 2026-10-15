extends "res://tests/feedback_check.gd"
## Finite adverse combinations, deterministic probabilities/contact alignment.
## Threshold interventions use real CRT mouse input and ordinary world frames.

func snapshot_roundtrip() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var loaded:Dictionary=app.store.load_snapshot()
 return loaded.ok and app.restore_snapshot(loaded.data)

func _ready() -> void:
 folder="res://../docs/validation/feedback_20261015/home-adverse"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="首关不利组合验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 var orders:Dictionary={}
 for seed_value in range(20):
  fixture();app.family.config.probabilities.mother_base=1;app.family.config.probabilities.father_base=1
  app.family.data.actions=1;app.family.data.extra_checked=false
  app.session.data.targets=["bedroom:1"];app.hero_pos=app.layout.furniture[1].at
  # Receipt is produced by a real search, then consumed by the ordinary-node dispatcher.
  until(func():return app.rules.search_active)
  app.rng.seed=seed_value
  var dispatched:bool=until(func():return not app.family.data.queued.is_empty())
  if seed_value<2:check(dispatched,"real second search-settlement dispatch queues another parent / seed %d"%seed_value)
  if app.family.data.queued.is_empty():failures.append("ordinary queue unreachable");break
  var first:String=str(app.family.data.spawn_order[0])
  if orders.has(first):continue
  orders[first]=true
  check(not app.family.collapse_active() and app.family.data.spawn_order.size()==1,"dual ordinary successes do not invent co-presence before second event node")
  var queue:Array=app.family.data.queued.duplicate()
  var rng_state:int=app.rng.state
  check(snapshot_roundtrip() and app.family.data.queued==queue and app.rng.state==rng_state,"queued parent/order/RNG survive actual JSON save before entry response")
  check(until(func():return app.family.collapse_active()),"next actual parent-entry node creates co-presence and collapse")
  check(app.family.data.spawn_order.size()==2 and app.family.data.inventory.is_empty(),"no unfinished handoff is issued by dual-parent collapse")
  await capture("01_queued_"+first+"_first")
  if orders.size()==2:break
 check(orders.size()==2,"both real mother-first and father-first ordinary queues covered")

 fixture();app.rules.sp=80;app.family.spawn("mother")
 until(func():return app.family.data.mother.phase=="transfer")
 app.family.data.extra_checked=false;app.family.config.probabilities.extra_base=1
 app.family.data.checks.erase("mother_handoff")
 check(until(func():return app.family.collapse_active()),"other parent can arrive at real handoff completion node")
 var porridge:String=app.family.food_id("porridge")
 check(app.rules.owners.get(porridge,"")=="hero" and app.family.data.inventory.has(porridge),"already-completed transfer survives same-node collapse")
 var count:int=app.family.data.inventory.count(porridge)
 check(snapshot_roundtrip() and app.family.data.inventory.count(porridge)==count,"collapse save/reload cannot duplicate already-owned food")

 fixture(false,true);app.rules.sp=60
 var item:String=food("candy");app.family.request_food("candy")
 app.family.advance_eating(1.49)
 # Explicit transaction-boundary fixture: actual cat contact on the last 0.01s.
 app.home.data.cat.phase="attack";app.home.data.cat.left=0.01;app.home.data.cat.pos=app.home.xy(app.hero_pos)
 var balance:int=app.rules.neurons
 app.advance_world(0.01)
 check(app.rules.hp==90 and app.rules.sp==50 and app.rules.owners[item]=="hero","same-frame cat hit interrupts swallow before spending food or healing")
 check(app.rules.neurons==balance and app.family.data.eating.is_empty() and not app.family.data.has("food_feedback"),"cat-interrupted food grants no income or completion feedback")
 var hp:int=app.rules.hp
 check(snapshot_roundtrip(),"cat/food boundary writes and reloads actual transaction state")
 step(0.05)
 check(app.rules.hp==hp and app.rules.owners[item]=="hero","load does not replay cat hit or late food consumption")
 await capture("02_cat_interrupts_swallow")

 fixture(false,true);app.rules.sp=80;app.family.spawn("mother")
 until(func():return app.family.data.mother.phase=="transfer")
 clear_lines();app.family.data.mother.elapsed=float(app.family.config.test_parameters.transfer_duration)-0.01
 app.family.data.mother.pos=app.family.xy(app.hero_pos+Vector2(0.25,0))
 app.home.data.cat.phase="attack";app.home.data.cat.left=0.01;app.home.data.cat.pos=app.home.xy(app.hero_pos)
 porridge=app.family.food_id("porridge");app.advance_world(0.01)
 check(app.rules.hp==90 and app.rules.owners.get(porridge,"")=="mother" and app.family.data.inventory.is_empty(),"cat hit at handoff boundary interrupts transfer before unique ownership changes")
 check(app.family.data.mother.phase=="approach","interrupted mother must approach/contact again rather than late-deliver")

 fixture();item=food("candy");app.audio.reset_scene();app.audio.set_world_paused(false)
 app.family.request_food("candy");app.family.advance_eating(0.2)
 var serial:int=app.family.data.eating.serial
 cast("SKIN");step(0.6);clear_lines();app.audio.set_world_paused(false)
 check(app.family.data.eating.is_empty() and app.rules.owners[item]=="hero","actual neural interruption preserves same unconsumed food")
 app.family.request_food("candy");app.family.advance_eating(0.2)
 var starts:int=0
 for entry in app.audio.starts:
  if entry.id=="SFX_SEARCH_CLOTH" and str(entry.event).begins_with("eat_prepare:"):starts+=1
 check(starts==2 and int(app.family.data.eating.serial)>serial,"retry has a distinct preparation sound event without a new consumption receipt")
 check(snapshot_roundtrip(),"preparation attempt counter survives real save")
 var current_serial:int=app.family.data.eating.serial
 app.family.data.eating.clear();app.restart_attempt(1,false);clear_lines()
 app.family.request_food("candy")
 check(int(app.family.data.eating.serial)>current_serial,"unused carried food keeps monotonic preparation attempts across new actual attempts")

 for success in [true,false]:
  fixture(false,true);app.family.spawn("father");until(func():return app.family.data.father.phase=="think")
  clear_lines();give_skill("TEMP");app.rules.sp=60;app.family.data.pressure=0.99
  app.rules.skill_states.TEMP.resistance=0 if success else int(app.rules.skill_states.TEMP.power)
  app.paused_manual=false;app.open_neuron_menu();get_window().grab_focus()
  var before:int=app.rules.neurons
  await click(app.menu.nodes.TEMP)
  var queued:bool=false
  for i in range(60):
   if not app.rules.pending_neural.is_empty():queued=true;break
   await frames(1)
  check(queued and app.closing_left>0 and app.rules.sp==60,"actual CRT submission freezes threshold while closing / success "+str(success))
  var paid:int=app.rules.neurons
  check(snapshot_roundtrip() and app.rules.neurons==paid,"queued paid intervention reloads without second charge")
  for i in range(100):
   if app.rules.pending_neural.is_empty() and app.closing_left<=0:break
   await frames(1)
  app.paused_manual=true
  if success:
   check(app.family.data.father.phase=="leave" and app.rules.sp==60 and not app.family.data.system_prompts.has("FATHER_LOW_SP"),"successful effect expels father before same-node pressure crosses threshold")
  else:
   check(app.family.data.father.phase=="approach" and app.rules.sp==59 and app.family.data.system_prompts.has("FATHER_LOW_SP"),"resistance permits actual threshold crossing and one forced-follow prompt")
  check(paid==before-int(app.rules.spec("TEMP").cost) and app.rules.neurons==paid,"threshold result consumes one configured fee / success "+str(success))
  await capture("03_threshold_"+str(success))

 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"finite deterministic ordinary-parent probability/order fixtures; explicit cat contact alignment at transaction boundary; real CRT threshold input, closing and JSON resume; not exhaustive infinite combinations or human full play"},"  "));output.close()
 print("HOME_ADVERSE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

