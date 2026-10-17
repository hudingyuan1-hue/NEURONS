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
 await frames(2);RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func run_check() -> void:
 check(OS.has_feature("windows"),"package validation runs on target Windows platform")
 check(not FileAccess.file_exists("res://tests/test_rules.gd"),"test scripts are excluded from shipped pack")
 check(not DirAccess.dir_exists_absolute("res://DOCX"),"source documents are not shipped")
 for name in ["skills","home_rules","home_dialogue","tutorial_dialogue","search_actions","presentation","audio_bindings","hospital","hospital_observations","hidden_street","opening","asylum","asylum_records","asylum_ward_events","asylum_trace_events","asylum_isolation","asylum_observations","asylum_nurse_duty","asylum_intake","cortex_events","cortex_upper_events","key_discovery","room_spaces","institution_spaces","combat_chapter","street_chapter"]:
  check(JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json"%name)) is Dictionary,"dynamic JSON is in PCK: "+name)
 var corridor_layout=load("res://scripts/world/institution_layout.gd").new("corridor",3)
 var activity_layout=load("res://scripts/world/institution_layout.gd").new("activity",3)
 check(corridor_layout.world_size()==Vector2(16,5) and corridor_layout.furniture.size()==4 and corridor_layout.portals.size()==7,"exported corridor resolves new dimensions, original four searches and seven portals")
 check(activity_layout.world_size()==Vector2(10,8) and activity_layout.furniture.size()==8 and activity_layout.portals.size()==1,"exported activity room resolves new dimensions and eight original search descriptors")
 for spec:Array in [["group_therapy",Vector2(9,8),6],["quiet",Vector2(6,5),4],["bathroom",Vector2(8,7),7],["double_ward",Vector2(8,6),7],["workshop",Vector2(10,7),8]]:
  var trial_layout=load("res://scripts/world/institution_layout.gd").new(str(spec[0]),3)
  check(trial_layout.world_size()==spec[1] and trial_layout.furniture.size()==int(spec[2]) and trial_layout.candidate_count()==int(spec[2]) and trial_layout.portals.size()==1,"exported upper room resolves original indices/actions and configured geometry: "+str(spec[0]))
 var package_session=load("res://scripts/core/campaign_session.gd").new();var package_rng:=RandomNumberGenerator.new()
 package_session.new_attempt(3,package_rng)
 var versions_ok:bool=package_session.data.asylum_space_versions.size()==7
 for room in package_session.ASYLUM_METRIC_ROOMS:versions_ok=versions_ok and int(package_session.data.asylum_space_versions.get(room,0))==2
 check(versions_ok,"exported fresh L3 activates exactly seven intended versioned upper rooms; stairs uses existing base version")
 corridor_layout=null;activity_layout=null;package_session=null
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
 var body_height:float=65.0 if app.layout.geometry_version>=2 else 25.0
 var at:Vector2=(app.world_viewport.get_canvas_transform()*(app.layout.project(app.hero_pos)+Vector2(0,-body_height)))*Vector2(1280,720)/Vector2(app.world_viewport.size)
 await click(at,MOUSE_BUTTON_RIGHT)
 check(app.menu.visible and app.menu.panel_mode=="tree","exported world body click opens actual freezer")
 await frames(15);await capture("03_windows_freezer")
 check(app.audio.assets.size()==bindings.assets.size(),"all configured development audio bindings load in exported game")
 check(app.menu.title.text=="星仓" and app.menu.pages.has("inventory"),"exported star-store title and independent inventory exist")
 app.menu.close_menu();app.closing_left=0;app.paused_manual=true;app.unlock_combat()
 check(app.session.data.level==5 and app.rules.mode=="combat" and app.CombatMap.rooms().size()==18,"exported L5 opens with eighteen rooms and combat rules")
 check(app.combat.config.observations.size()==7 and app.combat.reactions!=null and app.combat.observations!=null,"exported combat includes actual evidence and witnessed-reaction modules")
 check(app.combat.Bed.polygon(Vector2(3,3),Vector2(1,1)).size()==4,"exported bed resolves oriented geometry implementation")
 await capture("04_windows_combat")
 app.unlock_street()
 check(app.session.data.level==6 and app.street.data.actors.size()==45 and app.StreetMap.rooms().size()==7,"exported Street loads all forty-five identities and seven segments")
 var entry:Vector2=app.hero_pos
 check(entry.is_equal_approx(app.layout.spawn()),"exported Street begins at actual entry")
 check(app.street.box!=null and app.street.data.box.id=="street_labor_box","exported Street loads the one physical labor box module")
 check(app.street.lateral_bed!=null and app.street.lateral_bed.rect().has_area() and app.street.spec("transporter_asylum").attack=="lateral_bed","exported independent lateral bed is distinct from assistant charge")
 check(app.street.materials!=null and app.street.materials.state().surfaces.has("street_maintenance_label"),"exported physical Street paper/cleaner module and persistent floor label load")
 check(app.street.config.dialogue.size()==5 and app.street.config.materials.faceless.prop=="street_prop_3","exported original Street lines and correct maintenance debris binding are present")
 check(app.Achievements.DEFINITIONS.size()==12 and app.Achievements.EVENT_KEYS.size()==7,"exported global store contains all original twelve event/ending keys")
 app.enter_room("street_end");app.hero_pos=app.layout.portal("ending_gate").at-Vector2(1.4,0);app.keep_metric_actor_visible()
 await capture("05_street_end_direct_room_preview")
 check(app.store.save_snapshot(app.snapshot_data()).ok,"exported process writes independent profile successfully")
 var output:=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 output.store_string(JSON.stringify({"passes":passes,"failures":failures,"engine":Engine.get_version_info(),"rendered":true,"exported_template":false,"exported_pck":true,"scope":"matching engine loads exported PCK with external driver; source resources and test scripts excluded; EXE normal startup checked separately; not full EXE gameplay or audio audition"},"  "));output.close()
 print("EXPORTED_GAME_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 if failures.is_empty():frontend.request_exit();return
 app.audio.reset_scene();frontend.remove_child(app);app.queue_free();frontend.active=null;app=null
 root.remove_child(frontend);frontend.queue_free();frontend=null;await frames(4)
 quit(0 if failures.is_empty() else 1)
