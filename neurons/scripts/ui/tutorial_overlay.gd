extends Control
## Isolated practice. The campaign below stays frozen and untouched.
const Neural=preload("res://scripts/core/neural_rules.gd")
const Menu=preload("res://scripts/ui/campaign_menu.gd")
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
const Feedback=preload("res://scripts/ui/feedback_audio.gd")
const DialogueDisplay=preload("res://scripts/ui/dialogue_playback.gd")
const UIStyle=preload("res://scripts/ui/ui_style.gd")
const RigBodyPreview=preload("res://scripts/ui/rig_body_preview.gd")
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
var pause_control:Button
var lesson_data:Dictionary={}
var lesson_lines:Array=[]
var lesson_index:int=0
var lesson_delay:float=0.0
var lesson_history:Array=[]
var lesson_input_shield:Control
var guide_canvas:Node2D
var finishing:bool=false
var focus_mask:ColorRect
var focus_material:ShaderMaterial
var practice_body

func _init(owner) -> void:
 app=owner

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 theme=UIStyle.theme_for()
 practice_body=RigBodyPreview.new();add_child(practice_body)
 lesson_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_dialogue.json"))
 var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("17282a");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
 # A reused actor atlas in a labelled practice view; no new gameplay room.
 var panel:=Panel.new();panel.position=Vector2(70,110);panel.size=Vector2(1140,430)
 panel.add_theme_stylebox_override("panel",UIStyle.surface("paper"));panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
 var art:=Node2D.new();art.set_script(load("res://scripts/ui/menu_art.gd"));art.host=self;art.z_index=1;add_child(art)
 terminal=Menu.new();terminal.z_index=2;terminal.reduced_effects=app.reduced_effects;add_child(terminal)
 terminal.cast_requested.connect(practice_skin)
 terminal.skill_requested.connect(func(_id,_context):terminal._status.text="先按指引练习已开放的操作")
 terminal.close_requested.connect(close_terminal)
 terminal.tree_result.connect(tree_result)
 terminal.tree_action_filter=func(kind:String,id:String):return stage==9 and not manual_paused and not lesson_pending() and kind=="unlock" and id=="GUT"
 terminal.feedback_requested.connect(func(id:String):audio.cue_ui(id))
 for id in terminal.nodes:
  terminal.nodes[id].mouse_entered.connect(func():hover_id=id;hover_left=0)
  terminal.nodes[id].mouse_exited.connect(func():hover_id="";hover_left=0)
 audio=Feedback.new();add_child(audio);audio.levels=app.audio.levels.duplicate();audio.refresh_levels()
 lesson_input_shield=Control.new();lesson_input_shield.size=Vector2(1280,575)
 lesson_input_shield.mouse_filter=Control.MOUSE_FILTER_STOP;lesson_input_shield.z_index=5
 add_child(lesson_input_shield)
 guide_canvas=Node2D.new();guide_canvas.set_script(load("res://scripts/ui/menu_art.gd"))
 guide_canvas.host=self;guide_canvas.z_index=8;add_child(guide_canvas)
 # Experience P367–368: isolate the current target without modifying room art
 # or stealing input. This screen-space material is local to the practice UI.
 focus_mask=ColorRect.new();focus_mask.size=Vector2(1280,720);focus_mask.z_index=4
 focus_mask.mouse_filter=Control.MOUSE_FILTER_IGNORE
 focus_material=ShaderMaterial.new()
 var focus_shader:=Shader.new()
 focus_shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 focus_rect = vec4(0.0);
uniform float blur_pixels = 1.4;
void fragment() {
 vec2 p = SCREEN_UV * vec2(1280.0, 720.0);
 vec2 outside_axis = max(focus_rect.xy - p, p - focus_rect.zw);
 float outside = smoothstep(0.0, 7.0, max(outside_axis.x, outside_axis.y));
 vec2 d = SCREEN_PIXEL_SIZE * blur_pixels;
 vec3 sharp = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
 vec3 soft = sharp * 0.2;
 soft += textureLod(screen_tex, SCREEN_UV + vec2(d.x, 0.0), 0.0).rgb * 0.2;
 soft += textureLod(screen_tex, SCREEN_UV - vec2(d.x, 0.0), 0.0).rgb * 0.2;
 soft += textureLod(screen_tex, SCREEN_UV + vec2(0.0, d.y), 0.0).rgb * 0.2;
 soft += textureLod(screen_tex, SCREEN_UV - vec2(0.0, d.y), 0.0).rgb * 0.2;
 COLOR = vec4(mix(sharp, soft * 0.48, outside), 1.0);
}"""
 focus_material.shader=focus_shader;focus_mask.material=focus_material;add_child(focus_mask)
 var instructions:=Panel.new();instructions.position=Vector2(25,575);instructions.size=Vector2(1230,125);instructions.z_index=10
 instructions.add_theme_stylebox_override("panel",UIStyle.surface("paper",true));add_child(instructions)
 hint=Label.new();hint.position=Vector2(18,10);hint.size=Vector2(1175,30);hint.add_theme_font_size_override("font_size",21);instructions.add_child(hint)
 detail=Label.new();detail.position=Vector2(18,47);detail.size=Vector2(875,68);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",17);instructions.add_child(detail)
 next=button(instructions,"继续",Vector2(910,47),advance_lesson)
 button(instructions,"跳过练习 / 返回",Vector2(1050,47),finish)
 pause_control=button(self,"暂停练习",Vector2(1010,78),toggle_practice_pause)
 pause_control.size=Vector2(150,30)
 var reset_button:=button(self,"重置练习",Vector2(850,78),reset_practice)
 reset_button.size=Vector2(150,30)
 reset_button.visible=not guide_only
 reset_practice()
 if guide_only:
  stage=99;lesson_lines.clear();lesson_index=0;lesson_input_shield.hide()
  hint.text="操作详解 · 自主角色与神经干预"
  detail.text="左键身体打开CRT，悬停查看三句说明；右键身体查看前置与解锁升级。菜单/对白冻结世界。基本观察免费，参数扩展5神经簇。"
  if app.rules.skill_states.CONTROL.unlocked:detail.text+="掌控每次5神经元、最长6秒、结束后20秒冷却；不是持续直接控制。"
  next.visible=true;next.disabled=false;next.text="返回关卡"

func button(parent:Node,text:String,pos:Vector2,callback:Callable) -> Button:
 var b:=Button.new();b.position=pos;b.size=Vector2(130,42);b.text=text
 UIStyle.style_button(b)
 b.add_theme_font_size_override("font_size",15);b.pressed.connect(callback)
 if parent==self:b.z_index=10
 parent.add_child(b);return b

func reset_practice() -> void:
 demo=Neural.new();demo.tutorial_demo=true
 terminal.rules=demo;terminal.close_menu();manual_paused=false;closing=0
 if pause_control!=null:pause_control.text="暂停练习"
 history.clear();lesson_history.clear();change_stage(0)

func toggle_practice_pause() -> void:
 manual_paused=not manual_paused
 pause_control.text="继续练习" if manual_paused else "暂停练习"
 sync_lesson_controls()

func change_stage(value:int) -> void:
 stage=value;clock=0;hover_left=0;history.append(stage)
 lesson_lines=lesson_data.stages.get(str(stage),[]).duplicate(true)
 lesson_index=0
 lesson_delay=1.0 if stage==2 else 0.0 # Original P123, then player-paced lines.
 var hints:Dictionary={
  0:["教程练习 · 正式进度保持不动","先观察床边的角色。角色自主行动，玩家通过神经干预影响他。"],
  1:["左键点击角色身体","请用鼠标左键点击角色身体。继续按钮不会代替点击。"],
  2:["悬停发亮的皮肤刺激节点","请把鼠标移到皮肤刺激节点，查看右侧实际技能说明。"],
  3:["悬停灰暗的肠胃蠕动节点约2秒","请把鼠标移到肠胃蠕动节点，保持悬停约2秒。"],
  4:["点击发亮的皮肤刺激节点","请实际点击皮肤刺激；收屏后才执行独立练习的身体反应。"],
  5:["观察实际身体反应","收屏完成、世界恢复后才执行反应；练习不会改变正式资源。"],
  6:["身体反馈已经发生","读完后进入右键教程。"],
  7:["右键点击角色身体","请用鼠标右键点击角色身体。左键不会完成这一步。"],
  8:["转动人体和星环，选择肠胃蠕动","点击未发光的一颗星。前置、当前余额与费用都在检查面板中。"],
  9:["确认解锁肠胃蠕动 · 练习费用1神经簇","请在实际检查面板点击确认解锁。返回不扣费。"],
  10:["冰柜人体预览 · 不施放到实际角色","解锁和升级只改变对应节点；升级每次1神经簇只加强度。预览不计干预、成长或认知。"],
  11:["关闭冰柜，正式开始","请点击冰柜关闭按钮返回关卡。正式以5神经元、3神经簇、仅皮肤刺激开始。"]}
 if hints.has(stage):hint.text=hints[stage][0]
 detail.set_meta("instruction",str(hints.get(stage,["",""])[1]))
 refresh_lesson_text();sync_lesson_controls()

func lesson_pending() -> bool:
 return lesson_index<lesson_lines.size()

func current_lesson() -> Dictionary:
 return lesson_lines[lesson_index].duplicate(true) if lesson_pending() else {}

func lesson_text(entry:Dictionary) -> String:
 return str(entry.text).replace("{clusters}",str(demo.plexus))

func refresh_lesson_text() -> void:
 if not lesson_pending():
  detail.text=str(detail.get_meta("instruction",""));next.visible=guide_only
 elif lesson_delay>0:
  detail.text="教学即将开始…";next.visible=true;next.text="稍候"
 else:
  var entry:Dictionary=lesson_lines[lesson_index]
  detail.text=DialogueDisplay.display_text(str(entry.speaker)+":"+lesson_text(entry))
  next.visible=true;next.text="继续 %d / %d"%[lesson_index+1,lesson_lines.size()]

func sync_lesson_controls() -> void:
 terminal.ui_paused=manual_paused or lesson_pending()
 if lesson_input_shield!=null:lesson_input_shield.visible=manual_paused or lesson_pending()
 if next!=null:next.disabled=manual_paused or lesson_delay>0

func advance_lesson() -> bool:
 if manual_paused or lesson_delay>0:return false
 if guide_only:finish();return true
 if not lesson_pending():return false
 var entry:Dictionary=lesson_lines[lesson_index]
 lesson_history.append({"stage":stage,"source":entry.source,"speaker":entry.speaker,"text":lesson_text(entry)})
 lesson_index+=1
 if not lesson_pending() and stage==6:change_stage(7)
 else:refresh_lesson_text();sync_lesson_controls()
 return true

func open_body(button_index:int) -> void:
 if manual_paused or lesson_pending():return
 if stage==1 and button_index==MOUSE_BUTTON_LEFT:
  terminal.open_menu(demo.neurons,true);change_stage(2)
 elif stage==7 and button_index==MOUSE_BUTTON_RIGHT:
  terminal.open_page("tree");change_stage(8)

func practice_skin() -> void:
 if stage!=4 or manual_paused or lesson_pending():terminal._status.text="先读完当前说明，再按指引查看或点击节点";return
 var result:Dictionary=demo.submit_skin()
 if result.ok:
  terminal.close_menu();closing=0.18;change_stage(5)

func close_terminal() -> void:
 if manual_paused or lesson_pending():terminal._status.text="请先读完当前教程对白";return
 if stage==10:terminal._status.text="等待人体预览完成；也可直接跳过练习";return
 if stage==11:finish(true);return
 terminal.close_menu()
 if stage in [2,3,4]:change_stage(1)
 elif stage in [8,9,10]:change_stage(7)

func tree_result(kind:String,id:String,result:Dictionary) -> void:
 if result.get("ok",false) and id=="GUT" and kind=="unlock":
  change_stage(10)

func finish(complete_exit:bool=false) -> void:
 if finishing:return
 if complete_exit and (guide_only or stage!=11 or lesson_pending()):return
 finishing=true
 if complete_exit:
  # P401/P403 belong to the actual character after leaving the freezer.
  # Prepend them ahead of the existing first-room dialogue without issuing
  # resources or altering its facts, random choices, routes or action state.
  var return_lines:Array=lesson_data.return_to_world
  for index in range(return_lines.size()-1,-1,-1):
   var line:Dictionary=return_lines[index]
   app.dialogue_queue.push_front({"speaker":str(line.speaker),"text":str(line.text)})
  app.show_dialogue()
 set_process(false)
 terminal.set_process(false)
 audio.reset_scene()
 app.profile.tutorial_completed=true
 app.save_requested=true
 app.tutorial_ui=null
 app.input_lock_frames=maxi(app.input_lock_frames,3)
 hide();queue_free()

func _process(delta:float) -> void:
 sync_lesson_controls()
 sync_focus_mask()
 audio.set_world_paused(manual_paused or lesson_pending() or terminal.visible or closing>0,manual_paused or terminal.visible or lesson_pending())
 if manual_paused:return
 clock+=delta
 if lesson_delay>0:
  lesson_delay=maxf(0,lesson_delay-delta)
  if lesson_delay<=0:refresh_lesson_text();sync_lesson_controls()
 if closing>0:closing=maxf(0,closing-delta)
 if stage==0 and clock>=2:change_stage(1)
 if stage==2 and not lesson_pending() and hover_id=="SKIN":
  hover_left+=delta
  if hover_left>=0.7:change_stage(3)
 if stage==3 and not lesson_pending() and hover_id=="GUT":
  hover_left+=delta
  if hover_left>=2.0:change_stage(4)
 if stage==8 and not lesson_pending() and terminal.selected_id=="GUT" and terminal.inspect_panel.visible and terminal.inspect_clock>=0.18:change_stage(9)
 if stage==10 and not lesson_pending() and clock>=2.0 and terminal.preview_delay<=0 and terminal.preview_left<=0:change_stage(11)
 if stage==5 and not manual_paused and not terminal.visible and closing<=0:
  if not demo.pending_neural.is_empty():demo.apply_pending();audio.cue("SFX_SKIN","practice")
  demo.tick(delta)
  if demo.reaction_left<=0 and demo.pending_neural.is_empty():change_stage(6)
 if practice_body!=null:practice_body.sample(0,"SKIN" if demo.reaction_left>0 else "",float(demo.reaction_left)*4.0,clock,app.reduced_effects)
 for child in get_children():
  if child is Node2D:child.queue_redraw()

func _gui_input(event:InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and Rect2(605,220,100,200).has_point(event.position):open_body(event.button_index)

func draw_art(canvas:Node2D) -> void:
 if canvas==guide_canvas:draw_guidance(canvas);return
 if demo==null or terminal==null or terminal.visible:return
 canvas.draw_rect(Rect2(270,275,250,110),Color("879c9d"))
 canvas.draw_rect(Rect2(270,375,250,18),Color("606f70"))
 var foot:=Vector2(650,400)
 if practice_body==null or not practice_body.draw(canvas,foot,180):
  canvas.draw_rect(Rect2(605,220,100,200),Color("d6d5c5"))
  canvas.draw_string(theme.default_font,Vector2(615,309),"练习区",HORIZONTAL_ALIGNMENT_LEFT,-1,17,UIStyle.INK)
  canvas.draw_string(theme.default_font,Vector2(606,335),"人体校准中",HORIZONTAL_ALIGNMENT_LEFT,-1,14,UIStyle.MUTED)
 canvas.draw_string(theme.default_font,Vector2(415,485),"独立练习 / 不影响正式进度",HORIZONTAL_ALIGNMENT_LEFT,-1,18,UIStyle.MUTED)

func find_button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=find_button(child,text)
  if found!=null:return found
 return null

func guidance_target() -> Dictionary:
 var target:Rect2=Rect2()
 var mode:String="点击"
 var right:bool=false
 if stage in [1,7]:
  target=Rect2(605,220,100,200);right=stage==7
 elif stage in [2,4]:
  target=terminal.nodes.SKIN.get_global_rect();mode="悬停" if stage==2 else "点击"
 elif stage==3:
  target=terminal.nodes.GUT.get_global_rect();mode="悬停"
 elif stage==8:
  target=terminal._coin.get_global_rect() if lesson_index in [1,2] else terminal.tree_nodes.GUT.get_global_rect()
 elif stage==9:
  var unlock:Button=find_button(terminal.inspect_panel,"确认解锁")
  if unlock!=null:target=unlock.get_global_rect()
 elif stage==10:
  target=Rect2(170,170,220,335);mode="观察"
 elif stage==11:
  var close:Button=find_button(terminal,"CLOSE")
  if close!=null:target=close.get_global_rect()
 return {"rect":target,"mode":mode,"right":right}

func sync_focus_mask() -> void:
 if focus_mask==null:return
 var info:Dictionary=guidance_target()
 var target:Rect2=info.rect
 focus_mask.visible=not guide_only and target.size!=Vector2.ZERO
 if not focus_mask.visible:return
 target=target.grow(9)
 focus_material.set_shader_parameter("focus_rect",Vector4(target.position.x,target.position.y,target.end.x,target.end.y))
 focus_material.set_shader_parameter("blur_pixels",0.0 if app.reduced_effects else 1.4)

func draw_guidance(canvas:Node2D) -> void:
 if guide_only or demo==null or terminal==null:return
 var info:Dictionary=guidance_target()
 var target:Rect2=info.rect
 var mode:String=info.mode
 var right:bool=info.right
 if target.size==Vector2.ZERO:return
 var breathe:float=0.0 if app.reduced_effects or manual_paused else sin(clock*2.0)*1.5
 var center:Vector2=target.get_center()
 var radius:float=clampf(maxf(target.size.x,target.size.y)*0.58,28,82)+breathe
 canvas.draw_arc(center,radius,0,TAU,48,Color(0.72,0.85,0.65,0.72),2.0,true)
 canvas.draw_rect(target.grow(4),Color(0.72,0.85,0.65,0.55),false,1.0)
 if mode=="观察":return
 var icon:Vector2=Vector2(clampf(target.end.x+13,35,1225),clampf(center.y-20,120,510))
 var press:float=0.0 if app.reduced_effects or manual_paused or lesson_pending() else maxf(0,sin(clock*3.0))*2.0
 var body:Rect2=Rect2(icon+Vector2(0,press),Vector2(26,38))
 canvas.draw_style_box(app.panel_style(Color("24352f"),Color("bdd4ae")),body)
 canvas.draw_line(body.position+Vector2(13,0),body.position+Vector2(13,18),Color("bdd4ae"),1)
 canvas.draw_line(body.position+Vector2(0,18),body.position+Vector2(26,18),Color("bdd4ae"),1)
 var half:Rect2=Rect2(body.position+Vector2(14 if right else 2,2),Vector2(10,14))
 canvas.draw_rect(half,Color("a4be94"))
 var label:String="悬停" if mode=="悬停" else ("右键" if right else "左键")
 canvas.draw_string(theme.default_font,body.position+Vector2(-2,55),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d8e2c8"))
