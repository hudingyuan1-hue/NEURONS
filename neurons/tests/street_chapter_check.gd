extends "res://tests/combat_chapter_check.gd"
## Finite production paths with declared room/actor/resource fixtures.
func no_street() -> void:
 for id in app.street.data.actors:app.street.data.actors[id].present=false;app.street.data.actors[id].hp=app.street.spec(str(id)).hp
 app.street.data.holder="";app.rules.gripped=false;app.rules.hurt_left=0;app.rules.stun_left=0;clear_lines()
func contact6(id:String) -> void:
 var a:Dictionary=app.street.data.actors[id]
 a.present=true;a.room=app.room_id;a.pos=[2,3];a.hp=60;a.phase="windup";a.elapsed=0;a.cooldown=0;a.direction=[1,0];a.hits={};a.attack_id="street-fixture:"+id+":"+str(passes.size());a.follow="";a.hurt=0
 app.hero_pos=Vector2(2.9,3)
func run6(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.advance_world(.025)
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_20261017/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street有限规则验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors()
 app.rules.hp=70;app.rules.sp=60;var n:int=app.rules.neurons;var c:int=app.rules.plexus
 app.unlock_street()
 check(app.session.data.level==6 and app.rules.mode=="combat" and app.rules.hp==70 and app.rules.sp==60,"first Street entry preserves actual host life and spirit")
 check(app.rules.neurons==n+4 and app.rules.plexus==c+2,"one original unlock and actual plaza exploration reward")
 check(app.hero_pos.is_equal_approx(app.layout.spawn()),"first Street entry uses the actual entry landing, not an unknown portal")
 check(app.street.data.actors.size()==45 and app.StreetMap.rooms().size()==7,"all forty-five identities and seven source segments retained")
 var identities:Dictionary={};var counts:Dictionary={};var positioned:bool=true
 for id in app.street.data.actors:
  var s:Dictionary=app.street.spec(str(id));identities[s.identity_id]=true;counts[s.room]=int(counts.get(s.room,0))+1
  if not app.street.floor_for(str(s.room)).walkable(app.street.position(id)):positioned=false
 check(identities.size()==45 and counts.values().reduce(func(a,b):return a+b,0)==45,"stable canonical identities are unique and not a probability subset")
 check(counts=={"street_plaza":6,"street_side":5,"street_narrow":5,"street_twisted":9,"street_maintenance":6,"street_node":8,"street_end":6},"original 6/5/5/9/6/8/6 distribution")
 check(positioned,"all configured entities start at legal full-radius floor positions")
 for room in app.StreetMap.rooms():
  var floor=app.street.floor_for(room);var valid:bool=true
  for from in app.StreetMap.doors(room):
   var portal:Dictionary=floor.portal(from)
   if not floor.walkable(portal.at) or not floor.walkable(portal.threshold) or not floor.walkable(portal.landing):valid=false
   for to in app.StreetMap.doors(room):
    if from==to:continue
    var path:PackedVector2Array=floor.path(portal.landing,floor.portal(to).threshold)
    if path.is_empty():valid=false
    for i in range(1,path.size()):
     if not floor.clear_segment(path[i-1],path[i],floor.body_radius):valid=false
  check(valid,"continuous full-body portal routes: "+room)
 no_street();app.hero_pos=Vector2(2,5);app.street.data.actors.register_nurse.present=true;app.street.data.actors.register_nurse.pos=[2.5,5]
 app.hero_route=app.layout.path(app.hero_pos,Vector2(5,5));app.street.move_hero(.2)
 var radius_valid:bool=not app.hero_route.is_empty()
 for i in range(1,app.hero_route.size()):
  if not app.layout.segment_avoids_bodies(app.hero_route[i-1],app.hero_route[i],[{"pos":Vector2(2.5,5),"radius":.46}]):radius_valid=false
 check(radius_valid,"blocked host replans with combined host and actor clearance")
 for i in range(70):app.street.move_hero(.05)
 check(app.hero_pos.x>3.3,"real movement passes stationary body instead of repeating blocked path")
 no_street();app.hero_pos=Vector2(5.47,3.35)
 for id in ["father","warder","transporter_hospital"]:
  var a:Dictionary=app.street.data.actors[id];a.present=true;a.phase="windup";a.elapsed=.1;a.direction=[1,0]
 app.street.data.actors.father.pos=[5.04,3.51];app.street.data.actors.warder.pos=[5.57,4.62];app.street.data.actors.transporter_hospital.pos=[6.82,3.10]
 app.street.data.actors.father.direction=[.73,-.68];app.rules.end_control();app.rules.hurt_left=0;app.hero_route=PackedVector2Array();app.street._hero(.025)
 var goal:Vector2=app.street.vector(app.street.data.hero_goal);var clear_goal:bool=true
 for id in ["father","warder","transporter_hospital"]:
  if goal.distance_to(app.street.position(id))<.52:clear_goal=false
 check(clear_goal,"visible-attack dodge cannot choose another actor's occupied footprint")
 # Reproduce the actual return-stall snapshot: do not plan around an unseen remote actor.
 app.session.data.level=5;app.combat.data.boundary=false;app.enter_room("verify");no_actors();app.rules.end_control();app.rules.hurt_left=0;app.rules.stun_left=0
 app.hero_pos=Vector2(.86,5.6);var skin:Dictionary=app.combat.data.actors.skinface;skin.present=true;skin.room="verify";skin.pos=[5.526,.352];skin.phase="idle"
 var start:Vector2=app.hero_pos;app.combat._hero(.025)
 check(not app.hero_route.is_empty() or app.hero_pos.distance_to(start)>.001,"remote unseen doorway actor cannot freeze L5 return at entry")
 app.hero_pos=Vector2(5.6,2.2);app.hero_route=PackedVector2Array();app.combat.data.route_left=0;app.combat._hero(.025)
 check(not app.hero_route.is_empty() and app.combat.data.door_left<0,"visible occupied exit gets a reachable approach instead of an impossible endpoint")
 app.session.data.level=6
 no_street();app.enter_room("street_side");no_street();n=app.rules.neurons;app.enter_room("street_plaza");app.enter_room("street_side")
 check(app.rules.neurons==n,"ordinary return cannot repeat first-room income")
 app.enter_room("street_twisted");no_street();app.rules.control_left=20;app.rules.hp=100;app.rules.sp=100
 contact6("pharmacist");var pharmacist:Dictionary=app.street.data.actors.pharmacist;pharmacist.portions=2
 run6(1.5) # Advance actual world-clock liquid as well as the cup action.
 check(app.rules.sp==90 and pharmacist.portions==1,"real first liquid hit consumes one portion and ten spirit only")
 contact6("pharmacist")
 run6(1.5)
 check(app.rules.sp==80 and pharmacist.portions==0,"second real pour exhausts the original cup")
 pharmacist.phase="idle";pharmacist.cooldown=0;app.street._actor("pharmacist",.025)
 check(pharmacist.phase=="idle","empty cup cannot begin another attack")
 no_street();contact6("ward_nurse");app.rules.sp=100;app.rules.hp=100;app.rules.control_left=20
 # Actual reaching hand must finish contact inside the original .3s active
 # window; the former rectangle fixture assumed first-active-frame contact.
 for i in range(44):app.street._advance_attack("ward_nurse",.025)
 check(app.rules.gripped and app.rules.sp==100,"actual head grip has no premature medicine loss")
 run6(1.05)
 check(app.rules.sp==80 and not app.rules.gripped and app.street.data.actors.ward_nurse.portions==0,"actual swallow pays original spirit loss once and releases head")
 check(app.rules.stun_left>0 and app.rules.hp==100,"oral medicine pauses body without invented life damage")
 no_street();app.street.data.speed_stacks=0;app.street.data.speed_deaths={}
 for id in ["dog","corner","wheelchair","transport_patient"]:
  app.street.data.actors[id].hp=10;app.street.damage_actor("father",id,15,"qualified:"+id)
 check(app.street.data.speed_stacks==3 and app.street.data.speed_deaths.size()==4,"eligible actual NPC deaths cap at three speed layers but keep later history")
 app.street.damage_actor("father","dog",15,"duplicate-dog")
 check(app.street.data.speed_stacks==3,"same identity death cannot grant twice")
 app.street.data.actors.nurse.hp=5;app.street.damage_actor("father","nurse",15,"ineligible-nurse")
 check(not app.street.data.speed_deaths.has("nurse"),"nurse does not join the seven-identity growth list")
 app.rules.hp=0;app.street.data.speed_stacks=0;app.street.data.speed_deaths={};app.street.data.actors.speaker.hp=5;app.street.damage_actor("father","speaker",15,"simultaneous-fatal")
 check(app.street.data.speed_stacks==0,"simultaneous host death never grants a carried speed bonus")
 app.rules.hp=1;var five:int=int(app.session.data.attempts["5"]);var six:int=int(app.session.data.attempts["6"])
 app.combat.data.bandage_done=true;app.combat.data.actors.father.hp=0
 app.rules.hp=0;app.restart_attempt(3,true)
 check(app.session.data.level==5 and app.session.data.street_returning and int(app.session.data.attempts["6"])==six+1 and int(app.session.data.attempts["5"])==five,"Street death returns to L5 while increasing only L6 attempt")
 check(app.combat.data.bandage_done and app.combat.data.actors.father.hp==0,"return preserves spent L5 bandage and actual retired father")
 var registered:int=app.street.data.actors.size();var pending_save:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(pending_save) and app.session.data.street_returning and app.street.data.actors.size()==registered,"pending Street attempt and L5 return survive real JSON")
 app.rules.hp=0;app.restart_attempt(3,true)
 check(int(app.session.data.attempts["5"])==five and int(app.session.data.attempts["6"])==six+2 and app.combat.data.actors.father.hp==0,"death during return increments L6 once without restoring L5 casualties")
 six=int(app.session.data.attempts["6"]);n=app.rules.neurons;app.rules.hp=43;app.unlock_street();no_street()
 print("REENTRY_DIAGNOSTIC ",app.rules.hp," N ",n,"->",app.rules.neurons," attempt ",six,"->",app.session.data.attempts["6"]," receipts ",app.session.data.receipts.keys())
 check(app.rules.hp==43 and app.rules.neurons==n and int(app.session.data.attempts["6"])==six,"reentering uses already registered attempt without heal or duplicate income")
 var before:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 app.rules.control_ms=119999;app.rules.effects.clear();app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.end_control()
 app.enter_room("street_end");no_street();var door:Dictionary=app.layout.portal("ending_gate")
 app.hero_pos=door.at+Vector2(door.inward)*.15;app.street.data.destination="ending_gate";app.street.data.door_left=0;app.hero_route=app.layout.path(app.hero_pos,door.threshold)
 for i in range(50):app.street._hero(.025)
 check(not app.street.data.ending.is_empty() and app.hero_pos.distance_to(door.threshold)<.035,"real terminal-door threshold movement commits the ending")
 check(app.street.data.ending.id=="E2" and app.rules.hp==43,"119999 effective milliseconds selects E2 without healing")
 var receipt:String=app.street.data.ending.receipt;app.street.exit_crossed()
 check(app.street.data.ending.receipt==receipt,"ending commit is once even on repeated exit callback")
 check(app.restore_snapshot(before),"restore exact pre-ending Street snapshot")
 app.rules.hp=0;app.street.exit_crossed();check(app.street.data.ending.is_empty(),"lethal host state takes precedence over valid ending callback")
 app.rules.hp=43
 app.rules.control_ms=120000;app.street.exit_crossed()
 check(app.street.data.ending.id=="E3","exact 120000 effective milliseconds selects E3")
 app.paused_manual=false;app.sync_audio_pause();app.street.advance_ending(1.6);app.street.advance_ending(.1)
 check(app.dialogue_queue.size()==2 and app.dialogue_queue[0].text=="出来了。","unchanged original unrecognized exit dialogue is selected")
 var progress:Dictionary=app.achievements.load_progress()
 check(progress.ok and progress.data.unlocked.has("player_wins"),"actual E3 submits its global achievement without resource payment")
 check(app.audio.starts.any(func(a):return str(a.get("cue_id",a.get("id","")))=="MUS_END"),"actual ending selects the supplied ending music stream")
 clear_lines();app.street.advance_ending(.1);app.street.advance_ending(.5)
 var e_save:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()));var ending_time:float=app.street.data.ending.elapsed
 check(app.restore_snapshot(e_save) and is_equal_approx(float(app.street.data.ending.elapsed),ending_time),"half-finished main ending survives JSON without recommit")
 app.paused_manual=true;await seconds(.25)
 check(app.street.data.ending.elapsed==ending_time,"manual pause freezes the epilogue clock")
 app.menu.open_page("book");await frames(2);check(app.menu.visible,"declared ending-menu fixture is actually open before close");app.menu.close_menu();await frames(2)
 var closing:float=app.closing_left;await seconds(.25)
 check(app.closing_left==closing,"pause during ending-menu closing preserves its remaining transition")
 app.paused_manual=false;await seconds(.4)
 check(app.closing_left<=0,"ending-menu close resumes instead of deadlocking the epilogue")
 var ending_n:int=app.rules.neurons;await click(app.skip_main_ending);await frames(3)
 check(app.street.data.ending.complete and app.ending_panel.visible and app.ending_panel.edition.text.contains("E3"),"actual skip button reaches correctly named E3 result panel")
 check(app.rules.neurons==ending_n,"skipping epilogue gives no duplicate resources")
 check(app.restore_snapshot(before),"restore pre-ending fixture for success-history boundary checks")
 app.rules.control_ms=0;app.rules._record("skill_reacted","zero-ms-success-fixture",{"skill":"CONTROL"});app.street.exit_crossed()
 check(not "autonomous_main_clear" in app.street.data.pending_ending_achievements,"successful zero-effective-time CONTROL excludes free-will achievement")
 app.restore_snapshot(before);app.rules.control_ms=0;app.rules._record("skill_resisted","resisted-control-fixture",{"skill":"CONTROL"});app.street.exit_crossed()
 check("autonomous_main_clear" in app.street.data.pending_ending_achievements,"resisted CONTROL alone does not invent successful control history")
 await capture("01_ending_registration")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Declared room/health/actor and threshold fixtures; actual world/contact/return/save/achievement handlers and full-radius geometry. Not natural full-game, all 45 exclusive branches, final art or audio audition."},"  "));file.close()
 print("STREET_CHAPTER_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
