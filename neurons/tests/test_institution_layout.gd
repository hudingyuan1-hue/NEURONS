extends SceneTree
const Institution=preload("res://scripts/world/institution_layout.gd")
const Legacy=preload("res://scripts/world/room_layout.gd")
const Map=preload("res://scripts/core/asylum_map.gd")
const EXPECTED={"ward":Vector2(6.4,4.8),"lobby":Vector2(12,8),"clinic":Vector2(8,6),"pharmacy":Vector2(8,6),"office":Vector2(9,6),"stairs":Vector2(7,5)}
const COUNTS={"ward":0,"lobby":6,"clinic":8,"pharmacy":7,"office":11,"stairs":1}
var passed:int=0
var failed:Array[String]=[]
var routes_checked:int=0

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var layouts:Dictionary={}
 for room:String in EXPECTED:
  for phase:int in ([3] if room=="stairs" else [2,3]):
   var layout=Institution.new(room,phase)
   layouts["%s:%d"%[room,phase]]=layout
   verify_room(layout)
 for room:String in ["ward","lobby","clinic","pharmacy","office"]:
  var first=layouts[room+":2"];var lower=layouts[room+":3"]
  check(first.furniture==lower.furniture and first.portals==lower.portals,room+" preserves lower-floor base geometry across L2/L3")
  if room=="pharmacy":check(first.decor.size()==0 and lower.decor.size()==2,"L3 pharmacy actually adds treatment chair and medicine cart")
 verify_turn(layouts["lobby:2"],"stair_corner_before","stair_corner_after")
 verify_turn(layouts["stairs:3"],"stair_lower","stair_upper")
 verify_observation_indices(layouts)
 var old=Legacy.new()
 check(old.geometry_version==1 and old.world_size()==Vector2(5.6,3.8) and is_equal_approx(old.body_radius,0.14),"legacy geometry remains separate and unchanged")
 var probe=Institution.new("lobby",2)
 var original:Vector2=probe.get_anchor("spawn")
 probe.movable_blockers.append(Rect2(original-Vector2.ONE*0.1,Vector2.ONE*0.2))
 probe._init()
 check(probe.room_id=="lobby" and probe.furniture.size()==6 and not probe.walkable(original),"navigation rebuild preserves room and dynamic blockers")
 check(probe.get_anchor("unknown")==Vector2.INF and probe.portal("unknown").is_empty(),"unknown anchors/portals do not invent a target")
 print(JSON.stringify({"passed":passed,"failed":failed,"routes_checked":routes_checked,"scope":"headless geometry only; actual play and visual acceptance remain separate"}))
 quit(0 if failed.is_empty() else 1)

func verify_room(layout) -> void:
 var label:String="%s L%d"%[layout.room_id,layout.phase_level]
 check(layout.geometry_version==2 and layout.world_size().is_equal_approx(EXPECTED[layout.room_id]),label+" actual configured metre dimensions")
 check(is_equal_approx(layout.body_radius,0.21),label+" adult body radius is 0.21m")
 var expected:int=COUNTS[layout.room_id] if layout.phase_level==2 or layout.room_id=="stairs" else 0
 check(layout.candidate_count()==expected,label+" preserves source search count")
 check(layout.furniture.size()==(8 if layout.room_id=="ward" else COUNTS[layout.room_id]),label+" keeps furniture indices independent of decor")
 check(layout.get_anchor("spawn").is_finite(),label+" spawn configured")
 for point:Vector2 in [Vector2.ZERO,layout.world_size(),layout.world_size()*0.5]:
  check(layout.unproject(layout.project(point)).is_equal_approx(point),label+" projection round trip "+str(point))
 check(layout.project_at_height(Vector2.ONE,1.75).distance_to(layout.project(Vector2.ONE))==136.5,label+" 1.75m adult has 136.5px drawn height")
 var targets:Dictionary={}
 for index:int in range(layout.furniture.size()):
  var item:Dictionary=layout.furniture[index]
  check(item.id=="%s:%d"%[layout.room_id,index],label+" stable furniture index "+str(index))
  check(Rect2(Vector2.ZERO,layout.world_size()).encloses(item.rect),label+" furniture inside net room "+str(index))
  check(float(item.height_m)>0 and is_equal_approx(float(item.height),float(item.height_m)*78),label+" furniture height "+str(index))
  targets["furniture:"+str(index)]=item.at
 for item:Dictionary in layout.decor:
  check(Rect2(Vector2.ZERO,layout.world_size()).encloses(item.rect),label+" decor inside net room "+str(item.id))
  if item.has("approach_m"):targets["decor:"+str(item.id)]=item.at
 for name:String in layout.config.anchors:targets["anchor:"+name]=layout.get_anchor(name)
 var destinations:Array=[]
 for portal:Dictionary in layout.portals:
  destinations.append(str(portal.toward))
  var inward:Vector2=portal.inward;var tangent:=Vector2(inward.y,-inward.x)
  check(is_equal_approx(inward.length(),1) and float(portal.width_m)>=1.2 and float(portal.height_m)>=2.15,label+" doorway dimensions "+str(portal.toward))
  check((portal.at as Vector2).distance_to(portal.threshold)>=0.39 and (portal.wall_point as Vector2).distance_to(portal.threshold)>=0.21,label+" opening phase followed by actual inward-safe threshold "+str(portal.toward))
  for name:String in ["at","threshold","landing"]:targets["portal:"+str(portal.toward)+":"+name]=portal[name]
  verify_route(layout,portal.landing,portal.at,label+" landing to door "+str(portal.toward))
  verify_route(layout,portal.at,portal.threshold,label+" door to threshold "+str(portal.toward))
  for side:float in [-1.0,0.0,1.0]:
   var offset:Vector2=tangent*side*(float(portal.width_m)*0.5-layout.body_radius-0.02)
   check(layout.clear_segment(portal.at+offset,portal.threshold+offset,layout.body_radius),label+" full clear-width entrance "+str(portal.toward)+" side "+str(side))
  for offset:float in [-0.5,0.0,0.5]:
   check(layout.walkable(portal.landing+tangent*offset),label+" incoming actor side slot "+str(portal.toward)+" / "+str(offset))
 check(destinations==Map.GRAPH[layout.room_id],label+" topology and doorway order preserved")
 for name:String in targets:
  check(layout.walkable(targets[name]),label+" legal target "+name)
  if not layout.walkable(targets[name]):continue
  for portal:Dictionary in layout.portals:verify_route(layout,portal.landing,targets[name],label+" "+str(portal.toward)+" to "+name)
 for pair:Dictionary in layout.config.pairs:
  var a:Vector2=layout.get_anchor(str(pair.a));var b:Vector2=layout.get_anchor(str(pair.b));var distance:float=a.distance_to(b)
  check(layout.walkable(a) and layout.walkable(b) and distance>=layout.body_radius*2 and distance<=float(pair.max_distance_m) and layout.clear_segment(a,b),label+" two distinct bodies share real contact pair "+str(pair.id))
 for spec:Dictionary in layout.config.wide_routes:
  var wide=Institution.new(layout.room_id,layout.phase_level)
  wide.body_radius=float(spec.radius_m);wide.rebuild_grid()
  check(wide.body_radius>=0.45,label+" non-shrunken two-body/transport clearance "+str(spec.id))
  verify_route(wide,vec(spec.from),vec(spec.to),label+" wide route "+str(spec.id))

func verify_route(layout,from:Vector2,to:Vector2,label:String) -> void:
 routes_checked+=1
 var route:PackedVector2Array=layout.path(from,to)
 var valid:bool=not route.is_empty() and route[0].is_equal_approx(from) and route[-1].is_equal_approx(to)
 if valid:
  for index:int in range(1,route.size()):
   if not layout.clear_segment(route[index-1],route[index],layout.body_radius):valid=false;break
 check(valid,label+" radius-safe path")
 if not valid:return
 var moving:Vector2=from;var remaining:PackedVector2Array=route
 for step:int in range(1600):
  if moving.distance_to(to)<0.001:break
  var result:Dictionary=layout.move_path(moving,remaining,0.075)
  moving=result.position;remaining=result.route
 check(moving.distance_to(to)<0.001,label+" incremental movement reaches target"+ (" blocked at %s toward %s route %s"%[str(moving),str(to),str(remaining)] if moving.distance_to(to)>=0.001 else ""))

func verify_turn(layout,from_name:String,to_name:String) -> void:
 var a:Vector2=layout.get_anchor(from_name);var b:Vector2=layout.get_anchor(to_name)
 check(not layout.clear_segment(a,b,layout.body_radius),layout.room_id+" real return wall blocks straight shortcut")
 var route:PackedVector2Array=layout.path(a,b)
 check(route.size()>2,layout.room_id+" route includes actual turn")
 verify_route(layout,a,b,layout.room_id+" corner passage")

func verify_observation_indices(layouts:Dictionary) -> void:
 for file:String in ["hospital_observations.json","asylum_observations.json"]:
  var document:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+file))
  var definitions:Array=document.get("targets",document.get("observations",[]))
  check(not definitions.is_empty(),file+" actual observation definitions read")
  for item:Dictionary in definitions:
   var room:String=str(item.get("room",""))
   if not room in EXPECTED or not item.has("furniture_index"):continue
   var phase:int=3 if file.begins_with("asylum") else 2
   if not layouts.has("%s:%d"%[room,phase]):continue
   var layout=layouts["%s:%d"%[room,phase]]
   var index:int=int(item.furniture_index)
   check(index>=0 and index<layout.furniture.size(),file+" referenced furniture exists "+str(item.id))

func check(condition:bool,label:String) -> void:
 if condition:passed+=1
 else:failed.append(label);printerr("FAIL: "+label)

func vec(values:Array) -> Vector2:return Vector2(float(values[0]),float(values[1]))
