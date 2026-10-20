class_name RoomLayout
extends RefCounted

const SIZE := Vector2(5.6, 3.8)
const RADIUS := 0.14
const CELL := 0.1
const DOOR := Vector2(4.6, 0.22)
const BED_STOP := Vector2(2.55, 1.2)
# Legacy constants remain valid for rooms not yet migrated. Geometry v2 callers
# use the instance accessors instead of changing the scale of every old room.
var body_radius:float=RADIUS
var geometry_version:int=1
var bounds_size:Vector2=SIZE
var door_anchor:Vector2=DOOR
var bed_anchor:Vector2=BED_STOP
var cat_exit_anchor:Vector2=Vector2(3.95,3.6)
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
 rebuild_grid()

func world_size() -> Vector2:
 return bounds_size

func door_position() -> Vector2:
 return door_anchor

func bed_position() -> Vector2:
 return bed_anchor

func cat_exit_position() -> Vector2:
 return cat_exit_anchor

func rebuild_grid() -> void:
 var cells := Vector2i(ceili(world_size().x/CELL-0.00001)+1,ceili(world_size().y/CELL-0.00001)+1)
 grid.region = Rect2i(Vector2i.ZERO,cells)
 grid.cell_size = Vector2(CELL,CELL)
 grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 for y in range(cells.y):
  for x in range(cells.x):
   grid.set_point_solid(Vector2i(x,y), not walkable(Vector2(x,y)*CELL))

func push_movable_blocker(blocker:Rect2) -> Dictionary:
 # Only cells within this rectangle's body-radius expansion can change.
 # Preserve existing temporary occupancy and restore its exact solid mask.
 var previous:Array[Rect2]=movable_blockers.duplicate();var changed:Array=[]
 movable_blockers.append(blocker)
 var grown:Rect2=blocker.grow(body_radius+CELL)
 for y in range(floori(grown.position.y/CELL),ceili(grown.end.y/CELL)+1):
  for x in range(floori(grown.position.x/CELL),ceili(grown.end.x/CELL)+1):
   var cell:=Vector2i(x,y)
   if not grid.is_in_boundsv(cell):continue
   var was:bool=grid.is_point_solid(cell);var solid:bool=not walkable(Vector2(cell)*CELL)
   if was!=solid:changed.append({"cell":cell,"solid":was});grid.set_point_solid(cell,solid)
 return {"previous":previous,"changed":changed}

func pop_movable_blocker(state:Dictionary) -> void:
 movable_blockers=state.previous
 for item:Dictionary in state.changed:grid.set_point_solid(item.cell,item.solid)

func project(p:Vector2) -> Vector2:
 return Vector2(45.0 + 80.0*p.x + 28.0*p.y, 132.0 + 46.0*p.y)

func unproject(p:Vector2) -> Vector2:
 var depth := (p.y-132.0)/46.0
 return Vector2((p.x-45.0-28.0*depth)/80.0,depth)

func walkable(p:Vector2, radius:float=-1.0) -> bool:
 if radius<0.0:radius=body_radius
 if not Rect2(Vector2(radius,radius),world_size()-Vector2.ONE*radius*2).has_point(p):
  return false
 for f in furniture:
  if not f.get("solid",true) or not f.get("collision",true):continue
  for rect:Rect2 in f.get("collision_rects",[f.rect]):
   if footprint_contains(rect.grow(radius),p):return false
 for rect in movable_blockers:
  if footprint_contains(rect.grow(radius),p):return false
 return true

func footprint_contains(rect:Rect2,point:Vector2) -> bool:
 if geometry_version<2:return rect.has_point(point)
 # Geometry v2 uses the same closed boundary for points and segments.
 # Rect2.has_point excludes its far edges, allowing one endpoint onto a wall.
 return point.x>=rect.position.x and point.x<=rect.end.x and point.y>=rect.position.y and point.y<=rect.end.y

func segment_hits_rect(a:Vector2,b:Vector2,rect:Rect2) -> bool:
 # Continuous slab intersection, including tangencies, parallel edges and
 # zero-length segments. No spacing-dependent sampling can miss a corner.
 var direction:Vector2=b-a
 var enter:float=0.0
 var leave:float=1.0
 for axis:int in range(2):
  var delta:float=direction[axis]
  if absf(delta)<0.000000000001:
   if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]:return false
   continue
  var first:float=(rect.position[axis]-a[axis])/delta
  var last:float=(rect.end[axis]-a[axis])/delta
  if first>last:
   var saved:float=first;first=last;last=saved
  enter=maxf(enter,first);leave=minf(leave,last)
  if enter>leave:return false
 return true

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 if radius<0.0:radius=body_radius
 if not a.is_finite() or not b.is_finite():return false
 if geometry_version>=2:
  if not walkable(a,radius) or not walkable(b,radius):return false
  for item:Dictionary in furniture:
   if not item.get("solid",true) or not item.get("collision",true):continue
   for rect:Rect2 in item.get("collision_rects",[item.rect]):
    if segment_hits_rect(a,b,rect.grow(radius)):return false
  for rect:Rect2 in movable_blockers:
   if segment_hits_rect(a,b,rect.grow(radius)):return false
  return true
 var steps := maxi(2,ceili(a.distance_to(b)/0.03))
 for i in range(steps+1):
  var p := a.lerp(b,float(i)/steps)
  if not Rect2(Vector2(radius,radius),world_size()-Vector2.ONE*radius*2).has_point(p):return false
  for f in furniture:
   if not f.get("solid",true) or not f.get("collision",true):continue
   for rect:Rect2 in f.get("collision_rects",[f.rect]):
    if rect.grow(radius).has_point(p):return false
  for rect in movable_blockers:
   if rect.grow(radius).has_point(p):return false
 return true

func path(a:Vector2,b:Vector2) -> PackedVector2Array:
 if not walkable(a) or not walkable(b):return PackedVector2Array()
 if geometry_version>=2:return _connected_path(a,b)
 var ai := Vector2i((a/CELL+Vector2.ONE*0.0001).round())
 var bi := Vector2i((b/CELL+Vector2.ONE*0.0001).round())
 if not grid.is_in_boundsv(ai) or not grid.is_in_boundsv(bi):
  return PackedVector2Array()
 var result := grid.get_point_path(ai,bi)
 if result.size()>0:
  result[0]=a
  result[result.size()-1]=b
 return result

func _connected_path(a:Vector2,b:Vector2) -> PackedVector2Array:
 # Exact endpoints connect to visible legal cells. Replacing rounded endpoints
 # can otherwise cut through an inflated cabinet corner or a moved object.
 if a.is_equal_approx(b):return PackedVector2Array([a])
 if clear_segment(a,b,body_radius):return PackedVector2Array([a,b])
 var starts:Array[Vector2i]=_grid_candidates(a)
 var ends:Array[Vector2i]=_grid_candidates(b)
 for start in starts:
  for finish in ends:
   var middle:PackedVector2Array=grid.get_point_path(start,finish)
   if middle.is_empty():continue
   var result:=PackedVector2Array([a])
   for point in middle:
    if not result[-1].is_equal_approx(point):result.append(point)
   if not result[-1].is_equal_approx(b):result.append(b)
   var valid:=true
   for index in range(1,result.size()):
    if not clear_segment(result[index-1],result[index],body_radius):
     valid=false
     break
   if valid:return _visible_waypoints(result)
 return PackedVector2Array()

func _visible_waypoints(points:PackedVector2Array) -> PackedVector2Array:
 # A moving target can require a new path every frame. Keeping the nearest
 # start grid cell behind the actor makes that actor walk back to it forever.
 # Keep exact endpoints and only remove waypoints reachable at full radius.
 var result:=PackedVector2Array([points[0]])
 var index:int=0
 while index<points.size()-1:
  var next:int=points.size()-1
  while next>index+1 and not clear_segment(points[index],points[next],body_radius):next-=1
  result.append(points[next]);index=next
 return result

func _grid_candidates(point:Vector2) -> Array[Vector2i]:
 var center:=Vector2i((point/CELL).round())
 var candidates:Array[Vector2i]=[]
 for y in range(center.y-3,center.y+4):
  for x in range(center.x-3,center.x+4):
   var cell:=Vector2i(x,y)
   if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):continue
   if clear_segment(point,Vector2(cell)*CELL,body_radius):candidates.append(cell)
 candidates.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
  var da:float=snappedf(point.distance_squared_to(Vector2(a)*CELL),0.000001)
  var db:float=snappedf(point.distance_squared_to(Vector2(b)*CELL),0.000001)
  if not is_equal_approx(da,db):return da<db
  return a.y<b.y or (a.y==b.y and a.x<b.x))
 if candidates.size()>8:candidates.resize(8)
 return candidates

func move_path(p:Vector2, route:PackedVector2Array, distance:float) -> Dictionary:
 var current := p
 var remaining := route.duplicate()
 while remaining.size()>0 and distance>0:
  var step := current.distance_to(remaining[0])
  if step<=distance:
   if not walkable(remaining[0]) or not clear_segment(current,remaining[0],body_radius):
    break
   current=remaining[0]
   remaining.remove_at(0)
   distance-=step
  else:
   var candidate := current.move_toward(remaining[0],distance)
   if walkable(candidate) and clear_segment(current,candidate,body_radius):
    current=candidate
   break
 return {"position":current,"route":remaining}

func segment_avoids_bodies(a:Vector2,b:Vector2,bodies:Array) -> bool:
 for body:Dictionary in bodies:
  var at:Vector2=body.pos;var radius:float=float(body.radius)
  if a.distance_to(at)<radius and b.distance_to(at)>a.distance_to(at):continue
  if Geometry2D.get_closest_point_to_segment(at,a,b).distance_to(at)<radius:return false
 return true

func path_around_bodies(a:Vector2,b:Vector2,bodies:Array) -> PackedVector2Array:
 # Temporary circular occupation participates in endpoints and every segment.
 # Keep grid waypoints: static-only smoothing would cut through an actor.
 if not walkable(a) or not walkable(b):return PackedVector2Array()
 if clear_segment(a,b,body_radius) and segment_avoids_bodies(a,b,bodies):return PackedVector2Array([a,b])
 var changed:Array[Vector2i]=[]
 for y in range(grid.region.position.y,grid.region.end.y):
  for x in range(grid.region.position.x,grid.region.end.x):
   var cell:=Vector2i(x,y)
   if grid.is_point_solid(cell):continue
   for body:Dictionary in bodies:
    if (Vector2(cell)*CELL).distance_to(body.pos)<float(body.radius)+.02:
     changed.append(cell);grid.set_point_solid(cell,true);break
 var starts:Array[Vector2i]=_grid_candidates(a)
 var ends:Array[Vector2i]=_grid_candidates(b)
 var result:=PackedVector2Array()
 for start in starts:
  if not segment_avoids_bodies(a,Vector2(start)*CELL,bodies):continue
  for finish in ends:
   if not segment_avoids_bodies(Vector2(finish)*CELL,b,bodies):continue
   var middle:PackedVector2Array=grid.get_point_path(start,finish)
   if middle.is_empty():continue
   var proposed:=PackedVector2Array([a]);proposed.append_array(middle);proposed.append(b)
   var valid:bool=true
   for i in range(1,proposed.size()):
    if not clear_segment(proposed[i-1],proposed[i],body_radius) or not segment_avoids_bodies(proposed[i-1],proposed[i],bodies):valid=false;break
   if valid:result=proposed;break
  if not result.is_empty():break
 for cell in changed:grid.set_point_solid(cell,false)
 return result

