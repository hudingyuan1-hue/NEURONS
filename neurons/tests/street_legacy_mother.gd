extends "res://scripts/core/street_mother.gd"
## Exact pre-optimization sampled clipping and uncached windup query.
func clipped(arms:Array) -> Array:
 var out:Array=arms.duplicate(true);var floor=battle.floor_for(str(actor().room))
 for arm in out:
  for j in range(1,3):
   var start:Vector2=battle.vector(arm[j-1]);var end:Vector2=battle.vector(arm[j]);var last:Vector2=start;var steps:int=maxi(1,ceili(start.distance_to(end)/param("mother_sample_m")))
   for n in range(1,steps+1):
    var next:Vector2=start.lerp(end,float(n)/steps)
    if not floor.clear_segment(last,next,param("mother_arm_m")):break
    last=next
   arm[j]=battle.xy(last)
 return out
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor()
 if not a.present or a.hp<=0 or a.hurt>0 or not battle.data.ending.is_empty():return false
 if a.phase=="windup":return touching(clipped(shape(1)),target)
 if a.phase!="attack":return false
 for pose in state().sweep:
  if touching(pose,target):return true
 return false
