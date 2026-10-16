extends SceneTree
const Map=preload("res://scripts/core/cortex_map.gd")
const Layout=preload("res://scripts/world/cortex_layout.gd")
var errors:Array=[]
var checks:int=0
var room_results:Array=[]

func expect(value:bool,message:String) -> void:
 checks+=1
 if not value:errors.append(message)

func _init() -> void:
 expect(Map.FIRST_ROOMS.size()==5 and Map.SECOND_ROOMS.size()==6,"S1 two floors must contain five and six rooms")
 expect(Map.candidates(1).size()==31 and Map.candidates(2).size()==31,"S1 both floors need thirty-one candidates")
 expect(Map.candidates().size()==62,"S4 total sixty-two candidates")
 var ids:Dictionary={}
 var edge_count:int=0
 var total:int=0
 var route_count:int=0
 for room in Map.ALL_ROOMS:
  var layout=Layout.new(room)
  total+=layout.furniture.size()
  expect(layout.furniture.size()==Map.POINTS[room].size(),"candidate/physical furniture mismatch "+room)
  var issues:Array=layout.geometry_issues()
  expect(issues.is_empty(),"physical paths "+room+": "+str(issues))
  room_results.append({"room":room,"candidates":layout.furniture.size(),"issues":issues})
  for item in layout.furniture:
   expect(not ids.has(item.id),"duplicate point "+str(item.id));ids[item.id]=true
   expect(not item.data.rest_point and float(item.data.search_seconds)==7.0,"no rest / original seven seconds "+str(item.id))
   expect(not str(item.data.action).is_empty() and not str(item.data.failure_hero).is_empty(),"source action / line missing "+str(item.id))
  for door in Map.doors(room):
   if door!="combat_exit":
    edge_count+=1
    expect(room in Map.doors(door),"one-way invented internal connection "+room+" -> "+door)
   var start:Vector2=Map.doorway(room,door)
   expect(layout.walkable(start),"blocked doorway "+room+" -> "+door)
   for item in layout.furniture:
    var position:Vector2=start
    var route:PackedVector2Array=layout.path(position,item.at)
    var iter:int=0
    while not route.is_empty() and iter<2000:
     var moved:Dictionary=layout.move_path(position,route,0.07)
     position=moved.position;route=moved.route;iter+=1
    expect(position.distance_to(item.at)<0.001 and route.is_empty(),"actual movement stuck "+room+" "+door+" -> "+str(item.id))
    route_count+=1
  expect(not Map.next_room(room,"combat_exit").is_empty(),"exit not reachable from "+room)
  expect(Map.next_room(room,"ward").is_empty(),"invented return to L3 from "+room)
 expect(total==62 and ids.size()==62,"physical unique sixty-two")
 expect(edge_count==26,"source graph has thirteen bidirectional internal edges")
 expect(Map.next_room("visual","memory")=="memory","required lateral door")
 expect(Map.next_room("body","bridge")=="atrium","body must not have a second-floor exit")
 expect(Map.next_room("decision","bridge")=="bridge","decision rear exit")
 expect(Map.next_room("switch","bridge")=="bridge" and Map.next_room("bridge","index")=="index" and Map.next_room("index","switch")=="switch","source loop must really traverse three doors")
 var atrium=Layout.new("atrium")
 expect(atrium.walkable(Map.SPAWN),"wake stand separated from core")
 expect(not atrium.clear_segment(Vector2(1.8,1.85),Vector2(3.8,1.85),Layout.RADIUS),"central core must physically block direct crossing")
 expect(not atrium.path(Vector2(1.8,1.85),Vector2(3.8,1.85)).is_empty(),"core must retain surrounding path")
 var visual=Layout.new("visual")
 expect(visual.walkable(Vector2(2.8,2.4)),"chair group central aisle")
 var body=Layout.new("body")
 expect(body.walkable(Vector2(2.3,1.9)),"mapping centre must remain open")
 var rhythm=Layout.new("rhythm")
 expect(not rhythm.clear_segment(Map.doorway("rhythm","bridge"),Map.doorway("rhythm","identity"),Layout.RADIUS),"rhythm retains a real bend")
 expect(not rhythm.path(Map.doorway("rhythm","bridge"),Map.doorway("rhythm","identity")).is_empty(),"rhythm bend still passable")
 expect(Map.doorway("verify","combat_exit").y<1.0,"exit lock is after all candidates, not another room")
 var result:Dictionary={"engine":Engine.get_version_info().string,"passed":checks-errors.size(),"failed":errors.size(),"checks":checks,"room_count":Map.ALL_ROOMS.size(),"point_count":total,"actual_routes":route_count,"rooms":room_results,"errors":errors,"scope":"Headless Godot actual AStar grid, every stand/door pair segment, real move_path traversal. No GPU/art/normal-play acceptance claimed."}
 var output:String="res://../tmp/b4_20261016/layout_unit.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--result="):output=arg.trim_prefix("--result=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("CORTEX_LAYOUT ",checks-errors.size()," passed / ",errors.size()," failed / ",route_count," routes / ",errors)
 quit(0 if errors.is_empty() else 1)
