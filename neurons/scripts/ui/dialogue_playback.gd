extends Node
## Presentation clock only. Source speaker/text remain unchanged in the queue.
## Existing save snapshots already retain the queue and audio playback cursor.
var app
var serial:int=0
var current_token:int=-1
var current_voice:String=""

func _init(owner=null) -> void:
 app=owner
 process_mode=Node.PROCESS_MODE_ALWAYS

static func display_text(raw:String) -> String:
 var text:String=""
 for character in raw:
  var code:int=character.unicode_at(0)
  # Full-width ASCII punctuation only; letters, numbers and unusual authored
  # dialogue glyphs keep their original form.
  text+=String.chr(code-65248) if code>=65281 and code<=65374 and not (code>=65296 and code<=65305) and not (code>=65313 and code<=65338) and not (code>=65345 and code<=65370) else character
 var punctuation:Dictionary={"，":",","。":".","！":"!","？":"?","：":":","；":";","、":",","（":"(","）":")","【":"[","】":"]","「":"\"","」":"\"","『":"\"","』":"\"","《":"<","》":">","〈":"<","〉":">","“":"\"","”":"\"","‘":"'","’":"'","—":"-","–":"-","·":" - ","～":"~","…":"...","﹏":"_","　":" "}
 for key in punctuation:text=text.replace(str(key),str(punctuation[key]))
 var dots:=RegEx.new();dots.compile("\\.{2,}")
 return dots.sub(text,"...",true)

static func reading_seconds(raw:String) -> float:
 var text:String=display_text(raw)
 var weight:float=0.0
 for character in text:
  var code:int=character.unicode_at(0)
  if character in [" ","\t","\n"]:weight+=0.25
  elif character in [".",",","!","?",";",":"]:weight+=1.2
  elif code<128:weight+=0.45
  else:weight+=1.0
 return maxf(2.2,1.2+weight/5.5)

func bind_current() -> void:
 if app.dialogue_queue.is_empty():clear_current();return
 var line:Dictionary=app.dialogue_queue[0]
 if not line.has("_display_token"):
  serial+=1;line._display_token=serial
 serial=maxi(serial,int(line._display_token))
 # Integer microseconds round-trip through JSON exactly. Old snapshots keep
 # their already-read time; the compatibility seconds field is derived.
 if not line.has("_display_elapsed_usec"):line._display_elapsed_usec=roundi(float(line.get("_display_elapsed",0.0))*1000000.0)
 line._display_elapsed=float(line._display_elapsed_usec)/1000000.0
 if not line.has("_display_duration"):line._display_duration=reading_seconds(str(line.text))
 var token:int=int(line._display_token)
 if token!=current_token:
  clear_current();current_token=token
 current_voice=str(line.get("voice_id",""))
 if current_voice.is_empty() and app.audio!=null:current_voice=app.audio.dialogue_voice(str(line.speaker),str(line.text))

func clear_current() -> void:
 if not current_voice.is_empty() and app.audio!=null:app.audio.stop_dialogue_voice(current_voice)
 current_token=-1;current_voice=""

func voice_active() -> bool:
 return not current_voice.is_empty() and app.audio!=null and app.audio.voice_playing(current_voice)

func can_advance() -> bool:
 if app.dialogue_timing_paused() or voice_active():return false
 if not app.dialogue_queue.is_empty() and app.audio!=null and app.audio.enabled and app.audio.has_dialogue_voice(current_voice) and not app.dialogue_queue[0].get("_voice_started",false):return false
 return true

func _process(delta:float) -> void:
 if app==null or not is_instance_valid(app):return
 # Family-collapse presentation writes this same label directly. Normalize
 # its display too, leaving the authored data and queued source text intact.
 if app.dialogue_text!=null and app.dialogue_panel.visible:app.dialogue_text.text=display_text(app.dialogue_text.text)
 if app.dialogue_queue.is_empty():
  if current_token>=0:clear_current()
  return
 bind_current()
 if app.dialogue_timing_paused() or not is_finite(delta) or delta<=0:return
 var line:Dictionary=app.dialogue_queue[0]
 var voiced:bool=app.audio!=null and app.audio.enabled and app.audio.has_dialogue_voice(current_voice)
 if voiced and voice_active():line._voice_started=true
 if voiced and not line.get("_voice_started",false):
  # An occupied voice channel is allowed to finish; it is never stolen by
  # the next line. Loading a saved started line does not issue another cue.
  if not app.audio.cue(current_voice,"dialogue:%d"%current_token):return
  line._voice_started=true
 line._display_elapsed_usec=int(line._display_elapsed_usec)+roundi(delta*1000000.0)
 line._display_elapsed=float(line._display_elapsed_usec)/1000000.0
 if not app.auto_dialogue_enabled:return
 if float(line._display_elapsed)<float(line._display_duration) or (voiced and voice_active()):return
 app.advance_dialogue()
