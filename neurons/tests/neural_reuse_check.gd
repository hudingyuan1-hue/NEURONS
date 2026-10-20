extends SceneTree
## Read-only production-data probe. Candidate geometry exists only in memory.
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const Map=preload("res://scripts/core/cortex_map.gd")
const BMap=preload("res://scripts/core/combat_map.gd")
const Bed=preload("res://scripts/core/bed_body.gd")
var rows:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for room:String in Map.ALL_ROOMS:
  var source=Cortex.new(room,2)
  var layout=Combat.new(room,true,3)
  var runtime_contract:bool="--runtime-contract" in OS.get_cmdline_user_args()
  if not runtime_contract:
   layout.metric_spec=source.space_spec();layout.metric_spec.chapter=5;layout.metric_spec.geometry_version=3
   for portal:Dictionary in layout.metric_spec.portals:
    if portal.toward=="combat_exit":portal.toward="hippocampus"
   layout.bounds_size=source.world_size();layout.furniture.clear();layout.decor.clear()
   for value:Dictionary in layout.metric_spec.furniture+layout.metric_spec.get("partitions",[]):layout.furniture.append(layout.metric_item(value))
   for value:Dictionary in layout.metric_spec.get("decor",[]):layout.decor.append(layout.metric_item(value))
   layout.rebuild_grid()
  var row:Dictionary={"room":room,"size_m":[layout.world_size().x,layout.world_size().y],"routes":[],"bed_entries":[],"passing":[]}
  if runtime_contract:
   row.same_base=true
   for key:String in ["size_m","spawn_m","wall_thickness_m","wall_height_m","furniture","partitions","decor","floor_polygon_m","wall_ranges_m"]:
    if layout.space_spec().get(key)!=source.space_spec().get(key):row.same_base=false;failures.append(room+" shared base differs "+key)
   var cportals:Array=source.space_spec().portals.duplicate(true)
   var bportals:Array=layout.space_spec().portals.duplicate(true)
   for portal:Dictionary in bportals:
    if portal.toward=="hippocampus":portal.toward="combat_exit"
   if cportals!=bportals:row.same_base=false;failures.append(room+" shared portal geometry differs")
  var portals:Array=[]
  for portal:Dictionary in layout.metric_spec.portals:portals.append(layout.portal(str(portal.toward)))
  for a:Dictionary in portals:
   for b:Dictionary in portals:
    if a.toward==b.toward:continue
    var route:PackedVector2Array=layout.path(a.landing,b.at)
    row.routes.append({"from":a.toward,"to":b.toward,"reachable":not route.is_empty(),"distance_m":path_length(route)})
    if route.is_empty():failures.append(room+" no body route "+str(a.toward)+" to "+str(b.toward))
   var spawn:Vector2=a.landing+Vector2(a.inward)*.8
   var entry:Dictionary={"toward":a.toward,"landing_clear":Bed.clear(layout,a.landing,a.inward,portals),"spawn_clear":Bed.clear(layout,spawn,a.inward,portals),"precise_landing_clear":precise_bed_clear(layout,a.landing,a.inward,portals),"precise_spawn_clear":precise_bed_clear(layout,spawn,a.inward,portals)}
   entry.actual_entry_sweep_complete=Bed.sweep(layout,a.landing,spawn,a.inward,a.inward,portals).complete
   if not entry.precise_landing_clear or not entry.precise_spawn_clear:entry.nearest_same_wall=nearest_entry(layout,a,portals)
   row.bed_entries.append(entry)
   if runtime_contract and (not entry.landing_clear or not entry.spawn_clear):failures.append(room+" bed entry blocked "+str(a.toward))
   if runtime_contract and not entry.actual_entry_sweep_complete:failures.append(room+" actual bed entry sweep blocked "+str(a.toward))
   var blocker:Vector2=a.landing+Vector2(a.inward)*1.2
   var passing:bool=true
   if layout.walkable(blocker) and blocker.distance_to(layout.spawn())>.6:
    passing=not layout.path_around_bodies(layout.spawn(),a.at,[{"pos":blocker,"radius":.47}]).is_empty()
   row.passing.append({"toward":a.toward,"one_actor_route":passing})
  rows.append(row)
 var before_path:String="res://../docs/validation/neural_spaces_20261018/reuse_correction/before_neural_spaces.json"
 if "--runtime-contract" in OS.get_cmdline_user_args():
  var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(before_path))
  var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/neural_spaces.json"))
  for room:String in BMap.DEEP:
   if before.rooms["L5:"+room]!=after.rooms["L5:"+room]:failures.append("deep structure changed "+room)
  var old=Combat.new("atrium",true,2)
  if old.world_size()!=Vector2(11.2,7.6) or old.portal("decision").at!=Vector2(5.6,.48):failures.append("legacy L5v2 size/door moved")
 var folder:String="res://../docs/validation/neural_spaces_20261018/reuse_probe"
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--validation-root="):folder=argument.trim_prefix("--validation-root=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"Read-only data probe: L4 actual metre contract copied into in-memory L5 layout; real Godot full-radius door routes, one-actor passing and original oriented bed entry geometry. No production file rewrite or actual AI acceptance."},"  "));file.close()
 print("NEURAL_REUSE ",rows.size()," rooms / ",failures.size()," route failures")
 for row:Dictionary in rows:
  for entry:Dictionary in row.bed_entries:
   if not entry.landing_clear or not entry.spawn_clear:print("BED_CONSTRAINT ",row.room," ",entry)
 quit(0 if failures.is_empty() else 1)
func path_length(points:PackedVector2Array) -> float:
 var distance:float=0
 for index in range(1,points.size()):distance+=points[index-1].distance_to(points[index])
 return distance

func precise_bed_clear(space,at:Vector2,direction:Vector2,portals:Array) -> bool:
 var size:Vector2=space.world_size()
 for point:Vector2 in Bed.polygon(at,direction):
  if point.x>=.15 and point.y>=.15 and point.x<=size.x-.15 and point.y<=size.y-.15:continue
  var opening:bool=false
  for mouth:Dictionary in portals:
   var offset:Vector2=point-mouth.at
   if offset.dot(mouth.inward)<=.35 and offset.dot(mouth.inward)>=-2.5 and absf(offset.cross(mouth.inward))<=float(mouth.width_m)*.5-.03:opening=true;break
  if not opening:return false
 for item:Dictionary in space.furniture+space.decor:
  if not item.get("solid",true):continue
  for rect:Rect2 in space.collision_rects(item):
   if Bed.overlaps_rect(at,direction,rect.grow(.025)):return false
 return true

func nearest_entry(space,old:Dictionary,portals:Array) -> Dictionary:
 var horizontal:bool=str(old.wall) in ["north","south"]
 var length:float=space.world_size().x if horizontal else space.world_size().y
 var choices:Array=[]
 for i in range(8,floori((length-.8)/.1)+1):
  var coordinate:float=float(i)*.1
  var at:Vector2=old.at
  if horizontal:at.x=coordinate
  else:at.y=coordinate
  choices.append({"at":at,"distance":at.distance_to(old.at)})
 choices.sort_custom(func(a,b):return float(a.distance)<float(b.distance))
 for choice:Dictionary in choices:
  var at:Vector2=choice.at
  var new:Dictionary=old.duplicate(true);new.at=at;new.landing=at+Vector2(old.inward)*.38
  var revised:Array=[]
  for mouth:Dictionary in portals:revised.append(new if mouth.toward==old.toward else mouth)
  var conflict:bool=false
  for other:Dictionary in revised:
   if other.toward!=new.toward and other.wall==new.wall and Vector2(other.at).distance_to(at)<1.5:conflict=true
  if conflict:continue
  if not space.walkable(new.landing) or space.path(space.spawn(),new.landing).is_empty():continue
  if not precise_bed_clear(space,new.landing,new.inward,revised) or not precise_bed_clear(space,new.landing+Vector2(new.inward)*.8,new.inward,revised):continue
  return {"at_m":[at.x,at.y],"distance_m":choice.distance,"wall":new.wall}
 return {}
