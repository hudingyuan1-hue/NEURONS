extends RefCounted
## One oriented transport bed. Dimensions are trial geometry, not art approval.
const HALF_LENGTH=0.95
const HALF_WIDTH=0.45
const OFFSET=0.85
const Geometry=preload("res://scripts/world/spatial_geometry.gd")

static func facing(direction:Vector2) -> Vector2:
 return direction.normalized() if direction.length_squared()>.000001 else Vector2.RIGHT

static func polygon(at:Vector2,direction:Vector2) -> PackedVector2Array:
 var forward:Vector2=facing(direction);var side:=Vector2(-forward.y,forward.x)
 var center:Vector2=at+forward*OFFSET
 return PackedVector2Array([center-forward*HALF_LENGTH-side*HALF_WIDTH,center+forward*HALF_LENGTH-side*HALF_WIDTH,center+forward*HALF_LENGTH+side*HALF_WIDTH,center-forward*HALF_LENGTH+side*HALF_WIDTH])

static func bounds(at:Vector2,direction:Vector2) -> Rect2:
 var points:PackedVector2Array=polygon(at,direction);var rect:=Rect2(points[0],Vector2.ZERO)
 for p in points:rect=rect.expand(p)
 return rect

static func touches(at:Vector2,direction:Vector2,point:Vector2,radius:float) -> bool:
 var forward:Vector2=facing(direction);var offset:Vector2=point-at-forward*OFFSET
 var dx:float=maxf(0,absf(offset.dot(forward))-HALF_LENGTH)
 var dy:float=maxf(0,absf(offset.cross(forward))-HALF_WIDTH)
 return dx*dx+dy*dy<=radius*radius+.0000001

static func overlaps_rect(at:Vector2,direction:Vector2,rect:Rect2) -> bool:
 var forward:Vector2=facing(direction);var side:=Vector2(-forward.y,forward.x)
 var center:Vector2=at+forward*OFFSET;var diff:Vector2=rect.get_center()-center;var half:Vector2=rect.size*.5
 for axis in [Vector2.RIGHT,Vector2.DOWN,forward,side]:
  var a:float=HALF_LENGTH*absf(forward.dot(axis))+HALF_WIDTH*absf(side.dot(axis))
  var b:float=half.x*absf(axis.x)+half.y*absf(axis.y)
  if absf(diff.dot(axis))>a+b:return false
 return true

static func contained(space,at:Vector2,direction:Vector2,portals:Array=[]) -> bool:
 if not at.is_finite() or not direction.is_finite():return false
 var size:Vector2=space.world_size()
 var spec:Dictionary=space.space_spec() if space.has_method("space_spec") else {}
 var bed:PackedVector2Array=polygon(at,direction)
 var samples:=PackedVector2Array()
 for i in range(bed.size()):
  var a:Vector2=bed[i];var b:Vector2=bed[(i+1)%bed.size()]
  var steps:int=ceili(a.distance_to(b)/.08)
  for step in range(steps+1):samples.append(a.lerp(b,float(step)/steps))
 samples.append(at+facing(direction)*OFFSET)
 # An enclosed void can fit between all four bed corners: test its boundary too.
 for hole:PackedVector2Array in Geometry.floor_holes(spec,size):
  for point:Vector2 in hole:
   if Geometry2D.is_point_in_polygon(point,bed):return false
 for p:Vector2 in samples:
  if Geometry.inside_floor(spec,size,p,.025 if spec.has("floor_polygon_m") else .15):continue
  var opening:bool=false
  for portal in portals:
   var mouth:Vector2=portal.at;var inward:Vector2=portal.inward;var offset:Vector2=p-mouth
   if offset.dot(inward)<=.35 and offset.dot(inward)>=-2.5 and absf(offset.cross(inward))<=float(portal.get("width_m",1.2))*.5-.03:opening=true;break
  if not opening:return false
 return true

static func clear(space,at:Vector2,direction:Vector2,portals:Array=[]) -> bool:
 if not contained(space,at,direction,portals):return false
 for f in space.furniture:
  if not f.get("solid",true) or not f.get("collision",true):continue
  for rect:Rect2 in f.get("collision_rects",[f.rect]):
   if overlaps_rect(at,direction,rect.grow(.025)):return false
 # Layouts may keep architectural partitions and solid decorative pieces in
 # separate collections. The bed uses the same real footprints as people;
 # a non-solid rug or the bounding box around two seat banks is not a wall.
 for property:Dictionary in space.get_property_list():
  if str(property.name) in ["walls","static_walls"]:
   for value in space.get(property.name):
    if value is Dictionary and (not value.get("solid",true) or not value.get("collision",true)):continue
    var rect:Rect2=value.rect if value is Dictionary else value
    if overlaps_rect(at,direction,rect.grow(.025)):return false
  elif str(property.name)=="decor":
   for f:Dictionary in space.get("decor"):
    if not f.get("solid",true) or not f.get("collision",true):continue
    for rect:Rect2 in f.get("collision_rects",[f.rect]):
     if overlaps_rect(at,direction,rect.grow(.025)):return false
 for rect in space.movable_blockers:
  if overlaps_rect(at,direction,rect.grow(.025)):return false
 return true

static func sweep(space,from:Vector2,to:Vector2,old_direction:Vector2,new_direction:Vector2,portals:Array=[]) -> Dictionary:
 var start:Vector2=facing(old_direction);var finish:Vector2=facing(new_direction)
 var turn:float=start.angle_to(finish)
 # The furthest corner moves at most 2.3cm per sample, including rotation.
 var steps:int=maxi(1,ceili((from.distance_to(to)+absf(turn)*2.0)/.023))
 var at:Vector2=from;var direction:Vector2=start;var poses:Array=[]
 for i in range(steps+1):
  var t:float=float(i)/steps;var next:Vector2=from.lerp(to,t);var next_direction:Vector2=start.rotated(turn*t)
  if not clear(space,next,next_direction,portals):return {"position":at,"direction":direction,"complete":false,"poses":poses}
  at=next;direction=next_direction;poses.append({"at":at,"direction":direction})
 return {"position":at,"direction":direction,"complete":true,"poses":poses}
