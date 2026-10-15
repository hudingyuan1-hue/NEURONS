extends Node
var frontend
var app
var tutor
var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/b1_20261015/tutorial"

func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)

func frames(count:int=3) -> void:
 for i in range(count):await get_tree().process_frame

func capture(name:String) -> void:
 await frames();await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(folder).path_join(name+".png"))

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();frontend.show_profile();await frames()
 frontend.name_field.text="教程沙盒验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 tutor=app.tutorial_ui
 check(tutor!=null and tutor.demo!=app.rules,"new-game tutorial has its own rule object")
 await frames(65)
 check(tutor.stage==1 and app.rules.world_time==0,"bedside introduction uses UI time while formal world stays frozen")
 await capture("01_practice_body")
 tutor.open_body(MOUSE_BUTTON_LEFT)
 check(tutor.stage==2 and tutor.terminal.visible,"actual left-body handler opens same CRT component")
 tutor.terminal.nodes.SKIN.mouse_entered.emit();await frames(24)
 check(tutor.stage==3 and not tutor.terminal._description.text.is_empty(),"actual bright-node hover prints description before locked-node lesson")
 tutor.terminal.nodes.SKIN.mouse_exited.emit();tutor.terminal.nodes.GUT.mouse_entered.emit();await frames(63)
 check(tutor.stage==4 and tutor.demo.neurons==5,"two-second locked hover advances guidance without payment")
 await capture("02_hover_and_coin")
 tutor.terminal.nodes.SKIN.pressed.emit();await frames(4)
 tutor.manual_paused=true;await frames(12)
 check(tutor.stage==5 and not tutor.demo.pending_neural.is_empty() and tutor.demo.reaction_left==0,"practice pause during close defers actual body reaction")
 check(app.rules.neurons==5 and app.rules.plexus==3 and app.rules.world_time==0,"practice payment never touches formal resources or clock")
 tutor.manual_paused=false;await frames(19)
 check(tutor.stage==6 and tutor.demo.skin_reactions==0 and tutor.demo.evidence.is_empty(),"completed skin reaction produces no adaptation or cognition progress")
 await capture("03_body_response")
 tutor.next.pressed.emit()
 tutor.open_body(MOUSE_BUTTON_LEFT)
 check(tutor.stage==7 and not tutor.terminal.visible,"right-body lesson cannot be bypassed with left click")
 tutor.open_body(MOUSE_BUTTON_RIGHT)
 check(tutor.stage==8 and tutor.terminal.panel_mode=="tree","actual right-body handler opens freezer")
 tutor.terminal.tree_nodes.GUT.pressed.emit();await frames(2)
 check(tutor.stage==9,"star-node inspection precedes confirmation")
 tutor.terminal.tree_action("unlock")
 check(tutor.stage==10 and tutor.demo.skill_states.GUT.unlocked and tutor.demo.plexus==2,"practice star unlock pays one practice cluster")
 check(not app.rules.skill_states.GUT.unlocked and app.rules.plexus==3,"model preview and practice unlock never unlock formal skill")
 await capture("04_star_unlock_preview");await frames(65)
 check(tutor.stage==11,"two-second UI-only preview completes before exit instruction")
 var history:Array=tutor.history.duplicate()
 tutor.close_terminal();await frames()
 check(app.tutorial_ui==null and app.profile.tutorial_completed,"closing after full lesson returns to formal game")
 check(app.rules.neurons==5 and app.rules.plexus==3 and app.rules.control_ms==0 and app.rules.evidence.is_empty(),"formal start remains exactly five N, three C, no tutorial progress contamination")
 for required in range(12):check(required in history,"tutorial order includes stage %d"%required)
 var saved:Dictionary=app.store.load_snapshot()
 check(saved.ok and saved.data.profile.tutorial_completed and saved.data.rules.neurons==5,"actual formal save records completion without reissuing initial resources")
 app.open_tutorial(true);await frames()
 check(app.tutorial_ui.guide_only and not app.tutorial_ui.detail.text.contains("120000") and not app.tutorial_ui.detail.text.contains("宿主"),"free guide remains accessible without hidden identity or loss threshold")
 app.tutorial_ui.finish();await frames()
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":true,"scope":"real tutorial UI handlers/clock with independent practice state; no voice/art acceptance"},"  "))
 print("TUTORIAL_CHECK %d passed %d failed"%[passes.size(),failures.size()])
 get_tree().quit(0 if failures.is_empty() else 1)
