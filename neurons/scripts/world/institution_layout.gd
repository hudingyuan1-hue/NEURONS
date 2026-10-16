extends "res://scripts/world/room_layout.gd"
## Metre-based hospital/shared lower-asylum rooms and the existing stair space.
## Configuration is a technical layout trial, not an approved visual design.
const SPACE_DATA_PATH:String="res://data/institution_spaces.json"
var config:Dictionary={}
var room_id:String="lobby"
var phase_level:int=2
var projection_origin:=Vector2(180,270)
var projection_x:float=96.0
var projection_depth:=Vector2(30,56)
var height_pixels_per_m:float=78.0
var wall_thickness_m:float=0.15
var decor:Array[Dictionary]=[]
var static_walls:Array[Dictionary]=[]
var portals:Array[Dictionary]=[]
var _configured:bool=false

func _init(room:String="lobby",level:int=2) -> void:
 if not _configured:
  var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(SPACE_DATA_PATH))
  assert(document is Dictionary and document.get("rooms",{}).has(room),"Unknown institution room: "+room)
  room_id=room;phase_level=level
  config=document.rooms[room].duplicate(true)
  geometry_version=int(config.geometry_version)
  bounds_size=_v2(config.size_m)
  body_radius=float(document.body_radius_m)
  projection_origin=_v2(document.projection.origin_px)
  projection_x=float(document.projection.x_px_per_m)
  projection_depth=_v2(document.projection.depth_px_per_m)
  height_pixels_per_m=float(document.projection.height_px_per_m)
  wall_thickness_m=float(config.wall.thickness_m)
  furniture.clear()
  for source:Dictionary in config.furniture:furniture.append(_item(source))
  for source:Dictionary in config.get("decor",[]):
   if source.has("levels") and not _level_allowed(source.levels):continue
   decor.append(_item(source))
  for source:Dictionary in config.get("static_walls",[]):static_walls.append(_item(source))
  for source:Dictionary in config.portals:
   var value:Dictionary=source.duplicate(true)
   for key:String in ["wall_point","at","threshold","inward","landing"]:value[key]=_v2(source[key])
   portals.append(value)
  door_anchor=portals[0].at
  bed_anchor=get_anchor("bed") if config.anchors.has("bed") else get_anchor("spawn")
  _configured=true
 # Existing callers rebuild navigation after changing blockers by calling _init.
 # Do not reload the room or reset moved furniture on that call.
 rebuild_grid()

func get_anchor(name:String) -> Vector2:
 return _v2(config.anchors[name]) if config.get("anchors",{}).has(name) else Vector2.INF

func portal(toward:String) -> Dictionary:
 for value:Dictionary in portals:
  if str(value.toward)==toward:return value.duplicate(true)
 return {}

func candidate_count() -> int:
 return int(config.get("search_counts",{}).get(str(phase_level),0))

func project(point:Vector2) -> Vector2:
 return projection_origin+Vector2(projection_x*point.x+projection_depth.x*point.y,projection_depth.y*point.y)

func unproject(point:Vector2) -> Vector2:
 var local:=point-projection_origin
 var depth:float=local.y/projection_depth.y
 return Vector2((local.x-projection_depth.x*depth)/projection_x,depth)

func project_at_height(point:Vector2,height_m:float) -> Vector2:
 return project(point)-Vector2(0,height_m*height_pixels_per_m)

func walkable(point:Vector2,radius:float=-1.0) -> bool:
 if radius<0.0:radius=body_radius
 if not Rect2(Vector2.ONE*radius,world_size()-Vector2.ONE*radius*2.0).has_point(point):return false
 for item:Dictionary in furniture:
  if bool(item.get("collision",true)) and (item.rect as Rect2).grow(radius).has_point(point):return false
 for item:Dictionary in decor:
  if bool(item.get("collision",true)) and (item.rect as Rect2).grow(radius).has_point(point):return false
 for item:Dictionary in static_walls:
  if (item.rect as Rect2).grow(radius).has_point(point):return false
 for rect:Rect2 in movable_blockers:
  if rect.grow(radius).has_point(point):return false
 return true

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 if radius<0.0:radius=body_radius
 if not walkable(a,radius) or not walkable(b,radius):return false
 # Point sampling can miss a very short crossing of an inflated cabinet corner.
 # Navigation and each real movement step must use the same continuous test.
 for items:Array in [furniture,decor,static_walls]:
  for item:Dictionary in items:
   if bool(item.get("collision",true)) and _crosses_rect(a,b,(item.rect as Rect2).grow(radius)):return false
 for rect:Rect2 in movable_blockers:
  if _crosses_rect(a,b,rect.grow(radius)):return false
 return true

func _crosses_rect(a:Vector2,b:Vector2,rect:Rect2) -> bool:
 var corners:Array[Vector2]=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
 for index:int in range(4):
  if Geometry2D.segment_intersects_segment(a,b,corners[index],corners[(index+1)%4])!=null:return true
 return false

func _level_allowed(levels:Array) -> bool:
 for level:Variant in levels:
  if int(level)==phase_level:return true
 return false

func _item(source:Dictionary) -> Dictionary:
 var value:Dictionary=source.duplicate(true)
 var dimensions:Array=source.rect_m
 value.rect=Rect2(float(dimensions[0]),float(dimensions[1]),float(dimensions[2]),float(dimensions[3]))
 value.at=_v2(source.get("approach_m",[value.rect.get_center().x,value.rect.get_center().y]))
 value.height=float(source.get("height_m",0.0))*height_pixels_per_m
 value.color=Color(str(source.get("color","8d9d95")))
 return value

func _v2(value:Array) -> Vector2:
 return Vector2(float(value[0]),float(value[1]))
