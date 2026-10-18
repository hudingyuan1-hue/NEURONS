extends RefCounted
## S3:P1596–1601: fixed-direction broken bottle, actual swept glass contact.
const ID="father"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.sweep
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func state() -> Dictionary:
 if not battle.data.has("father_bottle"):battle.data.father_bottle={"owner":ID,"phase":"lowered","attack_id":"","profile":[],"sweep":[],"blocked":false,"recover_profile":[]}
 return battle.data.father_bottle
func profile(progress:float) -> Array:
 var radius:float=param("bottle_radius_m");var half:float=param("bottle_length_m")*.5
 var reach:float=float(attack().reach)-radius;var angle:float=asin(clampf((float(attack().width)-radius)/reach,0,.95))
 var d:Vector2=direction().rotated(lerpf(-angle,angle,clampf(progress,0,1)))
 var length:float=lerpf(param("bottle_near_m"),reach-half,sin(clampf(progress,0,1)*PI))
 var at:Vector2=battle.position(ID)+d*length
 return [battle.xy(at-d*half),battle.xy(at+d*half)]
func rest_profile() -> Array:
 var d:Vector2=direction();var at:Vector2=battle.position(ID)+d*.25+Vector2(-d.y,d.x)*param("bottle_shoulder_m")
 return [battle.xy(at),battle.xy(at+d*param("bottle_length_m"))]
func clear_profile(p:Array,previous:Array=[]) -> bool:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("bottle_radius_m")
 if not floor.clear_segment(battle.vector(p[0]),battle.vector(p[1]),radius) or not floor.clear_segment(battle.position(ID),battle.vector(p[0]),radius):return false
 if not previous.is_empty():
  for i in range(2):
   if not floor.clear_segment(battle.vector(previous[i]),battle.vector(p[i]),radius):return false
 return true
func sweep_between(start:float,end:float) -> Dictionary:
 var points:Array=[];var steps:int=maxi(1,ceili((end-start)*(float(attack().reach)*PI+param("bottle_length_m"))/param("bottle_sample_m")))
 for i in range(steps+1):
  var p:Array=profile(lerpf(start,end,float(i)/steps))
  if not clear_profile(p,[] if points.is_empty() else points[-1]):return {"points":points,"blocked":true}
  points.append(p)
 return {"points":points,"blocked":false}
func before_actor() -> void:
 if actor().hurt>0 and actor().phase in ["windup","attack"]:actor().phase="recover";actor().elapsed=0
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if a.hp<=0:s.phase="attached_to_body";s.profile=rest_profile();s.sweep=[];return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.sweep=[];s.recover_profile=[]
  s.phase="shoulder_turn" if a.elapsed<float(attack().windup)*.5 else "bottle_raise"
  var from:Array=rest_profile();var to:Array=profile(0);var candidate:Array=[];var t:float=clampf(float(a.elapsed)/float(attack().windup),0,1)
  for i in range(2):candidate.append(battle.xy(battle.vector(from[i]).lerp(battle.vector(to[i]),t)))
  if clear_profile(candidate):s.profile=candidate
 elif a.phase=="attack":s.phase="glass_sweep"
 elif a.phase=="recover":
  if s.recover_profile.is_empty():s.recover_profile=(rest_profile() if s.profile.is_empty() else s.profile).duplicate(true)
  s.phase="arm_retract";var from:Array=s.recover_profile;var to:Array=rest_profile();var candidate:Array=[]
  for i in range(2):candidate.append(battle.xy(battle.vector(from[i]).lerp(battle.vector(to[i]),clampf(float(a.elapsed)/float(attack().recover),0,1))))
  if clear_profile(candidate,s.profile):s.profile=candidate
 else:s.phase="lowered";s.profile=rest_profile();s.sweep=[];s.blocked=false;s.recover_profile=[]
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var active:float=float(attack().active)
 var path:Dictionary=sweep_between(clampf(float(actor().elapsed)/active,0,1),clampf((float(actor().elapsed)+delta)/active,0,1))
 s.sweep=path.points;s.blocked=path.blocked
 if not s.sweep.is_empty():s.profile=s.sweep[-1].duplicate(true)
 if s.blocked:actor().elapsed=maxf(float(actor().elapsed),active-delta)
func contains(target:Vector2) -> bool:
 if not actor().present or actor().hp<=0 or actor().hurt>0:return false
 var points:Array=[]
 if actor().phase=="windup":points=sweep_between(0,1).points
 elif actor().phase=="attack":points=state().sweep
 else:return false
 var radius:float=param("bottle_radius_m")+param("bottle_body_radius_m");var floor=battle.floor_for(str(actor().room))
 for p in points:
  var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(p[0]),battle.vector(p[1]))
  if near.distance_squared_to(target)<=radius*radius and floor.clear_segment(near,target):return true
 return false
