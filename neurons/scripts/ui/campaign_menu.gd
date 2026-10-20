extends "res://scripts/ui/neuron_menu.gd"
## Code-drawn campaign UI. No world clock or gameplay mutation in animations.
const BodyPreview=preload("res://scripts/ui/body_preview.gd")
const NarrativeArt=preload("res://scripts/ui/narrative_art.gd")
const EvidenceCards=preload("res://scripts/ui/evidence_cards.gd")
const RigBodyPreview=preload("res://scripts/ui/rig_body_preview.gd")
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
var book_scroll:ScrollContainer
var book_cards:VBoxContainer
var extension_button:Button
var body_angle:int=0
var orbit:float=0.0
var book_category:String="角色"
var selected_direction:Vector2=Vector2.RIGHT
var direction_panel:HBoxContainer
var refund_note:String=""
var cast_pending:Dictionary={}
var full_description:String=""
var description_signature:String=""
var description_clock:float=0.0
var page_clock:float=0.0
var preview_left:float=0.0
var preview_delay:float=0.0
var preview_id:String=""
var crt_language:int=-1
const CRT_LANGUAGES=["C","C++","Java","JavaScript","C#","Go","PHP","Ruby","Swift","Kotlin","Rust","Lua","Python"]
var inspect_panel:Panel
var inspect_return:Button
var inspect_clock:float=0.0
var inspect_closing:float=0.0
var ui_paused:bool=false
var tree_action_filter:Callable
var skill_labels:Dictionary={}
var inventory_provider:Callable
var inventory_labels:Dictionary={}
var inventory_buttons:Dictionary={}
var body_preview

func skill_name(id:String) -> String:
 if rules!=null:return str(rules.spec(id).get("name",id))
 if skill_labels.is_empty():
  var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
  for entry in source.skills:skill_labels[str(entry.id)]=str(entry.name)
 return str(skill_labels.get(id,id))

func _build_ui() -> void:
 if _built:return
 _built=true
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=UIStyle.theme_for()
 var veil:=ColorRect.new()
 veil.size=Vector2(1280,720)
 veil.color=Color("e9e2d2")
 veil.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(veil)
 title=_label(self,"神经终端",Rect2(70,32,700,52),30,INK)
 _coin=_label(self,"",Rect2(790,45,310,34),18,ACCENT)
 _button(self,"关闭 ×",Rect2(1110,39,110,42)).pressed.connect(func():close_requested.emit())
 _status=_label(self,"",Rect2(72,651,1125,46),17,UIStyle.OXIDE)
 for key in ["cast","tree","book","inventory"]:
  var page:=Control.new()
  page.size=Vector2(1280,630)
  page.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(page)
  pages[key]=page
 build_cast()
 build_tree()
 build_book()
 build_inventory()
 art_canvas=Node2D.new()
 art_canvas.set_script(load("res://scripts/ui/menu_art.gd"))
 art_canvas.host=self
 art_canvas.z_index=1
 add_child(art_canvas)

func box(parent:Node,rect:Rect2) -> Panel:
 var p:=Panel.new()
 p.position=rect.position;p.size=rect.size
 p.add_theme_stylebox_override("panel",UIStyle.surface(UIStyle.mode_for(parent)))
 parent.add_child(p)
 return p

func build_cast() -> void:
 var page:Control=pages.cast
 page.set_meta("ui_mode","terminal")
 box(page,Rect2(70,115,590,480))
 box(page,Rect2(685,115,535,480))
 _label(page,"CRT / 神经节点",Rect2(90,132,540,30),17,UIStyle.TERMINAL_DIM)
 _description=_label(page,"",Rect2(710,140,480,360),17,UIStyle.TERMINAL_INK)
 _description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var ids:Array=["SKIN","GUT","PORES","TEMP","TINNITUS","DRYMOUTH","KNEE","WITHDRAW","STARTLE","FEAR","JOY","CONTROL"]
 for i in range(ids.size()):
  var id:String=ids[i]
  var p:=Vector2(110+(i%3)*180,190+(i/3)*87)
  positions[id]=p+Vector2(66,22)
  var b:=_button(page,skill_name(id),Rect2(p,Vector2(132,45)))
  b.name="skill_"+id;b.tooltip_text=id
  b.icon=UIStyle.skill_icon(id);b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
  b.add_theme_constant_override("icon_max_width",25)
  b.add_theme_font_size_override("font_size",17)
  nodes[id]=b
  b.mouse_entered.connect(func():preview_description(id))
  b.mouse_exited.connect(restore_selected_description)
  b.pressed.connect(func():describe(id);_request_cast())
 _skin=nodes.SKIN
 direction_panel=HBoxContainer.new()
 direction_panel.position=Vector2(710,520)
 direction_panel.add_theme_constant_override("separation",10)
 page.add_child(direction_panel)
 for pair in [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]:
  var b:=Button.new()
  b.text=pair[0];b.custom_minimum_size=Vector2(66,42)
  UIStyle.style_button(b,"terminal")
  direction_panel.add_child(b)
  b.pressed.connect(func():selected_direction=pair[1];submit_selected(true))
 var cancel:=Button.new()
 cancel.text="取消方向";cancel.custom_minimum_size=Vector2(135,42)
 UIStyle.style_button(cancel,"terminal")
 direction_panel.add_child(cancel)
 cancel.pressed.connect(func():direction_panel.hide();restore_selected_description();_status.text="已取消；未扣费")
 direction_panel.hide()

func build_tree() -> void:
 var page:Control=pages.tree
 box(page,Rect2(70,115,430,480))
 box(page,Rect2(525,115,440,480))
 inspect_panel=box(page,Rect2(985,115,235,480))
 _label(page,"星仓 / 身体反应",Rect2(90,132,385,30),17,INK)
 _label(page,"螺旋星环 · 连线为实际前置",Rect2(545,132,420,30),16,INK)
 _button(page,"↶ 人体",Rect2(95,531,160,43)).pressed.connect(func():body_angle=(body_angle+3)%4;queue_redraw())
 _button(page,"人体 ↷",Rect2(280,531,160,43)).pressed.connect(func():body_angle=(body_angle+1)%4;queue_redraw())
 _button(page,"↶ 星环",Rect2(550,531,160,43)).pressed.connect(func():orbit-=0.35;layout_tree())
 _button(page,"星环 ↷",Rect2(775,531,160,43)).pressed.connect(func():orbit+=0.35;layout_tree())
 inspect=_label(inspect_panel,"选择节点检查",Rect2(15,22,200,205),16,INK)
 inspect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _button(inspect_panel,"确认解锁",Rect2(15,245,200,40)).pressed.connect(func():tree_action("unlock"))
 _button(inspect_panel,"升级强度 · 1神经簇",Rect2(15,295,200,40)).pressed.connect(func():tree_action("upgrade"))
 inspect_return=_button(inspect_panel,"返回星环",Rect2(15,345,200,40))
 inspect_return.pressed.connect(return_to_tree)
 _button(page,"10神经元 → 1神经簇",Rect2(1000,535,200,40)).pressed.connect(func():tree_action("exchange"))
 _button(page,"应急重连 · 5神经元",Rect2(1000,585,200,40)).pressed.connect(func():tree_action("emergency"))
 for id in positions:
  var b:=_button(page,skill_name(id),Rect2(Vector2.ZERO,Vector2(92,32)))
  b.name="tree_"+id;b.tooltip_text=id
  b.z_index=2
  b.add_theme_font_size_override("font_size",12)
  b.size=Vector2(92,32) # Reapply after font change; old 18px minimum otherwise survives.
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
 extension_button=_button(page,"参数明细 · 5神经簇",Rect2(710,140,470,42))
 extension_button.add_theme_font_size_override("font_size",15)
 extension_button.pressed.connect(func():
  var result:Dictionary=rules.buy_book_extension(rules.book_extension_id(book_category))
  _status.text="参数明细已开启；基本观察始终免费" if result.ok else reason_text(str(result.reason))
  refresh_book();refresh_state()
 )
 book_scroll=ScrollContainer.new()
 book_scroll.position=Vector2(100,205);book_scroll.size=Vector2(1080,350)
 book_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 page.add_child(book_scroll)
 book_cards=VBoxContainer.new();book_cards.custom_minimum_size.x=1040;book_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 book_cards.add_theme_constant_override("separation",14);book_scroll.add_child(book_cards)
 book_text=Label.new()
 book_text.custom_minimum_size.x=1040
 book_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 book_text.add_theme_color_override("font_color",INK)
 book_text.hide();page.add_child(book_text) # Source-equivalent accessible text remains available to existing readers/checks.

func build_inventory() -> void:
 var page:Control=pages.inventory
 box(page,Rect2(70,115,1150,480))
 _label(page,"随身物品",Rect2(100,140,800,32),23,INK)
 _label(page,"实际取得后入库；使用请求关闭窗口，吞服完成后才结算。",Rect2(100,180,1060,35),17,DIM)
 var row:int=0
 for pair in [["porridge","粥"],["candy","糖果"],["chocolate","巧克力"],["gift","门口礼物（尚未取得）"]]:
  var kind:String=pair[0]
  inventory_labels[kind]=_label(page,pair[1],Rect2(110,238+row*72,710,36),20,INK)
  var button:Button=_button(page,"走近拾取" if kind=="gift" else "食用",Rect2(880,232+row*72,280,44))
  button.pressed.connect(func():food_requested.emit(kind))
  inventory_buttons[kind]=button
  row+=1
 _label(page,"未持有或当前身体无法完成时不可使用；查阅本窗口不消耗物品。",Rect2(100,547,1090,32),16,DIM)

func refresh_inventory() -> void:
 var contents:Dictionary=inventory_provider.call() if inventory_provider.is_valid() else {}
 for kind in inventory_labels:
  var entry:Dictionary=contents.get(kind,{})
  var name:String={"porridge":"粥","candy":"糖果","chocolate":"巧克力","gift":"门口礼物（尚未取得）"}[kind]
  inventory_labels[kind].text="%s  × %d"%[name,int(entry.get("count",0))]
  inventory_buttons[kind].disabled=not bool(entry.get("available",false))
  inventory_buttons[kind].tooltip_text=str(entry.get("reason","当前没有可用物品"))

func open_menu(neurons_value:int,can_cast:bool,resistance_test:bool=false) -> void:
 open_page("cast")
 _can_cast=can_cast
 _submitted=false
 _coin.text="神经元 %d"%neurons_value
 _status.text="" if not resistance_test else "抵抗测试场次"

func open_page(key:String) -> void:
 _build_ui()
 panel_mode=key
 if key=="tree":
  if body_preview==null:body_preview=RigBodyPreview.new();add_child(body_preview)
 elif body_preview!=null:body_preview.queue_free();body_preview=null
 cast_pending.clear();page_clock=0.0;_submitted=false
 preview_left=0.0;preview_delay=0.0;preview_id="";inspect_closing=0.0;inspect_clock=0.0
 for id in pages:pages[id].visible=id==key
 visible=true
 _status.text=""
 title.text={"cast":"神经干预 / CRT","tree":"星仓","book":"已见信息档案","inventory":"物品栏"}[key]
 if key=="tree":
  inspect_panel.hide()
  feedback_requested.emit("SFX_COLD")
 elif key=="book":refresh_book()
 elif key=="inventory":refresh_inventory()
 refresh_state()
 if key=="cast":restore_selected_description()
 if art_canvas!=null:art_canvas.queue_redraw()

func refresh_state() -> void:
 if rules==null:return
 _coin.text="神经元 %d   神经簇 %d"%[rules.neurons,rules.plexus]
 for id in nodes:
  var state:Dictionary=rules.skill_states[id]
  nodes[id].modulate=Color.WHITE
  tree_nodes[id].modulate=Color.WHITE
  nodes[id].add_theme_color_override("font_color",UIStyle.TERMINAL_INK if state.unlocked else Color("718574"))
  tree_nodes[id].add_theme_color_override("font_color",INK if state.unlocked else Color("8c9182"))
  var selected:bool=selected_id==id
  nodes[id].add_theme_stylebox_override("normal",UIStyle.button_box("terminal","pressed" if selected else "normal" if state.unlocked else "disabled"))
  tree_nodes[id].add_theme_stylebox_override("normal",UIStyle.button_box("paper","pressed" if selected else "normal" if state.unlocked else "disabled"))

func describe(id:String) -> void:
 # Public explicit selection is also used by the existing rescue prompt.
 selected_id=id
 preview_description(id,true)

func preview_description(id:String,force:bool=false) -> void:
 # Hovering previews a node without changing the player's actual choice.
 # Direction buttons must continue to submit the node the player selected.
 if rules==null:return
 var state:Dictionary=rules.skill_states[id]
 if not state.unlocked:
  _description.text=skill_name(id)+" / 节点未解锁\n\n前置与解锁费用可在星仓查看。\n此节点当前不能施放。"
  _description.visible_characters=-1;full_description="";return
 var reason:String=rules.availability(id,context_provider.call() if context_provider.is_valid() else {})
 var extra:String="强度 %d"%int(state.power)
 if rules.book_extensions.has("book_role_resistance"):extra+="  /  抗性 %d"%(int(state.resistance)+rules.global_resistance)
 var entry:Dictionary=rules.spec(id)
 var signature:String=JSON.stringify([id,rules.mode,reason,extra,entry.cost,entry.cooldown])
 # Re-entering the same description must not hide it behind another typing
 # animation, particularly after a direction submission is refused.
 if not force and signature==description_signature and not full_description.is_empty() and _description.text==full_description:return
 description_signature=signature
 crt_language=randi_range(0,CRT_LANGUAGES.size()-1) # Presentation RNG only; never campaign RNG.
 var fee:String="消耗 %d 神经元  ·  冷却 %s 秒"%[int(entry.cost),str(entry.cooldown)]
 full_description=crt_text(id,crt_language)+"\n\n"+fee+"\n"+extra+"  ·  "+("探索" if rules.mode=="exploration" else "战斗")+"\n"+reason_text(reason)
 _description.text=full_description;_description.visible_characters=0;description_clock=0.0

func restore_selected_description() -> void:
 if visible and panel_mode=="cast":preview_description(selected_id)

func crt_text(id:String,language:int) -> String:
 # Experience P143–276 defines the wrappers. S2:T17 explicitly replaces the old
 # probability wording: preserve its three sentences verbatim for every node.
 var entry:Dictionary=rules.spec(id)
 var lines:Array[String]=[]
 for sentence in str(entry.description).split("。",false):lines.append("###"+sentence+"。")
 var header:String
 var suffix:String=";"
 match language:
  0:header='char* %s = "%s";\nint COIN = %d;'%[id,entry.name,entry.cost]
  1:header='#include <string>\nstd::string %s = "%s";\nint COIN = %d;'%[id,entry.name,entry.cost]
  2:header='String %s = "%s";\nint COIN = %d;'%[id,entry.name,entry.cost]
  3:header='const %s = "%s";\nconst COIN = %d;'%[id,entry.name,entry.cost]
  4:header='string %s = "%s";\nint COIN = %d;'%[id,entry.name,entry.cost]
  5:header='package main\nvar %s string = "%s"\nvar COIN int = %d'%[id,entry.name,entry.cost]
  6:header='$%s = "%s";\n$COIN = %d;'%[id,entry.name,entry.cost]
  _:
   var keyword:String={8:"let ",9:"val ",10:"let "}.get(language,"")
   if language in [7,8,9,11,12]:suffix=""
   header='%s%s = "%s"%s\n%sCOIN = %d%s'%[keyword,id,entry.name,suffix,keyword,entry.cost,suffix]
 var opening:String="/*"
 var ending:String="*/"
 if language==7:opening="=begin";ending="=end"
 elif language==11:opening="--[[";ending="]]"
 elif language==12:opening="";ending=""
 var comment:String="# " if language in [7,12] else ("-- " if language==11 else "// ")
 return comment+str(CRT_LANGUAGES[clampi(language,0,12)])+"\n"+header+"\n"+opening+"\n"+"\n".join(lines)+"\n"+ending

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
 if not reason.is_empty():restore_selected_description();_status.text=reason_text(reason);return
 direction_panel.hide()
 cast_pending={"id":selected_id,"context":context.duplicate(true),"elapsed":0.0}

func close_menu() -> void:
 cast_pending.clear()
 if direction_panel!=null:direction_panel.hide()
 preview_left=0.0;preview_delay=0.0;preview_id="";inspect_closing=0.0
 if body_preview!=null:body_preview.queue_free();body_preview=null
 super.close_menu()

func describe_tree() -> void:
 if rules==null:return
 var entry:Dictionary=rules.spec(selected_id)
 var state:Dictionary=rules.skill_states[selected_id]
 inspect_panel.show();inspect_panel.modulate.a=1.0;inspect_clock=0.0;inspect_closing=0.0
 var prerequisites:Array[String]=[]
 for id in entry.prerequisites:prerequisites.append(skill_name(str(id)))
 inspect.text="%s\n\n前置: %s\n%s\n解锁: %d神经簇\n当前强度: %d"%[entry.name," / ".join(prerequisites) if not prerequisites.is_empty() else "无","初始开放" if prerequisites.is_empty() else "任一满足" if entry.prerequisite_mode=="any" else "全部满足",entry.unlock_cost,state.power]

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
 _status.text="已完成 · %s"%skill_name(selected_id) if result.ok else reason_text(str(result.reason))
 if result.ok and kind in ["unlock","upgrade","emergency"]:refund_note="growth"
 if result.ok and kind in ["unlock","upgrade"]:
  inspect_closing=0.18
  preview_id=selected_id;preview_delay=0.36;preview_left=0.0
 feedback_requested.emit("SFX_UI_REWARD" if result.ok else "SFX_UI_DENIED")
 tree_result.emit(kind,selected_id,result)
 refresh_state();queue_redraw()
 if not result.ok:describe_tree()

func refresh_book() -> void:
 if rules==null:return
 for child in pages.book.get_children():
  if child is Button and child.text in ["人物","物品","角色"]:
   child.add_theme_stylebox_override("normal",UIStyle.button_box("paper","pressed" if child.text==book_category else "normal"))
 var lines:Array[String]=[]
 for child in book_cards.get_children():book_cards.remove_child(child);child.queue_free()
 book_scroll.scroll_vertical=0
 var visible_records:int=0
 for entry in rules.observations:
  if entry.category!=book_category:continue
  lines.append("[%s] %s\n来源：%s\n"%[entry.kind,entry.text,entry.source])
  visible_records+=1
  var portrait:Texture2D=NarrativeArt.portrait(entry) if book_category=="人物" else null
  var photo:Texture2D=NarrativeArt.texture("UI_EVIDENCE_FAMILY_PHOTO") if str(entry.id)=="hospital_family_photo_seen" else null
  EvidenceCards.add(book_cards,str(entry.kind),str(entry.text),str(entry.source),portrait,photo)
 if visible_records==0:EvidenceCards.add(book_cards,"已见信息","尚无已见记录。\n基本观察免费；未知信息不会预先写入。")
 book_text.text="\n".join(lines) if not lines.is_empty() else "尚无已见记录。\n基本观察免费；未知信息不会预先写入。"
 var details:String=rules.book_details(book_category)
 for id in nodes:details=details.replace(str(id),skill_name(str(id)))
 var units:=RegEx.new();units.compile("([0-9]+)N")
 details=units.sub(details,"$1神经元",true);units.compile("([0-9]+)C");details=units.sub(details,"$1神经簇",true)
 if not details.is_empty():
  book_text.text+="\n\n"+details
  EvidenceCards.add(book_cards,"参数明细 / 说明不登记为已发生事实",details)
 extension_button.text="已开启参数明细" if rules.book_extensions.has(rules.book_extension_id(book_category)) else "解锁参数明细 · 5神经簇 (基本观察免费)"

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
 if panel_mode=="tree" and body_preview!=null:body_preview.sample(body_angle,preview_id,preview_left,page_clock,reduced_effects)
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
 var bottom:float=470+15*pow(1.0-opening,3)
 for band in range(12):
  canvas.draw_rect(Rect2(90,bottom+band*2.5,385,2.5),Color("3b626b").lerp(Color("172b42"),band/11.0))
 canvas.draw_polyline(PackedVector2Array([Vector2(92,bottom),Vector2(98,bottom-46*opening),Vector2(470,bottom-46*opening),Vector2(475,bottom)]),Color("9ebfbe"),3)
 if rules!=null:
  for id in tree_positions:
   for parent in rules.spec(id).prerequisites:
    if tree_positions.has(parent):canvas.draw_line(tree_positions[id],tree_positions[parent],Color("56745f"),1)
 var drawn:bool=body_preview!=null and body_preview.draw(canvas,Vector2(285,470),260)
 if not drawn:canvas.draw_string(theme.default_font,Vector2(126,324),"主角四向预览校准中",HORIZONTAL_ALIGNMENT_LEFT,-1,18,DIM)
 if drawn and (preview_delay>0 or preview_left>0):
  canvas.draw_string(theme.default_font,Vector2(95,184),"%s / 身体反应预览"%skill_name(preview_id),HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)
 if inspect_closing>0:
  var hit:Vector2=inspect_panel.position+Vector2(-8,150)
  canvas.draw_line(hit+Vector2(-65,-40*inspect_closing/0.18),hit,Color("c7b79a"),5)
  canvas.draw_rect(Rect2(hit-Vector2(12,5),Vector2(24,10)),Color("91b4ad"))
 if not reduced_effects:
  for i in range(5):
   var x:float=112+i*75
   var y:float=480-fmod(_phase*28+i*31,250)
   canvas.draw_arc(Vector2(x,y),17,0,PI,10,Color(0.6,0.8,0.8,0.15),2)
