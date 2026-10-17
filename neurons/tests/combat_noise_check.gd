extends "res://tests/combat_chapter_check.gd"
func count(kind:String) -> int:
 var n:int=0
 for fact in app.rules.facts:
  if fact.kind==kind:n+=1
 return n
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_20261017/noise"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="衣架物理声源验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;app.unlock_combat();no_actors();app.enter_room("hippocampus");no_actors()
 var self_actor:Dictionary=app.combat.data.actors.self
 self_actor.present=true;self_actor.room="hippocampus";self_actor.pos=[3.7,2.95];self_actor.phase="idle";self_actor.last_seen=[];self_actor.investigation={}
 app.hero_pos=Vector2(2.6,2.95);app.hero_route=PackedVector2Array();app.rules.neurons=10
 check(app.layout.rack_rect.has_area() and app.layout.walkable(app.hero_pos),"new attempt has one physical rack and legal approach")
 check(not app.combat.can_see(app.room_id,app.combat.position("self"),app.hero_pos),"actual rack blocks initial line of sight")
 var result:Dictionary=app.rules.submit_skill("SKIN",{"direction":[1,0]});app.apply_cast();app.closing_left=0;clear_lines()
 check(result.ok and not app.motion.is_empty() and app.motion.has("impact"),"paid skin step plans a finite blocked approach")
 check(count("physical_sound")==0,"planning the path makes no premature sound")
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(snapshot) and app.motion.has("impact"),"pending real rack contact survives JSON")
 app.rules.control_left=3 # Freeze autonomous route choice, not physical motion.
 for i in range(20):app.advance_world(.025)
 check(count("physical_sound")==1,"body actually reaches rack before one collision sound")
 check(count("sound_heard")==1,"occluded nearby self hears actual source through reachable space")
 check(app.hero_pos.x<app.layout.rack_rect.position.x and app.layout.walkable(app.hero_pos),"impact stays on legal side instead of passing through rack")
 var state:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(state) and app.combat.data.rack_sound.latched,"active rack contact and latch survive JSON")
 app.layout.record_rack_contact(app.hero_pos,app.hero_pos+Vector2(.04,0));app.combat.noises.tick(.025)
 check(count("physical_sound")==1,"continuous contact cannot repeat the sound after load")
 var swing:float=app.combat.data.rack_sound.swing;await seconds(.3)
 check(app.combat.data.rack_sound.swing==swing,"menu pause freezes rack motion and sound clocks")
 app.combat.noises.tick(.8);app.layout.record_rack_contact(app.hero_pos,app.hero_pos+Vector2(.04,0));app.combat.noises.tick(.025)
 check(count("physical_sound")==2,"a new impact after settling can produce another sound")
 var before:int=count("physical_sound");app.combat.on_skill({"id":"TINNITUS","success":true,"event_id":"ear-not-source"})
 check(count("physical_sound")==before,"internal tinnitus is not an external noise lure")
 self_actor=app.combat.data.actors.self;self_actor.pos=[3.8,4.8];self_actor.phase="attack";self_actor.direction=[1,0];self_actor.elapsed=.1
 app.hero_pos=Vector2(3.2,4.9)
 check(not app.combat.noises.hear("self",app.room_id,app.layout.rack_rect.get_center(),"visible-no-lure"),"visible host takes precedence over rack sound")
 app.hero_pos=Vector2(2.6,2.95);self_actor.pos=[3.7,2.95];self_actor.investigation={};self_actor.phase="windup";self_actor.direction=[1,0]
 check(app.combat.noises.hear("self",app.room_id,app.layout.rack_rect.get_center(),"source-only"),"new real occluded source can be inspected")
 check(self_actor.phase=="windup" and self_actor.direction==[1,0] and self_actor.investigation.has("source_at"),"heard noise does not cancel launched direction or reveal later host position")
 await capture("01_rack_contact")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Production paid SKIN, motion/contact/latch/hearing/LOS/pause/JSON with declared geometry/actor/CONTROL-duration fixtures; not natural full game or subjective sound acceptance."},"  "));file.close()
 print("COMBAT_NOISE_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
