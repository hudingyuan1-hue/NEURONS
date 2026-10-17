extends "res://tests/opening_campaign_check.gd"
## Real-window input regression. Fixtures are declared in result.json.

func clear_dialogue() -> void:
 app.dialogue_queue.clear();app.show_dialogue()

func body_point() -> Vector2:
 var at:Vector2=app.layout.project(app.hero_pos)+Vector2(0,-65 if int(app.layout.geometry_version)>=2 else -25)
 return (app.world_viewport.get_canvas_transform()*at)*Vector2(1280,720)/Vector2(app.world_viewport.size)

func cast_by_mouse() -> void:
 await click_position(body_point())
 check(app.menu.visible and app.menu.panel_mode=="cast","actual body click opens CRT")
 await click(app.menu.nodes.SKIN)
 await wait_for(func():return app.closing_left>0,1.0)

func finish_feedback() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"real OpenGL window and injected mouse/buttons; search reaches actual contact through ordinary _process; declared NPC-disabled, target priority, finite UI-search miss-seed, 30N/10C and one held porridge fixtures; no human pacing/art/audio acceptance"},"  "));f.close()
 print("FEEDBACK_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 folder="res://../docs/validation/feedback_20261017/interaction"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 check(frontend.store.root.contains("tmp/"),"isolated save root")
 await frontend.show_profile()
 frontend.name_field.text="干预与界面验证";frontend.overwrite_armed=true;frontend.new_game()
 await frames();app=frontend.active
 if app.opening_ui!=null:app.opening_ui.skip()
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.home.enabled=false;app.family.enabled=false;app.hospital.enabled=false
 app.rules.neurons=30;app.rules.plexus=10
 var bindings:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_bindings.json"))
 check(app.audio.assets.size()==bindings.assets.size() and app.audio.assets.has("SFX_KEY") and app.audio.assets.has("SFX_ITEM_HANDOFF") and app.audio.assets.has("SFX_HIT"),"all sound bindings load including real key handoff and hit candidates")
 clear_dialogue();app.closing_left=0;app.paused_manual=false
 await click(button(app,"图书"))
 check(app.menu.visible and app.menu.panel_mode=="book","actual archive button opens visible archive")
 check(button(app.menu.pages.book,"食用")==null and button(app.menu.pages.book,"拾取")==null,"archive contains no consumption or pickup controls")
 await capture("01_archive")
 await click(button(app.menu,"关闭 ×"));await seconds(.3)
 clear_dialogue()
 var item:String=app.family.ensure_food("porridge","hero");app.family.data.inventory.append(item)
 await click(button(app,"物品栏"))
 check(app.menu.visible and app.menu.panel_mode=="inventory" and app.menu.title.text=="物品栏","separate inventory opens from actual button")
 check(app.menu.inventory_labels.porridge.text.contains("1") and not app.menu.inventory_buttons.porridge.disabled,"inventory reads held item and valid use state")
 check(app.menu.inventory_buttons.candy.disabled,"unheld food cannot be used")
 await capture("02_inventory")
 var frozen:float=app.rules.world_time;var before:int=app.rules.neurons
 await seconds(.4)
 check(app.rules.world_time==frozen and app.rules.neurons==before and app.rules.owners[item]=="hero","inventory pauses world without consuming or rewarding")
 await click(button(app.menu,"关闭 ×"));await seconds(.3);clear_dialogue()
 await click(button(app,"星仓"))
 check(app.menu.visible and app.menu.panel_mode=="tree" and app.menu.title.text=="星仓","player-facing tree is named star store while internal tree ID remains")
 await capture("03_star_store")
 await click(button(app.menu,"关闭 ×"));await seconds(.3);clear_dialogue()
 app.rules.cancel_search();app.target_index=-1;app.hero_route=PackedVector2Array();app.session.data.targets=["bedroom:1"]
 # Isolate UI from a legitimate early key/scene transition. Full-size key
 # eligibility remains intact; the separate key suite owns discovery coverage.
 for index in range(30):
  app.session.data.key_discovery.seed="feedback-ui-miss:"+str(index)
  if app.session.key_rules.draw(app.session.data.key_discovery,"bedroom:1")>=app.session.key_rules.probability(app.session.data.key_discovery,"bedroom:1"):break
 check(await wait_for(func():return app.rules.search_active,8),"autonomous host really walks to bedside search")
 var attempts:int=app.rules.search_attempts;before=app.rules.neurons
 await cast_by_mouse()
 app.paused_manual=true
 var closing:float=app.closing_left
 await seconds(.4)
 check(app.closing_left==closing and not app.rules.pending_neural.is_empty() and app.rules.search_active,"pause during closing retains timer pending cast and unfinished search")
 app.paused_manual=false
 check(await wait_for(func():return not app.rules.search_active and not app.intervention_feedback.receipts.is_empty(),1),"mouse-submitted SKIN cancels real unfinished search")
 check(app.rules.neurons==before-1 and app.rules.search_attempts==attempts and not app.completed.has("bedroom:1"),"one cast cost and one used opportunity, no cancelled reward")
 check(app.intervention_feedback.headline.text.contains("中断"),"visible outcome states cancellation")
 await capture("04_paid_interrupt")
 clear_dialogue()
 check(await wait_for(func():clear_dialogue();return app.rules.search_active,4),"host can autonomously retry instead of becoming player-controlled")
 check(app.rules.search_attempts==attempts+1 and app.rules.search_elapsed<app.rules.search_duration,"same-point retry uses new time and opportunity")
 app.rules.skin_resistance=app.rules.skin_power
 before=app.rules.neurons
 await seconds(2.1);clear_dialogue()
 if not app.rules.search_active:
  app.rules.cancel_search();app.rules._completed_targets.clear();app.completed.clear();app.target_index=-1
  await wait_for(func():clear_dialogue();return app.rules.search_active,5)
 await cast_by_mouse()
 await wait_for(func():return app.rules.pending_neural.is_empty() and app.closing_left<=0,1)
 check(app.intervention_feedback.headline.text.contains("抵抗") and app.rules.search_active,"equal resistance is visible and leaves real search active")
 check(app.rules.neurons==before-1,"resisted real input still pays once")
 await capture("05_resisted")
 app.paused_manual=true;clear_dialogue();app.menu.close_menu();app.closing_left=0
 app.reduced_effects=false;app.view_controls.miniature=false
 await frames(3);await capture("06_focus_off")
 app.view_controls.miniature=true
 await frames(3);await capture("07_focus_on")
 check(app.view_controls.focus.visible,"miniature simulation affects world viewport only")
 app.reduced_effects=true;await frames(3)
 check(not app.view_controls.focus.visible,"reduced feedback disables focus blur")
 app.paused_manual=false;app.rules.cancel_search();app.target_index=-1
 var camera_before:Vector2=app.camera.position
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_MIDDLE;down.pressed=true;down.position=Vector2(650,340)
 Input.parse_input_event(down);await frames(2)
 var motion:=InputEventMouseMotion.new();motion.position=Vector2(750,380);motion.relative=Vector2(100,40);motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE
 Input.parse_input_event(motion);await frames(2)
 down.pressed=false;Input.parse_input_event(down);await frames(2)
 check(app.view_controls.manual_view and not app.view_controls.dragging and app.camera.position!=camera_before,"middle drag actually pans and releases without a gameplay click")
 await click_position(body_point())
 check(app.menu.visible and app.menu.panel_mode=="cast","body click remains aligned after actual camera pan")
 await click(button(app.menu,"关闭 ×"));await seconds(.3);clear_dialogue()
 for index in range(4):
  app.zoom_index=index;app.camera.zoom=Vector2.ONE*app.BASE_ZOOM*app.ZOOM_STEPS[index]
  await frames(2);await click_position(body_point())
  check(app.menu.visible and app.menu.panel_mode=="cast","body click matches projected host at existing zoom tier "+str(index))
  await click(button(app.menu,"关闭 ×"));await seconds(.3);clear_dialogue()
 app.reset_zoom();check(not app.view_controls.manual_view,"reset restores automatic framing")
 app.paused_manual=true
 app.unlock_hospital()
 check(app.arrival_left>0 and app.session.data.receipts.has("hospital_first_arrival"),"first hospital arrival schedules one nonverbal look-around without invented dialogue")
 var arrival:float=app.arrival_left;await seconds(.3)
 check(app.arrival_left==arrival,"arrival observation freezes during manual pause")
 var saved:Dictionary=app.snapshot_data()
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(saved))) and is_equal_approx(app.arrival_left,arrival),"mid-arrival JSON restores remaining observation")
 app.paused_manual=false;await seconds(2.0)
 check(app.arrival_left<=0,"arrival ends and releases autonomous action")
 await capture("08_hospital_arrival")
 app.unlock_hospital();check(app.arrival_left<=0,"already observed hospital arrival does not replay")
 clear_dialogue();app.family.enabled=true;app.rules.sp=70
 app.family.data.father.present=true;app.family.data.father.phase="approach"
 app.family.data.gift_wait=5;app.family.data.picking_gift=true
 check(not app.family.present("father") and not app.family.busy() and app.family.world_rate()==1.0,"historical home parent/gift state cannot freeze or slow hospital world")
 before=app.rules.neurons;var clusters:int=app.rules.plexus
 await click(button(app,"物品栏"))
 await click(app.menu.inventory_buttons.porridge)
 check(not app.menu.visible and app.rules.owners[item]=="hero" and app.rules.neurons==before,"inventory use closes window but does not prepay unfinished swallow")
 check(await wait_for(func():return app.rules.owners[item]=="consumed",2.5),"actual swallow finishes after requested inventory use")
 check(app.rules.sp==100 and app.rules.neurons==before+5 and app.rules.plexus==clusters+1,"porridge settles exactly original completed effects once")
 app.family.enabled=false;clear_dialogue()
 await click(button(app,"物品栏"))
 check(app.menu.inventory_buttons.porridge.disabled and not app.family.data.inventory.has(item),"consumed item leaves inventory and cannot be requested again")
 await capture("09_after_actual_swallow")
 await finish_feedback()
