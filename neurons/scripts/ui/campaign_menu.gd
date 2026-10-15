extends "res://scripts/ui/neuron_menu.gd"
## Code-drawn campaign UI. No world clock or gameplay mutation in animations.
const BodyPreview=preload("res://scripts/ui/body_preview.gd")
signal skill_requested(id:String,context:Dictionary)
signal food_requested(kind:String)
signal tree_result(kind:String,id:String,result:Dictionary)
signal feedback_requested(id:String)
var rules
var context_provider:Callable
var art_canvas:Node2D
var panel_mode:String="cast"
var selected_id:String="SKIN"
var pages:Dictionary={}
var nodes:Dictionary={}
var tree_nodes:Dictionary={}
var positions:Dictionary={}
var tree_positions:Dictionary={}
var title:Label
var inspect:Label
var tree_status:Label
var book_text:Label
var extension_button:Button
var body_angle:int=0
var orbit:float=0.0
var book_category:String="角色"
var selected_direction:Vector2=Vector2.RIGHT
var direction_panel:HBoxContainer
var refund_note:String=""
var cast_pending:Dictionary={}
var full_description:String=""
var description_clock:float=0.0
var page_clock:float=0.0
var preview_left:float=0.0
var preview_delay:float=0.0
var inspect_panel:Panel
var inspect_return:Button
var inspect_clock:float=0.0
var inspect_closing:float=0.0
var ui_paused:bool=false
var tree_action_filter:Callable

func _build_ui() -> void:
 if _built:return
 _built=true
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=Theme.new()
 theme.default_font=load(FONT_PATH)
 theme.default_font_size=18
 for state_name in ["normal","hover","pressed","disabled","focus"]:
  theme.set_stylebox(state_name,"Button",_box(Color("29402f") if state_name=="hover" else Color("1c3027"),ACCENT if state_name in ["hover","focus"] else DIM,1))
 var veil:=ColorRect.new()
 veil.size=Vector2(1280,720)
 veil.color=Color(0.025,0.045,0.045,0.94)
 veil.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(veil)
 title=_label(self,"NEURONS / 神经终端",Rect2(70,32,800,52),29,INK)
 _coin=_label(self,"",Rect2(850,45,250,34),20,ACCENT)
 _button(self,"CLOSE ×",Rect2(1110,39,110,42)).pressed.connect(func():close_requested.emit())
 _status=_label(self,"",Rect2(72,651,1125,46),17,Color("d1bd8d"))
 for key in ["cast","tree","book"]:
  var page:=Control.new()
  page.size=Vector2(1280,630)
  page.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(page)
  pages[key]=page
 build_cast()
 build_tree()
 build_book()
 art_canvas=Node2D.new()
 art_canvas.set_script(load("res://scripts/ui/menu_art.gd"))
 art_canvas.host=self
 art_canvas.z_index=1
 add_child(art_canvas)

func box(parent:Node,rect:Rect2) -> Panel:
 var p:=Panel.new()
 p.position=rect.position;p.size=rect.size
 p.add_theme_stylebox_override("panel",_box(Color("172a25"),Color("627762"),2))
 parent.add_child(p)
 return p

func build_cast() -> void:
 var page:Control=pages.cast
 box(page,Rect2(70,115,590,480))
 box(page,Rect2(685,115,535,480))
 _label(page,"CRT  /  已解锁节点",Rect2(90,132,540,30),18,DIM)
 _description=_label(page,"",Rect2(710,140,480,360),18,INK)
 _description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var ids:Array=["SKIN","GUT","PORES","TEMP","TINNITUS","DRYMOUTH","KNEE","WITHDRAW","STARTLE","FEAR","JOY","CONTROL"]
 for i in range(ids.size()):
  var id:String=ids[i]
  var p:=Vector2(110+(i%3)*180,190+(i/3)*87)
  positions[id]=p+Vector2(66,22)
  var b:=_button(page,id,Rect2(p,Vector2(132,45)))
  nodes[id]=b
  b.mouse_entered.connect(func():describe(id))
  b.mouse_exited.connect(func():_description.text="";full_description="")
  b.pressed.connect(func():selected_id=id;_request_cast())
 _skin=nodes.SKIN
 direction_panel=HBoxContainer.new()
 direction_panel.position=Vector2(710,520)
 direction_panel.add_theme_constant_override("separation",10)
 page.add_child(direction_panel)
 for pair in [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]:
  var b:=Button.new()
  b.text=pair[0];b.custom_minimum_size=Vector2(66,42)
  b.add_theme_stylebox_override("normal",_box(Color("29402d"),ACCENT,1))
  direction_panel.add_child(b)
  b.pressed.connect(func():selected_direction=pair[1];submit_selected(true))
 var cancel:=Button.new()
 cancel.text="取消方向";cancel.custom_minimum_size=Vector2(135,42)
 direction_panel.add_child(cancel)
 cancel.pressed.connect(func():direction_panel.hide();_status.text="已取消；未扣费")
 direction_panel.hide()

func build_tree() -> void:
 var page:Control=pages.tree
 box(page,Rect2(70,115,430,480))
 box(page,Rect2(525,115,440,480))
 inspect_panel=box(page,Rect2(985,115,235,480))
 _label(page,"CRYO / 二维人体比例占位",Rect2(90,132,400,30),17,INK)
 _label(page,"螺旋星环 · 连线为实际前置",Rect2(545,132,420,30),16,INK)
 _button(page,"↶ 人体",Rect2(95,531,160,43)).pressed.connect(func():body_angle=(body_angle+3)%4;queue_redraw())
 _button(page,"人体 ↷",Rect2(280,531,160,43)).pressed.connect(func():body_angle=(body_angle+1)%4;queue_redraw())
 _button(page,"↶ 星环",Rect2(550,531,160,43)).pressed.connect(func():orbit-=0.35;layout_tree())
 _button(page,"星环 ↷",Rect2(775,531,160,43)).pressed.connect(func():orbit+=0.35;layout_tree())
 inspect=_label(inspect_panel,"选择节点检查",Rect2(15,22,200,205),16,INK)
 inspect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _button(inspect_panel,"确认解锁",Rect2(15,245,200,40)).pressed.connect(func():tree_action("unlock"))
 _button(inspect_panel,"升级强度 · 1C",Rect2(15,295,200,40)).pressed.connect(func():tree_action("upgrade"))
 inspect_return=_button(inspect_panel,"返回星环",Rect2(15,345,200,40))
 inspect_return.pressed.connect(return_to_tree)
 _button(page,"10N → 1C",Rect2(1000,535,200,40)).pressed.connect(func():tree_action("exchange"))
 _button(page,"应急重连 · 5N",Rect2(1000,585,200,40)).pressed.connect(func():tree_action("emergency"))
 for id in positions:
  var b:=_button(page,id,Rect2(Vector2.ZERO,Vector2(92,32)))
  b.z_index=2
  b.add_theme_font_size_override("font_size",12)
  tree_nodes[id]=b
  b.pressed.connect(func():
   if inspect_closing>0:return
   selected_id=id;describe_tree()
  )
 layout_tree()

func layout_tree() -> void:
 var i:int=0
 for id in tree_nodes:
  var angle:float=orbit+i*TAU/5.7
  var radius:float=116+i*1.0
  var p:=Vector2(745,445-i*22)+Vector2(cos(angle)*radius,sin(angle)*radius*0.24)
  tree_positions[id]=p
  tree_nodes[id].position=p-Vector2(46,16)
  i+=1
 # Keep labels readable while the projected spiral rotates. This is UI-only.
 for iteration in range(40):
  for a in tree_positions:
   for b in tree_positions:
    if a>=b:continue
    var delta:Vector2=tree_positions[b]-tree_positions[a]
    var dx:float=96-absf(delta.x)
    var dy:float=39-absf(delta.y)
    if dx>0 and dy>0:
     var push:Vector2=Vector2(signf(delta.x) if delta.x!=0 else 1,0)*dx*0.51 if dx<dy else Vector2(0,signf(delta.y) if delta.y!=0 else 1)*dy*0.51
     tree_positions[a]-=push;tree_positions[b]+=push
   tree_positions[a]=Vector2(clampf(tree_positions[a].x,579,911),clampf(tree_positions[a].y,195,498))
 for id in tree_nodes:tree_nodes[id].position=tree_positions[id]-Vector2(46,16)
 queue_redraw()

func build_book() -> void:
 var page:Control=pages.book
 box(page,Rect2(70,115,1150,480))
 for i in range(3):
  var category:String=["人物","物品","角色"][i]
  _button(page,category,Rect2(100+i*200,140,180,42)).pressed.connect(func():book_category=category;refresh_book())
 extension_button=_button(page,"参数明细 · 5C",Rect2(750,140,430,42))
 extension_button.pressed.connect(func():
  var result:Dictionary=rules.buy_book_extension(rules.book_extension_id(book_category))
  _status.text="参数明细已开启；基本观察始终免费" if result.ok else reason_text(str(result.reason))
  refresh_book();refresh_state()
 )
 var scroll:=ScrollContainer.new()
 scroll.position=Vector2(100,205);scroll.size=Vector2(1080,325)
 page.add_child(scroll)
 book_text=Label.new()
 book_text.custom_minimum_size.x=1040
 book_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 book_text.add_theme_color_override("font_color",INK)
 scroll.add_child(book_text)
 var index:int=0
 for pair in [["porridge","食用粥"],["candy","食用糖果"],["chocolate","食用巧克力"],["gift","拾取门口礼物"]]:
  var kind:String=pair[0]
  _button(page,pair[1],Rect2(100+index*265,540,245,40)).pressed.connect(func():food_requested.emit(kind))
  index+=1

func open_menu(neurons_value:int,can_cast:bool,resistance_test:bool=false) -> void:
 open_page("cast")
 _can_cast=can_cast
 _submitted=false
 _coin.text="COIN  %d N"%neurons_value
 _status.text="" if not resistance_test else "抵抗测试场次"
 _description.text="";full_description=""

func open_page(key:String) -> void:
 _build_ui()
 panel_mode=key
 cast_pending.clear();page_clock=0.0;_submitted=false
 preview_left=0.0;preview_delay=0.0;inspect_closing=0.0;inspect_clock=0.0
 for id in pages:pages[id].visible=id==key
 visible=true
 _status.text=""
 title.text={"cast":"NEURONS / CRT 神经干预","tree":"NEURONS / CRYO 冰柜与星环","book":"NEURONS / 已见信息档案"}[key]
 if key=="tree":
  inspect_panel.hide()
  feedback_requested.emit("SFX_COLD")
 elif key=="book":refresh_book()
 refresh_state()
 if art_canvas!=null:art_canvas.queue_redraw()

func refresh_state() -> void:
 if rules==null:return
 _coin.text="COIN  %d N    %d C"%[rules.neurons,rules.plexus]
 for id in nodes:
  var state:Dictionary=rules.skill_states[id]
  nodes[id].modulate=Color.WHITE if state.unlocked else Color("5a695e")
  tree_nodes[id].modulate=Color("d2e5bf") if state.unlocked else Color("758b86")

func describe(id:String) -> void:
 selected_id=id
 if rules==null:return
 var entry:Dictionary=rules.spec(id)
 var state:Dictionary=rules.skill_states[id]
 var reason:String=rules.availability(id,context_provider.call() if context_provider.is_valid() else {})
 var detail:String=str(entry.exploration_description if rules.mode=="exploration" else entry.combat_description)
 var extra:String="强度 %d"%int(state.power)
 if rules.book_extensions.has("book_role_resistance"):extra+="  /  抗性 %d"%(int(state.resistance)+rules.global_resistance)
 _description.text="%s · %s\n{\n  %s\n}\n\n%s\n%s"%[id,entry.name,detail.replace("。","。\n  "),extra,reason_text(reason)]
 full_description=_description.text
 var style:int=randi_range(0,2) # UI RNG, independent of saved campaign RNG.
 if style==1:full_description=full_description.replace("{","def response():").replace("}","return result")
 elif style==2:full_description=full_description.replace("{","BEGIN NODE").replace("}","END NODE;")
 _description.text=full_description;_description.visible_characters=0;description_clock=0.0

func reason_text(reason:String) -> String:
 if reason=="recognition_lock":return "角色正在抵制干预；完成一次自主行动后恢复"
 if reason=="not_observed":return "该类信息尚未实际观察到"
 return {"":"可提交","locked":"节点未解锁","cooldown":"冷却尚未结束","control_active":"掌控中不可并发","insufficient_neurons":"神经元余额不足","insufficient_clusters":"神经簇余额不足","body_unavailable":"身体当前不可执行","pending":"已有待执行干预","effect_active":"效果持续中","direction_required":"请选择方向","prerequisites":"前置未满足","already_unlocked":"已经解锁","no_perceived_threat":"尚未感知威胁","invalid_target":"目标无效","unavailable":"当前不可执行","action_active":"动作尚未结束"}.get(reason,reason)

func _request_cast() -> void:
 if rules==null or not cast_pending.is_empty():return
 if selected_id=="SKIN" and rules.mode=="exploration":
  if not rules.availability("SKIN").is_empty():
   _status.text=reason_text(rules.availability("SKIN"));return
  cast_pending={"id":"SKIN","context":{},"elapsed":0.0}
  return
 if selected_id=="SKIN" and rules.mode=="combat":
  direction_panel.show();_status.text="选择实际位移方向；取消不扣费";return
 submit_selected(false)

func submit_selected(with_direction:bool) -> void:
 var context:Dictionary=context_provider.call() if context_provider.is_valid() else {}
 if with_direction:context.direction=[selected_direction.x,selected_direction.y]
 var reason:String=rules.availability(selected_id,context)
 if not reason.is_empty():_status.text=reason_text(reason);return
 direction_panel.hide()
 cast_pending={"id":selected_id,"context":context.duplicate(true),"elapsed":0.0}

func close_menu() -> void:
 cast_pending.clear()
 if direction_panel!=null:direction_panel.hide()
 preview_left=0.0;preview_delay=0.0;inspect_closing=0.0
 super.close_menu()

func describe_tree() -> void:
 if rules==null:return
 var entry:Dictionary=rules.spec(selected_id)
 var state:Dictionary=rules.skill_states[selected_id]
 inspect_panel.show();inspect_panel.modulate.a=1.0;inspect_clock=0.0;inspect_closing=0.0
 inspect.text="%s · %s\n\n前置：%s\n%s\n解锁 %dC\n当前强度 %d"%[selected_id,entry.name," / ".join(entry.prerequisites),"任一满足" if entry.prerequisite_mode=="any" else "全部满足",entry.unlock_cost,state.power]

func return_to_tree() -> void:
 if inspect_closing>0:return
 inspect_closing=0.18
 feedback_requested.emit("SFX_UI_BACK")

func tree_action(kind:String) -> void:
 if rules==null:return
 if tree_action_filter.is_valid() and not tree_action_filter.call(kind,selected_id):
  _status.text="先按教程完成当前步骤；没有扣费"
  return
 if inspect_closing>0:return
 var result:Dictionary
 match kind:
  "unlock":result=rules.unlock(selected_id)
  "upgrade":result=rules.upgrade(selected_id)
  "exchange":result=rules.exchange()
  _:result=rules.emergency_reconnect()
 _status.text="已完成 · %s"%selected_id if result.ok else reason_text(str(result.reason))
 if result.ok and kind in ["unlock","upgrade","emergency"]:refund_note="growth"
 if result.ok and kind in ["unlock","upgrade"]:
  inspect_closing=0.18
  if selected_id=="GUT":preview_delay=0.36
 feedback_requested.emit("SFX_UI_CONFIRM" if result.ok else "SFX_UI_DENIED")
 tree_result.emit(kind,selected_id,result)
 refresh_state();queue_redraw()
 if not result.ok:describe_tree()

func refresh_book() -> void:
 if rules==null:return
 var lines:Array[String]=[]
 for entry in rules.observations:
  if entry.category==book_category:lines.append("[%s] %s\n来源：%s\n"%[entry.kind,entry.text,entry.source])
 book_text.text="\n".join(lines) if not lines.is_empty() else "尚无已见记录。\n基本观察免费；未知信息不会预先写入。"
 var details:String=rules.book_details(book_category)
 if not details.is_empty():book_text.text+="\n\n"+details
 extension_button.text="已开启参数明细" if rules.book_extensions.has(rules.book_extension_id(book_category)) else "解锁参数明细 · 5C（基本观察免费）"

func _process(delta:float) -> void:
 if not visible or ui_paused:return
 _phase+=delta
 page_clock+=delta
 inspect_clock+=delta
 if inspect_panel.visible:
  var slide:float=clampf(inspect_clock/0.18,0,1)
  inspect_panel.position.x=lerpf(1235.0,985.0,1.0-pow(1.0-slide,3))
 if inspect_closing>0:
  inspect_closing=maxf(0.0,inspect_closing-delta)
  inspect_panel.position.x=985.0-(1.0-inspect_closing/0.18)*260
  inspect_panel.modulate.a=inspect_closing/0.18
  if inspect_closing<=0:inspect_panel.hide();inspect_panel.modulate.a=1.0
 if preview_delay>0:
  preview_delay=maxf(0.0,preview_delay-delta)
  if preview_delay<=0:preview_left=2.0
 else:preview_left=maxf(0.0,preview_left-delta)
 if not full_description.is_empty():
  description_clock+=delta
  _description.visible_characters=mini(full_description.length(),int(description_clock*220))
 if not cast_pending.is_empty():
  cast_pending.elapsed+=delta
  if float(cast_pending.elapsed)>=0.12:
   var intent:Dictionary=cast_pending.duplicate(true)
   cast_pending.clear()
   if intent.id=="SKIN" and rules.mode=="exploration":cast_requested.emit()
   else:skill_requested.emit(str(intent.id),intent.context)
 refresh_state()
 if art_canvas!=null:art_canvas.queue_redraw()

func draw_art(canvas:Node2D) -> void:
 if not visible:return
 if panel_mode=="cast" and not reduced_effects:
  for y in range(170,590,4):canvas.draw_line(Vector2(76,y),Vector2(654,y),Color(0.01,0.03,0.02,0.16),1)
 if panel_mode=="cast" and not cast_pending.is_empty():
  var p:Vector2=positions[cast_pending.id]
  var amount:float=clampf(float(cast_pending.elapsed)/0.12,0,1)
  canvas.draw_circle(p+Vector2(-45,-25),14,Color("91b4ad"))
  canvas.draw_circle(p+Vector2(-49,-27),2,Color("23342e"));canvas.draw_circle(p+Vector2(-41,-27),2,Color("23342e"))
  var head:Vector2=p+Vector2(0,-28*(1-amount))
  canvas.draw_line(p+Vector2(-32,-24),head,Color("c7b79a"),4)
  canvas.draw_rect(Rect2(head-Vector2(12,4),Vector2(24,8)),Color("879b92"))
 if panel_mode!="tree":return
 var opening:float=clampf(page_clock/0.45,0,1)
 var bottom:float=495+70*pow(1.0-opening,3)
 for band in range(12):
  canvas.draw_rect(Rect2(90,bottom+band*2.5,385,2.5),Color("3b626b").lerp(Color("172b42"),band/11.0))
 canvas.draw_polyline(PackedVector2Array([Vector2(92,bottom),Vector2(98,bottom-46*opening),Vector2(470,bottom-46*opening),Vector2(475,bottom)]),Color("9ebfbe"),3)
 if rules!=null:
  for id in tree_positions:
   for parent in rules.spec(id).prerequisites:
    if tree_positions.has(parent):canvas.draw_line(tree_positions[id],tree_positions[parent],Color("56745f"),1)
 BodyPreview.draw(canvas,body_angle,page_clock,preview_left)
 if inspect_closing>0:
  var hit:Vector2=inspect_panel.position+Vector2(-8,150)
  canvas.draw_line(hit+Vector2(-65,-40*inspect_closing/0.18),hit,Color("c7b79a"),5)
  canvas.draw_rect(Rect2(hit-Vector2(12,5),Vector2(24,10)),Color("91b4ad"))
 if not reduced_effects:
  for i in range(5):
   var x:float=112+i*75
   var y:float=480-fmod(_phase*28+i*31,250)
   canvas.draw_arc(Vector2(x,y),17,0,PI,10,Color(0.6,0.8,0.8,0.15),2)
