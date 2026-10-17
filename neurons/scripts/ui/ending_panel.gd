extends Control
## Read-only E1 ending UI. Campaign owns save/title/new-profile transitions.
signal return_to_title_requested
signal new_game_requested
const FONT_PATH="res://assets/fonts/NotoSansCJKsc-Regular.otf"
var app
var records:ScrollContainer
var record_text:Label
var edition:Label
var heading:Label
var explanation:Label
var records_button:Button
var back_button:Button
var showing_records:bool=false
var _built:bool=false

func _init(owner=null) -> void:
 app=owner
 visible=false
 mouse_filter=Control.MOUSE_FILTER_STOP
 z_index=40

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 build()

func surface(fill:Color,border:Color,width:int=1) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=fill
 style.border_color=border
 style.set_border_width_all(width)
 style.set_corner_radius_all(3)
 return style

func label(text:String,rect:Rect2,size:int,color:Color) -> Label:
 var item:=Label.new()
 item.text=text;item.position=rect.position;item.size=rect.size
 item.add_theme_font_size_override("font_size",size)
 item.add_theme_color_override("font_color",color)
 item.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(item)
 return item

func button(text:String,node_name:String,rect:Rect2,callback:Callable) -> Button:
 var item:=Button.new()
 item.name=node_name;item.text=text;item.position=rect.position;item.size=rect.size
 item.pressed.connect(callback)
 add_child(item)
 return item

func build() -> void:
 if _built:return
 _built=true
 theme=Theme.new();theme.default_font=load(FONT_PATH);theme.default_font_size=20
 theme.set_color("font_color","Button",Color("d7dfcb"))
 for state in ["normal","hover","pressed","focus","disabled"]:
  theme.set_stylebox(state,"Button",surface(Color("304339") if state in ["hover","focus"] else Color("1d2b27"),Color("a8b99b") if state in ["hover","focus"] else Color("607362"),2 if state=="focus" else 1))
 var veil:=ColorRect.new();veil.color=Color(0.035,0.055,0.052,0.76);veil.size=Vector2(1280,720);add_child(veil)
 var paper:=Panel.new();paper.position=Vector2(80,105);paper.size=Vector2(1120,515)
 paper.add_theme_stylebox_override("panel",surface(Color("15231f"),Color("738472"),2));add_child(paper)
 edition=label("NEURONS  /  E1",Rect2(120,130,600,40),18,Color("91a58d"))
 heading=label("宿主胜利",Rect2(120,190,1040,60),40,Color("e0e4ce"))
 explanation=label("结局一 · 幻觉逃脱\n\n广场的出口消退。现实病床上的宿主睁开眼睛。\n本次流程结束。",Rect2(120,275,1010,180),22,Color("c5d0bc"))
 explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label("记录与成就保留。新游戏另建流程，不继承本次背包。",Rect2(120,507,1040,26),16,Color("91a58d"))
 records=ScrollContainer.new();records.position=Vector2(120,240);records.size=Vector2(1040,255)
 records.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 add_child(records)
 record_text=Label.new();record_text.custom_minimum_size.x=1000
 record_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 record_text.add_theme_color_override("font_color",Color("c5d0bc"));record_text.add_theme_font_size_override("font_size",18)
 records.add_child(record_text)
 records_button=button("查看本次记录","EndingRecords",Rect2(120,540,300,50),show_records)
 back_button=button("返回结局","EndingBack",Rect2(120,540,300,50),show_ending)
 button("返回主菜单","EndingTitle",Rect2(440,540,300,50),func():return_to_title_requested.emit())
 button("新游戏","EndingNewGame",Rect2(760,540,300,50),func():new_game_requested.emit())
 show_ending()

func main_ending() -> Dictionary:
 return app.street.data.get("ending",{}) if app!=null and app.street!=null else {}

func sync_from_game() -> void:
 if not _built:build()
 var should_show:bool=app!=null and app.hidden_route!=null and app.hidden_route.data.get("status","")=="ending" and bool(app.hidden_route.data.get("ending",{}).get("complete",false))
 should_show=should_show or bool(main_ending().get("complete",false))
 if should_show and not visible:
  show_ending()
  records_button.grab_focus()
 visible=should_show

func show_ending() -> void:
 showing_records=false
 if not _built:return
 var main:Dictionary=main_ending()
 edition.text="NEURONS  /  "+str(main.get("id","E1"))
 heading.text="玩家胜利" if main.get("id","")=="E3" else "角色胜利" if main.get("id","")=="E2" else "宿主胜利"
 if not main.is_empty():explanation.text="结局三 · 玩家接续身体" if main.id=="E3" else "结局二 · 角色接续身体；玩家在来处星球恢复感知"
 explanation.show();records.hide();records_button.show();back_button.hide()

func show_records() -> void:
 showing_records=true
 heading.text="本次记录"
 record_text.text=records_text()
 records.scroll_vertical=0
 explanation.hide();records.show();records_button.hide();back_button.show()
 back_button.grab_focus()

func records_text() -> String:
 if app==null:return "没有可读取的本次记录。"
 var lines:Array[String]=["结局一 · 幻觉逃脱；宿主胜利。", "生命 %d  /  精神 %d  /  神经元 %d  /  神经簇 %d"%[app.rules.hp,app.rules.sp,app.rules.neurons,app.rules.plexus],"", "已见信息（不把机构宣称当成实际结果）"]
 if app.rules.observations.is_empty():lines.append("本次尚无已见条目。")
 for entry in app.rules.observations:
  lines.append("[%s / %s] %s"%[str(entry.get("category","")),str(entry.get("kind","")),str(entry.get("text",""))])
 if not main_ending().is_empty():
  lines[0]=str(main_ending().id)+" · 机构登记自行离院；不覆盖实际伤亡。"
  for id in app.street.data.actors:
   var actor:Dictionary=app.street.data.actors[id]
   if actor.hp<=0:lines.append("实际退场："+str(app.street.spec(id).name))
 var encounters:Array=app.hidden_route.encounter_record()
 if not encounters.is_empty():
  lines.append("");lines.append("实际遭遇的反馈")
  for encounter in encounters:
   lines.append({"saw":"看见猎手","evaded":"实际躲开扑击","hit":"受到非致命扑击"}.get(str(encounter.event),str(encounter.event))+("（越界前已发生，尚未播放）" if encounter.deferred else ""))
   for line in encounter.lines:lines.append("%s：%s"%[str(line.speaker),str(line.text)])
 return "\n".join(lines)

func _gui_input(event:InputEvent) -> void:
 # Closing a record never forwards an Escape/Enter/click into the frozen world.
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and showing_records:
  show_ending();records_button.grab_focus();accept_event()
