extends "res://tests/cortex_check.gd"
## Regression for actual risks found during B4 integration: two-way body
## collision, occupied arrival doors, original rhythm stands and index retreat.
## Each actor/position is an explicit fixture, never a normal-play assertion.
var navigation_samples:Array=[]

func isolated_actor(id:String,room:String,at:Vector2,stand_done:bool=true) -> void:
 app.cortex.enabled=true
 for group in app.cortex.data.groups:
  app.cortex.data.groups[group].drawn=true;app.cortex.data.groups[group].pending=false
 for other in app.cortex.data.actors:app.cortex.actor(str(other)).phase="absent"
 var actor:Dictionary=app.cortex.actor(id)
 actor.room=room;actor.pos=[at.x,at.y];actor.route=[];actor.phase="idle";actor.stand_done=stand_done

func actor_clock(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):
  while not app.dialogue_queue.is_empty():app.advance_dialogue()
  app.cortex.tick(minf(.025,seconds-i*.025))

func walk_past_actor(id:String,destination_point:Vector2,limit:int=1600) -> Dictionary:
 app.hero_route=app.layout.path(app.hero_pos,destination_point)
 var minimum:float=INF
 var visited:int=0
 for i in range(limit):
  if app.hero_route.is_empty():break
  var before:Vector2=app.hero_pos
  app.move_hero(.025)
  var at:Vector2=app.cortex.position(id)
  minimum=minf(minimum,Geometry2D.get_closest_point_to_segment(at,before,app.hero_pos).distance_to(at))
  visited+=1
 return {"reached":app.hero_pos.distance_to(destination_point)<.035,"minimum":minimum,"steps":visited}

func finish_navigation() -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"samples":navigation_samples,
  "scope":"Finite declared actor/room/position fixtures, real move_hero and neural motion, actual source and destination doorway checks, default spawned rhythm crossing, original read→label extraction→physical retreat→terminal search. NPC clock/ordinary campaign handlers and real JSON; no claim of all crowd permutations or human full play."},"  "));file.close()
 print("CORTEX_NAVIGATION_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b4_20261016/navigation"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="脑部实际占位与通路验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 fixture4();app.hero_pos=Vector2(.95,2.9)
 isolated_actor("backward","atrium",Vector2(.95,1.65))
 var hp:int=app.rules.hp;var sp:int=app.rules.sp;var neurons:int=app.rules.neurons
 var movement:Dictionary=walk_past_actor("backward",Vector2(.95,.65))
 navigation_samples.append({"ordinary_actor_detour":movement})
 check(movement.reached and float(movement.minimum)>=.319,"normal hero movement routes around a real stationary original NPC without body overlap")
 check(app.cortex.position("backward").distance_to(Vector2(.95,1.65))<.001,"detour never snaps or moves the obstructing actor")
 check(app.rules.hp==hp and app.rules.sp==sp and app.rules.neurons==neurons,"ordinary body obstruction creates no damage or extra cost")
 await capture("01_actual_body_detour")

 fixture4();app.hero_pos=Vector2(.95,2.9)
 isolated_actor("backward","atrium",Vector2(.95,2.25))
 var before:Vector2=app.hero_pos;var minimum:float=INF
 app.start_motion(Vector2(0,-1),1.0,.2)
 for i in range(12):
  before=app.hero_pos;step3(.025)
  var at:Vector2=app.cortex.position("backward")
  minimum=minf(minimum,Geometry2D.get_closest_point_to_segment(at,before,app.hero_pos).distance_to(at))
 check(minimum>=.319,"actual neural displacement also respects physical NPC body instead of bypassing ordinary movement collision")
 check(app.rules.hp==100 and app.rules.sp==100,"blocked neural motion does not invent collision damage")

 # Arrival occupied by an already-present actor in the destination room.
 fixture4();app.hero_pos=Vector2(.9,1.1)
 var incoming:Vector2=CMap.doorway("memory","atrium")
 isolated_actor("stitched","memory",incoming)
 app.route_to_door("memory");step3(4.0)
 check(app.room_id=="atrium","occupied destination doorway prevents spawning the hero inside an existing NPC")
 var moved:bool=false
 for i in range(160):
  if app.cortex.move("stitched",Vector2(5.36,2.0),.025):moved=true;break
 check(moved,"destination NPC genuinely walks aside along a legal path")
 check(until3(func():return app.room_id=="memory",5),"same opening completes after actual destination clearance")
 check(app.hero_pos.distance_to(app.cortex.position("stitched"))>=.319,"arrival retains body separation rather than post-arrival repair")
 await capture("02_destination_door_actual_clearance")

 fixture4("bridge")
 incoming=CMap.doorway("rhythm","bridge")
 isolated_actor("twitch","rhythm",incoming+Vector2(.38,0))
 check(not app.cortex_arrival_clear("rhythm"),"arrival checks preserve the original rhythm actor's larger 0.42 body radius")

 # The real default stand is derived by the production pending spawn/stand
 # logic, not substituted by the convenient fixture used by event unit tests.
 fixture4("rhythm");app.hero_pos=Vector2(4.8,2.5);app.session.data.exploration_boundary=true
 app.cortex.enabled=true
 for group in app.cortex.data.groups:app.cortex.data.groups[group].drawn=true;app.cortex.data.groups[group].pending=false
 app.cortex.data.groups.twitch.pending=true
 check(until3(func():return app.cortex.present("twitch") and app.cortex.actor("twitch").stand_done,20),"default rhythm actor actually spawns at original door and walks to its authored furniture-side stand")
 actor_clock(.025)
 var rhythm:Dictionary=app.cortex.upper_events.state().rhythm
 var start:Array=rhythm.from.duplicate();var finish:Array=rhythm.to.duplicate()
 var valid:bool=start.size()==2 and finish.size()==2
 if valid:
  valid=app.layout.walkable(Vector2(float(start[0]),float(start[1]))) and app.layout.walkable(Vector2(float(finish[0]),float(finish[1])))
 var min_cycle:int=int(rhythm.count)
 for i in range(400):
  actor_clock(.025)
  valid=valid and app.layout.walkable(app.cortex.position("twitch"))
 check(valid and int(rhythm.count)>=min_cycle+3,"three real default rhythm crossings stay in walkable space and do not freeze against an invisible wall")
 navigation_samples.append({"rhythm_default_from":start,"rhythm_default_to":finish,"count":rhythm.count})
 var initial_searches:int=app.rules.search_attempts;hp=app.rules.hp;sp=app.rules.sp
 app.hero_pos=Vector2(1.05,1.8);app.hero_route=app.layout.path(app.hero_pos,app.layout.furniture[3].at)
 minimum=INF
 for i in range(1600):
  if app.hero_route.is_empty():break
  actor_clock(.025);before=app.hero_pos;app.move_hero(.025)
  var at:Vector2=app.cortex.position("twitch")
  minimum=minf(minimum,Geometry2D.get_closest_point_to_segment(at,before,app.hero_pos).distance_to(at))
 check(app.hero_pos.distance_to(app.layout.furniture[3].at)<.035 and minimum>=.419,"real default moving support can be passed on its side without endless wait or body crossing")
 check(app.rules.hp==hp and app.rules.sp==sp and app.rules.search_attempts==initial_searches,"rhythm yielding preserves health and search attempt count")
 await capture("03_default_rhythm_crossing_and_bypass")

 fixture4("switch");app.hero_pos=app.layout.furniture[1].at;app.hero_facing=Vector2.LEFT
 isolated_actor("reverse","switch",Vector2(2.15,3.1))
 actor_clock(1.0)
 check(not app.cortex.upper_events.state().switch.attempted and app.cortex.upper_events.forced_route_target().is_empty(),"nearby unseen behind-the-back pointing cannot start a forced loop")
 app.hero_facing=Vector2.RIGHT;actor_clock(.025)
 check(app.cortex.upper_events.state().switch.phase=="point","actually looking at the original actor starts its visible pointing preparation")
 # Actual ownership transfer fixture at a previously discovered unique key
 # stand, deliberately inside the actor's still-unfinished pointing window.
 app.session.data.key_target="switch:1";app.session.data.key_owner="switch:1";app.rules.owners.key="switch:1"
 app.session.data.key_seen=true
 var received:bool=app.rules.commit_transfer("navigation_key_during_point","key","switch:1","hero",0.0,true,true,true)
 if received:app.session.data.key_owner="hero"
 actor_clock(.5)
 check(received and app.cortex.upper_events.forced_route_target().is_empty() and app.cortex.upper_events.state().switch.phase=="done","actual key ownership acquired during pointing prevents a new forced loop")

 # A terminal slot cannot remain permanently occupied after label extraction.
 fixture4("index");app.session.data.exploration_boundary=true;app.hero_pos=Vector2(4.35,1.65)
 isolated_actor("faceless","index",Vector2(4.85,1.1))
 app.cortex.face_target("faceless",app.layout.furniture[1].at)
 var spec:Dictionary=app.cortex.specification("cortex_index_original")
 check(app.route_cortex_observation(spec,false),"original document read starts through actual legal approach handler")
 check(until3(func():return app.cortex.upper_events.persistent().index_removed,30),"witnessed original read really causes walking, pinching and extraction")
 var terminal:Vector2=app.layout.furniture[3].at
 check(until3(func():return app.cortex.upper_events.state().index.phase=="done",20),"original actor physically returns to cabinet after putting away the label")
 check(app.cortex.position("faceless").distance_to(terminal)>=.42,"completed removal leaves the terminal's unique search/read stand clear")
 check(app.rules.owners.cortex_name_label=="faceless","retreat preserves the one actual label owner")
 check(roundtrip(),"post-retreat JSON preserves actor position and original ownership")
 spec=app.cortex.specification("cortex_index_query")
 check(app.route_cortex_observation(spec,false) and until3(func():return app.cortex.data.completed_observations.has("cortex_index_query"),20),"the vacated original terminal remains physically readable")
 app.session.data.exploration_boundary=false;app.session.data.targets=["index:3"]
 app.target_index=-1;app.action_phase="autonomy";app.hero_route=PackedVector2Array();clear_lines()
 check(until3(func():return "index:3" in app.completed,15),"the same vacated terminal still supports genuine seven-second key search")
 await capture("04_terminal_access_after_real_retreat")
 finish_navigation()
