extends Node
## Finite rendered integration run. No static scene mockups are used.
var app:Node
var passes:Array[String]=[]
var failures:Array[String]=[]

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 app=get_parent()
 await get_tree().process_frame
 await run()

func check(value:bool,description:String) -> void:
 if value:
  passes.append(description)
  print("PASS: "+description)
 else:
  failures.append(description)
  push_error("CHECK: "+description)

func until(predicate:Callable,timeout:float=12.0) -> bool:
 var start:=Time.get_ticks_msec()
 while not predicate.call():
  if (Time.get_ticks_msec()-start)/1000.0>timeout:
   check(false,"timeout at "+str(app.scene_phase))
   return false
  await get_tree().process_frame
 return true

func pause_for(seconds:float) -> void:
 await get_tree().create_timer(seconds,true).timeout

func clear_dialogue() -> void:
 while not app.dialogue_queue.is_empty():app.advance_dialogue()

func click_at(p:Vector2,button:int=MOUSE_BUTTON_LEFT) -> void:
 var event:=InputEventMouseButton.new()
 event.position=p
 event.global_position=p
 event.button_index=button
 event.pressed=true
 Input.parse_input_event(event)
 await get_tree().process_frame
 event=InputEventMouseButton.new()
 event.position=p
 event.global_position=p
 event.button_index=button
 event.pressed=false
 Input.parse_input_event(event)
 await get_tree().process_frame

func run() -> void:
 clear_dialogue()
 await until(func():return app.rules.search_active and app.rules.search_elapsed>0.2)
 await app.snapshot("01_autonomous_search")
 # Actual mouse coordinates pass through the world projection/camera transform.
 var point:Vector2=app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-28))
 await click_at(point*2)
 check(app.menu.visible,"click protagonist opens neuron menu")
 var t:float=app.rules.world_time
 var p:Vector2=app.hero_pos
 var elapsed:float=app.rules.search_elapsed
 await pause_for(0.35)
 check(is_equal_approx(t,app.rules.world_time) and p==app.hero_pos and is_equal_approx(elapsed,app.rules.search_elapsed),"menu freezes world position search and cooldown clock")
 app.menu._show_description()
 await app.snapshot("02_neuron_menu")
 var coins:int=app.rules.neurons
 app.menu._request_cast()
 check(app.rules.neurons==coins-1,"one valid skin submission spends exactly one neuron")
 check(app.rules.search_active,"skin submission does not apply while screen closes")
 app.paused_manual=true
 await pause_for(0.25)
 check(app.rules.reaction_left==0 and app.rules.search_active,"manual pause during closing defers pending body reaction")
 app.paused_manual=false
 await until(func():return app.rules.reaction_left>0)
 check(not app.rules.search_active and app.rules.search_count==0,"skin actual reaction cancels unfinished search without reward")
 await app.snapshot("03_skin_interruption")
 await until(func():return app.rules.reaction_left<=0)
 check(not app.menu.visible,"close does not reopen menu or leak a click")
 await until(func():return app.rules.search_active)
 check(app.rules.search_attempts==2,"resumed autonomous search spends a new attempt")
 # Freeze with manual pause while viewing the rendered zoom extremes.
 app.paused_manual=true
 app.zoom_index=0
 app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*0.8
 await pause_for(0.05)
 await app.snapshot("04_zoom_080")
 app.zoom_index=3
 app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*1.3
 await pause_for(0.05)
 await app.snapshot("05_zoom_130")
 app.reset_zoom()
 app.paused_manual=false
 # Resistance: equal strength cannot cancel or reset search progress.
 app.rules.cooldown_until=app.rules.world_time
 app.rules.skin_resistance=1
 app.open_neuron_menu()
 var before:float=app.rules.search_elapsed
 app.menu._request_cast()
 await until(func():return app.closing_left==0 and not app.menu.visible)
 check(app.rules.search_active and app.rules.search_elapsed>=before,"resisted skin keeps search progress")
 app.rules.skin_resistance=0
 # Mother normal transfer; advance original dialogue, preserving world pause.
 app.reset_sample(1)
 clear_dialogue()
 await until(func():return app.scene_phase=="mother_give")
 clear_dialogue()
 await until(func():return app.sample_done)
 check(app.rules.owners.porridge=="hero","mother transfer commits at actual contact endpoint")
 check(app.rules.sp==80 and app.rules.neurons==5,"receiving porridge does not eat it or award food resources")
 var repeat:bool=app.rules.commit_transfer("mother:%d"%app.event_generation,"porridge","mother","hero",0.6,true,true,true)
 check(not repeat,"replayed transfer completion cannot duplicate ownership")
 await app.snapshot("06_mother_transfer")
 # Mother interrupted before delivery.
 app.reset_sample(1)
 clear_dialogue()
 await until(func():return app.scene_phase=="mother_give")
 clear_dialogue()
 await pause_for(0.12)
 app.open_neuron_menu()
 app.menu._request_cast()
 await until(func():return app.sample_done)
 check(app.rules.owners.porridge=="mother","interrupted receiving leaves item with mother")
 # Father receives its own NPC and original timing, using half-speed game clock.
 app.reset_sample(2)
 clear_dialogue()
 await until(func():return app.grabbed,20.0)
 check(app.actual_contact(0.7),"father grip starts only at actual close facing unobstructed contact")
 var gap:Vector2=app.hero_pos-app.npc_pos
 await until(func():return app.scene_phase=="father_drag",10.0)
 await pause_for(0.5)
 check((app.hero_pos-app.npc_pos).is_equal_approx(gap),"paired drag preserves physical offset without snapping")
 await app.snapshot("07_father_drag")
 var father_before:Vector2=app.npc_pos
 var sp_before:int=app.rules.sp
 app.open_neuron_menu()
 await pause_for(0.3)
 check(app.npc_pos==father_before and app.rules.sp==sp_before,"menu freezes father motion and pressure")
 app.close_neuron_menu()
 await until(func():return not app.world_paused())
 app.cast_startle()
 await until(func():return app.scene_phase=="father_released",5.0)
 check(not app.grabbed and app.rules.neurons==3 and app.startle_rewarded,"startle pays two neurons and rewards only actual separation")
 await app.snapshot("08_father_release")
 # Cat only attacks after visible successful interference of its occupied point.
 app.reset_sample(3)
 clear_dialogue()
 await until(func():return app.rules.search_active and app.rules.search_elapsed>0.3)
 app.open_neuron_menu()
 app.menu._request_cast()
 await until(func():return app.cat_pending)
 clear_dialogue()
 await until(func():return app.cat_hit_done)
 clear_dialogue()
 await until(func():return app.sample_done)
 clear_dialogue()
 check(app.rules.hp==90 and app.rules.sp==90,"cat actual hit applies HP/SP minus ten exactly once")
 check(not app.rules.commit_hit("cat:%d"%app.event_generation,0.4,true,true,true),"cat replay cannot repeat damage")
 await app.snapshot("09_cat_hit")
 # Navigation debug image is the actual footprint/path overlay.
 app.reset_sample(0)
 clear_dialogue()
 app.view.debug_geometry=true
 await pause_for(0.3)
 await app.snapshot("10_collision_overlay")
 var output:=ProjectSettings.globalize_path("res://../docs/validation/rendered_integration.json")
 var f:=FileAccess.open(output,FileAccess.WRITE)
 f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"rendered":true,"passes":passes,"failures":failures,"scope":"isolated bedroom mechanics, not complete game"},"\t"))
 f.close()
 print("RENDERED_INTEGRATION: %d passed, %d failed"%[passes.size(),failures.size()])
 await pause_for(0.1)
 get_tree().quit(0 if failures.is_empty() else 1)

