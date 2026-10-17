extends "res://tests/combat_chapter_check.gd"
class RejectingStore extends "res://scripts/core/achievement_store.gd":
 func grant_event(_keys:Array,_event_id:String) -> Dictionary:return {"ok":false,"error":"declared write-failure fixture"}

func unlocked(key:String) -> bool:
 var p:Dictionary=app.achievements.load_progress()
 return p.ok and p.data.unlocked.has(key)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_props_20261018/achievements"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="真实事件成就验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false
 check(app.achievements.load_progress().data.unlocked.is_empty(),"new profile and tutorial do not invent actual-event achievements")
 var demo=app.NeuralRules.new();demo.tutorial_demo=true;demo.achievement_requested.connect(app.queue_event_achievement)
 demo.record_awakening("parents_collapse");demo.recognize();demo.control_ms=119999;demo.control_left=1;demo.tick(.01)
 check(app.achievements.load_progress().data.unlocked.is_empty(),"tutorial demo awakening, recognition and clock never grant global achievements")
 app.rules.sp=0;app._process(0);app.rules.sp=100
 check(not unlocked("first_death") and not unlocked("first_awakening"),"low spirit and standing are neither actual death nor formal awakening")
 var invalid:Dictionary=app.rules.submit_skill("CONTROL",{})
 check(not invalid.ok and not unlocked("control_resisted"),"locked or invalid CONTROL is not resisted takeover")
 app.rules.neurons=50;app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.power=1;app.rules.skill_states.CONTROL.resistance=0;app.rules.global_resistance=0
 var c:int=app.rules.plexus;var result:Dictionary=app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 check(result.ok and result.success and app.rules.control_left>0 and not unlocked("first_control_action"),"successful takeover standing alone does not grant actual-action achievement")
 var standing:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 var before:Vector2=app.hero_pos;var target:Vector2=before+Vector2(.3,0)
 if not app.layout.walkable(target):target=before+Vector2(0,.3)
 app.controlled_route=true;app.hero_route=app.layout.path(before,target);app.move_hero(.1)
 check(app.hero_pos.distance_to(before)>.0001 and unlocked("first_control_action"),"real controlled movement grants physical-action achievement")
 var neurons:int=app.rules.neurons;var digest:String=FileAccess.get_sha256(ProjectSettings.globalize_path(app.achievements.path()))
 app.rules.record_control_action("navigation","floor")
 check(FileAccess.get_sha256(ProjectSettings.globalize_path(app.achievements.path()))==digest and app.rules.neurons==neurons and app.rules.plexus==c,"repeat callbacks do not rewrite achievement or grant resources")
 check(app.restore_snapshot(standing) and unlocked("first_control_action"),"loading pre-action profile cannot roll back independent global union")
 app.set_process(false);app.rules.end_control();app.rules.skill_states.CONTROL.until=0;app.rules.skill_states.CONTROL.resistance=1
 neurons=app.rules.neurons;result=app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 check(result.ok and not result.success and app.rules.neurons==neurons-int(app.rules.spec("CONTROL").cost) and unlocked("control_resisted"),"valid resisted CONTROL still pays original cost and grants only resisted event")
 neurons=app.rules.neurons;app.rules.awareness_stage=2;app.rules.recognize()
 check(unlocked("exposed_player") and app.rules.neurons==neurons,"actual recognize transition grants exposure without altering resource rules")
 app.rules.control_ms=119999;app.rules.control_fraction_ms=0;app.rules.control_left=1;app.rules.gripped=true;app.rules.tick(.05)
 check(app.rules.control_ms==119999 and not unlocked("self_erased"),"blocked control interval cannot unlock effective-time achievement")
 app.rules.gripped=false;app.rules.tick(.001)
 check(app.rules.control_ms==120000 and unlocked("self_erased"),"exact 120000 effective milliseconds grants original self-erasure achievement")
 app.family.enabled=true;app.family.spawn("mother");app.family.spawn("father");app._process(0)
 check(unlocked("first_death") and unlocked("parent_collapse_death") and unlocked("first_awakening"),"actual collapse handler can grant death, cause and formally registered awakening together")
 digest=FileAccess.get_sha256(ProjectSettings.globalize_path(app.achievements.path()));app._process(0);app.rules.record_awakening("parents_collapse")
 check(FileAccess.get_sha256(ProjectSettings.globalize_path(app.achievements.path()))==digest,"paused death and repeated awakening do not duplicate global settlement")
 var store=app.achievements;app.achievements=RejectingStore.new();app.achievements.root=store.root
 app.rules.awareness_stage=2;app.rules.recognize()
 check(not app.session.data.get("pending_event_achievements",[]).is_empty(),"failed global write keeps an actual pending event")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved) and not app.session.data.get("pending_event_achievements",[]).is_empty(),"pending event survives profile JSON independently of store failure")
 app.set_process(false);app.achievements=store;app.achievement_retry_left=0
 for i in range(12):app.flush_event_achievements()
 check(app.session.data.pending_event_achievements.is_empty() and unlocked("exposed_player"),"pending event retries against restored store without duplicate rewards")
 var separate=app.Achievements.new();separate.root=store.root
 check(separate.load_progress().data.unlocked.size()==7 and separate.DEFINITIONS.size()==12,"seven new actual-event hooks preserve original twelve definitions and cross-profile global store")
 check(not store.grant_event(["player_wins"],"invalid-entry").ok and not store.grant(["first_death"],"invalid-e1","fixture").ok,"event and ending grant APIs retain their separate whitelists")
 var legacy=app.Achievements.new();legacy.root=store.root.path_join("legacy_backfill");app.achievements=legacy
 var previous_observations:Array=app.rules.observations.duplicate(true);neurons=app.rules.neurons
 app.restore_event_achievements()
 check(unlocked("first_awakening") and unlocked("exposed_player") and unlocked("self_erased") and unlocked("control_resisted"),"older valid saved counters and facts can backfill their global achievements")
 check(not unlocked("first_control_action") and app.rules.observations==previous_observations and app.rules.neurons==neurons,"saved control intent cannot invent physical action, knowledge or resource rewards")
 app.achievements=store
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Declared resource/recognition/threshold/collapse and write-failure fixtures through real submit, physical move, restore and global-store handlers. No manufactured resource awards, tutorial progress or natural whole-game claim."},"  "));file.close()
 print("ACHIEVEMENT_EVENTS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
