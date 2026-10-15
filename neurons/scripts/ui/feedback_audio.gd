extends AudioStreamPlayer
signal level_changed(channel:String,value:float)
## User audio replaces provisional tones. Playback cannot submit game facts.
const CUES := {
 "open":["SFX_UI_CONFIRM","ui",170.0], "close":["SFX_UI_BACK","ui",120.0],
 "invalid":["SFX_UI_DENIED","ui",82.0], "success":["SFX_SKIN","world",440.0],
 "transfer":["SFX_ITEM_HANDOFF","world",660.0], "hit":["SFX_HIT","world",65.0],
 "drawer":["SFX_DRAWER","world",145.0]
}
var enabled := true
var world_frozen := false
var voice_frozen := false
var levels := {"master":0.8,"ui":0.7,"world":0.7,"ambience":0.5,"music":0.5,"voice":0.8}
var assets:Dictionary={}
var tones:Dictionary={}
var channels:Dictionary={}
var played_events:Dictionary={}
var starts:Array[Dictionary]=[]

func _exit_tree() -> void:
 # Explicitly detach playback before the audio server shuts down. Ogg
 # playback otherwise retains the packet sequence when the window exits.
 reset_scene()
 assets.clear()
 tones.clear()

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 add_to_group("neurons_audio")
 for channel in ["ui","world","ambience","music","voice"]:
  channels[channel]=[]
  for i in range(4 if channel=="world" else 1):
   var player:=AudioStreamPlayer.new()
   add_child(player)
   channels[channel].append(player)
 refresh_levels()

 var bindings=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_bindings.json"))
 if bindings is Dictionary:
  for entry in bindings.get("assets",[]):
   if entry.get("license","").is_empty() or not ResourceLoader.exists(str(entry.get("stream",""))):continue
   var stream=load(str(entry.stream))
   if stream is AudioStream:register_asset(str(entry.id),stream,str(entry.channel),bool(entry.get("loop",false)))

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
 return true

func set_level(channel:String, value:float) -> void:
 if not levels.has(channel):return
 levels[channel]=clampf(value,0,1)
 refresh_levels()
 level_changed.emit(channel,float(levels[channel]))

func refresh_levels() -> void:
 for channel in channels:
  for player in channels[channel]:
   player.volume_linear=float(levels.master)*float(levels[channel]) if enabled else 0.0

func set_world_paused(value:bool, pause_voice:bool=false) -> void:
 world_frozen=value
 voice_frozen=pause_voice
 for channel in channels:
  if channel=="ui":continue
  for player in channels[channel]:player.stream_paused=pause_voice if channel=="voice" else value

func reset_scene() -> void:
 for channel in channels:
  for player in channels[channel]:
   if not is_instance_valid(player):continue
   player.stop()
   player.stream=null
 played_events.clear()
 starts.clear()

func stop_channel(channel:String) -> void:
 for player in channels.get(channel,[]):player.stop()

func snapshot_playback() -> Dictionary:
 var playing:Array=[]
 for channel in channels:
  for player in channels[channel]:
   if player.playing:
    playing.append({"id":str(player.get_meta("cue_id","")),"position":player.get_playback_position(),"channel":channel})
 return {"receipts":played_events.duplicate(true),"playing":playing}

func restore_playback(state:Dictionary) -> void:
 reset_scene()
 played_events=state.get("receipts",{}).duplicate(true)
 for entry in state.get("playing",[]):
  var id:String=str(entry.id)
  if not assets.has(id):continue
  var spec:Dictionary=assets[id]
  var channel:String=str(spec.channel)
  if entry.get("channel","")=="ui" and channel=="world":channel="ui"
  var position:float=float(entry.position)
  if position<0 or position>=spec.stream.get_length():continue
  for player in channels[channel]:
   if player.playing:continue
   player.stream=spec.stream
   player.set_meta("cue_id",id)
   player.play(position)
   player.stream_paused=voice_frozen if channel=="voice" else world_frozen if channel!="ui" else false
   break

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
 if not enabled or (voice_frozen and channel=="voice") or (world_frozen and channel not in ["ui","voice"]):return false
 var key:=id+":"+event_id
 if not event_id.is_empty() and played_events.has(key):return false
 for current in channels[channel]:
  if looping and current.playing and current.stream==sound:return false
 var player:AudioStreamPlayer=null
 for candidate in channels[channel]:
  if not candidate.playing:
   player=candidate
   break
 if player==null:
  if channel=="world":return false # No delayed replay queue.
  player=channels[channel][0]
 player.stream=sound
 player.set_meta("cue_id",id)
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

