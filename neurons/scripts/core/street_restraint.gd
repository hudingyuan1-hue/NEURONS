extends RefCounted
## S3:P1682/P1699–1704: open loop, actual forearm, tightening, brief fixation.
const ID="assistant_asylum"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.restraint
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func state() -> Dictionary:
 if not battle.data.has("assistant_restraint"):battle.data.assistant_restraint={"owner":ID,"phase":"folded","attack_id":"","pose":{},"recover_pose":{},"blocked":false,"avoid_goal":[]}
 return battle.data.assistant_restraint
func shape(progress:float,at:Vector2,heading:Vector2) -> Dictionary:
 var t:float=clampf(progress,0,1);var close:float=clampf((t-param("restraint_extend_ratio"))/(1.0-param("restraint_extend_ratio")),0,1)
 var radius:float=lerpf(param("restraint_open_m"),param("restraint_closed_m"),close)
 var side:=Vector2(-heading.y,heading.x);var distance:float=lerpf(.38,float(attack().reach)-radius-param("restraint_band_m"),clampf(t/param("restraint_extend_ratio"),0,1))
 var center:Vector2=at+heading*distance-side*param("restraint_side_m")
 var arms:Array=[];var loop:Array=[]
 for sign_value in [-1,1]:
  var sign_f:float=float(sign_value);var shoulder:Vector2=at+side*param("restraint_shoulder_m")*sign_f
  var hand:Vector2=center+side*radius*sign_f
  arms.append([battle.xy(shoulder),battle.xy(shoulder.lerp(hand,.5)-heading*.07),battle.xy(hand)])
 for i in range(17):loop.append(battle.xy(center+heading*cos(float(i)/16*TAU)*radius+side*sin(float(i)/16*TAU)*radius))
 return {"center":battle.xy(center),"radius":radius,"arms":arms,"loop":loop}
func clear_pose(pose:Dictionary,previous:Dictionary={}) -> bool:
 var floor=battle.floor_for(str(actor().room));var r:float=param("restraint_band_m")
 for path in pose.arms+[pose.loop]:
  for i in range(1,path.size()):
   if not floor.clear_segment(battle.vector(path[i-1]),battle.vector(path[i]),r):return false
 if not previous.is_empty():
  for i in range(pose.loop.size()):
   if not floor.clear_segment(battle.vector(previous.loop[i]),battle.vector(pose.loop[i]),r):return false
 return true
func wide_at(at:Vector2,heading:Vector2) -> bool:
 var floor=battle.floor_for(str(actor().room))
 if not floor.walkable(at):return false
 for t in [0.0,.35,.7,1.0]:
  if not clear_pose(shape(t,at,heading)):return false
 for to in battle.map.doors(str(actor().room)):
  if at.distance_to(floor.portal(str(to)).at)<param("restraint_portal_clear_m"):return false
 return true
func before_actor(delta:float) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if battle.data.holder==ID and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0):release("actual_interruption")
 if a.hurt>0 and a.phase in ["windup","attack"]:a.phase="recover";a.elapsed=0.0
 sync()
 if not a.present or a.hp<=0 or a.hurt>0 or a.phase!="idle" or not str(a.follow).is_empty() or a.room!=app.room_id:return false
 if battle.hero_attack_slots(str(a.room))>=2:return false
 var at:Vector2=battle.position(ID);var to_hero:Vector2=app.hero_pos-at
 if to_hero.length()>param("restraint_start_m") or not battle.can_see(str(a.room),at,app.hero_pos):return false
 var heading:Vector2=to_hero.normalized() if to_hero.length_squared()>.001 else direction()
 if wide_at(at,heading):s.avoid_goal=[];return false
 # Actual side step into room space; no loop left across a recess or portal.
 a.cooldown=maxf(0,float(a.cooldown)-delta)
 var side:=Vector2(-heading.y,heading.x);var floor=battle.floor_for(str(a.room))
 for offset in [-heading,side,-side,heading]:
  for amount in [.6,1.0,1.4]:
   var goal:Vector2=at+offset*amount
   if wide_at(goal,heading) and floor.clear_segment(at,goal,.21):
    s.avoid_goal=battle.xy(goal);battle._move_actor(ID,goal,delta);return true
 s.avoid_goal=[];return true
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_restraint_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1702–1704"})
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="folded";s.pose={};return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.recover_pose={}
  s.phase="loop_open";var candidate:Dictionary=shape(0,battle.position(ID),direction())
  s.pose=candidate if clear_pose(candidate) else {}
 elif a.phase=="attack":s.phase="arm_extend" if a.elapsed<float(attack().active)*param("restraint_extend_ratio") else "tighten"
 elif a.phase=="grip" and battle.data.holder==ID:s.phase="fixed";s.pose=shape(1,battle.position(ID),direction())
 elif a.phase=="recover":
  if s.recover_pose.is_empty():s.recover_pose=s.pose.duplicate(true)
  s.phase="release_retract"
  if not s.recover_pose.is_empty():
   var t:float=clampf(float(a.elapsed)/float(attack().recover),0,1);var rest:Dictionary=shape(0,battle.position(ID),direction());var candidate:Dictionary=s.recover_pose.duplicate(true)
   candidate.center=battle.xy(battle.vector(s.recover_pose.center).lerp(battle.vector(rest.center),t));candidate.radius=lerpf(float(s.recover_pose.radius),float(rest.radius),t)
   for i in range(2):
    for j in range(3):candidate.arms[i][j]=battle.xy(battle.vector(s.recover_pose.arms[i][j]).lerp(battle.vector(rest.arms[i][j]),t))
   for i in range(candidate.loop.size()):candidate.loop[i]=battle.xy(battle.vector(s.recover_pose.loop[i]).lerp(battle.vector(rest.loop[i]),t))
   if clear_pose(candidate,s.pose):s.pose=candidate
 else:s.phase="folded";s.pose={};s.recover_pose={};s.blocked=false
func prepare(delta:float) -> void:
 if actor().phase!="attack":return
 var s:Dictionary=state();var start:float=clampf(float(actor().elapsed)/float(attack().active),0,1);var end:float=clampf((float(actor().elapsed)+delta)/float(attack().active),0,1)
 var steps:int=maxi(1,ceili((end-start)/.025))
 for i in range(1,steps+1):
  var candidate:Dictionary=shape(lerpf(start,end,float(i)/steps),battle.position(ID),direction())
  if not clear_pose(candidate,s.pose):s.blocked=true;actor().elapsed=maxf(float(actor().elapsed),float(attack().active)-delta);return
  s.pose=candidate
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or s.blocked:return false
 if a.phase=="attack":
  if a.elapsed<float(attack().active)*param("restraint_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 var pose:Dictionary=s.pose if a.phase=="attack" else shape(1,battle.position(ID),direction())
 if pose.is_empty() or not clear_pose(pose):return false
 var facing:Vector2=app.hero_facing
 if target.distance_to(app.hero_pos)<.001:
  if app.rules.reaction_skill=="WITHDRAW" and app.rules.reaction_left>0:return false
 else:
  for id in battle.data.actors:
   if battle.data.actors[id].present and battle.data.actors[id].room==a.room and battle.position(str(id)).distance_to(target)<.001:facing=battle.vector(battle.data.actors[id].direction);break
 if facing.length_squared()<.001:facing=Vector2.RIGHT
 facing=facing.normalized();var side:=Vector2(-facing.y,facing.x);var center:Vector2=battle.vector(pose.center)
 for sign_value in [-1,1]:
  var wrist:Vector2=target+side*float(sign_value)*param("restraint_wrist_m")
  var near:Vector2=Geometry2D.get_closest_point_to_segment(center,wrist-facing*.035,wrist+facing*.105)
  if near.distance_to(center)+param("restraint_forearm_m")<=float(pose.radius) and battle.floor_for(str(a.room)).clear_segment(center,near):return true
 return false
