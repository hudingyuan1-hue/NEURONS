extends "res://tests/family_check.gd"
## Household setup uses fixed handlers; the lying-body/menu/interrupt segment
## uses actual viewport mouse/key events and the ordinary world process.

func click_at(point:Vector2,which:int=MOUSE_BUTTON_LEFT) -> void:
 var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
 await frames(2)
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=which;event.pressed=down
  Input.parse_input_event(event);await frames(2)

func body_click(which:int) -> void:
 var point:Vector2=(app.world_viewport.get_canvas_transform()*app.view.hero_body_rect().get_center())*2.0
 await click_at(point,which)

func find_button(root:Node,text:String) -> Button:
 for child in root.get_children():
  if child is Button and child.text.contains(text):return child
  var found:Button=find_button(child,text)
  if found!=null:return found
 return null

func _ready() -> void:
 folder="res://../docs/validation/status_20261015/rest-input"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames();frontend.name_field.text="卧床实际点击验证"
 frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 fixture();app.rules.sp=80;app.family.spawn("mother");give_skill("GUT")
 check(until(func():return app.action_phase=="resting" and app.family.data.mother.get("bed_line_shown",false)),"normal mother route reaches lying/body-caption phase")
 var position:Vector2=app.hero_pos
 await frames(2) # Rendering/UI sync follows the fixed handler setup.
 check(app.view.self_modulate.r<1.0 and float(app.view.rest_pose().t)>0.99,"actual rendered bedroom dims only after lying down")
 await capture("01_lying_before_intervention")
 clear_lines();app.paused_manual=false;get_window().grab_focus();await frames(1)
 await body_click(MOUSE_BUTTON_RIGHT)
 check(app.menu.visible and app.menu.panel_mode=="tree" and app.action_phase=="resting","right-click actual lying body opens freezer before rest completes")
 var remaining:float=app.action_left
 var clock:float=app.rules.world_time
 await frames(20)
 check(app.action_left==remaining and app.rules.world_time==clock,"menu freezes remaining rest and presentation instead of finishing unlock behind UI")
 var saved:Dictionary=app.snapshot_data()
 check(app.store.save_snapshot(saved).ok,"lying body/menu writes actual JSON save")
 var disk:Dictionary=app.store.load_snapshot()
 check(disk.ok and app.restore_snapshot(disk.data) and app.menu.visible and app.action_phase=="resting" and is_equal_approx(app.action_left,remaining),"load restores lying pose and freezer without premature rest completion")
 await capture("02_freezer_during_saved_rest")
 var close:Button=find_button(app.menu,"CLOSE")
 await click_at(close.get_global_rect().get_center())
 for i in range(15):
  if app.closing_left<=0:break
  await frames(1)
 await body_click(MOUSE_BUTTON_LEFT)
 check(app.menu.visible and app.menu.panel_mode=="cast" and app.action_phase=="resting","left-click lying body opens CRT at mapped body position")
 var neurons:int=app.rules.neurons
 await click_at(app.menu.nodes.GUT.get_global_rect().get_center())
 for i in range(100):
  if app.rules.reaction_skill=="GUT" and app.rules.reaction_left>0:break
  await frames(1)
 check(app.rules.reaction_skill=="GUT" and app.action_phase=="autonomy" and app.family.data.mother.phase=="leave","real GUT click interrupts unfinished rest and current persuasion")
 check(app.rules.neurons==neurons-int(app.rules.spec("GUT").cost) and app.session.data.level==1 and app.session.data.cycle==1,"interrupt pays configured skill once and cannot award rest/unlock early")
 check(app.rules.owners.get(app.family.food_id("porridge"),"")=="hero" and app.hero_pos==position,"already-delivered porridge survives interruption; presentation offset never teleports logical position")
 await capture("03_actual_rest_interruption")
 var result:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"fixed mother setup, actual lying-body viewport keys/buttons, normal paused world, JSON restore, actual GUT interruption; no full B1 acceptance"},"  "));result.close()
 print("REST_INPUT_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 frontend.request_exit(0 if failures.is_empty() else 1)
