extends SceneTree
## Real layouts/path movement, no combat/ending fixtures or user save writes.
const Street=preload("res://scripts/world/street_layout.gd")
const Map=preload("res://scripts/core/street_map.gd")
const Hidden=preload("res://scripts/world/hidden_layout.gd")
var passed:int=0
var failures:Array=[]
var rooms:Array=[]

func check(ok:bool,label:String) -> void:
 if ok:passed+=1
 else:failures.append(label);push_error(label)

func _initialize() -> void:call_deferred("run")

func run() -> void:
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/street_chapter.json"))
 for id:String in Map.ROOMS:
  var layout=Street.new(id);var spec:Dictionary=layout.space_spec();var portals:Array=[]
  check(layout.world_size()==Vector2(source.rooms[id].trial_size_m[0],source.rooms[id].trial_size_m[1]),id+" existing bounds retained")
  check(spec.environment!="" and float(spec.wall.height_m)>2.2 and float(spec.wall.thickness_m)<.25,id+" complete logical architecture")
  for item:Dictionary in layout.furniture+layout.decor:
   var rect:Rect2=item.rect
   check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=layout.world_size().x+.00001 and rect.end.y<=layout.world_size().y+.00001,id+":"+str(item.id)+" footprint inside scene")
   check(float(item.height_m)>0 and Vector2(item.at).is_equal_approx(rect.get_center()),id+":"+str(item.id)+" metre height and foot anchor")
  for to:String in Map.doors(id):
   var portal:Dictionary=layout.portal(to);portals.append(portal)
   check(layout.walkable(portal.landing) and layout.walkable(portal.threshold),id+"→"+to+" clear body threshold and landing")
   var side:=Vector2(-Vector2(portal.inward).y,Vector2(portal.inward).x)
   check(layout.walkable(Vector2(portal.landing)+side*.4) and layout.walkable(Vector2(portal.landing)-side*.4),id+"→"+to+" actual 1.4m portal sideways clearance")
   check(portal.wall_point.x==0 or portal.wall_point.y==0 or portal.wall_point.x==layout.world_size().x or portal.wall_point.y==layout.world_size().y,id+"→"+to+" fullwall aperture point")
  for item:Dictionary in layout.furniture+layout.decor:
   if str(item.kind) in ["wall","wall_lamp"]:continue
   var reachable:bool=false
   for approach:Dictionary in item.approaches:
    if not layout.path(portals[0].landing,approach.at).is_empty():reachable=true;break
   check(reachable,id+":"+str(item.id)+" reachable furniture approach for generation/contact guide")
  var movement:Array=[]
  for first in range(portals.size()):
   for second in range(first+1,portals.size()):
    var start:Vector2=portals[first].landing;var goal:Vector2=portals[second].landing
    var route:PackedVector2Array=layout.path(start,goal)
    check(not route.is_empty(),id+" portal pair connected")
    var position:Vector2=start;var distance:float=0
    for step in range(1500):
     if route.is_empty():break
     var moved:Dictionary=layout.move_path(position,route,.08)
     distance+=position.distance_to(moved.position);position=moved.position;route=moved.route
    check(position.distance_to(goal)<.05,id+" actual swept movement reaches other portal")
    movement.append({"from":portals[first].toward,"to":portals[second].toward,"distance_m":distance,"reached":position.distance_to(goal)<.05})
  rooms.append({"room":id,"portal_routes":movement,"prop_count":layout.furniture.size()+layout.decor.size()})
 var hidden=Hidden.new();var hspec:Dictionary=hidden.space_spec()
 check(hidden.geometry_version==2 and hidden.world_size()==Vector2(5.6,3.8),"hidden saved logical size retained and metric geometry active")
 check(hidden.project(Vector2(1,1))-hidden.project(Vector2.ZERO)==Vector2(126,56),"hidden shares96/30/56 projection")
 check(hidden.walkable(Hidden.ENTRY) and hidden.walkable(Hidden.EXIT),"hidden original entry and exit free")
 var path:PackedVector2Array=hidden.path(Hidden.ENTRY,Hidden.EXIT)
 check(not path.is_empty(),"hidden original independent E1 route connected")
 var hpos:Vector2=Hidden.ENTRY
 for step in range(500):
  if path.is_empty():break
  var moved:Dictionary=hidden.move_path(hpos,path,.04);hpos=moved.position;path=moved.route
 check(hpos.distance_to(Hidden.EXIT)<.05,"hidden real swept movement reaches original exit")
 check(hspec.portals.size()==2 and hspec.portals[1].toward=="E1","hidden separate entry and E1 only, no invented Street7 branch")
 var result:Dictionary={"passed":passed,"failed":failures.size(),"failures":failures,"rooms":rooms,"scope":"Actual runtime layouts, swept body path movement, independent hidden geometry. Not NPC crowd or human balance/visual approval."}
 var output:String="../docs/validation/space_street_20261018/contract/result.json"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
