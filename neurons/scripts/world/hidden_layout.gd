extends "res://scripts/world/room_layout.gd"
## Independent L1 plaza fragment. Same metre/pixel mapping as the current
## campaign, not the seven-room Street route. Geometry remains test data.
const ENTRY=Vector2(0.6,3.35)
const EXIT=Vector2(5.12,0.42)

func _init() -> void:
 furniture=[
  {"id":"fountain","name":"喷泉 · 碰撞占位","rect":Rect2(2.25,1.25,1.0,1.2),"at":Vector2(2.0,1.8),"height":23.0,"color":Color("667f81"),"kind":"fountain"},
  {"id":"bench_west","name":"长椅 · 不可休息","rect":Rect2(0.25,0.25,1.0,0.35),"at":Vector2(0.8,0.85),"height":15.0,"color":Color("8b7965"),"kind":"bench"},
  {"id":"bench_east","name":"长椅 · 不可休息","rect":Rect2(4.1,3.2,1.0,0.35),"at":Vector2(4.4,2.95),"height":15.0,"color":Color("8b7965"),"kind":"bench"},
  {"id":"lamp","name":"路灯 · 占位","rect":Rect2(4.7,1.55,0.2,0.2),"at":Vector2(4.5,1.65),"height":75.0,"color":Color("7e8987"),"kind":"lamp"}
 ]
 movable_blockers.clear()
 super._init()

func clipped_step(from:Vector2,to:Vector2,radius:float=RADIUS) -> Vector2:
 var result:Vector2=from
 var steps:int=maxi(1,ceili(from.distance_to(to)/0.02))
 for i in range(1,steps+1):
  var next:Vector2=from.lerp(to,float(i)/steps)
  if not walkable(next,radius) or not clear_segment(result,next,radius):break
  result=next
 return result
