extends Node
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/ui"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func wait_frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func hold(seconds:float) -> void:
 var frames:int=ceili(seconds*30.0)
 for i in range(frames):await get_tree().process_frame

func capture(name:String) -> void:
 await wait_frames()
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func ready_world() -> void:
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 app.paused_manual=false;app.menu.close_menu()

func settle_cast(id:String) -> void:
 app.open_neuron_menu()
 app.cast_skill(id,{})
 check(app.menu.visible==false and app.closing_left>0,"cast closes terminal with isolated transition: "+id)
 var before:float=app.rules.world_time
 app.paused_manual=true
 await hold(0.4)
 check(app.rules.world_time==before,"pause during closing freezes pending effect: "+id)
 app.paused_manual=false
 await hold(0.3)

func _ready() -> void:
 name="CampaignCheck"
 frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await wait_frames()
 frontend.show_profile();await wait_frames()
 frontend.name_field.text="B1验证"
 frontend.overwrite_armed=true;frontend.new_game();await wait_frames()
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 app.family.enabled=false # Separate family branch suite owns these fixtures.
 app.home.enabled=false # This suite isolates UI/audio; natural animal tests are separate.
 ready_world()
 await wait_frames()
 check(app.audio.assets.size()==15,"development sound bindings actually load fifteen streams")
 check(app.audio.channels.music[0].playing,"room music reaches actual AudioStreamPlayer")
 app.open_neuron_menu()
 check(app.menu.nodes.size()==12 and not app.rules.skill_states.GUT.unlocked,"formal entry terminal has twelve nodes; initial tree remains locked")
 var clock:float=app.rules.world_time
 await capture("01_crt_initial");await hold(0.8)
 check(app.rules.world_time==clock,"CRT presentation does not advance world")
 var music_position:float=app.audio.channels.music[0].get_playback_position()
 await hold(0.3)
 check(absf(app.audio.channels.music[0].get_playback_position()-music_position)<0.05,"world music playback position freezes during terminal pause")
 var sound_count:int=app.audio.starts.size()
 check(not app.audio.cue("SFX_FOOTSTEP","stale_during_pause") and app.audio.starts.size()==sound_count,"paused world cue rejected without delayed replay queue")
 app.menu.selected_id="CONTROL";app.menu._request_cast()
 check(app.rules.neurons==5 and app.menu._status.text.contains("未解锁"),"locked node distinguishes feedback without charge")
 app.menu.close_menu()
 app.open_system_page("tree")
 app.menu.selected_id="GUT";app.menu.describe_tree();app.menu.tree_action("unlock")
 check(app.rules.skill_states.GUT.unlocked and app.rules.plexus==2,"freezer confirms actual one-cluster unlock")
 await capture("02_freezer_unlock");await hold(0.8)
 app.menu.body_angle=1;app.menu.orbit+=0.35;app.menu.layout_tree()
 await capture("03_body_ring_rotation")
 check(app.rules.world_time==clock,"body and spiral rotation use UI clock only")
 app.close_neuron_menu();ready_world()
 app.rules.plexus=40 # Isolated fixture for advanced-node UI; never official slot.
 for id in app.rules.skill_states:
  if id!="SKIN" and not app.rules.skill_states[id].unlocked:app.rules.unlock(id)
 app.rules.neurons=40
 app.rules.cancel_search();app.target_index=-1;app.hero_route=PackedVector2Array()
 app.session.data.targets=["bedroom:1"]
 for i in range(200):
  if app.rules.search_active:break
  app.advance_world(0.05)
 check(app.rules.search_active,"actual walk reaches cabinet before intervention")
 await capture("04_search_before_temp")
 var progress:float=app.rules.search_elapsed
 await settle_cast("TEMP")
 check(app.rules.search_active and app.rules.effects.get("TEMP",0)>0,"TEMP produces sustained effect while retaining current search")
 await capture("05_temp_search");await hold(0.6)
 app.open_neuron_menu();app.menu.selected_id="TINNITUS";app.menu.describe("TINNITUS")
 await capture("06_crt_unlocked");await hold(0.8)
 app.cast_skill("TINNITUS",{});await hold(0.4)
 check(app.rules.search_active,"tinnitus pauses same unfinished search instead of cancelling it")
 await capture("07_tinnitus");await hold(0.8)
 await settle_cast("GUT")
 check(not app.rules.search_active and app.rules.reaction_left>0,"GUT actually interrupts cabinet search")
 await capture("08_gut_interruption")
 await hold(1.3)
 app.open_system_page("book");app.menu.book_category="角色";app.menu.refresh_book()
 check(app.menu.book_text.text.contains("身体反应") and app.rules.observations.size()>=3,"observed body reactions enter free character bookmark")
 await capture("09_book");await hold(0.8)
 app.close_neuron_menu();ready_world()
 await settle_cast("CONTROL")
 check(app.rules.control_left>0,"actual formal campaign control window starts after closing")
 var effective:int=app.rules.control_ms
 app.paused_manual=true;await hold(0.5)
 check(app.rules.control_ms==effective,"manual pause excludes effective control time")
 app.paused_manual=false
 app.rules.observe("角色","debug-free-record","当前掌控已发生；具体阈值不展示")
 await capture("10_control");await hold(0.8)
 var saved:Dictionary=app.snapshot_data()
 var payment:int=app.rules.neurons
 var saved_ms:int=app.rules.control_ms
 var written:Dictionary=app.store.save_snapshot(saved)
 var loaded:Dictionary=app.store.load_snapshot()
 check(written.ok and loaded.ok and app.restore_snapshot(loaded.data),"schema-two state saves and reloads in actual campaign")
 check(app.rules.neurons==payment and app.rules.control_ms==saved_ms,"load replays neither payment nor effective milliseconds")
 app.rules.end_control()
 check(app.rules.skill_states.CONTROL.until>app.rules.world_time,"manual return starts twenty-second cooldown")
 await capture("11_control_ended");await hold(0.7)
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"formal UI/campaign automation with explicit advanced-tree fixture; no NPC/combat acceptance"},"  "))
 print("B1_UI_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
