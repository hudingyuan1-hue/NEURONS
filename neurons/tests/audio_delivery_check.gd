extends Node
## Selected chapter/ending fixtures; real imported streams and audio cursors.
## Not a listening/mix, new gameplay mode, or full-game acceptance test.
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/audio2_20261017/runtime"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func wait_real(seconds:float) -> void:
 var until:int=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<until:await get_tree().process_frame

func clear_lines() -> void:
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 app.menu.close_menu();app.audio_panel.hide();app.paused_manual=false
 app.sync_audio_pause()

func music_id() -> String:
 return str(music_player().get_meta("cue_id",""))

func music_player():return app.audio.channels.music[maxi(0,app.audio.music_slot)]

func cursor() -> float:return music_player().get_playback_position()

func pump() -> void:
 clear_lines();app._process(0.0)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="音频交付验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 if app.opening_ui!=null:app.opening_ui.skip()
 app.set_process(false) # Declared stationary chapter fixtures; audio mixer stays real-time.
 app.home.enabled=false;app.family.enabled=false;clear_lines();app.audio.reset_scene()
 var bindings=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_bindings.json"))
 var entries:Dictionary={}
 for entry in bindings.assets:entries[entry.id]=entry
 check(app.audio.assets.size()==bindings.assets.size(),"every configured stream imports and registers, no silent fallback")
 for id in ["MUS_HOSPITAL","MUS_END","MUS_DANGER"]:
  var stream:AudioStream=app.audio.assets[id].stream
  check(stream is AudioStreamOggVorbis and stream.get_length()>1 and not app.audio.assets[id].loop,"actual imported nonlooping music: "+id)
 check(absf(app.audio.assets.MUS_HOSPITAL.stream.get_length()-271.4721667)<.05,"hospital recording retains full source duration")
 check(absf(app.audio.assets.MUS_END.stream.get_length()-85.9941875)<.05 and entries.MUS_END.source.ends_with("MUS_ENDING_E2_v001.wav"),"stable MUS_END now resolves delivered E2 recording")
 check(entries.MUS_DANGER.source_sha256=="14b8eb0cdbdbc014a54216e208f0c13ffde15c515e167510bd77640ca428387f","danger delivery equals previous original and reuses processed stream")
 pump();check(music_id()=="MUS_ROOM","bedroom retains existing room music")
 app.unlock_hospital();pump();check(music_id()=="MUS_HOSPITAL","actual hospital unlock replaces bedroom music")
 await wait_real(.18)
 var starts:int=app.audio.starts.size();var before:float=cursor()
 app.enter_room("clinic");pump();await wait_real(.18)
 check(music_id()=="MUS_HOSPITAL" and app.audio.starts.size()==starts and cursor()>before,"same chapter doorway does not restart or duplicate hospital music")
 app.add_dialogue("角色","音频时钟验证。未新增剧情。")
 app.sync_audio_pause();before=cursor();await wait_real(.25)
 check(app.audio.world_frozen and not app.audio.background_frozen and cursor()>before+.1,"ordinary dialogue holds world but hospital music continues")
 clear_lines();app.menu.open_page("inventory");app.sync_audio_pause();await wait_real(.12)
 before=cursor();await wait_real(.22)
 check(app.menu.visible and is_equal_approx(cursor(),before),"actual menu holds new music playback cursor")
 app.menu.close_menu();app.sync_audio_pause();await wait_real(.2)
 check(cursor()>before+.08,"closing menu resumes same music cursor")
 app.paused_manual=true;app.sync_audio_pause();await wait_real(.12);before=cursor()
 var state:Dictionary=JSON.parse_string(JSON.stringify(app.audio.snapshot_playback()))
 await wait_real(.2);check(is_equal_approx(cursor(),before),"manual pause holds new music")
 app.audio.restore_playback(state);await wait_real(.12)
 check(music_id()=="MUS_HOSPITAL" and music_player().stream_paused and absf(cursor()-before)<.12,"audio JSON restores current replacement and paused seek without replay from zero")
 app.paused_manual=false;app.sync_audio_pause();before=cursor();await wait_real(.2)
 check(cursor()>before+.08,"restored replacement resumes after pause")
 app.audio.set_level("music",.25)
 check(is_equal_approx(music_player().volume_linear,float(app.audio.levels.master)*.25),"existing music volume controls apply to replacement")
 app.unlock_asylum();pump();check(music_id()=="MUS_HOSPITAL","actual asylum unlock selects hospital exploration recording")
 app.unlock_cortex();pump();check(music_id()=="MUS_HOSPITAL","actual cortex exploration selects hospital recording")
 app.unlock_combat();pump();check(music_id()=="MUS_DANGER","actual cortex battle selects danger recording")
 starts=app.audio.starts.size();app.enter_room("hippocampus");pump()
 check(music_id()=="MUS_DANGER" and app.audio.starts.size()==starts,"deep chase preserves danger without doorway restart")
 var mode:String=app.rules.mode;app.rules.mode="exploration"
 check(app.gameplay_music_cue()=="MUS_HOSPITAL","deep exploration selection-only fixture maps hospital without creating new gameplay")
 app.rules.mode=mode;app.unlock_street();pump();check(music_id()=="MUS_DANGER","existing Street music remains unchanged")
 app.rules.control_ms=0;app.street.exit_crossed();app.sync_audio_pause();app._process(0)
 check(app.street.data.ending.id=="E2" and music_id()=="MUS_END","actual E2 handler replaces danger with delivered ending recording")
 starts=app.audio.starts.size();app.street.advance_ending(1.6);app.street.advance_ending(0)
 clear_lines();app.street.advance_ending(.01);app.street.advance_ending(3.1)
 check(app.street.data.ending.phase=="planet" and music_id()=="MUS_END" and app.audio.starts.size()==starts,"origin planet epilogue continues same recording without restart")
 app.street.data.ending={};app.street.data.boundary=false;app.rules.transitioning=false;app.rules.control_ms=120000
 clear_lines();app.street.exit_crossed();app.sync_audio_pause();app._process(0)
 check(app.street.data.ending.id=="E3" and music_id()=="MUS_END","actual E3 handler uses same specified ending recording")
 var confirm_applied:bool=bool(bindings.last_delivery.get("confirm_replacement_applied",false))
 if confirm_applied:
  var confirm:AudioStream=app.audio.assets.SFX_UI_CONFIRM.stream
  check(entries.SFX_UI_CONFIRM.stream.ends_with("sfx_ui_confirm_v001_new.wav") and confirm is AudioStreamWAV,"confirmation cue resolves new WAV with stable ID")
  check(absf(confirm.get_length()-.1002916667)<.001,"new confirmation retains source duration with no leading trim")
  check(app.audio.cue_ui("open","new-confirm-test") and str(app.audio.channels.ui[0].get_meta("cue_id",""))=="SFX_UI_CONFIRM","real UI cue starts replacement while world is held by ending")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","confirm_replacement_applied":confirm_applied,"scope":"Stationary chapter/ending fixtures through real handlers; actual imported music mixer cursors, menu/manual/dialogue and JSON. Dummy output; not subjective listening, loop/mix, human/full-game acceptance."},"  "));file.close()
 print("AUDIO_DELIVERY_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
