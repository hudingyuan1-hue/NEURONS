extends SceneTree
## Source-led nonrectangular room navigation. No campaign or progress mutation.
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const CMap=preload("res://scripts/core/cortex_map.gd")
const BMap=preload("res://scripts/core/combat_map.gd")
const Spatial=preload("res://scripts/world/spatial_geometry.gd")
var failures:Array=[]
var checks:int=0
var rows:Array=[]

func _initialize() -> void:call_deferred("run")
func verify(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)

func inspect(layout,chapter:int) -> void:
 var key:String="L%d:%s"%[chapter,layout.room_id]
 var spec:Dictionary=layout.space_spec()
 verify(spec.get("floor_polygon_m",[]).size()>4,key+" actual shaped outline")
 verify(not str(spec.get("shape_description","")).is_empty(),key+" source identity")
 verify(layout.walkable(layout.spawn()),key+" legal spawn")
 var targets:Array=[]
 for prop:Dictionary in spec.furniture:
  var at:=Vector2(float(prop.stand_m[0]),float(prop.stand_m[1]))
  targets.append({"id":str(prop.id),"at":at})
  verify(not str(prop.get("silhouette_note","")).is_empty(),key+" distinct prop brief "+str(prop.id))
 for toward in CMap.doors(layout.room_id) if chapter==4 else BMap.doors(layout.room_id):
  var mouth:Dictionary=layout.portal(str(toward))
  verify(not mouth.is_empty(),key+" graph preserved "+str(toward))
  if mouth.is_empty():continue
  for field:String in ["at","threshold","landing"]:
   verify(layout.walkable(mouth[field]),key+" legal mouth "+str(toward)+" "+field)
  verify(layout.clear_segment(mouth.threshold,mouth.landing,layout.body_radius),key+" clear threshold "+str(toward))
  targets.append({"id":"door:"+str(toward),"at":mouth.at})
 var lengths:Dictionary={}
 for target:Dictionary in targets:
  verify(layout.walkable(target.at),key+" target stand "+target.id)
  if not layout.walkable(target.at):continue
  var route:PackedVector2Array=layout.path(layout.spawn(),target.at)
  verify(not route.is_empty(),key+" route "+target.id)
  var length:float=0
  for index in range(1,route.size()):
   verify(layout.clear_segment(route[index-1],route[index],layout.body_radius),key+" actual contour segment "+target.id)
   length+=route[index-1].distance_to(route[index])
  lengths[target.id]=snappedf(length,.01)
 for hole:PackedVector2Array in Spatial.floor_holes(spec,layout.world_size()):
  var center:=Vector2.ZERO
  for point in hole:center+=point
  center/=hole.size()
  verify(not layout.walkable(center),key+" inner void blocks floor")
 rows.append({"room":key,"shape":spec.shape_description,"size_m":spec.size_m,"targets":lengths})

func run() -> void:
 for room:String in CMap.ALL_ROOMS:inspect(Cortex.new(room,2),4)
 for room:String in BMap.rooms():inspect(Combat.new(room,true,3),5)
 for room:String in CMap.ALL_ROOMS:
  var left:Dictionary=CMap.space_spec(room);var right:Dictionary=BMap.space_spec(room)
  for field:String in ["size_m","floor_polygon_m","floor_holes_m","furniture","partitions"]:
   verify(left[field]==right[field],"L5 reuses L4 exact geometry "+room+" "+field)
 var atrium=Cortex.new("atrium",2)
 verify(atrium.portal("memory").wall=="south" and atrium.portal("body").wall=="west","document24 corrected cardinal links")
 var branch=Cortex.new("switch",2)
 verify(not branch.walkable(Vector2(1,1)) and not branch.walkable(Vector2(11,2)),"Y branches do not expose rectangle floor")
 var bridge=Cortex.new("bridge",2)
 verify(not bridge.walkable(Vector2(6,.8)),"bridge neck has real outside void")
 var pulse=Combat.new("brainstem",true,3)
 verify(not pulse.clear_segment(pulse.portal("thalamus").at,pulse.portal("street_exit").at,.21),"pulse pit cannot be crossed by endpoint shortcut")
 var folder:String="res://../tmp/spatial_rebuild_20261019"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file:=FileAccess.open(folder+"/neural_navigation_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"rooms":rows,"failures":failures,"scope":"Actual Godot metre geometry, static floor/void collision, standing targets and portal routes. Does not assert whole-game pacing or formal art acceptance."},"  "));file.close()
 print("NEURAL_SHAPE_REBUILD ",checks," checks / ",rows.size()," rooms / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
