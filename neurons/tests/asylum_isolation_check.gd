extends "res://tests/asylum_events_check.gd"
## Finite GPU fixtures enter at an explicitly signed, physically located order
## AFTER ordinary delivery. No test sets a successful grip or closed door.

func iso3():return app.asylum.isolation
func isolation_receipt(id:String) -> bool:return rec3(id)
func fact_count3(kind:String) -> int:
 var result:int=0
 for fact in app.rules.facts:
  if str(fact.get("kind",""))==kind:result+=1
 return result

func isolation_fixture(target:String="hero",hero_room:String="quiet",hero_at:Vector2=Vector2(2.8,1.6),signed_order:bool=true,attempt_offset:int=0) -> String:
 fixture3(hero_room,true);app.session.data.exploration_boundary=true
 app.hero_pos=hero_at;app.hero_route=PackedVector2Array();app.target_index=-1
 actor3("isolation_orderly","corridor",Vector2(3.3,0.65))
 if target!="hero":actor3(target,"quiet",Vector2(2.8,1.6))
 var station:Vector2=app.layout_for_room("corridor").furniture[0].at
 var id:String="fixture-isolation:%d:%s"%[app.rules.actual_attempt,target]
 # Declared intermediate input, not a fabricated outcome of this suite:
 # the earlier reporter/signature/ordinary-delivery chain has its own suite.
 # The isolation worker must still walk to this station and take this paper.
 app.asylum.ward_events.state().reports.append({
  "id":id,"event":"explicit_signed_handoff_fixture","source":"explicit_test_input_after_ordinary_delivery","target":target,
  "attempt":app.rules.actual_attempt+attempt_offset,"written":true,"received":true,"permit_given":false,
  "ordinary_taken":true,"ordinary_outcome":"delivered","isolation_order":"isolate:"+id,"isolation_signed":signed_order,
  "isolation_taken":false,"last_room":hero_room if target=="hero" else "quiet",
  "last_pos":app.asylum.xy(hero_at if target=="hero" else Vector2(2.8,1.6)),"station_pos":app.asylum.xy(station),
  "patient_number":null,"head_nurse_witnessed":false})
 check(app.layout.walkable(app.hero_pos) and app.asylum.layout_for("corridor").walkable(app.asylum.position("isolation_orderly")),"isolation initial protagonist and staff stand on real walkable floor")
 return id

func original_report(id:String) -> Dictionary:return app.asylum.ward_events.report_for_id(id)

func wait_for_closed(seconds:float=30.0) -> bool:
 return until3(func():return bool(iso3().state().door_closed),seconds)

func finish3() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"B3 finite isolation integration with actual movement, paper contact, grip preparation/contact, paired doorway travel, door timing, indoor autonomy/search, paid JOY/WITHDRAW and checksummed schema2 JSON. Actual rendered viewport captures; fixed test conditions, not normal-speed human play or every random combination.",
  "fixtures":"Explicitly signed/current-attempt report at real nurse-station stand after ordinary staff delivery; initial identities/positions are declared. Negative cases alter only signature/attempt/last-seen input, initial absence or a visible physical obstacle. Tests never set successful grip, door closure, 8-second completion or item/knowledge rewards.",
  "untested":"Full initial informer-to-signature chain in this suite; all competing-holder/arrival permutations; natural RNG; formal art, voice or subjective sound; non-null approved number glyphs; target-platform export."},"  "));f.close()
 print("ASYLUM_ISOLATION_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/isolation"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="安静室隔离验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.asylum.isolation==null:
  check(false,"isolation is connected to the normal campaign clock and actor owner");finish3();return

 var id:String=isolation_fixture("hero","quiet",Vector2(2.8,1.6),false)
 step3(10)
 check(not original_report(id).isolation_taken and iso3().state().phase=="idle" and not app.rules.gripped,"unsigned ordinary delivery is not an isolation warrant and starts no grip")
 check(app.rules.hp==100 and app.rules.sp==100 and not iso3().state().door_closed,"an unsigned page causes no damage, recovery or invented closed door")
 id=isolation_fixture("hero","quiet",Vector2(2.8,1.6),true,1);step3(10)
 check(not original_report(id).isolation_taken and not iso3().state().hero_attempted,"another actual attempt's signed report cannot punish this attempt")
 id=isolation_fixture();app.asylum.actor("isolation_orderly").phase="absent";step3(12)
 check(not original_report(id).isolation_taken and not app.rules.gripped and not iso3().state().door_closed,"missing isolation staff leave paper waiting without spawning a substitute or remotely grabbing")

 id=isolation_fixture("hero","activity",Vector2(4.1,2.35))
 original_report(id).last_room="quiet";original_report(id).last_pos=[2.8,1.6]
 check(until3(func():return iso3().state().handled.has(id),25),"staff actually take the order, walk to the report's old room and end a failed local search")
 check(iso3().state().handled.get(id,"")=="not_found_at_last_seen" and app.asylum.actor("isolation_orderly").room=="quiet","unseen target's current activity-room position never becomes a global pursuit waypoint")
 check(not app.rules.gripped and not iso3().state().hero_attempted,"not finding a target creates neither grip nor false contact attempt")

 id=isolation_fixture("hero","quiet",Vector2(3.9,2.55))
 check(until3(func():return original_report(id).isolation_taken,15),"isolation worker really reaches the station and receives this signed paper")
 app.layout.movable_blockers.append(Rect2(0.14,1.0,5.32,0.2))
 for y in range(39):
  for x in range(57):app.layout.grid.set_point_solid(Vector2i(x,y),not app.layout.walkable(Vector2(x,y)*app.layout.CELL))
 step3(12)
 check(app.asylum.actor("isolation_orderly").room=="quiet" and app.asylum.position("isolation_orderly").y<0.86,"a real continuous wall blocks the staff's approach instead of allowing through-wall target contact")
 check(not app.rules.gripped and not iso3().state().door_closed and app.hero_pos.is_equal_approx(Vector2(3.9,2.55)),"wall-separated target is neither absorbed to staff nor assigned an isolation outcome")

 id=isolation_fixture()
 check(until3(func():return iso3().state().phase=="reach",25),"order reading and target confirmation lead to a visible pre-contact grab window")
 check(not app.rules.gripped and app.rules.hp==100 and app.rules.sp==100,"grab preparation is not already restraint or damage")
 step3(0.025);give_skill("WITHDRAW")
 check(cast("WITHDRAW").get("success",false),"real paid WITHDRAW executes before isolation contact")
 check(until3(func():return iso3().state().handled.has(id),3),"pre-contact withdrawal makes this one grab attempt end")
 check(iso3().state().handled.get(id,"")=="grab_missed" and not app.rules.gripped and app.rules.hp==100 and app.rules.sp==100,"a missed grab causes no damage, delivery, closure or lingering holder")
 step3(12)
 check(fact_count3("asylum_isolation_attempt_started")==1 and fact_count3("asylum_isolation_grip")==0,"same signed handoff cannot immediately re-grab after its failed attempt")
 await capture("01_withdraw_ended_one_attempt")

 id=isolation_fixture("hero","activity",Vector2(4.1,2.35))
 check(until3(func():return app.asylum.data.holder=="isolation_orderly",30),"staff physically approach and establish the sole actual isolation holder")
 var grip_time:float=app.rules.world_time
 check(app.rules.hp==100 and app.rules.sp==100 and iso3().blocks_hero(),"actual isolation contact pauses the original action without adding HP or SP loss")
 check(until3(func():return app.asylum.data.holder!="isolation_orderly",6.15),"hero's paired drag releases by the original six-second cap")
 check(app.rules.world_time-grip_time<=6.1 and not app.rules.gripped and app.layout.walkable(app.hero_pos),"capped or delivered drag leaves the hero at a real walkable position")
 var release_room:String=app.room_id;var release_pos:Vector2=app.hero_pos
 var delivery:bool=isolation_receipt("isolation_delivered:"+id)
 if not delivery:
  check(not iso3().state().door_closed and fact_count3("asylum_isolation_started")==0,"an undelivered capped drag does not fabricate arrival or a closed-room isolation")
  step3(0.5)
  check(app.room_id==release_room and app.hero_pos.is_equal_approx(release_pos),"failed delivery releases in place without a later corrective teleport")
 else:check(app.room_id=="quiet","delivery before the six-second cap really reaches the existing quiet room")
 await capture("02_real_drag_release_position")

 id=isolation_fixture("postop_patient","quiet",Vector2(2.8,1.15))
 step3(14)
 check(not iso3().state().door_closed and not isolation_receipt("isolation_grip:"+id),"non-target observer inside quiet room prevents NPC grabbing and door closure")
 check(not iso3().blocks_hero() and not app.rules.gripped and app.asylum.actor("postop_patient").room=="quiet","waiting for the observer does not freeze, relocate or silently isolate either original person")
 app.session.data.exploration_boundary=false;app.route_to_door("corridor")
 check(until3(func():return app.room_id=="corridor",8),"the observer can physically walk to the normal door and leave during pending isolation")
 app.session.data.exploration_boundary=true
 check(wait_for_closed(20),"only after non-target observer actually exits can staff grab, position and close on the NPC target")
 check(app.room_id=="corridor" and not app.rules.gripped and app.asylum.actor("postop_patient").room=="quiet","NPC confinement retains the original patient and leaves the protagonist outside")
 check(not iso3().can_exit("corridor","quiet") and not iso3().blocks_hero(),"a closed NPC isolation door blocks entry while the outside hero stays free")
 check(original_report(id).patient_number==null,"processing an internally bound subject never invents unprovided visible number glyphs")
 await capture("03_npc_isolation_observer_outside")

 id=isolation_fixture()
 check(wait_for_closed(30),"hero already inside is moved to the real observation position and the staff actually close the existing door")
 check(app.room_id=="quiet" and not app.rules.gripped and app.asylum.data.holder=="" and not iso3().blocks_hero(),"door closure releases the grip and does not freeze the room's resident")
 check(not iso3().can_exit("quiet","corridor") and iso3().can_exit("activity","corridor"),"closed-door restriction applies to the actual quiet-room doorway rather than all navigation")
 check(app.rules.hp==100 and app.rules.sp==100,"completed isolation adds no arbitrary injury or healing")
 var start_pos:Vector2=app.hero_pos
 app.session.data.targets=["quiet:1","stairs:0"];app.session.data.key_target="stairs:0";app.session.data.key_owner="stairs:0";app.rules.owners.key="stairs:0"
 app.session.data.exploration_boundary=false;app.action_phase="autonomy";app.hero_route=PackedVector2Array();app.target_index=-1
 check(until3(func():return app.rules.search_active,4),"while the door is closed, autonomous protagonist still really walks to a cabinet and starts searching")
 check(iso3().state().door_closed and app.hero_pos.distance_to(start_pos)>0.2 and app.target_index==1 and is_equal_approx(app.rules.search_duration,6.0),"indoor movement and normal six-second search remain executable during isolation")
 await capture("04_indoor_search_with_closed_door")
 var closed_elapsed:float=float(iso3().state().closed_elapsed);var world:float=app.rules.world_time;var search_elapsed:float=app.rules.search_elapsed
 check(roundtrip() and is_equal_approx(float(iso3().state().closed_elapsed),closed_elapsed) and is_equal_approx(app.rules.search_elapsed,search_elapsed),"real checksummed JSON restores closed-door remaining time together with the ongoing indoor search")
 await frames(12)
 check(is_equal_approx(float(iso3().state().closed_elapsed),closed_elapsed) and is_equal_approx(app.rules.world_time,world),"manual pause freezes isolation observation, indoor action and world clock")
 app.paused_manual=false;app.open_neuron_menu();await frames(15)
 check(app.menu.visible and is_equal_approx(float(iso3().state().closed_elapsed),closed_elapsed) and is_equal_approx(app.rules.world_time,world),"real CRT menu frames freeze observation and world while its UI remains active")
 app.paused_manual=true;app.close_neuron_menu();await get_tree().create_timer(0.25).timeout
 give_skill("JOY");var sp_before:int=app.rules.sp
 check(cast("JOY").get("success",false) and app.rules.sp==mini(100,sp_before+20),"JOY still performs its original independent SP recovery inside the room")
 check(iso3().state().door_closed and is_equal_approx(float(iso3().state().closed_elapsed),closed_elapsed),"JOY neither opens the actual door nor restarts or erases elapsed isolation time")
 check(until3(func():return float(iso3().state().closed_elapsed)>=7.95 or iso3().state().phase!="observing",10),"normal game clock resumes toward the original eight-second observation end")
 check(iso3().state().door_closed and iso3().state().phase=="observing" and float(iso3().state().closed_elapsed)<8.0,"door remains physically closed before the complete eight game seconds")
 check(until3(func():return iso3().state().phase=="opening",0.15),"only a full eight seconds after actual closure starts the opening action")
 check(float(iso3().state().closed_elapsed)>=8.0 and iso3().state().door_closed,"opening preparation is not already an open exit")
 step3(0.25);var open_elapsed:float=float(iso3().state().elapsed)
 check(roundtrip() and iso3().state().phase=="opening" and is_equal_approx(float(iso3().state().elapsed),open_elapsed),"JSON resumes a partly opening door without replaying eight seconds or starting over")
 check(until3(func():return not iso3().state().door_closed,0.8) and iso3().can_exit("quiet","corridor"),"actual opening completes within the original one-second limit and releases the exit")
 check(fact_count3("asylum_isolation_started")==1 and fact_count3("asylum_isolation_door_opened")==1 and fact_count3("asylum_isolation_ended")==1,"one source handoff has exactly one actual closure, opening and isolation outcome")
 check(roundtrip(),"completed isolation state is accepted by the normal saved-game schema")
 step3(3)
 check(fact_count3("asylum_isolation_started")==1 and not app.rules.gripped and not iso3().state().door_closed,"load and continued play cannot reclose the door or repeat this signed event")
 await capture("05_open_exit_after_real_observation")

 id=isolation_fixture()
 check(wait_for_closed(30),"early-release case first reaches a genuine closed-door observation")
 step3(0.5);var held_time:float=float(iso3().state().closed_elapsed)
 check(app.asylum.actor("isolation_orderly").room=="corridor" and held_time<8.0 and iso3().state().door_closed,"staff standing just outside the real door still count as observing")
 app.asylum.actor("isolation_orderly").phase="gone"
 check(until3(func():return not iso3().state().door_closed,1.1),"staff actually leaving starts and completes early opening without waiting eight seconds")
 check(not app.rules.gripped and iso3().can_exit("quiet","corridor") and app.rules.hp==100 and app.rules.sp==100,"interrupted observation leaves no lock, holder, injury or recovery")

 id=isolation_fixture()
 check(until3(func():return iso3().state().phase=="closing",30),"dynamic-exit case genuinely reaches door-closing preparation")
 app.session.data.exploration_boundary=false;app.session.data.targets=[]
 app.session.data.key_owner="hero";app.rules.owners.key="hero";app.route_to_door("corridor")
 check(app.action_phase=="door","a pre-closure exit command may begin along a real indoor path")
 step3(2)
 check(app.room_id=="quiet" and iso3().state().door_closed and app.hero_route.is_empty(),"door closing after route start cancels stale departure and cannot bypass actual eight-second confinement")
 step3(2)
 check(app.room_id=="quiet" and not app.rules.gripped and not iso3().blocks_hero(),"cancelled departure leaves indoor agency without silently changing the isolation timer")

 id=isolation_fixture()
 check(wait_for_closed(30),"death cleanup case begins from real prior closure")
 app.rules.hp=0;step3(0.025)
 check(not app.rules.gripped and app.asylum.data.holder=="" and not iso3().state().door_closed and iso3().can_exit("quiet","corridor"),"actual zero HP immediately clears old isolation restrictions before revival rather than retaining a dead holder or locked door")
 finish3()
