extends SceneTree
## Geometry-only checks. No visual, NPC pairing, story or normal-play claim.
const Legacy=preload("res://scripts/world/room_layout.gd")
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Asylum=preload("res://scripts/world/asylum_layout.gd")
const AsylumMap=preload("res://scripts/core/asylum_map.gd")
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const CortexMap=preload("res://scripts/core/cortex_map.gd")
const Hidden=preload("res://scripts/world/hidden_layout.gd")
var checks:int=0
var failed:int=0
var failures:Array[String]=[]

func _init() -> void:
 var layout=Bedroom.new()
 var legacy=Legacy.new()
 check(legacy.geometry_version==1 and legacy.world_size()==Legacy.SIZE,"legacy dimensions retained")
 check(legacy.door_position()==Legacy.DOOR and legacy.bed_position()==Legacy.BED_STOP,"legacy anchors retained")
 check(legacy.body_radius==Legacy.RADIUS and legacy.grid.region.size==Vector2i(57,39),"legacy footprint and grid retained")
 check(layout.geometry_version==2 and layout.world_size().is_equal_approx(Vector2(6.4,4.8)),"bedroom independent dimensions")
 check(layout.grid.region.size==Vector2i(65,49),"metre grid covers new bounds without float off-by-one")
 check(is_equal_approx(layout.body_radius,0.21),"new navigation footprint")
 check(is_equal_approx(layout.door_width_m,0.95) and is_equal_approx(layout.door_height_m,2.15),"door dimensions distinct from interaction distance")
 check(layout.furniture.size()==11,"eleven source search points retained")
 var ids:Array[String]=["bed","bedside","chair","desk","stool","box","rack","wardrobe","books","storage","fan"]
 var overlaps:Array[String]=[]
 for index:int in range(ids.size()):
  var item:Dictionary=layout.furniture[index]
  check(item.id==ids[index],"stable search index "+ids[index])
  check(is_equal_approx(float(item.height),float(item.height_m)*78.0),"physical height "+ids[index])
  check(Rect2(Vector2.ZERO,layout.world_size()).encloses(item.rect),"furniture inside room "+ids[index])
  for other:int in range(index+1,ids.size()):
   if (item.rect as Rect2).intersects(layout.furniture[other].rect):overlaps.append(ids[index]+"/"+ids[other])
 check(overlaps.is_empty(),"furniture footprints do not overlap: "+str(overlaps))
 check((layout.furniture[0].rect as Rect2).size.is_equal_approx(Vector2(2.05,1.0)),"single bed dimensions")
 check(is_equal_approx(float(layout.furniture[8].height_m),1.6),"source five-layer shelf height")
 check(not layout.walkable(Vector2(2.5,0.85)) and layout.walkable(Vector2(2.5,0.85),0.0),"navigation radius does not replace zero-radius LOS")
 check(not layout.walkable(Vector2(6.3,2.0)) and layout.walkable(Vector2(5.0,2.15)),"new bounds and obstacle clearance are independent")
 verify_projection(layout)
 verify_routes(layout,"initial")
 # Replan toward an actor who is moving around the coat-rack corner. The
 # former nearest-cell start repeatedly walked backward and never arrived.
 var moving_from:Vector2=Vector2(4.707867,1.2)
 var moving_to:Vector2=Vector2(5.065354,0.834646)
 for tick in range(150):
  var dynamic_route:PackedVector2Array=layout.path(moving_from,moving_to)
  moving_from=layout.move_path(moving_from,dynamic_route,1.0/60.0).position
 check(moving_from.distance_to(moving_to)<0.02,"per-frame repath follows moving contact around a real cabinet corner")
 var chair:Dictionary=layout.furniture[2]
 var chair_start:Rect2=chair.rect
 var chair_shift:Vector2=v2(chair.action_offsets.shift)
 chair.rect=Rect2(chair_start.position+chair_shift,chair_start.size)
 var box:Dictionary=layout.furniture[5]
 var base:Rect2=box.rect
 var upper:Rect2=Rect2(base.position+v2(box.action_offsets.upper_shift),base.size)
 layout.movable_blockers.append(upper)
 layout._init()
 check((layout.furniture[2].rect as Rect2).position.is_equal_approx(chair_start.position+chair_shift),"compatibility _init preserves moved chair")
 check(layout.movable_blockers.size()==1 and layout.movable_blockers[0]==upper,"compatibility _init preserves moved upper box")
 check(not layout.walkable(upper.get_center()),"moved upper box blocks real floor space")
 verify_routes(layout,"moved")
 # A route created before a new blocker may never walk through that blocker.
 var start:=Vector2(3.0,2.1)
 var finish:=Vector2(4.5,2.1)
 var stale:PackedVector2Array=layout.path(start,finish)
 layout.movable_blockers.append(Rect2(3.6,1.85,0.25,0.5))
 var blocked:Dictionary=layout.move_path(start,stale,3.0)
 check((blocked.position as Vector2).distance_to(finish)>0.1,"stale route cannot cross a new blocker")
 check(layout.walkable(blocked.position),"blocked move retains a legal position")
 layout.rebuild_grid()
 verify_route(layout,start,finish,"new blocker detour")
 verify_legacy_children()
 for label:String in failures:print("FAIL "+label)
 print("NEURONS bedroom geometry v2: %d checks, %d failures"%[checks,failed])
 for arg:String in OS.get_cmdline_user_args():
  if not arg.begins_with("--result="):continue
  var output:String=arg.trim_prefix("--result=")
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
  var file:=FileAccess.open(output,FileAccess.WRITE)
  file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"passed":checks-failed,"failed":failed,"failures":failures,"scope":"Headless real geometry/navigation/move_path; all new L1 targets before and after furniture moves; legacy layouts remain v1. No GPU, NPC pairing, artwork or normal-play acceptance."},"  "))
  file.close()
 quit(1 if failed else 0)

func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failed+=1;failures.append(label)

func v2(value:Array) -> Vector2:
 return Vector2(float(value[0]),float(value[1]))

func verify_legacy_children() -> void:
 for room:String in AsylumMap.UPPER_ROOMS:
  var layout=Asylum.new(room)
  check(layout.geometry_version==1 and layout.world_size()==Legacy.SIZE,"asylum legacy bounds "+room)
  check(layout.geometry_issues().is_empty(),"asylum inherited navigation "+room)
 for room:String in CortexMap.ALL_ROOMS:
  var layout=Cortex.new(room)
  check(layout.geometry_version==1 and layout.world_size()==Legacy.SIZE,"cortex legacy bounds "+room)
  check(layout.geometry_issues().is_empty(),"cortex inherited navigation "+room)
 var hidden=Hidden.new()
 check(hidden.geometry_version==1 and hidden.world_size()==Legacy.SIZE,"hidden street legacy bounds")
 verify_route(hidden,Hidden.ENTRY,Hidden.EXIT,"hidden street inherited navigation")

func verify_projection(layout) -> void:
 var origin:Vector2=layout.project(Vector2.ZERO)
 check(origin.is_equal_approx(Vector2(180,270)),"1280 viewport projection origin")
 check((layout.project(Vector2.RIGHT)-origin).is_equal_approx(Vector2(96,0)),"one metre along x")
 check((layout.project(Vector2.DOWN)-origin).is_equal_approx(Vector2(30,56)),"one metre along depth")
 check((origin-layout.project_at_height(Vector2.ZERO,1.75)).is_equal_approx(Vector2(0,136.5)),"adult visual ruler is 1.75m without assigning identity")
 var worst:float=0.0
 for y:int in range(49):
  for x:int in range(65):
   var p:=Vector2(x,y)*0.1
   for zoom:float in [0.8,1.0,1.3]:
    var offset:=Vector2(-61,27)
    var screen:Vector2=layout.project(p)*zoom+offset
    worst=maxf(worst,p.distance_to(layout.unproject((screen-offset)/zoom)))
 check(worst<0.00001,"projection inverse remains accurate at supported zooms")

func verify_routes(layout,phase:String) -> void:
 var points:Array[Vector2]=[layout.door_position(),layout.bed_position(),layout.cat_exit_position()]
 var labels:Array[String]=["door","bed_stop","cat_window"]
 for item:Dictionary in layout.furniture:
  points.append(item.at);labels.append(item.id)
 for index:int in range(points.size()):
  check(layout.walkable(points[index]),phase+" legal approach "+labels[index])
  for target:int in range(points.size()):
   verify_route(layout,points[index],points[target],phase+" "+labels[index]+" -> "+labels[target])

func verify_route(layout,start:Vector2,finish:Vector2,label:String) -> void:
 var route:PackedVector2Array=layout.path(start,finish)
 check(not route.is_empty(),label+" reachable")
 if route.is_empty():return
 check(route[0].is_equal_approx(start) and route[-1].is_equal_approx(finish),label+" exact endpoints")
 var previous:Vector2=start
 var continuous:bool=true
 for p:Vector2 in route:
  if not layout.clear_segment(previous,p,layout.body_radius):continuous=false;break
  previous=p
 check(continuous,label+" continuous legal footprint")
 var position:Vector2=start
 var remaining:PackedVector2Array=route.duplicate()
 var safe:bool=true
 for tick:int in range(3000):
  if remaining.is_empty():break
  var before:Vector2=position
  var moved:Dictionary=layout.move_path(position,remaining,0.037)
  position=moved.position;remaining=moved.route
  if not layout.walkable(position):safe=false;break
  if before.is_equal_approx(position) and not remaining.is_empty():safe=false;break
 check(safe and remaining.is_empty() and position.is_equal_approx(finish),label+" incremental motion arrives")
