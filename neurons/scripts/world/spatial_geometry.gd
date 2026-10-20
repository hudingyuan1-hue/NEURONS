extends RefCounted
## Shared 2D floor contract. Drawing and navigation use the same contour/voids.
## Coordinates are metres; no runtime 3D or gameplay state is introduced.
static var _cache:Dictionary={}
static var _line_cache:Dictionary={}
const Materials=preload("res://scripts/world/spatial_materials.gd")

static func _area(poly:PackedVector2Array) -> float:
 var area:float=0.0
 for i in range(poly.size()):area+=poly[i].cross(poly[(i+1)%poly.size()])
 return area*.5

static func _points(raw) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for p in raw:
  var v:Vector2=p if p is Vector2 else Vector2(float(p[0]),float(p[1]))
  if result.is_empty() or result[-1].distance_to(v)>.00001:result.append(v)
 if result.size()>2 and result[0].distance_to(result[-1])<.00001:result.remove_at(result.size()-1)
 return result

static func _contract(spec:Dictionary,size:Vector2) -> Dictionary:
 var raw=spec.get("floor_polygon_m",[[0,0],[size.x,0],[size.x,size.y],[0,size.y]])
 var holes=spec.get("floor_holes_m",[])
 var key:int=hash(raw)^hash(holes)^hash(size)
 if _cache.has(key):return _cache[key]
 var outer:PackedVector2Array=_points(raw)
 if _area(outer)<0:outer.reverse()
 var inner:Array=[]
 for item in holes:
  var ring:PackedVector2Array=_points(item)
  if ring.size()<3:continue
  if _area(ring)>0:ring.reverse()
  inner.append(ring)
 var result:Dictionary={"outer":outer,"holes":inner}
 if _cache.size()>256:_cache.clear()
 _cache[key]=result
 return result

static func floor_polygon(spec:Dictionary,size:Vector2) -> PackedVector2Array:
 return _contract(spec,size).outer

static func floor_holes(spec:Dictionary,size:Vector2) -> Array:
 return _contract(spec,size).holes

static func distance_to_ring(point:Vector2,ring:PackedVector2Array) -> float:
 var nearest:float=INF
 for i in range(ring.size()):
  nearest=minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,ring[i],ring[(i+1)%ring.size()])))
 return nearest

static func inside_floor(spec:Dictionary,size:Vector2,point:Vector2,radius:float=0.0) -> bool:
 if not point.is_finite():return false
 var contract:Dictionary=_contract(spec,size)
 if not Geometry2D.is_point_in_polygon(point,contract.outer):return false
 if radius>0 and distance_to_ring(point,contract.outer)<radius-.00001:return false
 for ring:PackedVector2Array in contract.holes:
  if Geometry2D.is_point_in_polygon(point,ring):return false
  if radius>0 and distance_to_ring(point,ring)<radius-.00001:return false
 return true

static func segment_inside_floor(spec:Dictionary,size:Vector2,a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 var distance:float=a.distance_to(b)
 var steps:int=maxi(1,ceili(distance/maxf(.04,minf(.12,radius*.5 if radius>0 else .08))))
 for i in range(steps+1):
  if not inside_floor(spec,size,a.lerp(b,float(i)/steps),radius):return false
 return true

static func projected_ring(layout,ring:PackedVector2Array,height_m:float=0.0) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for p in ring:result.append(layout.project(p)-Vector2(0,height_m*78.0))
 return result

static func draw_floor(canvas,layout,tone:Color,void_tone:Color=Color("171b25")) -> void:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var size:Vector2=layout.world_size()
 var outer:PackedVector2Array=floor_polygon(spec,size)
 if not Materials.floor(canvas,layout,outer,tone):canvas.draw_colored_polygon(projected_ring(layout,outer),tone)
 # Holes are real non-walkable openings; they cannot be filled by a rectangular floor.
 for ring:PackedVector2Array in floor_holes(spec,size):
  canvas.draw_colored_polygon(projected_ring(layout,ring),void_tone)
  var contour:PackedVector2Array=projected_ring(layout,ring);contour.append(contour[0])
  canvas.draw_polyline(contour,tone.darkened(.25),1.3,true)

static func draw_floor_lines(canvas,layout,step:float,tone:Color) -> void:
 if Materials.enabled():return # The painted material supplies its own physical seams.
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var size:Vector2=layout.world_size()
 if spec.has("boundary_style") and str(spec.boundary_style) not in ["open_street","street","covered_interior"]:
  # Organic and white-matter floors are not tiled rectangular hospital boxes.
  return
 var key:int=hash(spec.get("floor_polygon_m",[]))^hash(spec.get("floor_holes_m",[]))^hash(size)^hash(step)
 if _line_cache.has(key):
  for pair:Array in _line_cache[key]:canvas.draw_line(layout.project(pair[0]),layout.project(pair[1]),tone,1.0,true)
  return
 var lines:Array=[]
 for row in range(1,ceili(size.y/step)):
  var y:float=row*step;var start:float=-1.0
  for col in range(ceili(size.x/.1)+1):
   var x:float=minf(size.x,col*.1);var inside:bool=inside_floor(spec,size,Vector2(x,y),.025)
   if inside and start<0:start=x
   if start>=0 and (not inside or x>=size.x):
    if x-start>.1:lines.append([Vector2(start,y),Vector2(x-.05,y)])
    start=-1.0
 if _line_cache.size()>96:_line_cache.clear()
 _line_cache[key]=lines
 for pair:Array in lines:canvas.draw_line(layout.project(pair[0]),layout.project(pair[1]),tone,1.0,true)
