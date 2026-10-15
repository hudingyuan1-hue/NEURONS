extends Control
## Isolated practice. The campaign below stays frozen and untouched.
const Neural=preload("res://scripts/core/neural_rules.gd")
const Menu=preload("res://scripts/ui/campaign_menu.gd")
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
var app
var demo
var terminal
var audio
var catalog=Catalog.new()
var stage:int=0
var clock:float=0.0
var closing:float=0.0
var hover_id:String=""
var hover_left:float=0.0
var manual_paused:bool=false
var hint:Label
var detail:Label
var next:Button
var guide_only:bool=false
var history:Array=[]

func _init(owner) -> void:
 app=owner

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 theme=app.theme
 var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("17282a");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
 # A reused actor atlas in a labelled practice view; no new gameplay room.
 var panel:=Panel.new();panel.position=Vector2(70,110);panel.size=Vector2(1140,430)
 panel.add_theme_stylebox_override("panel",app.panel_style(Color("293b37"),Color("718e7c")));panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
 var art:=Node2D.new();art.set_script(load("res://scripts/ui/menu_art.gd"));art.host=self;art.z_index=1;add_child(art)
 terminal=Menu.new();terminal.z_index=2;terminal.reduced_effects=app.reduced_effects;add_child(terminal)
 terminal.cast_requested.connect(practice_skin)
 terminal.skill_requested.connect(func(_id,_context):terminal._status.text="先按指引练习已开放的操作")
 terminal.close_requested.connect(close_terminal)
 terminal.tree_result.connect(tree_result)
 for id in terminal.nodes:
  terminal.nodes[id].mouse_entered.connect(func():hover_id=id;hover_left=0)
  terminal.nodes[id].mouse_exited.connect(func():hover_id="";hover_left=0)
 audio=Feedback.new();add_child(audio);audio.levels=app.audio.levels.duplicate();audio.refresh_levels()
 var instructions:=Panel.new();instructions.position=Vector2(25,575);instructions.size=Vector2(1230,125);instructions.z_index=10
 instructions.add_theme_stylebox_override("panel",app.panel_style(Color("20322d"),Color("849a83")));add_child(instructions)
 hint=Label.new();hint.position=Vector2(18,10);hint.size=Vector2(1175,30);hint.add_theme_font_size_override("font_size",21);instructions.add_child(hint)
 detail=Label.new();detail.position=Vector2(18,47);detail.size=Vector2(875,68);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",17);instructions.add_child(detail)
 next=button(instructions,"继续",Vector2(910,47),func():
  if guide_only:finish()
  elif stage==6:change_stage(7)
 )
 button(instructions,"跳过练习 / 返回",Vector2(1050,47),finish)
 button(self,"暂停练习",Vector2(1030,42),func():manual_paused=not manual_paused)
 var reset_button:=button(self,"重置练习",Vector2(880,42),reset_practice)
 reset_button.visible=not guide_only
 reset_practice()
 if guide_only:
  stage=99;hint.text="操作详解 · 自主角色与神经干预"
  detail.text="左键身体打开CRT，悬停查看三句说明；右键身体查看前置与解锁升级。菜单/对白冻结世界。基本观察免费，参数扩展5C。"
  if app.rules.skill_states.CONTROL.unlocked:detail.text+="掌控每次5N、最长6秒、结束后20秒冷却；不是持续直接控制。"
  next.visible=true

func button(parent:Node,text:String,pos:Vector2,callback:Callable) -> Button:
 var b:=Button.new();b.position=pos;b.size=Vector2(130,42);b.text=text
 b.add_theme_stylebox_override("normal",app.panel_style(Color("294032"),Color("8a9d7a")))
 b.add_theme_font_size_override("font_size",15);b.pressed.connect(callback);parent.add_child(b);return b

func reset_practice() -> void:
 demo=Neural.new();demo.tutorial_demo=true
 terminal.rules=demo;terminal.close_menu();manual_paused=false;closing=0
 history.clear();change_stage(0)

func change_stage(value:int) -> void:
 stage=value;clock=0;history.append(stage);next.visible=stage==6
 var hints:Dictionary={
  0:["教程练习 · 正式进度保持不动","先观察床边的角色。角色自主行动，玩家通过神经干预影响他。"],
  1:["左键点击角色身体","左键点击角色身体使用Neurons神经元 可以选择一种方式干扰他的行动"],
  2:["悬停发亮的 SKIN 节点","将鼠标悬停到发亮节点处 会在右侧展示详细的能力信息"],
  3:["悬停灰暗的 GUT 节点约2秒","将鼠标悬停到灰暗节点处..."],
  4:["点击发亮的 SKIN 节点","...呃...我还没有这个能力\n咳咳...我们一步步来"],
  5:["观察实际身体反应","收屏完成、世界恢复后才执行反应；练习不会改变正式资源。"],
  6:["身体反馈已经发生","看到了吗 这家伙刚才的样子 哈哈哈哈 当然 我们之后也可以对这家伙使用更多”手段”..."],
  7:["右键点击角色身体","右键点击角色 使用Plexus神经簇获得新能力"],
  8:["转动人体和星环，选择 GUT","点击未发光的一颗星。前置、当前余额与费用都在检查面板中。"],
  9:["确认解锁 GUT · 练习费用1C","这块智能面板展示了这一神经簇的详细信息 我们可以花费...1神经簇解锁 但要注意节制 星仓可不是随时都有产出的"],
  10:["冰柜人体预览 · 不施放到实际角色","解锁和升级只改变对应节点；升级每次1C只加强度。预览不计干预、成长或认知。"],
  11:["关闭冰柜，正式开始","好了 该回去看看这家伙的情况了 有啥问题可以多”看看书”\n练习说明：正式以5N、3C、仅SKIN开始。"]}
 if hints.has(stage):hint.text=hints[stage][0];detail.text=hints[stage][1]

func open_body(button_index:int) -> void:
 if stage==1 and button_index==MOUSE_BUTTON_LEFT:
  terminal.open_menu(demo.neurons,true);change_stage(2)
 elif stage==7 and button_index==MOUSE_BUTTON_RIGHT:
  terminal.open_page("tree");change_stage(8)

func practice_skin() -> void:
 if stage!=4:terminal._status.text="先按指引查看发亮与灰暗节点";return
 var result:Dictionary=demo.submit_skin()
 if result.ok:
  terminal.close_menu();closing=0.18;change_stage(5)

func close_terminal() -> void:
 if stage==10:terminal._status.text="等待人体预览完成；也可直接跳过练习";return
 if stage==11:finish();return
 terminal.close_menu()
 if stage in [2,3,4]:change_stage(1)
 elif stage in [8,9,10]:change_stage(7)

func tree_result(kind:String,id:String,result:Dictionary) -> void:
 if result.get("ok",false) and id=="GUT" and kind=="unlock":
  terminal.preview_left=2.0;change_stage(10)

func finish() -> void:
 set_process(false)
 terminal.set_process(false)
 audio.reset_scene()
 app.profile.tutorial_completed=true
 app.save_requested=true
 app.tutorial_ui=null
 hide();queue_free()

func _process(delta:float) -> void:
 clock+=delta
 if closing>0:closing=maxf(0,closing-delta)
 audio.set_world_paused(manual_paused or terminal.visible or closing>0,manual_paused or terminal.visible)
 if stage==0 and clock>=2:change_stage(1)
 if stage==2 and hover_id=="SKIN":
  hover_left+=delta
  if hover_left>=0.7:change_stage(3)
 if stage==3 and hover_id=="GUT":
  hover_left+=delta
  if hover_left>=2.0:change_stage(4)
 if stage==4 and clock>1.2:detail.text="看到左上角的COIN值了吗 这是我的”财产” 用鼠标点击发光的神经节点 我会让这家伙受到”惩罚”!!! 桀桀桀桀桀~"
 if stage==8 and terminal.selected_id=="GUT":change_stage(9)
 if stage==10 and clock>=2.0:change_stage(11)
 if stage==5 and not manual_paused and not terminal.visible and closing<=0:
  if not demo.pending_neural.is_empty():demo.apply_pending();audio.cue("SFX_SKIN","practice")
  demo.tick(delta)
  if demo.reaction_left<=0 and demo.pending_neural.is_empty():change_stage(6)
 for child in get_children():
  if child is Node2D:child.queue_redraw()

func _gui_input(event:InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and Rect2(605,220,100,200).has_point(event.position):open_body(event.button_index)

func draw_art(canvas:Node2D) -> void:
 if demo==null or terminal==null or terminal.visible:return
 canvas.draw_rect(Rect2(270,275,250,110),Color("879c9d"))
 canvas.draw_rect(Rect2(270,375,250,18),Color("606f70"))
 var pose:String="scratch" if demo.reaction_left>0 else "idle"
 var phase:float=maxf(0,0.5-demo.reaction_left) if pose=="scratch" else clock
 var frame:Dictionary=catalog.actor_frame(pose,Vector2.LEFT,phase)
 var foot:=Vector2(650,400)
 canvas.draw_texture_rect_region(frame.texture,Rect2(foot-frame.foot*2,frame.size*2),frame.source)
 canvas.draw_string(theme.default_font,Vector2(415,485),"独立练习 · 身体与界面均为可替换占位",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c7d7be"))
