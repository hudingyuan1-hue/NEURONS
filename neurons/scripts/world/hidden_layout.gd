extends "res://scripts/world/room_layout.gd"
const NeuralDisplay=preload("res://scripts/world/spatial_presentation.gd")
const SpatialGeometry=preload("res://scripts/world/spatial_geometry.gd")
const SpatialRevision=preload("res://scripts/world/spatial_revision.gd")
var spatial_revision:int=SpatialRevision.CURRENT
## Independent L1 plaza fragment. Saved metre coordinates and E1 threshold
## are retained; pure2D projection now matches the rest of the measured world.
const ENTRY=Vector2(0.6,3.35)
const EXIT=Vector2(5.12,0.42)
var room_id:String="hidden_street"
var spatial_config:Dictionary={}
var decor:Array=[]
var floor_polygon_m:Array=[]

func _init(revision:int=SpatialRevision.CURRENT) -> void:
 spatial_revision=revision
 var all_spaces:Dictionary=SpatialRevision.document("street_spaces.json",revision)
 spatial_config=all_spaces.hidden.duplicate(true)
 geometry_version=3;bounds_size=Vector2(spatial_config.size_m[0],spatial_config.size_m[1])
 floor_polygon_m=spatial_config.get("floor_polygon_m",[]).duplicate(true)
 furniture.clear()
 for entry:Dictionary in spatial_config.props:
  var a:Array=entry.rect;var rect:=Rect2(a[0],a[1],a[2],a[3])
  var item:Dictionary=entry.duplicate(true)
  item.merge({"id":str(entry.id),"name":str(entry.name),"rect":rect,"at":rect.get_center(),"height":float(entry.height_m)*78,"height_m":float(entry.height_m),"color":Color("7e8987"),"kind":str(entry.kind),"solid":true,"anchor":"footprint_center","render_layer":"independent_prop"},true)
  furniture.append(item)
 movable_blockers.clear()
 super._init()
 for item:Dictionary in furniture:
  item.approaches=[]
  var rect:Rect2=item.rect
  for at:Vector2 in [Vector2(rect.get_center().x,rect.end.y+.35),Vector2(rect.position.x-.35,rect.get_center().y),Vector2(rect.end.x+.35,rect.get_center().y)]:
   if walkable(at):item.approaches.append({"at":at,"facing":at.direction_to(rect.get_center())})

func project(p:Vector2) -> Vector2:return NeuralDisplay.project(p,Vector2(70,200))
func unproject(p:Vector2) -> Vector2:return NeuralDisplay.unproject(p,Vector2(70,200))

func portal(toward:String) -> Dictionary:
 for entry:Dictionary in spatial_config.portals:
  if str(entry.toward)!=toward:continue
  var result:Dictionary=entry.duplicate(true)
  for field:String in ["at","wall_point","threshold","landing","inward"]:
   var a:Array=entry[field];result[field]=Vector2(a[0],a[1])
  return result
 return {}

func space_spec() -> Dictionary:
 var result:Dictionary=spatial_config.duplicate(true)
 result.portals=[]
 for destination:String in ["bedroom","E1"]:result.portals.append(portal(destination))
 result.logical_boundary=SpatialGeometry.floor_polygon(spatial_config,world_size())
 result.furniture=furniture.duplicate(true);result.decor=[]
 result.contact_policy="Independent hidden encounter: no search, keys, Street45 or new branch room; entry and real E1 threshold retained."
 return result

func walkable(point:Vector2,radius:float=-1.0) -> bool:
 if radius<0:radius=body_radius
 return SpatialGeometry.inside_floor(spatial_config,world_size(),point,radius) and super.walkable(point,radius)

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 if radius<0:radius=body_radius
 return SpatialGeometry.segment_inside_floor(spatial_config,world_size(),a,b,radius) and super.clear_segment(a,b,radius)

func clipped_step(from:Vector2,to:Vector2,radius:float=RADIUS) -> Vector2:
 var result:Vector2=from
 var steps:int=maxi(1,ceili(from.distance_to(to)/0.02))
 for i in range(1,steps+1):
  var next:Vector2=from.lerp(to,float(i)/steps)
  if not walkable(next,radius) or not clear_segment(result,next,radius):break
  result=next
 return result
