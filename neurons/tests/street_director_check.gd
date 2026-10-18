extends "res://tests/street_belt_check.gd"
## Declared torso/rail/blocker poses; original shared damage, holder, disk and kick.
func director_scene(offset:Vector2=Vector2(.84,0),heading:Vector2=Vector2.RIGHT) -> Dictionary:
 if app.room_id!="street_node":app.enter_room("street_node")
 belt_scene(offset,heading);app.street.data.actors.warder.present=false;app.street.data.erase("director_frame");app.street.data.grip_until=0;app.street.data.ending={};app.street.data.boundary=false
 var a:Dictionary=actor_at("director",Vector2(4,4));a.hp=60;a.direction=app.street.xy(heading);a.phase="windup";a.elapsed=0;a.cooldown=0;a.hits={};a.attack_id="declared_director:"+str(passes.size()+failures.size());app.street.director.sync();return a
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_director_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="真实椅架夹合与释放验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_node");no_street()
 var a:Dictionary=director_scene();var owners:Dictionary=app.rules.owners.duplicate(true);var records:Array=app.rules.institutional_records.duplicate(true);var evidence:Array=app.rules.evidence.duplicate(true);var book:Dictionary=app.rules.book_extensions.duplicate(true);step(.8)
 check(a.phase=="attack" and app.rules.hp==100 and app.rules.sp==80 and not app.rules.gripped,"full original preparation visibly opens attached rails without damage or control")
 step(.225)
 check(app.rules.hp==100 and not app.rules.gripped and app.street.director.state().frames.size()==2,"two still-open approaching rails are not a completed clamp")
 await capture("01_actual_rails_closing_before_contact");step(.05)
 check(not app.rules.gripped and app.rules.hp==100,"near-closed geometry still respects final physical contact threshold")
 step(.025)
 check(a.phase=="grip" and app.street.data.holder=="director" and app.rules.gripped and app.rules.hp==90 and app.rules.sp==70,"both actual side rails close on torso before one original ten/ten injury and fixation")
 var receipt:String=a.attack_id;var clock:float=app.street.data.clock;var until:float=app.street.data.grip_until;var frames:Array=app.street.director.state().frames.duplicate(true);var hit_count:int=count_fact("combat_hit")
 check(disk() and app.rules.settled.has(receipt) and app.street.data.holder=="director","real JSON preserves closed rails, sole holder and paid receipt")
 a=app.street.data.actors.director;app._process(.7)
 check(is_equal_approx(clock,float(app.street.data.clock)) and app.street.vector(frames[0][2]).is_equal_approx(app.street.vector(app.street.director.state().frames[0][2])) and app.rules.hp==90,"manual pause freezes actual frame and original control deadline after disk restore")
 await capture("02_actual_torso_fixed_paused");var pos:Vector2=app.hero_pos;app.rules.reaction_skill="WITHDRAW";app.rules.reaction_left=2;app.hero_route=app.layout.path(pos,pos+Vector2(2,0));step(.1)
 check(app.rules.gripped and app.hero_pos.is_equal_approx(pos) and app.street.data.holder=="director","withdraw or ordinary route cannot undo an already-enclosed torso")
 step(until-float(app.street.data.clock)+.025)
 check(not app.rules.gripped and app.street.data.holder=="" and a.phase=="recover" and app.street.director.state().phase=="rails_release","original1.2s deadline opens rails and actually releases")
 await capture("03_actual_rails_release");step(.65)
 check(a.phase=="idle" and a.cooldown>1.3 and app.street.director.state().frames.is_empty() and count_fact("combat_hit")==hit_count,"full recovery folds same attached rails with no reverse hit or residual capture line")
 check(app.rules.owners==owners and app.rules.institutional_records==records and app.rules.evidence==evidence and app.rules.book_extensions==book,"recorder appearance creates no testimony, revived recording, item or institutional claim")
 var envelope_ok:bool=true
 for n in range(101):
  for frame in app.street.director.shape(float(n)/100):
   for p in frame:
    var delta:Vector2=app.street.vector(p)-app.street.position("director");var radius:float=app.street.director.param("director_bar_m")
    envelope_ok=envelope_ok and delta.x+radius<=float(app.street.config.attacks.restraint.reach)+.00001 and absf(delta.y)+radius<=float(app.street.config.attacks.restraint.width)+.00001
 check(envelope_ok,"all trial rail positions and thickness fit original1.2 forward reach and .4 lateral envelope")
 for offset in [Vector2(.84,.13),Vector2(.84,-.18),Vector2(1.15,0),Vector2(-.3,0)]:
  a=director_scene(offset);step(1.15)
  check(app.rules.hp==100 and app.rules.sp==80 and not app.rules.gripped,"single side grazing/front/rear body does not become actual bilateral clamp "+str(offset))
 for d in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  a=director_scene(d*.84,d);step(1.1)
  check(app.rules.hp==90 and app.rules.sp==70 and app.street.data.holder=="director","same closed rail geometry follows original fixed heading "+str(d))
 for skill in ["WITHDRAW","GUT"]:
  a=director_scene();app.rules.reaction_skill=skill;app.rules.reaction_left=2;step(1.1)
  check(app.rules.hp==90 and app.rules.gripped,"original "+skill+" does not automatically erase body-height chair enclosure")
 a=director_scene();step(.8);app.hero_pos=Vector2(4,4.84);step(.35)
 check(app.rules.hp==100 and not app.rules.gripped and app.street.vector(a.direction).is_equal_approx(Vector2.RIGHT),"host changing side after windup cannot rotate already-started chair attack")
 a=director_scene();app.layout.furniture.append({"id":"declared_one_rail_blocker","name":"只挡住一侧椅架","rect":Rect2(4.5,3.53,.14,.18),"height":110});app.layout.rebuild_grid();step(1.15)
 check(app.street.director.state().blocked and app.rules.hp==100 and not app.rules.gripped and a.phase=="recover","blocking one real rail prevents through-cabinet bilateral enclosure")
 check(not app.street.director.state().frames.is_empty(),"obstructed attached rails remain visible on accepted side instead of vanishing")
 await capture("04_one_actual_rail_blocked")
 a=director_scene();step(1.1);app.layout.furniture.append({"id":"declared_held_rail_blocker","name":"新实体进入已闭合椅架","rect":Rect2(4.45,3.64,.1,.08),"height":110});app.layout.rebuild_grid();step(.025)
 check(not app.rules.gripped and app.rules.hp==90 and app.rules.sp==70,"new actual solid interruption releases existing rails without refund or another charge")
 a=director_scene();step(1.1);app.hero_pos+=Vector2(0,.6);pos=app.hero_pos;app.street._actor("director",.025)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(pos),"declared external body displacement outside real cage releases instead of snapping host back")
 a=director_scene();step(.8);app.street.damage_actor("father","director",15,"declared_frame_precontact_hurt");step(.35)
 check(app.rules.hp==100 and not app.rules.gripped,"real damage handler interrupts an uncompleted frame attack")
 a=director_scene(Vector2(.8,0));app.hero_facing=Vector2.LEFT;kick_body()
 check(a.hp==45 and app.street.director.state().frames.is_empty(),"actual effective knee immediately clears old chair geometry in same contact frame")
 step(.5)
 check(a.hp==45 and app.rules.hp==100 and a.phase not in ["windup","attack"],"actually paid CONTROL and legal knee damage carrier before closure")
 a=director_scene();step(1.1);app.street.damage_actor("father","director",15,"declared_frame_holder_hurt")
 check(not app.rules.gripped and app.street.data.holder=="" and app.rules.hp==90 and app.rules.sp==70,"hurt owner opens only own fixed rails and preserves original injury")
 a=director_scene();step(1.1);var furniture_count:int=app.layout.furniture.size();app.street.damage_actor("father","director",100,"declared_frame_holder_death")
 check(a.hp==0 and not app.rules.gripped and app.street.data.holder=="" and app.street.director.state().owner=="director" and app.layout.furniture.size()==furniture_count,"owner death releases attached frame without a new chair behind host or prison scene")
 a=director_scene();step(1.1);a.present=false;app.street._actor("director",.025)
 check(not app.rules.gripped and app.street.director.state().frames.is_empty(),"absent owner cannot leave independent invisible chair capture")
 a=director_scene();step(1.1);a.room="street_end";app.street._actor("director",.025)
 check(not app.rules.gripped and app.room_id=="street_node","cross-room invalidation releases locally without teleporting host")
 a=director_scene();var other:Dictionary=actor_at("isolation",app.hero_pos+Vector2(.85,0));other.phase="grip";app.street.data.holder="isolation";app.street.data.grip_until=app.street.data.clock+1.2;app.rules.gripped=true;step(1.1)
 check(app.street.data.holder=="isolation" and app.rules.hp==100 and app.rules.sp==80 and not a.hits.has("hero"),"already-prepared rails cannot steal another torso holder or queue damage behind it")
 app.street.damage_actor("father","director",15,"declared_nonholder_frame_hurt")
 check(app.street.data.holder=="isolation" and app.rules.gripped,"injuring non-owner frame does not free the other holder")
 a=director_scene();step(1.1);var saved:Dictionary=app.snapshot_data();saved.street_state.erase("director_frame");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));step(.1)
 check(app.street.data.holder=="director" and app.rules.hp==90 and app.rules.sp==70 and app.street.director.state().phase=="torso_fixed","legacy valid paid grip reconstructs attached rails without replay")
 a=director_scene();step(1.1);app.hero_pos=app.street.position("director")+Vector2(1.35,0);saved=app.snapshot_data();saved.street_state.erase("director_frame");app.restore_snapshot(JSON.parse_string(JSON.stringify(saved)));pos=app.hero_pos;step(.1)
 check(not app.rules.gripped and app.hero_pos.is_equal_approx(pos) and app.rules.hp==90,"legacy rectangular grip outside actual cage releases without creating chair behind host or recharging")
 a=director_scene();a.phase="idle";app.hero_pos=Vector2(5.6,4);step(3)
 check(app.rules.hp==90 and app.rules.sp==70 and app.street.data.holder=="director","autonomous approach reaches actual closing rails instead of repeated remote box grips")
 a=director_scene();app.hero_pos=Vector2(7,4);var neutral:Dictionary=actor_at("register_nurse",Vector2(4.84,4));step(1.15)
 check(neutral.hp==30 and a.hits.has("register_nurse"),"same physical rails preserve existing once-per-target neutral HP handler")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Declared body/side/four-heading/one-rail blocker/new-blocker/other-holder/legacy fixtures, actual paid CONTROL/legal knee/shared10HP10SP and1.2s/disk/manual pause. External body displacement is explicitly a pose fixture, not an actual bed-hit replay. Recorder/identity visuals are procedural; no source statement or recording invented. Not natural all-crowd/full B6/B7/final art."},"  "));file.close()
 print("STREET_DIRECTOR_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
