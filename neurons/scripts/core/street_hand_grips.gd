extends RefCounted
## S3:P1724–1727/P1774–1780/P1821–1824/P1887–1889.
## Existing four identities: physical forearm enclosure, never torso grazing.
const IDS=["archivist","supervisor","stitched","self"]
const SOURCES={"archivist":"S3:P1724–1727","supervisor":"S3:P1774–1780","stitched":"S3:P1821–1824","self":"S3:P1887–1889"}
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor(id:String) -> Dictionary:return battle.data.actors[id]
func attack(id:String) -> Dictionary:return battle.config.attacks[str(battle.spec(id).attack)]
func param(key:String) -> float:return float(battle.config.test_parameters["hand_grip_"+key])
func state(id:String) -> Dictionary:
 if not battle.data.has("hand_grips"):battle.data.hand_grips={}
 if not battle.data.hand_grips.has(id):battle.data.hand_grips[id]={"owner":id,"phase":"lowered","attack_id":"","hands":[],"blocked":[],"open":1.0,"recover_from":[],"held_offset":[],"holding_hand":-1}
 return battle.data.hand_grips[id]
func direction(id:String) -> Vector2:
 var value:Vector2=battle.vector(actor(id).direction)
 return value.normalized() if value.length_squared()>.001 else Vector2.RIGHT
func hand_sides(id:String) -> Array:return [-1,1] if id=="supervisor" else [1] if id=="stitched" else [-1]
func outer_radius(id:String) -> float:return param("clamp_outer_m") if id=="supervisor" else param("hand_outer_m")
func shoulder(id:String,index:int) -> Vector2:
 var d:Vector2=direction(id);return battle.position(id)+Vector2(-d.y,d.x)*float(hand_sides(id)[index])*param("shoulder_m")
func hand_goal(id:String,index:int,progress:float=1.0) -> Vector2:
 var d:Vector2=direction(id);var side:=Vector2(-d.y,d.x);var offset:float=float(hand_sides(id)[index])*param("wrist_offset_m")
 # Every attached finger/jaw stays inside the original reach and width.
 var reach:float=sqrt(maxf(.01,pow(float(attack(id).reach)-outer_radius(id),2)-offset*offset))
 return battle.position(id)+d*lerpf(param("near_m"),reach,clampf(progress,0,1))+side*offset
func forearm_point(target:Vector2,center:Vector2,room:String) -> Vector2:
 var facing:Vector2=app.hero_facing;var withdrawal:float=0.0
 if target.distance_to(app.hero_pos)<.001:
  if not app.rules.gripped and app.rules.reaction_skill=="WITHDRAW" and app.rules.reaction_left>0:withdrawal=param("withdraw_m")
 else:
  for other in battle.data.actors:
   var body:Dictionary=actor(str(other))
   if body.present and body.room==room and battle.position(str(other)).distance_to(target)<.001:facing=battle.vector(body.direction);break
 if facing.length_squared()<.001:facing=Vector2.RIGHT
 facing=facing.normalized();var side:=Vector2(-facing.y,facing.x);var closest:Vector2=target;var distance:float=INF
 for sign_value in [-1,1]:
  var wrist:Vector2=target+side*float(sign_value)*param("wrist_offset_m")-facing*withdrawal
  var near:Vector2=Geometry2D.get_closest_point_to_segment(center,wrist-facing*param("forearm_m")*.25,wrist+facing*param("forearm_m")*.75)
  if near.distance_squared_to(center)<distance:closest=near;distance=near.distance_squared_to(center)
 return closest
func release(id:String,reason:String) -> void:
 if battle.data.holder!=id:return
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor(id).hp>0:actor(id).phase="recover";actor(id).elapsed=0.0
 app.rules._record("street_hand_grip_released",str(actor(id).attack_id)+":release",{"actor":id,"reason":reason,"source":SOURCES[id]})
func before_actor(id:String) -> void:
 var a:Dictionary=actor(id)
 if battle.data.holder==id and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0 or not battle.data.ending.is_empty()):release(id,"actual_interruption")
 if a.phase=="grip" and battle.data.holder!=id:a.phase="recover";a.elapsed=0.0
 if a.hurt>0 and a.phase in ["windup","attack"]:a.phase="recover";a.elapsed=0.0
 sync(id)
func sync(id:String) -> void:
 var a:Dictionary=actor(id);var s:Dictionary=state(id);var count:int=hand_sides(id).size()
 if s.hands.size()!=count:
  s.hands=[];s.blocked=[]
  for index in range(count):s.hands.append(battle.xy(hand_goal(id,index,0)));s.blocked.append(false)
 if not a.present or a.hp<=0:s.phase="lowered";s.open=1.0;return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:
   s.attack_id=a.attack_id;s.blocked=[];s.recover_from=[];s.held_offset=[];s.holding_hand=-1
   for index in range(count):s.blocked.append(false)
  s.phase="jaws_open" if id=="supervisor" else "fingers_open";s.open=1.0
  for index in range(count):s.hands[index]=battle.xy(hand_goal(id,index,0))
 elif a.phase=="attack":
  var progress:float=float(a.elapsed)/float(attack(id).active)
  s.phase="extend" if progress<param("extend_ratio") else "close"
  s.open=1.0-clampf((progress-param("extend_ratio"))/(1.0-param("extend_ratio")),0,1)
 elif a.phase=="grip" and battle.data.holder==id:
  if s.held_offset.is_empty():
   # Legacy data proves a paid receipt/deadline, not an invisible long-range arm.
   var hand_index:int=capture_hand(id,app.hero_pos,true)
   if hand_index<0:release(id,"legacy_outside_actual_forearm");sync(id);return
   s.holding_hand=hand_index;s.held_offset=battle.xy(forearm_point(app.hero_pos,hand_goal(id,hand_index),str(a.room))-app.hero_pos)
  var index:int=int(s.holding_hand);var held:Vector2=app.hero_pos+battle.vector(s.held_offset)
  if index<0 or index>=count or battle.position(id).distance_to(held)>float(attack(id).reach) or not battle.floor_for(str(a.room)).clear_segment(shoulder(id,index),held,param("arm_radius_m")):
   release(id,"actual_hold_geometry_broken");sync(id);return
  s.phase="held";s.open=0.0;s.hands[index]=battle.xy(held)
 elif a.phase=="recover":
  if s.recover_from.is_empty():s.recover_from=s.hands.duplicate(true)
  s.phase="open_retract";s.open=1.0
  for index in range(count):s.hands[index]=battle.xy(battle.vector(s.recover_from[index]).lerp(hand_goal(id,index,0),clampf(float(a.elapsed)/float(attack(id).recover),0,1)))
 else:
  s.phase="paper_remaining" if id=="stitched" and a.phase=="tear" else "lowered";s.open=1.0;s.recover_from=[];s.held_offset=[];s.holding_hand=-1
  for index in range(count):s.hands[index]=battle.xy(hand_goal(id,index,0));s.blocked[index]=false
func prepare(id:String,delta:float) -> void:
 if actor(id).phase!="attack":return
 var a:Dictionary=actor(id);var s:Dictionary=state(id);var floor=battle.floor_for(str(a.room))
 var progress:float=clampf((float(a.elapsed)+delta)/(float(attack(id).active)*param("extend_ratio")),0,1)
 for index in range(s.hands.size()):
  if s.blocked[index]:continue
  var start:Vector2=shoulder(id,index);var goal:Vector2=hand_goal(id,index,progress)
  if floor.clear_segment(start,goal,param("arm_radius_m")) and floor.clear_segment(battle.vector(s.hands[index]),goal,outer_radius(id)):
   s.hands[index]=battle.xy(goal);continue
  var last:Vector2=start;var count:int=maxi(1,ceili(start.distance_to(goal)/param("sample_m")))
  for sample in range(1,count+1):
   var next:Vector2=start.lerp(goal,float(sample)/count)
   if not floor.clear_segment(last,next,outer_radius(id)):break
   last=next
  s.hands[index]=battle.xy(last);s.blocked[index]=true
func capture_hand(id:String,target:Vector2,legacy:bool=false) -> int:
 var a:Dictionary=actor(id);var s:Dictionary=state(id);var floor=battle.floor_for(str(a.room))
 for index in range(hand_sides(id).size()):
  if not legacy and bool(s.blocked[index]):continue
  var hand:Vector2=hand_goal(id,index) if legacy or a.phase=="windup" else battle.vector(s.hands[index])
  var near:Vector2=forearm_point(target,hand,str(a.room))
  if hand.distance_to(near)<=param("capture_m") and floor.clear_segment(shoulder(id,index),hand,param("arm_radius_m")) and floor.clear_segment(hand,near):return index
 return -1
func contains(id:String,target:Vector2) -> bool:
 var a:Dictionary=actor(id)
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():return false
 if a.phase=="attack":
  if float(a.elapsed)<float(attack(id).active)*param("contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 return capture_hand(id,target)>=0
func begin_hold(id:String) -> void:
 var s:Dictionary=state(id);var index:int=capture_hand(id,app.hero_pos)
 if index<0:release(id,"actual_forearm_lost_before_hold");return
 s.holding_hand=index;s.held_offset=battle.xy(forearm_point(app.hero_pos,battle.vector(s.hands[index]),str(actor(id).room))-app.hero_pos)
 sync(id)
