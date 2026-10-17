extends "res://tests/combat_chapter_check.gd"
## Real geometry/inputs with funded CONTROL and no-NPC fixtures.
func prop_index(id:String) -> int:
 for i in range(app.layout.furniture.size()):
  if str(app.layout.furniture[i].id)==id:return i
 return -1

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/combat_continue_20261017/evidence"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="深部现场查看验证";frontend.overwrite_armed=true;frontend.new_game()
 await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;app.unlock_combat();app.home.enabled=false;app.family.enabled=false;no_actors()
 app.enter_room("basal");no_actors();clear_lines()
 var obs=app.combat.observations
 var index:int=prop_index("路径终端")
 check(index>=0,"source-defined path terminal actually exists")
 check(not obs.begin(index,true),"uncontrolled click cannot command inspection")
 app.rules.neurons=30;app.rules.plexus=30
 for skill in app.rules.config.skills:
  if skill.id!="SKIN" and not app.rules.skill_states[skill.id].unlocked:app.rules.unlock(str(skill.id))
 var cast:Dictionary=app.rules.submit_skill("CONTROL",app.skill_context());app.apply_cast();app.closing_left=0;clear_lines()
 var n:int=app.rules.neurons;var c:int=app.rules.plexus
 check(cast.ok and app.rules.control_left>0,"inspection uses existing paid control instead of free steering")
 var prop:Dictionary=app.layout.furniture[index]
 var point:Vector2=app.layout.project(prop.rect.get_center())-Vector2(0,float(prop.height)*.5)
 check(app.view.furniture_at_pixel(point)==index,"terminal visible silhouette resolves the correct target")
 app.paused_manual=false;await frames(3)
 var shift:=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.pressed=true;Input.parse_input_event(shift)
 var pixel:Vector2=app.world_viewport.get_canvas_transform()*point
 await click_position(pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
 shift=InputEventKey.new();shift.keycode=KEY_SHIFT;shift.pressed=false;Input.parse_input_event(shift)
 check(not app.combat.data.inspection.is_empty(),"actual Shift mouse input starts approach to physical terminal")
 check(await wait_for(func():return app.combat.data.inspected.get("basal_records",{}).has("路径终端"),10),"real route reaches terminal and finishes original and final-field reading")
 app.paused_manual=true
 check(app.rules.neurons==n and app.rules.plexus==c and app.rules.search_attempts==0,"optional evidence gives no search income or new opportunity")
 var fact:Dictionary={}
 for entry in app.rules.facts:
  if entry.kind=="combat_evidence_read" and entry.prop=="路径终端":fact=entry
 check(fact.get("records",[]).size()==2 and fact.records[0].identity==null and fact.records[1].time==null,"two source records stay separate with unknown identity and time")
 check(fact.get("records",[]).size()==2 and fact.records[1].original_choice=="拒绝" and fact.records[1].final_stamp=="同意","observed refusal and institutional consent remain distinct")
 await capture("01_completed_terminal")
 clear_lines();app.rules.end_control();app.enter_room("cerebellum");no_actors();app.rules.control_left=12;app.rules.control_event="evidence-json-fixture"
 obs=app.combat.observations;index=prop_index("控制终端");app.hero_pos=obs.station(app.layout.furniture[index].rect)
 check(obs.begin(index,true),"actual reachable terminal has a valid body-radius station")
 app.combat._hero(.3)
 check(not app.combat.data.inspection.is_empty() and not app.combat.data.inspected.has("cerebellum_records"),"partial contact cannot settle observation")
 var elapsed:float=app.combat.data.inspection.elapsed;await seconds(.3)
 check(app.combat.data.inspection.elapsed==elapsed,"world pause freezes reading progress")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(snapshot) and is_equal_approx(float(app.combat.data.inspection.elapsed),elapsed),"half-read contact survives real JSON with original progress")
 obs=app.combat.observations
 for i in range(40):app.combat._hero(.025)
 check(app.combat.data.inspected.get("cerebellum_records",{}).has("控制终端"),"continued read completes once without restarting")
 var count:int=0
 for entry in app.rules.facts:
  if entry.kind=="combat_evidence_read" and entry.prop=="控制终端":count+=1
 app.combat._hero(.3)
 var after_count:int=0
 for entry in app.rules.facts:
  if entry.kind=="combat_evidence_read" and entry.prop=="控制终端":after_count+=1
 check(count==1 and after_count==1,"finished inspection is not replayed on the next frame")
 clear_lines();app.enter_room("hypothalamus");no_actors();app.rules.control_left=12
 obs=app.combat.observations;index=prop_index("监测屏");app.hero_pos=obs.station(app.layout.furniture[index].rect);obs.begin(index,true);app.combat._hero(.2)
 app.combat._damage_hero("inspection-contact-fixture",10,0,"doctor")
 check(app.combat.data.inspection.is_empty() and not app.combat.data.inspected.has("hypothalamus_records"),"actual hit cancels incomplete reading without evidence or reward")
 clear_lines();app.rules.hurt_left=0;app.rules.end_control()
 var reachable:int=0;var expected:int=0
 for item in app.combat.config.observations:
  app.enter_room(str(item.room));no_actors()
  for id in item.props:
   expected+=1;index=prop_index(str(id))
   if index>=0 and obs.station(app.layout.furniture[index].rect).x>=0:reachable+=1
 check(reachable==expected and expected==11,"all eleven deep-room read surfaces have real reachable stations")
 check(app.combat.config.observations[1].line=="","unknown number glyph does not generate same-identity dialogue")
 check(app.audio.assets.has("SFX_COMBAT_WINDUP") and app.audio.assets.has("SFX_BED_ROLL"),"new attack preparation and bed-roll audio streams really load")
 await capture("02_interrupted_read")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"real OpenGL Shift-click, paid CONTROL, original geometry path/contact, pause, JSON and interruption; explicit resources, direct deep-room entry and NPC-disabled fixtures. No natural distribution or all branches/audio audition."},"  "));file.close()
 print("COMBAT_EVIDENCE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
