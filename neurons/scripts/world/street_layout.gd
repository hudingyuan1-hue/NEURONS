extends "res://scripts/world/combat_layout.gd"
const StreetMap=preload("res://scripts/core/street_map.gd")
const BedShape=preload("res://scripts/core/bed_body.gd")
var oriented_beds:Array=[]
var portal_width_m:float=1.4
var spatial_config:Dictionary={}
var floor_polygon_m:Array=[]

func walkable(point:Vector2,radius:float=-1.0) -> bool:
 if radius<0:radius=body_radius
 if not SpatialGeometry.inside_floor(spatial_config,world_size(),point,radius):return false
 if not super.walkable(point,radius):return false
 for pose in oriented_beds:
  if BedShape.touches(pose.at,pose.axis,point,radius):return false
 return true

func clear_segment(from:Vector2,to:Vector2,radius:float=0.0) -> bool:
 if radius<0:radius=body_radius
 if not SpatialGeometry.segment_inside_floor(spatial_config,world_size(),from,to,radius):return false
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

func _init(room:String="street_plaza",revision:int=SpatialRevision.CURRENT) -> void:
 spatial_revision=revision
 room_id=room;geometry_version=3;bounds_size=StreetMap.SIZES[room];body_radius=.21
 furniture.clear();movable_blockers.clear();rack_rect=Rect2();cold_zone=Rect2()
 # The same measured geometry supplies navigation, drawing and art templates.
 # Keep actors, attack rules and stable prop IDs in the chapter configuration.
 var all_spaces:Dictionary=SpatialRevision.document("street_spaces.json",revision)
 spatial_config=all_spaces.rooms[room].duplicate(true)
 bounds_size=Vector2(float(spatial_config.size_m[0]),float(spatial_config.size_m[1]))
 floor_polygon_m=spatial_config.get("floor_polygon_m",[]).duplicate(true)
 decor.clear()
 for entry in spatial_config.props:
  var a:Array=entry.rect
  var f:Dictionary=prop(str(entry.name),Rect2(a[0],a[1],a[2],a[3]),float(entry.height_m),str(entry.get("kind","cabinet")))
  f.id=str(entry.id)
  f.height_m=float(entry.height_m);f.solid=bool(entry.get("solid",true))
  for field:String in ["render","collision","footprint_shape","silhouette_note","rect_meaning"]:
   if entry.has(field):f[field]=entry[field]
  f.source=str(entry.get("source",spatial_config.source))
  f.anchor="footprint_center";f.render_layer="independent_prop"
  if entry.get("solid",true):furniture.append(f)
  else:decor.append(f)
 rebuild_grid()
 for item:Dictionary in furniture+decor:
  item.approaches=[]
  var rect:Rect2=item.rect
  var candidates:Array=[{"at":Vector2(rect.get_center().x,rect.end.y+.5),"facing":Vector2.UP},{"at":Vector2(rect.get_center().x,rect.position.y-.5),"facing":Vector2.DOWN},{"at":Vector2(rect.position.x-.5,rect.get_center().y),"facing":Vector2.RIGHT},{"at":Vector2(rect.end.x+.5,rect.get_center().y),"facing":Vector2.LEFT}]
  for candidate:Dictionary in candidates:
   if walkable(candidate.at):item.approaches.append(candidate)
func portal(toward:String) -> Dictionary:
 var result:Dictionary=StreetMap.doorway_spec(room_id,toward,spatial_revision)
 if not result.is_empty():result.width_m=portal_width_m
 return result
func spawn() -> Vector2:
 var at:Array=spatial_config.get("spawn_m",[1.3,world_size().y*.5])
 return Vector2(float(at[0]),float(at[1]))

func space_spec() -> Dictionary:
 var result:Dictionary=spatial_config.duplicate(true)
 result.portals=[]
 for destination in StreetMap.doors(room_id):result.portals.append(portal(str(destination)))
 result.logical_boundary=SpatialGeometry.floor_polygon(spatial_config,world_size())
 result.furniture=furniture.duplicate(true);result.decor=decor.duplicate(true)
 result.contact_policy="No search/key/rest. Export prop footprints and reachable approach positions only; action contacts remain owned by gameplay."
 return result
