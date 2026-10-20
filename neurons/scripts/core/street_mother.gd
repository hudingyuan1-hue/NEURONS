extends RefCounted
## S3:P1826–1830. Actual multi-arm impact and torso enclosure are separate.
const ID="mother"
var owner_ref:WeakRef
var prediction_key:Array=[]
var prediction_arms:Array=[]
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.grab
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state() -> Dictionary:
 if not battle.data.has("mother_arms"):battle.data.mother_arms={"owner":ID,"phase":"folded","attack_id":"","arms":[],"sweep":[],"recover":[],"blocked":false}
 return battle.data.mother_arms
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shape(progress:float) -> Array:
 var opening:Array=battle.config.test_parameters.mother_open_profile;var closing:Array=battle.config.test_parameters.mother_closed_profile
 var arms:Array=[];var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var at:Vector2=battle.position(ID);var t:float=clampf(progress,0,1)
 # Two pairs at separate display heights, sharing physical torso-side paths.
 for pair in range(2):
  for sign_value in [-1,1]:
   var arm:Array=[]
   for j in range(3):arm.append(battle.xy(at+d*lerpf(float(opening[j][0]),float(closing[j][0]),t)+side*lerpf(float(opening[j][1]),float(closing[j][1]),t)*float(sign_value)))
   arms.append(arm)
 return arms
func clear_arms(arms:Array,previous:Array=[]) -> bool:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("mother_arm_m")
 for i in range(arms.size()):
  for j in range(1,3):
   if not floor.clear_segment(battle.vector(arms[i][j-1]),battle.vector(arms[i][j]),radius):return false
  if previous.size()==arms.size():
   for j in [1,2]:
    if not floor.clear_segment(battle.vector(previous[i][j]),battle.vector(arms[i][j]),radius):return false
 return true
func clipped(arms:Array) -> Array:
 var out:Array=arms.duplicate(true);var floor=battle.floor_for(str(actor().room))
 for arm in out:
  for j in range(1,3):
   var start:Vector2=battle.vector(arm[j-1]);var end:Vector2=battle.vector(arm[j]);var last:Vector2=start;var steps:int=maxi(1,ceili(start.distance_to(end)/param("mother_sample_m")))
   # The exact continuous query proves a whole arm segment clear. Keep the
   # original samples whenever obstructed so accepted stop poses stay equal.
   if floor.clear_segment(start,end,param("mother_arm_m")):continue
   for n in range(1,steps+1):
    var next:Vector2=start.lerp(end,float(n)/steps)
    if not floor.clear_segment(last,next,param("mother_arm_m")):break
    last=next
   arm[j]=battle.xy(last)
 return out
func encloses(arms:Array,target:Vector2) -> bool:
 if arms.size()!=4 or not clear_arms(arms):return false
 var poly:=PackedVector2Array()
 for p in arms[0]:poly.append(battle.vector(p))
 for j in [2,1,0]:poly.append(battle.vector(arms[1][j]))
 if not Geometry2D.is_point_in_polygon(target,poly):return false
 for j in range(poly.size()):
  if target.distance_to(Geometry2D.get_closest_point_to_segment(target,poly[j],poly[(j+1)%poly.size()]))<param("mother_torso_m"):return false
 for i in range(2):
  var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(arms[i][1]),battle.vector(arms[i][2]))
  if target.distance_to(near)>param("mother_body_m")+param("mother_arm_m"):return false
 return battle.floor_for(str(actor().room)).clear_segment(battle.position(ID),target,param("mother_torso_m"))
func touching(arms:Array,target:Vector2) -> bool:
 var radius:float=param("mother_body_m")+param("mother_arm_m");var floor=battle.floor_for(str(actor().room))
 for arm in arms:
  for j in range(1,3):
   var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(arm[j-1]),battle.vector(arm[j]))
   if target.distance_to(near)<=radius and floor.clear_segment(near,target):return true
 return false
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_mother_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1681/P1828–1830"})
func before_actor() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if battle.data.holder==ID and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0 or not battle.data.ending.is_empty()):release("actual_interruption")
 if a.hurt>0:s.arms=[];s.sweep=[];s.recover=[]
 if (a.hurt>0 and a.phase in ["windup","attack"]) or (a.phase=="grip" and battle.data.holder!=ID):a.phase="recover";a.elapsed=0.0
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="folded";s.arms=[];s.sweep=[];return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.recover=[];s.sweep=[]
  s.phase="arms_gather" if a.elapsed<float(attack().windup)*.5 else "arms_open"
  var opening:Array=shape(0);var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var at:Vector2=battle.position(ID);var t:float=clampf(float(a.elapsed)/float(attack().windup),0,1)
  for i in range(4):
   var sign_f:float=-1.0 if i%2==0 else 1.0
   opening[i][1]=battle.xy((at+d*.12+side*.18*sign_f).lerp(battle.vector(opening[i][1]),t))
   opening[i][2]=battle.xy((at+d*.16+side*.16*sign_f).lerp(battle.vector(opening[i][2]),t))
  s.arms=clipped(opening)
 elif a.phase=="attack":s.phase="arms_close"
 elif a.phase=="grip" and battle.data.holder==ID:
  var candidate:Array=shape(1)
  if not clear_arms(candidate,s.arms) or not encloses(candidate,app.hero_pos):release("actual_enclosure_lost");s.arms=clipped(s.arms);sync();return
  s.phase="torso_fixed";s.arms=candidate
 elif a.phase=="recover":
  if s.recover.is_empty():s.recover=s.arms.duplicate(true)
  s.phase="arms_release"
  if not s.recover.is_empty():
   var candidate:Array=s.recover.duplicate(true);var rest:Array=shape(0);var t:float=clampf(float(a.elapsed)/float(attack().recover),0,1)
   for i in range(4):
    for j in range(3):candidate[i][j]=battle.xy(battle.vector(s.recover[i][j]).lerp(battle.vector(rest[i][j]),t))
   if clear_arms(candidate,s.arms):s.arms=candidate
 else:s.phase="folded";s.arms=[];s.sweep=[];s.recover=[];s.blocked=false
func prepare(delta:float) -> void:
 var s:Dictionary=state();s.sweep=[]
 if actor().phase!="attack":return
 var begin:float=clampf(float(actor().elapsed)/float(attack().active),0,1);var end:float=clampf((float(actor().elapsed)+delta)/float(attack().active),0,1)
 var steps:int=maxi(1,ceili((end-begin)/param("mother_sample_m")))
 for n in range(steps+1):
  var candidate:Array=shape(lerpf(begin,end,float(n)/steps))
  if not clear_arms(candidate,s.arms):s.blocked=true;actor().elapsed=maxf(float(actor().elapsed),float(attack().active)-delta);break
  s.arms=candidate;s.sweep.append(candidate)
func _prediction_key() -> Array:
 var floor=battle.floor_for(str(actor().room));var geometry:Array=[];var parameters:Dictionary={}
 for key in battle.config.test_parameters:
  if str(key).begins_with("mother_"):parameters[key]=battle.config.test_parameters[key]
 for property:Dictionary in floor.get_property_list():
  if str(property.name) not in ["furniture","decor","walls","static_walls","movable_blockers","oriented_beds","bounds_size","geometry_version","spatial_version","metric_spec","floor_polygon_m","body_radius"]:continue
  var value=floor.get(property.name)
  geometry.append([property.name,value.duplicate(true) if value is Array or value is Dictionary else value])
 return [str(actor().room),battle.position(ID),direction(),floor.get_instance_id(),attack().duplicate(true),parameters,geometry]

func _windup_arms() -> Array:
 var current:Array=_prediction_key()
 if current!=prediction_key:
  prediction_key=current;prediction_arms=clipped(shape(1))
 return prediction_arms

func contains(target:Vector2) -> bool:
 var a:Dictionary=actor()
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():return false
 if a.phase=="windup":return touching(_windup_arms(),target)
 if a.phase!="attack":return false
 for pose in state().sweep:
  if touching(pose,target):return true
 return false
func resolve_contact() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if a.room==app.room_id and str(battle.data.holder).is_empty() and battle.data.clock>=battle.data.grip_safe_until:
  if not a.hits.has("hero") and contains(app.hero_pos):
   a.hits.hero=true;battle._damage_hero(str(a.attack_id),int(attack().hp),int(attack().sp),ID)
  if app.rules.hp>0 and not s.blocked and float(a.elapsed)>=float(attack().active)*param("mother_close_ratio") and encloses(s.arms,app.hero_pos):
   battle.data.holder=ID;battle.data.grip_until=battle.data.clock+1.2;app.rules.gripped=true;a.phase="grip"
 for other in battle.data.actors:
  if other==ID:continue
  var body:Dictionary=battle.data.actors[other]
  if (battle.spec(other).relation in ["friend","neutral"] or other=="father") and body.present and body.hp>0 and body.room==a.room and not a.hits.has(other) and contains(battle.position(other)):
   a.hits[other]=true;battle.damage_actor(ID,str(other),int(attack().hp),str(a.attack_id)+":"+other)
