extends "res://tests/hospital_check.gd"
## Actual process/audio cursors with temporary in-memory silent streams.
## Silence validates clock/voice lifetime only, not voice or music quality.
const Dialogue=preload("res://scripts/ui/dialogue_playback.gd")

func check(value:bool,label:String) -> void:
 # This suite starts in the bedroom, with hospital actors intentionally absent.
 # Keep failures local instead of invoking hospital-specific diagnostics.
 if value:
  passes.append(label);print("PASS "+label);return
 failures.append(label);print("FAIL "+label)
 if app==null:return
 var players:Dictionary={}
 for channel in app.audio.channels:
  players[channel]=[]
  for player in app.audio.channels[channel]:
   players[channel].append({"playing":player.playing,"has_playback":player.has_stream_playback(),"paused":player.stream_paused,"position":player.get_playback_position(),"cue":str(player.get_meta("cue_id",""))})
 var diagnostic:Dictionary={"failed":label,"world_time":app.rules.world_time,"dialogue":app.dialogue_queue.duplicate(true),"automatic":app.auto_dialogue_enabled,"manual_pause":app.paused_manual,"closing_left":app.closing_left,"world_frozen":app.audio.world_frozen,"voice_frozen":app.audio.voice_frozen,"background_frozen":app.audio.background_frozen,"players":players,"playback":app.audio.snapshot_playback(),"starts":app.audio.starts}
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_%02d.json"%failures.size()),FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(diagnostic,"  "));file.close()

func wait_seconds(seconds:float) -> void:
 var elapsed:float=0.0
 while elapsed<seconds:
  await get_tree().process_frame
  elapsed+=get_process_delta_time()

func wait_condition(predicate:Callable,seconds:float) -> bool:
 var elapsed:float=0.0
 while elapsed<seconds and not predicate.call():
  await get_tree().process_frame
  elapsed+=get_process_delta_time()
 return predicate.call()

func silent_stream(seconds:float) -> AudioStreamWAV:
 var result:=AudioStreamWAV.new();result.format=AudioStreamWAV.FORMAT_16_BITS;result.mix_rate=22050
 var samples:=PackedByteArray();samples.resize(int(seconds*22050)*2);samples.fill(0);result.data=samples
 return result

func position(channel:String) -> float:
 var slot:int=maxi(0,app.audio.music_slot) if channel=="music" else 0
 return app.audio.channels[channel][slot].get_playback_position()

func _ready() -> void:
 folder="res://../docs/validation/dialogue_20261016"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="对白时钟验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.opening_ui!=null:app.opening_ui.skip()
 clear_lines();app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false;app.asylum.enabled=false;app.cortex.enabled=false
 app.session.data.exploration_boundary=true;app.hero_route=PackedVector2Array();app.target_index=-1
 app.paused_manual=false;app.menu.close_menu();app.audio_panel.hide();app.closing_left=0
 app.set_auto_dialogue(true);app.audio.reset_scene();app.sync_audio_pause()
 check(app.auto_dialogue_enabled and app.auto_dialogue_box.button_pressed,"normal dialogue defaults to automatic and settings reflect the mode")
 app.menu.open_page("tree");app.menu.selected_id="GUT";app.menu.describe_tree();await frames(12)
 check(app.menu.nodes.SKIN.text=="皮肤刺激" and app.menu.tree_nodes.GUT.text=="肠胃蠕动" and app.menu.nodes.size()==12 and app.menu.CRT_LANGUAGES.size()==13,"Chinese primary node labels preserve twelve stable skill IDs and thirteen CRT code styles")
 check(app.menu.inspect.text.contains("皮肤刺激") and app.menu.inspect.text.contains("神经簇") and not app.menu.inspect.text.contains("SKIN"),"freezer inspection explains prerequisites and unlock currency in Chinese")
 check(app.menu._coin.text.contains("神经元") and app.menu._coin.text.contains("神经簇"),"runtime resource balances use Chinese names")
 await capture("chinese_freezer_names_and_costs")
 app.menu.close_menu();app.sync_audio_pause()
 var raw:String="“测试”，继续……？！ (●'◡'●) 䵴䵰䶷"
 var formatted:String=Dialogue.display_text(raw)
 check(formatted=="\"测试\",继续...?! (●'◡'●) 䵴䵰䶷" and Dialogue.display_text(formatted)==formatted,"display formatting normalizes punctuation and ellipsis without corrupting emoticons or authored unusual glyphs")
 check(Dialogue.reading_seconds("这是比较长的一段对白，需要留出实际可读时间。")>Dialogue.reading_seconds("嗯。"),"silent reading duration depends on text length, not render frame count")
 # Match the actual bedroom music context. The production selector remains
 # enabled; it must not fight an unrelated test-only music ID each frame.
 app.audio.register_asset("MUS_ROOM",silent_stream(12),"music",false)
 app.audio.register_asset("AMB_FAN",silent_stream(12),"ambience",false)
 app.audio.register_asset("TEST_DIALOGUE_ACTION",silent_stream(12),"world")
 app.audio.stop_channel("music");app.audio.set_music("MUS_ROOM",0.0)
 app.audio.stop_channel("ambience");app.audio.set_ambience("AMB_FAN",0.0);app.audio.cue("TEST_DIALOGUE_ACTION","test_action")
 var world_time:float=app.rules.world_time
 app.add_dialogue("角色",raw)
 # AudioServer pauses with a short fade on its next mix, independent of
 # render frames. Sample the held raw cursor after that transition, then
 # require exact stability; the world clock must freeze immediately.
 await wait_seconds(0.1)
 var music_time:float=position("music");var ambience_time:float=position("ambience");var action_time:float=position("world")
 check(app.dialogue_queue[0].text==raw and app.dialogue_text.text.contains(formatted),"source dialogue stays unchanged while the rendered line uses half-width punctuation")
 await wait_seconds(0.65)
 check(app.rules.world_time==world_time and position("world")>action_time+0.3,"dialogue freezes gameplay but lets already playing scene sound continue")
 check(not app.audio.cue("hit","new_world_trigger_during_dialogue"),"dialogue cannot start a new gameplay sound while its action clock is frozen")
 check(position("music")>music_time+0.3 and position("ambience")>ambience_time+0.3,"already playing music and ambience continue across dialogue")
 app.paused_manual=true;app.sync_audio_pause();await wait_seconds(0.1)
 music_time=position("music");ambience_time=position("ambience");var reading_time:float=app.dialogue_queue[0]._display_elapsed
 await wait_seconds(0.35)
 check(is_equal_approx(position("music"),music_time) and is_equal_approx(position("ambience"),ambience_time) and app.dialogue_queue[0]._display_elapsed==reading_time,"manual pause freezes background audio and dialogue reading time together")
 app.paused_manual=false
 check(await wait_condition(func():return app.dialogue_queue.is_empty(),8),"automatic dialogue advances after readable real time without a Continue click")

 app.set_auto_dialogue(false);app.add_dialogue("角色","手动继续。")
 var saved_preferences:=ConfigFile.new()
 check(not frontend.preferences.auto_dialogue and saved_preferences.load(frontend.store.root.path_join("preferences.cfg"))==OK and not bool(saved_preferences.get_value("interface","auto_dialogue",true)),"in-game manual dialogue setting persists through the shared front-end preferences file")
 await wait_seconds(Dialogue.reading_seconds("手动继续。")+0.25)
 check(app.dialogue_queue.size()==1,"manual dialogue mode does not advance after its reading duration")
 app.request_dialogue_advance()
 check(app.dialogue_queue.is_empty(),"manual Continue action advances the actual dialogue queue")
 app.set_auto_dialogue(true)
 app.audio.register_asset("TEST_DIALOGUE_VOICE",silent_stream(4.5),"voice")
 app.dialogue_queue.append({"speaker":"测试角色","text":"嗯。","voice_id":"TEST_DIALOGUE_VOICE"});app.show_dialogue()
 check(await wait_condition(func():return app.audio.voice_playing("TEST_DIALOGUE_VOICE"),1),"an available registered voice starts on the voice channel")
 await wait_seconds(0.6)
 app.request_dialogue_advance()
 check(app.dialogue_queue.size()==1 and app.audio.voice_playing("TEST_DIALOGUE_VOICE"),"manual Continue cannot truncate an unfinished available voice")
 app.paused_manual=true;app.sync_audio_pause();await wait_seconds(0.1)
 var voice_position:float=position("voice");reading_time=app.dialogue_queue[0]._display_elapsed
 var reading_usec:int=int(app.dialogue_queue[0]._display_elapsed_usec)
 check(app.audio.snapshot_playback().playing.any(func(entry):return entry.id=="TEST_DIALOGUE_VOICE"),"paused unfinished voice remains in the real audio snapshot")
 check(roundtrip() and int(app.dialogue_queue[0]._display_elapsed_usec)==reading_usec and app.dialogue_queue[0]._display_elapsed==reading_time and app.dialogue_queue[0].text=="嗯。","JSON preserves dialogue reading time and original line data")
 await wait_seconds(0.25)
 check(absf(position("voice")-voice_position)<0.04,"paused JSON voice restores its playback cursor without replaying the line")
 app.paused_manual=false
 await wait_seconds(1.9)
 check(app.dialogue_queue.size()==1 and app.audio.voice_playing("TEST_DIALOGUE_VOICE"),"automatic mode waits for voice even after short subtitle reading time has elapsed")
 await capture("dialogue_auto_waits_for_voice")
 check(await wait_condition(func():return app.dialogue_queue.is_empty(),4),"automatic mode advances after actual voice playback finishes")
 app.audio_panel.show();app.sync_audio_pause();await frames(2)
 check(app.audio.world_frozen and app.audio.voice_frozen and app.audio.background_frozen,"settings pause all non-interface channels according to manual pause policy")
 await capture("dialogue_settings_auto_toggle")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Actual process seconds, world/audio cursors, manual/automatic queue, JSON and display punctuation. Temporary in-memory silent streams; no final speech or subjective listening claim."},"  "));file.close()
 print("DIALOGUE_PLAYBACK_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
