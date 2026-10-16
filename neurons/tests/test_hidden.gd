extends SceneTree
## Headless isolated gameplay/geometry checks, not a rendered playthrough.
const Hidden=preload("res://scripts/core/hidden_street.gd")
const Neural=preload("res://scripts/core/neural_rules.gd")
const Plaza=preload("res://scripts/world/hidden_layout.gd")
const Achievements=preload("res://scripts/core/achievement_store.gd")
var checks:int=0
var failed:int=0
var results:Array=[]

class FakeApp extends RefCounted:
 var rules=Neural.new()
 var layout=Plaza.new()
 var room_id:String="hidden_street"
 var hero_pos:Vector2=Vector2.ZERO
 var hero_route:=PackedVector2Array()
 var hero_state:String="idle"
 var hero_facing:Vector2=Vector2.RIGHT
 var target_index:int=-1
 var action_phase:String="autonomy"
 var motion:Dictionary={}
 var dialogue_queue:Array=[]
 var paused_manual:bool=false
 var menu:Dictionary={"visible":false}
 var audio_panel:Dictionary={"visible":false}
 var closing_left:float=0
 func world_paused() -> bool:
  return paused_manual or menu.visible or audio_panel.visible or closing_left>0 or not dialogue_queue.is_empty()
 func add_dialogue(who:String,line:String) -> void:
  dialogue_queue.append({"speaker":who,"text":line})
 func move_hero(delta:float) -> void:
  var before:Vector2=hero_pos
  var moved:Dictionary=layout.move_path(hero_pos,hero_route,1.15*rules.movement_rate()*delta)
  hero_pos=moved.position;hero_route=moved.route
  if hero_pos.distance_to(before)>0.00001:hero_facing=(hero_pos-before).normalized()
  hero_state="idle" if hero_route.is_empty() else "walk"

func check(ok:bool,label:String) -> void:
 checks+=1;results.append({"label":label,"ok":ok})
 if not ok:failed+=1;push_error(label)

func fresh() -> Dictionary:
 var app=FakeApp.new()
 var module=Hidden.new(app)
 module.start()
 return {"app":app,"module":module}

func tick(pair:Dictionary,seconds:float) -> void:
 var left:float=seconds
 while left>0.000001:
  var step:float=minf(left,1.0/120.0)
  left-=step
  if not pair.app.world_paused():pair.app.rules.tick(step)
  pair.module.tick(step)

func stationary(pair:Dictionary,hero:Vector2,hunter:Vector2) -> void:
 pair.app.hero_pos=hero
 pair.app.rules.control_left=6.0 # Isolated contact fixture: no autonomous route.
 pair.app.hero_route=PackedVector2Array()
 pair.module.data.hunter.pos=[hunter.x,hunter.y]
 pair.module.data.hunter.phase="cooldown"
 pair.module.data.hunter.left=10.0

func force_attack(pair:Dictionary,direction:Vector2=Vector2.RIGHT) -> void:
 pair.module.data.hunter.phase="attack"
 pair.module.data.hunter.elapsed=0.0
 pair.module.data.hunter.direction=[direction.x,direction.y]
 pair.module.data.hunter.attack_id=pair.module.event_id("fixture_attack")
 pair.module.data.hunter.attack_hit=false
 pair.module.data.hunter.attack_had_target=true

func _init() -> void:
 test_entry_and_layout()
 test_sight_and_attack()
 test_body_and_kick()
 test_exit_and_storage()
 test_natural_escape()
 test_global_achievements()
 var folder:String=ProjectSettings.globalize_path("res://../docs/validation/b2_hidden_20261016")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=ProjectSettings.globalize_path(arg.trim_prefix("--validation-root="))
 DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder.path_join("hidden_rules.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failed":failed,"results":results,"scope":"Headless isolated Godot module; fixtures for contact/attack/exit. No GPU rendering, natural random route or full campaign acceptance claimed."},"  "))
 print("NEURONS hidden Street: %d checks, %d failures"%[checks,failed])
 quit(1 if failed>0 else 0)

func test_entry_and_layout() -> void:
 var pair:Dictionary=fresh()
 var app=pair.app;var module=pair.module
 app.rules.hp=43;app.rules.sp=18;app.rules.neurons=0;app.rules.plexus=0
 app.rules.owners["food:test"]="hero"
 module.start()
 check(app.rules.mode=="combat" and app.rules.hp==43 and app.rules.sp==18,"entry changes mode without restoring body values")
 check(app.rules.neurons==0 and app.rules.plexus==0 and app.rules.owners["food:test"]=="hero","hidden route has no unlock/entry reward or item reset")
 check(module.data.hunter.hp==60 and app.layout.furniture.size()==4,"one 60HP hunter and independent plaza fixtures")
 check(not app.layout.clear_segment(Vector2(1.5,1.8),Vector2(4,1.8)),"fountain blocks actual line of sight")
 var above:PackedVector2Array=app.layout.path(Vector2(1.5,0.95),Vector2(4,0.95))
 var below:PackedVector2Array=app.layout.path(Vector2(1.5,2.8),Vector2(4,2.8))
 check(not above.is_empty() and not below.is_empty(),"both sides of fountain have reachable independent bypasses")
 var patrol_clear:bool=true
 for goal in module.config.layout.patrol:patrol_clear=patrol_clear and app.layout.walkable(module.vector(goal))
 check(patrol_clear,"all return-patrol positions are actually reachable beside fountain and benches")
 check(not app.layout.path(app.layout.ENTRY,app.layout.EXIT).is_empty(),"zero-resource entry can reach exit through ordinary navigation")
 module.data.hunter.hp=0;module.data.hunter.phase="dead"
 tick(pair,15)
 check(module.data.status=="ending","zero-resource autonomous body reaches E1 without a key or killed-enemy requirement")
 check(app.rules.neurons>=1 and app.rules.neurons<=3,"shared combat regeneration runs only until actual exit locks world")

func test_sight_and_attack() -> void:
 var pair:Dictionary=fresh();var app=pair.app;var module=pair.module
 stationary(pair,Vector2(1.5,1.8),Vector2(4,1.8))
 module.data.hunter.phase="chase";module.data.hunter.last_seen=[1.5,0.8]
 module.tick(0.01)
 check(module.data.hunter.phase=="investigate" and module.data.hunter.last_seen==[1.5,0.8],"occlusion retains last actual sight without tracking through fountain")
 module.data.hunter.last_seen=[2.75,1.8]
 module.data.hunter.route=[]
 module.tick(0.01)
 check(module.data.hunter.phase=="patrol" and module.data.hunter.last_seen.is_empty(),"unreachable last-seen location ends investigation without a permanent chase")
 stationary(pair,Vector2(2,0.9),Vector2(1.2,0.9))
 module.data.hunter.phase="chase"
 module.tick(0.001)
 check(module.data.hunter.phase=="windup" and app.rules.hp==100,"nearby hunter begins visible windup without proximity damage")
 tick(pair,0.81)
 var direction:Array=module.data.hunter.direction.duplicate()
 app.hero_pos=Vector2(1.2,1.8)
 tick(pair,0.2)
 check(module.data.hunter.direction==direction and module.data.hunter.phase=="attack","late windup locks attack direction; attack does not retarget")
 tick(pair,0.5)
 check(app.rules.hp==100 and module.data.hunter.phase=="recover","real sidestep misses without invulnerability or compensating hit")
 tick(pair,0.81)
 check(module.data.hunter.phase=="cooldown" and module.data.hunter.left>1.4,"1.5-second cooldown begins only after 0.8-second recovery")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.75,0.9),Vector2(1,0.9));force_attack(pair)
 tick(pair,0.5)
 check(app.rules.hp==85 and app.rules.sp==100,"actual hunter hit deducts 15HP and zero SP")
 check(module.data.hunter.attack_hit and app.rules.settled.has(module.event_id("fixture_attack")),"one attack commits one durable hit receipt")
 module._hit_hero(module.event_id("fixture_attack"))
 check(app.rules.hp==85,"repeat hit callback never duplicates damage")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(3.6,1.8),Vector2(1.8,1.8));force_attack(pair)
 tick(pair,0.5)
 check(module.position().x<2.12 and app.rules.hp==100,"fountain stops forward lunge and prevents damage through facility")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.75,0.9),Vector2(1,0.9));force_attack(pair)
 app.menu.visible=true
 var before:String=JSON.stringify(module.data)
 tick(pair,2)
 check(JSON.stringify(module.data)==before and app.rules.hp==100 and app.rules.world_time==0,"menu freezes attack position, phase, damage and world time")
 app.menu.visible=false;tick(pair,0.15)
 check(app.rules.hp==85,"closing menu resumes same attack to actual contact")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.4,0.9),Vector2(1,0.9));force_attack(pair)
 app.rules.control_left=0
 check(app.rules.submit_skill("SKIN",{"direction":[0,1]}).ok,"contact-interruption fixture uses a genuinely available paid skill")
 var paid_id:String=str(app.rules.pending_neural.event_id)
 tick(pair,0.02)
 check(app.rules.neurons==4 and app.rules.pending_neural.is_empty() and app.rules.settled.get(paid_id)=="interrupted","actual contact cancels unexecuted body reaction while retaining valid cast fee and interruption receipt")

func test_body_and_kick() -> void:
 var pair:Dictionary=fresh();var app=pair.app;var module=pair.module
 stationary(pair,Vector2(1.7,0.9),Vector2(1,0.9));force_attack(pair)
 app.rules.reaction_skill="GUT";app.rules.reaction_left=0.8;module.data.duck_left=0.8
 tick(pair,0.15)
 check(app.rules.hp==100 and module.body_height()<0.9,"held crouch actually lowers upper body below high lunge trajectory")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.4,0.9),Vector2(1,0.9));force_attack(pair)
 app.rules.reaction_skill="GUT";app.rules.reaction_left=1.2;module.data.duck_left=1.2
 tick(pair,0.02)
 check(app.rules.hp==85,"early crouch entry is still physically in attack trajectory")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.4,0.9),Vector2(1,0.9));force_attack(pair)
 app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=0.3
 tick(pair,0.02)
 check(app.rules.hp==85,"withdrawing hands gives no torso invulnerability")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1,0.9),Vector2(1.7,0.9))
 var original_neurons:int=app.rules.neurons
 for i in range(4):
  module.data.hunter.pos=[1.7,0.9]
  module.data.hunter.phase="windup";module.data.hunter.elapsed=0
  app.rules.action={"id":"fixture_kick:%d"%i,"phase":"attack","direction":[1,0],"hit_receipts":{}}
  module.kick_contact();module.kick_contact()
  check(module.data.hunter.hp==maxi(0,60-(i+1)*15),"kick %d commits one 15HP body hit"%(i+1))
 check(module.data.hunter.phase=="dead" and app.rules.neurons==original_neurons,"four actual hits retire hunter with no resource drops or duplicate neural fee")
 check(not module.blocks_hero() and module.actors().is_empty(),"dead hunter neither blocks hero nor remains a living drawn actor")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.5,1.8),Vector2(3.7,1.8))
 app.rules.action={"id":"fixture_wall","phase":"attack","direction":[1,0],"hit_receipts":{}}
 module.kick_contact()
 check(module.data.hunter.hp==60,"kick cannot damage beyond range or through fountain")

func test_exit_and_storage() -> void:
 var pair:Dictionary=fresh();var app=pair.app;var module=pair.module
 var threshold:Vector2=module.vector(module.config.layout.exit)
 var inside:Vector2=threshold+Vector2(0,0.05)
 var outside:Vector2=threshold-Vector2(0,0.05)
 app.hero_pos=inside
 check(not module.commit_exit(inside),"standing near an exit marker is not a crossing")
 app.hero_pos=threshold
 check(not module.commit_exit(),"legacy proximity callback without a movement segment cannot award E1")
 check(module.crossed_exit(inside,outside) and not module.crossed_exit(outside,inside),"only an inside-to-outside threshold crossing has valid direction")
 check(not module.crossed_exit(inside+Vector2(-0.8,0),outside+Vector2(-0.8,0)),"crossing beside the finite doorway cannot award E1")
 check(not app.layout.path(inside,module.exit_destination()).is_empty(),"outer landing is reachable by ordinary collision-aware movement")
 stationary(pair,app.layout.EXIT,Vector2(4.8,0.42));force_attack(pair)
 app.rules.hp=15
 tick(pair,0.01)
 check(app.rules.hp==0 and module.data.status=="dead" and module.data.ending.is_empty(),"fatal contact at actual exit wins over E1")
 check(module.data.pending_feedback.is_empty(),"fatal hit cannot queue still-alive or escape-success dialogue")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,inside,Vector2(4.8,0.42));force_attack(pair)
 app.rules.hp=16
 tick(pair,0.01)
 check(app.rules.hp==1 and module.data.status=="active","nonfatal hit beside threshold does not itself complete E1")
 app.hero_pos=outside # Isolated swept-crossing fixture after the real contact.
 check(module.commit_exit(inside),"valid crossing commits only after nonfatal damage has been applied")
 check(module.data.ending.id=="E1" and module.data.pending_achievements==["hidden_clear","host_wins"],"E1 requests the two original global achievement keys")
 check("hit" in module.data.ending_feedback and not module.encounter_record().is_empty(),"feedback due at crossing survives into the ending record without blocking E1")
 check(app.rules.transitioning and module.blocks_hero() and app.hero_route.is_empty(),"ending locks old world, attack and player movement")
 var hp:int=app.rules.hp
 module._hit_hero("stale_after_exit")
 check(app.rules.hp==hp and not module.commit_exit(),"old-world damage and repeated exit callbacks are inert")
 app.paused_manual=true;module.advance_ending(3)
 check(module.data.ending.elapsed==0,"manual pause freezes separate ending presentation clock")
 app.paused_manual=false;module.advance_ending(2.1)
 check(module.ending_frame().phase=="bed" and module.ending_frame().wake>0,"E1 first retains plaza then transitions to reality-bed wake-up placeholder")
 module.advance_ending(3)
 check(module.ending_frame().complete and module.data.status=="ending","finished E1 never automatically revives or enters hospital")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.75,0.9),Vector2(1,0.9));force_attack(pair)
 tick(pair,0.15)
 var saved:Dictionary=JSON.parse_string(JSON.stringify(module.data))
 var hp_after:int=app.rules.hp
 module.data=saved
 tick(pair,0.2)
 check(app.rules.hp==hp_after and module.data.hunter.attack_hit,"JSON-restored attack preserves contact receipt and cannot hit twice")
 check(typeof(module.data.hunter.pos)==TYPE_ARRAY and typeof(module.data.hunter.phase)==TYPE_STRING,"module persistence uses portable JSON primitives")
 pair=fresh();app=pair.app;module=pair.module
 module.tick(0.01)
 check(module.data.feedback_receipts.has("saw") and not app.dialogue_queue.is_empty(),"first actual sight is presented during the encounter rather than waiting for patrol")
 var lines:String=JSON.stringify(app.dialogue_queue)
 check(not "出口在后面。" in lines and "……" in lines,"latest player-opposition instruction suppresses only the contradictory assistance quote")
 module.data=JSON.parse_string(JSON.stringify(module.data));app.dialogue_queue.clear()
 module._perceive();module._safe_feedback()
 check(app.dialogue_queue.is_empty(),"restoring an already-presented sight receipt does not repeat its dialogue")
 check(module.config.feedback.saw[1].text=="出口在后面。","historical source dialogue remains intact while the explicit user override controls playback")

func test_natural_escape() -> void:
 var pair:Dictionary=fresh();var app=pair.app;var module=pair.module
 app.rules.neurons=0;app.rules.plexus=0
 var seen_living:bool=false
 for frame in range(120*40):
  app.dialogue_queue.clear() # Driver advances safe captions; no gameplay mutations.
  tick(pair,1.0/120.0)
  seen_living=seen_living or bool(module.data.hero_perceived)
  if module.data.status!="active":break
 check(seen_living and module.data.status=="ending" and app.rules.hp>0,"zero-resource autonomous body evades a live hunter to the real exit")
 check(module.data.hunter.hp==60 and app.rules.sp==100,"natural autonomous escape does not require attacks, resource purchase or mental damage")
 check(module.data.feedback_receipts.has("saw") and module.data.feedback_receipts.has("evaded"),"natural pursuit presents both actual sight and real evade feedback")
 pair=fresh();app=pair.app;module=pair.module
 stationary(pair,Vector2(1.7,0.9),Vector2(1,0.9));force_attack(pair)
 app.rules.loading=true
 var state:String=JSON.stringify(module.data)
 module.tick(3)
 check(JSON.stringify(module.data)==state and app.rules.hp==100,"loading cannot advance hidden contact or consume queued attack")
 app.rules.loading=false;tick(pair,0.06)
 check(app.rules.hp==85,"loading completion resumes the saved real contact")

func test_global_achievements() -> void:
 var global=Achievements.new()
 check(global.path()=="user://global_progress.json" and global.DEFINITIONS.size()==12,"formal global file is independent from profiles and reserves the original twelve keys")
 # A fresh directory per invocation prevents prior test state and never writes
 # user://global_progress.json. No delete/reset of human progress is used.
 global.root="res://../tmp/b2_source_intake/achievement_tests/%d_%d"%[Time.get_ticks_usec(),OS.get_process_id()]
 check(global.path().begins_with(global.root),"isolated save root also isolates all global achievement writes")
 var first:Dictionary=global.grant_e1("hidden:1:exit")
 check(first.ok and first.changed==["hidden_clear","host_wins"],"one valid E1 atomically unlocks both actual global achievements")
 var stored:Dictionary=global.load_progress().data
 check(stored.unlocked.size()==2 and stored.receipts.size()==1 and not stored.has("neurons") and not stored.has("observations"),"global record contains no resource rewards or profile knowledge")
 var repeated:Dictionary=global.grant_e1("hidden:1:exit")
 check(repeated.ok and repeated.changed.is_empty(),"replaying one exit callback cannot unlock or reward twice")
 var other_save=Achievements.new();other_save.root=global.root
 var next:Dictionary=other_save.grant_e1("other_profile:hidden:4:exit")
 check(next.ok and next.changed.is_empty() and other_save.load_progress().data.unlocked.size()==2,"new profiles and restored older saves cannot reduce already-earned global progress")
 check(not global.grant(["first_death"],"preview","not wired").ok and not global.grant_e1("").ok,"unwired triggers, previews and missing event identities cannot create achievements")
 var file:=FileAccess.open(ProjectSettings.globalize_path(global.path()),FileAccess.WRITE)
 file.store_string("broken test fixture");file.close()
 var recovered:Dictionary=global.load_progress()
 check(recovered.ok and recovered.get("recovered_backup",false) and recovered.data.unlocked.size()==2,"damaged primary recovers the complete latest monotonic global union")
 file=FileAccess.open(ProjectSettings.globalize_path(global.path())+".bak",FileAccess.WRITE)
 file.store_string("broken backup fixture");file.close()
 var corrupt:Dictionary=global.grant_e1("retry")
 check(not corrupt.ok,"corrupt global file without valid backup is preserved and clearly reports failure")
