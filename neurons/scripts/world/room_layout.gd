class_name RoomLayout
extends RefCounted

const SIZE := Vector2(5.6, 3.8)
const RADIUS := 0.14
const CELL := 0.1
const DOOR := Vector2(4.6, 0.22)
const BED_STOP := Vector2(2.55, 1.2)
var furniture: Array[Dictionary] = [
 {"id":"bed", "name":"床", "rect":Rect2(0.18,0.18,2.15,1.42), "at":Vector2(2.55,1.2), "height":27.0, "color":Color("8b9b9c"), "kind":"bed"},
 {"id":"bedside", "name":"床头柜", "rect":Rect2(0.18,1.82,0.58,0.48), "at":Vector2(0.97,1.85), "height":22.0, "color":Color("967857"), "kind":"drawer"},
 {"id":"chair", "name":"靠背椅", "rect":Rect2(0.98,2.14,0.4,0.43), "at":Vector2(1.62,2.34), "height":16.0, "color":Color("8a7255"), "kind":"chair"},
 {"id":"desk", "name":"书桌", "rect":Rect2(0.18,3.0,1.65,0.58), "at":Vector2(1.68,2.72), "height":28.0, "color":Color("ae8c61"), "kind":"desk"},
 {"id":"stool", "name":"蓝凳与纸箱", "rect":Rect2(2.43,3.0,0.36,0.36), "at":Vector2(2.5,2.72), "height":14.0, "color":Color("657f8b"), "kind":"stool"},
 {"id":"box", "name":"杂物箱", "rect":Rect2(1.94,3.02,0.38,0.42), "at":Vector2(2.03,2.72), "height":17.0, "color":Color("a78f6c"), "kind":"box"},
 {"id":"rack", "name":"衣帽架与白褂", "rect":Rect2(3.38,3.10,0.4,0.4), "at":Vector2(3.15,2.9), "height":63.0, "color":Color("c4bba6"), "kind":"rack"},
 {"id":"wardrobe", "name":"衣柜", "rect":Rect2(4.78,2.23,0.65,1.3), "at":Vector2(4.5,2.65), "height":72.0, "color":Color("81755f"), "kind":"wardrobe"},
 {"id":"books", "name":"五层书架", "rect":Rect2(4.86,1.63,0.55,0.44), "at":Vector2(4.55,1.85), "height":67.0, "color":Color("967c5c"), "kind":"books"},
 {"id":"storage", "name":"储物柜与病服", "rect":Rect2(4.75,0.65,0.68,0.74), "at":Vector2(4.45,1.05), "height":43.0, "color":Color("879184"), "kind":"drawer"},
 {"id":"fan", "name":"立式风扇", "rect":Rect2(3.83,0.22,0.4,0.4), "at":Vector2(3.7,0.9), "height":54.0, "color":Color("6d8485"), "kind":"fan"}
]
var grid := AStarGrid2D.new()
var movable_blockers:Array[Rect2]=[]

func _init() -> void:
 grid.region = Rect2i(0,0,57,39)
 grid.cell_size = Vector2(CELL,CELL)
 grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 for y in range(39):
  for x in range(57):
   grid.set_point_solid(Vector2i(x,y), not walkable(Vector2(x,y)*CELL))

func project(p:Vector2) -> Vector2:
 return Vector2(45.0 + 80.0*p.x + 28.0*p.y, 132.0 + 46.0*p.y)

func unproject(p:Vector2) -> Vector2:
 var depth := (p.y-132.0)/46.0
 return Vector2((p.x-45.0-28.0*depth)/80.0,depth)

func walkable(p:Vector2, radius:float=RADIUS) -> bool:
 if not Rect2(Vector2(radius,radius),SIZE-Vector2.ONE*radius*2).has_point(p):
  return false
 for f in furniture:
  if (f.rect as Rect2).grow(radius).has_point(p):
   return false
 for rect in movable_blockers:
  if rect.grow(radius).has_point(p):return false
 return true

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 var steps := maxi(2,ceili(a.distance_to(b)/0.03))
 for i in range(steps+1):
  var p := a.lerp(b,float(i)/steps)
  if not Rect2(Vector2(radius,radius),SIZE-Vector2.ONE*radius*2).has_point(p):return false
  for f in furniture:
   if (f.rect as Rect2).grow(radius).has_point(p):
    return false
  for rect in movable_blockers:
   if rect.grow(radius).has_point(p):return false
 return true

func path(a:Vector2,b:Vector2) -> PackedVector2Array:
 if not walkable(a) or not walkable(b):return PackedVector2Array()
 var ai := Vector2i((a/CELL+Vector2.ONE*0.0001).round())
 var bi := Vector2i((b/CELL+Vector2.ONE*0.0001).round())
 if not grid.is_in_boundsv(ai) or not grid.is_in_boundsv(bi):
  return PackedVector2Array()
 var result := grid.get_point_path(ai,bi)
 if result.size()>0:
  result[0]=a
  result[result.size()-1]=b
 return result

func move_path(p:Vector2, route:PackedVector2Array, distance:float) -> Dictionary:
 var current := p
 var remaining := route.duplicate()
 while remaining.size()>0 and distance>0:
  var step := current.distance_to(remaining[0])
  if step<=distance:
   if not walkable(remaining[0]) or not clear_segment(current,remaining[0],RADIUS):
    break
   current=remaining[0]
   remaining.remove_at(0)
   distance-=step
  else:
   var candidate := current.move_toward(remaining[0],distance)
   if walkable(candidate) and clear_segment(current,candidate,RADIUS):
    current=candidate
   break
 return {"position":current,"route":remaining}

