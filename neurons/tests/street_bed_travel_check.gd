extends "res://tests/street_props_check.gd"
## Explicit source/destination cast and pose fixtures. Production follow/portal paths.
func capture(value:String) -> void:
 app.update_ui();app.keep_metric_actor_visible();app.view.queue_redraw();await super.capture(value)
func travel_fixture(from:String,to:String,center:Vector2) -> void:
 app.enter_room(from);setup_bed(center)
 var a:Dictionary=app.street.data.actors.transporter_asylum
 a.last_seen_at=app.street.data.clock
 app.enter_room(to);app.hero_pos=Vector2(7,4.7);app.street.data.actors.transporter_asylum.follow=to
 app.street.lateral_bed.normalize()
func run_trip(limit:int=1600) -> Dictionary:
 var valid:bool=true;var crossed:bool=false;var a:Dictionary=app.street.data.actors.transporter_asylum
 var b:Dictionary=app.street.data.lateral_bed;var before_room:String=str(b.room);var steps:int=0
 for i in range(limit):
  steps=i+1;var at:Vector2=app.street.vector(b.center);var person:Vector2=app.street.position("transporter_asylum");var axis:Vector2=app.street.vector(b.axis);var previous_phase:String=app.street.lateral_bed.travel.phase()
  app.street.lateral_bed.actor(.025)
  if b.room==before_room:
   if at.distance_to(app.street.vector(b.center))>.85*.025+.0001 or person.distance_to(app.street.position("transporter_asylum"))>.9*.025+.0001 or absf(axis.angle_to(app.street.vector(b.axis)))>1.8*.025+.0001:valid=false
  else:
   crossed=true
   var mouth:Dictionary=app.street.floor_for(before_room).portal(str(b.room))
   if previous_phase!="cross" or absf((at-Vector2(mouth.at)).dot(Vector2(mouth.inward)))>.03:valid=false
   before_room=str(b.room)
  if str(a.follow).is_empty() and app.street.lateral_bed.travel.phase().is_empty():break
 return {"valid":valid,"crossed":crossed,"steps":steps,"room":b.room,"phase":app.street.lateral_bed.travel.phase()}

func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_bed_travel_20261018/finite"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="侧挤床跨段验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street()
 var trips:Array=[]
 for pair in [["street_twisted","street_node",Vector2(12,6)],["street_node","street_twisted",Vector2(6,6)],["street_twisted","street_maintenance",Vector2(8,6)],["street_maintenance","street_twisted",Vector2(6,4)]]:
  travel_fixture(pair[0],pair[1],pair[2]);var before:int=app.rules.hp;var result:Dictionary=run_trip();trips.append(result)
  check(result.valid,"actual per-step body/bed/rotation limits and portal-only coordinate mapping: "+str(pair[0])+"→"+str(pair[1]))
  check(result.crossed and result.room==pair[1] and result.phase=="","same carrier and bed complete existing doorway: "+str(pair[0])+"→"+str(pair[1]))
  check(app.rules.hp==before and app.street.data.actors.size()==45,"ordinary transport makes no attack damage or extra patient: "+str(pair[1]))
 var diagnostic:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("trip_diagnostics.json"),FileAccess.WRITE);diagnostic.store_string(JSON.stringify(trips,"  "));diagnostic.close()
 await capture("01_arrived_bed")

 travel_fixture("street_twisted","street_node",Vector2(12,6))
 for i in range(12):app.street.lateral_bed.actor(.025)
 var b:Dictionary=app.street.data.lateral_bed;var axis:Array=b.axis.duplicate();var center:Array=b.center.duplicate()
 app._process(.5)
 check(b.axis==axis and b.center==center and app.street.lateral_bed.travel.phase()=="turn","actual manual pause freezes in-progress turn")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved) and app.street.vector(app.street.data.lateral_bed.axis).is_equal_approx(app.street.vector(axis)) and app.street.data.lateral_bed.travel.to=="street_node","JSON reload keeps same partial rotation and pending destination")
 app.set_process(false);app.paused_manual=true;clear_lines();var result:Dictionary=run_trip()
 check(result.crossed and result.room=="street_node","restored partial turn follows remaining route without bed respawn")

 travel_fixture("street_twisted","street_node",Vector2(12,6))
 var blocker:Dictionary=app.street.data.actors.register_nurse;blocker.present=true;blocker.hp=40;blocker.room="street_node";blocker.pos=[1.1,6]
 result=run_trip()
 check(not result.crossed and result.room=="street_twisted" and result.phase=="","occupied destination causes real withdrawal, never teleporting through a person")
 var mouth:Dictionary=app.street.floor_for("street_twisted").portal("street_node")
 check(not app.street.lateral_bed.touches("street_twisted",mouth.threshold,.21),"blocked large carrier finishes away from the return doorway")

 travel_fixture("street_twisted","street_node",Vector2(12,6));app.street.floor_for("street_node").portal_width_m=1.1
 result=run_trip()
 check(not result.crossed and result.phase=="" and result.room=="street_twisted","declared narrow-mouth fixture rejects actual combined bed/operator width and withdraws")
 app.street.floor_for("street_node").portal_width_m=1.4

 travel_fixture("street_twisted","street_node",Vector2(12,6));b=app.street.data.lateral_bed
 for i in range(1000):
  app.street.lateral_bed.actor(.025)
  if app.street.lateral_bed.travel.phase()=="cross" and absf((app.street.vector(b.center)-Vector2(mouth.at)).dot(Vector2(mouth.inward)))<.3:break
 check(b.room=="street_twisted" and app.street.lateral_bed.travel.phase()=="cross","fixture reaches real door-crossing sweep before death")
 var dead_at:Array=b.center.duplicate();app.street.damage_actor("father","transporter_asylum",60,"fixture:transport-death");app.street.lateral_bed.actor(.025)
 check(b.center==dead_at and app.street.data.actors.transporter_asylum.hp==0 and app.street.lateral_bed.travel.phase()=="","death leaves stationary traveling bed at its actual pose, without posthumous locomotion")
 app.enter_room("street_twisted");app.hero_pos=Vector2(16,6);app.rules.hp=100;app.rules.hurt_left=0;app.rules.end_control()
 var raw:Dictionary=app.layout.portal("street_node");var lane:Dictionary=app.street.hero_portal("street_node")
 check(absf(float(lane.get("lane_offset",0)))>.4 and not app.street.bed_blocks(app.room_id,lane.threshold,.21),"dead bed at door center still leaves a real body-width lane inside the same aperture")
 var patch:Dictionary=app.street.lateral_bed.push_blocker(app.layout,app.street.lateral_bed.rect(),{"at":app.street.lateral_bed.anchor(app.street.vector(b.center),app.street.vector(b.axis)),"axis":app.street.vector(b.axis)})
 check(not app.layout.path(app.hero_pos,lane.threshold).is_empty(),"actual rotated-footprint navigation reaches remaining door lane after carrier death")
 app.street.lateral_bed.pop_blocker(app.layout,patch)
 app.keep_metric_actor_visible()
 var screen:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.hero_pos)
 check(Rect2(199,284,882,262).has_point(screen),"actual Street automatic camera keeps host feet inside the existing combat safe frame")
 app.view_controls.manual_view=true;app.camera.position=app.layout.project(app.street.vector(b.center))+Vector2(0,-80);app.view_controls.clamp_camera()
 var camera_at:Vector2=app.camera.position;app.keep_metric_actor_visible()
 check(app.camera.position==camera_at,"manual current-room view still takes priority over automatic Street following")
 await capture("02a_dead_bed_same_door_lane") # Camera-only framing fixture, no pose edits.
 app.view_controls.reset()
 for i in range(600):
  app.street._hero(.025)
  if app.room_id=="street_node":break
 check(app.room_id=="street_node" and not app.street.bed_blocks(app.room_id,app.hero_pos,.21),"autonomous host physically approaches side lane and crosses existing door without collision bypass")
 await capture("02_dead_bed_passage")
 var source_floor=app.street.floor_for("street_twisted")
 patch=app.street.lateral_bed.push_blocker(source_floor,app.street.lateral_bed.rect(),{"at":app.street.lateral_bed.anchor(app.street.vector(b.center),app.street.vector(b.axis)),"axis":app.street.vector(b.axis)})
 var cut_from:Vector2=app.street.vector(b.center)+Vector2(-1.17,.49);var cut_to:=Vector2(19.52,6.47)
 check(source_floor.walkable(cut_from) and source_floor.walkable(cut_to) and not source_floor.clear_segment(cut_from,cut_to,.21),"clear endpoints cannot conceal a line crossing the stopped bed's rounded corner")
 app.street.lateral_bed.pop_blocker(source_floor,patch)

 travel_fixture("street_twisted","street_node",Vector2(12,6))
 for i in range(1000):
  app.street.lateral_bed.actor(.025)
  if app.street.lateral_bed.travel.phase()=="enter":break
 var count:int=app.rules.facts.filter(func(f):return f.kind=="street_bed_crossed").size();var neurons:int=app.rules.neurons
 saved=JSON.parse_string(JSON.stringify(app.snapshot_data()))
 check(app.restore_snapshot(saved) and app.street.lateral_bed.travel.phase()=="enter","half-entered destination keeps the same bed and source portal frame through JSON")
 app.set_process(false);app.paused_manual=true;clear_lines();result=run_trip()
 check(result.room=="street_node" and result.phase=="" and app.rules.facts.filter(func(f):return f.kind=="street_bed_crossed").size()==count and app.rules.neurons==neurons,"resuming after frame mapping never crosses twice or grants another room reward")

 travel_fixture("street_twisted","street_node",Vector2(12,6));b=app.street.data.lateral_bed
 for i in range(1000):
  app.street.lateral_bed.actor(.025)
  if app.street.lateral_bed.travel.phase()=="cross" and absf((app.street.vector(b.center)-Vector2(mouth.at)).dot(Vector2(mouth.inward)))<1.0:break
 blocker=app.street.data.actors.register_nurse;blocker.present=true;blocker.hp=40;blocker.room="street_node";blocker.pos=[1.1,6]
 result=run_trip()
 check(not result.crossed and result.room=="street_twisted" and result.phase=="","newly arriving blocker during the crossing sweep forces actual backing out")
 check(not app.street.lateral_bed.touches("street_twisted",mouth.threshold,.21),"mid-cross obstruction does not leave a live permanent mouth guard")

 travel_fixture("street_twisted","street_node",Vector2(12,6));b=app.street.data.lateral_bed
 for i in range(20):app.street.lateral_bed.actor(.025)
 var a:Dictionary=app.street.data.actors.transporter_asylum;var start:Vector2=app.street.position("transporter_asylum");var body_to_center:Vector2=(app.street.vector(b.center)-start).normalized()
 app.enter_room("street_twisted");app.hero_pos=start-body_to_center*.7;app.rules.skill_states.KNEE.unlocked=true;app.rules.control_left=10;app.rules.kick_until=0;app.rules.action.clear()
 var kick:Dictionary=app.rules.begin_kick({"direction":app.street.xy(body_to_center)},true);app.rules.advance_kick(.2);var traces:int=app.street.materials.state().surfaces.size();app.street.kick_contact();app.street.kick_contact()
 check(kick.ok and a.hp==45 and not app.street.lateral_bed.touches("street_twisted",app.street.position("transporter_asylum"),.21),"real carrier kick keeps original damage and cannot displace his body through his own bed")
 check(app.street.materials.state().surfaces.size()==traces+1,"one actual kick injury produces one local trace, not repeated marks for one contact")
 center=b.center.duplicate();axis=b.axis.duplicate();app.street.lateral_bed.actor(.025)
 check(b.center==center and b.axis==axis and a.hurt>0,"carrier hurt interrupts transit without moving or deleting the current bed")
 await capture("03_interrupted_transport")
 travel_fixture("street_twisted","street_node",Vector2(18.9,6));result=run_trip()
 check(result.crossed and result.room=="street_node" and result.phase=="" and result.valid,"bed already near wall backs into turning space and retries boundedly before crossing")
 travel_fixture("street_twisted","street_node",Vector2(12,6));b=app.street.data.lateral_bed
 for i in range(1000):
  app.street.lateral_bed.actor(.025)
  if app.street.lateral_bed.travel.phase()=="enter":break
 blocker=app.street.data.actors.register_nurse;blocker.present=true;blocker.hp=40;blocker.room="street_node";blocker.pos=[2.3,6]
 for i in range(600):
  app.street.lateral_bed.actor(.025)
  if app.street.lateral_bed.travel.phase().is_empty():break
 check(b.room=="street_twisted" and app.street.lateral_bed.travel.phase().is_empty(),"new obstruction after entry makes the same bed reverse through the same aperture and retreat in source")
 check(not app.street.lateral_bed.touches("street_twisted",mouth.threshold,.21),"post-entry reversal leaves source doorway available instead of guarding it indefinitely")
 var f:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"passes":passes,"failures":failures,"rendered":DisplayServer.get_name()!="headless","scope":"Four clear-floor/cast/pose fixtures through real follow requests, exact transport sweeps, manual pause/JSON, blocked and temporarily narrower portal fixtures, actual death and autonomous side-lane exit. Not all crowd combinations, natural all-game/human/formal art/audio acceptance."},"  "));f.close()
 if not failures.is_empty():
  f=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("failure_snapshot.json"),FileAccess.WRITE);f.store_string(JSON.stringify(app.snapshot_data(),"  "));f.close()
 print("STREET_BED_TRAVEL_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
