extends "res://tests/opening_campaign_check.gd"
## New geometry only. Finite source-point coverage is deliberately separate
## from the untouched autonomous direct-L4 entry run.
const NeuralMap=preload("res://scripts/core/cortex_map.gd")
var searches:Array=[]
var doors:Array=[]
var natural_visits:Array=[]
var natural_timeline:Array=[]
var finite_elapsed:float=0.0
var finite_step:float=.025
var initial_entry:Dictionary={}
var initial_cortex_enabled:bool=true
var contact_timeline:Array=[]

func dump_json(filename:String,value:Dictionary) -> void:
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join(filename),FileAccess.WRITE)
 file.store_string(JSON.stringify(value,"  "));file.close()

func finite_tick(seconds:float=.025) -> void:
 var left:float=seconds
 while left>.000001:
  # Finite geometry fixtures skip only the already-enqueued dialogue UI;
  # they still use actual movement, action/contact and key settlement.
  while not app.dialogue_queue.is_empty():app.advance_dialogue()
  var delta:float=minf(finite_step,left)
  app.advance_world(delta);finite_elapsed+=delta;left-=delta

func finite_until(predicate:Callable,seconds:float) -> bool:
 for index in range(ceili(seconds/finite_step)):
  if predicate.call():return true
  finite_tick()
 return predicate.call()

func go_to_room(target:String) -> bool:
 for guard in range(30):
  if app.room_id==target:return true
  var before:String=app.room_id
  var next:String=NeuralMap.next_room(before,target)
  if next.is_empty():return false
  app.session.data.exploration_boundary=false
  app.route_to_door(next)
  var reached:bool=finite_until(func():return app.room_id!=before,60)
  app.session.data.exploration_boundary=true
  doors.append({"from":before,"toward":next,"arrived":app.room_id,"reached":reached,"world_time":app.rules.world_time,"position":[app.hero_pos.x,app.hero_pos.y]})
  if not reached:return false
 return app.room_id==target

func search_point(index:int) -> bool:
 var target:String=app.point_id(index)
 var item:Dictionary=app.layout.furniture[index]
 var before_reward:int=app.rules.neurons
 var before_count:int=app.rules.search_count
 var start_position:Vector2=app.hero_pos
 var record:Dictionary={"target":target,"source":item.data.source,"start_m":[start_position.x,start_position.y],"stand_m":[item.at.x,item.at.y],"completed_before":target in app.completed}
 app.target_index=index;app.action_phase="autonomy"
 # Explicit target-selection fixture: only schedule the selected legal point.
 # choose_public_target performs the real route, movement, facing and begin.
 var begun:bool=false
 for guard in range(4000):
  if app.rules.search_active:begun=true;break
  app.choose_public_target(finite_step)
  finite_tick()
 record.begun=begun
 record.contact_error_m=app.hero_pos.distance_to(item.at)
 record.duration_s=app.rules.search_duration
 record.event_id=app.rules._search_id
 check(begun and app.rules.search_target==target,"metric source search actually begins "+target)
 check(record.contact_error_m<=.035 and app.layout.walkable(app.hero_pos),"actual legal stand/contact before search "+target)
 check(is_equal_approx(app.rules.search_duration,7.0),"source seven-second duration "+target)
 if not begun:searches.append(record);return false
 if target=="body:5":
  finite_tick(2.5)
  var elapsed:float=app.rules.search_elapsed
  var payload:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
  var save:Dictionary=app.store.save_snapshot(payload)
  var loaded:Dictionary=app.store.load_snapshot()
  var restored:bool=save.ok and loaded.ok and app.restore_snapshot(loaded.data)
  check(restored and is_equal_approx(app.rules.search_elapsed,elapsed) and app.rules.search_active,"new L4 touch-table real JSON keeps in-flight search")
  record.mid_search_roundtrip=restored
 var finished:bool=finite_until(func():return target in app.completed,9)
 record.completed=finished;record.settlement=app.rules.settled.get(str(record.event_id),"")
 record.neuron_delta=app.rules.neurons-before_reward;record.count_delta=app.rules.search_count-before_count
 record.actual_position_m=[app.hero_pos.x,app.hero_pos.y]
 record.world_time=app.rules.world_time
 check(finished and record.settlement=="completed" and record.neuron_delta==1 and record.count_delta==1,"real completion/once-only reward "+target)
 searches.append(record)
 return finished

func finite_points() -> bool:
 # These are declared fixture conditions, not a natural-RNG acceptance claim.
 # No position, completion, key result or damage is injected after the entry.
 app.cortex.enabled=false
 app.session.data.exploration_boundary=true
 app.paused_manual=true
 var all_ok:bool=true
 for room:String in NeuralMap.ALL_ROOMS:
  var arrived:bool=go_to_room(room)
  check(arrived,"new metric door-to-door handlers reach "+room)
  if not arrived:return false
  if not finite_until(func():return app.arrival_left<=0,3):return false
  for index in range(NeuralMap.POINTS[room].size()):
   if not search_point(index):all_ok=false;break
  if not all_ok:break
  if room in ["atrium","body","identity"]:await capture("finite_"+room)
 check(searches.size()==62 and app.completed.size()==62,"all sixty-two legal L4 source actions genuinely completed")
 check(int(app.session.data.cortex_geometry_version)==2 and app.layout.geometry_version==2,"all finite source actions use fresh metric L4 version2")
 dump_json("finite_snapshot.json",app.snapshot_data())
 dump_json("finite_result.json",{"searches":searches,"doors":doors,"world_seconds":finite_elapsed,"passes":passes,"failures":failures,"fixture":"Actual unlock_cortex entry; NPC processing disabled and chapter exit held for finite geometry coverage. Each next source point is explicitly selected through choose_public_target, then normal advance_world route/search/contact/completion/key handlers run. Original sixteen-key sample and key RNG are not rewritten; no completion, injury, owner or reward fields injected. Existing finite dialogue queued UI is advanced. Separate untouched natural run follows entry restore."})
 return all_ok

func observe_natural() -> void:
 app.cortex.enabled=initial_cortex_enabled
 var restored:bool=app.restore_snapshot(JSON.parse_string(JSON.stringify(initial_entry)))
 check(restored and int(app.session.data.cortex_geometry_version)==2,"natural run restores the actual untouched direct-L4 entry")
 if not restored:return
 app.paused_manual=false
 var elapsed:float=0
 var deadline:float=1200
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--natural-limit="):deadline=float(argument.trim_prefix("--natural-limit="))
 var last:Vector2=app.hero_pos
 var previous:String=app.room_id
 var still:float=0
 var last_signature:String=""
 var next_log:float=0
 var deaths:Array=[]
 var last_death:String=""
 var genuine_l5:bool=false
 while elapsed<deadline and int(app.session.data.level)<6:
  await get_tree().process_frame
  var delta:float=get_process_delta_time();elapsed+=delta
  var key:String="L%d:%s"%[int(app.session.data.level),app.room_id]
  if not key in natural_visits:
   natural_visits.append(key);await capture("natural_%02d_%s"%[natural_visits.size(),app.room_id])
  var signature:String=JSON.stringify([int(app.session.data.level),app.room_id,app.action_phase,app.rules.search_active,app.rules.search_target,app.rules.hp,app.rules.gripped,app.rules.actual_attempt,app.dialogue_queue.size()])
  if signature!=last_signature:
   natural_timeline.append({"elapsed":elapsed,"world_time":app.rules.world_time,"level":app.session.data.level,"room":app.room_id,"action":app.action_phase,"target":app.rules.search_target,"search_elapsed":app.rules.search_elapsed,"searches":app.rules.search_attempts,"hp":app.rules.hp,"sp":app.rules.sp,"position_m":[app.hero_pos.x,app.hero_pos.y],"gripped":app.rules.gripped,"dialogue":app.dialogue_queue.size()})
   last_signature=signature
  if int(app.session.data.level)==5:
   genuine_l5=int(app.combat.data.get("geometry_version",0))==3
  var body_can_move:bool=not app.rules.body_busy() and not app.rules.gripped and not app.rules.search_active and not app.world_paused() and app.rules.hp>0 and app.arrival_left<=0
  if previous==app.room_id and app.hero_pos.distance_to(last)<.0001 and body_can_move:still+=delta
  else:still=0
  if app.rules.hp<=0:
   var death_signature:String=str(app.session.data.level)+":"+JSON.stringify(app.session.data.attempts)
   if death_signature!=last_death:
    deaths.append({"elapsed":elapsed,"level":app.session.data.level,"room":app.room_id,"attempts":app.session.data.attempts.duplicate(true)})
    dump_json("natural_death_%02d.json"%deaths.size(),app.snapshot_data());last_death=death_signature
  if elapsed>=next_log:
   next_log+=30;print("SPATIAL_NEURAL_NATURAL %.1fs L%d %s hp%d searches%d pos%s"%[elapsed,app.session.data.level,app.room_id,app.rules.hp,app.rules.search_attempts,app.hero_pos])
  if still>25:break
  last=app.hero_pos;previous=app.room_id
 app.paused_manual=true
 check(genuine_l5,"natural actual keyed L4 departure reaches new L5 version3")
 check(int(app.session.data.level)==6 and app.street.data.actors.size()==45,"natural L4 to L5 to actual Street doorway retains forty-five identities")
 check(still<=25,"no twenty-five-second unexplained standstill in natural new geometry")
 check(int(app.session.data.level)<5 or app.rules.search_attempts==0,"actual L5 departure cancels key-search gameplay")
 dump_json("natural_snapshot.json",app.snapshot_data())
 dump_json("natural_result.json",{"passes":passes,"failures":failures,"elapsed_game_seconds":elapsed,"visits":natural_visits,"timeline":natural_timeline,"deaths":deaths,"still_seconds":still,"hp":app.rules.hp,"level":app.session.data.level,"attempts":app.session.data.attempts,"scope":"Actual initial unlock_cortex entry snapshot restored before starting. Then ordinary _process only: no seed, NPC, resource, position, route, key, damage, search, event or ending writes; default auto dialogue retained. Actual deaths/retries recorded. Fixed-frame automated observation is not human pacing or all branches."})
 await capture("natural_final")

func contact_sequence() -> void:
 # Separate explicit point/actor fixture. Positions derive from the actual
 # new touch-table stand, never the old room's (3,2) magic coordinates.
 app.cortex.enabled=true
 app.session.data.targets=["body:5"]
 for group in app.cortex.data.groups:app.cortex.data.groups[group].drawn=true
 app.enter_room("body")
 var stand:Vector2=app.layout.furniture[5].at
 var initial_operator:Vector2=app.cortex.beside("body",stand,Vector2(0,.6))
 var operator:Dictionary=app.cortex.actor("misaligned")
 operator.room="body";operator.phase="idle";operator.pos=[initial_operator.x,initial_operator.y]
 operator.elapsed=0.0;operator.route=[];operator.facing=[-1,0]
 check(app.layout.walkable(initial_operator),"new metric touch-table operator starts at a legal derived stand")
 dump_json("contact_initial_fixture.json",app.snapshot_data())
 var initial_hp:int=app.rules.hp
 var got_grip:bool=false
 var got_release:bool=false
 var previous:String=""
 var elapsed:float=0.0
 app.paused_manual=false
 while elapsed<80 and not "body:5" in app.completed:
  await get_tree().process_frame
  elapsed+=get_process_delta_time()
  var state:Dictionary=app.cortex.data.clamp
  var signature:String=JSON.stringify([state.phase,state.hurt,app.rules.hp,app.rules.search_active,app.rules.search_attempts,app.rules.gripped])
  if signature!=previous:
   contact_timeline.append({"elapsed":elapsed,"clamp":state.duplicate(true),"hero_m":[app.hero_pos.x,app.hero_pos.y],"operator":app.cortex.actor("misaligned").duplicate(true),"action":app.action_phase,"search_target":app.rules.search_target,"search_elapsed":app.rules.search_elapsed,"search_attempts":app.rules.search_attempts,"hp":app.rules.hp,"gripped":app.rules.gripped})
   previous=signature
  if state.hurt and app.rules.gripped and not got_grip:
   got_grip=true
   check(initial_hp-app.rules.hp==10 and bool(app.cortex.clamp_hand_state().contact),"actual new metric hand contact closes clamp and settles original ten HP once")
   await capture("contact_actual_grip")
  if got_grip and state.phase=="done" and not app.rules.gripped and not got_release:
   got_release=true;await capture("contact_actual_release")
 app.paused_manual=true
 check(got_grip and got_release,"ordinary process new metric clamp genuinely grips and releases")
 check("body:5" in app.completed and app.rules.search_attempts>=2,"autonomous host retries and genuinely finishes touch-table search after release")
 check(initial_hp-app.rules.hp==10 and app.cortex.data.receipts.has("cortex:1:clamp_damage"),"new geometry cannot duplicate original clamp damage")
 dump_json("contact_snapshot.json",app.snapshot_data())
 dump_json("contact_result.json",{"passes":passes,"failures":failures,"elapsed_game_seconds":elapsed,"timeline":contact_timeline,"hp":app.rules.hp,"scope":"Explicit fresh-L4v2 body:5 target, unrelated random groups suppressed, actual derived legal operator stand. Then ordinary process and default dialogue only; no begin-search, contact, damage, grip, completion or route writes. Formal figure/animation and all operator combinations not accepted."})
 await capture("contact_final")

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/neural_spaces_20261018/sequence"
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="新脑部空间动作与自主链路"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 while not app.dialogue_queue.is_empty():app.advance_dialogue()
 app.closing_left=0;app.paused_manual=true;app.unlock_cortex()
 initial_entry=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 initial_cortex_enabled=app.cortex.enabled
 dump_json("initial_entry.json",initial_entry)
 check(int(app.session.data.level)==4 and int(app.session.data.cortex_geometry_version)==2,"real unlock_cortex selects new L4 metric geometry")
 check(str(app.session.data.key_target).is_empty() and str(app.session.data.key_owner).is_empty(),"no key location is preselected at actual L4 entry")
 if "--contact-only" in OS.get_cmdline_user_args():await contact_sequence()
 else:
  if not "--natural-only" in OS.get_cmdline_user_args():await finite_points()
  if not "--finite-only" in OS.get_cmdline_user_args():await observe_natural()
 dump_json("result.json",{"passes":passes,"failures":failures,"search_count":searches.size(),"doors":doors,"natural_visits":natural_visits,"rendered":DisplayServer.get_name()!="headless","scope":"New L4v2 sixty-two real source actions and separate fresh autonomous L4→L5v3→Street run; fixture and natural evidence are separate files. No formal-art, audio listening or full B7 claim."})
 print("SPATIAL_NEURAL_SEQUENCE ",passes.size()," passed ",failures.size()," failed")
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
