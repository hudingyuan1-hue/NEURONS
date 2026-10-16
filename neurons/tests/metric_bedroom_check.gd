extends "res://tests/family_check.gd"
## Physical-space fixtures. Normal RNG/actors are checked separately by fresh_flow.
const LegacyRoom=preload("res://scripts/world/room_layout.gd")
var baseline:Dictionary={}

func click_world(pixel:Vector2) -> void:
 var screen:Vector2=app.world_viewport.get_canvas_transform()*pixel
 screen*=Vector2(1280,720)/Vector2(app.world_viewport.size)
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  Input.parse_input_event(event);await frames(2)

func test_visible_clicks() -> void:
 reset_metric();app.paused_manual=false;app.rules.control_left=20.0;app.input_lock_frames=0
 # Choose an exposed visible top-left portion, away from the tall foreground
 # wardrobe. The hit must use the elevated face, not its ground projection.
 var shelf:Dictionary=app.layout.furniture[8]
 var pixel:Vector2=app.layout.project(shelf.rect.position)+Vector2(8,-float(shelf.height)+8)
 check(not shelf.rect.has_point(app.layout.unproject(pixel)),"exposed shelf pixel is distinct from its ground footprint")
 await click_world(pixel)
 check(app.target_index==8 and app.action_phase=="controlled_search","actual mouse on elevated shelf selects physical shelf approach")
 app.paused_manual=true;await capture("visible_shelf_click")
 reset_metric();app.paused_manual=false;app.rules.control_left=20.0;app.input_lock_frames=0
 var center:Vector2=app.layout.project(Vector2(app.layout.door_position().x,0))-Vector2(0,app.layout.door_height_m*78.0*0.5)
 await click_world(center)
 check(app.status_note.contains("开锁条件") and app.room_id=="bedroom","actual visible door click checks real key requirement")
 app.paused_manual=true

func reset_metric() -> void:
 app.restore_snapshot(baseline.duplicate(true))
 app.home.enabled=false;app.family.enabled=false
 app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=false
 app.session.data.key_discovery.discovered="fixture_geometry_only"
 app.paused_manual=true;clear_lines()

func reset_legacy() -> bool:
 reset_metric()
 # Explicit fresh legacy-coordinate fixture, then all tested actions run
 # through the current production handlers. This is not a historical file.
 var legacy:Dictionary=baseline.duplicate(true)
 var old_room=LegacyRoom.new()
 var start:Vector2=old_room.bed_position()
 legacy.schema=2;legacy.session.erase("room_geometry_version")
 legacy.hero_pos=[start.x,start.y];legacy.route=[];legacy.target_index=-1
 legacy.action_phase="autonomy";legacy.hero_state="idle";legacy.motion={}
 legacy.search_props={};legacy.prop_receipts={};legacy.completed=[]
 legacy.rules.search_active=false;legacy.rules.search_elapsed=0.0
 legacy.rules.search_attempts=0;legacy.rules.search_count=0;legacy.rules._completed_targets={}
 var accepted:bool=app.restore_snapshot(legacy)
 check(accepted and app.layout.geometry_version==1 and app.hero_pos==start,"explicit schema2 fixture retains its legal legacy starting geometry")
 app.session.data.key_discovery.discovered="fixture_geometry_only"
 app.paused_manual=true;clear_lines()
 return accepted

func legacy_snapshot() -> Dictionary:
 var data:Dictionary=app.snapshot_data()
 data.schema=2;data.session.erase("room_geometry_version")
 return data

func roundtrip(data:Dictionary,label:String) -> bool:
 var saved:Dictionary=app.store.save_snapshot(data)
 check(bool(saved.ok),label+" writes checked JSON")
 if not saved.ok:return false
 var loaded:Dictionary=app.store.load_snapshot()
 var accepted:bool=bool(loaded.ok) and app.restore_snapshot(loaded.data)
 check(accepted,label+" restores checked JSON")
 return accepted

func fact_count(kind:String,event_id:String) -> int:
 var count:int=0
 for fact:Dictionary in app.rules.facts:
  if str(fact.get("kind",""))==kind and str(fact.get("event_id",""))==event_id:count+=1
 return count

func test_legacy_search(index:int) -> void:
 if not reset_legacy():return
 var target:String="bedroom:%d"%index
 var label:String="legacy point %d"%index
 app.session.data.targets=[target]
 app.hero_pos=app.layout.door_position()
 var started:bool=until(func():return app.rules.search_active and app.target_index==index,1800)
 check(started,label+" walks from the real door into real search")
 if not started:return
 var halfway:bool=until(func():return app.rules.search_elapsed>=app.rules.search_duration*0.5,300)
 check(halfway and app.rules.search_active,label+" reaches an unfinished physical half-search")
 if not halfway:return
 var at:Vector2=app.hero_pos
 var elapsed:float=app.rules.search_elapsed
 var receipt:String=str(app.rules._search_id)
 var balance:int=app.rules.neurons
 var prop_receipts:Dictionary=app.search_actions.receipts.duplicate(true)
 var props:Dictionary=app.search_actions.states.duplicate(true)
 var upper_event:String=receipt+":移开上层箱"
 if index==5:
  check(app.search_actions.state("box").has("upper_shift") and app.layout.movable_blockers.size()==1,label+" physically moved upper box before save")
  check(fact_count("prop_action",upper_event)==1,label+" upper-box contact has one real action receipt")
 if not roundtrip(legacy_snapshot(),label+" unfinished action"):return
 check(app.layout.geometry_version==1 and app.hero_pos==at and is_equal_approx(app.rules.search_elapsed,elapsed),label+" preserves original contact and elapsed time without teleporting")
 check(app.search_actions.states==props and app.search_actions.receipts==prop_receipts and app.rules.neurons==balance,label+" restores original prop metres and receipts without replay or payment")
 if index==5:
  check(app.layout.movable_blockers.size()==1 and not app.layout.walkable(app.layout.movable_blockers[0].get_center()),label+" restored upper box remains a real blocker")
 await frames(4)
 check(app.hero_pos==at and is_equal_approx(app.rules.search_elapsed,elapsed) and app.rules.neurons==balance,label+" manual pause freezes restored contact")
 await capture("legacy_half_%02d"%index)
 var completed:bool=until(func():return target in app.completed,600)
 check(completed and app.rules.settled.get(receipt,"")=="completed",label+" continues the same real search to completion")
 check(app.rules.neurons==balance+1 and fact_count("search_completed",receipt)==1,label+" completed search pays exactly once")
 if not completed:return
 if index==5:check(fact_count("prop_action",upper_event)==1,label+" resumed later frames do not reapply upper-box contact")
 var completed_props:Dictionary=app.search_actions.receipts.duplicate(true)
 var completed_balance:int=app.rules.neurons
 if not roundtrip(legacy_snapshot(),label+" completed action"):return
 check(app.rules.neurons==completed_balance and fact_count("search_completed",receipt)==1,label+" completed-action reload does not grant a second reward")
 var cycle:int=int(app.session.data.cycle)
 var attempt:int=app.rules.actual_attempt
 # The one declared sampled target is now exhausted. Production autonomy
 # must choose return_bed, traverse its path and perform the 1.2s rest.
 var returning:bool=until(func():return app.action_phase=="return_bed",120)
 check(returning and app.layout.geometry_version==1,label+" exhaustion enters real legacy return-bed navigation")
 if not returning:return
 var resting:bool=until(func():return app.action_phase=="resting",1200)
 check(resting and app.hero_pos.distance_to(app.layout.bed_position())<=0.035,label+" actually reaches bed before rest")
 if not resting:return
 check(int(app.session.data.cycle)==cycle and app.rules.actual_attempt==attempt,label+" reaching bed alone does not migrate or increment attempt")
 var upgraded:bool=until(func():return app.layout.geometry_version==2,150)
 check(upgraded and app.layout.walkable(app.hero_pos),label+" finished physical rest adopts metric geometry")
 check(int(app.session.data.cycle)==cycle+1 and app.rules.actual_attempt==attempt+1,label+" one rest causes one cycle and one attempt transition")
 check(app.rules.neurons==completed_balance and fact_count("search_completed",receipt)==1 and app.search_actions.receipts==completed_props,label+" geometry migration neither replays action receipts nor grants rewards")
 if index==5:
  var expected:Array=app.layout.furniture[5].action_offsets.upper_shift
  check(app.search_actions.state("box").upper_shift==expected and app.layout.movable_blockers.size()==1,label+" new boundary remaps existing box placement to metric action offset once")
  check(fact_count("prop_action",upper_event)==1,label+" boundary remap is not another gameplay contact")
 check(app.store.save_snapshot(app.snapshot_data()).ok and FileAccess.file_exists(ProjectSettings.globalize_path(app.store.root).path_join("profile.schema2.json")),label+" schema3 save preserves an earlier valid schema2 file")
 await capture("legacy_after_rest_%02d"%index)

func test_grip_restore(version:int) -> void:
 if version==1:
  if not reset_legacy():return
 else:reset_metric()
 var label:String="geometry%d father"%version
 app.family.enabled=true
 app.family.start_attempt();app.family.data.extra_checked=true
 # Only deterministic initial presence/probability isolation; no grip, timer,
 # route or contact is injected, and no hidden ending is asserted here.
 app.family.config.probabilities.mother_base=0.0
 app.family.config.probabilities.father_base=0.0
 app.hero_pos=app.layout.bed_position()
 var start:Vector2=app.hero_pos
 app.family.spawn("father")
 var doorway:Vector2=app.family.position("father")
 var preparing:bool=until(func():return app.family.data.father.phase=="grab",1800)
 check(preparing and not app.rules.gripped,label+" walks from actual door and reaches visible grab preparation")
 if not preparing:return
 check(app.family.position("father").distance_to(doorway)>0.1 and app.layout.walkable(app.family.position("father")),label+" preparation follows legal physical movement")
 var held:bool=until(func():return app.rules.gripped,200)
 check(held and app.family.data.father.phase=="steady",label+" timed contact establishes actual grip")
 if not held:return
 var parent_at:Vector2=app.family.position("father")
 var phase_elapsed:float=float(app.family.data.father.elapsed)
 var pressure:float=float(app.family.data.pressure)
 var balance:int=app.rules.neurons
 var saved:Dictionary=legacy_snapshot() if version==1 else app.snapshot_data()
 if not roundtrip(saved,label+" established grip"):return
 check(app.layout.geometry_version==version and app.rules.gripped and app.hero_pos==start and app.family.position("father")==parent_at,label+" JSON retains both paired positions and original geometry")
 check(is_equal_approx(float(app.family.data.father.elapsed),phase_elapsed) and is_equal_approx(float(app.family.data.pressure),pressure) and app.rules.neurons==balance,label+" JSON does not restart the grip clock or award resources")
 await frames(4)
 check(app.rules.gripped and app.hero_pos==start and app.family.position("father")==parent_at and is_equal_approx(float(app.family.data.father.elapsed),phase_elapsed),label+" manual pause freezes restored pair")
 await capture("grip_restore_v%d"%version)
 var dragging:bool=until(func():return app.family.data.father.phase=="drag",200)
 check(dragging and app.rules.gripped,label+" saved stabilization continues into actual drag")
 if not dragging:return
 var before:Vector2=app.hero_pos
 for i in range(16):step(0.025)
 check(app.hero_pos.distance_to(before)>0.05 and app.rules.gripped,label+" restored pair actually moves without re-grabbing")
 check(app.layout.walkable(app.hero_pos) and app.layout.walkable(app.family.position("father")) and app.layout.clear_segment(app.hero_pos,app.family.position("father")),label+" both bodies remain on reachable floor with real contact line")
 check(app.hero_pos.distance_to(app.family.position("father"))<=float(app.family.config.test_parameters.grab_distance) and not app.family.data.hidden_pending,label+" short resumed drag preserves pairing without completing hidden route")
 check(app.rules.neurons==balance and app.session.data.level==1,label+" grip restore grants no reward or level transition")
 await capture("grip_resume_v%d"%version)

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="空间比例验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.opening_ui!=null:app.opening_ui.skip()
 app.paused_manual=true;clear_lines();app.closing_left=0
 baseline=app.snapshot_data()
 check(app.layout.geometry_version==2 and app.world_viewport.size==Vector2i(1280,720),"new profile enters metric room with native world viewport")
 await capture("01_metric_room")
 for index in range(11):
  reset_metric()
  var id:String="bedroom:%d"%index
  app.session.data.targets=[id]
  app.hero_pos=app.layout.door_position()
  var origin:Vector2=app.hero_pos
  check(until(func():return app.rules.search_active,1800),"real approach and facing reach search point %d"%index)
  check(app.hero_pos.distance_to(origin)>0.1 and app.hero_pos.distance_to(app.layout.furniture[index].at)<0.04,"point %d reached through physical route"%index)
  step(0.45)
  var elapsed:float=app.rules.search_elapsed
  var before:int=app.rules.neurons
  var at:Vector2=app.hero_pos
  check(app.store.save_snapshot(app.snapshot_data()).ok,"point %d saves incomplete physical action"%index)
  var disk:Dictionary=app.store.load_snapshot()
  check(disk.ok and app.restore_snapshot(disk.data) and app.hero_pos==at and is_equal_approx(app.rules.search_elapsed,elapsed),"point %d JSON restores contact without reposition or reward"%index)
  await frames(4)
  check(is_equal_approx(app.rules.search_elapsed,elapsed) and app.rules.neurons==before,"point %d manual pause holds action and settlement"%index)
  if index in [1,6,8]:await capture("contact_%02d"%index)
  check(until(func():return id in app.completed,900),"point %d completes real search"%index)
  check(app.rules.neurons==before+1,"point %d grants one physical completion receipt"%index)
  if index in [2,5]:
   var field:String="shift" if index==2 else "upper_shift"
   check(app.search_actions.state(app.layout.furniture[index].id).has(field),"point %d moves its independent prop"%index)
   for f in app.layout.furniture:
    check(app.layout.walkable(f.at) and not app.layout.path(app.hero_pos,f.at).is_empty(),"point %d moved geometry preserves access to %s"%[index,f.id])
   clear_lines();await capture("moved_%02d"%index)
 reset_metric()
 for zoom in [0,1,3]:
  app.zoom_index=zoom;app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*app.ZOOM_STEPS[zoom]
  app.camera.force_update_scroll();await frames(2)
  var pixel:Vector2=app.layout.project(app.hero_pos)
  var screen:Vector2=app.world_viewport.get_canvas_transform()*pixel
  screen*=Vector2(1280,720)/Vector2(app.world_viewport.size)
  check(app.world_mouse_position(screen).distance_to(pixel)<0.001,"zoom %d preserves world click coordinate"%zoom)
  await capture("zoom_%d"%zoom)
 reset_metric()
 app.target_index=1;app.hero_pos=app.layout.furniture[1].at
 app.rules.begin_search("bedroom:1");app.hero_state="search"
 step(1.2);app.view.catalog.select_set("a");await capture("replacement_a")
 var semantic:Dictionary={"pos":app.hero_pos,"elapsed":app.rules.search_elapsed,"owners":app.rules.owners.duplicate(true),"neurons":app.rules.neurons,"props":app.search_actions.states.duplicate(true)}
 app.view.catalog.select_set("b");await capture("replacement_b")
 check(semantic.pos==app.hero_pos and semantic.elapsed==app.rules.search_elapsed and semantic.owners==app.rules.owners and semantic.neurons==app.rules.neurons and semantic.props==app.search_actions.states,"actor and layered cabinet replacement preserves action clock, ownership and movable state")
 await test_visible_clicks()
 await test_legacy_search(1)
 await test_legacy_search(5)
 await test_grip_restore(1)
 await test_grip_restore(2)
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"GPU presentation and fixed-step production handlers, not a normal-speed human playthrough. Geometry fixtures disable unrelated NPCs and key discovery. Legacy v1 fixtures originate from current runtime in schema2 shape, then perform real half-search/moved-box JSON continuation and physical return/rest into v2. Father v1/v2 fixtures select initial presence only and preserve real timed approach/grab/stabilization/drag through JSON. The inherited step driver clears dialogue to isolate mechanics; dialogue pace, random encounters, hidden ending, formal art and subjective listening are not accepted by this suite."},"  "));result.close()
 print("METRIC_BEDROOM_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
