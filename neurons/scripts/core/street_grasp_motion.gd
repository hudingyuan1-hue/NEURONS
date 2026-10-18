extends RefCounted
## S3:P1848–1852/P1892–1898; S4:T19R4/R6. Wrist contact before paired motion.
const IDS=["psychiatrist","guard_hospital"]
const LIMIT_M=1.0 # Original maximum, not a difficulty/testing adjustment.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor(id:String) -> Dictionary:return battle.data.actors[id]
func attack(id:String) -> Dictionary:return battle.config.attacks[str(battle.spec(id).attack)]
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func state(id:String) -> Dictionary:
 if not battle.data.has("grasp_motion"):battle.data.grasp_motion={}
 if not battle.data.grasp_motion.has(id):battle.data.grasp_motion[id]={"owner":id,"phase":"lowered","attack_id":"","hand":actor(id).pos.duplicate(),"blocked":false,"open":1.0,"recover_hand":[],"motion":{}}
 return battle.data.grasp_motion[id]
func direction(id:String) -> Vector2:
 var d:Vector2=battle.vector(actor(id).direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func shoulder(id:String) -> Vector2:
 var d:Vector2=direction(id);return battle.position(id)-Vector2(-d.y,d.x)*param("grasp_shoulder_m")
func hand_goal(id:String,progress:float=1.0) -> Vector2:
 var d:Vector2=direction(id);var at:Vector2=battle.position(id);var side:=Vector2(-d.y,d.x)
 return at+d*lerpf(.28,float(attack(id).reach)-param("grasp_tip_inset_m"),clampf(progress,0,1))-side*param("grasp_wrist_m")
func forearm_point(target:Vector2,center:Vector2,room:String) -> Vector2:
 var facing:Vector2=app.hero_facing
 if target.distance_to(app.hero_pos)>.001:
  for other in battle.data.actors:
   if actor(str(other)).present and actor(str(other)).room==room and battle.position(str(other)).distance_to(target)<.001:facing=battle.vector(actor(str(other)).direction);break
 if facing.length_squared()<.001:facing=Vector2.RIGHT
 facing=facing.normalized();var side:=Vector2(-facing.y,facing.x);var best:Vector2=target;var dist:float=INF
 for sign_value in [-1,1]:
  var wrist:Vector2=target+side*float(sign_value)*param("grasp_wrist_m")
  var near:Vector2=Geometry2D.get_closest_point_to_segment(center,wrist-facing*.035,wrist+facing*.105)
  if near.distance_to(center)<dist:best=near;dist=near.distance_to(center)
 return best
func release(id:String,reason:String) -> void:
 if battle.data.holder!=id:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor(id).hp>0:actor(id).phase="recover";actor(id).elapsed=0.0
 app.rules._record("street_grasp_released",str(actor(id).attack_id)+":release",{"actor":id,"reason":reason,"source":"S3:P1681/P1851/P1896"})
func before_actor(id:String) -> void:
 var a:Dictionary=actor(id)
 if battle.data.holder==id and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0 or not battle.data.ending.is_empty()):release(id,"actual_interruption")
 if a.phase=="grip" and battle.data.holder!=id:a.phase="recover";a.elapsed=0.0
 if a.hurt>0 and a.phase in ["windup","attack"]:a.phase="recover";a.elapsed=0.0
 sync(id)
func sync(id:String) -> void:
 var a:Dictionary=actor(id);var s:Dictionary=state(id)
 if not a.present or a.hp<=0:s.phase="attached_to_body";s.hand=battle.xy(hand_goal(id,0));s.open=1.0;return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.blocked=false;s.recover_hand=[];s.motion={}
  s.phase="clasp_raise" if id=="psychiatrist" else "hand_raise";s.open=1.0;s.hand=battle.xy(hand_goal(id,0))
 elif a.phase=="attack":
  s.phase="reach" if a.elapsed<float(attack(id).active)*param("grasp_extend_ratio") else "close";s.open=1.0-clampf((float(a.elapsed)/float(attack(id).active)-param("grasp_extend_ratio"))/(1.0-param("grasp_extend_ratio")),0,1)
 elif a.phase=="grip" and battle.data.holder==id:
  if s.motion.is_empty():
   # A legacy hold proves the injury/deadline, not a missing one-metre trajectory.
   if battle.position(id).distance_to(app.hero_pos)>float(attack(id).reach)+.21:release(id,"legacy_out_of_reach");sync(id);return
   s.motion={"legacy_static":true,"distance":0.0,"direction":[0,0],"offset":battle.xy(forearm_point(app.hero_pos,hand_goal(id),str(a.room))-app.hero_pos),"turn_left":0.0,"blocked":false}
  s.phase="legacy_fixed" if s.motion.legacy_static else "turn_inward" if float(s.motion.turn_left)>0 else "pull" if id=="psychiatrist" else "push_inward"
  s.open=0.0;s.hand=battle.xy(app.hero_pos+battle.vector(s.motion.offset))
 elif a.phase=="recover":
  if s.recover_hand.is_empty():s.recover_hand=s.hand.duplicate()
  s.phase="open_retract";s.open=1.0
  var next:Vector2=battle.vector(s.recover_hand).lerp(hand_goal(id,0),clampf(float(a.elapsed)/float(attack(id).recover),0,1))
  if battle.floor_for(str(a.room)).clear_segment(battle.vector(s.hand),next,param("grasp_hand_radius_m")):s.hand=battle.xy(next)
 else:s.phase="lowered";s.hand=battle.xy(hand_goal(id,0));s.open=1.0;s.recover_hand=[]
func prepare(id:String,delta:float) -> void:
 if actor(id).phase!="attack":return
 var a:Dictionary=actor(id);var s:Dictionary=state(id);var p:float=clampf((float(a.elapsed)+delta)/(float(attack(id).active)*param("grasp_extend_ratio")),0,1)
 var floor=battle.floor_for(str(a.room));var target:Vector2=hand_goal(id,p);var radius:float=param("grasp_hand_radius_m")
 if not floor.clear_segment(shoulder(id),target,radius) or not floor.clear_segment(battle.vector(s.hand),target,radius):
  s.blocked=true;a.elapsed=maxf(float(a.elapsed),float(attack(id).active)-delta);return
 s.hand=battle.xy(target)
func contains(id:String,target:Vector2) -> bool:
 var a:Dictionary=actor(id);var s:Dictionary=state(id)
 if not a.present or a.hp<=0 or a.hurt>0 or s.blocked or not battle.data.ending.is_empty():return false
 if a.phase=="attack":
  if a.elapsed<float(attack(id).active)*param("grasp_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 var hand:Vector2=hand_goal(id) if a.phase=="windup" else battle.vector(s.hand);var near:Vector2=forearm_point(target,hand,str(a.room));var floor=battle.floor_for(str(a.room))
 return hand.distance_to(near)<=param("grasp_capture_m") and floor.clear_segment(shoulder(id),hand,param("grasp_hand_radius_m")) and floor.clear_segment(hand,near)
func begin_hold(id:String) -> void:
 var a:Dictionary=actor(id);var s:Dictionary=state(id);var heading:Vector2=-direction(id)
 if id=="guard_hospital":
  var toward:String="ending_gate" if a.room=="street_end" else battle.map.next_room(str(a.room),"street_end")
  var portal:Dictionary=battle.floor_for(str(a.room)).portal(toward)
  if not portal.is_empty():heading=Vector2(portal.inward)
 s.motion={"legacy_static":false,"distance":0.0,"direction":battle.xy(heading),"offset":battle.xy(forearm_point(app.hero_pos,battle.vector(s.hand),str(a.room))-app.hero_pos),"turn_left":param("grasp_guard_turn_s") if id=="guard_hospital" else 0.0,"blocked":false}
 sync(id)
func pair_clear(id:String,hero_from:Vector2,hero_to:Vector2,body_from:Vector2,body_to:Vector2) -> bool:
 var room:String=str(actor(id).room);var floor=battle.floor_for(room);var radius:float=.21
 if not floor.clear_segment(hero_from,hero_to,radius) or not floor.clear_segment(body_from,body_to,radius):return false
 var s:Dictionary=state(id);var hand_to:Vector2=hero_to+battle.vector(s.motion.offset);var hand_radius:float=param("grasp_hand_radius_m")
 if not floor.clear_segment(battle.vector(s.hand),hand_to,hand_radius) or not floor.clear_segment(shoulder(id)+(body_to-body_from),hand_to,hand_radius):return false
 if battle.bed_blocks(room,hero_to,radius,id) or battle.bed_blocks(room,body_to,radius,id):return false
 for other in battle.data.actors:
  var b:Dictionary=actor(str(other))
  if str(other)==id or not b.present or b.hp<=0 or b.room!=room:continue
  var at:Vector2=battle.position(str(other))
  if Geometry2D.get_closest_point_to_segment(at,hero_from,hero_to).distance_to(at)<.42 or Geometry2D.get_closest_point_to_segment(at,body_from,body_to).distance_to(at)<.42:return false
 return true
func tick_hold(id:String,delta:float) -> void:
 var s:Dictionary=state(id);var m:Dictionary=s.motion
 if m.is_empty() or m.legacy_static:return
 if float(m.turn_left)>0:m.turn_left=maxf(0,float(m.turn_left)-delta);sync(id);return
 var floor=battle.floor_for(str(actor(id).room));var from:Vector2=battle.position(id);var hero:Vector2=app.hero_pos
 var distance:float=minf(LIMIT_M-float(m.distance),float(battle.config.test_parameters.actor_speed_m_s)*minf(float(floor.speed_factor(from)),float(floor.speed_factor(hero)))*delta)
 var offset:Vector2=battle.vector(m.direction)*maxf(0,distance)
 if not pair_clear(id,hero,hero+offset,from,from+offset):m.blocked=true;release(id,"actual_path_obstructed");sync(id);return
 app.hero_pos=hero+offset;actor(id).pos=battle.xy(from+offset);m.distance=float(m.distance)+distance;sync(id)
 if float(m.distance)>=LIMIT_M-.00001:release(id,"actual_release_point");sync(id)
