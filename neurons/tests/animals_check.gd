extends Node
const Neural=preload("res://scripts/core/neural_rules.gd")
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/animals"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(n:int=3) -> void:
 for i in range(n):await get_tree().process_frame

func clear_lines() -> void:
 app.dialogue_queue.clear();app.show_dialogue()

func advance(seconds:float) -> void:
 for i in range(ceili(seconds/0.025)):
  clear_lines();app.advance_world(minf(0.025,seconds-i*0.025))

func until(predicate:Callable,steps:int=2000) -> bool:
 for i in range(steps):
  if predicate.call():return true
  clear_lines();app.advance_world(0.025)
 return predicate.call()

func fixture(dog:bool,cat:bool) -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session.data.level=1;app.session.data.unlocked=[1]
 app.session.new_attempt(1,app.rng)
 app.session.data.targets=[]
 for i in range(10):app.session.data.targets.append("bedroom:%d"%i)
 app.session.data.key_target="bedroom:9";app.session.data.key_owner="bedroom:9"
 app.rules.owners.key=app.session.data.key_owner
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.enter_room("bedroom");app.home.enabled=true
 app.home.start_attempt({"dog":dog,"cat":cat,"cat_point":1})
 app.hero_pos=app.layout.furniture[1].at
 app.paused_manual=true;clear_lines();app.menu.close_menu();app.closing_left=0

func capture(name:String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames()
 frontend.name_field.text="动物规则验证";frontend.overwrite_armed=true;frontend.new_game();await frames()
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 app.family.enabled=false # Separate family branch suite owns these fixtures.
 fixture(true,false)
 check(until(func():return app.home.data.dog.phase=="walk"),"dog autonomously chooses reachable open point after hero search begins")
 var dog_point:int=int(app.home.data.dog.target)
 check(dog_point!=app.target_index and dog_point in [0,2,10],"dog chooses a different exposed point, never sealed cabinet")
 # Set the already-chosen dog's point to key for this delivery fixture. The
 # choice happened first; normal game key sampling is unchanged.
 app.session.data.key_target="bedroom:%d"%dog_point
 app.session.data.key_owner=app.session.data.key_target;app.rules.owners.key=app.session.data.key_owner
 check(until(func():return app.home.data.dog.phase=="search"),"dog actually walks before sniffing")
 await capture("01_dog_search")
 check(until(func():return app.home.data.dog.phase=="bring"),"dog completes real search and holds discovered key")
 check(app.rules.owners.key=="dog" and not app.has_key(),"key held by dog is not prematurely delivered to hero")
 await capture("02_dog_key")
 check(until(func():return app.has_key()),"dog actually returns and transfers key at contact")
 check(app.rules.owners.key=="hero" and app.session.data.key_owner=="hero","dog and hero share one key ownership record")
 var receipt:String="dog_search:%d:bedroom:%d"%[app.rules.actual_attempt,dog_point]
 check(app.rules.settled.has(receipt) and app.completed.count("bedroom:%d"%dog_point)==1,"dog search has one shared completion receipt")
 var before:int=app.rules.neurons
 app.home.tick(0.01)
 check(app.rules.neurons==before,"dog completion replay cannot duplicate reward")
 fixture(false,true)
 check(until(func():return app.rules.search_active and app.target_index==1),"hero really starts attempted search at occupied cat point")
 var attempts:int=app.rules.search_attempts
 app.rules.skin_resistance=1
 app.rules.submit_skin();app.apply_cast()
 check(app.home.data.cat.phase=="occupy" and app.rules.search_active,"resisted skill neither scares cat nor cancels search")
 advance(0.6)
 check(app.rules.search_attempts>=attempts and app.rules.search_count==0 and app.home.data.cat.rounds==1,"cat block consumes existing opportunity without reward or completion")
 check(until(func():return app.home.data.cat.phase=="leave"),"third actual hero action settlement starts cat departure")
 check(app.home.data.cat.rounds==3,"walking and dog actions do not count as extra cat rounds")
 fixture(false,true)
 check(until(func():return app.rules.search_active and app.target_index==1),"fresh cat scare fixture reaches real contact")
 app.rules.submit_skin();app.apply_cast()
 check(app.home.data.cat.phase=="attack" and not app.rules.search_active,"scare uses pre-interruption search object snapshot")
 await capture("03_cat_scare")
 advance(0.6)
 check(app.rules.hp==90 and app.rules.sp==90,"cat actual contact deals exactly ten HP and SP once")
 var health:int=app.rules.hp;advance(1)
 check(app.rules.hp==health,"cat follow-up frames do not repeat damage")
 await capture("04_cat_damage")
 var saved:Dictionary=app.snapshot_data()
 var home_state:String=JSON.stringify(app.home.data,"",true)
 check(app.restore_snapshot(saved) and JSON.stringify(app.home.data,"",true)==home_state,"load retains cat phase, position and counted rounds without reroll")
 fixture(true,true)
 advance(2)
 check(app.home.data.fighting and app.home.data.dog.remaining==3 and app.home.data.cat.rounds==0,"combination priority pauses assistance and cat occupancy counters")
 check(app.layout.walkable(app.home.position("dog")) and app.layout.walkable(app.home.position("cat")),"combination actors occupy actual clear floor, not exit or furniture")
 await capture("05_combination")
 var snapshot:Dictionary=app.snapshot_data()
 await frames(15)
 check(app.rules.world_time==snapshot.rules.world_time and app.home.data==snapshot.home_state,"manual pause freezes natural animal action data")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"formal entry with deterministic animal/key fixtures; no parent branches or human gameplay acceptance"},"  "))
 print("ANIMALS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
