extends Control
## Presentation-only opening. Host freezes the world and stores snapshot() in
## its existing profile/schema; this module never owns gameplay or save files.
signal completed(sequence:String,skipped:bool)
signal state_changed(state:Dictionary)
const DATA_PATH="res://data/opening.json"
var data:Dictionary={}
var sequence_key:String=""
var context:Dictionary={}
var index:int=0
var typed:float=0.0
var card_clock:float=0.0
var hold_clock:float=0.0
var auto_play:bool=false
var paused:bool=false
var finished:bool=false
var fade_out:float=0.0
var completed_ids:Array=[]
var reduced_effects:bool=false
var art_canvas:Node2D
var caption:Label
var speaker:Label
var progress:Label
var next_button:Button
var auto_button:Button
var pause_button:Button

func _init() -> void:
 visible=false;process_mode=Node.PROCESS_MODE_ALWAYS
 mouse_filter=Control.MOUSE_FILTER_STOP

func _ready() -> void:
 data=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf");theme.default_font_size=20
 var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("101b20");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
 art_canvas=Node2D.new();art_canvas.set_script(load("res://scripts/ui/menu_art.gd"));art_canvas.host=self;add_child(art_canvas)
 var status:=label("演出占位 · 正式画面与语音待交付",Rect2(45,25,900,35),15,Color("aab3a5"))
 status.mouse_filter=Control.MOUSE_FILTER_IGNORE
 progress=label("",Rect2(1080,25,150,35),16,Color("b4c6b6"))
 var plate:=Panel.new();plate.position=Vector2(35,475);plate.size=Vector2(1210,210)
 plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
 plate.add_theme_stylebox_override("panel",style(Color("172a2b")));add_child(plate)
 speaker=label("",Rect2(60,487,1100,30),18,Color("b8cba8"))
 caption=label("",Rect2(60,526,1150,100),22,Color("e2dfc7"));caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 next_button=button("继续 / 完整显示",Rect2(1030,632,190,38),advance)
 auto_button=button("自动：关",Rect2(680,632,150,38),toggle_auto)
 pause_button=button("暂停演出",Rect2(850,632,160,38),toggle_pause)
 button("跳过",Rect2(1090,70,140,38),skip)
 refresh()

func style(color:Color) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=Color("6f8d83");s.set_border_width_all(1);s.set_corner_radius_all(4);return s

func label(text:String,bounds:Rect2,font_size:int,color:Color) -> Label:
 var l:=Label.new();l.text=text;l.position=bounds.position;l.size=bounds.size;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(l);return l

func button(text:String,bounds:Rect2,callback:Callable) -> Button:
 var b:=Button.new();b.text=text;b.position=bounds.position;b.size=bounds.size;b.add_theme_font_size_override("font_size",16);b.add_theme_stylebox_override("normal",style(Color("253b35")));b.pressed.connect(callback);add_child(b);return b

func cards() -> Array:
 return data.get("sequences",{}).get(sequence_key,{}).get("cards",[])

func current_card() -> Dictionary:
 return cards()[index] if index>=0 and index<cards().size() else {}

func current_text() -> String:
 return str(current_card().get("text","")).replace("{invader_id}",str(context.get("invader_id",""))).replace("{name}",str(context.get("name","")))

func start(sequence:String,values:Dictionary={},saved:Dictionary={}) -> bool:
 if not data.get("sequences",{}).has(sequence):return false
 sequence_key=sequence;context={"name":str(values.get("name","")),"invader_id":str(values.get("invader_id",""))}
 index=0;typed=0;card_clock=0;hold_clock=0;fade_out=0;paused=false;finished=false;completed_ids.clear()
 auto_play=bool(data.sequences[sequence].auto_play)
 if not saved.is_empty() and not restore(saved):return false
 visible=not finished;refresh();notify_state();return true

func snapshot() -> Dictionary:
 return {"schema":1,"sequence":sequence_key,"context":context.duplicate(true),"index":index,"typed":typed,"card_clock":card_clock,"hold_clock":hold_clock,"fade_out":fade_out,"auto_play":auto_play,"paused":paused,"finished":finished,"completed_ids":completed_ids.duplicate()}

func restore(saved:Dictionary) -> bool:
 if int(saved.get("schema",0))!=1 or str(saved.get("sequence",""))!=sequence_key:return false
 var restored_index:int=int(saved.get("index",-1))
 if restored_index<0 or restored_index>=cards().size():return false
 context={"name":str(saved.get("context",context).get("name","")),"invader_id":str(saved.get("context",context).get("invader_id",""))}
 index=restored_index;typed=clampf(float(saved.get("typed",0)),0,current_text().length())
 card_clock=maxf(0,float(saved.get("card_clock",0)));hold_clock=maxf(0,float(saved.get("hold_clock",0)))
 fade_out=clampf(float(saved.get("fade_out",0)),0,float(data.presentation_parameters.fade_seconds))
 auto_play=bool(saved.get("auto_play",false));paused=bool(saved.get("paused",false));finished=bool(saved.get("finished",false))
 completed_ids=saved.get("completed_ids",[]).duplicate()
 visible=not finished;refresh();return true

func notify_state() -> void:
 state_changed.emit(snapshot())

func refresh() -> void:
 if caption==null:return
 caption.text=current_text();caption.visible_characters=int(typed)
 caption.visible=str(current_card().get("visual",""))!="logo"
 speaker.text=str(current_card().get("speaker",""))
 progress.text="%d / %d"%[index+1,cards().size()] if not sequence_key.is_empty() else ""
 auto_button.text="自动：开" if auto_play else "自动：关"
 pause_button.text="继续演出" if paused else "暂停演出"
 next_button.disabled=paused or fade_out>0
 sync_opacity()
 if art_canvas!=null:art_canvas.queue_redraw()

func toggle_auto() -> void:
 if finished:return
 auto_play=not auto_play;hold_clock=0;refresh();notify_state()

func toggle_pause() -> void:
 if finished:return
 paused=not paused;refresh();notify_state()

func advance() -> void:
 if finished or paused or fade_out>0 or cards().is_empty():return
 if int(typed)<current_text().length():
  typed=current_text().length();hold_clock=0;refresh();notify_state();return
 var id:String=str(current_card().id)
 if id not in completed_ids:completed_ids.append(id)
 fade_out=float(data.presentation_parameters.fade_seconds)
 if reduced_effects:commit_next()
 else:refresh();notify_state()

func commit_next() -> void:
 fade_out=0
 if index+1>=cards().size():finish(false);return
 index+=1;typed=0;card_clock=0;hold_clock=0;refresh();notify_state()

func skip() -> void:
 if finished:return
 finish(true)

func finish(skipped:bool) -> void:
 if finished:return
 finished=true;visible=false;notify_state();completed.emit(sequence_key,skipped)

func _process(delta:float) -> void:
 if not visible or paused or finished or cards().is_empty():return
 if fade_out>0:
  fade_out=maxf(0,fade_out-delta)
  if fade_out<=0:commit_next()
  elif art_canvas!=null:art_canvas.queue_redraw()
  sync_opacity()
  return
 card_clock+=delta
 var duration:float=float(data.presentation_parameters.fade_seconds)
 typed=minf(current_text().length(),typed+delta*float(data.presentation_parameters.characters_per_second))
 caption.visible_characters=int(typed)
 if typed>=current_text().length() and card_clock>=duration:
  hold_clock+=delta
  var hold:float=float(data.presentation_parameters.blank_hold_seconds if current_text().is_empty() else data.presentation_parameters.auto_hold_seconds)
  if auto_play and hold_clock>=hold:advance()
 if art_canvas!=null:art_canvas.queue_redraw()
 sync_opacity()

func opacity() -> float:
 if reduced_effects:return 1.0
 var duration:float=float(data.presentation_parameters.fade_seconds)
 return fade_out/duration if fade_out>0 else clampf(card_clock/duration,0,1)

func sync_opacity() -> void:
 if caption==null:return
 caption.modulate.a=opacity();speaker.modulate.a=opacity()

func _gui_input(event:InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.position.y>=475:
  advance();accept_event()

func _unhandled_key_input(event:InputEvent) -> void:
 if not visible or not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode in [KEY_SPACE,KEY_ENTER]:advance();get_viewport().set_input_as_handled()
 elif event.keycode==KEY_ESCAPE:toggle_pause();get_viewport().set_input_as_handled()

func draw_art(canvas:Node2D) -> void:
 if not visible:return
 var visual:String=str(current_card().get("visual","black"))
 canvas.modulate.a=opacity()
 var panel:=Rect2(80,120,1120,335)
 canvas.draw_rect(panel,Color("17292d"))
 if visual=="black":canvas.draw_rect(panel,Color("080d10"));return
 if visual in ["city","country","sea","crisis"]:
  canvas.draw_rect(Rect2(80,120,1120,188),Color("3f4c50"))
  if visual in ["city","crisis"]:
   for i in range(11):
    var height:float=60+(i*37%115)
    canvas.draw_rect(Rect2(85+i*103,335-height,74,height),Color("26353a"))
  elif visual=="country":
   for i in range(6):canvas.draw_colored_polygon(PackedVector2Array([Vector2(95+i*185,340),Vector2(180+i*185,240),Vector2(265+i*185,340)]),Color("2d4140"))
  else:
   for i in range(5):canvas.draw_line(Vector2(90,310+i*22),Vector2(1190,310+i*22),Color("4f6569"),3)
  canvas.draw_circle(Vector2(875,237),55,Color("a89f7c"));canvas.draw_line(Vector2(885,160),Vector2(900,350),Color("7e7565"),6)
  canvas.draw_string(theme.default_font,Vector2(105,428),"危机画面占位 · 城市 / 乡村 / 海面",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("bec7b5"))
 elif visual=="laboratory":
  canvas.draw_rect(Rect2(220,210,830,150),Color("3e5555"))
  for i in range(6):
   var p:=Vector2(300+i*128,245+(i%2)*53)
   canvas.draw_circle(p,15,Color("9cae8f"))
   if i<5:canvas.draw_line(p,p+Vector2(128,53 if i%2==0 else -53),Color("809b89"),2)
  canvas.draw_string(theme.default_font,Vector2(105,428),"实验室神经元画面占位",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("bec7b5"))
 elif visual in ["back","gesture","turn"]:
  canvas.draw_line(Vector2(90,380),Vector2(1190,380),Color("53665e"),3)
  canvas.draw_rect(Rect2(575,240,130,140),Color("293b3e"))
  canvas.draw_string(theme.default_font,Vector2(420,218),"玩家形象待定 · 本轮仅演出位置标记",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("bec7b5"))
 elif visual in ["bedroom","sleep","wake","logo"]:
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(155,310),Vector2(520,165),Vector2(1100,300),Vector2(735,433)]),Color("52615e"))
  canvas.draw_rect(Rect2(375,262,360,105),Color("799090"))
  canvas.draw_rect(Rect2(395,264,70,40),Color("a6b5a4"))
  if visual in ["sleep","wake"]:
   canvas.draw_rect(Rect2(462,276 if visual=="sleep" else 221,175 if visual=="sleep" else 42,43 if visual=="sleep" else 101),Color("83a5b4"))
   canvas.draw_string(theme.default_font,Vector2(150,425),"卧室与角色演出占位",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("d1dac5"))
  if visual=="logo":canvas.draw_string(theme.default_font,Vector2(420,306),"N E U R O N S",HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color("dee5ce"))
