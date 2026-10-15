extends Node
var frontend:Node
var app:Node
var passes:Array[String]=[]
var failures:Array[String]=[]
var folder:String

func logic_fingerprint() -> String:
 var data:Dictionary=app.snapshot_data()
 # Audio backend sample position is not a gameplay clock. The audio thread
 # can finish its current mix block while a paused UI replaces a texture.
 # Keep streams/channels/receipts and every original gameplay field checked.
 for stream in data.get("audio_state",{}).get("playing",[]):stream.erase("position")
 return JSON.stringify(data,"",true)

func check(value:bool,description:String) -> void:
 (passes if value else failures).append(description)
 print(("PASS " if value else "FAIL ")+description)

func wait_frames(count:int=2) -> void:
 for i in range(count):await get_tree().process_frame

func capture(name:String) -> void:
 await wait_frames(2)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(folder.path_join(name+".png"))

func clear_dialogue() -> void:
 app.dialogue_queue.clear()
 app.show_dialogue()

func fast_until(predicate:Callable,limit:int=5000) -> bool:
 for i in range(limit):
  if predicate.call():return true
  if not app.dialogue_queue.is_empty():
   app.advance_dialogue() # Continue actual newly connected first-damage feedback.
   continue
  app.advance_world(0.05)
 return predicate.call()

func _ready() -> void:
 name="CampaignCheck"
 frontend=get_parent()
 folder=ProjectSettings.globalize_path("res://../docs/validation/campaign_20261015")
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=ProjectSettings.globalize_path(argument.trim_prefix("--validation-root="))
 DirAccess.make_dir_recursive_absolute(folder)
 await wait_frames(3)
 await capture("01_title")
 frontend.show_settings()
 frontend.volume_slider.value=0.37
 frontend.reduced_box.button_pressed=true
 frontend.apply_settings()
 check(is_equal_approx(float(frontend.preferences.master),0.37),"title settings controls persist real master volume preference")
 frontend.create_title()
 frontend.show_profile()
 await wait_frames(3)
 check(frontend.name_field.text=="张%d"%frontend.pending_invader_id,"default player name uses the same fixed ID as the created profile")
 frontend.name_field.text="测试建档"
 frontend.overwrite_armed=true
 frontend.new_game()
 await wait_frames(3)
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 app.family.enabled=false # Separate family branch suite owns these fixtures.
 app.home.enabled=false # Isolated exploration/save/replacement regression; NPCs have their own suite.
 check(app!=null and app.profile.name=="测试建档","profile name and stable invader ID created through real UI handlers")
 check(app.rules.neurons==5 and app.rules.plexus==3,"new profile receives initial resources once")
 check(is_equal_approx(float(app.audio.levels.master),0.37),"saved master volume setting reaches actual audio channel mixer")
 clear_dialogue()
 app.paused_manual=true
 check(app.session.data.targets.size()==10 and app.session.data.targets.has(app.session.data.key_target),"ten sampled targets contain one fixed key")
 check(fast_until(func():return app.rules.search_active),"autonomous protagonist actually walks to and starts a search")
 app.advance_world(0.3)
 await capture("02_search")
 var clock:float=app.rules.world_time
 var position:Vector2=app.hero_pos
 var paid:int=app.rules.neurons
 app.paused_manual=false
 app.open_neuron_menu()
 app.menu._request_cast()
 app.paused_manual=true
 await get_tree().create_timer(0.3).timeout
 check(app.rules.world_time==clock and app.hero_pos==position,"menu and manual pause freeze world while UI closing advances")
 check(app.rules.neurons==paid-1 and not app.rules.pending_skin.is_empty(),"one skill submission paid once and remains pending during pause")
 var snapshot:Dictionary=app.snapshot_data()
 var target=app.session.data.key_target
 var sample=app.session.data.targets.duplicate()
 var rng_state:String=str(app.rng.state)
 var gen:int=app.runtime_generation
 var save:Dictionary=app.store.save_snapshot(snapshot)
 check(save.ok,"actual JSON save written and checksum verified")
 var read:Dictionary=app.store.load_snapshot()
 check(read.ok and app.restore_snapshot(read.data),"actual JSON load restores a playable scene")
 check(app.session.data.key_target==target and app.session.data.targets==sample and str(app.rng.state)==rng_state,"save/load does not reroll target set key or RNG continuation")
 check(app.runtime_generation>gen and app.rules.neurons==paid-1,"loading changes runtime generation without charging skill again")
 app.paused_manual=false
 await get_tree().create_timer(0.12).timeout
 app.paused_manual=true
 check(app.rules.reaction_left>0 and not app.rules.search_active,"loaded pending reaction actually interrupts unfinished search after unpause")
 var logic:String=logic_fingerprint()
 var first_frame:Dictionary=app.view.catalog.actor_frame("search",Vector2.RIGHT,0)
 var final_frame:Dictionary=app.view.catalog.actor_frame("search",Vector2.RIGHT,100)
 check(first_frame.source.position.x==0 and final_frame.source.position.x==192,"non-looping action starts at preparation and holds its final pose instead of replaying")
 check(app.view.catalog.select_set("b"),"replacement B loads actor atlas and moving furniture layers by stable ID")
 check(logic_fingerprint()==logic,"visual replacement does not change rules ownership positions action clocks or story facts")
 await capture("03_replacement_b")
 app.view.catalog.select_set("a")
 var old_path:String=app.view.catalog.presets.b.CHR_MAIN.texture
 app.view.catalog.presets.b.CHR_MAIN.texture="res://assets/missing.png"
 check(not app.view.catalog.select_set("b") and app.view.catalog.active_set=="a","missing replacement is rejected and old valid presentation preserved")
 app.view.catalog.presets.b.CHR_MAIN.texture=old_path
 # A separate furniture trial preserves the campaign snapshot, then restores it.
 var before_furniture:Dictionary=app.snapshot_data()
 app.rules.reaction_left=0
 app.rules.cancel_search()
 app.session.data.targets=["bedroom:1"]
 app.completed.clear()
 app.target_index=-1
 app.hero_route=PackedVector2Array()
 app.action_phase="autonomy"
 check(fast_until(func():return app.rules.search_active and app.target_index==1),"replacement furniture test actually walks to bedside contact")
 check(fast_until(func():return float(app.drawer_open.get("bedside",0))>0.5),"drawer actually opens after contact using unchanged action clock")
 await capture("06_drawer_a")
 var furniture_logic:String=logic_fingerprint()
 var handle:Vector2=app.view.bedside_handle()
 check(app.view.catalog.select_set("b") and app.view.bedside_handle().is_equal_approx(handle),"active furniture replacement preserves measured hand contact point")
 check(logic_fingerprint()==furniture_logic,"mid-action actor and drawer replacement leaves action ownership and completion state unchanged")
 await capture("07_drawer_b")
 app.restore_snapshot(before_furniture)
 # A real rest is reached by autonomy after SP fixture; no gameplay skip UI.
 app.rules.cancel_search()
 app.rules.reaction_left=0
 app.rules.sp=40
 var cooldown:float=app.rules.cooldown_until
 var old_attempt:int=app.rules.actual_attempt
 check(fast_until(func():return app.rules.actual_attempt>old_attempt),"low-SP autonomy walks to bed and finishes a real rest")
 check(app.rules.hp==100 and app.rules.sp==100 and app.rules.neurons>=5,"rest restores body and only tops neurons up to five")
 check(app.rules.cooldown_until==cooldown,"rest does not clear skill cooldown")
 check(app.layout.walkable(app.door_point("lobby")) and not app.layout.path(app.hero_pos,app.door_point("lobby")).is_empty(),"bedroom door uses original unblocked doorway instead of bed footprint")
 # Run the actual AI with the genuine sampled key; no direct event completion.
 check(fast_until(func():return app.session.data.level==2),"autonomous search finds picks up key walks to door and unlocks hospital")
 check(app.room_id=="lobby" and app.session.data.targets.size()==12,"hospital entrance is lobby and samples twelve of thirty-two targets")
 check(app.rules.plexus==5,"first hospital unlock awards exactly two clusters")
 await capture("04_hospital_lobby")
 var hospital:Dictionary=app.snapshot_data()
 var hospital_fingerprint:String=JSON.stringify(hospital,"",true)
 var names:Array=[]
 var count:int=0
 for room in ["ward","lobby","clinic","pharmacy","office"]:
  app.enter_room(room)
  names.append(room)
  for f in app.layout.furniture:
   if room=="ward":continue
   count+=1
   check(app.layout.walkable(f.at) and not app.layout.path(app.hero_pos,f.at).is_empty(),"hospital reachable %s / %s"%[room,f.name])
 check(count==32,"hospital room point counts are exactly 0 + 6 + 8 + 7 + 11")
 app.restore_snapshot(hospital)
 app.paused_manual=true
 check(fast_until(func():return app.session.data.exploration_boundary,9000),"hospital AI travels actual spoke doors searches and reaches keyed stair boundary")
 check(app.has_key() and app.rules.plexus==5,"hospital exploration never duplicates unlock reward")
 await capture("05_hospital_exit_boundary")
 check(JSON.stringify(hospital,"",true)==hospital_fingerprint,"saved snapshot arrays and receipts never mutate while the live world advances")
 # Paused in-flight search snapshots retain completion receipts across repeated loads.
 app.restore_snapshot(hospital)
 app.paused_manual=true
 check(fast_until(func():return app.rules.search_active),"hospital can resume search from saved lobby")
 var running:Dictionary=app.snapshot_data()
 var before:int=app.rules.neurons
 app.advance_world(app.rules.search_duration+0.1)
 var after:Dictionary=app.snapshot_data()
 check(app.rules.neurons==before+1,"one actual search completion awards one neuron")
 app.restore_snapshot(after)
 app.advance_world(0.01)
 check(app.rules.neurons==before+1,"loaded completed receipt cannot issue the previous reward again")
 app.restore_snapshot(running)
 check(app.rules.search_active and app.rules.search_attempts==running.rules.search_attempts,"in-flight load retains consumed search opportunity")
 var backup_first:Dictionary=app.snapshot_data()
 app.store.save_snapshot(backup_first)
 app.store.save_snapshot(app.snapshot_data())
 var file:=FileAccess.open(ProjectSettings.globalize_path(app.store.root).path_join("profile.json"),FileAccess.WRITE)
 file.store_string("intentional test corruption")
 file.close()
 var backup:Dictionary=app.store.load_snapshot()
 check(backup.ok and backup.get("recovered_backup",false),"corrupt primary restores previous verified backup")
 var output:=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"rendered":true,"passes":passes,"failures":failures,"scope":"profile save/load presentation replacement and L1/L2 exploration; NPC/remaining levels not complete"},"\t"))
 output.close()
 print("CAMPAIGN_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
