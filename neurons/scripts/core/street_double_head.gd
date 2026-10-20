extends RefCounted
## S3:P1842–1847. One neutral body, two heads and two actual forward arms.
## Counter eligibility/15HP/single receipt/timing remain in the original chapter.
const ID="double_head"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks[str(battle.spec(ID).attack)]
func param(key:String) -> float:return float(battle.config.test_parameters["double_head_"+key])
func state() -> Dictionary:
 if not battle.data.has("double_head_arms"):battle.data.double_head_arms={"owner":ID,"phase":"mutual_neck_hold","attack_id":"","arms":[],"traces":[],"blocked":[],"recover_from":[],"turn":0.0}
 return battle.data.double_head_arms
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shoulder(index:int) -> Vector2:
 var d:Vector2=direction();return battle.position(ID)+Vector2(-d.y,d.x)*param("shoulder_m")*(-1 if index==0 else 1)
func tip(index:int,progress:float) -> Vector2:
 var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var offset:float=param("hand_side_m")*(-1 if index==0 else 1)
 var reach:float=sqrt(maxf(.01,pow(float(attack().reach)-param("arm_radius_m"),2)-offset*offset))
 return battle.position(ID)+d*lerpf(param("near_m"),reach,sin(clampf(progress,0,1)*PI*.5))+side*offset
func arm(index:int,progress:float) -> Array:
 var sign_value:float=-1 if index==0 else 1;var d:Vector2=direction();var side:=Vector2(-d.y,d.x)
 return [battle.xy(shoulder(index)),battle.xy(battle.position(ID)+d*param("elbow_m")+side*sign_value*param("hand_side_m")),battle.xy(tip(index,progress))]
func before_actor() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():s.traces=[]
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.arms=[];s.traces=[];s.phase="stopped";return
 if a.hurt>0:
  s.phase="hurt";s.traces=[]
  if a.phase=="idle":s.arms=[]
  return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=[false,false];s.traces=[];s.recover_from=[]
  var progress:float=clampf(float(a.elapsed)/float(attack().windup),0,1)
  s.turn=clampf((progress-param("release_ratio"))/(1.0-param("release_ratio")),0,1)
  s.phase="release_necks" if progress<param("release_ratio") else "heads_turn"
  s.arms=[arm(0,0),arm(1,0)]
 elif a.phase=="attack":
  s.phase="two_arm_thrust";s.turn=1.0
  if s.arms.size()!=2:
   # An old mid-strike save proves elapsed time, not an unrecorded sweep
   # from the beginning. Reconstruct only its currently possible pose;
   # subsequent contact starts here and cannot replay the missing past.
   s.attack_id=a.attack_id;s.arms=[];s.traces=[];s.blocked=[false,false]
   var floor=battle.floor_for(str(a.room));var ratio:float=clampf(float(a.elapsed)/float(attack().active),0,1)
   for index in range(2):
    var pose:Array=arm(index,ratio);var start:Vector2=shoulder(index);var goal:Vector2=battle.vector(pose[2]);var last:Vector2=start
    var count:int=maxi(1,ceili(start.distance_to(goal)/param("sample_m")))
    for sample in range(1,count+1):
     var next:Vector2=start.lerp(goal,float(sample)/count)
     if not floor.clear_segment(last,next,param("arm_radius_m")):s.blocked[index]=true;break
     last=next
    pose[2]=battle.xy(last);s.arms.append(pose)
 elif a.phase=="recover":
  if s.recover_from.is_empty():s.recover_from=s.arms.duplicate(true)
  s.phase="retract";s.traces=[]
  for index in range(s.recover_from.size()):
   var pose:Array=arm(index,0);var old:Array=s.recover_from[index]
   pose[2]=battle.xy(battle.vector(old[2]).lerp(tip(index,0),clampf(float(a.elapsed)/float(attack().recover),0,1)))
   if index<s.arms.size():s.arms[index]=pose
 else:
  s.phase="mutual_neck_hold";s.turn=0.0;s.arms=[];s.traces=[];s.recover_from=[];s.blocked=[false,false]
func prepare(delta:float) -> void:
 var a:Dictionary=actor()
 if a.phase!="attack":return
 var s:Dictionary=state();var floor=battle.floor_for(str(a.room));s.traces=[]
 if s.arms.size()!=2:s.arms=[arm(0,0),arm(1,0)]
 if s.blocked.size()!=2:s.blocked=[false,false]
 var progress:float=clampf((float(a.elapsed)+delta)/float(attack().active),0,1)
 for index in range(2):
  if s.blocked[index]:continue
  var pose:Array=arm(index,progress);var from:Vector2=battle.vector(s.arms[index][2]);var desired:Vector2=battle.vector(pose[2]);var last:Vector2=from
  var count:int=maxi(1,ceili(from.distance_to(desired)/param("sample_m")))
  for sample in range(1,count+1):
   var next:Vector2=from.lerp(desired,float(sample)/count)
   if not floor.clear_segment(last,next,param("arm_radius_m")) or not floor.clear_segment(shoulder(index),next,param("arm_radius_m")):
    s.blocked[index]=true;break
   last=next
  pose[2]=battle.xy(last);s.arms[index]=pose;s.traces.append([battle.xy(from),battle.xy(last)])
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state();var floor=battle.floor_for(str(a.room))
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():return false
 var traces:Array=s.traces
 if a.phase=="windup":traces=[[battle.xy(tip(0,0)),battle.xy(tip(0,1))],[battle.xy(tip(1,0)),battle.xy(tip(1,1))]]
 elif a.phase!="attack":return false
 for trace:Array in traces:
  var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(trace[0]),battle.vector(trace[1]))
  if near.distance_to(target)<=param("arm_radius_m")+.21 and floor.clear_segment(near,target):return true
 return false
