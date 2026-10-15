extends Node
## Finite real-render fixture; no gameplay system is reimplemented here.
var app:Node
var passes:Array[String]=[]
var failures:Array[String]=[]

func check(ok:bool,label:String) -> void:
 (passes if ok else failures).append(label)
 print(("PASS: " if ok else "FAIL: ")+label)

func wait_for(predicate:Callable,seconds:float=12) -> bool:
 var started:=Time.get_ticks_msec()
 while not predicate.call():
  if Time.get_ticks_msec()-started>seconds*1000:
   check(false,"timeout waiting for affected interaction")
   return false
  await get_tree().process_frame
 return true

func delay(seconds:float) -> void:
 await get_tree().create_timer(seconds,true).timeout

func fixture() -> void:
 app.start_bedside_sample()
 app.dialogue_queue.clear()
 app.dialogue_panel.hide()
 app.scenario_label.text="局部试接入 / 未定稿"

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 app=get_parent()
 await get_tree().process_frame
 var folder:=ProjectSettings.globalize_path(app.evidence_dir)
 DirAccess.make_dir_recursive_absolute(folder)
 var marker:=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 marker.store_string(JSON.stringify({"status":"running_not_yet_verified","passes":[],"failures":[],"started_unix":Time.get_unix_time_from_system()}))
 marker.close()
 if not app.view.has_method("bedside_handle"):
  check(false,"trial view resources must load before any verification")
  var failed:=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
  failed.store_string(JSON.stringify({"status":"failed_preflight","passes":passes,"failures":failures}))
  failed.close()
  get_tree().quit(1)
  return
 await run()

func run() -> void:
 fixture()
 check(app.layout.furniture.size()==11,"all eleven existing search points retained")
 var all_reachable:=true
 for f in app.layout.furniture:
  all_reachable=all_reachable and app.layout.walkable(f.at) and not app.layout.path(app.layout.BED_STOP,f.at).is_empty()
 check(all_reachable,"all eleven anchors have actual existing-grid routes")
 check(app.world_viewport.canvas_item_default_texture_filter==Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,"nearest filtering retained")
 app.paused_manual=true
 await app.snapshot("01_trial_scope")
 await delay(.35)
 app.paused_manual=false
 if not await wait_for(func():return app.rules.search_active):
  print("PAUSE_DIAGNOSTIC: ",app.paused_manual," dialogues=",app.dialogue_queue.size()," menu=",app.menu.visible," closing=",app.closing_left," audio=",app.audio_panel.visible," processing=",app.is_processing())
  get_tree().quit(1)
  return
 check(app.hero_pos.distance_to(app.layout.furniture[1].at)<.04,"autonomous route reaches trial approach")
 check(float(app.drawer_open.get("bedside",0))==0,"no drawer movement before hand contact")
 await app.snapshot("02_arrival")
 await wait_for(func():return app.rules.search_elapsed>.35)
 app.paused_manual=true
 var elapsed:float=app.rules.search_elapsed
 var opening:float=app.drawer_open.bedside
 var footprint:Rect2=app.layout.furniture[1].rect
 check(opening>0 and opening<1,"drawer progressively opens after contact")
 check(app.view.bedside_hand().distance_to(app.view.bedside_handle())<.01,"hand tracks measured moving handle")
 await app.snapshot("03_contact_paused")
 await delay(.35)
 check(app.rules.search_elapsed==elapsed and app.drawer_open.bedside==opening,"pause freezes search and drawer")
 for i in range(4):
  app.zoom_index=i
  app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*app.ZOOM_STEPS[i]
  await delay(.3)
  await app.snapshot("04_zoom_%d"%i)
  check(app.layout.furniture[1].rect==footprint and app.view.bedside_hand().distance_to(app.view.bedside_handle())<.01,"zoom %d preserves collision and contact"%i)
 app.reset_zoom()
 check(app.camera.zoom==Vector2.ONE*app.BASE_ZOOM,"zoom reset uses original default")
 app.paused_manual=false
 var balance:int=app.rules.neurons
 await wait_for(func():return app.rules.search_count==1)
 app.paused_manual=true
 check(app.rules.neurons==balance+1 and app.drawer_open.bedside==1,"search completes once and drawer remains open")
 await app.snapshot("05_open_completed")
 await delay(.4)
 # Inspect legal poses without adding direct movement controls to the game.
 app.hero_state="idle"
 app.hero_pos=Vector2(.97,1.76)
 check(app.layout.walkable(app.hero_pos),"rear occlusion pose is legal")
 await app.snapshot("06_rear_occlusion")
 await delay(.35)
 app.hero_pos=Vector2(.5,2.55)
 check(app.layout.walkable(app.hero_pos),"front occlusion pose is legal")
 await app.snapshot("07_front_occlusion")
 await delay(.35)
 app.view.debug_geometry=true
 await app.snapshot("08_collision_overlay")
 app.view.debug_geometry=false
 # Visual-only movable-object fixture, not a claim that original book/clock
 # search choreography is already implemented. Complete top remains underneath.
 app.view.book_shift=Vector2(12,3)
 app.view.clock_shift=Vector2(8,-2)
 app.note("露底夹具：书/闹钟位移仅供背景检查，尚未接入逐项搜寻演出。")
 await app.snapshot("09_revealed_background")
 await delay(.4)
 app.view.book_shift=Vector2.ZERO
 app.view.clock_shift=Vector2.ZERO
 fixture()
 await wait_for(func():return app.rules.search_active and app.rules.search_elapsed>.35)
 # Use original hit conversion at the trial camera, not a new click handler.
 var mouse:=InputEventMouseButton.new()
 mouse.button_index=MOUSE_BUTTON_LEFT
 mouse.pressed=true
 mouse.position=(app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-35)))*2
 app._unhandled_input(mouse)
 check(app.menu.visible,"original mouse hit handler opens menu on trial actor")
 await app.snapshot("10_menu")
 await delay(.35)
 app.menu._request_cast()
 app.paused_manual=true
 opening=app.drawer_open.bedside
 elapsed=app.rules.search_elapsed
 await delay(.4)
 check(app.rules.search_active and app.rules.reaction_left==0 and app.rules.search_elapsed==elapsed and app.drawer_open.bedside==opening,"pausing during menu close preserves pending intervention and drawer")
 await app.snapshot("11_pause_during_close")
 app.paused_manual=false
 await wait_for(func():return app.rules.reaction_left>0)
 app.sample_done=true
 balance=app.rules.neurons
 await delay(.7)
 check(not app.rules.search_active and app.rules.search_count==0 and app.rules.neurons==balance,"interrupted search cannot backfill reward")
 check(app.drawer_open.bedside==opening,"interrupted moving art stays at actual partial position")
 await app.snapshot("12_interrupted")
 await delay(.5)
 var folder:=ProjectSettings.globalize_path(app.evidence_dir)
 var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"status":"complete","finished_unix":Time.get_unix_time_from_system(),"engine":Engine.get_version_info().string,"rendered":true,"passes":passes,"failures":failures,"scope":"reversible bedside plus bed edge; remaining assets greybox; art not approved","input":"original handler simulation, not manual OS clicking"},"\t"))
 file.close()
 print("ART_TRIAL: %d passed, %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
