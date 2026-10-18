extends RefCounted
## S3:P1742–1747 / S4:P227/T16R5/T19R9. Actual local liquid, not a body box.
const ID="pharmacist"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func attack() -> Dictionary:return battle.config.attacks.splash
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func cup() -> Vector2:
 var d:Vector2=direction()
 return battle.position(ID)+d*param("splash_cup_forward_m")+Vector2(-d.y,d.x)*param("splash_cup_side_m")
func state() -> Dictionary:
 if not battle.data.has("pharmacist_splash"):battle.data.pharmacist_splash={"launched":{},"shots":[],"phase":"ready"}
 return battle.data.pharmacist_splash
func ray_targets(at:Vector2,d:Vector2) -> Array:
 var radius:float=param("splash_drop_radius_m");var reach:float=float(attack().reach)-radius
 var angle:float=asin(clampf((float(attack().width)-radius)/reach,0,.95));var targets:Array=[]
 var count:int=int(param("splash_ray_count"))
 for i in range(count):targets.append(battle.xy(at+d.rotated(lerpf(-angle,angle,float(i)/float(maxi(1,count-1))))*reach))
 return targets
func launch() -> void:
 var a:Dictionary=actor();var s:Dictionary=state();var receipt:String=str(a.attack_id)
 if s.launched.has(receipt):return
 if not a.present or a.hp<=0 or a.portions<=0:
  a.phase="recover";a.elapsed=0;return
 var start:Vector2=cup();var targets:Array=ray_targets(battle.position(ID),direction());var rays:Array=[]
 for end in targets:rays.append({"pos":battle.xy(start),"end":end,"path":[],"ground_at":-1.0,"blocked":false})
 s.launched[receipt]=true;a.portions=maxi(0,int(a.portions)-1)
 s.shots.append({"id":receipt,"room":a.room,"origin":battle.xy(start),"age":0.0,"rays":rays,"hits":{}})
 battle.app.audio.cue("SFX_SPLASH",receipt+":pour")
 app.rules._record("street_splash_released",receipt+":pour",{"remaining":a.portions,"room":a.room,"source":"S3:P1747/S4:T16R5"})
func before_actor() -> void:
 var a:Dictionary=actor()
 if a.hurt>0 and a.phase in ["windup","attack"]:
  # A real blow stops the hand action. Already-released fluid has its own clock.
  a.phase="recover";a.elapsed=0
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:s.phase="lowered"
 elif a.phase=="windup":s.phase="cup_raise" if a.elapsed<float(attack().windup)*.5 else "cup_tip"
 elif a.phase=="attack":s.phase="release"
 elif a.phase=="recover":s.phase="cup_withdraw"
 else:s.phase="ready" if a.portions>0 else "empty"
func travel_ray(shot:Dictionary,ray:Dictionary,age:float) -> void:
 ray.path=[]
 if float(ray.ground_at)>=0:return
 var floor=battle.floor_for(str(shot.room));var radius:float=param("splash_drop_radius_m")
 var from:Vector2=battle.vector(ray.pos);var desired:Vector2=battle.vector(shot.origin).lerp(battle.vector(ray.end),clampf(age/float(attack().active),0,1));var last:Vector2=from
 var steps:int=maxi(1,ceili(from.distance_to(desired)/param("splash_sample_m")))
 for index in range(1,steps+1):
  var next:Vector2=from.lerp(desired,float(index)/steps)
  if not floor.clear_segment(last,next,radius):ray.blocked=true;ray.ground_at=age;break
  last=next
 ray.pos=battle.xy(last);ray.path=[battle.xy(from),battle.xy(last)]
 if age>=float(attack().active):ray.ground_at=age
func path_contains(room:String,paths:Array,target:Vector2) -> bool:
 var radius:float=param("splash_drop_radius_m")+param("splash_body_radius_m");var floor=battle.floor_for(room)
 for path in paths:
  if path.is_empty():continue
  var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(path[0]),battle.vector(path[1]))
  if near.distance_squared_to(target)<=radius*radius and floor.clear_segment(near,target):return true
 return false
func settle(shot:Dictionary) -> void:
 var paths:Array=[]
 for ray in shot.rays:paths.append(ray.path)
 if shot.room==app.room_id and app.rules.hp>0 and not shot.hits.has("hero") and path_contains(str(shot.room),paths,app.hero_pos):
  shot.hits.hero=true
  if actor().attack_id==shot.id:actor().hits.hero=true
  battle._damage_hero(str(shot.id),int(attack().hp),int(attack().sp),ID)
 for id in battle.data.actors:
  var b:Dictionary=battle.data.actors[id]
  if id==ID or not b.present or b.hp<=0 or b.room!=shot.room or shot.hits.has(id) or battle.spec(str(id)).relation not in ["friend","neutral"]:continue
  if path_contains(str(shot.room),paths,battle.position(str(id))):
   shot.hits[id]=true
   # Preserve the existing shared zero-HP NPC contact; no invented NPC SP system.
   battle.damage_actor(ID,str(id),int(attack().hp),str(shot.id)+":"+str(id))
func tick(delta:float) -> void:
 var s:Dictionary=state();var retained:Array=[]
 for shot in s.shots:
  shot.previous_age=shot.age;shot.age+=delta;var visible:bool=false
  for ray in shot.rays:
   travel_ray(shot,ray,float(shot.age))
   if float(ray.ground_at)<0 or float(shot.age)-float(ray.ground_at)<param("splash_ground_s"):visible=true
  settle(shot)
  if visible:retained.append(shot)
 s.shots=retained
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor()
 if not a.present or a.hp<=0 or a.hurt>0:return false
 if a.phase=="windup" and a.portions>0:
  var paths:Array=[];var start:Vector2=cup();var floor=battle.floor_for(str(a.room))
  for end in ray_targets(battle.position(ID),direction()):
   var last:Vector2=start;var to:Vector2=battle.vector(end);var count:int=maxi(1,ceili(start.distance_to(to)/param("splash_sample_m")))
   for i in range(1,count+1):
    var next:Vector2=start.lerp(to,float(i)/count)
    if not floor.clear_segment(last,next,param("splash_drop_radius_m")):break
    last=next
   paths.append([battle.xy(start),battle.xy(last)])
  return path_contains(str(a.room),paths,target)
 if a.phase=="attack":
  for shot in state().shots:
   if shot.id!=a.attack_id:continue
   var paths:Array=[]
   for ray in shot.rays:paths.append(ray.path)
   return path_contains(str(shot.room),paths,target)
 return false
