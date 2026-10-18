extends "res://tests/street_belt_check.gd"
## Four declared destination bodies after source door intent; real world/nav/cross handlers.
func occupy(id:String,to:String,side_value:float) -> void:
 var a:Dictionary=actor_at(id,Vector2.ZERO);var portal:Dictionary=app.street.floor_for(to).portal("street_narrow");var inward:Vector2=portal.inward
 a.room=to;a.pos=app.street.xy(Vector2(portal.landing)+Vector2(-inward.y,inward.x)*side_value);a.hp=app.street.spec(id).hp
func pending(to:String) -> void:
 app.hero_pos=app.layout.portal(to).threshold;app.hero_route=PackedVector2Array();app.motion.clear();app.street.data.destination=to;app.street.data.door_left=.025
func actual_step_aside(id:String) -> bool:
 var a:Dictionary=app.street.data.actors[id];var from:Vector2=app.street.position(id);var portal:Dictionary=app.street.floor_for(str(a.room)).portal("street_narrow");var goal:Vector2=from+Vector2(portal.inward)*.9;var bounded:bool=true
 for i in range(60):
  var previous:Vector2=app.street.position(id);app.street._move_actor(id,goal,.025)
  bounded=bounded and previous.distance_to(app.street.position(id))<=.022501
 return bounded and app.street.position(id).distance_to(goal)<.05
func await_cross(to:String) -> bool:
 for i in range(100):
  step(.025)
  if app.room_id!= "street_narrow":return app.room_id==to
 return false
func _ready() -> void:
 name="CampaignCheck";frontend=get_parent();folder="res://../docs/validation/street_director_20261018/doors"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await frames();await frontend.show_profile();frontend.name_field.text="两门实际新占位与恢复通过验证";frontend.overwrite_armed=true;frontend.new_game();await frames();app=frontend.active
 if app.tutorial_ui!=null:app.tutorial_ui.finish()
 app.set_process(false);clear_lines();app.paused_manual=true;app.home.enabled=false;app.family.enabled=false;app.unlock_combat();no_actors();app.unlock_street();app.enter_room("street_narrow");no_street();app.rules.end_control();app.rules.hp=100;app.rules.sp=80
 # Declare actual threshold/intent first; add four physically separated bodies afterwards.
 pending("street_plaza");occupy("register_nurse","street_plaza",-.24);occupy("back","street_plaza",.24);occupy("postop","street_twisted",-.24);occupy("transport_patient","street_twisted",.24)
 step(.025)
 check(app.room_id=="street_narrow" and app.street.data.destination=="street_plaza" and app.street.data.door_left>0,"newly occupied west destination stops already-pending actual crossing without losing intent")
 check(not app.street._landing_clear("street_narrow","street_plaza",0) and not app.street._landing_clear("street_narrow","street_twisted",0),"both actual destination mouths are simultaneously occupied by four unique bodies")
 await capture("01_actual_west_pending_blocked");pending("street_twisted");step(.025)
 check(app.room_id=="street_narrow" and app.street.data.destination=="street_twisted" and app.rules.hp==100,"same simultaneous setup also blocks east pending crossing without teleport or invented damage")
 await capture("02_actual_east_pending_blocked")
 check(disk() and app.street.data.destination=="street_twisted","real JSON preserves all four original bodies and pending blocked destination")
 var clock:float=app.street.data.clock;var left:float=app.street.data.door_left;var pos:Vector2=app.hero_pos;app._process(.7)
 check(app.hero_pos.is_equal_approx(pos) and is_equal_approx(clock,float(app.street.data.clock)) and is_equal_approx(left,float(app.street.data.door_left)),"manual pause after restore freezes pending crossing rather than running its retry timer")
 pending("street_plaza")
 check(actual_step_aside("back"),"one original west blocker really navigates inward at existing speed rather than teleporting or disappearing")
 var lane:Dictionary=app.street.hero_portal("street_plaza")
 check(absf(float(lane.get("lane_offset",0)))>.4,"existing1.4m doorway selects an actual side lane after one blocker moves")
 check(await_cross("street_plaza"),"same pending west intent resumes ordinary world walking and actually crosses free lane without another click")
 var clear:bool=true
 for id in ["register_nurse","back"]:clear=clear and app.hero_pos.distance_to(app.street.position(id))>=.4299
 check(clear and app.layout.walkable(app.hero_pos) and app.rules.hp==100,"actual west landing preserves full body clearance without overlap or new damage")
 await capture("03_actual_west_clearance_after_cross")
 app.enter_room("street_narrow");pending("street_twisted");step(.025)
 check(app.room_id=="street_narrow" and app.street.data.door_left>0,"freeing west does not silently clear the still-blocked opposite destination")
 check(actual_step_aside("transport_patient"),"one east blocker really moves within existing destination geometry and speed")
 check(await_cross("street_twisted"),"east pending crossing similarly resumes through remaining physical lane")
 clear=true
 for id in ["postop","transport_patient"]:clear=clear and app.hero_pos.distance_to(app.street.position(id))>=.4299
 check(clear and app.rules.hp==100 and app.street.data.actors.size()==45,"second actual landing keeps all45 unique identities and no overlap, extra exit or forced injury")
 await capture("04_actual_east_clearance_after_cross")
 var file:=FileAccess.open(ProjectSettings.globalize_path(folder).path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Four explicit stationary destination bodies appear after declared source threshold/intent in original two-door narrow room; actual world retry, disk/manual pause and real blocker _move_actor then source walk/cross/target landing. Source threshold/intent and later switch to opposite door are explicit fixtures, not autonomous choice of both exits or natural mixed crowd/large wheelchair coverage. Existing1.4m apertures/topology/45 identities preserved."},"  "));file.close()
 print("STREET_DOOR_BLOCK_CHECK %d passed %d failed"%[passes.size(),failures.size()]);app.audio.reset_scene();frontend.request_exit(0 if failures.is_empty() else 1)
