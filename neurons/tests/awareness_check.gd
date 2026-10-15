extends Node
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/awareness"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func step() -> void:
 if not app.dialogue_queue.is_empty():app.advance_dialogue();return
 app.advance_world(0.025)

func wait_clock(until_time:float) -> void:
 for i in range(600):
  if app.rules.world_time>=until_time:return
  step()

func contact(index:int) -> void:
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 app.hero_pos=app.layout.furniture[index].at;app.action_phase="autonomy"
 for i in range(20):
  if app.rules.search_active and app.target_index==index:return
  step()

func cast(id:String) -> void:
 app.rules.submit_skill(id,app.skill_context());app.apply_cast()

func capture(name:String) -> void:
 await frames();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="认知流程验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.home.enabled=false;app.family.enabled=false;app.paused_manual=true
 app.dialogue_queue.clear();app.show_dialogue()
 app.session.data.targets=[]
 for i in range(10):app.session.data.targets.append("bedroom:%d"%i)
 app.session.data.key_target="bedroom:9";app.session.data.key_owner="bedroom:9";app.rules.owners.key="bedroom:9"
 app.rules.unlock("GUT")
 for i in range(3):
  contact(0 if i==0 else 1)
  cast("SKIN")
  check(app.rules.evidence.size()==i+1,"real body reaction contributes one perception through campaign handler")
  if i<2:wait_clock(app.rules.cooldown_until+0.01)
 check(app.rules.awareness_stage==2,"formal campaign reaches awareness with two real object contexts and repeated skill")
 wait_clock(app.rules.cooldown_until+0.01)
 check(not app.rules.trial.is_empty(),"next actual autonomous behavior opens saved trial window")
 var saved:Dictionary=app.snapshot_data()
 var rng_state:String=str(app.rng.state)
 check(app.store.save_snapshot(saved).ok,"aware trial serial and reaction history write to actual save")
 var loaded:Dictionary=app.store.load_snapshot()
 check(loaded.ok and app.restore_snapshot(loaded.data) and str(app.rng.state)==rng_state,"loaded trial does not reroll public target or RNG")
 cast("GUT")
 check(app.rules.awareness_stage==3 and app.rules.intervention_lock,"actual contrary GUT reaction in trial recognizes and begins one-action refusal")
 var neurons:int=app.rules.neurons
 check(not app.rules.submit_skin().ok and app.rules.neurons==neurons,"recognition refusal never charges invalid cast")
 await capture("01_recognition_refusal")
 for i in range(600):
  if not app.rules.intervention_lock:break
  step()
 check(not app.rules.intervention_lock,"actual next autonomous action completion clears refusal")
 check(app.rules.known.all(func(x):return not str(x).contains("宿主")) and app.rules.institutional_records.is_empty(),"recognition does not reveal three-subject author truth or invent records")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"formal body/target/cognition handlers with fixed contact fixtures; not full natural human playthrough"},"  "))
 print("AWARENESS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
