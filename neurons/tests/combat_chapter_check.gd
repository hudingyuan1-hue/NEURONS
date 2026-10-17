extends "res://tests/opening_campaign_check.gd"
## Finite real handlers and geometry; explicit actor/contact fixtures, not full play.
var routes:int=0

func clear_lines() -> void:app.dialogue_queue.clear();app.show_dialogue()
func step(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.advance_world(.025)
func no_actors() -> void:
 for id in app.combat.data.actors:
  app.combat.data.actors[id].present=false;app.combat.data.actors[id].pending=false
func contact(id:String,at:Vector2,direction:Vector2) -> void:
 var a:Dictionary=app.combat.data.actors[id]
 a.hurt=0.0;a.retreat_left=0.0;a.follow=""
 a.present=true;a.pending=false;a.room=app.room_id;a.pos=app.combat.xy(at);a.hp=80;a.phase="windup";a.elapsed=0.0;a.cooldown=0.0;a.direction=app.combat.xy(direction);a.hits={};a.attack_id="fixture:"+id+":"+str(passes.size()+failures.size())

func finish_combat() -> void:
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"routes":routes,"rendered":DisplayServer.get_name()!="headless","scope":"18-room door-to-door continuous full-radius paths; actual L5 entry/save/restart/environment/contact handlers with declared NPC-disabled and aligned attack fixtures. Not all exclusive NPC branches, natural full game, formal art/audio or human acceptance."},"  "));f.close()
 print("COMBAT_CHAPTER_CHECK %d passed %d failed, %d routes"%[passes.size(),failures.size(),routes])
 app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/feedback_20261017/combat"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames()
 await frontend.show_profile();frontend.name_field.text="第五关有限验证";frontend.overwrite_armed=true;frontend.new_game()
 await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false
 var n:int=app.rules.neurons;var c:int=app.rules.plexus
 app.unlock_combat();no_actors()
 check(app.session.data.level==5 and app.rules.mode=="combat" and app.room_id=="atrium" and app.rules.search_limit==0 and not app.has_key(),"L5 really starts combat without exploration key or search")
 check(app.rules.neurons==n+4 and app.rules.plexus==c+2,"first L5 unlock and actual first room reward each settle once")
 n=app.rules.neurons;app.enter_room("atrium");check(app.rules.neurons==n,"reentering visited room gives no duplicate first exploration reward")
 check(app.CombatMap.rooms().size()==18 and app.combat.data.actors.size()==17,"original eighteen spaces and seventeen stable identities retained")
 for room in app.CombatMap.rooms():
  var floor_layout=app.combat.floor_for(room)
  var valid:bool=true
  for from in app.CombatMap.doors(room):
   var portal:Dictionary=floor_layout.portal(from)
   if not floor_layout.walkable(portal.at) or not floor_layout.walkable(portal.threshold) or not floor_layout.walkable(portal.landing):valid=false
   for to in app.CombatMap.doors(room):
    if from==to:continue
    routes+=1
    var path:PackedVector2Array=floor_layout.path(portal.landing,floor_layout.portal(to).at)
    if path.is_empty():valid=false
    for index in range(1,path.size()):
     if not floor_layout.clear_segment(path[index-1],path[index],floor_layout.body_radius):valid=false
  check(valid,"full-radius portals and all door routes: "+room)
 app.enter_room("atrium");no_actors();app.hero_pos=Vector2(2,4.8)
 contact("father",Vector2(2.9,4.8),Vector2.LEFT)
 var hp:int=app.rules.hp
 for i in range(50):app.combat._advance_attack("father",.025)
 check(app.rules.hp==hp-15 and app.combat.data.actors.father.hits.has("hero"),"actual swept contact pays one S4 bottle hit")
 for i in range(20):app.combat._advance_attack("father",.025)
 check(app.rules.hp==hp-15,"same attack cannot damage repeatedly through recovery")
 app.rules.hurt_left=0;app.rules.reaction_left=1.0;app.rules.reaction_skill="GUT"
 contact("father",Vector2(2.9,4.8),Vector2.LEFT);hp=app.rules.hp
 for i in range(45):app.combat._advance_attack("father",.025)
 check(app.rules.hp==hp,"lowered upper body actually avoids chest-height bottle sweep")
 contact("doctor",Vector2(2.9,4.8),Vector2.LEFT)
 for i in range(45):app.combat._advance_attack("doctor",.025)
 check(app.rules.hp==hp-15,"crouch does not evade doctor's downward blade")
 app.rules.hurt_left=0;app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=.3
 contact("mother",Vector2(2.9,4.8),Vector2.LEFT);hp=app.rules.hp
 for i in range(38):app.combat._advance_attack("mother",.025)
 check(app.rules.hp==hp-10 and app.rules.gripped,"withdrawing a hand does not evade mother's torso clamp")
 no_actors();step(1.3);app.rules.hurt_left=0
 app.rules.reaction_left=0
 contact("archivist",Vector2(2.9,4.8),Vector2.LEFT)
 for i in range(38):app.combat._advance_attack("archivist",.025)
 check(app.rules.gripped and app.combat.data.holder=="archivist","actual closed hand creates one bounded grip")
 no_actors();step(1.3)
 check(not app.rules.gripped and app.combat.data.holder=="","grip releases without skill or repeated damage")
 app.enter_room("memory");no_actors();app.hero_pos=Vector2(2.5,3.0);app.rules.hp=60;app.rules.hurt_left=0
 var nurse:Dictionary=app.combat.data.actors.nurse
 nurse.present=true;nurse.room="memory";nurse.pos=[3.1,3.0]
 app.combat._friend("nurse",1.5)
 check(app.rules.hp==60 and not app.combat.data.bandage_done,"incomplete actual-contact bandage grants no early healing")
 app.rules.hurt_left=.25;app.combat._friend("nurse",1.0)
 check(app.rules.hp==60 and is_equal_approx(app.combat.data.bandage_elapsed,1.5),"unsafe interruption preserves bandage progress without healing")
 app.rules.hurt_left=0;app.combat._friend("nurse",1.5)
 check(app.rules.hp==80 and app.combat.data.bandage_done,"three contact seconds grant original twenty HP once")
 app.combat._friend("nurse",4.0);check(app.rules.hp==80,"same attempt cannot repeat successful bandage")
 app.enter_room("index");no_actors()
 var cart:Dictionary=app.layout.furniture[0];var old_rect:Rect2=cart.rect
 var stand:Vector2=Vector2(old_rect.position.x-.4,old_rect.get_center().y)
 app.hero_pos=Vector2(7.8,4.0)
 var helper:Dictionary=app.combat.data.actors.faceless
 helper.present=true;helper.room="index";helper.pos=app.combat.xy(stand)
 for i in range(10):app.combat._friend("faceless",.1)
 check(cart.rect.position.x>old_rect.position.x and app.combat.data.cart_shift>0,"faceless helper actually moves one physical cart")
 var moved_rect:Rect2=cart.rect
 var cart_save:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(cart_save) and (app.layout.furniture[0].rect as Rect2).position.is_equal_approx(moved_rect.position),"moved cart background/collision position survives real JSON")
 app.enter_room("cerebellum");no_actors();app.hero_pos=Vector2(4.2,3.5)
 contact("father",Vector2(3.2,3.5),Vector2.RIGHT)
 check(not app.combat._contains("father",app.hero_pos),"fold partition blocks a within-range attack instead of permitting wall hits")
 app.enter_room("atrium");no_actors();app.hero_pos=Vector2(3.8,1.0);app.rules.hurt_left=0;app.rules.reaction_left=0;app.rules.gripped=false
 app.rules.plexus=100;app.rules.neurons=50
 for entry in app.rules.config.skills:
  var id:String=str(entry.id)
  if id!="SKIN" and not app.rules.skill_states[id].unlocked:app.rules.unlock(id)
 var paid:Dictionary=app.rules.submit_skill("CONTROL",app.skill_context());app.apply_cast()
 check(paid.ok and paid.success and app.rules.neurons==45,"L5 control pays original five neurons without granting free attack unlocks")
 app.closing_left=0;app.paused_manual=false;await frames(4)
 var door_pixel:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.door_point("decision"))
 await click_position(door_pixel*Vector2(1280,720)/Vector2(app.world_viewport.size))
 check(await wait_for(func():return app.room_id=="decision",5.0),"actual controlled mouse door command walks opens and crosses a L5 doorway")
 app.rules.end_control();await frames(2);app.paused_manual=true
 app.enter_room("hypothalamus");no_actors()
 check(is_equal_approx(app.layout.speed_factor(Vector2(3,3)),.8) and app.layout.speed_factor(Vector2(7,3))==1.0,"cold is local reversible and uses same actor/hero factor")
 app.enter_room("brainstem");no_actors();app.hero_pos=Vector2(5.2,1.4);app.rules.hp=100;app.combat.data.pulse_clock=1.6
 app.combat.data.actors.self.present=true;app.combat.data.actors.self.room="brainstem";app.combat.data.actors.self.pos=[5.2,5.9];app.combat.data.actors.self.hp=80
 app.combat._pulse()
 check(app.rules.hp==80 and app.combat.data.actors.self.hp==60,"one actual pulse damages both host and unique pursuer")
 app.combat._pulse();check(app.rules.hp==80 and app.combat.data.actors.self.hp==60,"pulse receipt prevents repeated same-cycle damage")
 no_actors();app.hero_pos=Vector2(4.4,1.4);app.hero_route=PackedVector2Array();app.combat.data.route_left=0
 app.combat._hero(.025)
 check(app.hero_route.is_empty() or app.hero_route[-1].x<app.layout.pulse_zone.position.x,"autonomous host waits outside the visibly active pulse instead of walking into it")
 await capture("01_pulse")
 var state:Dictionary=app.snapshot_data();var before_clock:float=app.combat.data.clock
 check(app.restore_snapshot(JSON.parse_string(JSON.stringify(state))) and app.session.data.level==5 and is_equal_approx(float(app.combat.data.clock),before_clock),"L5 JSON restores actual actor/pulse state without resetting chapter")
 var clock:float=app.combat.data.clock;await seconds(.3)
 check(app.combat.data.clock==clock,"manual pause freezes combat/environment clocks")
 app.rules.hp=0;var attempt:int=app.rules.actual_attempt;var cycle:int=app.session.data.cycle
 app.restart_attempt(3,true)
 check(app.session.data.level==5 and app.room_id=="atrium" and app.rules.actual_attempt==attempt+1 and app.session.data.cycle==cycle+3 and app.rules.mode=="combat" and app.rules.search_limit==0,"death revives once in L5 without returning to key search")
 no_actors();app.paused_manual=false
 check(await wait_for(func():clear_lines();no_actors();return app.combat.data.get("boundary",false),240),"ordinary autonomous process walks through L5 portals to actual brainstem exit")
 check(app.session.data.level==6 and 6 in app.session.data.unlocked and app.street.data.ending.is_empty(),"real L5 exit enters Street without prematurely submitting an ending")
 await capture("02_exit_boundary")
 await finish_combat()
