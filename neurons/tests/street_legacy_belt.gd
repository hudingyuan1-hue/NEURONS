extends "res://scripts/core/street_belt.gd"
## Read-only reference of the pre-optimization clipping and uncached query.
func clipped(p:Array,previous:Array=[]) -> Dictionary:
 var floor=battle.floor_for(str(actor().room));var radius:float=param("belt_radius_m")
 if not previous.is_empty() and previous.size()==p.size():
  for i in range(p.size()):
   if not floor.clear_segment(battle.vector(previous[i]),battle.vector(p[i]),radius):return {"points":previous.duplicate(true),"blocked":true}
 var out:Array=[p[0]]
 if not floor.clear_segment(battle.position(ID),battle.vector(p[0]),radius):return {"points":[],"blocked":true}
 for i in range(1,p.size()):
  var start:Vector2=battle.vector(p[i-1]);var end:Vector2=battle.vector(p[i]);var last:Vector2=start
  var count:int=maxi(1,ceili(start.distance_to(end)/param("belt_sample_m")))
  for n in range(1,count+1):
   var next:Vector2=start.lerp(end,float(n)/count)
   if not floor.clear_segment(last,next,radius):
    if last.distance_to(start)>.0001:out.append(battle.xy(last))
    return {"points":out,"blocked":true}
   last=next
  out.append(p[i])
 return {"points":out,"blocked":false}
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor()
 if not a.present or a.hp<=0 or a.hurt>0:return false
 var points:Array=[]
 if a.phase=="windup":points=sweep_between(0,1).points
 elif a.phase=="attack":points=state().sweep
 else:return false
 var radius:float=param("belt_radius_m")+param("belt_body_radius_m");var floor=battle.floor_for(str(a.room))
 for pose in points:
  for i in range(1,pose.size()):
   var near:Vector2=Geometry2D.get_closest_point_to_segment(target,battle.vector(pose[i-1]),battle.vector(pose[i]))
   if near.distance_squared_to(target)<=radius*radius and floor.clear_segment(near,target):return true
 return false
