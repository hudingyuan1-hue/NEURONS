extends SceneTree
## Small declared footprint fixtures against shared production collision APIs.
## Existing route/save/bed/arm suites exercise actual actions separately.
const Base=preload("res://scripts/world/room_layout.gd")
const Bed=preload("res://scripts/core/bed_body.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
class Probe:
 extends "res://scripts/world/room_layout.gd"
 var walls:Array[Rect2]=[]
 var static_walls:Array[Dictionary]=[]
 var decor:Array[Dictionary]=[]

var passes:Array=[]
var failures:Array=[]
var folder:String="res://../docs/validation/full_campaign_spatial_20261019/collision_compat"
func verify(ok:bool,label:String) -> void:
 (passes if ok else failures).append(label)
 print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:call_deferred("run")

func empty(version:int):
 var space=Probe.new();space.bounds_size=Vector2(8,6);space.geometry_version=version
 space.furniture.clear();space.movable_blockers.clear();space.rebuild_grid();return space

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--validation-root="):folder=arg.trim_prefix("--validation-root=")
 for version in [1,2]:
  for key in ["solid","collision"]:
   var space=empty(version)
   var rug:Dictionary={"id":"declared_nonphysical_layer","rect":Rect2(2,2,3,1),key:false}
   space.furniture.append(rug);space.rebuild_grid()
   verify(space.walkable(Vector2(3,2.5)),"v%d %s=false floor layer permits actor footprint"%[version,key])
   verify(space.clear_segment(Vector2(1,2.5),Vector2(6,2.5),.14),"v%d %s=false floor layer permits actor segment"%[version,key])
   verify(Bed.clear(space,Vector2(2.3,2.5),Vector2.RIGHT),"v%d %s=false floor layer permits oriented bed"%[version,key])
  var space=empty(version)
  space.furniture.append({"id":"declared_two_banks","rect":Rect2(2,1,3,4),"collision_rects":[Rect2(2,1,3,.5),Rect2(2,4.5,3,.5)]})
  space.rebuild_grid()
  verify(space.walkable(Vector2(3,3)) and space.clear_segment(Vector2(1,3),Vector2(6,3),.14),"v%d separate banks preserve true centre passage, not enclosing hull"%version)
  verify(not space.walkable(Vector2(3,1.25)) and not space.clear_segment(Vector2(1,1.25),Vector2(6,1.25),.14),"v%d real bank still blocks actor and segment"%version)
  verify(Bed.clear(space,Vector2(2.3,3),Vector2.RIGHT) and not Bed.clear(space,Vector2(2.3,1.25),Vector2.RIGHT),"v%d oriented bed uses actual banks and centre opening"%version)
 var space=empty(2)
 space.walls.append(Rect2(3,1,.15,4))
 verify(not Bed.clear(space,Vector2(2.3,3),Vector2.RIGHT),"oriented bed cannot cross architectural walls collection")
 space.walls.clear();space.decor.append({"id":"declared_rail","rect":Rect2(3,1,.15,4),"solid":true})
 verify(not Bed.clear(space,Vector2(2.3,3),Vector2.RIGHT),"oriented bed cannot cross solid decorative rail")
 space.decor[0].solid=false
 verify(Bed.clear(space,Vector2(2.3,3),Vector2.RIGHT),"non-solid decorative layer does not become bed blocker")
 # Institution architecture uses static_walls, not the cortex `walls` field.
 var institution=Institution.new("stairs",3);institution.furniture.clear();institution.decor.clear();institution.static_walls.clear()
 institution.static_walls.append({"id":"declared_return_wall","rect":Rect2(3,1,.15,3),"height_m":2.55})
 verify(Bed.clear(institution,Vector2(.8,2.5),Vector2.RIGHT),"institution static wall permits a genuinely unobstructed bed pose")
 verify(not Bed.clear(institution,Vector2(2.3,2.5),Vector2.RIGHT),"oriented bed respects institution static_walls as real walls")
 for version in [2,3]:
  var combat=Combat.new("atrium",false,version);combat.furniture.clear();combat.decor.clear();combat.movable_blockers.clear()
  combat.furniture.append({"id":"declared_noncollision_prop","rect":Rect2(2,2,3,1),"solid":true,"collision":false})
  combat.rebuild_grid()
  verify(combat.walkable(Vector2(3,2.5)) and combat.clear_segment(Vector2(1,2.5),Vector2(6,2.5),.21),"combat v%d respects explicit collision=false independently from solid"%version)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file=FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures,"scope":"Explicit local nonphysical/compound/wall/rail fixtures, real v1/v2/v3 production collision APIs. No game-rule mutation or natural-play claim."},"  "));file.close()
 print("SHARED_COLLISION_COMPAT %d passed %d failed"%[passes.size(),failures.size()])
 quit(0 if failures.is_empty() else 1)
