extends "res://tests/feedback_check.gd"
## Explicit last B1 acceptance gaps; deterministic contact fixtures only.
func _ready() -> void:
 folder="res://../docs/validation/takeover_20261016/acceptance"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="B1整批边界验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 for kind in ["swallow","exit","rest"]:
  fixture(false,true);app.rules.hp=10;app.rules.sp=70
  var item:String=""
  if kind=="swallow":
   item=food("chocolate");app.family.request_food("chocolate");app.family.advance_eating(1.49)
  elif kind=="exit":
   app.session.data.key_seen=true;app.session.data.key_owner="hero";app.rules.owners.key="hero"
   app.hero_pos=app.layout.DOOR;app.action_phase="opening";app.action_left=0.01;app.destination="lobby"
  else:app.action_phase="resting";app.action_left=0.01
  app.home.data.cat.phase="attack";app.home.data.cat.left=0.01;app.home.data.cat.pos=app.home.xy(app.hero_pos)
  var balance:int=app.rules.neurons;var attempt:int=app.rules.actual_attempt;var cycle:int=app.session.data.cycle
  app.advance_world(0.01)
  check(app.rules.hp==0 and app.session.data.level==1 and app.session.data.cycle==cycle and app.rules.actual_attempt==attempt,"fatal actual cat contact wins same-node "+kind)
  check(app.rules.neurons==balance,"fatal "+kind+" cannot pay late recovery/unlock/search income")
  if kind=="swallow":check(app.rules.owners[item]=="hero" and not app.family.data.has("food_feedback"),"fatal swallow leaves unconsumed chocolate and no taste feedback")
  var saved:Dictionary=app.snapshot_data();app.store.save_snapshot(saved);var loaded:Dictionary=app.store.load_snapshot()
  check(loaded.ok and app.restore_snapshot(loaded.data) and app.rules.hp==0,"fatal "+kind+" JSON restore stays dead before real revival")
  app.advance_world(0.01)
  check(app.rules.hp==0 and app.session.data.level==1 and app.rules.neurons==balance,"fatal "+kind+" cannot replay late completion after load")
  await capture("fatal_"+kind)
 fixture(true,false)
 app.family.enabled=false
 app.hero_pos=app.layout.furniture[1].at;app.target_index=1
 app.rules.begin_search("bedroom:1");app.rules.search_elapsed=app.rules.search_duration-0.01
 app.home.data.dog.phase="bring";app.home.data.dog.remaining=0;app.home.data.dog.pos=app.home.xy(app.hero_pos)
 app.session.data.key_owner="dog";app.rules.owners.key="dog"
 var income_before:int=app.rules.neurons;var count_before:int=app.rules.search_count
 app.advance_world(0.01)
 check(app.rules.neurons==income_before+1 and app.rules.search_count==count_before+1 and "bedroom:1" in app.completed,"same-node dog key handoff preserves genuinely completed hero search income")
 check(app.has_key() and app.rules.owners.key=="hero" and not app.rules.search_active,"actual dog contact transfers unique key after completed search verdict")
 var simultaneous:Dictionary=app.snapshot_data();app.store.save_snapshot(simultaneous)
 var restored:Dictionary=app.store.load_snapshot();app.restore_snapshot(restored.data);app.advance_world(0.01)
 check(app.rules.neurons==income_before+1 and app.rules.owners.key=="hero","JSON replay of concurrent completion and key transfer cannot repay income or duplicate key")
 fixture(true,false);app.family.enabled=false
 app.hero_pos=app.layout.furniture[1].at;app.target_index=1
 app.rules.begin_search("bedroom:1");app.rules.search_elapsed=1.0
 app.home.data.dog.phase="bring";app.home.data.dog.remaining=0;app.home.data.dog.pos=app.home.xy(app.hero_pos)
 app.session.data.key_owner="dog";app.rules.owners.key="dog";income_before=app.rules.neurons
 app.advance_world(0.01)
 check(app.has_key() and not app.rules.search_active and app.rules.neurons==income_before,"same dog contact cancels a genuinely unfinished search without late income")
 for sp in [80,100]:
  for dog in [false,true]:
   for cat in [false,true]:
    fixture(dog,cat);app.rules.sp=sp;app.family.spawn("mother")
    var reached:bool=until(func():return app.family.data.mother.phase not in ["intro","enter"])
    check(reached,"mother choice reaches real response SP%d dog%s cat%s"%[sp,dog,cat])
    var branch:String=str(app.family.data.mother.get("branch",""))
    # Completion is checked by existing family tests. Here the finite input
    # matrix ensures the choice preserves SP priority and actual participants.
    if sp<100:check(branch=="porridge","low-SP mother chooses porridge before animal alternatives")
    elif cat:check(branch=="chocolate","full-SP mother chooses existing cat eviction")
    elif dog:check(branch=="gift","full-SP dog alone chooses doorway gift")
    else:check(app.family.data.mother.phase=="leave","full-SP empty room chooses refusal")
 for dog in [false,true]:
  for cat in [false,true]:
   fixture(dog,cat);app.family.spawn("father")
   var reached:bool=until(func():return app.family.data.father.phase not in ["intro","enter"])
   check(reached,"father branch reaches real decision dog%s cat%s"%[dog,cat])
   if cat and not dog:check(app.family.data.father.phase in ["cat_approach","think"],"only-cat father uses cat thought branch")
   elif dog and not cat:check(app.family.data.father.phase=="kill_dog","only-dog father uses L1 plot effect branch")
   else:check(app.family.rescue_context(),"empty/both-animal father starts actual abduction")
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"deterministic finite parent choice matrix and fatal contact aligned with swallow/exit/rest, actual JSON restore; not human play or later combat"},"  "));output.close()
 print("B1_ACCEPTANCE %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
