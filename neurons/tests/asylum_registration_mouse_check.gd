extends "res://tests/asylum_registration_check.gd"
## Finite registration-history fixture, then genuine CRT/world mouse input.
## No begin_registration_followup/cancel API or manual tick after CRT opens.

func world_click(at:Vector2,offset:Vector2=Vector2.ZERO) -> void:
 var screen:Vector2=(app.world_viewport.get_canvas_transform()*(app.layout.project(at)+offset))*2.0
 var motion_event:=InputEventMouseMotion.new();motion_event.position=screen;motion_event.global_position=screen
 Input.parse_input_event(motion_event);await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func finish_live_lines() -> void:
 for index in range(12):
  if app.dialogue_queue.is_empty():return
  await continue_live_line()

func mouse_live_until(predicate:Callable,seconds:float=3.0) -> bool:
 # Ordinary controlled actions may queue genuine body feedback. Respect that
 # pause and advance its visible lines through Enter rather than erasing text.
 var elapsed:float=0.0
 while elapsed<seconds:
  if predicate.call():return true
  var before_frame:int=Engine.get_process_frames()
  if not app.dialogue_queue.is_empty():await continue_live_line()
  else:await frames(1)
  elapsed+=float(maxi(1,Engine.get_process_frames()-before_frame))*get_process_delta_time()
 return predicate.call()

func legal_control() -> bool:
 give_skill("CONTROL");app.paused_manual=false
 app.open_neuron_menu();await click(app.menu.nodes.CONTROL)
 var active:bool=await await_live(func():return app.rules.control_left>0 and app.closing_left<=0,3)
 await finish_live_lines();await frames(4)
 return active

func prepare_mouse_case() -> bool:
 registration_fixture(true)
 # Earn the initial answer through the existing contact/timing handler. The
 # stationary precondition avoids an automatic second question before input.
 var answered:bool=until3(func():return bool(app.asylum.data.registered),4)
 check(answered and registration3().reply_pending and not registration3().asked,"mouse fixture earns the real initial departure-copy answer without injecting a follow-up outcome")
 if not answered:return false
 await finish_live_lines()
 check(app.dialogue_queue.is_empty() and not registration3().asked,"actual Enter inputs finish the first answer while the explicit manual pause preserves the unasked state")
 app.session.data.exploration_boundary=false;app.session.data.targets=[]
 var controlled:bool=await legal_control()
 check(controlled and registration3().reply_received and not registration3().asked,"actual CRT payment starts legal CONTROL before a new autonomous question")
 return controlled

func finish3() -> void:
 var output:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,
  "scope":"Two finite actual CRT/world-mouse registration sequences: desk click and visible nurse-body click, real route/contact, interruptible writing, floor-command interruption and later same-paper reading. Ordinary _process after CRT opens; no direct begin/cancel API or manual world tick in the mouse sequences.",
  "fixtures":"Initial walkable nurse/hero, carried prior wheelchair departure, no random arrivals, 50N/unlocked CONTROL and empty unrelated autonomous targets. The first registration answer is genuinely earned with finite world steps, then consumed using actual Enter while the explicitly paused preparation state prevents an automatic follow-up. No question, written accusation or read knowledge is assigned.",
  "untested":"Natural-RNG full playthrough, every competing NPC or obstruction, approved concrete patient-number glyphs, formal art and subjective audio."},"  "));output.close()
 print("ASYLUM_REGISTRATION_MOUSE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 folder="res://../docs/validation/b3_20261016/registration_mouse"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="登记台与护士真实鼠标验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()

 if await prepare_mouse_case():
  var before:Vector2=app.hero_pos
  await world_click(app.layout.furniture[0].rect.get_center())
  check(app.action_phase in ["asylum_read_route","asylum_reading"] or app.asylum.data.body.get("kind","")=="registration_followup","real registration-desk mouse click requests the implemented route/contact interaction")
  check(await await_live(func():return bool(registration3().asked),3),"ordinary process reaches the nurse and asks the original follow-up after the desk click")
  check(app.hero_pos.distance_to(before)>0.04 and rec3("registration_question") and not registration3().written,"desk route physically moves before the actual question; speech alone issues no completed paper")
  await finish_live_lines()
  check(await await_live(func():return bool(registration3().written),2),"desk-initiated nurse really completes interruptible writing before the accusation exists")
  check(label_count3()==1 and not registration3().read,"finished desk-initiated paper remains unread until the separate viewing clock")
  check(await await_live(func():return bool(registration3().read),2),"desk-initiated actual viewing completes and obtains the source reaction through normal process")
  check(app.rules.owners.get("asylum_registration_followup","")=="registration_nurse" and app.rules.neurons==45 and app.rules.hp==100 and app.rules.sp==100,"actual mouse sequence keeps one nurse-owned paper, one CONTROL fee and no invented damage")
  app.paused_manual=true;await capture("01_actual_desk_route_write_read")

 if await prepare_mouse_case():
  await world_click(app.asylum.position("registration_nurse"),Vector2(0,-25))
  check(app.action_phase in ["asylum_read_route","asylum_reading"] or app.asylum.data.body.get("kind","")=="registration_followup","real visible nurse-body click also enters the physical registration interaction")
  check(await await_live(func():return bool(registration3().asked),3),"nurse-body click reaches actual question rather than a debug completion")
  await finish_live_lines()
  check(await await_live(func():return bool(registration3().written),2),"nurse-body sequence earns the original finished sheet before interruption")
  var floor_point:=Vector2(3.9,2.3)
  check(app.layout.walkable(floor_point),"new-command target is an explicitly checked walkable floor position")
  await world_click(floor_point)
  check(app.asylum.data.body.is_empty() and registration3().written and not registration3().read and label_count3()==1,"actual new floor command cancels only unfinished viewing and preserves the one written accusation")
  check(await mouse_live_until(func():return app.hero_route.is_empty(),2) and app.hero_pos.distance_to(floor_point)<0.08,"same controlled protagonist really follows the new floor route while genuine body feedback is continued through Enter")
  app.paused_manual=true;await capture("02_actual_floor_command_preserves_unread_paper")
  app.paused_manual=false
  await finish_live_lines()
  await world_click(app.asylum.position("registration_nurse"),Vector2(0,-25))
  check(await mouse_live_until(func():return bool(registration3().read),3),"later real nurse click routes back and reads the same completed paper")
  check(label_count3()==1 and rec3("registration_followup_written") and rec3("registration_followup_read") and app.rules.neurons==45,"re-reading through actual input creates no duplicate paper, settlement or second CONTROL fee")
  app.paused_manual=true;await capture("03_actual_nurse_same_paper_read")
 finish3()
