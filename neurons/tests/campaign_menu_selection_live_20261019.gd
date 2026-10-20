extends "res://tests/opening_campaign_check.gd"
## Actual mouse/key UI regression. Only fixture is a production restore of the
## unchanged actual Street exit checkpoint; unlock/fees/cast all use real UI.
var records:Array=[]

func write_json(file_name:String,value:Variant) -> void:
 var file=FileAccess.open(folder.path_join(file_name),FileAccess.WRITE)
 file.store_string(JSON.stringify(value,"  "));file.close()

func key_tap(code:Key) -> void:
 for pressed:bool in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
  Input.parse_input_event(event);await frames(3)

func hover(target:Control) -> void:
 var event:=InputEventMouseMotion.new();event.position=target.get_global_rect().get_center();event.global_position=event.position
 Input.parse_input_event(event);await frames(35)

func note(label:String) -> void:
 records.append({"label":label,"clock":app.street.data.clock,"selected":app.menu.selected_id,"direction":[app.menu.selected_direction.x,app.menu.selected_direction.y],"direction_visible":app.menu.direction_panel.visible,"description":app.menu.full_description,"status":app.menu._status.text,"neurons":app.rules.neurons,"clusters":app.rules.plexus,"pos":[app.hero_pos.x,app.hero_pos.y],"menu_visible":app.menu.visible})

func ready_for_input() -> void:
 await wait_for(func():return not app.world_paused() and app.input_lock_frames<=0,20)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/campaign_pacing_20261019/street/menu_selection_ui_r1"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="CRT实际选择与方向说明";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.dialogue_queue.clear();app.show_dialogue();app.closing_left=0
 var checkpoint:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/validation/campaign_pacing_20261019/street/exit_baseline_r1/initial_entry_fixture.json"))
 check(frontend.store.root.contains("tmp/") and app.restore_snapshot(checkpoint),"declared unchanged actual checkpoint restores into isolated save root")
 write_json("initial_snapshot.json",app.snapshot_data())
 await ready_for_input()
 var neurons:int=app.rules.neurons;var clusters:int=app.rules.plexus
 await click(button(app,"星仓"));check(app.menu.visible and app.menu.panel_mode=="tree","actual star-cabinet button opens real purchase UI")
 await click(app.menu.tree_nodes.TEMP);await frames(8)
 await click(button(app.menu.inspect_panel,"确认解锁"));await frames(10)
 check(app.rules.skill_states.TEMP.unlocked and app.rules.plexus==clusters-1 and app.rules.neurons==neurons,"actual one-cluster TEMP purchase supplies second hoverable node without free resource writes")
 await key_tap(KEY_ESCAPE);await ready_for_input()
 await key_tap(KEY_TAB)
 check(app.menu.visible and app.menu.panel_mode=="cast","actual Tab opens current CRT")
 # Preserve public explicit selection used by the existing rescue prompt.
 app.menu.describe("TEMP")
 check(app.menu.selected_id=="TEMP","public describe retains explicit rescue-prompt selection semantics")
 await click(app.menu.nodes.SKIN)
 check(app.menu.selected_id=="SKIN" and app.menu.direction_panel.visible,"actual SKIN click chooses SKIN and exposes direction controls")
 var frozen:float=app.street.data.clock
 await hover(app.menu.nodes.TEMP);note("hover_other_unlocked")
 check(app.menu.selected_id=="SKIN" and app.menu.full_description.contains("TEMP") and app.rules.neurons==neurons,"real hover previews TEMP while retaining clicked SKIN and zero fee")
 await hover(button(app.menu.direction_panel,"↑"));note("leave_preview_for_direction")
 check(app.menu.selected_id=="SKIN" and app.menu.full_description.contains("SKIN") and app.menu.full_description.contains("消耗 1 神经元") and app.menu.full_description.contains("冷却"),"real pointer entering direction area restores selected fee action and cooldown description")
 check(app.menu.selected_direction==Vector2.RIGHT,"hover does not change existing direction choice")
 await capture("01_selected_description_at_direction")
 await hover(app.menu.nodes.GUT)
 check(app.menu.full_description.is_empty() and app.menu.selected_id=="SKIN","locked node hover retains old blank-preview rule without selecting it")
 await hover(button(app.menu.direction_panel,"↑"))
 check(app.menu.full_description.contains("SKIN") and app.menu.selected_id=="SKIN","leaving locked preview restores selected node")
 await click(button(app.menu.direction_panel,"取消方向"));note("actual_direction_cancel")
 check(not app.menu.direction_panel.visible and app.menu.full_description.contains("SKIN") and app.rules.neurons==neurons and app.rules.pending_neural.is_empty(),"actual cancel keeps selected information and charges nothing")
 check(is_equal_approx(frozen,float(app.street.data.clock)),"real pointer preview direction and cancel preserve ordinary menu world freeze")
 await capture("02_actual_cancel_keeps_description")
 await click(app.menu.nodes.SKIN)
 await hover(app.menu.nodes.TEMP)
 await hover(button(app.menu.direction_panel,"↑"))
 await click(button(app.menu.direction_panel,"↑"))
 check(await wait_for(func():return not app.menu.visible and app.closing_left<=0 and app.rules.pending_neural.is_empty(),3),"actual selected-direction click closes CRT and resolves through production cast handler")
 await frames(10);note("actual_skin_resolved")
 var submissions:Array=[]
 for fact:Dictionary in app.rules.facts:
  if fact.get("kind","")=="skill_submitted":submissions.append(fact)
 check(submissions.size()==1 and str(submissions[0].skill)=="SKIN" and int(submissions[0].cost)==1 and app.rules.neurons==neurons-1,"hovering TEMP did not swap real cast; exactly one SKIN receipt charges one neuron")
 check(float(app.rules.effects.get("TEMP",0))<=0 and app.menu.selected_direction==Vector2.UP,"actual direction is north and previewed TEMP has not been applied")
 await ready_for_input();await key_tap(KEY_TAB)
 check(app.menu.visible and app.menu.full_description.contains("SKIN"),"actual close and reopen regenerate selected information")
 await click(app.menu.nodes.SKIN)
 await hover(app.menu.nodes.TEMP)
 await hover(button(app.menu.direction_panel,"↑"))
 var characters_before_refusal:int=app.menu._description.visible_characters
 await click(button(app.menu.direction_panel,"↑"));await frames(8);note("actual_cooldown_refusal")
 check(app.menu.visible and app.menu._status.text.contains("冷却") and app.menu.full_description.contains("SKIN") and app.menu.full_description.contains("冷却") and app.rules.neurons==neurons-1,"actual cooldown refusal retains selected cost action cooldown text and adds no charge")
 check(app.menu._description.visible_characters>=characters_before_refusal,"actual refusal does not restart and hide the already-visible selected description")
 await capture("03_actual_cooldown_refusal_keeps_description")
 await click(button(app.menu.direction_panel,"取消方向"));await key_tap(KEY_ESCAPE);await ready_for_input();await key_tap(KEY_TAB)
 check(app.menu.visible and app.menu.selected_id=="SKIN" and app.menu.full_description.contains("SKIN") and app.rules.neurons==neurons-1,"actual cancel close reopen preserves selection without another payment")
 await capture("04_actual_reopen_selected")
 note("finished");write_json("records.json",records);write_json("final_snapshot.json",app.snapshot_data())
 write_json("result.json",{"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Actual mouse across unlocked/locked nodes, selected direction, cancel, successful one-neuron SKIN, cooldown refusal, close and reopen. Actual TEMP purchase1C; only direct UI call is compatibility check of public describe used by rescue prompt. No resources/skill/RNG/NPC/route/position/damage writes after production checkpoint restore; not a full campaign or artwork/audio acceptance."})
 print("CAMPAIGN_MENU_SELECTION_LIVE ",passes.size()," passed ",failures.size()," failed")
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
