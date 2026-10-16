extends "res://tests/asylum_ward_check.gd"
## Single stated initial fixture, ordinary _process and actual UI input after it.
func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/recording"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="作业抽屉实机记录"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 ward_fixture("workshop");app.session.data.exploration_boundary=false
 app.session.data.targets=["workshop:6","stairs:0"];app.session.data.key_target="stairs:0";app.session.data.key_owner="stairs:0";app.rules.owners.key="stairs:0"
 app.hero_pos=Vector2(4.4,2.35);actor3("supervisor","workshop",Vector2(4.4,2.75));give_skill("WITHDRAW")
 var initial:Dictionary=app.snapshot_data();var started:int=Engine.get_process_frames();var stage:int=0
 var observations:Array=[];var previous:String="";app.paused_manual=false
 for index in range(1200):
  var state:Dictionary=ward_state().clamp
  var signature:String=JSON.stringify([state.phase,app.rules.hp,app.rules.search_active,app.rules.reaction_left>0,app.menu.visible])
  if signature!=previous:
   observations.append({"frame":Engine.get_process_frames()-started,"game_time":app.rules.world_time,"clamp":state.duplicate(true),"hero":[app.hero_pos.x,app.hero_pos.y],"hp":app.rules.hp,"sp":app.rules.sp,"neurons":app.rules.neurons,"search_attempts":app.rules.search_attempts,"phase":app.action_phase,"menu":app.menu.visible});previous=signature
  if not app.dialogue_queue.is_empty():await continue_live_line();continue
  if stage==0 and state.phase=="windup":
   await capture("01_visible_closing_preparation");app.open_neuron_menu();await click(app.menu.nodes.WITHDRAW);stage=1
  elif stage==1 and state.phase=="done" and app.rules.reaction_left<=0:
   await capture("02_real_withdraw_misses_clamp");stage=2
  elif stage==2 and "workshop:6" in app.completed:
   await capture("03_autonomy_resumed_and_search_finished");stage=3;await frames(15);break
  await frames(1)
 app.paused_manual=true
 check(stage==3,"ordinary process with real CRT mouse intervention resumes autonomous search to completion")
 check(app.rules.hp==100 and rec3("drawer_attempt") and not rec3("drawer_hurt"),"visible actual withdrawal avoids clamp without invented injury or removing one-attempt receipt")
 check(app.rules.neurons==int(initial.rules.neurons)-int(app.rules.spec("WITHDRAW").cost)+1,"real UI intervention pays once and only eventual finished search gives one neuron")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"observations":observations,"frames":Engine.get_process_frames()-started,"scope":"continuous ordinary _process after initial stated workshop/actor/50N/unlocked-WITHDRAW/two-target fixture; actual Enter and CRT mouse; no manual world tick after setup, silent MovieMaker capture, not human natural-RNG/formal-art/audio acceptance"},"  "));file.close()
 print("ASYLUM_RECORD_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
