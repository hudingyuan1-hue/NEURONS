extends Node
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/resume_20261015/persistence_ui"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=button(child,text)
  if found!=null:return found
 return null

func click(target:Button) -> void:
 var point:Vector2=target.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point
 Input.parse_input_event(move);await frames(2)
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  Input.parse_input_event(event);await frames(2)

func capture(name:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await click(button(frontend,"建立档案"));frontend.name_field.text="保存回标题验证"
 await click(button(frontend,"建立并开始"))
 if frontend.active==null:await click(button(frontend,"建立并开始"))
 app=frontend.active
 if app.tutorial_ui!=null:await click(button(app.tutorial_ui,"跳过练习"))
 while not app.dialogue_queue.is_empty():await click(button(app.dialogue_panel,"继续"))
 await frames(25);app.paused_manual=true
 var root:String=app.store.root
 var clock:float=app.rules.world_time
 var neurons:int=app.rules.neurons
 var hp:int=app.rules.hp
 var owner:String=str(app.session.data.key_owner)
 var position:Vector2=app.hero_pos
 var route:PackedVector2Array=app.hero_route.duplicate()
 var rng_state:String=str(app.rng.state)
 var blocker:String=root.path_join("unwritable_directory_fixture")
 var block:=FileAccess.open(blocker,FileAccess.WRITE)
 block.store_string("A test file, not a writable save directory");block.close()
 app.store.root=blocker
 await click(button(app,"保存并回标题"));await frames()
 check(frontend.active==app and app.campaign_ready and app.paused_manual,"failed save retains active campaign and pauses instead of losing progress")
 check(app.status_note.contains("保存失败") and app.rules.neurons==neurons and app.rules.hp==hp,"save failure shows specific feedback without changing resources or damage")
 check(app.rules.world_time==clock and app.hero_pos==position,"save failure cannot secretly advance the interrupted world")
 await capture("01_save_failure_keeps_game")
 app.store.root=root
 await click(button(app,"保存并回标题"));await frames(4)
 check(frontend.active==null,"successful real save-and-title button returns to title")
 var saved:Dictionary=frontend.store.load_snapshot()
 check(saved.ok and is_equal_approx(float(saved.data.rules.world_time),clock),"title is reached only after an actual verified save")
 check(FileAccess.file_exists(ProjectSettings.globalize_path(root).path_join("profile.json.bak")),"previous valid save backup remains available")
 await capture("02_returned_to_title")
 await click(button(frontend,"CONTINUE"));await frames(4);app=frontend.active
 check(app!=null and app.tutorial_ui==null,"real continue reloads completed tutorial without issuing another practice")
 check(app.rules.neurons==neurons and app.rules.hp==hp and str(app.session.data.key_owner)==owner,"continue preserves resource balance, health and unique key ownership")
 check(app.hero_pos==position and app.hero_route==route and str(app.rng.state)==rng_state,"continue preserves actual position, active route and RNG")
 check(app.paused_manual and is_equal_approx(app.rules.world_time,clock),"saved manual pause resumes frozen instead of progressing behind title")
 await capture("03_continued_exact_state")
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"actual mouse save/return/continue with own unwritable-path fixture and independent test profile"},"  "));result.close()
 print("PERSISTENCE_UI_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene();frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 await frames(4)
 frontend.request_exit(0 if failures.is_empty() else 1)
