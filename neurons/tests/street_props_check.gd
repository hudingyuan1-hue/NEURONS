extends "res://tests/street_chapter_check.gd"
## Real prop/attack handlers with explicit aligned, stationary actor fixtures.
func box_step(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.street.box.tick(.025)
func bed_step(seconds:float) -> void:
 for i in range(ceili(seconds/.025)):app.street.lateral_bed.actor(.025)
func sounds() -> int:
 return app.rules.facts.filter(func(f):return f.kind=="physical_sound" and f.get("object","")=="street_labor_box").size()
func setup_bed(center:Vector2=Vector2(4,6)) -> void:
 no_street();var a:Dictionary=app.street.data.actors.transporter_asylum
 a.present=true;a.hp=60;a.room=app.room_id;a.pos=[center.x-.8,center.y];a.phase="idle";a.hurt=0;a.cooldown=0;a.follow="";a.direction=[1,0]
 app.street.data.lateral_bed={"room":app.room_id,"center":[center.x,center.y],"axis":[0,1],"push":[1,0],"operator":a.pos.duplicate(),"phase":"idle","elapsed":0.0,"distance":0.0,"velocity":0.0,"coasting":false,"hits":{},"attack_id":"","retreat_left":0.0,"seen_sign":false}
 app.street.data.next_attack=0;app.rules.hp=100;app.rules.sp=100;app.rules.hurt_left=0;app.rules.gripped=false;app.rules.stun_left=0
 app.rules.end_control();app.rules.action.clear();app.rules.kick_until=0;app.hero_pos=center+Vector2(1.6,0)

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_props_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="Street实物验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street()
 app.enter_room("street_maintenance");no_street();var labor:Dictionary=app.street.data.actors.labor
 labor.present=true;labor.room=app.room_id;labor.pos=[5,4.8];labor.hp=40;labor.hurt=0
 app.street.data.box={};app.street.box.normalize()
 app.hero_pos=Vector2(8,2.5)
 var seeker:Dictionary=app.street.data.actors.self
 seeker.present=true;seeker.room=app.room_id;seeker.pos=[4,2.5];seeker.hp=80;seeker.hostile=true;seeker.last_seen=[4,4];seeker.phase="idle"
 check(not app.street.can_see(app.room_id,app.street.position("self"),app.hero_pos),"box seeker fixture genuinely loses line of sight behind existing cabinet")
 app.street.box.tick(.025)
 check(app.street.data.box.phase=="prepare" and sounds()==0,"labor starts visible preparation without early sound")
 labor.hurt=.4;app.street.box.tick(.025)
 check(app.street.data.box.phase=="held" and not app.street.data.box.released and sounds()==0,"pre-release injury retains the only box with no fabricated impact")
 labor.hurt=0;box_step(.25)
 var before:float=app.street.data.box.elapsed;app._process(.5)
 check(app.street.data.box.elapsed==before,"real manual pause holds box preparation")
 box_step(.6)
 check(app.street.data.box.phase=="flight" and app.street.data.box.released and sounds()==0,"actual release starts flight without landing sound")
 check(app.street.vector(app.street.data.box.origin).distance_to(app.street.vector(app.street.data.box.target))<=4.0001,"planned throw respects original four metre maximum")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved) and app.street.data.box.phase=="flight" and not app.street.data.box.sound_sent,"in-flight JSON keeps the same object and unheard impact")
 app.set_process(false);var b:Dictionary=app.street.data.box
 var visible:Dictionary=app.street.data.actors.warder;visible.present=true;visible.hp=60;visible.room=app.room_id;visible.pos=[8,3.5];visible.last_seen=[8,2.5];visible.phase="windup";visible.direction=[0,-1]
 seeker=app.street.data.actors.self;seeker.phase="attack";seeker.direction=[0,1]
 app.street.data.actors.labor.hp=0
 var hp:int=app.rules.hp;var sp:int=app.rules.sp;box_step(1.1)
 check(app.street.data.box.phase=="ground" and sounds()==1,"released box survives thrower's death and sounds only on actual landing")
 check(app.street.data.box.heard.has("self") and not app.street.data.box.heard.has("warder"),"occluded audible seeker investigates while visible pursuer keeps target")
 check(seeker.phase=="attack" and seeker.direction==[0,1] and visible.phase=="windup","landing sound does not cancel launched attacks or retarget their directions")
 check(app.rules.hp==hp and app.rules.sp==sp and app.rules.stun_left==0,"box causes no damage, healing, resource or stun effect")
 var landing:Array=app.street.data.box.pos.duplicate();box_step(2)
 check(app.street.data.box.pos==landing and sounds()==1 and app.street.data.box.released,"stationary box does not replenish or keep emitting")
 check(app.street.box._safe_landing(app.street.vector(landing)),"final landing preserves the actual return doorway lane")

 clear_lines();app.enter_room("street_twisted");setup_bed()
 var space=app.layout;var cell:Vector2i=Vector2i(Vector2(4,6)/space.CELL);var was:bool=space.grid.is_point_solid(cell)
 var patch:Dictionary=app.street.lateral_bed.push_blocker(space,app.street.lateral_bed.rect())
 check(space.grid.is_point_solid(cell) and patch.changed.size()>0 and patch.changed.size()<space.grid.region.size.x*space.grid.region.size.y/10,"temporary bed navigation updates only its occupied local grid cells")
 app.street.lateral_bed.pop_blocker(space,patch)
 check(space.grid.is_point_solid(cell)==was and space.movable_blockers.is_empty(),"temporary bed grid restores previous cells without leaving blocked trails")
 var axis:Vector2=Vector2(-.85210848,.52336621).normalized();var center:=Vector2(15.668272,5.225437);var outside:=Vector2(14.623637,5.8)
 var rect:Rect2=app.street.Bed.bounds(app.street.lateral_bed.anchor(center,axis),axis)
 patch=app.street.lateral_bed.push_blocker(space,rect,{"at":app.street.lateral_bed.anchor(center,axis),"axis":axis})
 check(rect.grow(.21).has_point(outside) and space.walkable(outside) and not space.path(outside,space.portal("street_node").landing).is_empty(),"real death-snapshot point outside rotated bed retains a path despite lying in its AABB")
 app.street.lateral_bed.pop_blocker(space,patch)
 check(app.street.lateral_bed.lane_clear(Vector2(4,6),Vector2.DOWN,Vector2.RIGHT),"side-push reserves all original door-to-door routes outside complete sweep")
 app.street.lateral_bed.actor(.025)
 check(app.street.data.lateral_bed.phase=="windup" and app.street.data.actors.transporter_asylum.attack_id.begins_with("street_lateral:"),"distinct carrier starts an actual lateral bed attack")
 before=app.street.data.lateral_bed.elapsed;app.paused_manual=true;app._process(.5)
 check(app.street.data.lateral_bed.elapsed==before,"manual pause freezes physical bed windup")
 bed_step(1.2);saved=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved) and app.street.data.lateral_bed.phase=="attack","bed attack JSON keeps locked sideways direction and distance")
 app.set_process(false);var start:Vector2=app.street.vector(app.street.data.lateral_bed.center);bed_step(.6)
 check(app.rules.hp==80 and absf(app.street.vector(app.street.data.lateral_bed.center).y-start.y)<.001,"moving side edge makes one original twenty HP contact")
 check(float(app.street.data.lateral_bed.distance)<=1.0001 and app.hero_pos.distance_to(Vector2(5.6,6))<=1.0001,"sideways stroke and actual displacement each stay within one metre")
 hp=app.rules.hp;bed_step(.3);check(app.rules.hp==hp,"stopped/recovering bed cannot keep crushing for repeated damage")
 check(not app.street.lateral_bed.lane_clear(Vector2(19.1,6),Vector2.DOWN,Vector2.RIGHT),"wall/exit-closing stroke is rejected before launch")

 setup_bed();app.rules.skill_states.KNEE.unlocked=true;app.rules.control_left=10;app.hero_pos=Vector2(4.8,6)
 var kick:Dictionary=app.rules.begin_kick({"direction":[-1,0]},true);app.rules.advance_kick(.2);app.street.kick_contact()
 check(kick.ok and app.street.data.actors.transporter_asylum.hp==60,"kick into bed body does not count as hitting its distant carrier")
 app.rules.action.clear();setup_bed();app.street.lateral_bed.actor(.025);bed_step(1.2)
 var state:Dictionary=app.street.data.lateral_bed;start=app.street.vector(state.center)
 app.rules.control_left=10;app.hero_pos=app.street.position("transporter_asylum")-Vector2(.7,0)
 kick=app.rules.begin_kick({"direction":[1,0]},true);app.rules.advance_kick(.2);app.street.kick_contact()
 check(kick.ok and app.street.data.actors.transporter_asylum.hp==45,"actual carrier kick uses existing contact damage once")
 app.rules.action.clear();bed_step(.025)
 check(state.coasting and app.street.vector(state.center).distance_to(start)>0 and state.phase=="attack","already moving bed decelerates after carrier interruption instead of disappearing")
 bed_step(.5);check(state.phase=="recover" and state.velocity==0,"interrupted bed reaches a physical stationary state")
 setup_bed();app.street.lateral_bed.actor(.025);bed_step(1.2)
 start=app.street.vector(app.street.data.lateral_bed.center)
 app.street.damage_actor("father","transporter_asylum",60,"fixture:bed-carrier-death");bed_step(.5)
 check(app.street.data.actors.transporter_asylum.hp==0 and app.street.vector(app.street.data.lateral_bed.center).distance_to(start)>0,"carrier death leaves the launched physical bed and coast")
 var stopped:Array=app.street.data.lateral_bed.center.duplicate();bed_step(2)
 check(app.street.data.lateral_bed.center==stopped and app.street.bed_blocks(app.room_id,app.street.vector(stopped),.21),"dead carrier's stopped bed remains a real obstacle at saved position")
 check(app.street.data.actors.size()==45 and app.street.data.actors.has("assistant"),"second transport bed creates no duplicate patient or actor")
 setup_bed();app.rules.neurons=50;app.rules.skill_states.CONTROL.unlocked=true;app.rules.skill_states.CONTROL.until=0;app.rules.skill_states.CONTROL.resistance=0
 var takeover:Dictionary=app.rules.submit_skill("CONTROL",{});app.rules.apply_pending()
 var guard:Dictionary=app.street.data.actors.warder;guard.present=true;guard.hp=60;guard.room=app.room_id;guard.pos=[app.hero_pos.x+.465,app.hero_pos.y]
 app.controlled_route=true;app.hero_route=PackedVector2Array([app.hero_pos,app.hero_pos+Vector2(1,0)]);start=app.hero_pos
 app.street.move_hero(.05)
 check(takeover.ok and takeover.success and app.hero_pos==start and not app.rules.settled.has(app.rules.control_event+":physical_action"),"rolled-back controlled movement against a real body cannot grant actual-action achievement")
 guard.present=false;app.hero_route=PackedVector2Array([app.hero_pos,app.hero_pos+Vector2(1,0)]);app.street.move_hero(.05)
 check(app.hero_pos.distance_to(start)>.0001 and app.rules.settled.has(app.rules.control_event+":physical_action"),"only final committed combat movement records controlled physical action")
 await capture("lateral_bed_stopped_actual")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Declared stationary actor/occlusion/contact fixtures through real box, lateral bed, kick, pause and JSON handlers. Not natural full route, all NPC combinations or formal art/audio acceptance."},"  "));file.close()
 print("STREET_PROPS_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
