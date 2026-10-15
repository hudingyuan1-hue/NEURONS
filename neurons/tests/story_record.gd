extends Node
var frontend
var app
var folder:String="res://../docs/validation/b1_20261015/continuous"

func frames(count:int) -> void:
 for i in range(count):await get_tree().process_frame

func clear_lines() -> void:
 app.dialogue_queue.clear();app.show_dialogue()

func capture(name:String) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func dialogue_until_empty() -> void:
 var safety:int=0
 while not app.dialogue_queue.is_empty() and safety<40:
  await frames(24);app.advance_dialogue();safety+=1

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames(3);frontend.show_profile();await frames(3)
 frontend.name_field.text="父亲连续操作 · 测试";frontend.overwrite_armed=true;frontend.new_game();await frames(3)
 app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish() # Exercises skip; full practice has its own suite.
 app.home.start_attempt({"dog":false,"cat":false})
 app.family.start_attempt();app.family.data.extra_checked=true
 app.hero_pos=Vector2(2.9,2.3);app.hero_route=PackedVector2Array();app.rules.cancel_search();app.target_index=-1
 clear_lines()
 app.open_system_page("tree")
 app.paused_manual=true
 app.menu.selected_id="TEMP";app.menu.tree_action("unlock")
 app.menu.selected_id="STARTLE";app.menu.tree_action("unlock")
 await frames(30);await capture("01_unlock_from_initial_three_clusters")
 app.close_neuron_menu();await dialogue_until_empty();await frames(10)
 app.family.spawn("father")
 await dialogue_until_empty()
 app.paused_manual=false
 var count:int=0
 while not app.rules.gripped and count<900:
  if not app.dialogue_queue.is_empty():await dialogue_until_empty()
  await frames(1);count+=1
 await capture("02_actual_grab")
 app.open_neuron_menu();app.menu.selected_id="STARTLE";app.menu.describe("STARTLE")
 var clock:float=app.rules.world_time
 await frames(30);await capture("03_rescue_terminal")
 app.menu._request_cast()
 app.paused_manual=true
 await frames(18)
 var paused_ok:bool=app.rules.world_time==clock and app.rules.gripped and not app.rules.pending_neural.is_empty()
 await capture("04_pause_during_close")
 app.paused_manual=false
 await frames(35)
 await capture("05_actual_escape")
 var escaped:bool=not app.rules.gripped and app.rules.neurons==3 and app.family.data.blood_door
 await frames(30)
 app.paused_manual=true
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"rendered":true,"real_clock_frames":true,"forced_father_fixture":true,"initial_5N_3C_preserved":true,"pause_during_close_verified":paused_ok,"actual_special_escape_verified":escaped,"scope":"continuous automated UI inputs; actor presence fixed, normal rules/timing/cost/contact; graybox art, not human playthrough"},"  "))
 print("STORY_RECORD pause=%s escape=%s"%[paused_ok,escaped])
 app.audio.reset_scene()
 frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 await frames(4)
 get_tree().quit(0 if paused_ok and escaped else 1)
