extends "res://tests/combat_chapter_check.gd"
## Declared clear-floor, aligned contacts and visible observer fixtures.
const Bed=preload("res://scripts/core/bed_body.gd")
const Space=preload("res://scripts/world/combat_layout.gd")

func clear_floor() -> void:
 no_actors();clear_lines();app.layout.furniture.clear();app.layout.rebuild_grid()
 app.rules.hurt_left=0;app.rules.reaction_left=0;app.rules.action.clear();app.rules.gripped=false;app.rules.end_control()
 app.hero_route=PackedVector2Array();app.motion.clear();app.combat.data.face_pending={}

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/combat_continue_20261017/details"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="第五关动作细节验证";frontend.overwrite_armed=true;frontend.new_game()
 await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();clear_floor()
 var floor=Space.new("atrium");floor.furniture.clear();floor.rebuild_grid()
 var diagonal:Vector2=Vector2(1,1).normalized()
 check(Bed.touches(Vector2(4,3),diagonal,Vector2(4,3)+diagonal*1.5,.21),"diagonal bed uses actual oriented footprint")
 check(not Bed.touches(Vector2(4,3),diagonal,Vector2(5.5,2.8),.05),"empty AABB corner is not a bed hit")
 floor.furniture.assign([{"rect":Rect2(3,2.8,.03,.4)}])
 var sweep:Dictionary=Bed.sweep(floor,Vector2(.5,3),Vector2(7,3),Vector2.RIGHT,Vector2.RIGHT)
 check(not sweep.complete and sweep.position.x<1.2,"full translation sweep cannot tunnel through thin furniture")
 floor.furniture.assign([{"rect":Rect2(6.1,4.1,.12,.12)}])
 check(Bed.clear(floor,Vector2(5,3),Vector2.RIGHT) and Bed.clear(floor,Vector2(5,3),Vector2.DOWN),"rotation fixture endpoints both actually clear")
 sweep=Bed.sweep(floor,Vector2(5,3),Vector2(5,3),Vector2.RIGHT,Vector2.DOWN)
 check(not sweep.complete,"turn sweep rejects intermediate corner collision")
 var to:String=str(app.CombatMap.doors(app.room_id)[0]);var portal:Dictionary=app.layout.portal(to)
 check(Bed.clear(app.layout,portal.threshold,-Vector2(portal.inward),app.combat.bed_portals(app.room_id)),"aligned bed fits real 1.2m portal opening")
 check(not app.combat.bed_clear("atrium",Vector2(.25,2),Vector2.LEFT),"bed cannot protrude through a non-door wall")
 contact("assistant",Vector2(2,3),Vector2.RIGHT)
 var assistant:Dictionary=app.combat.data.actors.assistant
 assistant.phase="attack";assistant.elapsed=0;app.hero_pos=Vector2(4.1,3)
 var hp:int=app.rules.hp;var initial:Vector2=app.hero_pos
 for i in range(25):app.combat._advance_attack("assistant",.025)
 check(app.rules.hp==hp-20 and app.hero_pos.x>initial.x,"actual bed contact damages once and physically pushes host")
 var after:Vector2=app.combat.position("assistant")
 check(assistant.phase=="recover" and float(assistant.get("retreat_left",0))>0,"bed stops after impact and schedules physical retreat")
 for i in range(40):app.combat._actor("assistant",.025)
 check(app.combat.position("assistant").x<after.x,"bed actually backs away instead of holding the doorway")
 clear_floor();contact("assistant",Vector2(2,3),Vector2.RIGHT);assistant=app.combat.data.actors.assistant
 assistant.phase="attack";assistant.hp=0;app.hero_pos=Vector2(8,5);initial=app.combat.position("assistant")
 app.combat._actor("assistant",.1)
 check(app.combat.position("assistant").x>initial.x,"already launched bed continues when pusher dies")
 assistant.phase="idle"
 check(app.combat.bed_blocks(app.room_id,app.combat.position("assistant")+Vector2(1,0),.21),"stopped physical bed remains after pusher death")
 clear_floor();app.hero_pos=Vector2(7,5)
 to=str(app.CombatMap.doors(app.room_id)[0]);portal=app.layout.portal(to)
 var receiving=app.combat.floor_for(to);receiving.furniture.clear();receiving.rebuild_grid()
 contact("assistant",portal.threshold,-Vector2(portal.inward));assistant=app.combat.data.actors.assistant
 assistant.phase="idle";assistant.follow=to
 app.combat._actor("assistant",.025)
 check(assistant.room==to and app.combat.bed_clear(to,app.combat.position("assistant"),app.combat.vector(assistant.direction)),"same assistant and bed cross only after destination clearance")
 contact("assistant",portal.threshold,-Vector2(portal.inward));assistant=app.combat.data.actors.assistant;assistant.phase="idle";assistant.follow=to
 var entry:Dictionary=receiving.portal(app.room_id)
 receiving.furniture.append({"rect":Rect2(entry.landing+Vector2(entry.inward)*.7-Vector2(.6,.6),Vector2(1.2,1.2))});receiving.rebuild_grid()
 app.combat._actor("assistant",.025)
 check(assistant.room==app.room_id and assistant.follow=="" and float(assistant.get("retreat_left",0))>0,"blocked bed doorway keeps one entity and schedules retreat")
 clear_floor();app.hero_pos=Vector2(4,3);contact("double_head",Vector2(5,3),Vector2.LEFT)
 var head:Dictionary=app.combat.data.actors.double_head
 head.phase="idle";head.hostile=false
 app.combat._actor("double_head",.025)
 check(head.phase=="idle" and not head.hostile,"passing neutral double-head does not cause attack or self damage")
 head.hostile=true;head.phase="recover";head.elapsed=.59;head.home=[5,3]
 app.combat._advance_attack("double_head",.025)
 check(not head.hostile and head.phase=="idle","one retaliation ends by restoring neutral state")
 head.hostile=true;head.phase="idle";head.last_seen=[5,3];head.last_seen_at=-10;app.hero_pos=Vector2(10.7,6.7)
 app.combat._actor("double_head",.025)
 check(not head.hostile,"lost-target retaliation ends after actual last-position check")
 clear_floor();app.hero_pos=Vector2(3.8,3);contact("twitch",Vector2(3,3),Vector2.RIGHT)
 var twitch:Dictionary=app.combat.data.actors.twitch;twitch.phase="idle";twitch.cooldown=0;app.combat.data.next_attack=0
 app.combat._actor("twitch",.025)
 check(twitch.phase=="windup" and not twitch.echo_knee,"no successful knee history means no invented knee echo")
 app.rules._record("skill_reacted","declared-historical-knee-fixture",{"skill":"KNEE"})
 app.combat._advance_attack("twitch",.21)
 check(twitch.tap_count==1 and not twitch.echo_knee,"first heel tap adjusts once and does not reread mid-windup history")
 app.combat._advance_attack("twitch",.5);var locked:Vector2=app.combat.vector(twitch.direction)
 app.hero_pos=Vector2(3,4.3);app.combat._advance_attack("twitch",.5)
 check(twitch.tap_count==2 and app.combat.vector(twitch.direction).is_equal_approx(locked),"second heel tap locks the actual charge direction")
 clear_floor();app.hero_pos=Vector2(4,3);contact("double_face",Vector2(5,3),Vector2.LEFT)
 var watcher:Dictionary=app.combat.data.actors.double_face
 watcher.phase="idle";watcher.hostile=false;watcher.face_turned=false;watcher.face_turn_progress=0
 var reaction=app.combat.reactions
 reaction.on_skill({"id":"SKIN","event_id":"resisted","success":false});reaction.tick(.2)
 check(not watcher.face_turned and app.combat.data.face_pending.is_empty(),"resisted intervention cannot turn the witnessed face")
 app.rules.control_left=1.0
 reaction.on_skill({"id":"CONTROL","event_id":"takeover","success":true});reaction.tick(.1)
 check(not watcher.face_turned and not app.combat.data.face_pending.turning,"control takeover alone is not a visible execution")
 app.hero_pos+=Vector2(.1,0);reaction.tick(.1)
 check(float(watcher.face_turn_progress)>0 and not watcher.face_turned,"actual controlled movement begins finite visible turn")
 var turn:float=watcher.face_turn_progress;await seconds(.25)
 check(is_equal_approx(watcher.face_turn_progress,turn),"menu pause freezes the partially completed face turn")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved),"partial witness and turn state survive real JSON")
 watcher=app.combat.data.actors.double_face
 app.layout.furniture.clear();app.layout.rebuild_grid();reaction=app.combat.reactions
 reaction.tick(.4)
 check(watcher.face_turned and app.combat.data.visible_casts.has("takeover"),"continued actual turn completes one observed cast receipt")
 var facts:int=app.rules.facts.size();reaction.tick(.5)
 check(app.rules.facts.size()==facts,"completed face turn does not duplicate observations or dialogue")
 clear_lines();app.rules.end_control();watcher.face_turned=false;reaction.on_skill({"id":"GUT","event_id":"hurt-turn","success":true})
 app.rules.reaction_skill="GUT";app.rules.reaction_left=.5;reaction.tick(.1);watcher.hurt=.25;reaction.tick(.1)
 check(not watcher.face_turned and app.combat.data.face_pending.is_empty(),"actual damage interrupts turn without queued replay")
 watcher.hurt=0;app.rules.reaction_left=0;app.layout.furniture.assign([{"rect":Rect2(4.5,2,.2,2)}]);app.layout.rebuild_grid()
 reaction.on_skill({"id":"GUT","event_id":"wall","success":true})
 check(app.combat.data.face_pending.is_empty(),"wall prevents witness even for a successful intervention")
 app.enter_room("memory");clear_floor();app.hero_pos=Vector2(4,3)
 var nurse:Dictionary=app.combat.data.actors.nurse;nurse.present=true;nurse.pos=[4.6,3];nurse.phase="bandage"
 app.combat.data.bandage_elapsed=1;app.combat.data.spoken.erase("nurse")
 contact("archivist",Vector2(5.5,3),Vector2.LEFT);app.combat.reactions.tick(.1)
 check(app.dialogue_queue.is_empty(),"active pursuit defers original friendly garbled line")
 app.combat.data.actors.archivist.present=false;app.combat.reactions.tick(.1)
 check(not app.dialogue_queue.is_empty() and app.combat.data.spoken.has("nurse"),"safe real contact dispatches exact nurse line once")
 clear_lines();app.combat.reactions.tick(.1)
 check(app.dialogue_queue.is_empty(),"same-attempt friendly line cannot repeat")
 app.combat.data.spoken.erase("nurse");nurse.hp=0;app.combat.reactions.tick(.1)
 check(app.dialogue_queue.is_empty(),"retired speaker never delivers deferred line")
 app.enter_room("body");no_actors();clear_lines();app.hero_pos=Vector2(7.5,4.5)
 assistant=app.combat.data.actors.assistant;assistant.room="body";assistant.pending=true;assistant.present=false;assistant.hp=60;assistant.phase="idle";assistant.retreat_left=0
 app.combat.data.last_spawn.erase("body");app.combat._spawn()
 check(assistant.present and not assistant.pending and app.combat.bed_clear("body",app.combat.position("assistant"),app.combat.vector(assistant.direction)),"real body-room doorway can spawn the pusher with one legal physical bed")
 await capture("01_visible_contact")
 var result={"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Production contact, geometry, reaction, pause and JSON paths with explicit clear-floor, positioned NPC, health and visible-cast fixtures. No full natural branch/art/audio acceptance."}
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("COMBAT_DETAIL_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
