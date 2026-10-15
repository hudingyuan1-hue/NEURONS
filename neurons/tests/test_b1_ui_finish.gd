extends SceneTree
## Rendered presentation check; all saves use an explicitly isolated tmp root.
const Preview=preload("res://scripts/ui/body_preview.gd")
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_ui_finish_20261016"
var frontend
var app

func _init() -> void:
 call_deferred("run")

func check(condition:bool,label:String) -> void:
 (passes if condition else failures).append(label)
 print(("PASS " if condition else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await process_frame

func capture(label:String) -> void:
 await frames(2);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(label+".png"))

func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 frontend=load("res://scenes/front_end.tscn").instantiate();root.add_child(frontend)
 await frames()
 check(frontend.store.root.contains("tmp/"),"test starts only with isolated tmp save path")
 if not frontend.store.root.contains("tmp/"):quit(2);return
 frontend.show_profile();await frames()
 frontend.name_field.text="B1界面收尾验证";frontend.overwrite_armed=true;frontend.new_game();await frames()
 app=frontend.active
 if app.opening_ui!=null:app.opening_ui.skip() # Separate opening suite owns the full sequence.
 var tutor=app.tutorial_ui
 for i in range(100):
  if tutor.stage==1:break
  await frames(1)
 tutor.sync_focus_mask()
 check(tutor.focus_mask.visible and tutor.focus_mask.mouse_filter==Control.MOUSE_FILTER_IGNORE,"tutorial target-outside material is visible and does not intercept clicks")
 check(tutor.guidance_target().rect==Rect2(605,220,100,200),"body prompt retains actual body click bounds")
 frontend.preferences.reduced=false;app.reduced_effects=false;tutor.sync_focus_mask()
 check(is_equal_approx(tutor.focus_material.get_shader_parameter("blur_pixels"),1.4),"standard feedback enables only local outside-target softening")
 await capture("01_tutorial_focus")
 app.reduced_effects=true;tutor.sync_focus_mask()
 check(is_zero_approx(tutor.focus_material.get_shader_parameter("blur_pixels")),"reduced feedback keeps static darkening and removes blur")
 await capture("02_tutorial_reduced")
 tutor.finish();await frames()
 app.family.enabled=false;app.home.enabled=false
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0;app.paused_manual=false
 app.open_neuron_menu()
 var menu=app.menu
 menu.describe("GUT")
 check(menu.full_description.is_empty(),"locked CRT node leaves description blank as original hover rule requires")
 menu.describe("SKIN");await frames(40)
 check(menu.full_description.count("###")==3 and not menu.full_description.contains("有概率"),"CRT uses three current S2 sentences rather than superseded probability description")
 await capture("03_crt_skin")
 var states:Array=[]
 var source_ok:bool=true
 for id in menu.nodes:
  for language in range(menu.CRT_LANGUAGES.size()):
   var text:String=menu.crt_text(id,language)
   if text.count("###")!=3:source_ok=false
   for sentence in str(app.rules.spec(id).description).split("。",false):
    if not text.contains("###"+sentence+"。"):source_ok=false
  var signature:String=str(Preview.pose(id,1.0,1.0))
  if signature not in states:states.append(signature)
 check(source_ok,"all thirteen language wrappers preserve all twelve current three-sentence descriptions verbatim")
 check(states.size()==12,"twelve skill previews have distinct source-based body poses")
 var rng_state:int=app.rng.state
 for i in range(40):menu.describe("SKIN")
 check(app.rng.state==rng_state,"random CRT language never consumes saved campaign RNG")
 app.menu.close_menu();app.open_system_page("tree");app.rules.plexus=100
 var clear_buttons:bool=true
 for rotation in [0.0,0.35,0.7]:
  menu.orbit=rotation;menu.layout_tree();await frames(2)
  for a in menu.tree_nodes:
   for b in menu.tree_nodes:
    if a<b and menu.tree_nodes[a].get_global_rect().intersects(menu.tree_nodes[b].get_global_rect()):clear_buttons=false
 check(clear_buttons,"actual tree button rectangles remain separate at three ring rotations")
 var clock:float=app.rules.world_time
 var neurons:int=app.rules.neurons
 var control_ms:int=app.rules.control_ms
 var evidence_count:int=app.rules.evidence.size()
 for id in menu.nodes:
  menu.selected_id=id;menu.describe_tree()
  var cost:int=1 if id=="SKIN" else int(app.rules.spec(id).unlock_cost)
  var before:int=app.rules.plexus
  menu.tree_action("upgrade" if id=="SKIN" else "unlock")
  check(menu.preview_id==id and menu.preview_delay>0 and app.rules.plexus==before-cost,"actual confirmation starts UI-only preview with original charge: "+id)
  await frames(14)
  check(menu.preview_left>0 and not menu.inspect_panel.visible,"preview follows inspection close: "+id)
  var left:float=menu.preview_left
  menu.ui_paused=true;await frames(5)
  check(is_equal_approx(menu.preview_left,left),"manual UI pause freezes preview: "+id)
  menu.ui_paused=false
  for angle in range(4):
   menu.body_angle=angle
   if angle==0:await capture("preview_"+id)
   elif (id=="GUT" and angle==1) or (id=="TINNITUS" and angle==2) or (id=="SKIN" and angle==3):await capture("angle_%s_%d"%[id,angle])
   else:await frames(1)
  await frames(70)
  check(menu.preview_left<=0 and Preview.pose(id,0,1).amount==0,"preview restores T-pose without carrying residue: "+id)
 check(app.rules.world_time==clock and app.rules.neurons==neurons and app.rules.control_ms==control_ms and app.rules.evidence.size()==evidence_count,"all body previews preserve paused world, neurons, effective control and evidence")
 menu.selected_id="GUT";menu.describe_tree();menu.tree_action("upgrade");await frames(15)
 check(menu.preview_id=="GUT" and menu.preview_left>0,"upgrade also replays corresponding UI preview")
 menu.close_menu()
 check(menu.preview_id.is_empty() and menu.preview_delay==0 and menu.preview_left==0,"closing freezer cancels presentation without late preview")
 var out:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 out.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"UI-only 12-skill poses and 13 language wrappers; explicit 100C fixture; original source quotes separately compared; not combat/character art approval"},"  "));out.close()
 print("B1_UI_FINISH %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene();frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 await frames(4);root.remove_child(frontend);frontend.queue_free();await frames(4)
 quit(0 if failures.is_empty() else 1)
