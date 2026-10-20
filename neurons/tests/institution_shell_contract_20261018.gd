extends SceneTree
## Spatial audit against real runtime layouts. Does not alter game saves,
## source events, key probabilities or imported art.
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const BedroomView=preload("res://scripts/world/metric_bedroom_view.gd")
const InstitutionView=preload("res://scripts/world/metric_institution_view.gd")
var passes:Array=[]
var failures:Array=[]
var rooms:Array=[]
var output:String="res://../docs/validation/spatial_institution_20261018/contract"

func verify(ok:bool,label:String) -> void:
 (passes if ok else failures).append(label)
 if not ok:print("FAIL "+label)

func _initialize() -> void:
 call_deferred("run")

func test_room(id:String,layout,starts:Array) -> void:
 var spec:Dictionary=layout.config
 var size:Vector2=layout.world_size()
 var display:Dictionary=spec.wall.get("display",{})
 verify(layout.geometry_version==2,id+": retains versioned metre geometry")
 verify(bool(display.get("logical_full_height",false)) and float(spec.wall.height_m)>2.1,id+": full four-wall architecture is independent of near-wall visibility")
 verify(float(display.get("occluded_alpha",1))<float(display.get("near_alpha",0)) and float(display.get("near_alpha",1))<.3,id+": near-wall fade preserves actor/action visibility")
 verify(is_equal_approx(layout.project(Vector2(1,0)).x-layout.project(Vector2.ZERO).x,96),id+": shared world-pixel scale")
 verify((layout.unproject(layout.project(size*.43))-size*.43).length()<.00001,id+": exact floor projection inverse")
 var approach_rows:Array=[]
 for item:Dictionary in layout.furniture:
  var at:Vector2=item.at
  var reachable:bool=layout.walkable(at)
  var paths:Array=[]
  for start:Vector2 in starts:
   var route:PackedVector2Array=layout.path(start,at)
   var legal:bool=not route.is_empty()
   for i in range(1,route.size()):legal=legal and layout.clear_segment(route[i-1],route[i],layout.body_radius)
   reachable=reachable and legal
   paths.append({"from":[start.x,start.y],"points":route.size(),"legal":legal})
  verify(reachable,id+": source search/action approach reachable "+str(item.get("id",item.get("name",""))))
  if str(item.get("kind",""))=="window":
   verify(str(item.get("wall_mount","")) in ["north","south","east","west"] and float(item.get("sill_height_m",0))+float(item.get("opening_height_m",0))<=float(spec.wall.height_m),id+": wall-mounted window and opening fit actual wall height "+str(item.id))
  approach_rows.append({"id":item.get("id",item.get("name","")),"rect_m":[item.rect.position.x,item.rect.position.y,item.rect.size.x,item.rect.size.y],"approach_m":[at.x,at.y],"height_m":item.get("height_m",0),"paths":paths})
 rooms.append({"room":id,"size_m":[size.x,size.y],"furniture":approach_rows,"wall":spec.wall})

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):output=arg.trim_prefix("--validation-root=")
 var bedroom=Bedroom.new()
 test_room("bedroom",bedroom,[bedroom.door_position(),bedroom.bed_position()])
 var document:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/institution_spaces.json"))
 for id:String in document.rooms:
  var room=Institution.new(id,3)
  var starts:Array=[]
  for portal:Dictionary in room.portals:
   starts.append(portal.landing)
   verify(room.walkable(portal.landing) and room.walkable(portal.threshold),id+": real portal landing and threshold are walkable toward "+str(portal.toward))
   verify(room.clear_segment(portal.threshold,portal.landing,room.body_radius),id+": actual doorway inward route remains unobstructed toward "+str(portal.toward))
  test_room(id,room,starts)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var file=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"rooms":rooms,"scope":"Runtime-layout projection, original source search/action approaches, all real portal paths and full-wall visibility contract. No normal-play, formal-art or subjective aesthetic acceptance."},"  "))
 file.close()
 print("INSTITUTION_SHELL_CONTRACT %d passed %d failed"%[passes.size(),failures.size()])
 quit(0 if failures.is_empty() else 1)
