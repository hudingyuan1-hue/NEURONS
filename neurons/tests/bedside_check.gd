extends Node
## Isolated runtime fixture; no permanent player movement controls.
var app:Node
var passes:Array[String]=[]
var failures:Array[String]=[]

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 app=get_parent()
 await get_tree().process_frame
 await run()

func check(ok:bool, label:String) -> void:
 (passes if ok else failures).append(label)
 print(("PASS: " if ok else "FAIL: ")+label)

func wait_for(predicate:Callable, seconds:float=15.0) -> bool:
 var start:=Time.get_ticks_msec()
 while not predicate.call():
  if Time.get_ticks_msec()-start>seconds*1000:
   check(false,"timeout")
   return false
  await get_tree().process_frame
 return true

func delay(seconds:float) -> void:
 await get_tree().create_timer(seconds,true).timeout

func fixture() -> void:
 app.start_bedside_sample()
 app.dialogue_queue.clear()
 app.dialogue_panel.hide()

func run() -> void:
 fixture()
 var original_rect:Rect2=app.layout.furniture[1].rect
 check(app.view.BEDSIDE_WOOD.get_size()==Vector2(64,64),"wood imported at 64 square logical pixels")
 check(app.world_viewport.canvas_item_default_texture_filter==Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,"world nearest sampling retained")
 await wait_for(func():return app.rules.search_active)
 check(app.hero_pos.distance_to(app.layout.furniture[1].at)<0.04,"autonomous route reaches existing bedside approach")
 check(float(app.drawer_open.get("bedside",0))==0,"drawer remains closed before hand contact")
 await wait_for(func():return app.rules.search_elapsed>0.35)
 app.paused_manual=true
 var elapsed:float=app.rules.search_elapsed
 var opening:float=app.drawer_open.bedside
 check(app.view.bedside_hand().distance_to(app.view.bedside_handle())<0.01,"search hand follows actual drawer handle")
 check(opening>0 and opening<1,"drawer opens progressively after contact")
 await app.snapshot("11_bedside_contact")
 await delay(0.25)
 check(app.rules.search_elapsed==elapsed and app.drawer_open.bedside==opening,"pause freezes drawer and search clock")
 check(app.audio.world_frozen,"pause gates world audio events")
 for i in range(4):
  app.zoom_index=i
  app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*app.ZOOM_STEPS[i]
  await delay(0.05)
  await app.snapshot("12_bedside_zoom_%d"%i)
  check(app.layout.furniture[1].rect==original_rect and app.hero_pos.distance_to(app.layout.furniture[1].at)<0.04,"zoom %d preserves footprint and action position"%i)
 app.reset_zoom()
 check(app.zoom_index==1 and app.camera.zoom==Vector2.ONE*app.BASE_ZOOM,"zoom reset restores baseline")
 app.paused_manual=false
 var coins:int=app.rules.neurons
 await wait_for(func():return app.rules.search_count==1)
 app.paused_manual=true
 check(app.rules.neurons==coins+1,"completion awards exactly one neuron")
 check(app.drawer_open.bedside==1,"completed drawer remains physically open")
 var cues:int=0
 for event in app.audio.starts:
  if event.id=="SFX_DRAWER":cues+=1
 check(cues==1,"drawer movement emits one contact cue")
 await app.snapshot("13_bedside_complete")
 app.view.debug_geometry=true
 await app.snapshot("14_bedside_collision")
 app.view.debug_geometry=false
 # Occlusion fixtures change only test poses at legal floor points.
 app.hero_state="idle"
 app.hero_pos=Vector2(0.97,1.78)
 check(app.layout.walkable(app.hero_pos),"rear occlusion fixture is walkable")
 await app.snapshot("15_bedside_behind")
 app.hero_pos=Vector2(0.5,2.55)
 check(app.layout.walkable(app.hero_pos),"front occlusion fixture is walkable")
 await app.snapshot("16_bedside_front")
 fixture()
 await wait_for(func():return app.rules.search_active and app.rules.search_elapsed>0.3)
 app.open_neuron_menu()
 app.menu._request_cast()
 app.paused_manual=true
 opening=app.drawer_open.bedside
 await delay(0.3)
 check(app.rules.search_active and app.rules.reaction_left==0 and app.drawer_open.bedside==opening,"closing plus manual pause keeps drawer and pending skill frozen")
 app.paused_manual=false
 await wait_for(func():return app.rules.reaction_left>0)
 app.sample_done=true
 coins=app.rules.neurons
 await delay(0.65)
 check(not app.rules.search_active and app.rules.search_count==0 and app.rules.neurons==coins,"interrupted search cannot backfill completion reward")
 check(app.drawer_open.bedside==opening,"interrupted drawer cannot continue opening")
 await app.snapshot("17_bedside_interrupted")
 # Test-only loop is synthesized in memory; never saved as supplied audio.
 app.audio.reset_scene()
 app.audio.set_world_paused(false)
 var loop:AudioStreamWAV=app.audio.make_test_tone(110)
 var chunk:PackedByteArray=loop.data
 var long_data:=PackedByteArray()
 for i in range(10):long_data.append_array(chunk)
 loop.data=long_data
 check(app.audio.register_asset("TEST_LOOP",loop,"ambience",true),"audio registers a separate loop copy")
 check(loop.loop_mode==AudioStreamWAV.LOOP_DISABLED,"audio registration preserves source stream")
 check(app.audio.cue("TEST_LOOP","loop1"),"loop starts")
 check(not app.audio.cue("TEST_LOOP","loop2"),"same active loop cannot stack")
 check(app.audio.cue("hit","once"),"world event starts")
 check(not app.audio.cue("hit","once"),"duplicate event rejected")
 await delay(0.12)
 app.paused_manual=true
 await delay(0.05)
 check(app.audio.channels.ambience[0].stream_paused,"ambient loop pauses")
 await delay(0.05)
 var paused_position:float=app.audio.channels.ambience[0].get_playback_position()
 await delay(0.15)
 check(absf(app.audio.channels.ambience[0].get_playback_position()-paused_position)<0.03,"paused loop playback position stays fixed")
 check(not app.audio.cue("drawer","paused"),"paused world event is rejected without a replay queue")
 check(app.audio.cue("open","ui_pause"),"UI cue remains available during world pause")
 app.audio.set_level("master",0)
 check(app.audio.channels.ui[0].volume_linear==0,"master slider mutes all channels")
 app.audio.set_level("master",0.8)
 app.paused_manual=false
 await delay(0.05)
 check(not app.audio.channels.ambience[0].stream_paused,"loop resumes without restart")
 await delay(0.12)
 check(app.audio.channels.ambience[0].get_playback_position()>paused_position+0.04,"resumed loop continues from held playback position")
 app.audio.reset_scene()
 check(not app.audio.channels.ambience[0].playing and app.audio.played_events.is_empty(),"scene reset clears playback and event identities")
 check(app.audio.register_asset("TEST_VOICE",loop,"voice"),"voice channel accepts a supplied stream")
 app.add_dialogue("测试夹具","仅验证对白暂停关系，不是新增剧情")
 await delay(0.05)
 check(app.world_paused() and app.audio.cue("TEST_VOICE","dialogue"),"dialogue freezes world but permits its voice")
 app.paused_manual=true
 await delay(0.05)
 check(app.audio.channels.voice[0].stream_paused,"manual pause also freezes dialogue voice")
 app.paused_manual=false
 app.dialogue_queue.clear()
 app.dialogue_panel.hide()
 app.audio.reset_scene()
 app.toggle_audio_controls()
 check(app.world_paused(),"audio controls pause the world")
 await app.snapshot("18_audio_controls")
 app.toggle_audio_controls()
 check(not app.world_paused(),"audio controls restore world pause state")
 var file:=FileAccess.open("res://../docs/validation/local_20261015/bedside_integration.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"rendered":true,"passes":passes,"failures":failures,"scope":"bedside art candidate and provisional audio interface, not final characters or full game"},"\t"))
 file.close()
 print("BEDSIDE_INTEGRATION: %d passed, %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
