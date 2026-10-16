extends Node
## Uses viewport mouse events, not pressed.emit or test-stage jumps.
var frontend
var app
var tutor
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/resume_20261015/tutorial_input"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func wait_for(predicate:Callable,limit:int=150) -> bool:
 for i in range(limit):
  if predicate.call():return true
  await frames(1)
 return predicate.call()

func move_mouse(point:Vector2) -> void:
 var event:=InputEventMouseMotion.new()
 event.position=point;event.global_position=point
 Input.parse_input_event(event)
 await frames(2)

func click(point:Vector2,button:int=MOUSE_BUTTON_LEFT) -> void:
 await move_mouse(point)
 for down in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=point;event.global_position=point
  event.button_index=button;event.pressed=down
  Input.parse_input_event(event)
  await frames(2)

func click_button(button:Button) -> void:
 await click(button.get_global_rect().get_center())

func find_button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=find_button(child,text)
  if found!=null:return found
 return null

func read_lesson() -> void:
 # Acknowledgements use the visible tutorial button; no stage mutation.
 for attempt in range(300):
  if not is_instance_valid(tutor) or not tutor.lesson_pending():return
  if tutor.next.visible and not tutor.next.disabled:await click_button(tutor.next)
  else:await frames(1)
 check(false,"finite actual-button lesson reading completes")

func capture(name:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 await click_button(find_button(frontend,"建立档案"))
 frontend.name_field.text="真实鼠标教程检查"
 await click_button(find_button(frontend,"建立并开始"))
 if frontend.active==null:await click_button(find_button(frontend,"建立并开始"))
 app=frontend.active;tutor=app.tutorial_ui
 check(tutor!=null,"real title/profile mouse buttons launch isolated tutorial")
 check(await wait_for(func():return tutor.stage==1),"introduction reaches body prompt without advancing formal world")
 await read_lesson()
 await capture("00_body_mouse")
 await click(Vector2(650,300))
 check(tutor.stage==2 and tutor.terminal.visible,"viewport left-body click opens CRT")
 await frames(35)
 var unread:String=tutor.detail.text
 await frames(45)
 check(tutor.lesson_pending() and tutor.detail.text==unread and unread.contains("暂且只掌握"),"original first CRT sentence remains until actual acknowledgement")
 await capture("00a_original_crt_line")
 var pause:Button=find_button(tutor,"暂停练习")
 await click_button(pause)
 await move_mouse(tutor.terminal.nodes.SKIN.get_global_rect().get_center())
 var hover:float=tutor.hover_left
 await frames(30)
 check(tutor.manual_paused and tutor.stage==2 and tutor.hover_left==hover,"pause remains clickable above CRT and freezes hover lesson")
 await click_button(pause)
 await read_lesson()
 await move_mouse(tutor.terminal.nodes.SKIN.get_global_rect().get_center())
 check(await wait_for(func():return tutor.stage==3),"resume allows real bright-node hover")
 await read_lesson()
 await move_mouse(tutor.terminal.nodes.GUT.get_global_rect().get_center())
 check(await wait_for(func():return tutor.stage==4),"real locked-node hover observes two-second wait")
 unread=tutor.detail.text
 await frames(50)
 check(tutor.detail.text==unread and unread.contains("没有这个能力"),"locked-node dialogue is never replaced by a timed COIN message")
 await capture("00b_locked_original_line")
 var demo_money:int=tutor.demo.neurons
 await click_button(tutor.terminal.nodes.SKIN)
 check(tutor.stage==4 and tutor.demo.neurons==demo_money,"unread original instructions cannot be bypassed by a paid node press")
 await read_lesson()
 await click_button(tutor.terminal.nodes.SKIN)
 check(await wait_for(func():return tutor.stage==6),"real node press, closing and body reaction complete in order")
 check(app.rules.world_time==0 and app.rules.neurons==5 and app.rules.plexus==3,"full practice input never pays from or advances formal campaign")
 await read_lesson()
 await read_lesson()
 await click(Vector2(650,300),MOUSE_BUTTON_RIGHT)
 check(tutor.stage==8 and tutor.terminal.panel_mode=="tree","viewport right-body click opens freezer")
 await read_lesson()
 check(tutor.lesson_history.any(func(line):return str(line.source).contains("P372") and str(line.text).contains("还剩3簇")),"original cluster narration uses actual three-cluster practice balance")
 check(tutor.demo.plexus==3,"old five-cluster narration never grants extra practice funds")
 await frames(8)
 await click_button(tutor.terminal.tree_nodes.TEMP)
 await click_button(find_button(tutor.terminal.inspect_panel,"确认解锁"))
 check(not tutor.demo.skill_states.TEMP.unlocked and tutor.demo.plexus==3,"wrong tutorial node cannot spend practice funds or strand required unlock")
 await click_button(tutor.terminal.inspect_return);await frames(8)
 await click_button(tutor.terminal.tree_nodes.GUT)
 check(await wait_for(func():return tutor.stage==9 and tutor.terminal.inspect_panel.visible),"real star click reveals inspection panel before original explanation")
 await read_lesson()
 await frames(7)
 await capture("01_inspection")
 await click_button(tutor.terminal.inspect_return);await frames(8)
 check(not tutor.demo.skill_states.GUT.unlocked and tutor.demo.plexus==3 and not tutor.terminal.inspect_panel.visible,"return cancels inspection with no payment or unlock")
 await click_button(tutor.terminal.tree_nodes.GUT);await frames(7)
 await click_button(find_button(tutor.terminal.inspect_panel,"确认解锁"))
 check(tutor.stage==10 and tutor.demo.plexus==2,"confirmation unlocks once after actual inspection")
 await read_lesson()
 check(await wait_for(func():return tutor.terminal.preview_left>1.0),"gut preview starts after inspection closes")
 check(not tutor.terminal.inspect_panel.visible,"model preview is visible after panel departure")
 await frames(5)
 await click_button(pause)
 var left:float=tutor.terminal.preview_left
 var time:float=tutor.terminal.page_clock
 await frames(15)
 check(tutor.manual_paused and is_equal_approx(tutor.terminal.preview_left,left) and is_equal_approx(tutor.terminal.page_clock,time),"practice pause freezes actual body preview and interface timeline")
 await capture("02_gut_pose_paused")
 tutor.terminal.body_angle=2
 await capture("03_back_view")
 tutor.terminal.body_angle=0
 await click_button(pause)
 check(await wait_for(func():return tutor.stage==11),"full two-second preview returns to T pose before exit instruction")
 await capture("04_restored_t_pose")
 await read_lesson()
 var lesson_history:Array=tutor.lesson_history.duplicate(true)
 check(lesson_history.size()==19,"all nineteen player tutorial lines were acknowledged before complete exit")
 await click_button(find_button(tutor.terminal,"关闭"))
 check(await wait_for(func():return app.tutorial_ui==null),"real CLOSE exits tutorial")
 check(app.dialogue_queue.size()>=2 and app.dialogue_queue[0].text=="似乎 身体有些变化???" and app.dialogue_queue[1].text=="不管了 继续想办法逃出去吧","full tutorial returns original two hero lines to formal dialogue in order")
 check(app.rules.neurons==5 and app.rules.plexus==3 and app.rules.control_ms==0 and app.rules.evidence.is_empty(),"preview and unlock never contaminate formal resources, control or cognition")
 var saved:Dictionary=app.store.load_snapshot()
 check(saved.ok and saved.data.profile.tutorial_completed,"actual completion is saved once")
 await frames(5)
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 var body:Vector2=(app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-25)))*2.0
 await click(body)
 check(app.menu.visible and app.menu.panel_mode=="cast","formal viewport left-body click reaches campaign handler")
 await click_button(find_button(app.menu,"关闭"));await frames(10)
 body=(app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-25)))*2.0
 await click(body,MOUSE_BUTTON_RIGHT)
 check(app.menu.visible and app.menu.panel_mode=="tree","formal viewport right-body click opens freezer without debug handler")
 app.rules.plexus=5
 app.menu.selected_id="GUT";app.menu.describe_tree();await frames(7)
 await click_button(find_button(app.menu.inspect_panel,"确认解锁"))
 await frames(8)
 check(app.rules.skill_states.GUT.unlocked and app.rules.plexus==4,"formal freezer still unlocks through its real confirmation button")
 var clock:float=app.rules.world_time
 var frozen_ms:int=app.rules.control_ms
 await frames(80)
 check(app.rules.world_time==clock and app.rules.control_ms==frozen_ms and app.rules.evidence.is_empty(),"formal model preview runs only in UI time while campaign stays frozen")
 check(app.audio.starts.any(func(s):return s.id=="SFX_COLD" and s.channel=="ui"),"freezer cold material plays on UI channel during world pause")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"lesson_history":lesson_history,"scope":"viewport mouse events; isolated practice plus formal freezer; code-drawn placeholder body; audio loaded/played but not subjectively auditioned"},"  "))
 f.close()
 print("TUTORIAL_INPUT_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene()
 frontend.remove_child(app);app.queue_free();frontend.active=null;app=null;tutor=null
 await frames(4)
 frontend.request_exit(0 if failures.is_empty() else 1)
