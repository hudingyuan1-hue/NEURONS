extends SceneTree
## Load exported PCK with the matching engine. Official release EXEs ignore
## custom --script overrides; this driver stays outside the shipped PCK.
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var folder:String=""

func _init() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 if folder.is_empty():push_error("Pass an absolute --validation-root for export evidence");quit(1);return
 DirAccess.make_dir_recursive_absolute(folder)
 call_deferred("run_check")

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await process_frame

func button(node:Node,text:String) -> Button:
 for child in node.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=button(child,text)
  if found!=null:return found
 return null

func click(point:Vector2,index:int=MOUSE_BUTTON_LEFT) -> void:
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point
 Input.parse_input_event(move);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
  event.button_index=index;event.pressed=down;Input.parse_input_event(event);await frames(2)

func press(control:Button) -> void:
 await click(control.get_global_rect().get_center())

func capture(name:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func run_check() -> void:
 check(OS.has_feature("windows"),"package validation runs on target Windows platform")
 check(not FileAccess.file_exists("res://tests/test_rules.gd"),"test scripts are excluded from shipped pack")
 check(not DirAccess.dir_exists_absolute("res://DOCX"),"source documents are not shipped")
 for name in ["skills","home_rules","home_dialogue","tutorial_dialogue","search_actions","presentation","audio_bindings","hospital","hidden_street","opening"]:
  check(JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json"%name)) is Dictionary,"dynamic JSON is in PCK: "+name)
 var bindings=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_bindings.json"))
 for entry in bindings.assets:
  check(load(str(entry.stream)) is AudioStream,"audio stream loads from PCK: "+str(entry.id))
 var catalog=load("res://scripts/presentation/asset_catalog.gd").new()
 check(catalog.errors.is_empty() and not catalog.current.is_empty(),"runtime actor/cabinet catalog resolves imported textures inside pack")
 catalog=null
 frontend=load("res://scenes/front_end.tscn").instantiate();root.add_child(frontend)
 if frontend.startup_opening!=null:frontend.startup_opening.skip()
 await frames(4);await capture("01_windows_title")
 await press(button(frontend,"建立档案"));frontend.name_field.text="EXE资源验证"
 await press(button(frontend,"建立并开始"))
 if frontend.active==null:await press(button(frontend,"建立并开始"))
 app=frontend.active
 if app.opening_ui!=null:
  check(app.opening_ui.current_text().contains("EXE资源验证"),"exported introduction resolves actual profile name")
  await capture("01b_windows_introduction")
  await press(button(app.opening_ui,"跳过"))
 check(app!=null and app.tutorial_ui!=null,"exported title/profile buttons reach actual tutorial")
 await capture("02_windows_tutorial")
 await press(button(app.tutorial_ui,"跳过练习"))
 while not app.dialogue_queue.is_empty():await press(button(app.dialogue_panel,"继续"))
 await frames(5)
 var at:Vector2=(app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-25)))*2.0
 await click(at,MOUSE_BUTTON_RIGHT)
 check(app.menu.visible and app.menu.panel_mode=="tree","exported world body click opens actual freezer")
 await frames(15);await capture("03_windows_freezer")
 check(app.audio.assets.size()==15,"all configured development audio bindings load in exported game")
 check(app.store.save_snapshot(app.snapshot_data()).ok,"exported process writes independent profile successfully")
 var output:=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"engine":Engine.get_version_info(),"rendered":true,"exported_template":false,"exported_pck":true,"scope":"matching engine loads exported PCK with external driver; source resources and test scripts excluded; EXE normal startup checked separately; not full EXE gameplay or audio audition"},"  "));output.close()
 print("EXPORTED_GAME_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 if failures.is_empty():frontend.request_exit();return
 app.audio.reset_scene();frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 root.remove_child(frontend);frontend.queue_free();frontend=null;await frames(4)
 quit(0 if failures.is_empty() else 1)
