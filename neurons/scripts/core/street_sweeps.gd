extends RefCounted
## S3:P1831–1835/P1880–1884: real descending blades and fixed-direction arms.
const IDS=["doctor","skinface"]
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
func _init(owner) -> void:owner_ref=weakref(owner)
func attack() -> Dictionary:return battle.config.attacks.sweep
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state(id:String) -> Dictionary:
 if not battle.data.has("local_sweeps"):battle.data.local_sweeps={}
 if not battle.data.local_sweeps.has(id):battle.data.local_sweeps[id]={"owner":id,"phase":"lowered","attack_id":"","limbs":[],"sweep":[],"recover":[],"stopped":[],"blocked":false,"height_px":param("sweep_low_px")}
 return battle.data.local_sweeps[id]
func direction(id:String) -> Vector2:
 var d:Vector2=battle.vector(battle.data.actors[id].direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func profile(id:String,t:float) -> Array:
 var d:Vector2=direction(id);var side:=Vector2(-d.y,d.x);var at:Vector2=battle.position(id);var limbs:Array=[]
 var radius:float=param("sweep_edge_m");var reach:float=float(attack().reach)-radius
 if id=="doctor":
  # Two coordinated attached blades descend along separate, fixed local lanes.
  for sign_value in [-1,1]:
   var shoulder:Vector2=at+side*.14*float(sign_value)
   var hand:Vector2=at+d*lerpf(param("sweep_near_m"),reach-param("sweep_blade_m"),sin(clampf(t,0,1)*PI*.5))+side*param("sweep_blade_lane_m")*float(sign_value)
   limbs.append([battle.xy(shoulder),battle.xy(hand),battle.xy(hand+d*param("sweep_blade_m"))])
 else:
  var angle:float=asin((float(attack().width)-radius)/reach)
  var hand:Vector2=at+d.rotated(lerpf(-angle,angle,clampf(t,0,1)))*lerpf(param("sweep_near_m"),reach,sin(clampf(t,0,1)*PI))
  limbs.append([battle.xy(at+side*.14),battle.xy(at+d*.35+side*.18),battle.xy(hand)])
 return limbs
func clear_limb(id:String,limb:Array,previous:Array=[]) -> bool:
 var floor=battle.floor_for(str(battle.data.actors[id].room));var radius:float=param("sweep_edge_m")
 for j in range(1,3):
  if not floor.clear_segment(battle.vector(limb[j-1]),battle.vector(limb[j]),radius):return false
 if previous.size()==3:
  for j in [1,2]:
   if not floor.clear_segment(battle.vector(previous[j]),battle.vector(limb[j]),radius):return false
 return true
func clipped(id:String,limb:Array) -> Array:
 var out:Array=limb.duplicate(true);var floor=battle.floor_for(str(battle.data.actors[id].room))
 for j in range(1,3):
  var start:Vector2=battle.vector(out[j-1]);var end:Vector2=battle.vector(out[j]);var last:Vector2=start;var n:int=maxi(1,ceili(start.distance_to(end)/param("sweep_sample_m")))
  for index in range(1,n+1):
   var next:Vector2=start.lerp(end,float(index)/n)
   if not floor.clear_segment(last,next,param("sweep_edge_m")):break
   last=next
  out[j]=battle.xy(last)
 return out
func before_actor(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 if a.hurt>0:
  s.limbs=[];s.sweep=[];s.recover=[]
  if a.phase in ["windup","attack"]:a.phase="recover";a.elapsed=0
 sync(id)
func sync(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 if not a.present or a.hp<=0:s.phase="lowered";s.limbs=[];s.sweep=[];return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.recover=[];s.sweep=[];s.stopped=[]
  s.phase="blades_raise" if id=="doctor" else "arm_raise";s.limbs=[]
  for limb in profile(id,0):s.limbs.append(clipped(id,limb))
  s.height_px=lerpf(param("sweep_low_px"),param("sweep_high_px"),clampf(float(a.elapsed)/float(attack().windup),0,1)) if id=="doctor" else lerpf(param("sweep_low_px")*.5,param("sweep_low_px"),clampf(float(a.elapsed)/float(attack().windup),0,1))
 elif a.phase=="attack":s.phase="blades_descend" if id=="doctor" else "arm_sweep"
 elif a.phase=="recover":
  if s.recover.is_empty():s.recover=s.limbs.duplicate(true)
  s.phase="retract";var t:float=clampf(float(a.elapsed)/float(attack().recover),0,1);var rest:Array=profile(id,0)
  for i in range(s.recover.size()):
   var candidate:Array=[]
   for j in range(3):candidate.append(battle.xy(battle.vector(s.recover[i][j]).lerp(battle.vector(rest[i][j]),t)))
   if clear_limb(id,candidate,s.limbs[i]):s.limbs[i]=candidate
 else:s.phase="lowered";s.limbs=[];s.sweep=[];s.recover=[];s.blocked=false
func prepare(id:String,delta:float) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id);s.sweep=[]
 if a.phase!="attack":return
 var begin:float=clampf(float(a.elapsed)/float(attack().active),0,1);var end:float=clampf((float(a.elapsed)+delta)/float(attack().active),0,1)
 if s.limbs.is_empty():
  for limb in profile(id,begin):s.limbs.append(clipped(id,limb))
 if s.stopped.size()!=s.limbs.size():
  s.stopped=[]
  for i in range(s.limbs.size()):s.stopped.append(false)
 var stopped:Array=s.stopped
 var count:int=maxi(1,ceili((end-begin)*float(attack().reach)*PI/param("sweep_sample_m")))
 for n in range(count+1):
  var t:float=lerpf(begin,end,float(n)/count);var candidate:Array=profile(id,t)
  for i in range(candidate.size()):
   if stopped[i]:continue
   if not clear_limb(id,candidate[i],s.limbs[i]):stopped[i]=true;s.blocked=true;continue
   s.limbs[i]=candidate[i];s.sweep.append({"limb":candidate[i],"height_m":lerpf(param("sweep_high_m"),param("sweep_floor_m"),t) if id=="doctor" else 1.0})
 s.height_px=lerpf(param("sweep_high_px"),param("sweep_floor_px"),end) if id=="doctor" else param("sweep_low_px")
 # Blocked limbs stay where accepted for the rest of this one swing.
 if stopped.all(func(v):return v):a.elapsed=maxf(float(a.elapsed),float(attack().active)-delta)
func contains(id:String,target:Vector2) -> bool:
 var a:Dictionary=battle.data.actors[id]
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():return false
 var poses:Array=state(id).sweep
 if a.phase=="windup":
  poses=[]
  for limb in profile(id,.65):
   if clear_limb(id,limb):poses.append({"limb":limb,"height_m":1.0})
 elif a.phase!="attack":return false
 var duck:bool=battle.app.rules.reaction_skill=="GUT" and battle.app.rules.reaction_left>.2 and target.is_equal_approx(battle.app.hero_pos) and a.room==battle.app.room_id
 for pose in poses:
  if id=="doctor" and (float(pose.height_m)>param("sweep_body_high_m")*(.56 if duck else 1.0) or float(pose.height_m)<param("sweep_body_low_m")):continue
  var limb:Array=pose.limb;var first:int=2 if id=="doctor" else 1
  for j in range(first,3):
   var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(limb[j-1]),battle.vector(limb[j]))
   if target.distance_to(near)<=param("sweep_body_m")+param("sweep_edge_m") and battle.floor_for(str(a.room)).clear_segment(near,target):return true
 return false
