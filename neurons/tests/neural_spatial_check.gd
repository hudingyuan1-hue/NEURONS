extends SceneTree
## Real Godot layouts/navigation; independent save-neutral spatial contract check.
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const CMap=preload("res://scripts/core/cortex_map.gd")
const BMap=preload("res://scripts/core/combat_map.gd")
const BattleView=preload("res://scripts/world/combat_view.gd")
var failures:Array=[]
var checked:Array=[]
func _initialize() -> void:call_deferred("run")
func verify(value:bool,label:String) -> void:
 if not value:failures.append(label);push_error(label)
func inspect_layout(layout,chapter:int) -> void:
 var key:String="L%d:%s"%[chapter,layout.room_id]
 var spec:Dictionary=layout.space_spec()
 verify(not spec.is_empty(),key+" contract exists")
 verify(layout.walkable(layout.spawn()),key+" spawn legal")
 for item:Dictionary in layout.furniture:
  if item.get("kind","")=="wall" or item.get("logical_exclusion",false):continue
  # Solid decoration may share the broad-phase furniture collider array;
  # its floor-center anchor is not an interaction/search standing point.
  var decorative:bool=false
  for decoration:Dictionary in spec.get("decor",[]):
   if str(decoration.id)==str(item.id):decorative=true;break
  if decorative:continue
  verify(layout.walkable(item.at),key+" stand legal "+str(item.id))
  if layout.walkable(item.at):verify(not layout.path(layout.spawn(),item.at).is_empty(),key+" stand reached "+str(item.id))
 for toward in CMap.doors(layout.room_id) if chapter==4 else BMap.doors(layout.room_id):
  var p:Dictionary=layout.portal(str(toward))
  verify(not p.is_empty(),key+" portal "+str(toward))
  if p.is_empty():continue
  verify(layout.walkable(p.at),key+" doorway legal "+str(toward))
  verify(layout.walkable(p.landing),key+" landing legal "+str(toward))
  verify(layout.walkable(p.threshold),key+" crossing threshold legal "+str(toward))
  verify(not layout.path(layout.spawn(),p.at).is_empty(),key+" doorway reached "+str(toward))
  verify(layout.clear_segment(p.at,p.landing,layout.body_radius),key+" actual door approach "+str(toward))
  verify(not layout.path(p.landing,p.threshold).is_empty(),key+" actual crossing route "+str(toward))
 for sample in [layout.spawn(),layout.world_size()*.5]:verify(layout.unproject(layout.project(sample)).distance_to(sample)<.0001,key+" projection reversible")
 checked.append({"room":key,"size_m":[layout.world_size().x,layout.world_size().y],"furniture":layout.furniture.size(),"portals":spec.portals.size()})
func run() -> void:
 for room in CMap.ALL_ROOMS:inspect_layout(Cortex.new(str(room),2),4)
 for room in BMap.rooms():inspect_layout(Combat.new(str(room),true,3),5)
 var old_c=Cortex.new("memory")
 verify(old_c.geometry_version==1 and old_c.world_size().is_equal_approx(Vector2(5.6,3.8)),"old L4 constructor remains legacy size")
 var old_b=Combat.new("memory")
 verify(old_b.spatial_version==2 and old_b.world_size().is_equal_approx(Vector2(11.2,7.6)),"old L5 constructor remains legacy size")
 var metric=Cortex.new("memory",2)
 var cabinet:Rect2=metric.furniture[0].rect
 var y:float=cabinet.end.y+.10
 var a:=Vector2(cabinet.position.x-.08,y)
 var b:=Vector2(cabinet.end.x+.08,y)
 verify(metric.clear_segment(a,b,0),"L4 zero-radius sight/contact path remains zero-radius")
 verify(not metric.clear_segment(a,b,.21),"L4 adult movement uses full radius at furniture edge")
 verify(not metric.walkable(cabinet.end,0),"L4 v2 far furniture edge is closed")
 verify(not metric.clear_segment(cabinet.end,cabinet.end,0),"L4 v2 exact zero-length on furniture edge is blocked")
 var tiny:Vector2=cabinet.end+Vector2(.16,.16)
 verify(metric.walkable(tiny,.14) and not metric.walkable(tiny,.21),"L4 explicit radius parameter is respected")
 var folder:String="res://../docs/validation/neural_spaces_20261018"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file:=FileAccess.open(folder+"/geometry_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"rooms":checked,"failures":failures,"scope":"Actual new L4/L5 Godot layout construction, real grid routing and portal segments. Legacy constructor compatibility. Not whole-game human pacing, all actor combinations or formal art acceptance."},"  "));file.close()
 print("NEURAL_SPATIAL ",checked.size()," rooms / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
