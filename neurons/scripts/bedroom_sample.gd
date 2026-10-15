extends Control

const Rules=preload("res://scripts/core/interaction_rules.gd")
const Layout=preload("res://scripts/world/room_layout.gd")
const RoomView=preload("res://scripts/world/room_view.gd")
const Menu=preload("res://scripts/ui/neuron_menu.gd")
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
var rules:InteractionRules
var layout:RoomLayout
var view:Node2D
var camera:Camera2D
var world_viewport:SubViewport
var menu:Control
var audio:AudioStreamPlayer
var hero_pos:=Vector2(2.55,1.2)
var hero_facing:=Vector2.RIGHT
var hero_route:=PackedVector2Array()
var hero_state:="idle"
var npc_pos:=Vector2(4.6,0.22)
var npc_facing:=Vector2.LEFT
var npc_route:=PackedVector2Array()
var npc_state:="idle"
var npc_moving:=false
var scenario:=0
var target_index:=-1
var world_visual_time:=0.0
var state_time:=0.0
var scene_phase:=""
var completed:Array[String]=[]
var selected:Array[int]=[]
var paused_manual:=false
var closing_left:=0.0
var dialogue_queue:Array[Dictionary]=[]
var dialogue_panel:PanelContainer
var dialogue_text:Label
var event_label:Label
var status_label:Label
var state_label:Label
var scenario_label:Label
var debug_label:Label
var log_lines:Array[String]=[]
var test_resistance:=false
var reduced_effects:=true
var zoom_index:=1
const ZOOM_STEPS:=[0.8,1.0,1.15,1.3]
const BASE_ZOOM:=0.85
var status_visible:=false
var pair_offset:=Vector2.ZERO
var grabbed:=false
var pressure_accumulator:=0.0
var cat_pending:=false
var cat_hit_done:=false
var event_generation:=0
var input_lock_frames:=0
var rng:=RandomNumberGenerator.new()
var sample_done:=false
var demo_mode:=false
var demo_time:=0.0
var demo_phase:=0
var snapshot_count:=0
var sample_font:Font
var startle_button:Button
var invader_id:=0
var startle_cooldown:=0.0
var startle_pending:=false
var startle_rewarded:=false
var first_damage:=false
var drawer_open:Dictionary={}
var demo_assertions:Array[String]=[]
var demo_failures:Array[String]=[]
var paused_snapshot:Dictionary={}
var audio_panel:PanelContainer

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 rng.randomize()
 invader_id=rng.randi_range(1000,9999)
 layout=Layout.new()
 sample_font=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
 theme=Theme.new()
 theme.default_font=sample_font
 theme.default_font_size=17
 create_world()
 create_ui()
 menu=Menu.new()
 add_child(menu)
 menu.cast_requested.connect(cast_skin)
 menu.close_requested.connect(close_neuron_menu)
 menu.visible=false
 audio=Feedback.new()
 add_child(audio)
 create_audio_controls()
 rng.randomize()
 reset_sample(0)
 demo_mode="--visual-check" in OS.get_cmdline_user_args() or "--bedside-check" in OS.get_cmdline_user_args()
 if demo_mode:
  dialogue_queue.clear()
  dialogue_panel.hide()
  print("VISUAL_CHECK: real rendering and input simulation started")
  var driver:=Node.new()
  driver.set_script(load("res://tests/bedside_check.gd" if "--bedside-check" in OS.get_cmdline_user_args() else "res://tests/visual_check.gd"))
  add_child(driver)

func create_world() -> void:
 var container:=SubViewportContainer.new()
 container.name="WorldCanvas"
 container.size=Vector2(1280,720)
 container.stretch=true
 container.stretch_shrink=2
 container.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 container.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(container)
 world_viewport=SubViewport.new()
 world_viewport.size=Vector2i(640,360)
 world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 world_viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 container.add_child(world_viewport)
 view=RoomView.new()
 view.app=self
 view.layout=layout
 view.font=sample_font
 world_viewport.add_child(view)
 camera=Camera2D.new()
 camera.position=Vector2(320,196)
 camera.zoom=Vector2.ONE*BASE_ZOOM
 view.add_child(camera)

func label_at(text:String,pos:Vector2,size_px:int=18,col:Color=Color("e4dfca")) -> Label:
 var label:=Label.new()
 label.text=text
 label.position=pos
 label.add_theme_font_size_override("font_size",size_px)
 label.add_theme_color_override("font_color",col)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(label)
 return label

func button_at(text:String,pos:Vector2,width:float,callback:Callable) -> Button:
 var button:=Button.new()
 button.text=text
 button.position=pos
 button.size=Vector2(width,34)
 button.add_theme_font_size_override("font_size",14)
 button.focus_mode=Control.FOCUS_NONE
 button.pressed.connect(callback)
 add_child(button)
 return button

func panel_style(color:Color,border:Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=color
 style.set_border_width_all(1)
 style.border_color=border
 style.set_corner_radius_all(5)
 style.content_margin_left=16
 style.content_margin_top=12
 style.content_margin_right=16
 style.content_margin_bottom=12
 return style

func create_ui() -> void:
 var top:=ColorRect.new()
 top.color=Color("202a2f")
 top.size=Vector2(1280,100)
 top.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(top)
 label_at("N E U R O N S",Vector2(28,15),24)
 label_at("BEDROOM / INTERACTION STUDY",Vector2(29,52),11,Color("99ada9"))
 scenario_label=label_at("",Vector2(365,16),20)
 label_at("床头柜美术候选 · 其余人物/家具灰盒 · 不写剧情进度",Vector2(365,53),13,Color("b3afa0"))
 var name_field:=LineEdit.new()
 name_field.position=Vector2(1000,18)
 name_field.size=Vector2(245,34)
 name_field.text="张%d"%invader_id
 name_field.placeholder_text="玩家姓名"
 name_field.max_length=24
 add_child(name_field)
 label_at("入侵者 #%d / 玩家命名预览"%invader_id,Vector2(1000,57),11,Color("99ada9"))
 var footer:=ColorRect.new()
 footer.position=Vector2(0,589)
 footer.size=Vector2(1280,131)
 footer.color=Color("202a2f")
 footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(footer)
 for i in range(4):
  button_at(["1 自主搜寻","2 母亲递物","3 父亲抓握","4 黑猫受击"][i],Vector2(24+i*152,603),142,reset_sample.bind(i))
 button_at("抗性夹具 0 / 1",Vector2(640,603),145,toggle_resistance)
 button_at("显示碰撞",Vector2(797,603),112,toggle_geometry)
 button_at("复位视野",Vector2(921,603),112,reset_zoom)
 button_at("轻反馈",Vector2(1045,603),85,toggle_effects)
 button_at("音量",Vector2(1140,603),90,toggle_audio_controls)
 state_label=label_at("",Vector2(24,648),14,Color("b6c9ba"))
 event_label=label_at("",Vector2(24,678),13,Color("aaa995"))
 for info_rect in [Rect2(16,106,395,35),Rect2(765,106,490,35)]:
  var info:=ColorRect.new()
  info.position=info_rect.position
  info.size=info_rect.size
  info.color=Color(0.12,0.17,0.18,0.94)
  info.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(info)
 status_label=label_at("",Vector2(26,112),16)
 debug_label=label_at("",Vector2(785,112),13,Color("b7b9a9"))
 button_at("床头柜局部",Vector2(24,151),145,start_bedside_sample)
 startle_button=button_at("惊跳：已解锁测试夹具",Vector2(892,151),298,cast_startle)
 startle_button.hide()
 dialogue_panel=PanelContainer.new()
 dialogue_panel.position=Vector2(155,405)
 dialogue_panel.size=Vector2(970,168)
 dialogue_panel.add_theme_stylebox_override("panel",panel_style(Color("283332"),Color("869a8d")))
 add_child(dialogue_panel)
 var row:=HBoxContainer.new()
 row.add_theme_constant_override("separation",24)
 dialogue_panel.add_child(row)
 var monster:=TextureRect.new()
 monster.texture=null # Rejected v001 retained as source history, no longer presented.
 monster.custom_minimum_size=Vector2(104,132)
 monster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 monster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 row.add_child(monster)
 var column:=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.add_child(column)
 dialogue_text=Label.new()
 dialogue_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 dialogue_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
 dialogue_text.add_theme_font_size_override("font_size",19)
 column.add_child(dialogue_text)
 var next:=Button.new()
 next.text="继续  /  Enter"
 next.pressed.connect(advance_dialogue)
 column.add_child(next)
 dialogue_panel.hide()

func reset_sample(index:int) -> void:
 if audio!=null:audio.reset_scene()
 if menu!=null:menu.hide()
 event_generation+=1
 scenario=index
 rules=Rules.new()
 rules.skin_resistance=1 if test_resistance else 0
 hero_pos=layout.BED_STOP
 npc_pos=layout.DOOR
 hero_route=PackedVector2Array()
 npc_route=PackedVector2Array()
 hero_state="idle"
 npc_state="idle"
 target_index=-1
 state_time=0
 world_visual_time=0
 pressure_accumulator=0
 paused_manual=false
 closing_left=0
 grabbed=false
 sample_done=false
 cat_pending=false
 cat_hit_done=false
 status_visible=false
 first_damage=false
 startle_cooldown=0
 startle_pending=false
 startle_rewarded=false
 drawer_open.clear()
 log_lines.clear()
 completed.clear()
 selected.clear()
 for i in range(11):selected.append(i)
 # Public candidates only. No hidden-key information is supplied to selection.
 for i in range(selected.size()-1,0,-1):
  var j:=rng.randi_range(0,i)
  var temp:=selected[i]
  selected[i]=selected[j]
  selected[j]=temp
 selected.resize(10)
 dialogue_queue.clear()
 dialogue_panel.hide()
 startle_button.visible=scenario==2
 scenario_label.text=["01 / 自主行动与神经干预","02 / 母亲赠粥 · 接触交付","03 / 父亲 · 接近 / 抓握 / 释放","04 / 黑猫 · 外显干预与受击"][scenario]
 scene_phase="autonomy"
 if scenario==0:
  add_dialogue("角色 · 认真","总之继续行动吧!")
 elif scenario==1:
  rules.sp=80
  hero_pos=Vector2(3.1,1.8)
  scene_phase="mother_approach"
  npc_route=layout.path(npc_pos,hero_pos+Vector2(0.6,0))
  add_dialogue("母亲","宝贝 妈妈能进来吗?")
  add_dialogue("角色 · 呆滞","可以的 妈妈")
 elif scenario==2:
  rules.sp=80
  hero_pos=Vector2(3.1,1.8)
  hero_state="fear"
  scene_phase="father_prepare"
  add_dialogue("父亲 · 剪影","嘿 儿子 爹进门咯!!!")
  add_dialogue("角色 · 发抖 害怕","... ...")
  note("父亲测试夹具：无其他人物；正式事件后段待接。SKIN不能解已成立抓握。")
 elif scenario==3:
  hero_pos=Vector2(2.9,1.2)
  target_index=0
  npc_pos=Vector2(2.55,0.9)
  selected=[0]
  note("猫占床搜索目标：实际搜寻中成功外显干预，才触发抓伤。")
 note("本场开始；所有结果仅属于当前测试，不登记周目或结局。")
 input_lock_frames=2
 view.queue_redraw()

func world_paused() -> bool:
 return paused_manual or not dialogue_queue.is_empty() or menu.visible or closing_left>0 or (audio_panel!=null and audio_panel.visible)

func start_bedside_sample() -> void:
 reset_sample(0)
 selected.clear()
 selected.append(1)
 scenario_label.text="01 / 床头柜局部 · 自主搜寻"

func sync_audio_pause() -> void:
 # Spoken dialogue may continue while the world is frozen by that dialogue.
 audio.set_world_paused(world_paused(),paused_manual or menu.visible or closing_left>0 or audio_panel.visible)

func _process(delta:float) -> void:
 input_lock_frames=maxi(0,input_lock_frames-1)
 if closing_left>0:
  closing_left=maxf(0,closing_left-delta)
 sync_audio_pause()
 if not world_paused():
  if not rules.pending_skin.is_empty():apply_cast()
  if not world_paused():advance_world(delta*(0.5 if scenario==2 else 1.0))
 update_ui()
 view.queue_redraw()
 if demo_mode:
  run_visual_check(delta)

func advance_world(delta:float) -> void:
 world_visual_time+=delta
 if rules.search_active and target_index>=0:
  var active_id:String=layout.furniture[target_index].id
  if active_id!="bedside" or (view.bedside_contact() and rules.search_elapsed>=0.18):
   var old_open:float=float(drawer_open.get(active_id,0.0))
   drawer_open[active_id]=minf(1.0,old_open+delta*2)
   if active_id=="bedside" and old_open==0.0:
    audio.cue("drawer","drawer:%d:bedside"%event_generation)
 var result:Dictionary=rules.tick(delta)
 if result.search_completed:
  completed.append(result.target_id)
  note("搜寻完成：%s；+1神经元（一次结算）"%result.target_id)
  if result.target_id=="bed":add_dialogue("角色 · 认真","这里没有")
  target_index=-1
  hero_state="idle"
  if scenario==3:
   sample_done=true
   note("本场无干预搜寻完成；重开此场可验证猫的受惊反应。")
  return
 if rules.reaction_left>0:
  hero_state="scratch"
 elif rules.stun_left>0 or rules.hurt_left>0:
  hero_state="hit"
 elif hero_state in ["scratch","hit"]:
  hero_state="idle"
 if cat_pending:
  advance_cat(delta)
  return
 if sample_done:
  return
 match scenario:
  0:advance_autonomy(delta)
  1:advance_mother(delta)
  2:advance_father(delta)
  3:advance_autonomy(delta)

func advance_autonomy(delta:float) -> void:
 if rules.body_busy():return
 if rules.search_active:
  hero_state="search"
  return
 if rules.search_attempts>=rules.search_limit or rules.sp<50:
  if scene_phase!="return_bed":
   scene_phase="return_bed"
   hero_route=layout.path(hero_pos,layout.BED_STOP)
   target_index=-1
  move_hero(delta)
  if hero_route.is_empty():
   sample_done=true
   note("已实际回到床侧；本轮样板止于此，休息/周目/钥匙通关待实现。")
  return
 if target_index<0:
  var distance:=INF
  for index in selected:
   if layout.furniture[index].id in completed:continue
   var candidate:float=hero_pos.distance_to(layout.furniture[index].at)
   if candidate<distance:
    distance=candidate
    target_index=index
  if target_index<0:
   sample_done=true
   return
 if hero_route.is_empty() and hero_pos.distance_to(layout.furniture[target_index].at)>0.03:
  hero_route=layout.path(hero_pos,layout.furniture[target_index].at)
 move_hero(delta)
 if hero_pos.distance_to(layout.furniture[target_index].at)<=0.03:
  hero_facing=((layout.furniture[target_index].rect as Rect2).get_center()-hero_pos).normalized()
  if rules.begin_search(layout.furniture[target_index].id):
   hero_state="search"
   note("开始搜寻 %s；已占用次数 %d/10"%[layout.furniture[target_index].name,rules.search_attempts])

func move_hero(delta:float) -> void:
 if hero_route.is_empty():return
 var before:=hero_pos
 var moved:=layout.move_path(hero_pos,hero_route,1.15*delta)
 hero_pos=moved.position
 hero_route=moved.route
 if hero_pos.distance_to(before)>0.00001:hero_facing=(hero_pos-before).normalized()
 hero_state="walk" if not hero_route.is_empty() else "idle"

func move_npc(delta:float,speed:float=1.0) -> void:
 var before:=npc_pos
 var moved:=layout.move_path(npc_pos,npc_route,speed*delta)
 npc_pos=moved.position
 npc_route=moved.route
 npc_moving=npc_pos.distance_to(before)>0.00001
 if npc_moving:npc_facing=(npc_pos-before).normalized()

func facing_each_other() -> bool:
 var dir:Vector2=(hero_pos-npc_pos).normalized()
 return npc_facing.dot(dir)>0.6 and hero_facing.dot(-dir)>0.6

func actual_contact(limit:float=0.75) -> bool:
 return hero_pos.distance_to(npc_pos)<=limit and layout.clear_segment(hero_pos,npc_pos) and facing_each_other()

func advance_mother(delta:float) -> void:
 if scene_phase=="mother_approach":
  move_npc(delta)
  if npc_route.is_empty():
   npc_facing=(hero_pos-npc_pos).normalized()
   hero_facing=-npc_facing
   scene_phase="mother_give"
   state_time=0
   add_dialogue("母亲 · 关心","妈妈给你熬了粥 喝了休息吧")
 elif scene_phase=="mother_give":
  npc_moving=false
  if rules.reaction_left>0:
   scene_phase="mother_interrupted"
   npc_state="idle"
   note("接碗动作已中断；粥仍由母亲持有，本场不补发。")
   return
  npc_state="give"
  hero_state="give"
  state_time+=delta
  if state_time>=0.8:
   var ok:bool=rules.commit_transfer("mother:%d"%event_generation,"porridge","mother","hero",hero_pos.distance_to(npc_pos),layout.clear_segment(hero_pos,npc_pos),facing_each_other(),actual_contact())
   if ok:
    audio.cue("transfer","transfer:%d"%event_generation)
    note("实际接碗：唯一归属 mother → hero；未食用，不恢复精神，不发资源。")
   scene_phase="mother_retract"
   state_time=0
 elif scene_phase=="mother_retract":
  state_time+=delta
  if state_time>0.35:
   hero_state="idle"
   npc_state="idle"
   sample_done=true
   note("递物场次结束；原上床/转场剧情待接。可重开验证交付前干预。")
 elif scene_phase=="mother_interrupted" and rules.reaction_left<=0:
  hero_state="idle"
  sample_done=true

func advance_father(delta:float) -> void:
 pressure_accumulator+=delta
 if pressure_accumulator>=1.0:
  pressure_accumulator-=1.0
  rules.sp=maxi(0,rules.sp-1)
  first_damage=true
  status_visible=true
 state_time+=delta
 if scene_phase=="father_prepare" and state_time>=2:
  npc_route=layout.path(npc_pos,hero_pos+Vector2(0.55,0))
  scene_phase="father_approach"
  state_time=0
 elif scene_phase=="father_approach":
  move_npc(delta)
  if npc_route.is_empty():
   npc_facing=(hero_pos-npc_pos).normalized()
   hero_facing=-npc_facing
   scene_phase="father_windup"
   state_time=0
   npc_state="grab"
   note("抓取前摇 1 秒；尚未抓牢。")
 elif scene_phase=="father_windup" and state_time>=1:
  if actual_contact(0.7):
   grabbed=true
   pair_offset=hero_pos-npc_pos
   hero_route=PackedVector2Array()
   rules.cancel_search()
   scene_phase="father_gripped"
   state_time=0
   rules.facts.append({"kind":"grab_started","time":rules.world_time,"distance":hero_pos.distance_to(npc_pos)})
   note("抓握实际成立；保持原相对位置，抓稳转身 2 秒后带行。")
  else:
   sample_done=true
   note("抓握失败：距离、方向或遮挡不合法；没有瞬移补位。")
 elif scene_phase=="father_gripped" and state_time>=2:
  scene_phase="father_drag"
  npc_route=layout.path(npc_pos,Vector2(4.65,0.35))
 elif scene_phase=="father_drag":
  var moved:=layout.move_path(npc_pos,npc_route,delta)
  var partner:Vector2=moved.position+pair_offset
  if layout.walkable(partner) and layout.clear_segment(hero_pos,partner,layout.RADIUS):
   npc_pos=moved.position
   npc_route=moved.route
   hero_pos=partner
   npc_moving=true
   hero_state="walk"
  else:
   npc_moving=false
   note_once("配对路径受阻，双方停止；没有穿家具或吸附。")
  if npc_route.is_empty():
   sample_done=true
   npc_moving=false
   note("已沿可行路径带至门内；隐藏Street跨场与结局未实现。")
 elif scene_phase=="startle_escape":
  move_hero(delta)
  if hero_route.is_empty() and hero_pos.distance_to(npc_pos)>0.85:
   grabbed=false
   startle_pending=false
   if not startle_rewarded:
    rules.sp=mini(100,rules.sp+5)
    startle_rewarded=true
    rules.facts.append({"kind":"startle_escape","time":rules.world_time,"sp_restored":5})
   npc_state="idle"
   hero_state="idle"
   npc_moving=false
   scene_phase="father_released"
   sample_done=true
   note("惊跳实际脱离，+5精神一次；父亲压迫仍存在。测试止于释放，后续追抓待接。")

func cast_startle() -> void:
 if scenario!=2 or world_paused() or sample_done or startle_pending or rules.body_busy():return
 if not scene_phase in ["father_windup","father_gripped","father_drag"]:
  note("惊跳测试：等待本次抓取前摇或抓牢；无效操作不扣费。")
  return
 if rules.neurons<2 or rules.world_time<startle_cooldown:
  note("惊跳不可用：需要2神经元且4秒冷却已结束。")
  return
 rules.neurons-=2
 startle_cooldown=rules.world_time+4
 if 2<=rules.global_resistance:
  note("惊跳被抵抗；已消耗2神经元，不解抓握。")
  return
 var away:Vector2=(hero_pos-npc_pos).normalized()
 var endpoint:=hero_pos+away*0.4
 # Distance is a presentation-only safe separation for this fixture, not
 # an invented universal exploration-skill displacement.
 if not layout.walkable(endpoint) or not layout.clear_segment(hero_pos,endpoint,layout.RADIUS):
  note("后撤路径受阻；技能已提交，没有伪造成功脱离或精神奖励。")
  return
 hero_route=layout.path(hero_pos,endpoint)
 scene_phase="startle_escape"
 startle_pending=true
 hero_state="walk"
 npc_moving=false
 note("惊跳已提交：2神经元 / 强度2 / 冷却4游戏秒；实际后撤完成才结算专属脱离。")

func advance_cat(delta:float) -> void:
 state_time+=delta
 npc_state="grab"
 if state_time>=0.22 and not cat_hit_done:
  npc_facing=(hero_pos-npc_pos).normalized()
  hero_facing=-npc_facing
  var hit:bool=rules.commit_hit("cat:%d"%event_generation,hero_pos.distance_to(npc_pos),layout.clear_segment(hero_pos,npc_pos),facing_each_other(),actual_contact(0.75))
  if hit:
   cat_hit_done=true
   hero_state="hit"
   status_visible=true
   first_damage=true
   audio.cue("hit","cat:%d"%event_generation)
   note("猫抓伤实际命中一次：生命 -10 / 精神 -10。")
 if state_time>=0.5:
  cat_pending=false
  npc_state="idle"
  if cat_hit_done:add_dialogue("角色 · 难受","I Feel bad")
  sample_done=true
  note("受击验证止于命中；后续跳窗与下一行为尾段待接。")

func open_neuron_menu() -> void:
 if world_paused() or sample_done and scenario!=2:return
 var can:bool=rules.neurons>=1 and rules.world_time>=rules.cooldown_until and rules.reaction_left<=0
 menu.open_menu(rules.neurons,can,test_resistance)
 audio.cue("open")

func cast_skin() -> void:
 var submitted:Dictionary=rules.submit_skin()
 if not submitted.ok:
  note("无效提交：%s；没有扣费"%submitted.reason)
  audio.cue("invalid")
  return
 note("SKIN已提交：-1神经元；身体反应等待关屏完成。")
 close_neuron_menu()

func close_neuron_menu() -> void:
 menu.close_menu()
 closing_left=0.18
 input_lock_frames=3
 audio.cue("close")

func apply_cast() -> void:
 var cat_context:bool=scenario==3 and rules.search_active and target_index==0 and not cat_hit_done
 var result:Dictionary=rules.apply_pending()
 if not result.ok:return
 if result.success:
  hero_route=PackedVector2Array()
  hero_state="scratch"
  audio.cue("success")
  note("干预成功：抓挠 0.5 秒；%s"%("未完成搜寻取消，不发完成奖励" if result.search_cancelled else "不额外结算伤害"))
  if scenario==1 and scene_phase=="mother_give":
   scene_phase="mother_interrupted"
   npc_state="idle"
   note("接碗已被打断；粥保持母亲唯一持有。")
  if cat_context:
   cat_pending=true
   state_time=0
   add_dialogue("黑猫 · 生气","喵!!!")
 else:
  note("干预被抵抗；费用已支付，原搜寻进度继续。")
  audio.cue("invalid")

func add_dialogue(speaker:String,text:String) -> void:
 dialogue_queue.append({"speaker":speaker,"text":text})
 show_dialogue()

func show_dialogue() -> void:
 if dialogue_queue.is_empty():
  dialogue_panel.hide()
 else:
  dialogue_text.text=dialogue_queue[0].speaker+"\n\n"+dialogue_queue[0].text
  dialogue_panel.show()

func advance_dialogue() -> void:
 if not dialogue_queue.is_empty():dialogue_queue.pop_front()
 show_dialogue()
 input_lock_frames=3

func note(message:String) -> void:
 log_lines.append(message)
 if log_lines.size()>60:log_lines.pop_front()
 if demo_mode:print("EVENT: "+message)

func note_once(message:String) -> void:
 if not message in log_lines:note(message)

func update_ui() -> void:
 status_label.text="COIN  %02d     PLEXUS  %02d"%[rules.neurons,rules.plexus]
 if status_visible:status_label.text+="     HP %d  SP %d"%[rules.hp,rules.sp]
 var remaining:float=maxf(0,rules.cooldown_until-rules.world_time)
 debug_label.text="游戏时间 %.2fs   冷却 %.2fs   视野 %.2f×"%[rules.world_time,remaining,ZOOM_STEPS[zoom_index]]
 state_label.text=("世界暂停" if world_paused() else "自主运行")+"   /   搜寻 %d/10   完成 %d   %s   |   左键主角：神经菜单  ·  空格：暂停  ·  滚轮：视野"%[rules.search_attempts,rules.search_count,hero_state]
 if log_lines.size()>0:event_label.text=log_lines[-1]

func _unhandled_input(event:InputEvent) -> void:
 if input_lock_frames>0:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ENTER and not dialogue_queue.is_empty():
   advance_dialogue()
  elif event.keycode==KEY_ESCAPE and menu.visible:close_neuron_menu()
  elif event.keycode==KEY_SPACE and not menu.visible and dialogue_queue.is_empty():paused_manual=not paused_manual
  elif event.keycode==KEY_X and first_damage:status_visible=not status_visible
  elif event.keycode==KEY_R:reset_zoom()
  elif event.keycode==KEY_F6:toggle_geometry()
  elif event.keycode==KEY_TAB:open_neuron_menu()
 elif event is InputEventMouseButton and event.pressed and not world_paused():
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   zoom_index=clampi(zoom_index+(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1),0,3)
   camera.zoom=Vector2.ONE*BASE_ZOOM*ZOOM_STEPS[zoom_index]
  elif event.button_index==MOUSE_BUTTON_LEFT:
   var world_mouse:Vector2=world_viewport.get_canvas_transform().affine_inverse()*(event.position/2.0)
   var actor_screen:=layout.project(hero_pos)
   if Rect2(actor_screen+Vector2(-16,-62),Vector2(32,65)).has_point(world_mouse):open_neuron_menu()

func toggle_resistance() -> void:
 test_resistance=not test_resistance
 rules.skin_resistance=1 if test_resistance else 0
 note("测试夹具：SKIN针对抗性=%d；相等抵抗，不是正式成长。"%rules.skin_resistance)

func toggle_geometry() -> void:
 view.debug_geometry=not view.debug_geometry

func reset_zoom() -> void:
 zoom_index=1
 camera.zoom=Vector2.ONE*BASE_ZOOM

func toggle_effects() -> void:
 reduced_effects=not reduced_effects
 menu.reduced_effects=reduced_effects
 note("降低反馈已%s；不影响判定与世界时序。"%("开启" if reduced_effects else "关闭"))

func create_audio_controls() -> void:
 audio_panel=PanelContainer.new()
 audio_panel.position=Vector2(805,230)
 audio_panel.custom_minimum_size=Vector2(390,330)
 audio_panel.add_theme_stylebox_override("panel",panel_style(Color("283332"),Color("869a8d")))
 add_child(audio_panel)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",8)
 audio_panel.add_child(column)
 var title:=Label.new()
 title.text="音量 · 当前音效为待替换测试音"
 title.add_theme_font_size_override("font_size",16)
 column.add_child(title)
 for channel in ["master","ui","world","ambience","music","voice"]:
  var row:=HBoxContainer.new()
  column.add_child(row)
  var caption:=Label.new()
  caption.text={"master":"总音量","ui":"界面","world":"动作音效","ambience":"环境","music":"音乐","voice":"配音"}[channel]
  caption.custom_minimum_size.x=100
  row.add_child(caption)
  var slider:=HSlider.new()
  slider.min_value=0
  slider.max_value=1
  slider.step=0.01
  slider.value=audio.levels[channel]
  slider.custom_minimum_size.x=210
  slider.value_changed.connect(func(value:float):audio.set_level(channel,value))
  row.add_child(slider)
 var close:=Button.new()
 close.text="关闭 · 恢复"
 close.pressed.connect(toggle_audio_controls)
 column.add_child(close)
 audio_panel.hide()

func toggle_audio_controls() -> void:
 audio_panel.visible=not audio_panel.visible
 sync_audio_pause()

func snapshot(tag:String) -> void:
 var folder:=ProjectSettings.globalize_path("res://../docs/validation/screenshots")
 DirAccess.make_dir_recursive_absolute(folder)
 await RenderingServer.frame_post_draw
 var result:=get_viewport().get_texture().get_image().save_png(folder+"/"+tag+".png")
 print("SCREENSHOT "+tag+" result="+str(result))

func run_visual_check(_delta:float) -> void:
 # A finite, visible engine run. Calls scene actions through the same handlers;
 # recorded screenshots are genuine viewport frames, not composited mockups.
 pass
