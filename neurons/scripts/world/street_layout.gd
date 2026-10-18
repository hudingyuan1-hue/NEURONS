extends "res://scripts/world/combat_layout.gd"
const StreetMap=preload("res://scripts/core/street_map.gd")
const BedShape=preload("res://scripts/core/bed_body.gd")
var oriented_beds:Array=[]
var portal_width_m:float=1.4

func walkable(point:Vector2,radius:float=-1.0) -> bool:
 if radius<0:radius=body_radius
 if not super.walkable(point,radius):return false
 for pose in oriented_beds:
  if BedShape.touches(pose.at,pose.axis,point,radius):return false
 return true

func clear_segment(from:Vector2,to:Vector2,radius:float=0.0) -> bool:
 if radius<0:radius=body_radius
 if not super.clear_segment(from,to,radius):return false
 for pose in oriented_beds:
  var axis:Vector2=BedShape.facing(pose.axis);var center:Vector2=Vector2(pose.at)+axis*BedShape.OFFSET
  var a:=Vector2((from-center).dot(axis),(from-center).cross(axis));var b:=Vector2((to-center).dot(axis),(to-center).cross(axis))
  var length:float=BedShape.HALF_LENGTH;var width:float=BedShape.HALF_WIDTH
  # Exact rectangle + circular body: two strips and four rounded corners.
  # Endpoint-only checks let path smoothing cut through a rotated bed.
  if segment_hits_rect(a,b,Rect2(-length,-width-radius,2*length,2*(width+radius))) or segment_hits_rect(a,b,Rect2(-length-radius,-width,2*(length+radius),2*width)):return false
  for x in [-length,length]:
   for y in [-width,width]:
    var corner:=Vector2(x,y)
    if Geometry2D.get_closest_point_to_segment(corner,a,b).distance_squared_to(corner)<=radius*radius+.0000001:return false
 return true

func _init(room:String="street_plaza") -> void:
 room_id=room;geometry_version=2;bounds_size=StreetMap.SIZES[room];body_radius=.21
 furniture.clear();movable_blockers.clear();rack_rect=Rect2();cold_zone=Rect2()
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/street_chapter.json"))
 for entry in data.rooms[room].props:
  var a:Array=entry.rect
  var f:Dictionary=prop(str(entry.name),Rect2(a[0],a[1],a[2],a[3]),float(entry.height),str(entry.get("kind","cabinet")))
  f.id=str(entry.id)
  if entry.get("solid",true):furniture.append(f)
  else:decor.append(f)
 rebuild_grid()
func portal(toward:String) -> Dictionary:
 var at:Vector2=StreetMap.doorway(room_id,toward);var size:Vector2=world_size()
 if at.x<0:return {}
 var inward:Vector2=Vector2.RIGHT if at.x<1 else Vector2.LEFT if at.x>size.x-1 else Vector2.DOWN
 return {"at":at,"threshold":at-inward*.23,"landing":at+inward*.38,"inward":inward,"toward":toward,"width_m":portal_width_m,"height_m":2.2}
func spawn() -> Vector2:return Vector2(1.3,world_size().y*.5)
