extends "res://scripts/world/room_layout.gd"
## L1 geometry v2: metre-based whitebox, not an approved art layout.
## Repeated _init calls rebuild navigation without resetting moved furniture.
const SPACE_DATA_PATH:String="res://data/room_spaces.json"
var config:Dictionary={}
var projection_origin:=Vector2(180,270)
var projection_x:float=96.0
var projection_depth:=Vector2(30,56)
var height_pixels_per_m:float=78.0
var wall_thickness_m:float=0.15
var door_width_m:float=0.95
var door_height_m:float=2.15
var _configured:bool=false

func _init() -> void:
 if not _configured:
  var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(SPACE_DATA_PATH))
  assert(document is Dictionary and document.has("rooms"),"Missing room-space configuration")
  config=document.rooms.bedroom.duplicate(true)
  geometry_version=int(config.geometry_version)
  bounds_size=_v2(config.size_m)
  body_radius=float(config.body_radius_m)
  door_anchor=_v2(config.anchors.door)
  bed_anchor=_v2(config.anchors.bed)
  cat_exit_anchor=_v2(config.anchors.cat_exit)
  projection_origin=_v2(config.projection.origin_px)
  projection_x=float(config.projection.x_px_per_m)
  projection_depth=_v2(config.projection.depth_px_per_m)
  height_pixels_per_m=float(config.projection.height_px_per_m)
  wall_thickness_m=float(config.wall.thickness_m)
  door_width_m=float(config.door.clear_width_m)
  door_height_m=float(config.door.height_m)
  furniture.clear()
  for source:Dictionary in config.furniture:
   var item:Dictionary=source.duplicate(true)
   var dimensions:Array=source.rect_m
   item.rect=Rect2(float(dimensions[0]),float(dimensions[1]),float(dimensions[2]),float(dimensions[3]))
   item.at=_v2(source.approach_m)
   item.height=float(source.height_m)*height_pixels_per_m
   item.color=Color(str(source.color))
   furniture.append(item)
  _configured=true
 rebuild_grid()

func project(point:Vector2) -> Vector2:
 return projection_origin+Vector2(projection_x*point.x+projection_depth.x*point.y,projection_depth.y*point.y)

func unproject(point:Vector2) -> Vector2:
 var local:=point-projection_origin
 var depth:float=local.y/projection_depth.y
 return Vector2((local.x-projection_depth.x*depth)/projection_x,depth)

func project_at_height(point:Vector2,height_m:float) -> Vector2:
 return project(point)-Vector2(0,height_m*height_pixels_per_m)

func _v2(value:Array) -> Vector2:
 return Vector2(float(value[0]),float(value[1]))
