extends SceneTree
const Map=preload("res://scripts/core/asylum_map.gd")
const Layout=preload("res://scripts/world/asylum_layout.gd")
var errors:Array=[]
func _init() -> void:
 var count:int=0
 for room in Map.UPPER_ROOMS:
  var layout=Layout.new(room)
  count+=layout.furniture.size()
  for issue in layout.geometry_issues():errors.append(issue)
 if count!=45 or Map.candidates().size()!=45:errors.append("candidate count differs from S4 forty-five")
 var result:Dictionary={"engine":Engine.get_version_info().string,"point_count":count,"errors":errors,"scope":"actual Godot navigation/grid/segment collision only; visual acceptance is separate"}
 var path:String="res://../docs/validation/b3_20261016/layout_unit.json"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("ASYLUM_LAYOUT ",count," points / ",errors)
 quit(0 if errors.is_empty() else 1)
