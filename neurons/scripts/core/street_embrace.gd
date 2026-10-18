extends RefCounted
## S3:P1680–1682/P1705–1710: both padded arms must enclose the actual torso.
const ID="isolation"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.isolate
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state() -> Dictionary:
 if not battle.data.has("isolation_embrace"):
  battle.data.isolation_embrace={"phase":"folded","attack_id":"","open":0.0,"blocked":false,"arms":[],"recover_arms":[]}
 return battle.data.isolation_embrace
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shape(progress:float) -> Array:
 var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var origin:Vector2=battle.position(ID);var arms:Array=[]
 for sign_value in [-1,1]:
  var sign_f:float=float(sign_value)
  var shoulder:Vector2=origin+side*param("embrace_shoulder_m")*sign_f
  var elbow:Vector2=origin+d*param("embrace_elbow_forward_m")+side*lerpf(param("embrace_elbow_open_m"),param("embrace_elbow_closed_m"),progress)*sign_f
  var hand:Vector2=origin+d*lerpf(param("embrace_hand_open_forward_m"),float(attack().reach)-param("embrace_arm_radius_m"),progress)+side*lerpf(param("embrace_hand_open_m"),param("embrace_hand_closed_m"),progress)*sign_f
  arms.append([battle.xy(shoulder),battle.xy(elbow),battle.xy(hand)])
 return arms
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_embrace_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1681/P1707–1710"})
func before_actor() -> void:
 if battle.data.holder==ID and (not actor().present or actor().hp<=0 or actor().hurt>0 or actor().room!=app.room_id or app.rules.hp<=0):release("actual_interruption")
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="folded";s.arms=[];return
 if a.phase=="windup":
  if str(s.attack_id)!=str(a.attack_id):s.attack_id=a.attack_id;s.blocked=false;s.recover_arms=[]
  s.phase="arms_raise" if a.elapsed<float(attack().windup)*.5 else "arms_open";s.open=1.0;s.arms=clipped_arms(shape(0))
 elif a.phase=="attack":
  s.phase="closing";s.open=1.0-clampf(float(a.elapsed)/float(attack().active),0,1)
  # prepare() owns accepted geometry; the renderer cannot move through blockers.
 elif a.phase=="grip" and battle.data.holder==ID:s.phase="held";s.open=0.0;s.arms=shape(1)
 elif a.phase=="recover":
  if s.recover_arms.is_empty():s.recover_arms=(shape(1) if s.arms.is_empty() else s.arms).duplicate(true)
  s.phase="opening";var t:float=clampf(float(a.elapsed)/float(attack().recover),0,1);s.open=t
  var rest:Array=shape(0);var candidate:Array=s.recover_arms.duplicate(true)
  for i in range(2):
   for j in range(3):candidate[i][j]=battle.xy(battle.vector(s.recover_arms[i][j]).lerp(battle.vector(rest[i][j]),t))
  if clear_arms(candidate,s.arms):s.arms=candidate
 else:s.phase="folded";s.open=0.0;s.arms=[];s.recover_arms=[];s.blocked=false
func clipped_arms(arms:Array) -> Array:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("embrace_arm_radius_m");var clipped:Array=arms.duplicate(true)
 for i in range(2):
  for j in range(1,3):
   var start:Vector2=battle.vector(clipped[i][j-1]);var end:Vector2=battle.vector(arms[i][j]);var last:Vector2=start
   var steps:int=maxi(1,ceili(start.distance_to(end)/.025))
   for index in range(1,steps+1):
    var next:Vector2=start.lerp(end,float(index)/steps)
    if not floor.clear_segment(last,next,radius):break
    last=next
   clipped[i][j]=battle.xy(last)
 return clipped
func clear_arms(arms:Array,previous:Array=[]) -> bool:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("embrace_arm_radius_m")
 for i in range(2):
  for j in range(2):
   if not floor.clear_segment(battle.vector(arms[i][j]),battle.vector(arms[i][j+1]),radius):return false
  if not previous.is_empty():
   for j in [1,2]:
    if not floor.clear_segment(battle.vector(previous[i][j]),battle.vector(arms[i][j]),radius):return false
 return true
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var end:float=clampf((float(actor().elapsed)+delta)/float(attack().active),0,1)
 var begin:float=clampf(float(actor().elapsed)/float(attack().active),0,1)
 if s.arms.is_empty():s.arms=shape(begin)
 var steps:int=maxi(1,ceili((end-begin)/.04))
 for index in range(1,steps+1):
  var candidate:Array=shape(lerpf(begin,end,float(index)/steps))
  if not clear_arms(candidate,s.arms):
   s.blocked=true;actor().elapsed=maxf(float(actor().elapsed),float(attack().active)-delta);return
  s.arms=candidate
func finish() -> void:sync()
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or s.blocked:return false
 if a.phase=="attack":
  if float(a.elapsed)<float(attack().active)*param("embrace_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 # Evaluate the same closed padded arms, not a forward rectangular hit box.
 var arms:Array=s.arms if a.phase=="attack" else shape(1)
 if arms.is_empty() or not clear_arms(arms):return false
 var polygon:=PackedVector2Array()
 for point in arms[0]:polygon.append(battle.vector(point))
 for j in [2,1,0]:polygon.append(battle.vector(arms[1][j]))
 if not Geometry2D.is_point_in_polygon(target,polygon):return false
 var radius:float=param("embrace_torso_radius_m")
 for i in range(polygon.size()):
  if target.distance_to(Geometry2D.get_closest_point_to_segment(target,polygon[i],polygon[(i+1)%polygon.size()]))<radius:return false
 return battle.floor_for(str(a.room)).clear_segment(battle.position(ID),target,radius)
