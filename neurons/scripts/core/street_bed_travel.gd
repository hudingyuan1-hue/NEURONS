extends RefCounted
## Same physical bed across existing portal frames; no respawn or distant tracking.
var owner_ref:WeakRef
var bed:
 get:return owner_ref.get_ref()
var battle:
 get:return bed.battle
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func v(a:Array) -> Vector2:return battle.vector(a)
func xy(p:Vector2) -> Array:return battle.xy(p)
func right(axis:Vector2) -> Vector2:return Vector2(axis.y,-axis.x)
func grip() -> float:return float(battle.config.test_parameters.bed_travel_grip_m)
func edge() -> float:return (grip()+.21-battle.Bed.HALF_WIDTH)*.5
func phase() -> String:return str(battle.data.lateral_bed.get("travel",{}).get("phase",""))
func _portal(room:String,to:String) -> Dictionary:return battle.floor_for(room).portal(to)

func _static(room:String,center:Vector2,axis:Vector2,offset:float,portals:Array=[]) -> bool:
 var space=battle.floor_for(room)
 return battle.Bed.clear(space,bed.anchor(center,axis),axis,portals) and space.walkable(center-right(axis)*offset,.21)

func _sweep(room:String,from:Vector2,to:Vector2,old_axis:Vector2,axis:Vector2,old_grip:float,offset:float,portals:Array=[],people:bool=true) -> bool:
 var sweep:Dictionary=battle.Bed.sweep(battle.floor_for(room),bed.anchor(from,old_axis),bed.anchor(to,axis),old_axis,axis,portals)
 if not sweep.complete:return false
 # Bed.sweep samples the anchor; sample the actual center/operator in the same
 # angular steps too, so an offset handle cannot cut through a person or wall.
 var steps:int=maxi(1,ceili((from.distance_to(to)+absf(old_axis.angle_to(axis))*1.1)/.023))
 for i in range(steps+1):
  var t:float=float(i)/steps;var dir:Vector2=old_axis.rotated(old_axis.angle_to(axis)*t)
  var center:Vector2=from.lerp(to,t);var operator:Vector2=center-right(dir)*lerpf(old_grip,offset,t)
  if not _static(room,center,dir,lerpf(old_grip,offset,t),portals):return false
  if not battle.floor_for(room).walkable(operator,.21):return false
  if people and not bed._people_clear(center,dir,operator,room):return false
 return true

func _apply(center:Vector2,axis:Vector2,offset:float,portals:Array=[]) -> bool:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[bed.CARRIER]
 var old:float=v(b.center).distance_to(v(b.operator))
 if not _sweep(str(b.room),v(b.center),center,v(b.axis),axis,old,offset,portals):return false
 b.center=xy(center);b.axis=xy(axis);b.push=xy(right(axis));b.operator=xy(center-right(axis)*offset);a.pos=b.operator.duplicate();a.direction=b.push.duplicate()
 return true

func _path(room:String,from:Vector2,to:Vector2,axis:Vector2) -> Array:
 if _sweep(room,from,to,axis,axis,grip(),grip(),[],false):return [xy(to)]
 # Only plan once per failed/consumed route, for this rigid transport pose.
 # Body-only navigation is too small for a 1.9m bed and side operator.
 var cell:float=float(battle.config.test_parameters.bed_travel_grid_m)
 var nav:=AStarGrid2D.new();var size:Vector2=battle.floor_for(room).world_size()
 nav.region=Rect2i(Vector2i.ZERO,Vector2i(ceili(size.x/cell)+1,ceili(size.y/cell)+1));nav.cell_size=Vector2.ONE*cell
 nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav.update()
 for y in range(nav.region.size.y):
  for x in range(nav.region.size.x):nav.set_point_solid(Vector2i(x,y),not _static(room,Vector2(x,y)*cell,axis,grip()))
 var starts:Array[Vector2i]=[];var ends:Array[Vector2i]=[]
 for dy in range(-1,2):
  for dx in range(-1,2):
   var start:=Vector2i((from/cell).round())+Vector2i(dx,dy);var finish:=Vector2i((to/cell).round())+Vector2i(dx,dy)
   if nav.is_in_boundsv(start) and not nav.is_point_solid(start) and _sweep(room,from,Vector2(start)*cell,axis,axis,grip(),grip(),[],false):starts.append(start)
   if nav.is_in_boundsv(finish) and not nav.is_point_solid(finish) and _sweep(room,Vector2(finish)*cell,to,axis,axis,grip(),grip(),[],false):ends.append(finish)
 for start in starts:
  for finish in ends:
   var points:PackedVector2Array=nav.get_point_path(start,finish)
   if points.is_empty():continue
   var result:Array=[];var previous:Vector2=from;var valid:bool=true
   for point in points:
    if not _sweep(room,previous,point,axis,axis,grip(),grip(),[],false):valid=false;break
    if previous.distance_to(point)>.001:result.append(xy(point))
    previous=point
   if valid:result.append(xy(to));return result
 return []

func _entry_clear(from:String,to:String) -> bool:
 var mouth:Dictionary=_portal(from,to);var entry:Dictionary=_portal(to,from)
 if mouth.is_empty() or entry.is_empty():return false
 var width:float=battle.Bed.HALF_WIDTH+grip()+.21+.06
 if float(mouth.width_m)+.00001<width or float(entry.width_m)+.00001<width:return false
 var axis:Vector2=entry.inward;var center:Vector2=Vector2(entry.at)+right(axis)*edge()
 var goal:Vector2=center+axis*float(battle.config.test_parameters.bed_travel_staging_m)
 return _sweep(to,center,goal,axis,axis,grip(),grip(),[entry])

func _return_clear(from:String,to:String) -> bool:
 var entry:Dictionary=_portal(to,from)
 if entry.is_empty():return false
 var axis:Vector2=-Vector2(entry.inward);var center:Vector2=Vector2(entry.at)+right(axis)*edge()
 return _sweep(to,center,center+Vector2(entry.inward)*float(battle.config.test_parameters.bed_travel_staging_m),axis,axis,grip(),grip(),[entry])

func _finish(reason:String="arrived") -> void:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[bed.CARRIER]
 var t:Dictionary=b.get("travel",{});var to:String=str(t.get("to",""))
 app.rules._record("street_bed_travel_finished","bed_travel:%d:%d:%s"%[app.rules.actual_attempt,battle.data.serial,reason],{"room":b.room,"to":to,"reason":reason})
 b.travel={};a.phase="idle";a.route=[];a.goal=[]
 if str(a.follow)==to:a.follow=""

func _withdraw(delta:float) -> void:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[bed.CARRIER];var t:Dictionary=b.travel
 var room:String=str(b.room);var mouth:Dictionary=_portal(room,str(t.to))
 if mouth.is_empty():_finish("invalid_portal");return
 var inward:Vector2=mouth.inward
 if not t.has("withdraw_goal"):
  # Return off the mouth before waiting; never sit on a sole entrance.
  t.withdraw_goal=[]
  for direction in [inward,(inward+right(v(b.axis))).normalized(),(inward-right(v(b.axis))).normalized(),right(v(b.axis)),-right(v(b.axis))]:
   var goal:Vector2=v(b.center)+direction*float(battle.config.test_parameters.bed_travel_retreat_m)
   if _sweep(room,v(b.center),goal,v(b.axis),v(b.axis),grip(),grip(),[mouth]):t.withdraw_goal=xy(goal);break
 if t.withdraw_goal.is_empty():_finish("blocked_safe_stop");return
 var goal:Vector2=v(t.withdraw_goal);var next:Vector2=v(b.center).move_toward(goal,float(battle.config.test_parameters.actor_speed_m_s)*delta)
 a.phase="bed_retreat"
 var offset:float=move_toward(v(b.center).distance_to(v(b.operator)),grip(),delta*.2)
 if not _apply(next,v(b.axis),offset,[mouth]):_finish("blocked_safe_stop");return
 if next.distance_to(goal)<.01:
  if t.get("retry_turn",false) and int(t.get("turn_tries",0))<2:
   t.phase="turn";t.wait=0.0;t.route=[];t.planned=false;t.turn_tries=int(t.get("turn_tries",0))+1;t.erase("withdraw_goal")
  else:_finish("cannot_fit_retreat")

func tick(delta:float) -> bool:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[bed.CARRIER]
 if phase().is_empty():
  if str(a.follow).is_empty():return false
  var to:String=str(a.follow)
  if to not in battle.map.doors(str(b.room)) or to==str(battle.config.exit_id):a.follow="";return true
  b.travel={"phase":"turn","to":to,"route":[],"wait":0.0};battle.data.serial+=1
 var t:Dictionary=b.travel;var room:String=str(b.room);var to:String=str(t.to)
 if t.phase=="withdraw":_withdraw(delta);return true
 var source:String=str(t.get("from",room))
 var mouth:Dictionary=_portal(room,source if t.phase in ["enter","back_enter"] else to)
 if mouth.is_empty():_finish("invalid_portal");return true
 var axis:Vector2=Vector2(mouth.inward) if t.phase in ["enter","back_enter"] else -Vector2(mouth.inward)
 var goal:Vector2=Vector2(mouth.at)+Vector2(mouth.inward)*float(battle.config.test_parameters.bed_travel_staging_m)+right(axis)*edge()
 a.phase="bed_turn" if t.phase=="turn" else "bed_travel"
 if t.phase=="turn":
  var turn:float=clampf(v(b.axis).angle_to(axis),-float(battle.config.test_parameters.bed_turn_rad_s)*delta,float(battle.config.test_parameters.bed_turn_rad_s)*delta)
  # Limit the handle's arc to the ordinary movement speed.
  turn=clampf(turn,-float(battle.config.test_parameters.actor_speed_m_s)*delta/.8,float(battle.config.test_parameters.actor_speed_m_s)*delta/.8)
  var offset:float=move_toward(v(b.center).distance_to(v(b.operator)),grip(),delta*.2)
  if _apply(v(b.center),v(b.axis).rotated(turn),offset):
   t.wait=0.0
   if absf(v(b.axis).angle_to(axis))<.002 and absf(offset-grip())<.001:t.phase="approach"
  else:t.wait+=delta
 elif t.phase=="approach":
  if not t.get("planned",false):t.route=_path(room,v(b.center),goal,axis);t.planned=true
  if t.route.is_empty():t.wait+=delta
  else:
   var next:Vector2=v(b.center).move_toward(v(t.route[0]),float(battle.config.test_parameters.actor_speed_m_s)*delta)
   if _apply(next,axis,grip()):
    t.wait=0.0
    if next.distance_to(v(t.route[0]))<.001:t.route.pop_front()
   else:t.wait+=delta
  if v(b.center).distance_to(goal)<.02:t.phase="cross";t.wait=0.0
 elif t.phase=="cross":
  if not _entry_clear(room,to):t.wait+=delta
  else:
   goal=Vector2(mouth.at)+right(axis)*edge()
   var next:Vector2=v(b.center).move_toward(goal,float(battle.config.test_parameters.actor_speed_m_s)*delta)
   if _apply(next,axis,grip(),[mouth]):
    t.wait=0.0
    if next.distance_to(goal)<.001:
     # Existing rooms use local portal frames. Map the *same* pose across the
     # mouth only after the real source sweep and destination clearance pass.
     var entry:Dictionary=_portal(to,room);var new_axis:Vector2=entry.inward
     b.room=to;b.axis=xy(new_axis);b.push=xy(right(new_axis));b.center=xy(Vector2(entry.at)+right(new_axis)*edge());b.operator=xy(v(b.center)-v(b.push)*grip())
     a.room=to;a.pos=b.operator.duplicate();a.direction=b.push.duplicate();a.route=[];a.goal=[]
     t.from=room;t.phase="enter";t.wait=0.0
     app.rules._record("street_bed_crossed","bed_cross:%d:%d"%[app.rules.actual_attempt,battle.data.serial],{"from":room,"to":to,"object":b.id,"source":"S3:P1762/P1785"})
   else:t.wait+=delta
 elif t.phase=="enter":
  var next:Vector2=v(b.center).move_toward(goal,float(battle.config.test_parameters.actor_speed_m_s)*delta)
  if _apply(next,axis,grip(),[mouth]):
   t.wait=0.0
   if next.distance_to(goal)<.01:_finish()
  else:t.wait+=delta
 elif t.phase=="back_enter":
  a.phase="bed_retreat"
  if not _return_clear(room,source):
   b.blocked_reason="both_portal_sides_occupied";return true # Physical blockage, no teleport or corpse removal.
  goal=Vector2(mouth.at)+right(axis)*edge()
  var next:Vector2=v(b.center).move_toward(goal,float(battle.config.test_parameters.actor_speed_m_s)*delta)
  if _apply(next,axis,grip(),[mouth]):
   if next.distance_to(goal)<.001:
    var entry:Dictionary=_portal(source,room);var old_axis:Vector2=-Vector2(entry.inward)
    b.room=source;b.axis=xy(old_axis);b.push=xy(right(old_axis));b.center=xy(Vector2(entry.at)+right(old_axis)*edge());b.operator=xy(v(b.center)-v(b.push)*grip())
    a.room=source;a.pos=b.operator.duplicate();a.direction=b.push.duplicate();a.route=[];a.goal=[]
    t.phase="withdraw";t.wait=0.0;t.retry_turn=false;t.erase("withdraw_goal")
    app.rules._record("street_bed_returned","bed_return:%d:%d"%[app.rules.actual_attempt,battle.data.serial],{"from":room,"to":source,"object":b.id,"cause":"destination_blocked_after_entry"})
  return true
 if not b.get("travel",{}).is_empty() and float(t.wait)>=float(battle.config.test_parameters.bed_travel_wait_s):
  if t.phase=="enter":t.phase="back_enter";t.wait=0.0
  else:t.retry_turn=t.phase=="turn";t.phase="withdraw";t.wait=0.0
 return true
