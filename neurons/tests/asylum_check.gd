extends "res://tests/hospital_check.gd"
## Source-grounded finite exploration/save cases. Explicit initial fixtures;
## subsequent navigation/contact/rewards use the normal campaign methods.
const Map=preload("res://scripts/core/asylum_map.gd")

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)
 if value or app==null:return
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_%02d.json"%failures.size()),FileAccess.WRITE)
 f.store_string(JSON.stringify({"label":label,"snapshot":app.snapshot_data()},"  "));f.close()

func fixture3(room:String="stairs",events:bool=false) -> void:
 app.rules=Neural.new();app.menu.rules=app.rules
 app.session=Session.new();app.session.data.unlocked=[1,2,3];app.session.new_attempt(3,app.rng)
 app.rules.actual_attempt=1;app.rules.search_limit=14;app.rules.owners.key=app.session.data.key_owner
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=events
 app.asylum.start_attempt()
 for group in app.asylum.data.groups:app.asylum.data.groups[group].drawn=true
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.room_id="";app.enter_room(room);app.hero_pos=Vector2(2.8,1.4)
 app.hero_route=PackedVector2Array();app.target_index=-1;app.action_phase="autonomy"
 app.paused_manual=true;app.menu.close_menu();app.closing_left=0;clear_lines()

func step3(seconds:float=0.025) -> void:
 for index in range(ceili(seconds/0.025)):
  if not app.dialogue_queue.is_empty():
   while not app.dialogue_queue.is_empty():app.advance_dialogue()
  app.advance_world(minf(0.025,seconds-index*0.025))

func until3(predicate:Callable,seconds:float=180.0) -> bool:
 for index in range(ceili(seconds/0.025)):
  if predicate.call():return true
  step3()
 return predicate.call()

func finish3() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 exploration, actual doors/path/search/key/rest, finite fixed fixtures and real checksummed JSON; no human natural-RNG, all NPC combinations or formal art/audio acceptance"},"  "));f.close()
 print("ASYLUM_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/exploration"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="两层探索验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 hospital_fixture("lobby");app.rules.owners.key="hero";app.session.data.key_owner="hero"
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus;var cycle:int=app.session.data.cycle
 app.session.data.exploration_boundary=false;app.hero_pos=app.door_point("stairs");app.route_to_door("stairs")
 check(until3(func():return int(app.session.data.level)==3,2),"actual keyed hospital stair opening enters L3 without a development-stop button")
 app.asylum.enabled=false
 check(app.room_id=="stairs" and app.visible_doors.has("lobby") and app.visible_doors.has("corridor"),"third-level stairs retain down/up public routes without reception permission")
 check(app.rules.neurons==neurons+3 and app.rules.plexus==clusters+2 and int(app.session.data.cycle)==cycle,"first L3 unlock gives exact 3N/2C once and no new cycle")
 check(app.session.data.targets.size()==14 and app.rules.search_limit==14,"L3 samples fourteen targets and grants fourteen actual search opportunities")
 check(Map.ROOM_NAMES.size()==13 and Map.candidates().size()==45,"thirteen rooms preserve exactly forty-five second-floor candidates")
 var sampled:Array=app.session.data.targets.duplicate();var key:String=app.session.data.key_target
 var valid:bool=true
 for id in sampled:
  if not id in Map.candidates():valid=false
 check(valid and sampled.has(key),"all sampled points and the unique key are on the existing second floor")
 var snapshot:Dictionary=app.snapshot_data()
 for room in Map.ROOM_NAMES:
  app.room_id="";app.enter_room(room);app.hero_pos=Vector2(2.8,1.4)
  for door in app.visible_doors:
   check(app.layout.walkable(app.door_point(door)) and not app.layout.path(app.hero_pos,app.door_point(door)).is_empty(),"real accessible door %s -> %s"%[room,door])
  for f in app.layout.furniture:
   check(app.layout.walkable(f.at) and not app.layout.path(app.hero_pos,f.at).is_empty(),"reachable existing furniture %s / %s"%[room,f.name])
  if room in ["ward","lobby","clinic","pharmacy","office"]:check(Session.point_names(3,room).is_empty(),"first-floor %s has no additional key-search point"%room)
 check(app.restore_snapshot(snapshot),"actual L3 room and action snapshot is accepted by existing schema2 loader")
 var graph_valid:bool=true
 for room in Map.ROOM_NAMES:
  if room!="stairs" and Map.next_room(room,"stairs").is_empty():graph_valid=false
 check(graph_valid and Map.next_room("workshop","ward")=="corridor","all return-to-bed routes use corridor, stairs and reception without new edges")
 await capture("01_third_level_stairs")

 fixture3("workshop")
 var target:String="workshop:0";app.session.data.targets=[target];app.session.data.key_target="stairs:0";app.session.data.key_owner="stairs:0";app.rules.owners.key="stairs:0"
 check(until3(func():return app.rules.search_active,12),"autonomy physically approaches a real workshop stand before search begins")
 check(is_equal_approx(app.rules.search_duration,6.0) and app.rules.search_attempts==1,"first-attempt standard search lasts six seconds and consumes the opportunity at start")
 step3(1.0);var elapsed:float=app.rules.search_elapsed;neurons=app.rules.neurons
 check(roundtrip() and is_equal_approx(app.rules.search_elapsed,elapsed) and app.rules.search_attempts==1,"mid-search checksummed JSON keeps consumed attempt, six-second progress and target")
 var time:float=app.rules.world_time;await frames(12)
 check(is_equal_approx(app.rules.world_time,time) and is_equal_approx(app.rules.search_elapsed,elapsed),"manual pause freezes world and in-flight L3 search")
 check(until3(func():return target in app.completed,8),"same resumed six-second action genuinely finishes")
 check(app.rules.neurons==neurons+1,"one real completed target gives exactly one neuron")
 snapshot=app.snapshot_data();check(roundtrip(),"completed third-floor search can be saved and loaded")
 step3(0.1);check(app.rules.neurons==neurons+1,"loaded completed target cannot grant another search reward")
 check(app.session.data.key_target=="stairs:0","room navigation and JSON do not reroll the hidden key")
 await capture("02_workshop_actual_search")

 fixture3("workshop");app.rules.sp=40
 var attempts:int=app.rules.actual_attempt;cycle=app.session.data.cycle
 app.rules.skill_states.GUT.until=app.rules.world_time+200;var cooldown:float=app.rules.skill_states.GUT.until
 var visited:Array=[]
 for i in range(9000):
  if int(app.rules.actual_attempt)>attempts:break
  if visited.is_empty() or visited[-1]!=app.room_id:visited.append(app.room_id)
  step3()
 check(int(app.rules.actual_attempt)==attempts+1 and int(app.session.data.cycle)==cycle+1,"low-SP third-level hero physically returns to designated bed and completes one rest")
 check(visited.has("corridor") and visited.has("stairs") and visited.has("lobby") and visited.has("ward"),"return route actually traverses both floors and original reception")
 check(app.room_id=="ward" and app.rules.hp==100 and app.rules.sp==100,"third-level rest uses single ward bed, not a padded chair or treatment chair")
 check(app.rules.search_limit==14 and app.session.data.targets.size()==14 and app.rules.search_attempts==0,"new real attempt resets exactly fourteen searches and one new fixed sample")
 check(app.rules.skill_states.GUT.until==cooldown,"rest preserves skill cooldown instead of granting a reset")
 check(not app.asylum.data.carry.has("invented_patient_number"),"missing carried material stays absent rather than fabricating a patient identifier")
 await capture("03_real_return_to_first_floor_bed")

 fixture3("stairs");app.session.data.exploration_boundary=false
 neurons=app.rules.neurons;clusters=app.rules.plexus
 check(until3(func():return bool(app.session.data.exploration_boundary),300),"without any NPC, autonomy really searches, obtains the unique key and opens the existing L4 stair exit")
 check(app.room_id=="stairs" and app.has_key(),"third-level exit boundary requires actual key ownership at actual stair position")
 check(app.rules.plexus==clusters and app.rules.neurons>neurons,"search income occurs without duplicate level-unlock clusters")
 var stable:Dictionary=app.snapshot_data();step3(2)
 check(app.session.data.targets==stable.session.targets and app.rules.plexus==clusters,"development boundary does not replay rewards or pretend to finish fourth level")
 await capture("04_keyed_third_level_exit_boundary")
 finish3()
