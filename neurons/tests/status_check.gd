extends Node
## Real viewport keys/buttons plus fixed animal/point fixture; no human-play claim.
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/status_20261015"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(n:int=3) -> void:
 for i in range(n):await get_tree().process_frame

func until(predicate:Callable,limit:int=800,advance_lines:bool=false) -> bool:
 for i in range(limit):
  if predicate.call():return true
  if advance_lines and not app.dialogue_queue.is_empty():await drain_dialogue()
  else:await frames(1)
 return predicate.call()

func button(root:Node,text:String) -> BaseButton:
 for child in root.get_children():
  if child is BaseButton and child.text.contains(text):return child
  var found:BaseButton=button(child,text)
  if found!=null:return found
 return null

func click(target:BaseButton) -> void:
 var point:Vector2=target.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
 await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(2)

func key(code:int) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.pressed=down;Input.parse_input_event(event);await frames(2)

func drain_dialogue() -> void:
 for i in range(30):
  if app.dialogue_queue.is_empty():break
  await click(button(app.dialogue_panel,"继续"))

func capture(name:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(8);get_window().grab_focus();await frames(3)
 await click(button(frontend,"建立档案"))
 if frontend.name_field==null:await click(button(frontend,"建立档案"))
 frontend.name_field.text="受伤状态验证"
 await click(button(frontend,"建立并开始"))
 if frontend.active==null:await click(button(frontend,"建立并开始"))
 app=frontend.active
 if app.tutorial_ui!=null:await click(button(app.tutorial_ui,"跳过练习"))
 await drain_dialogue();app.paused_manual=true
 app.family.enabled=false;app.home.start_attempt({"dog":false,"cat":true,"cat_point":1})
 app.session.data.targets=["bedroom:1","bedroom:0","bedroom:2"]
 app.session.data.key_target="bedroom:9";app.session.data.key_owner="bedroom:9";app.rules.owners.key="bedroom:9"
 app.completed.clear();app.motion.clear();app.hero_route=PackedVector2Array();app.target_index=-1
 app.action_phase="autonomy";app.hero_pos=app.layout.furniture[1].at
 await drain_dialogue() # The fixture still presents its normal cat arrival lines.
 check(not app.vitality_panel.visible and not app.first_damage,"new profile hides health until a real loss")
 await key(KEY_X)
 check(not app.vitality_panel.visible,"X before first injury does not reveal status early")
 app.paused_manual=false
 check(await until(func():return app.rules.search_active and app.target_index==1),"autonomous hero really starts search at occupied cat point")
 app.cast_skin()
 check(await until(func():return app.home.data.cat.phase=="attack"),"successful interference reaches original cat anger dialogue")
 await drain_dialogue()
 check(await until(func():return app.rules.hp==90),"actual interrupted-search cat contact causes one injury")
 app.paused_manual=true
 check(app.first_damage and not app.vitality_panel.visible,"injury queues status until attack and feedback finish")
 await capture("01_injury_feedback")
 await drain_dialogue();app.paused_manual=false
 for i in range(60):
  if app.vitality_panel.visible:break
  if not app.dialogue_queue.is_empty():await drain_dialogue()
  else:await frames(1)
 check(app.vitality_panel.visible,"status opens after original first-injury dialogue and reaction")
 app.paused_manual=true
 check(app.vitality_panel.values.text.contains("90") and app.vitality_panel.hint.visible,"separate minimal status shows actual HP/SP and X guidance")
 await capture("02_automatic_status")
 var state:Dictionary=app.vitality_panel.snapshot()
 var clock:float=app.rules.world_time
 await frames(45)
 check(app.vitality_panel.snapshot()==state and app.rules.world_time==clock,"manual pause cannot expire status by real time")
 check(app.store.save_snapshot(app.snapshot_data()).ok,"active automatic display writes actual JSON save")
 var saved:Dictionary=app.store.load_snapshot()
 check(saved.ok and app.restore_snapshot(saved.data) and app.vitality_panel.snapshot()==state,"JSON reload preserves pending action lifetime and display mode")
 app.family.enabled=false
 app.paused_manual=false
 check(await until(func():return not app.vitality_panel.visible,800,true),"next actual completed navigation or search closes automatic display")
 app.paused_manual=true
 var last:String=app.vitality_panel.last_action
 check(not last.is_empty() and app.rules.hp==90,"display completion changes no damage and has an action identity")
 check(not app.rules.commit_hit("cat:%d"%app.rules.actual_attempt,0.1,true,true,true),"settled cat contact cannot replay injury after load")
 check(not app.vitality_panel.pending_damage,"replayed hit cannot reopen automatic status")
 await key(KEY_X)
 check(app.vitality_panel.visible and app.vitality_panel.manual_open,"real X key opens and pins status")
 last=app.vitality_panel.last_action
 app.paused_manual=false
 var action_done:bool=await until(func():return app.vitality_panel.last_action!=last,800,true)
 app.paused_manual=true
 check(action_done and app.vitality_panel.visible and app.vitality_panel.manual_open,"manual status stays open across subsequent real actions")
 await key(KEY_X)
 check(not app.vitality_panel.visible,"second X closes pinned status")
 app.rules.change_sp(-1)
 check(app.vitality_panel.pending_damage and not app.first_damage_pending,"later mental damage re-arms display without repeating first-injury speech")
 app.paused_manual=false
 check(await until(func():return app.vitality_panel.visible,800,true),"later injury also automatically displays current health")
 app.paused_manual=true
 await click(button(app,"设置"))
 check(app.audio_panel.visible,"actual upper-right settings button opens world-pausing panel")
 clock=app.rules.world_time;await frames(15)
 check(app.rules.world_time==clock,"settings does not advance world or action lifetime")
 await capture("03_settings")
 await click(app.auto_status_box)
 var config:=ConfigFile.new();var config_ok:int=config.load(app.store.root.path_join("preferences.cfg"))
 check(not app.auto_status_enabled and not app.vitality_panel.auto_open and config_ok==OK and not config.get_value("interface","auto_status",true),"settings checkbox disables auto display and persists preference")
 await click(button(app.audio_panel,"关闭"))
 app.rules.change_sp(-1)
 check(not app.vitality_panel.pending_damage and not app.vitality_panel.visible,"disabled auto display ignores subsequent actual SP loss")
 await key(KEY_X)
 check(app.vitality_panel.visible and app.vitality_panel.manual_open,"manual X remains available while automatic display is disabled")
 await click(button(app,"保存并回标题"));await frames(3)
 check(frontend.active==null,"status/preference test returns via real saved title path")
 await click(button(frontend,"CONTINUE"));app=frontend.active;await frames(3)
 check(not app.auto_status_enabled and app.vitality_panel.manual_open and app.vitality_panel.visible,"continue restores pinned display and disabled automatic preference")
 await capture("04_manual_after_continue")
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"real input, actual cat contact and JSON load, deterministic animal/target fixture; no full B1 or subjective audio acceptance"},"  "));output.close()
 print("STATUS_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
