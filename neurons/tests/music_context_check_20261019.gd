extends Node
## Real AudioStreamPlayer checks. No listening, seamless-loop or mix approval.
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
var sound
var passes:Array=[]
var failures:Array=[]
var observed:Dictionary={}
var output:String="res://../docs/validation/music_context_20261019"

func _ready() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):output=argument.trim_prefix("--validation-root=")
 call_deferred("run")

func check(value:bool,label:String) -> void:
 if value:passes.append(label)
 else:failures.append(label)

func wait_seconds(seconds:float) -> void:
 # Playback is mixed in wall time; a heavy front-end frame can advance a
 # scene timer before the audio thread has completed another mixing block.
 var until:int=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<until:await get_tree().process_frame

func wait_for_cursor(player:AudioStreamPlayer,before:float) -> void:
 # Dummy output advances in approximately 93 ms mixing blocks on this host.
 # Observe a real block with a bounded wall-time deadline, not a sub-block
 # timing sample that can legitimately see the same cursor twice.
 var until:int=Time.get_ticks_msec()+600
 while Time.get_ticks_msec()<until and player.get_playback_position()<=before:await get_tree().process_frame

func active_player():
 return sound.channels.music[sound.music_slot] if sound.music_slot>=0 else null

func position() -> float:
 var player=active_player()
 return float(player.get_playback_position()) if player!=null else -1.0

func playing_count() -> int:
 var count:int=0
 for player in sound.channels.music:
  if player.has_stream_playback():count+=1
 return count

func short_stream(seconds:float) -> AudioStreamWAV:
 # A quiet in-memory technical fixture, not a newly delivered audio asset.
 var stream:=AudioStreamWAV.new();var data:=PackedByteArray()
 var rate:int=22050;var frames:int=int(seconds*rate);data.resize(frames*2)
 for i in range(frames):data.encode_s16(i*2,int(sin(TAU*220.0*i/rate)*500))
 stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=data
 return stream

func run() -> void:
 sound=Feedback.new();add_child(sound)
 await get_tree().process_frame
 observed.clock="audio wall time; scene delta is not used as a playback timer"
 observed.audio_output_devices=Array(AudioServer.get_output_device_list())
 observed.audio_output_device=AudioServer.output_device
 var args:PackedStringArray=OS.get_cmdline_args();var driver_index:int=args.find("--audio-driver")
 observed.requested_audio_driver=args[driver_index+1] if driver_index>=0 and driver_index+1<args.size() else "engine default"
 check(sound.assets.size()==27,"all existing delivered bindings load without adding manual music")
 for id in ["MUS_MENU","MUS_ROOM","MUS_HOSPITAL","MUS_DANGER","MUS_END"]:
  observed[id+"_length_s"]=sound.assets[id].stream.get_length()
  check(not sound.assets[id].loop,"source binding remains non-looping "+id)
 check(sound.loop_variants.size()==3 and sound.loop_variant_issues.is_empty(),"three sustained-only loop derivatives import without changing the27 bindings")
 observed.loop_variants={}
 for id in ["MUS_HOSPITAL","MUS_DANGER"]:
  sound.set_music(id,0.0)
  var looping_player=active_player();var count_before:int=sound.starts.size()
  observed.loop_variants[id]={"path":sound.loop_variants[id].path,"duration_s":looping_player.stream.get_length()}
  looping_player.seek(looping_player.stream.get_length()-.2)
  await wait_seconds(.45)
  observed.loop_variants[id].after_wrap_position=position()
  check(looping_player.has_stream_playback() and position()<1.0 and sound.starts.size()==count_before,"actual processed "+id+" crosses its recording end without a restart")
 sound.cue("MUS_HOSPITAL","one-shot-original")
 check(is_equal_approx(active_player().stream.get_length(),sound.assets.MUS_HOSPITAL.stream.get_length()) and not sound.music_continuous,"once-only music cue retains original full recording rather than derivative")
 sound.reset_scene()
 check(sound.set_music("MUS_HOSPITAL",0.0),"sustained exploration music starts")
 await wait_seconds(.09)
 check(active_player().has_stream_playback() and position()>0.0,"actual exploration playback cursor advances")
 var started:int=sound.starts.size();var before:float=position()
 for i in range(30):sound.set_music("MUS_HOSPITAL")
 await wait_seconds(.18)
 observed.same_music={"starts_before":started,"starts_after":sound.starts.size(),"cursor_before":before,"cursor_after":position()}
 check(sound.starts.size()==started and position()>before,"per-frame same music does not restart")
 check(sound.set_music("MUS_DANGER",.3),"battle context can crossfade from exploration")
 await wait_seconds(.08)
 check(playing_count()==2 and float(sound.music_gains[0])>0 and float(sound.music_gains[1])>0,"crossfade retains both real players with bounded gains")
 before=position();var fade_before:float=sound.music_fade_elapsed
 sound.set_world_paused(true,true,true)
 await wait_seconds(.09)
 check(absf(position()-before)<.05 and is_equal_approx(sound.music_fade_elapsed,fade_before),"hard pause freezes playback and crossfade clock")
 sound.set_world_paused(true,false,false)
 await wait_seconds(.12)
 check(position()>before and sound.music_fade_elapsed>fade_before,"dialogue freezes world while background playback and fade continue")
 sound.played_events["MUS_HOSPITAL:music:5:1"]=true
 check(sound.set_music("MUS_HOSPITAL",.2),"return to exploration is not rejected by old once-only receipt")
 await wait_seconds(.25)
 check(sound.music_target=="MUS_HOSPITAL" and playing_count()==1,"return transition completes with exactly one active soundtrack")
 started=sound.starts.size();before=position()
 sound.set_level("music",0.0)
 await wait_for_cursor(active_player(),before)
 var silent:bool=true
 for player in sound.channels.music:silent=silent and is_zero_approx(player.volume_linear)
 observed.zero_volume={"muted":silent,"cursor_before":before,"cursor_after":position()}
 check(silent and position()>before,"zero music level mutes without restarting or stopping its cursor")
 sound.set_level("music",.5)
 check(sound.starts.size()==started and active_player().volume_linear>0,"restoring volume keeps the same playback")
 sound.set_music("MUS_DANGER",.4)
 await wait_seconds(.08)
 sound.set_world_paused(true,true,true)
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(sound.snapshot_playback()))
 var saved_positions:Dictionary={}
 for player in snapshot.music.players:saved_positions[int(player.slot)]=float(player.position)
 sound.restore_playback(snapshot)
 var restored:bool=sound.music_target=="MUS_DANGER" and sound.music_continuous
 for slot in saved_positions:restored=restored and absf(float(sound.channels.music[slot].get_playback_position())-float(saved_positions[slot]))<.05
 check(restored and sound.music_gains==snapshot.music.gains,"JSON restore retains both cursors, target and current fade gains")
 fade_before=sound.music_fade_elapsed
 await wait_seconds(.07)
 check(is_equal_approx(sound.music_fade_elapsed,fade_before),"restored hard pause preserves the unfinished fade")
 sound.set_world_paused(false,false,false)
 await wait_seconds(.45)
 check(sound.music_target=="MUS_DANGER" and playing_count()==1,"restored music finishes its fade and continues")
 var legacy:Dictionary=sound.snapshot_playback();legacy.erase("music")
 sound.restore_playback(legacy)
 check(sound.music_target=="MUS_DANGER" and playing_count()==1 and not sound.set_music("MUS_DANGER"),"legacy playback snapshot upgrades without a duplicate start")
 sound.register_asset("MUS_ROOM",short_stream(.16),"music",false)
 check(sound.set_music("MUS_ROOM",0.0),"short sustained-music fixture starts")
 started=sound.starts.size()
 await wait_seconds(.60)
 check(active_player().has_stream_playback() and sound.starts.size()==started and position()<.18,"sustained role passes the recording end without frame-driven restarts")
 sound.register_asset("MUS_END",short_stream(.15),"music",false)
 check(sound.cue("MUS_END","ending-test"),"ending remains an independent one-shot cue")
 await wait_seconds(.65)
 check(playing_count()==0 and not sound.cue("MUS_END","ending-test") and not sound.set_music("MUS_END"),"ending finishes once and cannot become a sustained loop")
 sound.set_world_paused(false,false,false)
 var fan:AudioStreamPlayer=sound.channels.ambience[0]
 observed.AMB_FAN_length_s=sound.assets.AMB_FAN.stream.get_length()
 check(not sound.assets.AMB_FAN.loop and not sound.set_ambience("SFX_HIT"),"only the explicit fan context loops; source binding remains unchanged")
 sound.played_events["AMB_FAN:fan:1"]=true
 check(sound.set_ambience("AMB_FAN",0.0),"fan room context ignores an old attempt event receipt")
 await wait_seconds(.09)
 started=sound.starts.size();before=fan.get_playback_position()
 for i in range(30):sound.set_ambience("AMB_FAN")
 await wait_seconds(.09)
 check(sound.starts.size()==started and fan.get_playback_position()>before,"repeated bedroom context does not restart the real fan")
 fan.seek(fan.stream.get_length()-.2)
 await wait_seconds(.45)
 observed.fan_after_real_end={"playing":fan.has_stream_playback(),"position":fan.get_playback_position(),"starts":sound.starts.size()-started}
 check(fan.has_stream_playback() and fan.get_playback_position()<1.0 and sound.starts.size()==started,"real 24-second fan recording wraps with no new trigger or permanent silence")
 sound.set_ambience("",.3)
 await wait_seconds(.06)
 before=fan.get_playback_position();started=sound.starts.size()
 check(sound.set_ambience("AMB_FAN",.2) and sound.starts.size()==started and fan.get_playback_position()>=before,"return during exit fade keeps the existing fan cursor")
 await wait_seconds(.25)
 sound.set_ambience("",.3)
 await wait_seconds(.06)
 sound.set_world_paused(true,true,true)
 snapshot=JSON.parse_string(JSON.stringify(sound.snapshot_playback()))
 before=fan.get_playback_position();fade_before=sound.ambience_fade_elapsed
 sound.restore_playback(snapshot)
 check(sound.ambience_target.is_empty() and absf(fan.get_playback_position()-before)<.05 and is_equal_approx(sound.ambience_gain,float(snapshot.ambience.gain)),"JSON restores an exiting fan cursor and unfinished fade")
 await wait_seconds(.09)
 check(absf(fan.get_playback_position()-before)<.05 and is_equal_approx(sound.ambience_fade_elapsed,fade_before),"hard pause freezes fan playback and fade clock after restore")
 sound.set_world_paused(true,false,false)
 await wait_seconds(.35)
 check(not fan.has_stream_playback() and is_zero_approx(sound.ambience_gain),"ordinary dialogue allows the pending room-exit fade to finish")
 check(sound.set_ambience("AMB_FAN",.1),"return after a completed room exit starts fan again")
 await wait_seconds(.15)
 before=fan.get_playback_position()
 await wait_for_cursor(fan,before)
 check(fan.get_playback_position()>before and not fan.stream_paused,"ordinary dialogue keeps the sustained bedroom fan running")
 sound.set_level("ambience",0.0);before=fan.get_playback_position()
 await wait_for_cursor(fan,before)
 check(is_zero_approx(fan.volume_linear) and fan.get_playback_position()>before,"zero ambience level mutes without resetting the continuous cursor")
 sound.set_level("ambience",.5)
 legacy=sound.snapshot_playback();legacy.erase("ambience")
 sound.restore_playback(legacy)
 check(sound.ambience_target=="AMB_FAN" and fan.has_stream_playback() and not sound.set_ambience("AMB_FAN"),"old ambience snapshot migrates to sustained fan without a duplicate start")
 check(sound.set_ambience("",0.0) and not fan.has_stream_playback(),"empty room context can stop fan immediately when explicitly requested")
 sound.set_world_paused(false,false,false)
 check(sound.cue("SFX_KEY","key-once") and not sound.cue("SFX_KEY","key-once"),"non-music event receipts still suppress duplicate sounds")
 sound.set_music("MUS_ROOM",0.0)
 sound.set_ambience("AMB_FAN",0.0)
 sound.reset_scene()
 check(playing_count()==0 and sound.music_target.is_empty() and sound.ambience_target.is_empty() and not fan.has_stream_playback(),"scene reset removes music, fan and both transition states")
 var folder:String=ProjectSettings.globalize_path(output);DirAccess.make_dir_recursive_absolute(folder)
 var result:Dictionary={"passes":passes,"failures":failures,"observed":observed,"scope":"Actual AudioStreamPlayer loading, playback cursors, controlled short-stream end, crossfade, pause, volume and JSON checks. Not subjective listening, seam quality, final mixing or a natural full game playthrough."}
 var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("MUSIC_CONTEXT_RESULT ",passes.size(),"/",failures.size())
 sound.queue_free()
 await get_tree().process_frame
 var parent=get_parent()
 if parent.has_method("request_exit"):parent.request_exit(0 if failures.is_empty() else 1)
 else:
  await wait_seconds(.15) # Allow the asynchronous mixer to retire stopped streams.
  get_tree().quit(0 if failures.is_empty() else 1)
