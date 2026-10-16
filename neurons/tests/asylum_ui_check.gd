extends "res://tests/asylum_events_check.gd"
## Actual viewport input, normal process after each declared initial fixture.
func world_click(at:Vector2,shift:bool=false,offset:Vector2=Vector2.ZERO) -> void:
 var screen:Vector2=(app.world_viewport.get_canvas_transform()*(app.layout.project(at)+offset))*2.0
 var motion_event:=InputEventMouseMotion.new();motion_event.position=screen;motion_event.global_position=screen
 Input.parse_input_event(motion_event);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.shift_pressed=shift
  Input.parse_input_event(event);await frames(2)

func legal_control() -> bool:
 give_skill("CONTROL");app.paused_manual=false
 app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 var active:bool=await await_live(func():return app.rules.control_left>0 and app.closing_left<=0,3)
 while not app.dialogue_queue.is_empty():await continue_live_line()
 await frames(4)
 return active

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/ui"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="精神病院真实鼠标验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture3("office",true);app.session.data.exploration_boundary=false;app.session.data.targets=[]
 app.hero_pos=Vector2(2.0,2.4)
 check(await legal_control(),"real CRT mouse selection pays and starts the legal CONTROL window")
 var spec:Dictionary=app.layout.furniture[6]
 await world_click(spec.rect.get_center())
 check(app.action_phase in ["asylum_read_route","asylum_reading"],"actual controlled furniture click requests reading rather than nonexistent first-floor key search")
 check(await await_live(func():return "asylum_duty_roster" in app.rules.known,4),"normal process walks to office paper and completes the actual public reading")
 check(app.rules.search_attempts==0 and app.rules.neurons==45,"public reading grants no search income or hidden extra CONTROL charge")
 app.paused_manual=true;await capture("01_actual_office_read_mouse")

 fixture3("office",true);app.session.data.exploration_boundary=false;app.session.data.targets=[]
 app.hero_pos=app.layout.furniture[0].at
 check(await legal_control(),"fresh legal window is submitted through actual CRT")
 await world_click(app.layout.furniture[0].rect.get_center())
 check(await await_live(func():return not app.asylum.records.state().reading.is_empty(),2),"real mouse begins finite prepare/contact/finish office read")
 await world_click(Vector2(2.3,1.8))
 await await_live(func():return app.hero_route.is_empty(),3)
 check(not "asylum_archive_index" in app.rules.known and app.asylum.records.state().reading.is_empty(),"new actual controlled movement cancels unfinished read without a late knowledge receipt")
 app.paused_manual=true;await capture("02_new_mouse_command_cancels_read")

 fixture3("bathroom",true);app.session.data.exploration_boundary=false;app.session.data.targets=[];app.hero_pos=Vector2(2.15,1.75)
 check(await legal_control(),"material-reading case uses real paid CONTROL through CRT")
 var relic:=Vector2(2.75,1.75)
 await world_click(relic)
 check(await await_live(func():return "asylum_corpse_wristband" in app.rules.known,3),"visible loose bracelet marker can actually be approached and read with world mouse")
 check(app.rules.owners.asylum_corpse_wristband=="bathroom:drain","actual reading leaves the same bracelet physically on the floor")
 await frames(2)
 while not app.dialogue_queue.is_empty():await continue_live_line()
 await world_click(relic,true)
 check(await await_live(func():return app.rules.owners.asylum_corpse_wristband=="hero",2),"Shift mouse performs timed physical pickup through the normal process")
 await frames(2)
 while not app.dialogue_queue.is_empty():await continue_live_line()
 var held:Dictionary={}
 for item in app.view.asylum_props():
  if item.id=="asylum_corpse_wristband" and item.get("held",false):held=item
 check(not held.is_empty(),"a genuinely held unread or read relic keeps a normal visible mouse entry")
 if not held.is_empty():
  await world_click(app.hero_pos,false,Vector2(float(held.draw_offset[0]),float(held.draw_offset[1])-5))
  check(not app.asylum.trace_events.state().active.is_empty(),"held-item marker actually starts a new finite physical reading instead of requiring read-before-take")
  check(await await_live(func():return app.asylum.trace_events.state().active.is_empty(),2),"held-item rereading ends normally and never waits permanently on an old receipt")
 check(app.rules.neurons==45 and app.rules.search_attempts==0,"loose item reading and taking grant no invented resources or key-search count")
 app.paused_manual=true;await capture("03_actual_marker_read_and_take_mouse")
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"real viewport CRT/furniture/material/Shift-pickup mouse and ordinary _process after explicit room/position/unlocked-CONTROL/50N fixture; not natural-RNG, all combinations, subjective audio or formal-art acceptance"},"  "));output.close()
 print("ASYLUM_UI_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
