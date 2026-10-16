extends "res://tests/asylum_details_check.gd"
## One declared initial paper/actor fixture, then ordinary process and UI only.

func capture(image_name:String) -> void:
 await frames(2);app.view.queue_redraw();RenderingServer.force_draw(false)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(image_name+".png"))

func _ready() -> void:
 folder="res://../docs/validation/b3_finish_20261016/recording"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="纸件阅读与自主恢复实机"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 observation_fixture("group_therapy",5);actor3("therapist","group_therapy",app.hero_pos+Vector2(-0.5,0))
 check(app.layout.walkable(app.hero_pos) and app.layout.walkable(app.asylum.position("therapist")),"declared paper and protagonist stands are outside fixed chair collision geometry")
 app.session.data.targets=["group_therapy:5","stairs:0"];app.session.data.key_target="stairs:0";app.session.data.key_owner="stairs:0";app.rules.owners.key="stairs:0"
 app.session.data.exploration_boundary=false;give_skill("CONTROL")
 var initial:Dictionary=app.snapshot_data();var started:int=Engine.get_process_frames();var stage:int=0;var timeline:Array=[];var last:String=""
 app.paused_manual=false
 for index in range(1800):
  var reading:Dictionary=observations3().state().active
  var phase:String=str(reading.get("phase",""))+":"+app.action_phase+":"+str(stage)
  if phase!=last:timeline.append({"frame":Engine.get_process_frames()-started,"world_time":app.rules.world_time,"stage":stage,"action":app.action_phase,"reading":reading.duplicate(true),"control":app.rules.control_left});last=phase
  if not app.dialogue_queue.is_empty():await continue_live_line();continue
  if stage==0:
   app.open_neuron_menu();await click(app.menu.nodes.CONTROL);stage=1
  elif stage==1 and app.rules.control_left>0 and app.closing_left<=0:
   for item in app.view.asylum_props():
    if item.id!="asylum_signature_record":continue
    var pixel:Vector2=app.view.asylum_item_pixel(item)
    var screen:Vector2=(app.world_viewport.get_canvas_transform()*pixel)*2
    var move_event:=InputEventMouseMotion.new();move_event.position=screen;move_event.global_position=screen;Input.parse_input_event(move_event);await frames(2)
    for down in [true,false]:
     var event:=InputEventMouseButton.new();event.position=screen;event.global_position=screen;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(2)
    stage=2;break
  elif stage==2 and not reading.is_empty():
   await capture("01_actual_paper_prepare_contact");stage=3
  elif stage==3 and observations3().state().read.has("asylum_signature_record"):
   await capture("02_paper_read_without_signature");stage=4
  elif stage==4 and "group_therapy:5" in app.completed:
   await capture("03_control_expired_autonomous_search_completed");stage=5;await frames(15);break
  await frames(1)
 app.paused_manual=true
 check(stage==5,"ordinary process and actual CRT/world mouse complete a source-paper read then resume autonomous search")
 check(observations3().state().read.get("asylum_signature_record",{}).get("fields",{}).get("actual_signature")==null,"visible paper inspection never manufactures an actual signature")
 check(app.rules.neurons==int(initial.rules.neurons)-int(app.rules.spec("CONTROL").cost)+1,"one real paid intervention and only the later finished search settle their original resource amounts")
 var out:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"frames":Engine.get_process_frames()-started,"timeline":timeline,"scope":"One stated group-therapy actor/paper/50N/unlocked-CONTROL/two-target fixture. Thereafter ordinary _process and actual UI inputs only; no manual advance_world, debug completion or new capture/signature event. Silent continuous MovieMaker recording; not human all-RNG or formal-art/audio acceptance."},"  "));out.close()
 print("ASYLUM_EVIDENCE_SEQUENCE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);frontend.request_exit(0 if failures.is_empty() else 1)
