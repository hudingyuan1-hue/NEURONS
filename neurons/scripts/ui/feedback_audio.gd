extends AudioStreamPlayer
signal level_changed(channel:String,value:float)
## User audio replaces provisional tones. Playback cannot submit game facts.
const CUES := {
 "open":["SFX_UI_CONFIRM","ui",170.0], "close":["SFX_UI_BACK","ui",120.0],
 "invalid":["SFX_UI_DENIED","ui",82.0], "success":["SFX_SKIN","world",440.0],
 "transfer":["SFX_ITEM_HANDOFF","world",660.0], "hit":["SFX_HIT","world",65.0],
 "drawer":["SFX_DRAWER","world",145.0]
}
const CONTINUOUS_MUSIC:PackedStringArray=["MUS_MENU","MUS_ROOM","MUS_HOSPITAL","MUS_DANGER"]
const MUSIC_FADE_SECONDS:float=0.35
const AMBIENCE_FADE_SECONDS:float=0.2
var enabled := true
var world_frozen := false
var voice_frozen := false
var background_frozen := false
var scene_playback_frozen := false
var levels := {"master":0.8,"ui":0.7,"world":0.7,"ambience":0.5,"music":0.5,"voice":0.8}
var assets:Dictionary={}
var tones:Dictionary={}
var channels:Dictionary={}
var played_events:Dictionary={}
var starts:Array[Dictionary]=[]
var dialogue_bindings:Array=[]
var music_streams:Dictionary={}
var loop_variants:Dictionary={}
var loop_variant_issues:Array=[]
var music_target:String=""
var music_continuous:bool=false
var music_slot:int=-1
var music_gains:Array=[0.0,0.0]
var music_fade_from:Array=[0.0,0.0]
var music_fade_to:Array=[0.0,0.0]
var music_fade_elapsed:float=0.0
var music_fade_duration:float=0.0
var ambience_target:String=""
var ambience_gain:float=1.0
var ambience_fade_from:float=1.0
var ambience_fade_to:float=1.0
var ambience_fade_elapsed:float=0.0
var ambience_fade_duration:float=0.0

func _exit_tree() -> void:
 # Explicitly detach playback before the audio server shuts down. Ogg
 # playback otherwise retains the packet sequence when the window exits.
 reset_scene()
 assets.clear()
 tones.clear()
 music_streams.clear()
 loop_variants.clear()

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 add_to_group("neurons_audio")
 for channel in ["ui","world","ambience","music","voice"]:
  channels[channel]=[]
  for i in range(4 if channel=="world" else 2 if channel=="music" else 1):
   var player:=AudioStreamPlayer.new()
   add_child(player)
   channels[channel].append(player)
 refresh_levels()

 var bindings=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_bindings.json"))
 if bindings is Dictionary:
  dialogue_bindings=bindings.get("dialogue",[]).duplicate(true)
  for entry in bindings.get("assets",[]):
   if entry.get("license","").is_empty() or not ResourceLoader.exists(str(entry.get("stream",""))):continue
   var stream=load(str(entry.stream))
   if stream is AudioStream:register_asset(str(entry.id),stream,str(entry.channel),bool(entry.get("loop",false)))
 _load_loop_variants()

func _load_loop_variants() -> void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_loop_variants.json"))
 if not data is Dictionary:
  loop_variant_issues.append("missing loop-variant manifest; sustained playback uses original copy")
  push_warning(str(loop_variant_issues.back()));return
 for entry in data.get("variants",[]):
  var id:String=str(entry.get("id",""));var path:String=str(entry.get("stream",""))
  if not id in ["MUS_HOSPITAL","MUS_DANGER","AMB_FAN"] or not assets.has(id):continue
  if not ResourceLoader.exists(path):
   loop_variant_issues.append(id+": missing derivative; sustained playback uses original copy")
   push_warning(str(loop_variant_issues.back()));continue
  var stream=load(path)
  if stream is AudioStream:loop_variants[id]={"stream":stream,"path":path}

func register_asset(id:String, source:AudioStream, channel:String, looping:bool=false) -> bool:
 if source==null or not channels.has(channel):return false
 var stream_copy:AudioStream=source.duplicate()
 if stream_copy is AudioStreamWAV:
  stream_copy.loop_mode=AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
  if looping and stream_copy.loop_end<=stream_copy.loop_begin:
   stream_copy.loop_begin=0
   stream_copy.loop_end=int(stream_copy.get_length()*stream_copy.mix_rate)
 elif stream_copy is AudioStreamOggVorbis or stream_copy is AudioStreamMP3:
  stream_copy.loop=looping
 elif looping:
  return false
 assets[id]={"stream":stream_copy,"channel":channel,"loop":looping}
 loop_variants.erase(id) # An explicit replacement must not retain an older derivative.
 music_streams.erase(id+":true");music_streams.erase(id+":false")
 return true

func _music_stream(id:String,continuous:bool) -> AudioStream:
 var key:String=id+":"+str(continuous)
 if music_streams.has(key):return music_streams[key]
 var source:AudioStream=(loop_variants[id].stream if continuous and loop_variants.has(id) else assets[id].stream).duplicate()
 if source is AudioStreamWAV:
  source.loop_mode=AudioStreamWAV.LOOP_FORWARD if continuous else AudioStreamWAV.LOOP_DISABLED
  if continuous:
   source.loop_begin=0
   source.loop_end=int(source.get_length()*source.mix_rate)
 elif source is AudioStreamOggVorbis or source is AudioStreamMP3:source.loop=continuous
 music_streams[key]=source
 return source

func _music_can_loop(id:String) -> bool:
 return id!="MUS_END" and (id in CONTINUOUS_MUSIC or assets.has(id) and bool(assets[id].loop))

## Scene music is state, not a once-only gameplay event. Calling this each frame
## is safe; returning to a previous scene cue does not replay an event receipt.
## Only the explicit sustained BGM roles loop. Opening/ending remain cue().
func set_music(id:String,fade_seconds:float=MUSIC_FADE_SECONDS) -> bool:
 if not id in CONTINUOUS_MUSIC:return false
 return _transition_music(id,true,fade_seconds,false,"scene-context")

func _transition_music(id:String,continuous:bool,fade_seconds:float,force:bool=false,event_id:String="") -> bool:
 if not enabled or channel_frozen("music") or not assets.has(id) or assets[id].channel!="music":return false
 var players:Array=channels.get("music",[])
 if players.size()!=2:return false
 if not force and music_target==id:
  if music_slot>=0 and players[music_slot].has_stream_playback():return false
  if not continuous:return false
 var selected:int=-1
 if not force:
  for i in range(players.size()):
   if players[i].has_stream_playback() and str(players[i].get_meta("cue_id",""))==id:
    selected=i;break # Reverse an unfinished crossfade without restarting A.
 var started:bool=selected<0
 if started:
  for i in range(players.size()):
   if not players[i].has_stream_playback():selected=i;break
  if selected<0:selected=0 if float(music_gains[0])<=float(music_gains[1]) else 1
  var player:AudioStreamPlayer=players[selected]
  player.stop();player.stream=_music_stream(id,continuous)
  player.set_meta("cue_id",id);player.set_meta("music_continuous",continuous)
  music_gains[selected]=0.0
  player.stream_paused=false;player.play()
  starts.append({"id":id,"event":event_id,"channel":"music","provisional":false})
 music_target=id;music_continuous=continuous;music_slot=selected
 music_fade_from=music_gains.duplicate();music_fade_to=[0.0,0.0];music_fade_to[selected]=1.0
 music_fade_duration=clampf(fade_seconds,0.0,1.5);music_fade_elapsed=0.0
 _advance_music_fade(0.0)
 return true

func _process(delta:float) -> void:
 if not channel_frozen("music"):_advance_music_fade(delta)
 if not channel_frozen("ambience"):_advance_ambience_fade(delta)

## The bedroom fan is a sustained room state, not a once-only attempt event.
## An empty context leaves the room; returning can resume a fading tail or
## start it again after the exit, independent of old fan event receipts.
func set_ambience(id:String,fade_seconds:float=AMBIENCE_FADE_SECONDS) -> bool:
 if not id in ["","AMB_FAN"] or not enabled or channel_frozen("ambience"):return false
 var players:Array=channels.get("ambience",[])
 if players.is_empty():return false
 var player:AudioStreamPlayer=players[0]
 if id==ambience_target:
  if id.is_empty() and (not player.has_stream_playback() or ambience_fade_to<=0.0):return false
  if not id.is_empty() and player.has_stream_playback():return false
 if not id.is_empty():
  if not assets.has(id) or assets[id].channel!="ambience":return false
  if not player.has_stream_playback() or str(player.get_meta("cue_id",""))!=id:
   player.stop();player.stream=_music_stream(id,true)
   player.set_meta("cue_id",id);player.set_meta("ambience_continuous",true)
   ambience_gain=0.0;player.stream_paused=false;player.play()
   starts.append({"id":id,"event":"room-context","channel":"ambience","provisional":false})
 ambience_target=id
 ambience_fade_from=ambience_gain;ambience_fade_to=0.0 if id.is_empty() else 1.0
 ambience_fade_elapsed=0.0;ambience_fade_duration=clampf(fade_seconds,0.0,1.5)
 _advance_ambience_fade(0.0)
 return true

func _advance_ambience_fade(delta:float) -> void:
 if ambience_fade_elapsed>=ambience_fade_duration and is_equal_approx(ambience_gain,ambience_fade_to):return
 ambience_fade_elapsed=minf(ambience_fade_duration,ambience_fade_elapsed+maxf(0.0,delta))
 var progress:float=1.0 if ambience_fade_duration<=0.0 else ambience_fade_elapsed/ambience_fade_duration
 ambience_gain=lerpf(ambience_fade_from,ambience_fade_to,progress)
 if progress>=1.0 and ambience_fade_to<=0.0:
  for player in channels.get("ambience",[]):player.stop()
 refresh_levels()

func _advance_music_fade(delta:float) -> void:
 if music_slot<0:return
 music_fade_elapsed=minf(music_fade_duration,music_fade_elapsed+maxf(0.0,delta))
 var progress:float=1.0 if music_fade_duration<=0.0 else music_fade_elapsed/music_fade_duration
 for i in range(music_gains.size()):
  music_gains[i]=lerpf(float(music_fade_from[i]),float(music_fade_to[i]),progress)
  var player:AudioStreamPlayer=channels.music[i]
  if progress>=1.0 and float(music_fade_to[i])<=0.0 and player.has_stream_playback():player.stop()
 refresh_levels()

func set_level(channel:String, value:float) -> void:
 if not levels.has(channel):return
 levels[channel]=clampf(value,0,1)
 refresh_levels()
 level_changed.emit(channel,float(levels[channel]))

func refresh_levels() -> void:
 for channel in channels:
  for i in range(channels[channel].size()):
   var player:AudioStreamPlayer=channels[channel][i]
   var gain:float=float(music_gains[i]) if channel=="music" else ambience_gain if channel=="ambience" else 1.0
   player.volume_linear=float(levels.master)*float(levels[channel])*gain if enabled else 0.0

func set_world_paused(value:bool, pause_voice:bool=false,pause_background:bool=true) -> void:
 world_frozen=value
 voice_frozen=pause_voice
 background_frozen=value and pause_background
 scene_playback_frozen=value and pause_background
 for channel in channels:
  for player in channels[channel]:
   var frozen:bool=playback_frozen(str(channel))
   if player.has_stream_playback() and player.stream_paused!=frozen:player.stream_paused=frozen

func channel_frozen(channel:String) -> bool:
 if channel=="ui":return false
 if channel=="voice":return voice_frozen
 if channel in ["music","ambience"]:return background_frozen
 return world_frozen

func playback_frozen(channel:String) -> bool:
 # Dialogue freezes new gameplay sound triggers with world actions, but an
 # already sounding contact/room tail remains audible. Manual/menu pause
 # still suspends those playbacks. Sound never advances a gameplay clock.
 if channel=="world":return scene_playback_frozen
 return channel_frozen(channel)

func dialogue_voice(speaker:String,text:String) -> String:
 for binding in dialogue_bindings:
  if str(binding.get("speaker",""))==speaker and str(binding.get("text",""))==text:return str(binding.get("asset",""))
 return ""

func has_dialogue_voice(id:String) -> bool:
 return not id.is_empty() and assets.has(id) and assets[id].channel=="voice" and not assets[id].loop

func voice_playing(id:String="") -> bool:
 for player in channels.get("voice",[]):
  # Godot's playing flag is false while paused. The retained playback is
  # still an unfinished line and must survive saves and reserve its slot.
  if player.has_stream_playback() and (id.is_empty() or str(player.get_meta("cue_id",""))==id):return true
 return false

func stop_dialogue_voice(id:String) -> void:
 for player in channels.get("voice",[]):
  if str(player.get_meta("cue_id",""))==id:player.stop()

func reset_scene() -> void:
 for channel in channels:
  for player in channels[channel]:
   if not is_instance_valid(player):continue
   player.stop()
   player.stream=null
 played_events.clear()
 starts.clear()
 _reset_music_state()
 _reset_ambience_state()

func _reset_music_state() -> void:
 music_target="";music_continuous=false;music_slot=-1
 music_gains=[0.0,0.0];music_fade_from=[0.0,0.0];music_fade_to=[0.0,0.0]
 music_fade_elapsed=0.0;music_fade_duration=0.0

func stop_channel(channel:String) -> void:
 for player in channels.get(channel,[]):player.stop()
 if channel=="music":_reset_music_state()
 if channel=="ambience":_reset_ambience_state()

func _reset_ambience_state() -> void:
 ambience_target="";ambience_gain=1.0;ambience_fade_from=1.0;ambience_fade_to=1.0
 ambience_fade_elapsed=0.0;ambience_fade_duration=0.0

func snapshot_playback() -> Dictionary:
 var playing:Array=[]
 for channel in channels:
  for player in channels[channel]:
   if player.has_stream_playback():
    playing.append({"id":str(player.get_meta("cue_id","")),"position":player.get_playback_position(),"channel":channel})
 var music_players:Array=[]
 for i in range(channels.get("music",[]).size()):
  var player:AudioStreamPlayer=channels.music[i]
  if player.has_stream_playback():music_players.append({"slot":i,"id":str(player.get_meta("cue_id","")),"position":player.get_playback_position(),"continuous":bool(player.get_meta("music_continuous",false))})
 var ambience_players:Array=[]
 for player in channels.get("ambience",[]):
  if player.has_stream_playback():ambience_players.append({"id":str(player.get_meta("cue_id","")),"position":player.get_playback_position(),"continuous":bool(player.get_meta("ambience_continuous",false))})
 return {"receipts":played_events.duplicate(true),"playing":playing,"music":{"target":music_target,"continuous":music_continuous,"slot":music_slot,"gains":music_gains.duplicate(),"from":music_fade_from.duplicate(),"to":music_fade_to.duplicate(),"elapsed":music_fade_elapsed,"duration":music_fade_duration,"players":music_players},"ambience":{"target":ambience_target,"gain":ambience_gain,"from":ambience_fade_from,"to":ambience_fade_to,"elapsed":ambience_fade_elapsed,"duration":ambience_fade_duration,"players":ambience_players}}

func restore_playback(state:Dictionary) -> void:
 reset_scene()
 played_events=state.get("receipts",{}).duplicate(true)
 for entry in state.get("playing",[]):
  var id:String=str(entry.id)
  if not assets.has(id):continue
  var spec:Dictionary=assets[id]
  var channel:String=str(spec.channel)
  if channel=="music" and state.has("music"):continue
  if channel=="ambience" and state.has("ambience"):continue
  if entry.get("channel","")=="ui" and channel=="world":channel="ui"
  var position:float=float(entry.position)
  if position<0 or position>=spec.stream.get_length():continue
  for player in channels[channel]:
   if player.has_stream_playback():continue
   if channel=="music":
    var continuous:bool=id in CONTINUOUS_MUSIC
    player.stream=_music_stream(id,continuous);player.set_meta("music_continuous",continuous)
    music_target=id;music_continuous=continuous;music_slot=channels.music.find(player)
    music_gains[music_slot]=1.0;music_fade_from=music_gains.duplicate();music_fade_to=music_gains.duplicate()
   elif channel=="ambience" and id=="AMB_FAN":
    player.stream=_music_stream(id,true);player.set_meta("ambience_continuous",true);ambience_target=id
   else:
    player.stream=spec.stream
    if channel=="ambience":player.set_meta("ambience_continuous",bool(spec.loop))
   player.set_meta("cue_id",id)
   player.play(position)
   player.stream_paused=playback_frozen(channel)
   break
 if state.has("music"):_restore_music(state.music)
 if state.has("ambience"):_restore_ambience(state.ambience)
 refresh_levels()

func _restore_ambience(saved:Dictionary) -> void:
 var players:Array=channels.get("ambience",[])
 for entry in saved.get("players",[]):
  var id:String=str(entry.get("id",""))
  if players.is_empty() or not assets.has(id) or assets[id].channel!="ambience":continue
  var continuous:bool=bool(entry.get("continuous",false)) and (id=="AMB_FAN" or bool(assets[id].loop))
  var stream:AudioStream=_music_stream(id,continuous);var position:float=maxf(0.0,float(entry.get("position",0)))
  if position>=stream.get_length():
   if not continuous or stream.get_length()<=0:continue
   position=fmod(position,stream.get_length())
  var player:AudioStreamPlayer=players[0]
  player.stream=stream;player.set_meta("cue_id",id);player.set_meta("ambience_continuous",continuous)
  player.play(position);player.stream_paused=playback_frozen("ambience")
  break
 ambience_target=str(saved.get("target",""))
 if ambience_target!="AMB_FAN":ambience_target=""
 ambience_gain=clampf(float(saved.get("gain",1.0)),0.0,1.0)
 ambience_fade_from=clampf(float(saved.get("from",ambience_gain)),0.0,1.0)
 ambience_fade_to=clampf(float(saved.get("to",ambience_gain)),0.0,1.0)
 ambience_fade_duration=clampf(float(saved.get("duration",0.0)),0.0,1.5)
 ambience_fade_elapsed=clampf(float(saved.get("elapsed",0.0)),0.0,ambience_fade_duration)

func _restore_music(saved:Dictionary) -> void:
 var players:Array=channels.get("music",[])
 for entry in saved.get("players",[]):
  var slot:int=int(entry.get("slot",-1));var id:String=str(entry.get("id",""))
  if slot<0 or slot>=players.size() or not assets.has(id) or assets[id].channel!="music":continue
  var continuous:bool=bool(entry.get("continuous",false)) and _music_can_loop(id)
  var stream:AudioStream=_music_stream(id,continuous);var position:float=maxf(0.0,float(entry.get("position",0)))
  if position>=stream.get_length():
   if not continuous or stream.get_length()<=0:continue
   position=fmod(position,stream.get_length())
  var player:AudioStreamPlayer=players[slot]
  player.stream=stream;player.set_meta("cue_id",id);player.set_meta("music_continuous",continuous)
  player.play(position);player.stream_paused=playback_frozen("music")
 music_target=str(saved.get("target",""));music_continuous=bool(saved.get("continuous",false)) and _music_can_loop(music_target)
 music_slot=clampi(int(saved.get("slot",-1)),-1,1)
 for field in ["gains","from","to"]:
  var values=saved.get(field,[0.0,0.0])
  if not values is Array or values.size()!=2:values=[0.0,0.0]
  var clean:Array=[clampf(float(values[0]),0.0,1.0),clampf(float(values[1]),0.0,1.0)]
  if field=="gains":music_gains=clean
  elif field=="from":music_fade_from=clean
  else:music_fade_to=clean
 music_fade_duration=clampf(float(saved.get("duration",0)),0.0,1.5)
 music_fade_elapsed=clampf(float(saved.get("elapsed",0)),0.0,music_fade_duration)

func cue_ui(kind:String,event_id:String="") -> bool:
 return cue(kind,event_id,"ui")

func cue(kind:String, event_id:String="",presentation_channel:String="") -> bool:
 var spec:Array=CUES.get(kind,[kind,"world",0.0])
 var id:String=spec[0]
 var channel:String=spec[1]
 var sound:AudioStream
 var looping:=false
 if assets.has(id):
  channel=assets[id].channel
  sound=assets[id].stream
  looping=assets[id].loop
 elif CUES.has(kind):
  if not tones.has(kind):tones[kind]=make_test_tone(float(spec[2]))
  sound=tones[kind]
 else:
  return false # Missing music/ambience/voice remains silent.
 if presentation_channel=="ui" and channel in ["ui","world"]:channel="ui"
 if not enabled or channel_frozen(channel):return false
 var key:=id+":"+event_id
 if not event_id.is_empty() and played_events.has(key):return false
 if channel=="music":
  if not _transition_music(id,looping and _music_can_loop(id),MUSIC_FADE_SECONDS,not event_id.is_empty(),event_id):return false
  if not event_id.is_empty():played_events[key]=true
  return true
 for current in channels[channel]:
  if looping and current.has_stream_playback() and current.stream==sound:return false
 var player:AudioStreamPlayer=null
 for candidate in channels[channel]:
  if not candidate.has_stream_playback():
   player=candidate
   break
 if player==null:
  if channel in ["world","voice"]:return false # Never steal a still-speaking voice; no delayed world replay.
  player=channels[channel][0]
 player.stream=sound
 player.set_meta("cue_id",id)
 if channel=="ambience":
  _reset_ambience_state();player.set_meta("ambience_continuous",looping);refresh_levels()
 player.stream_paused=false
 player.play()
 if not event_id.is_empty():played_events[key]=true
 starts.append({"id":id,"event":event_id,"channel":channel,"provisional":not assets.has(id)})
 return true

func make_test_tone(hz:float) -> AudioStreamWAV:
 var rate:=22050
 var count:=int(rate*0.12)
 var data:=PackedByteArray()
 data.resize(count*2)
 for i in range(count):
  var t:=float(i)/rate
  var envelope:=pow(1.0-float(i)/count,2)*minf(1.0,float(i)/120)
  var value:=int(sin(TAU*hz*t)*envelope*2600)
  data.encode_s16(i*2,value)
 var wav:=AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=rate
 wav.data=data
 return wav

