extends RefCounted
## S3:P1712–1716. One arm closes on an actual forearm, then releases/retracts.
const ID="dislocated"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.grab
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state() -> Dictionary:
 if not battle.data.has("dislocated_clamp"):
  battle.data.dislocated_clamp={"side":-1,"phase":"folded","attack_id":"","recovered":"","tip":actor().pos.duplicate(),"open":1.0,"blocked":false,"recover_origin":[]}
 return battle.data.dislocated_clamp
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shoulder() -> Vector2:
 var d:Vector2=direction();return battle.position(ID)+Vector2(-d.y,d.x)*param("clamp_shoulder_m")*float(state().side)
func endpoint(progress:float=1.0) -> Vector2:
 var offset:float=param("clamp_shoulder_m");var r:float=param("clamp_radius_m");var length:float=sqrt(maxf(.01,pow(float(attack().reach)-r,2)-offset*offset))
 return shoulder()+direction()*lerpf(.25,length,clampf(progress,0,1))
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_clamp_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1681/P1714"})
func before_actor() -> void:
 if battle.data.holder==ID and (not actor().present or actor().hp<=0 or actor().hurt>0 or actor().room!=app.room_id or app.rules.hp<=0):release("actual_interruption")
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state();var phase:String=str(a.phase)
 if not a.present or a.hp<=0:s.phase="folded";s.open=1.0;return
 if str(s.attack_id)!=str(a.attack_id) and phase=="windup":s.attack_id=a.attack_id;s.blocked=false
 if phase=="windup":
  s.phase="shoulder_raise" if a.elapsed<float(attack().windup)*.5 else "jaw_open";s.open=1.0;s.tip=battle.xy(endpoint(0));s.recover_origin=[]
 elif phase=="attack":
  var ratio:float=clampf(float(a.elapsed)/float(attack().active),0,1);var close:float=param("clamp_close_ratio")
  s.phase="extend" if ratio<close else "close";s.open=1.0 if ratio<close else 1.0-clampf((ratio-close)/(1.0-close),0,1)
  if not s.blocked:s.tip=battle.xy(endpoint(clampf(ratio/close,0,1)))
 elif phase=="grip" and battle.data.holder==ID:s.phase="held";s.open=0.0;s.tip=battle.xy(endpoint())
 elif phase=="recover":
  if s.recover_origin.is_empty():s.recover_origin=s.tip.duplicate()
  s.phase="open_retract";s.open=1.0;s.tip=battle.xy(battle.vector(s.recover_origin).lerp(endpoint(0),clampf(float(a.elapsed)/float(attack().recover),0,1)))
 else:s.phase="folded";s.open=1.0;s.tip=battle.xy(endpoint(0));s.blocked=false;s.recover_origin=[]
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var progress:float=clampf((float(actor().elapsed)+delta)/(float(attack().active)*param("clamp_close_ratio")),0,1)
 var floor=battle.floor_for(str(actor().room));var target:Vector2=endpoint(progress);var start:Vector2=shoulder()
 if not floor.clear_segment(start,target,param("clamp_radius_m")):
  var count:int=maxi(1,ceili(start.distance_to(target)/.025));var last:Vector2=start
  for i in range(1,count+1):
   var next:Vector2=start.lerp(target,float(i)/count)
   if not floor.clear_segment(last,next,param("clamp_radius_m")):break
   last=next
  s.tip=battle.xy(last);s.blocked=true;actor().elapsed=maxf(float(actor().elapsed),float(attack().active)-delta)
 else:s.tip=battle.xy(target)
func finish(before:String) -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if before=="recover" and a.phase=="idle" and str(s.recovered)!=str(a.attack_id):s.side=-int(s.side);s.recovered=a.attack_id
 sync()
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or s.blocked:return false
 if a.phase=="attack":
  if float(a.elapsed)<float(attack().active)*param("clamp_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 var tip:Vector2=endpoint();var floor=battle.floor_for(str(a.room))
 if not floor.clear_segment(shoulder(),tip,param("clamp_radius_m")):return false
 var facing:Vector2=app.hero_facing
 if target.distance_to(app.hero_pos)>.001:
  for id in battle.data.actors:
   if battle.data.actors[id].present and battle.data.actors[id].room==a.room and battle.position(str(id)).distance_to(target)<.001:facing=battle.vector(battle.data.actors[id].direction);break
 if facing.length_squared()<.001:facing=Vector2.RIGHT
 facing=facing.normalized();var side:=Vector2(-facing.y,facing.x)
 for sign_value in [-1,1]:
  var wrist:Vector2=target+side*float(sign_value)*param("clamp_wrist_offset_m")
  var length:float=param("clamp_forearm_length_m")
  var closest:Vector2=Geometry2D.get_closest_point_to_segment(tip,wrist-facing*length*.25,wrist+facing*length*.75)
  if closest.distance_to(tip)<=param("clamp_capture_radius_m")+param("clamp_forearm_radius_m") and floor.clear_segment(tip,closest):return true
 return false
