extends Node
## Real campaign handlers and mouse input. Save-and-title is invoked directly
## while covered by the cinematic, simulating a checkpoint/restart boundary.
var frontend
var app
var passes:Array=[]
var failures:Array=[]
var visited:Array=[]
var folder:String="res://../docs/validation/b2_opening_20261016/campaign"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func seconds(duration:float) -> void:
 var elapsed:float=0
 while elapsed<duration:
  await get_tree().process_frame;elapsed+=get_process_delta_time()

func wait_for(predicate:Callable,duration:float=3.0) -> bool:
 var elapsed:float=0
 while elapsed<duration and not predicate.call():
  await get_tree().process_frame;elapsed+=get_process_delta_time()
 return predicate.call()

func button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=button(child,text)
  if found!=null:return found
 return null

func click_position(point:Vector2) -> void:
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
 Input.parse_input_event(motion);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
  Input.parse_input_event(event);await frames(2)

func click(target:Button) -> void:
 if target==null:check(false,"requested real button exists");return
 await click_position(target.get_global_rect().get_center())

func capture(name:String) -> void:
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func gameplay() -> Dictionary:
 return {"neurons":app.rules.neurons,"plexus":app.rules.plexus,"hp":app.rules.hp,"sp":app.rules.sp,"world_time":app.rules.world_time,"control_ms":app.rules.control_ms,"attempt":app.rules.actual_attempt,"rng":str(app.rng.state),"owner":app.session.data.key_owner,"targets":app.session.data.targets.duplicate(),"facts":app.rules.facts.duplicate(true),"known":app.rules.known.duplicate(true),"institution":app.rules.institutional_records.duplicate(true),"pos":app.hero_pos}

func finish_check() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"actual new-profile/pause/next/continue/tutorial-skip handlers with injected viewport mouse input; existing save-and-title handler for restart; legacy flag fixture only; placeholder art/no voice acceptance","visited":visited},"  "));f.close()
 print("OPENING_CAMPAIGN_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 if is_instance_valid(app):
  app.audio.reset_scene();frontend.remove_child(app);app.queue_free();frontend.active=null;app=null;await frames(4)
 frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 check(frontend.store.root.contains("tmp/"),"opening integration uses isolated test save root")
 frontend.preferences.reduced=false # Explicit presentation setting; no gameplay fixture.
 await click(button(frontend,"建立档案"))
 check(frontend.name_field!=null,"actual title button opens profile entry")
 if frontend.name_field==null:await finish_check();return
 frontend.name_field.text="开场连续验证"
 await click(button(frontend,"建立并开始"))
 if frontend.active==null:await click(button(frontend,"建立并开始"))
 app=frontend.active
 if app==null:check(false,"actual profile button creates campaign");await finish_check();return
 check(app.opening_ui!=null and app.tutorial_ui==null and not app.profile.opening_completed,"actual new-profile button starts parasite intro before tutorial")
 if app.opening_ui==null:await finish_check();return
 var flow=app.opening_ui
 check(not flow.reduced_effects,"new-profile opening receives current visual preference before initial ready")
 var name_value:String=str(app.profile.name)
 var id_value:int=app.invader_id
 check(flow.current_text().contains(name_value) and flow.context.invader_id==str(id_value),"real opening reuses actual saved player name and invader ID")
 var unchanged:Dictionary=gameplay()
 await seconds(0.03);await click(flow.pause_button)
 check(flow.paused and app.world_paused(),"visible opening pause button pauses presentation while entire world remains frozen")
 check(flow.typed>0 and flow.typed<flow.current_text().length(),"actual pause occurs before the current subtitle finishes typing")
 var frozen:Dictionary=flow.snapshot()
 await seconds(0.5)
 check(flow.snapshot()==frozen and gameplay()==unchanged,"paused opening changes no typing, gameplay, RNG, ownership or fact ledger")
 await click_position(Vector2(80,620))
 check(not app.menu.visible and not app.title_requested and flow.snapshot()==frozen,"cinematic click over underlying save controls does not pass through")
 await capture("01_paused_named_intro")
 await frames()
 var saved:Dictionary=app.store.load_snapshot()
 check(saved.ok and saved.data.opening_state.paused and not saved.data.profile.opening_completed,"actual campaign autosave includes incomplete opening and paused subtitle state")
 var typed:float=flow.typed
 var card:int=flow.index
 app.request_title_return()
 check(await wait_for(func():return frontend.active==null),"existing save-and-title handler checkpoints covered intro successfully")
 app=null;flow=null
 await click(button(frontend,"继续游戏"));await frames();app=frontend.active;flow=app.opening_ui
 check(flow!=null and flow.paused and flow.index==card and is_equal_approx(flow.typed,typed),"real CONTINUE restores middle subtitle through JSON without replaying from start")
 if flow==null:await finish_check();return
 check(app.tutorial_ui==null and gameplay()==unchanged,"restore freezes original world and does not prematurely issue tutorial")
 check(app.invader_id==id_value and app.profile.name==name_value,"continuation never rerolls name or invader identity")
 await capture("02_continued_middle_intro")
 await click(flow.pause_button)
 for attempt in range(25):
  if app.opening_ui==null:break
  flow=app.opening_ui
  var prior:int=flow.index
  if prior not in visited:visited.append(prior)
  await click(flow.next_button)
  if prior==6 and app.opening_ui!=null and flow.index==prior and flow.fade_out<=0:await capture("03_original_motive")
  if app.opening_ui!=null and flow.index==prior and flow.fade_out<=0:await click(flow.next_button)
  await wait_for(func():return app.opening_ui==null or app.opening_ui.index!=prior)
 check(app.opening_ui==null and app.profile.opening_completed and app.tutorial_ui!=null,"actual next buttons complete full intro and start one isolated tutorial")
 check(visited.size()==9,"actual sequential intro visits all nine ordered cards")
 if app.opening_ui!=null or app.tutorial_ui==null:await finish_check();return
 check(gameplay()==unchanged,"full intro leaves resources, world clock, identity ledgers and unique key untouched")
 await capture("04_tutorial_after_intro")
 await frames()
 saved=app.store.load_snapshot()
 check(saved.ok and saved.data.profile.opening_completed and saved.data.opening_state.is_empty(),"completion is saved with no stale opening pending state")
 await click(button(app.tutorial_ui,"跳过练习"));await frames()
 check(app.tutorial_ui==null and app.profile.tutorial_completed,"tutorial skip remains independent of opening completion")
 app.paused_manual=true
 var old:Dictionary=app.snapshot_data();old.profile.erase("opening_completed");old.profile.tutorial_completed=true;old.opening_state={}
 var balance:int=app.rules.neurons
 check(app.store.save_snapshot(old).ok,"legacy-profile fixture is stored through real checksum save")
 frontend.close_campaign();app=null;await frames()
 await click(button(frontend,"继续游戏"));await frames();app=frontend.active
 check(app.opening_ui==null and app.tutorial_ui==null,"old profile without opening flag continues without retroactively inserting intro")
 check(app.rules.neurons==balance and app.invader_id==id_value,"legacy continuation neither reissues resources nor rerolls identity")
 await capture("05_legacy_continue")
 await finish_check()
