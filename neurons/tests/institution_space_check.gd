extends "res://tests/family_check.gd"
## Real production movement/actions in declared initial fixtures. No formal
## artwork, natural actor combination or normal-speed human acceptance claim.
const SessionRules=preload("res://scripts/core/campaign_session.gd")
var baseline:Dictionary={}
var route_evidence:Array=[]

func roundtrip() -> bool:
 if not app.store.save_snapshot(app.snapshot_data()).ok:return false
 var saved:Dictionary=app.store.load_snapshot()
 return saved.ok and app.restore_snapshot(saved.data)

func reset2(room:String="lobby") -> void:
 app.restore_snapshot(baseline)
 app.rules=Neural.new();app.menu.rules=app.rules
 app.rules.neurons=50;app.rules.search_limit=12;app.rules.search_duration=5.0
 app.session=SessionRules.new();app.session.data.unlocked=[1,2]
 app.session.new_attempt(2,app.rng)
 app.session.data.key_discovery.discovered="geometry_fixture"
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false
 app.hospital.data.clear();app.hospital.start_attempt()
 app.completed.clear();app.deferred_targets.clear();app.motion.clear()
 app.room_id="";app.enter_room(room)
 app.hero_pos=app.layout.get_anchor("spawn");app.hero_route=PackedVector2Array()
 app.paused_manual=true;app.menu.close_menu();clear_lines();app.closing_left=0

func walk_door(toward:String) -> bool:
 var previous:String=app.room_id
 var level:int=int(app.session.data.level)
 app.session.data.exploration_boundary=false
 app.route_to_door(toward)
 var crossed:bool=until(func():return app.room_id!=previous or int(app.session.data.level)!=level,4500)
 route_evidence.append({"from":previous,"toward":toward,"actual":app.room_id,"level":app.session.data.level,"hero":[app.hero_pos.x,app.hero_pos.y]})
 check(crossed,"physical route, opening and threshold crossing: "+previous+" -> "+toward)
 return crossed

func finish_check() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"routes":route_evidence,"rendered":true,"scope":"Fixed actor-free geometry fixtures; production movement/search/opening/threshold/JSON and paid interruption. L2 key ownership fixture isolates original unlock then L3 lobby change/stairs/return-to-bed. Legacy v1 fixture preserves original coordinates until actual rest. No all-NPC, normal-speed human, formal art or subjective audio acceptance."},"  "));file.close()
 print("INSTITUTION_SPACE_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="机构空间实跑"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.opening_ui!=null:app.opening_ui.skip()
 clear_lines();app.paused_manual=true;baseline=app.snapshot_data()
 reset2()
 check(app.layout.world_size()==Vector2(12,8) and app.world_viewport.size==Vector2i(1280,720),"lobby uses independent large floor and native viewport")
 check(app.visible_doors.size()==5,"lobby keeps original five connections")
 await capture("01_hospital_lobby")
 for room in ["ward","clinic","pharmacy","office"]:
  if not walk_door(room):await finish_check();return
  check(app.layout.walkable(app.hero_pos),"arrival is legal: "+room)
  await capture("room_"+room)
  if not walk_door("lobby"):await finish_check();return
 # All original L2 candidate identities execute real approach and contact.
 for room in ["lobby","clinic","pharmacy","office"]:
  for index in range(SessionRules.ROOM_POINTS[room].size()):
   reset2(room)
   var target:String="%s:%d"%[room,index]
   app.session.data.targets=[target]
   check(until(func():return app.rules.search_active,3000),"actual autonomous approach reaches "+target)
   if not app.rules.search_active:await finish_check();return
   step(0.6)
   var at:Vector2=app.hero_pos;var elapsed:float=app.rules.search_elapsed;var before:int=app.rules.neurons
   if index==0:
    check(roundtrip() and app.hero_pos==at and is_equal_approx(app.rules.search_elapsed,elapsed),"half-contact JSON preserves position and time in "+room)
    await frames(4)
    check(is_equal_approx(app.rules.search_elapsed,elapsed),"manual pause holds restored contact in "+room)
    await capture("contact_"+room)
   check(until(func():return target in app.completed,500),"real search completes "+target)
   check(app.rules.neurons==before+1 and app.layout.walkable(app.hero_pos),"one reward on reachable floor for "+target)
 # A full opened doorway still requires a physical threshold crossing.
 reset2()
 app.route_to_door("clinic")
 check(until(func():return app.action_phase=="crossing",3000),"opened clinic door enters separate threshold movement")
 var old_at:Vector2=app.hero_pos
 check(roundtrip() and app.action_phase=="crossing" and app.hero_pos==old_at,"crossing snapshot retains active route without teleport")
 var count:int=app.rules.neurons
 var result:Dictionary=app.rules.submit_skill("SKIN",app.skill_context());app.apply_cast()
 check(result.ok and result.success and app.rules.neurons==count-1 and app.action_phase=="autonomy" and app.hero_route.is_empty(),"paid intervention cancels doorway crossing before room change")
 check(app.room_id=="lobby","interrupted doorway does not prematurely enter clinic")
 check(walk_door("clinic"),"interrupted doorway can be reached and crossed again")
 # Original keyed exit: visible first-floor change before traversing stairs.
 reset2()
 app.session.data.key_owner="hero";app.rules.owners.key="hero"
 app.route_to_door("stairs")
 check(until(func():return int(app.session.data.level)==3,4000),"actual keyed hospital threshold unlocks asylum")
 check(app.room_id=="lobby" and not app.has_key(),"new asylum appears on the same lower floor before upstairs")
 check(app.layout.geometry_version==2 and app.layout.world_size()==Vector2(12,8),"lower-floor transformation keeps its exact geometry")
 await capture("02_asylum_lower_change")
 check(roundtrip(),"lower-floor transition survives JSON without repeat unlock")
 var reward:Vector2i=Vector2i(app.rules.neurons,app.rules.plexus)
 check(until(func():return app.room_id=="stairs",1200),"same corner and physical threshold lead into existing staircase")
 check(Vector2i(app.rules.neurons,app.rules.plexus)==reward,"stair arrival never repeats first-unlock reward")
 await capture("03_actual_staircase")
 if not walk_door("corridor"):await finish_check();return
 check(app.layout.geometry_version==2,"new chapter uses the explicitly migrated upper corridor")
 if not walk_door("stairs"):await finish_check();return
 if not walk_door("lobby"):await finish_check();return
 if not walk_door("ward"):await finish_check();return
 app.rules.sp=40;app.rules.search_attempts=app.rules.search_limit
 var attempt:int=app.rules.actual_attempt
 check(until(func():return app.rules.actual_attempt>attempt,2400),"low-SP asylum path physically reaches the designated bed and rests")
 check(app.room_id=="ward" and app.layout.geometry_version==2,"rest keeps proper new ward geometry")
 # Explicit old-schema coordinates and source transports stay v1 this chapter.
 reset2("ward")
 var saved:Dictionary=app.snapshot_data()
 saved.schema=2;saved.session.erase("institution_geometry_version")
 saved.hospital_state.erase("geometry_version")
 saved.hero_pos=[2.55,1.2];saved.route=[];saved.action_phase="resting";saved.action_left=0.6
 check(app.restore_snapshot(saved) and app.layout.geometry_version==1 and app.hero_pos==Vector2(2.55,1.2),"old institutional save retains original geometry and in-flight resting position")
 attempt=app.rules.actual_attempt
 check(until(func():return app.rules.actual_attempt>attempt,100),"old saved rest completes through production clock")
 check(app.layout.geometry_version==1 and app.hospital.source_geometry_version()==1 and app.layout.walkable(app.hero_pos),"old chapter rest retains legacy geometry and hospital source provenance")
 await capture("04_legacy_after_actual_rest")
 await finish_check()
