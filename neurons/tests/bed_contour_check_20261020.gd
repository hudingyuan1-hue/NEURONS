extends SceneTree
## A transport bed must clear its entire oriented footprint, including holes.
const Bed=preload("res://scripts/core/bed_body.gd")
class Space extends RefCounted:
 var furniture:Array=[]
 var movable_blockers:Array=[]
 var spec:Dictionary={}
 func world_size() -> Vector2:return Vector2(8,6)
 func space_spec() -> Dictionary:return spec
var passes:Array=[]
var failures:Array=[]
func check(value:bool,label:String) -> void:
 (passes if value else failures).append(label)
 print(("PASS " if value else "FAIL ")+label)
func _initialize() -> void:
 var room=Space.new()
 check(Bed.clear(room,Vector2(3,3),Vector2.RIGHT),"ordinary complete bed fits floor")
 check(not Bed.clear(room,Vector2(.1,3),Vector2.LEFT),"bed cannot project through unbroken boundary")
 var portal:Dictionary={"at":Vector2(.3,3),"inward":Vector2.RIGHT,"width_m":1.2}
 check(Bed.clear(room,Vector2(.45,3),Vector2.LEFT,[portal]),"real doorway permits swept bed extension")
 var narrow:Dictionary=portal.duplicate();narrow.width_m=.7
 check(not Bed.clear(room,Vector2(.45,3),Vector2.LEFT,[narrow]),"bed cannot pass doorway narrower than its sides")
 room.spec={"floor_polygon_m":[[0,0],[8,0],[8,6],[0,6]],"floor_holes_m":[[[3.28,2.8],[3.4,2.8],[3.4,2.95],[3.28,2.95]]]}
 check(not Bed.clear(room,Vector2(3,3),Vector2.RIGHT),"void enclosed between four legal corners still blocks bed")
 room.spec={"floor_polygon_m":[[0,0],[8,0],[8,6],[4,6],[4,3],[3.5,3],[3.5,6],[0,6]]}
 check(not Bed.clear(room,Vector2(3,3.7),Vector2.RIGHT),"concave missing floor blocks bed edge between legal corners")
 room.spec={"floor_polygon_m":[[0,0],[8,0],[8,6],[0,6]],"floor_holes_m":[[[3.3,2.7],[4.4,2.7],[4.4,3.3],[3.3,3.3]]]}
 check(not Bed.sweep(room,Vector2(1,3),Vector2(5,3),Vector2.RIGHT,Vector2.RIGHT).complete,"bed sweep stops before crossing real hole")
 room.spec={};room.furniture=[{"rect":Rect2(3.3,2.7,.2,.2)}]
 check(not Bed.clear(room,Vector2(3,3),Vector2.RIGHT),"original furniture collision remains effective")
 var folder:String="res://../docs/validation/spatial_rebuild_20261020"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file=FileAccess.open(folder.path_join("bed_contour_result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passes":passes,"failures":failures},"  "));file.close()
 quit(0 if failures.is_empty() else 1)
