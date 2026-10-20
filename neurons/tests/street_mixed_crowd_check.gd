extends "res://tests/street_door_block_check.gd"
## Bounded mixed-body/rigid-object combinations beyond the old four-body case.
var initial_street:Dictionary={}
var mixed_fixture:Dictionary={}
var live_timeline:Array=[]
var cache_evidence:Array=[]
var cache_subject:String="warder"

func same_point(a:Array,b:Array) -> bool:
 return app.street.vector(a).distance_to(app.street.vector(b))<.00001

func dump_json(filename:String,value:Dictionary) -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join(filename),FileAccess.WRITE)
 file.store_string(JSON.stringify(value,"  "));file.close()

func cast(id:String,room:String,at:Vector2,dead:bool=false) -> Dictionary:
 var a:Dictionary=actor_at(id,at)
 a.room=room;a.hp=0 if dead else int(app.street.spec(id).hp)
 a.hostile=app.street.spec(id).relation=="enemy";a.cooldown=3.0;a.direction=[1,0]
 return a

func safe_stand(room:String,wanted:Vector2,chair:bool=false) -> Vector2:
 var space=app.street.floor_for(room)
 for radius_index in range(35):
  var radius:float=radius_index*.15
  for index in range(12):
   var point:Vector2=wanted+Vector2.RIGHT.rotated(TAU*float(index)/12.0)*radius
   if not space.walkable(point,.64 if chair else .21):continue
   if app.street.bed_blocks(room,point,.64 if chair else .21):continue
   var free:bool=true
   for id in app.street.data.actors:
    var a:Dictionary=app.street.data.actors[id]
    if a.present and a.room==room and point.distance_to(app.street.position(str(id)))<1.1:free=false;break
   if free:return point
 return Vector2.INF

func dead_bed(room:String,center:Vector2,axis:Vector2) -> void:
 var push:=Vector2(axis.y,-axis.x)
 var carrier:Dictionary=cast("transporter_asylum",room,center-push*.8,true)
 app.street.data.lateral_bed={"id":"street_asylum_transport_bed","room":room,"center":app.street.xy(center),"axis":app.street.xy(axis),"push":app.street.xy(push),"operator":carrier.pos.duplicate(),"phase":"idle","elapsed":0.0,"distance":0.0,"velocity":0.0,"coasting":false,"hits":{},"attack_id":"","retreat_left":0.0,"seen_sign":false,"travel":{}}

func add_regular_bed(room:String,wanted:Vector2) -> bool:
 var space=app.street.floor_for(room)
 for radius_index in range(25):
  for direction:Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
   var at:Vector2=wanted+direction*float(radius_index)*.15
   if not space.walkable(at) or app.street.bed_blocks(room,at,.21):continue
   if not app.street.Bed.clear(space,at,direction):continue
   var free:bool=true
   for id in app.street.data.actors:
    var a:Dictionary=app.street.data.actors[id]
    if a.present and a.room==room and app.street.Bed.touches(at,direction,app.street.position(str(id)),.24):free=false;break
   if not free:continue
   var a:Dictionary=cast("assistant",room,at);a.direction=app.street.xy(direction)
   return true
 return false

func present_count() -> int:
 var count:int=0
 for a:Dictionary in app.street.data.actors.values():
  if a.present:count+=1
 return count

func setup_mixed_doors() -> bool:
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(initial_street))),"mixed-door fixture restores isolated actual Street entry")
 app.set_process(false);app.paused_manual=true;app.enter_room("street_narrow");no_street()
 var west="street_plaza";var east="street_twisted"
 var wp:Dictionary=app.street.floor_for(west).portal("street_narrow")
 var ep:Dictionary=app.street.floor_for(east).portal("street_narrow")
 var wt:=Vector2(-wp.inward.y,wp.inward.x);var et:=Vector2(-ep.inward.y,ep.inward.x)
 cast("wheelchair",west,Vector2(wp.landing)-wt*.38,true)
 cast("register_nurse",west,Vector2(wp.landing)+wt*.38)
 dead_bed(east,Vector2(ep.landing)+Vector2(ep.inward)*.4-et*.38,ep.inward)
 cast("postop",east,Vector2(ep.landing)+et*.38)
 for pair:Array in [["back",west],["warder",west],["doctor",west],["transporter_hospital",west],["mother",east],["archivist",east],["director",east],["transport_patient","street_narrow"],["nurse","street_narrow"]]:
  var room:String=pair[1];var size:Vector2=app.street.floor_for(room).world_size()
  var at:Vector2=safe_stand(room,Vector2(size.x*.55,size.y*.22))
  if not at.is_finite():return false
  cast(str(pair[0]),room,at)
 if not add_regular_bed(east,Vector2(7,8)):return false
 mixed_fixture=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 dump_json("dual_initial_fixture.json",mixed_fixture)
 return true

func move_blocker_inward(id:String) -> bool:
 var a:Dictionary=app.street.data.actors[id]
 var portal:Dictionary=app.street.floor_for(str(a.room)).portal("street_narrow")
 var goal:Vector2=app.street.position(id)+Vector2(portal.inward)*1.4
 var legal:bool=true
 for index in range(100):
  var before:Vector2=app.street.position(id)
  app.street._move_actor(id,goal,.025)
  legal=legal and before.distance_to(app.street.position(id))<=.022501
 return legal and app.street.position(id).distance_to(goal)<.05

func dual_case() -> void:
 var valid:bool=setup_mixed_doors()
 check(valid and present_count()==14,"declared fourteen-body mixture retains two distinct beds and dead wheelchair")
 if not valid:return
 var chair_at:Array=app.street.data.actors.wheelchair.pos.duplicate()
 var bed_center:Array=app.street.data.lateral_bed.center.duplicate()
 pending("street_plaza");step(.025)
 check(not app.street._landing_clear("street_narrow","street_plaza",0) and not app.street._landing_clear("street_narrow","street_twisted",0),"both pending mouths are truly occupied by rigid object plus live body")
 check(app.room_id=="street_narrow" and app.street.data.destination=="street_plaza","mixed west obstruction retains existing pass intent")
 pending("street_twisted");step(.1)
 check(app.room_id=="street_narrow" and app.street.data.destination=="street_twisted","independent east rigid bed also blocks actual crossing")
 check(disk() and present_count()==14,"real JSON retains mixed cast, stopped bed, dead chair and pending door")
 app.set_process(false);app.paused_manual=true
 var checkpoint:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 var clock:float=app.street.data.clock;var left:float=app.street.data.door_left
 app._process(.7)
 check(is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(left,float(app.street.data.door_left)),"actual paused process freezes mixed pending retry clock")
 await capture("01_mixed_dual_pending")
 pending("street_plaza")
 check(move_blocker_inward("register_nurse"),"west live blocker really navigates away beside stationary dead wheelchair")
 var lane:Dictionary=app.street.hero_portal("street_plaza")
 check(absf(float(lane.get("lane_offset",0)))>.4,"dead wheelchair keeps its footprint while existing aperture exposes legal side lane")
 check(await_cross("street_plaza"),"pending west intent actually resumes and crosses among larger mixed cast")
 check(same_point(app.street.data.actors.wheelchair.pos,chair_at) and app.street.data.actors.wheelchair.hp==0,"west crossing preserves dead wheelchair pose across JSON precision conversion")
 check(not app.street.bed_blocks(app.room_id,app.hero_pos,.21),"west arrival stands outside actual dead wheelchair footprint")
 dump_json("west_final_snapshot.json",app.snapshot_data())
 await capture("02_dead_wheelchair_lane")
 check(app.restore_snapshot(checkpoint),"actual saved mixed blocked-east branch restores without reconstructing cast")
 app.set_process(false);app.paused_manual=true
 check(move_blocker_inward("postop"),"east live blocker navigates along remaining lane beside original rigid bed")
 check(await_cross("street_twisted"),"same saved east pending intent resumes through physically free bed side lane")
 check(same_point(app.street.data.lateral_bed.center,bed_center) and app.street.data.actors.transporter_asylum.hp==0,"east passage preserves stopped dead-carrier bed across JSON precision conversion")
 check(not app.street.bed_blocks(app.room_id,app.hero_pos,.21),"east arrival stands outside actual dead carrier bed footprint")
 check(app.rules.hp==100 and app.street.data.actors.size()==45,"stationary objects/retries/save cannot fabricate damage or duplicate identities")
 dump_json("dual_final_snapshot.json",app.snapshot_data())
 await capture("03_stopped_bed_lane")

func setup_live() -> bool:
 if not app.restore_snapshot(JSON.parse_string(JSON.stringify(initial_street))):return false
 app.set_process(false);app.paused_manual=true;app.enter_room("street_twisted");no_street()
 var size:Vector2=app.layout.world_size()
 var mouth:Dictionary=app.layout.portal("street_narrow")
 app.hero_pos=Vector2(mouth.landing)+Vector2(mouth.inward)*.7
 var center:Vector2=safe_stand(app.room_id,Vector2(size.x*.5,size.y*.67))
 if not center.is_finite():return false
 dead_bed(app.room_id,center,Vector2.DOWN)
 var chair:Vector2=safe_stand(app.room_id,Vector2(size.x*.4,size.y*.25),true)
 if not chair.is_finite():return false
 cast("wheelchair",app.room_id,chair,true)
 for pair:Array in [["warder",Vector2(.31,.48)],["mother",Vector2(.44,.36)],["director",Vector2(.59,.25)],["register_nurse",Vector2(.25,.22)],["back",Vector2(.33,.82)],["postop",Vector2(.70,.83)],["speaker",Vector2(.78,.28)]]:
  var at:Vector2=safe_stand(app.room_id,Vector2(pair[1])*size)
  if not at.is_finite():return false
  cast(str(pair[0]),app.room_id,at)
 if not add_regular_bed(app.room_id,Vector2(size.x*.66,size.y*.60)):return false
 app.street.data.route_left=0;app.street.data.door_left=-1;app.street.data.destination=""
 app.hero_route=PackedVector2Array();app.rules.end_control();app.rules.hp=100;app.rules.sp=80
 dump_json("live_initial_fixture.json",app.snapshot_data())
 return true

func live_case() -> void:
 var valid:bool=setup_live()
 check(valid and present_count()==10,"one-room ordinary-process fixture has ten mixed bodies including both beds and dead chair")
 if not valid:return
 var dead_chair:Array=app.street.data.actors.wheelchair.pos.duplicate()
 var dead_center:Array=app.street.data.lateral_bed.center.duplicate()
 var elapsed:float=0;var still:float=0;var last:Vector2=app.hero_pos
 var max_attackers:int=0;var previous:String="";var start:String=app.room_id
 app.paused_manual=false;app.set_process(true)
 while elapsed<90 and app.room_id==start and app.rules.hp>0:
  await get_tree().process_frame
  var delta:float=get_process_delta_time();elapsed+=delta
  var active:int=0;var actors:Array=[]
  for id in app.street.data.actors:
   var a:Dictionary=app.street.data.actors[id]
   if a.present and a.hp>0 and a.room==app.room_id:
    actors.append([id,a.phase,a.pos])
    if a.hostile and a.phase in ["windup","attack"]:active+=1
  max_attackers=maxi(max_attackers,active)
  var signature:String=JSON.stringify([app.room_id,app.rules.hp,app.rules.gripped,actors])
  if signature!=previous and (live_timeline.is_empty() or elapsed-float(live_timeline[-1].elapsed)>.15):
   live_timeline.append({"elapsed":elapsed,"room":app.room_id,"hp":app.rules.hp,"hero_m":[app.hero_pos.x,app.hero_pos.y],"active_attackers":active,"actors":actors});previous=signature
  if app.hero_pos.distance_to(last)<.0001 and not app.rules.body_busy() and not app.rules.gripped and not app.world_paused():still+=delta
  else:still=0
  if still>20:break
  last=app.hero_pos
 app.paused_manual=true;app.set_process(false)
 check(app.room_id=="street_node" and app.rules.hp>0,"ordinary autonomous process actually exits ten-body mixed street to next source segment")
 check(still<=20 and max_attackers<=2,"bounded mixed attack scheduling and no unexplained twenty-second standstill")
 check(app.street.data.actors.wheelchair.pos==dead_chair and app.street.data.lateral_bed.center==dead_center,"ordinary mixed encounter keeps actual dead-object positions")
 var seen:Dictionary={};var unique:bool=true
 for fact:Dictionary in app.rules.facts:
  if str(fact.kind)!="combat_hit":continue
  if seen.has(str(fact.event_id)):unique=false
  seen[str(fact.event_id)]=true
 check(unique and app.street.data.actors.size()==45,"actual mixed receipts and identities remain unique across the passage")
 dump_json("live_snapshot.json",app.snapshot_data())
 dump_json("live_result.json",{"elapsed_game_seconds":elapsed,"max_simultaneous_attackers":max_attackers,"still_seconds":still,"hp":app.rules.hp,"room":app.room_id,"timeline":live_timeline,"scope":"Explicit single-room ten-identity poses: two initially stationary dead objects, original assistant bed, three hostile tool carriers and remaining neutral/friendly bodies. After initialization ordinary _process only; no route/position/seed/contact/damage/ending writes. Not natural-RNG all45 or all mixed crowd combinations."})
 await capture("04_actual_mixed_autonomous_exit")

func performance_case() -> void:
 var valid:bool=setup_live()
 check(valid and present_count()==10,"performance sample restores same ten-body explicit occupancy fixture")
 if not valid:return
 var origin:String=app.room_id
 var start:int=Time.get_ticks_usec();var times:Array=[];var last:int=start;var heavy:int=0
 var limit:int=30
 if "--perf-hot" in OS.get_cmdline_user_args():limit=360
 if "--perf-full" in OS.get_cmdline_user_args():limit=900
 app.paused_manual=false;app.set_process(true)
 for index in range(limit):
  await get_tree().process_frame
  var now:int=Time.get_ticks_usec();var span:float=float(now-last)/1000000.0
  times.append(span);last=now
  if index>10 and span>.1:heavy+=1
  if (heavy>=8 and "--perf-full" not in OS.get_cmdline_user_args()) or now-start>60000000 or app.room_id!=origin:break
 app.paused_manual=true;app.set_process(false)
 var total:float=float(Time.get_ticks_usec()-start)/1000000.0
 dump_json("performance_result.json",{"frames":times.size(),"wall_seconds":total,"actual_fps":float(times.size())/total,"frame_seconds":times,"room_start":origin,"room_end":app.room_id,"hp":app.rules.hp,"collection":"Only Time.get_ticks_usec once per frame, no actor scans, signature JSON, screenshots or timeline in loop. Ordinary enabled app._process; same ten-body fixture as first run."})
 dump_json("performance_snapshot.json",app.snapshot_data())
 if "--perf-full" in OS.get_cmdline_user_args():
  check(app.room_id=="street_node" and app.rules.hp>0,"timed ordinary ten-body encounter actually reaches next source segment alive")
  var seen:Dictionary={};var unique:bool=true
  for fact:Dictionary in app.rules.facts:
   if str(fact.kind)!="combat_hit":continue
   if seen.has(str(fact.event_id)):unique=false
   seen[str(fact.event_id)]=true
  check(unique and app.street.data.actors.size()==45,"timed passage retains unique damage receipts and original identities")

func hotspot_case() -> void:
 var source_path:String="res://../docs/validation/street_mixed_20261019/perf_hot/performance_snapshot.json"
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--hot-source="):source_path=argument.trim_prefix("--hot-source=")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path))
 var result:Dictionary={"fixture":"Actual performance snapshot after 98 ordinary process frames, no actor/route edits.","method_seconds":{}}
 if "--profile-calls" in OS.get_cmdline_user_args():
  app.restore_snapshot(source);app.set_process(false);app.paused_manual=true
  var profiled=load("res://tests/street_profile_layout.gd").new(app.room_id)
  app.layout=profiled;app.street.layouts[app.room_id]=profiled;profiled.calls.clear()
  var begin:int=Time.get_ticks_usec();app.street._hero(.025)
  result.hero_seconds=float(Time.get_ticks_usec()-begin)/1000000.0;result.calls=profiled.calls
  begin=Time.get_ticks_usec();var threat:bool=app.street.belt.contains(app.hero_pos)
  result.belt_contains_seconds=float(Time.get_ticks_usec()-begin)/1000000.0;result.belt_contains=threat
  dump_json("profile_calls.json",result);return
 var ids:Array=[]
 for id in source.street_state.actors:
  if source.street_state.actors[id].present:ids.append(id)
 for id in ids:
  app.restore_snapshot(source);app.set_process(false);app.paused_manual=true
  var before:int=Time.get_ticks_usec();app.street._actor(str(id),.025)
  result.method_seconds["actor:"+str(id)]=float(Time.get_ticks_usec()-before)/1000000.0
 app.restore_snapshot(source);app.set_process(false);app.paused_manual=true
 var before:int=Time.get_ticks_usec();app.street._hero(.025)
 result.method_seconds.hero=float(Time.get_ticks_usec()-before)/1000000.0
 app.restore_snapshot(source);app.set_process(false);app.paused_manual=true
 before=Time.get_ticks_usec();app.street.tick(.025)
 result.method_seconds.full_tick=float(Time.get_ticks_usec()-before)/1000000.0
 app.restore_snapshot(source);app.set_process(false);app.paused_manual=true
 var space=app.layout;var patches:Array=[]
 patches.append(app.street.lateral_bed.push_blocker(space,app.street.displays.chair_rect(app.street.position("wheelchair"))))
 var bed:Dictionary=app.street.data.lateral_bed
 patches.append(app.street.lateral_bed.push_blocker(space,app.street.lateral_bed.rect(),{"at":app.street.lateral_bed.anchor(app.street.vector(bed.center),app.street.vector(bed.axis)),"axis":app.street.vector(bed.axis)}))
 var goal:Vector2=app.street.hero_doorway("street_node");var bodies:Array=[]
 for id in ids:
  var a:Dictionary=app.street.data.actors[id]
  if a.hp>0 and app.street.position(str(id)).distance_to(app.hero_pos)<=float(app.street.config.test_parameters.hero_vision_m) and app.street.can_see(app.room_id,app.hero_pos,app.street.position(str(id))):bodies.append({"pos":app.street.position(str(id)),"radius":.47})
 before=Time.get_ticks_usec();var static_path:PackedVector2Array=space.path(app.hero_pos,goal)
 result.method_seconds.patched_static_path=float(Time.get_ticks_usec()-before)/1000000.0
 before=Time.get_ticks_usec();var dynamic_path:PackedVector2Array=space.path_around_bodies(app.hero_pos,goal,bodies)
 result.method_seconds.patched_body_path=float(Time.get_ticks_usec()-before)/1000000.0
 before=Time.get_ticks_usec();space.rebuild_grid()
 result.method_seconds.patched_full_grid_rebuild=float(Time.get_ticks_usec()-before)/1000000.0
 before=Time.get_ticks_usec();space.clipped_step(app.hero_pos,app.hero_pos+Vector2.RIGHT)
 result.method_seconds.patched_clipped_step=float(Time.get_ticks_usec()-before)/1000000.0
 result.path_inputs={"a":app.street.xy(app.hero_pos),"b":app.street.xy(goal),"bodies":bodies.size(),"static_points":static_path.size(),"body_points":dynamic_path.size()}
 patches.reverse()
 for patch in patches:app.street.lateral_bed.pop_blocker(space,patch)
 dump_json("hotspot_result.json",result)

func compare_belt(label:String,previous:Array=[]) -> void:
 var mother_mode:bool=cache_subject=="mother"
 var belt=app.street.mother if mother_mode else app.street.belt
 var legacy=load("res://tests/street_legacy_mother.gd" if mother_mode else "res://tests/street_legacy_belt.gd").new(app.street)
 var before:int=Time.get_ticks_usec();var old:Dictionary={"points":legacy.clipped(legacy.shape(1)),"blocked":false} if mother_mode else legacy.sweep_between(0,1)
 var old_seconds:float=float(Time.get_ticks_usec()-before)/1000000.0
 before=Time.get_ticks_usec();var points:Array=belt._windup_arms() if mother_mode else belt._windup_points()
 var fresh_seconds:float=float(Time.get_ticks_usec()-before)/1000000.0
 check(points==old.points,label+" retains every original predicted strip point")
 if not previous.is_empty():check(previous!=belt.prediction_key,label+" immediately invalidates exact geometry cache")
 var matches:bool=true;var at:Vector2=app.street.position(cache_subject)
 for offset:Vector2 in [Vector2(.6,0),Vector2(1.2,.5),Vector2(-.2,0),Vector2(0,.7)]:
  matches=matches and legacy.contains(at+offset)==belt.contains(at+offset)
 check(matches,label+" preserves original target containment")
 before=Time.get_ticks_usec()
 if mother_mode:belt._windup_arms()
 else:belt._windup_points()
 cache_evidence.append({"case":label,"legacy_sweep_seconds":old_seconds,"fresh_cached_seconds":fresh_seconds,"warm_seconds":float(Time.get_ticks_usec()-before)/1000000.0,"points":points.size(),"blocked":old.blocked})

func cache_case() -> void:
 var mother_mode:bool="--mother-cache" in OS.get_cmdline_user_args()
 cache_subject="mother" if mother_mode else "warder"
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/validation/street_mixed_20261019/perf_after_fast/performance_snapshot.json" if mother_mode else "res://../docs/validation/street_mixed_20261019/perf_hot/performance_snapshot.json"))
 check(app.restore_snapshot(source),"cache comparison restores actual slow ordinary-process snapshot")
 app.set_process(false);app.paused_manual=true
 var belt=app.street.mother if mother_mode else app.street.belt;var a:Dictionary=app.street.data.actors[cache_subject]
 compare_belt("actual open windup")
 var previous:Array=belt.prediction_key.duplicate(true);a.pos[0]=float(a.pos[0])+.0134;compare_belt("sub-cell source move",previous)
 previous=belt.prediction_key.duplicate(true);a.direction=app.street.xy(app.street.vector(a.direction).rotated(.17));compare_belt("actual turn",previous)
 previous=belt.prediction_key.duplicate(true);app.layout.furniture[0].rect.position+=Vector2(.013,.007);compare_belt("sub-cell furniture move",previous)
 previous=belt.prediction_key.duplicate(true);app.layout.furniture[0].solid=false;compare_belt("disabled solid footprint",previous)
 previous=belt.prediction_key.duplicate(true);app.layout.furniture[0].solid=true;app.layout.furniture[0].collision=false;compare_belt("disabled collision footprint",previous)
 previous=belt.prediction_key.duplicate(true);app.layout.furniture[0].collision=true;app.layout.furniture[0].collision_rects=[Rect2(app.layout.furniture[0].rect.position,Vector2(.1,.1))];compare_belt("compound footprint change",previous)
 previous=belt.prediction_key.duplicate(true)
 var anchor:Vector2=app.street.position(cache_subject)+app.street.vector(a.direction)*.5
 var axis:=Vector2(.8,.6);var rect:Rect2=app.street.Bed.bounds(anchor,axis)
 var patch:Dictionary=app.street.lateral_bed.push_blocker(app.layout,rect,{"at":anchor,"axis":axis})
 compare_belt("temporary rotated bed",previous)
 previous=belt.prediction_key.duplicate(true);app.street.lateral_bed.pop_blocker(app.layout,patch);compare_belt("rotated bed removed",previous)
 previous=belt.prediction_key.duplicate(true)
 patch=app.street.lateral_bed.push_blocker(app.layout,Rect2(app.street.position(cache_subject)+app.street.vector(a.direction)*.4-Vector2(.1,.1),Vector2(.2,.2)))
 compare_belt("temporary wheelchair footprint",previous)
 app.street.lateral_bed.pop_blocker(app.layout,patch)
 previous=belt.prediction_key.duplicate(true);a.pos=[.45,5.0];a.direction=[-1,0];compare_belt("wall-edge original stop sample",previous)
 previous=belt.prediction_key.duplicate(true);belt.attack().reach+=.01;compare_belt("attack geometry parameter",previous);belt.attack().reach-=.01
 var sample_key:String="mother_sample_m" if mother_mode else "belt_sample_m"
 previous=belt.prediction_key.duplicate(true);app.street.config.test_parameters[sample_key]+=.001;compare_belt("sampling parameter",previous);app.street.config.test_parameters[sample_key]-=.001
 previous=belt.prediction_key.duplicate(true);a.room="street_plaza";compare_belt("source room and layout change",previous)
 previous=belt.prediction_key.duplicate(true)
 check(disk(),"actual JSON restore during cache comparison succeeds")
 app.set_process(false);app.paused_manual=true;compare_belt("restored layout instance",previous)
 check(not JSON.stringify(app.snapshot_data()).contains("prediction_key") and not JSON.stringify(app.snapshot_data()).contains("prediction_points"),"cached predictions remain transient outside save facts")
 dump_json("cache_equivalence.json",{"cases":cache_evidence,"reference":"Test-only exact pre-optimization clipped and uncached contains; actual attack state/prepare/receipts unchanged."})

func grid_mask(space) -> PackedByteArray:
 var result:=PackedByteArray()
 for y in range(space.grid.region.position.y,space.grid.region.end.y):
  for x in range(space.grid.region.position.x,space.grid.region.end.x):result.append(1 if space.grid.is_point_solid(Vector2i(x,y)) else 0)
 return result

func mask_case() -> void:
 var fixtures:Array=[{"label":"Street nested rigid occupancy","space":app.street.floor_for("street_twisted"),"from":"street_narrow","to":"street_node"},{"label":"legacy L5 geometry v2","space":load("res://scripts/world/combat_layout.gd").new("atrium",true,2),"from":"memory","to":"decision"},{"label":"current L5 geometry v3","space":load("res://scripts/world/combat_layout.gd").new("atrium",true,3),"from":"memory","to":"decision"}]
 var evidence:Array=[]
 for fixture:Dictionary in fixtures:
  var space=fixture.space;var nested:Array=[]
  if str(fixture.label).begins_with("Street"):
   var at:=Vector2(10,8);var axis:=Vector2(.8,.6)
   nested.append(app.street.lateral_bed.push_blocker(space,Rect2(7.55,2.55,.9,.9)))
   nested.append(app.street.lateral_bed.push_blocker(space,app.street.Bed.bounds(at,axis),{"at":at,"axis":axis}))
  var before:PackedByteArray=grid_mask(space)
  var a:Vector2=space.portal(fixture.from).landing;var b:Vector2=space.portal(fixture.to).landing
  for angle:float in [0.0,.41,1.18,PI*.5]:
   var at:Vector2=space.world_size()*.5;var axis:Vector2=Vector2.RIGHT.rotated(angle)
   var rect:Rect2=app.street.Bed.bounds(at,axis)
   var patch:Dictionary=space.push_movable_blocker(rect)
   var local:PackedByteArray=grid_mask(space);var local_path:PackedVector2Array=space.path_around_bodies(a,b,[])
   space.pop_movable_blocker(patch)
   check(grid_mask(space)==before,str(fixture.label)+" exact nested mask restored after local pop "+str(angle))
   var old:Array[Rect2]=space.movable_blockers.duplicate();space.movable_blockers.append(rect);space.rebuild_grid()
   var full:PackedByteArray=grid_mask(space);var old_path:PackedVector2Array=space.path_around_bodies(a,b,[])
   check(full==local,str(fixture.label)+" local mask equals every old rebuilt cell "+str(angle))
   check(old_path==local_path,str(fixture.label)+" actual path equals old rebuilt path "+str(angle))
   space.movable_blockers=old;space.rebuild_grid()
   check(grid_mask(space)==before,str(fixture.label)+" old full restoration equals local restoration "+str(angle))
   evidence.append({"fixture":fixture.label,"angle":angle,"grid_cells":full.size(),"path_points":old_path.size(),"mask_equal":full==local,"path_equal":old_path==local_path})
  nested.reverse()
  for patch:Dictionary in nested:app.street.lateral_bed.pop_blocker(space,patch)
 dump_json("mask_equivalence.json",{"cases":evidence,"scope":"Full-grid old/new temporary assistant-bed AABB masks and exact routes; includes already-patched oriented lateral bed plus dead-wheelchair footprint; legacy L5 v2 and current v3. No static/body geometry or navigation rules changed."})

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_mixed_20261019/r1"
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="混合人群与双门实占地恢复"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);app.paused_manual=true;clear_lines();app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();no_street()
 initial_street=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 if "--mask-check" in OS.get_cmdline_user_args():mask_case()
 elif "--belt-cache" in OS.get_cmdline_user_args() or "--mother-cache" in OS.get_cmdline_user_args():cache_case()
 elif "--hotspot-only" in OS.get_cmdline_user_args():hotspot_case()
 elif "--perf-only" in OS.get_cmdline_user_args():await performance_case()
 else:
  await dual_case()
  if "--finite-only" not in OS.get_cmdline_user_args():await live_case()
 dump_json("result.json",{"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"New fourteen-identity dual-door/rigid-body finite recovery and separate ten-body ordinary-process passage. Initial object deaths are explicit occupancy fixtures, never claimed as actual attack/death events. Real disk/pause/movement/crossing retained. Not old four-body retest, final art/audio, all crowds or B7."})
 if not failures.is_empty():dump_json("failure_snapshot.json",app.snapshot_data())
 print("STREET_MIXED_CROWD ",passes.size()," passed ",failures.size()," failed")
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
