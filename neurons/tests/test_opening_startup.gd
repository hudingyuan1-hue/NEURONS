extends SceneTree
## Uses the normal front-end branch (no *-check flag), so the real startup
## slideshow and its title input shield are exercised rather than bypassed.
var frontend
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b2_opening_20261016/startup"

func _init() -> void:
 call_deferred("run")

func check(condition:bool,label:String) -> void:
 (passes if condition else failures).append(label)
 print(("PASS " if condition else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await process_frame

func button(root_node:Node,text:String) -> Button:
 for child in root_node.get_children():
  if child is Button and child.text.contains(text):return child
  var result:Button=button(child,text)
  if result!=null:return result
 return null

func click(target:Button) -> void:
 if target==null:check(false,"requested startup button exists");return
 var point:Vector2=target.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func capture(name:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 frontend=load("res://scenes/front_end.tscn").instantiate();root.add_child(frontend);await frames()
 check(not frontend.is_check_run() and frontend.startup_opening!=null,"normal application entry opens actual startup sequence before title interaction")
 check(frontend.active==null,"startup does not create or run a gameplay world")
 if frontend.startup_opening==null:frontend.request_exit(1);return
 var flow=frontend.startup_opening
 var done:Array=[];flow.completed.connect(func(sequence,skipped):done.append({"sequence":sequence,"skipped":skipped}))
 await click(button(frontend,"建立档案"))
 check(frontend.name_field==null and frontend.active==null,"startup modal prevents clicks from reaching covered NEW GAME button")
 await click(flow.pause_button)
 var state:Dictionary=flow.snapshot();await frames(12)
 check(flow.paused and flow.snapshot()==state,"real startup pause button freezes visible sequence clock")
 await capture("01_normal_startup_pause")
 await click(flow.pause_button)
 var elapsed:float=0
 while frontend.startup_opening!=null and elapsed<45:
  await frames(1);elapsed+=root.get_process_delta_time()
 check(frontend.startup_opening==null and done.size()==1 and not done[0].skipped,"normal automatic startup reaches title once after all cards")
 await capture("02_title_after_startup")
 await click(button(frontend,"建立档案"))
 check(frontend.name_field!=null and frontend.active==null,"title NEW GAME becomes available after startup completes")
 await capture("03_profile_after_startup")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"normal unbypassed front-end startup, actual mouse pause/input shield and full automatic return to title; code placeholders, no voice/subjective audio acceptance"},"  "));file.close()
 print("OPENING_STARTUP_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
