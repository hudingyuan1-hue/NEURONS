extends RefCounted
## S3:P1350–1355/P1602–1606: one attached waist-height strap, no restraint.
const ID="warder"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.belt
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func state() -> Dictionary:
 if not battle.data.has("warder_belt"):battle.data.warder_belt={"owner":ID,"phase":"wrapped","attack_id":"","profile":[],"sweep":[],"blocked":false,"recover_profile":[]}
 return battle.data.warder_belt
func profile(progress:float) -> Array:
 var t:float=clampf(progress,0,1);var d:Vector2=direction();var at:Vector2=battle.position(ID)
 var radius:float=param("belt_radius_m");var reach:float=float(attack().reach)-radius
 var angle:float=lerpf(-1,1,t)*asin(clampf((float(attack().width)-radius)/reach,0,.95))
 var length:float=lerpf(param("belt_near_m"),reach,sin(t*PI))
 # A visible bent strip, not a filled fan or a second attacking arm.
 return [battle.xy(at+d*param("belt_hand_m")),battle.xy(at+d.rotated(angle*.65)*length*.6),battle.xy(at+d.rotated(angle)*length)]
func rest_profile() -> Array:
 var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var at:Vector2=battle.position(ID)
 return [battle.xy(at+d*param("belt_hand_m")),battle.xy(at+d*.32+side*.12),battle.xy(at+d*.25-side*.12)]
func clipped(p:Array,previous:Array=[]) -> Dictionary:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("belt_radius_m")
 if not previous.is_empty() and previous.size()==p.size():
  for i in range(p.size()):
   if not floor.clear_segment(battle.vector(previous[i]),battle.vector(p[i]),radius):return {"points":previous.duplicate(true),"blocked":true}
 var out:Array=[p[0]]
 if not floor.clear_segment(battle.position(ID),battle.vector(p[0]),radius):return {"points":[],"blocked":true}
 for i in range(1,p.size()):
  var start:Vector2=battle.vector(p[i-1]);var end:Vector2=battle.vector(p[i]);var last:Vector2=start
  var count:int=maxi(1,ceili(start.distance_to(end)/param("belt_sample_m")))
  for n in range(1,count+1):
   var next:Vector2=start.lerp(end,float(n)/count)
   if not floor.clear_segment(last,next,radius):
    if last.distance_to(start)>.0001:out.append(battle.xy(last))
    return {"points":out,"blocked":true}
   last=next
  out.append(p[i])
 return {"points":out,"blocked":false}
func sweep_between(start:float,end:float,previous:Array=[]) -> Dictionary:
 var points:Array=[];var last:Array=previous
 var count:int=maxi(1,ceili((end-start)*float(attack().reach)*PI/param("belt_sample_m")))
 for i in range(count+1):
  var pose:Dictionary=clipped(profile(lerpf(start,end,float(i)/count)),last)
  if pose.points.size()>=2:points.append(pose.points)
  if pose.blocked:return {"points":points,"blocked":true,"stopped":pose.points}
  last=pose.points
 return {"points":points,"blocked":false,"stopped":last}
func before_actor() -> void:
 if actor().hurt>0 and actor().phase in ["windup","attack"]:actor().phase="recover";actor().elapsed=0.0
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="attached_to_body";s.profile=rest_profile();s.sweep=[];return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.sweep=[];s.recover_profile=[]
  var t:float=clampf(float(a.elapsed)/float(attack().windup),0,1)
  s.phase="side_draw" if t<.5 else "strap_uncoil"
  var candidate:Array=[];var from:Array=rest_profile();var to:Array=profile(0)
  for i in range(from.size()):candidate.append(battle.xy(battle.vector(from[i]).lerp(battle.vector(to[i]),t)))
  s.profile=clipped(candidate).points
 elif a.phase=="attack":s.phase="waist_sweep"
 elif a.phase=="recover":
  if s.recover_profile.is_empty():s.recover_profile=(rest_profile() if s.profile.size()<2 else s.profile).duplicate(true)
  s.phase="strap_retract";var candidate:Array=[];var from:Array=s.recover_profile;var to:Array=rest_profile()
  for i in range(from.size()):candidate.append(battle.xy(battle.vector(from[i]).lerp(battle.vector(to[mini(i,to.size()-1)]),clampf(float(a.elapsed)/float(attack().recover),0,1))))
  s.profile=clipped(candidate,s.profile).points;s.sweep=[]
 else:s.phase="wrapped";s.profile=rest_profile();s.sweep=[];s.blocked=false;s.recover_profile=[]
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var active:float=float(attack().active)
 if s.blocked:s.sweep=[];actor().elapsed=maxf(float(actor().elapsed),active-delta);return
 var path:Dictionary=sweep_between(clampf(float(actor().elapsed)/active,0,1),clampf((float(actor().elapsed)+delta)/active,0,1),s.profile)
 s.sweep=path.points;s.blocked=path.blocked
 if not path.stopped.is_empty():s.profile=path.stopped.duplicate(true)
 if s.blocked:actor().elapsed=maxf(float(actor().elapsed),active-delta)
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor()
 if not a.present or a.hp<=0 or a.hurt>0:return false
 var points:Array=[]
 if a.phase=="windup":points=sweep_between(0,1).points
 elif a.phase=="attack":points=state().sweep
 else:return false
 var radius:float=param("belt_radius_m")+param("belt_body_radius_m");var floor=battle.floor_for(str(a.room))
 for pose in points:
  for i in range(1,pose.size()):
   var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(pose[i-1]),battle.vector(pose[i]))
   if near.distance_squared_to(target)<=radius*radius and floor.clear_segment(near,target):return true
 return false
