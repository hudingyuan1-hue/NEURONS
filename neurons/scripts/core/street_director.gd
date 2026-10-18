extends RefCounted
## S3:P1858–1863, S4:T19R5. Attached chair rails must actually close on torso.
const ID="director"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.restraint
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state() -> Dictionary:
 if not battle.data.has("director_frame"):battle.data.director_frame={"owner":ID,"phase":"folded","attack_id":"","frames":[],"recover_frames":[],"blocked":false}
 return battle.data.director_frame
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shape(progress:float) -> Array:
 var d:Vector2=direction();var side:=Vector2(-d.y,d.x);var at:Vector2=battle.position(ID);var frames:Array=[];var t:float=clampf(progress,0,1)
 var opening:Array=battle.config.test_parameters.director_open_profile;var closing:Array=battle.config.test_parameters.director_closed_profile
 for sign_value in [-1,1]:
  var frame:Array=[]
  for j in range(opening.size()):frame.append(battle.xy(at+d*lerpf(float(opening[j][0]),float(closing[j][0]),t)+side*lerpf(float(opening[j][1]),float(closing[j][1]),t)*float(sign_value)))
  frames.append(frame)
 return frames
func clipped_frames(frames:Array) -> Array:
 var floor=battle.floor_for(str(actor().room));var clipped:Array=frames.duplicate(true)
 for i in range(2):
  for j in range(1,4):
   var start:Vector2=battle.vector(clipped[i][j-1]);var end:Vector2=battle.vector(frames[i][j]);var last:Vector2=start;var count:int=maxi(1,ceili(start.distance_to(end)/param("director_sample_m")))
   for n in range(1,count+1):
    var next:Vector2=start.lerp(end,float(n)/count)
    if not floor.clear_segment(last,next,param("director_bar_m")):break
    last=next
   clipped[i][j]=battle.xy(last)
 return clipped
func clear_frames(frames:Array,previous:Array=[]) -> bool:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("director_bar_m")
 for i in range(2):
  for j in range(1,4):
   if not floor.clear_segment(battle.vector(frames[i][j-1]),battle.vector(frames[i][j]),radius):return false
  if not previous.is_empty():
   for j in range(1,4):
    if not floor.clear_segment(battle.vector(previous[i][j]),battle.vector(frames[i][j]),radius):return false
 return true
func encloses(frames:Array,target:Vector2) -> bool:
 if frames.size()!=2:return false
 var polygon:=PackedVector2Array()
 for p in frames[0]:polygon.append(battle.vector(p))
 for j in [3,2,1,0]:polygon.append(battle.vector(frames[1][j]))
 if not Geometry2D.is_point_in_polygon(target,polygon):return false
 var radius:float=param("director_torso_m")+param("director_bar_m");var tolerance:float=param("director_contact_slack_m")
 for j in range(polygon.size()):
  if target.distance_to(Geometry2D.get_closest_point_to_segment(target,polygon[j],polygon[(j+1)%polygon.size()]))<radius-tolerance:return false
 # Both real side rails, rather than merely the filled polygon, must be close.
 for frame in frames:
  var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(frame[1]),battle.vector(frame[2]))
  if target.distance_to(near)>radius+tolerance:return false
 return battle.floor_for(str(actor().room)).clear_segment(battle.position(ID),target,param("director_torso_m"))
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_director_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1681/P1860–1863"})
func before_actor() -> void:
 var a:Dictionary=actor()
 if battle.data.holder==ID and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0 or not battle.data.ending.is_empty()):release("actual_interruption")
 if a.phase=="grip" and battle.data.holder!=ID:a.phase="recover";a.elapsed=0.0
 if a.hurt>0 and a.phase in ["windup","attack"]:a.phase="recover";a.elapsed=0.0
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="attached_to_body";s.frames=clipped_frames(shape(0)) if a.present else [];return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.recover_frames=[]
  s.phase="rails_raise" if a.elapsed<float(attack().windup)*.5 else "rails_open"
  s.frames=clipped_frames(shape(0))
 elif a.phase=="attack":s.phase="rails_close"
 elif a.phase=="grip" and battle.data.holder==ID:
  var candidate:Array=shape(1)
  if not clear_frames(candidate,s.frames) or not encloses(candidate,app.hero_pos):s.frames=clipped_frames(s.frames if not s.frames.is_empty() else candidate);release("actual_enclosure_lost");sync();return
  s.phase="torso_fixed";s.frames=candidate
 elif a.phase=="recover":
  if s.recover_frames.is_empty():s.recover_frames=s.frames.duplicate(true)
  s.phase="rails_release"
  if not s.recover_frames.is_empty():
   var t:float=clampf(float(a.elapsed)/float(attack().recover),0,1);var candidate:Array=s.recover_frames.duplicate(true);var rest:Array=shape(0)
   for i in range(2):
    for j in range(4):candidate[i][j]=battle.xy(battle.vector(s.recover_frames[i][j]).lerp(battle.vector(rest[i][j]),t))
   if clear_frames(candidate,s.frames):s.frames=candidate
 else:s.phase="folded";s.frames=[];s.recover_frames=[];s.blocked=false
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var begin:float=clampf(float(actor().elapsed)/float(attack().active),0,1);var end:float=clampf((float(actor().elapsed)+delta)/float(attack().active),0,1)
 var count:int=maxi(1,ceili((end-begin)/.025))
 for i in range(1,count+1):
  var candidate:Array=shape(lerpf(begin,end,float(i)/count))
  if not clear_frames(candidate,s.frames):s.blocked=true;actor().elapsed=maxf(float(actor().elapsed),float(attack().active)-delta);return
  s.frames=candidate
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or s.blocked or not battle.data.ending.is_empty():return false
 if a.phase=="attack":
  if a.elapsed<float(attack().active)*param("director_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 var frames:Array=s.frames if a.phase=="attack" else shape(1)
 return not frames.is_empty() and clear_frames(frames) and encloses(frames,target)
