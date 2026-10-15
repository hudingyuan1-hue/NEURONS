extends "res://tests/family_check.gd"
## Fixed game-time/actor fixtures through existing handlers. UI input is checked
## separately by status_check; this suite records the original-line event order.
var transcript:Array=[]

func clear_lines() -> void:
 if app!=null:
  for line in app.dialogue_queue:transcript.append(line.duplicate(true))
 super.clear_lines()

func said(text:String) -> bool:
 for line in transcript:
  if line.text==text:return true
 return false

func _ready() -> void:
 folder="res://../docs/validation/status_20261015/family_sequence"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames()
 frontend.name_field.text="父母原句顺序验证";frontend.overwrite_armed=true;frontend.new_game();await frames()
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture();transcript.clear()
 var covered:Dictionary={}
 for seed_value in range(80):
  app.rng.seed=seed_value;app.family.data.dialogue_choices={}
  for id in app.family.dialogue:
   app.family.cue(id)
   var index:int=int(app.family.data.dialogue_choices[id])
   covered[id+":"+str(index)]=true
   var prior_state:int=app.rng.state
   app.family.cue(id)
   if seed_value==0:check(app.rng.state==prior_state,"chosen variant never rerolls: %s / seed %d"%[id,seed_value])
   if app.rng.state!=prior_state:failures.append("variant changed RNG after initial selection")
   clear_lines()
 var expected:int=0
 for id in app.family.dialogue:expected+=app.family.dialogue[id].lines.size()
 check(covered.size()==expected,"fixed seeds cover every original family random alternative")
 var variants:Dictionary=app.family.data.dialogue_choices.duplicate(true)
 var save:Dictionary=app.snapshot_data()
 check(app.store.save_snapshot(save).ok,"chosen dialogue alternatives save through JSON store")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data) and app.family.data.dialogue_choices==variants,"JSON load retains every chosen alternative without reroll")

 fixture();transcript.clear()
 var animal_covered:Dictionary={}
 var replay_ok:bool=true
 for seed_value in range(100):
  app.rng.seed=seed_value;app.home.data.dialogue_choices={};app.home.data.dialogue_played={}
  for id in app.home.dialogue:
   app.home.cue(id,"coverage")
   animal_covered[id+":"+str(int(app.home.data.dialogue_choices[id+":coverage"]))]=true
   var prior_state:int=app.rng.state
   var queue_size:int=app.dialogue_queue.size()
   app.home.cue(id,"coverage")
   if app.rng.state!=prior_state or app.dialogue_queue.size()!=queue_size:replay_ok=false
   clear_lines()
 expected=0
 for id in app.home.dialogue:expected+=app.home.dialogue[id].variants.size()
 check(animal_covered.size()==expected,"fixed seeds cover all dog/cat/combined/start original alternatives")
 check(replay_ok,"same animal dialogue node does not replay or reroll")
 for group in app.home.dialogue.DOG_OPEN.variants:
  check((group[0].text=="啊...大黄怎么在这?" and group[1].text in ["... ...","我也想知道"]) or (group[0].text.contains("黄色生物") and group[1].text in ["要不要跳过认亲现场啊喂...","???装可爱呢"]),"dog A/B entry retains paired player response")
 app.home.data.dialogue_played={};app.home.data.dialogue_choices={};app.rules.actual_attempt=4
 app.home.start_exploration_line()
 check(app.dialogue_queue.size()==1 and app.dialogue_queue[0].text in ["继续","该做正事了!"],"later attempts select short original start line rather than early theatrical introduction")
 save=app.snapshot_data();app.store.save_snapshot(save);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 clear_lines();var old_rng:int=app.rng.state;app.home.start_exploration_line()
 check(app.dialogue_queue.is_empty() and app.rng.state==old_rng,"restored already-spoken search opening cannot replay or reroll")

 fixture();transcript.clear();app.rules.sp=80
 app.family.spawn("mother")
 check(not app.family.data.dialogue_choices.has("MOTHER_CONDITION") and app.family.data.inventory.is_empty(),"door entry does not speak close-up health line or give food remotely")
 check(until(func():return app.family.data.mother.phase=="comfort"),"mother actually navigates to hero before health concern")
 check(app.family.position("mother").distance_to(app.hero_pos)<=0.4,"health exchange starts at real contact distance")
 clear_lines();app.advance_world(0.2)
 check(app.family.data.mother.phase=="comfort" and app.hero_state=="scratch","head scratch has visible game-time action before response")
 await capture("01_head_scratch")
 var elapsed:float=app.family.data.mother.elapsed
 await frames(12)
 check(app.family.data.mother.elapsed==elapsed,"paused head-scratch animation does not advance its action clock")
 save=app.snapshot_data();check(app.store.save_snapshot(save).ok,"mid-head-scratch action saves")
 disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 check(is_equal_approx(float(app.family.data.mother.elapsed),elapsed),"head-scratch elapsed phase survives actual JSON reload")
 check(until(func():return app.family.data.mother.phase=="transfer"),"scratch ends before original response and rest request")
 check(app.family.data.dialogue_choices.has("HERO_CONDITION") and app.family.data.dialogue_choices.has("MOTHER_REST"),"missing hero response and both rest alternatives are connected")
 var item:String=app.family.food_id("porridge")
 check(app.rules.owners.get(item,"")=="mother" and app.family.data.inventory.is_empty(),"prepared porridge remains uniquely mother-owned before handoff")
 check(until(func():return app.family.data.mother.phase=="request_rest"),"original give-porridge line waits for real transfer completion")
 check(app.rules.owners[item]=="hero" and app.status_note=="你获得一碗粥" and not said("妈妈给你熬了粥 喝了休息吧"),"acquisition message and ownership occur before queued post-handoff speech")
 clear_lines()
 check(said("妈妈给你熬了粥 喝了休息吧"),"post-handoff original porridge line is retained")
 check(until(func():return app.action_phase=="resting" and app.family.data.mother.get("bed_line_shown",false)),"mother route reaches bed and lies down before good-child closing line")
 check(app.session.data.level==1 and not app.dialogue_queue.is_empty() and app.dialogue_queue[0].text=="乖孩子...","good-child original line precedes actual rest/unlock completion")
 check(app.hero_pos.distance_to(app.layout.BED_STOP)<0.035 and float(app.view.rest_pose().t)>0.99,"lying presentation attaches only after actual bed approach")
 check(app.view.hero_body_rect().get_center().distance_to(app.layout.project(app.hero_pos))>30,"bed pose has matching separate body click region")
 await capture("02_bed_closing_line")
 check(until(func():return app.session.data.level==2),"rest completes and unlocks hospital after its original closing line")

 fixture(false,true);transcript.clear();app.family.spawn("mother")
 check(until(func():return app.family.data.mother.phase=="wait_cat_exit"),"mother has explicit wait for actual cat departure")
 check(app.home.present("cat") and app.home.data.cat.phase=="leave" and app.family.data.inventory.is_empty(),"moving cat cannot be replaced by instant disappearance or early chocolate")
 step() # Begin the actual departure path before the mid-motion save.
 save=app.snapshot_data();app.store.save_snapshot(save);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 check(app.family.data.mother.phase=="wait_cat_exit" and not app.home.data.cat.route.is_empty(),"mid-eviction JSON reload retains mother's wait and cat route")
 check(until(func():return app.family.data.mother.phase=="request_rest"),"cat actually exits before mother walks back and hands chocolate")
 check(not app.home.present("cat") and app.rules.hp==100 and said("喵@#￥%……"),"eviction retains cat's original exit line and causes no scratch")
 clear_lines();check(said("谢谢妈"),"original thank-you follows completed chocolate handoff")
 await capture("03_cat_gone_chocolate")

 fixture(false,true);transcript.clear();app.family.spawn("mother")
 until(func():return app.family.data.mother.phase=="wait_cat_exit")
 app.family.spawn("father")
 check(app.family.collapse_active() and app.family.data.inventory.is_empty(),"actual father arrival during eviction takes exclusive collapse without unearned chocolate")
 check(app.action_phase=="collapse" and app.action_left==0,"exclusive collapse cancels pending ordinary action/presentation phase")
 var before:int=int(app.session.data.cycle)
 app.paused_manual=false
 for i in range(400):
  if not app.family.collapse_active():break
  await frames(1)
 app.paused_manual=true
 check(not app.family.collapse_active(),"interrupted eviction collapse reaches one real revival")
 check(app.session.data.cycle==before+3 and app.family.data.inventory.is_empty(),"collapse cannot complete old eviction transfer after revival")

 fixture(false,true);transcript.clear();app.family.spawn("father")
 check(until(func():return app.family.data.father.phase=="think"),"father physically holds cat before selected questioning alternative")
 give_skill("TEMP");cast("TEMP")
 check(app.family.data.father.phase=="leave" and not said("话说...这家伙不会因此[觉醒]吧"),"successful thinking interruption starts departure before reflection")
 clear_lines()
 check(not said("他绝对不是我父亲 我在他身上感受到无比浓重的[恶意]...这是怎么回事...难道?"),"post-departure realization is not spoken while father still present")
 save=app.snapshot_data();app.store.save_snapshot(save);disk=app.store.load_snapshot();app.restore_snapshot(disk.data)
 check(app.family.data.father.get("departure_reflection_pending",false),"departure continuation saves without premature reflection")
 check(until(func():return not app.family.present("father")),"father really walks out carrying cat")
 clear_lines()
 check(not app.home.present("cat") and said("话说...这家伙不会因此[觉醒]吧"),"original three reflection lines follow actual father/cat exit")
 var count_before:int=transcript.size();step();clear_lines()
 check(transcript.size()==count_before and app.rules.awakening_receipts.is_empty(),"departure replay cannot repeat reflection or award dialogue-implied awakening")
 await capture("04_father_departed")

 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"transcript":transcript,"scope":"fixed household branch/clock fixtures, actual movement/contact/save handlers; UI input covered separately; no full B1 acceptance"},"  "));result.close()
 print("FAMILY_SEQUENCE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

