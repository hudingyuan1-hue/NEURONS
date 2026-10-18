extends RefCounted
## S3:P1607–1611. One bag; shared attack timing/receipts, local swept contact.
const ACTOR="transporter_hospital"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func attack() -> Dictionary:return battle.config.attacks.sweep
func radius() -> float:return float(battle.config.test_parameters.laundry_bag_radius_m)
func state() -> Dictionary:
 if not battle.data.has("laundry_bag"):
  var a:Dictionary=battle.data.actors[ACTOR]
  battle.data.laundry_bag={"id":"street_hospital_laundry_bag","owner":ACTOR,"room":a.room,"center":a.pos.duplicate(),"heading":a.direction.duplicate(),"last_actor":a.pos.duplicate(),"raise_px":0.0,"phase":"drag","attack_id":"","path":[],"blocked":false,"recover_from":[]}
 return battle.data.laundry_bag
func heading() -> Vector2:
 var d:Vector2=battle.vector(battle.data.actors[ACTOR].direction)
 return d.normalized() if d.length_squared()>.0001 else Vector2.RIGHT
func dragged(at:Vector2,d:Vector2) -> Vector2:
 return at-d*.38+Vector2(-d.y,d.x)*.32
func sweep_point(progress:float) -> Vector2:
 var reach:float=float(attack().reach)-radius()
 # Stay inside the existing reach/width envelope; no new attack balance numbers.
 var half_angle:float=asin(clampf((float(attack().width)-radius())/reach,0,.95))
 return battle.position(ACTOR)+heading().rotated(lerpf(-half_angle,half_angle,clampf(progress,0,1)))*reach
func safe_pose(from:Vector2,to:Vector2) -> Vector2:
 var floor=battle.floor_for(str(battle.data.actors[ACTOR].room))
 var last:Vector2=from if floor.walkable(from,radius()) else battle.position(ACTOR)
 var count:int=maxi(1,ceili(last.distance_to(to)/float(battle.config.test_parameters.laundry_bag_step_m)))
 var origin:Vector2=last
 for i in range(1,count+1):
  var next:Vector2=origin.lerp(to,float(i)/count)
  if not floor.walkable(next,radius()) or not floor.clear_segment(last,next,radius()):break
  last=next
 return last
func sync() -> void:
 var s:Dictionary=state();var a:Dictionary=battle.data.actors[ACTOR]
 if a.hp<=0:
  s.owner="ground";s.raise_px=0.0;s.phase="ground";s.path=[];return
 var at:Vector2=battle.position(ACTOR);var moved:Vector2=at-battle.vector(s.last_actor)
 if moved.length_squared()>.000001 and a.phase=="idle":s.heading=battle.xy(moved.normalized())
 s.last_actor=a.pos.duplicate();s.room=a.room;s.owner=ACTOR
 var d:Vector2=battle.vector(s.heading)
 if a.phase=="windup":
  if str(s.attack_id)!=str(a.attack_id):s.attack_id=a.attack_id;s.blocked=false;s.path=[];s.recover_from=[]
  var progress:float=clampf(float(a.elapsed)/float(attack().windup),0,1)
  s.phase="tighten" if progress<.5 else "raise"
  s.center=battle.xy(safe_pose(battle.vector(s.center),dragged(at,d).lerp(sweep_point(0),progress)));s.raise_px=56.0*progress
 elif a.phase=="attack":
  if str(s.attack_id)!=str(a.attack_id):s.attack_id=a.attack_id;s.blocked=false;s.path=[]
  if s.path.is_empty():s.center=battle.xy(safe_pose(battle.vector(s.center),sweep_point(float(a.elapsed)/float(attack().active))))
  s.phase="swing";s.raise_px=56.0
 elif a.phase=="recover":
  if s.recover_from.is_empty():s.recover_from=s.center.duplicate()
  var progress:float=clampf(float(a.elapsed)/float(attack().recover),0,1)
  s.phase="lower" if progress<.6 else "regrip"
  s.center=battle.xy(safe_pose(battle.vector(s.center),battle.vector(s.recover_from).lerp(dragged(at,heading()),progress)));s.raise_px=56.0*(1.0-progress)
 else:
  s.phase="drag";s.center=battle.xy(safe_pose(at,dragged(at,d)));s.raise_px=0.0;s.path=[];s.recover_from=[]
func path_between(start:float,end:float) -> Dictionary:
 var floor=battle.floor_for(str(battle.data.actors[ACTOR].room))
 var step:float=float(battle.config.test_parameters.laundry_bag_step_m)
 var count:int=maxi(1,ceili((sweep_point(end)-sweep_point(start)).length()/step))
 var points:Array=[]
 for i in range(count+1):
  var point:Vector2=sweep_point(lerpf(start,end,float(i)/count))
  if not floor.walkable(point,radius()):return {"points":points,"blocked":true}
  if not points.is_empty() and not floor.clear_segment(battle.vector(points[-1]),point,radius()):return {"points":points,"blocked":true}
  points.append(battle.xy(point))
 return {"points":points,"blocked":false}
func prepare_step(delta:float) -> void:
 var a:Dictionary=battle.data.actors[ACTOR];var s:Dictionary=state()
 if a.phase!="attack":return
 var active:float=float(attack().active)
 var sweep:Dictionary=path_between(clampf(float(a.elapsed)/active,0,1),clampf((float(a.elapsed)+delta)/active,0,1))
 s.path=sweep.points;s.blocked=sweep.blocked
 if not s.path.is_empty():s.center=s.path[-1].duplicate()
 if sweep.blocked:
  # Shared attack handler still settles any contact before the obstacle and
  # performs the complete original recovery/cooldown. Never reverse-swing.
  a.elapsed=maxf(float(a.elapsed),active-delta)
func finish_step(before:String) -> void:
 var a:Dictionary=battle.data.actors[ACTOR];var s:Dictionary=state()
 if before=="attack" and a.phase=="recover":s.recover_from=s.center.duplicate()
 sync()
func contains(target:Vector2) -> bool:
 var a:Dictionary=battle.data.actors[ACTOR]
 if not a.present or a.hp<=0 or a.hurt>0:return false
 var points:Array=[]
 if a.phase=="windup":points=path_between(0,1).points
 elif a.phase=="attack":points=state().path
 else:return false
 var floor=battle.floor_for(str(a.room));var contact:float=radius()+.21
 for i in range(points.size()):
  var previous:Vector2=battle.vector(points[maxi(0,i-1)])
  var next:Vector2=battle.vector(points[i])
  var closest:Vector2=Geometry2D.get_closest_point_to_segment(target,previous,next)
  if closest.distance_squared_to(target)<=contact*contact and floor.clear_segment(closest,target):return true
 return false
