extends SceneTree
## Export the actual layouts, not a second hand-drawn interpretation.
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const Street=preload("res://scripts/world/street_layout.gd")
const Hidden=preload("res://scripts/world/hidden_layout.gd")
const CortexMap=preload("res://scripts/core/cortex_map.gd")
const CombatMap=preload("res://scripts/core/combat_map.gd")
const StreetMap=preload("res://scripts/core/street_map.gd")
const Presentation=preload("res://scripts/world/spatial_presentation.gd")
const Architecture=preload("res://scripts/world/architectural_surface.gd")
const BedroomView=preload("res://scripts/world/metric_bedroom_view.gd")
const InstitutionView=preload("res://scripts/world/metric_institution_view.gd")
const Shell=preload("res://scripts/world/spatial_shell.gd")
var rooms:Array=[]
var failures:Array=[]

func serial(value):
 if value is Vector2:return [value.x,value.y]
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Rect2:return [value.position.x,value.position.y,value.size.x,value.size.y]
 if value is Color:return value.to_html()
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[str(key)]=serial(value[key])
  return out
 if value is Array or value is PackedVector2Array:
  var out:Array=[]
  for item in value:out.append(serial(item))
  return out
 return value

func has_property(object,key:String) -> bool:
 for p in object.get_property_list():
  if p.name==key:return true
 return false

func exported_windows(config:Dictionary,furniture:Array,decor:Array) -> Array:
 var result:Array=[]
 var single:Dictionary=config.get("window",{})
 if not single.is_empty():
  var side:String=str(single.wall)
  var center:Array=single.center_m
  var at:float=float(center[0] if side in ["north","south"] else center[1])
  result.append({"wall":side,"start":at-float(single.width_m)*.5,"end":at+float(single.width_m)*.5,"sill":float(single.sill_height_m),"opening":float(single.opening_height_m)})
 for f in furniture+decor:
  if str(f.get("kind",""))!="window" or not f.has("wall_mount"):continue
  var side:String=str(f.wall_mount)
  var r:Array=f.rect
  var at:float=float(r[0] if side in ["north","south"] else r[1])
  var width:float=float(r[2] if side in ["north","south"] else r[3])
  result.append({"wall":side,"start":at,"end":at+width,"sill":float(f.get("sill_height_m",f.get("height_m",1.1))),"opening":float(f.get("opening_height_m",65.0/Presentation.HEIGHT_PIXELS))})
 var specs:Array=[]
 for physical:Dictionary in result:
  var shown:Dictionary=Presentation.window_display(str(physical.wall),float(physical.end)-float(physical.start),float(physical.sill),float(physical.opening))
  specs.append({"physical":physical,"drawing":{"wall":physical.wall,"start":physical.start,"end":physical.end,"sill":shown.sill_height_m,"opening":shown.opening_height_m,"cap_height_m":shown.wall_cap_height_m,"mode":shown.mode}})
 return specs

func add_room(chapter:int,id:String,title:String,layout,doors:Array) -> void:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var config:Dictionary=layout.config if has_property(layout,"config") else {}
 var size:Vector2=layout.world_size()
 var floor_items:Array=[]
 for f in layout.furniture:
  var item:Dictionary=f.duplicate(true)
  item["height_m"]=float(f.get("height_m",float(f.get("height",0))/Presentation.HEIGHT_PIXELS))
  item["approach_walkable"]=layout.walkable(f.at)
  var approach:Vector2=f.at
  if not layout.walkable(approach):
   for candidate in f.get("approaches",[]):
    if layout.walkable(candidate.at):approach=candidate.at;break
  item["operation_approach"]=serial(approach) if layout.walkable(approach) else null
  item["operation_policy"]="Existing search stand where present; outdoor props use a reachable reference side, never a new search point"
  item["solid"]=bool(f.get("solid",true)) and bool(f.get("collision",true)) and not (f.has("collision_rects") and f.collision_rects.is_empty())
  floor_items.append(serial(item))
 var decor:Array=[]
 if has_property(layout,"decor"):
  for f in layout.decor:
   var item:Dictionary=f.duplicate(true)
   item["height_m"]=float(f.get("height_m",float(f.get("height",0))/Presentation.HEIGHT_PIXELS))
   item["operation_approach"]=serial(f.at) if layout.walkable(f.at) else null
   decor.append(serial(item))
 var portals:Array=[]
 if layout.has_method("portal"):
  for toward in doors:
   var portal:Dictionary=layout.portal(str(toward))
   if not portal.is_empty():portals.append(serial(portal))
 elif config.has("door"):
  var door:Dictionary=config.door
  portals.append({"toward":"lobby","wall":door.wall,"wall_point":door.center_m,"at":serial(layout.door_position()),"width_m":door.clear_width_m,"height_m":door.height_m})
 var origin:Vector2=layout.project(Vector2.ZERO)
 if portals.is_empty() and spec.has("portals"):portals=serial(spec.portals)
 var spawn:Vector2=Hidden.ENTRY if chapter==0 else layout.spawn() if layout.has_method("spawn") else layout.get_anchor("spawn") if layout.has_method("get_anchor") else layout.bed_position()
 # Preserve the full physical wall separately from its opaque display cut.
 # Street/hidden expose a nested spec.wall rather than config.wall.
 var wall:Dictionary=config.get("wall",spec.get("wall",{"height_m":float(spec.get("wall_height_m",2.55)),"thickness_m":float(spec.get("wall_thickness_m",.15))})).duplicate(true)
 wall.erase("display")
 var outdoor:bool=chapter in [0,6] and str(spec.get("environment",""))!="covered_interior"
 var display_segments:Dictionary={}
 for side:String in ["north","east","south","west"]:
  var length:float=size.x if side in ["north","south"] else size.y
  var segments:Array=Presentation.wall_display_segments(side,length,float(wall.height_m))
  if outdoor and side in ["south","west"]:segments=[{"start":0.0,"end":length,"height_m":.14}]
  display_segments[side]=segments
 var presentation:Dictionary=Presentation.metadata()
 presentation.active_display_source="scripts/world/spatial_presentation.gd + actual layout.project(); config projection/near_alpha are legacy provenance only, not active display values."
 presentation.environment="outdoor" if outdoor else "interior"
 if outdoor:presentation.near_edge_height_m=.14
 var result:Dictionary={"id":"L%d_%s"%[chapter,id],"chapter":chapter,"room_id":id,"title":title,"geometry_version":layout.geometry_version,"size_m":serial(size),"projection":{"origin_px":serial(origin),"x_basis_px":serial(layout.project(Vector2.RIGHT)-origin),"depth_basis_px":serial(layout.project(Vector2.DOWN)-origin),"height_px_per_m":Presentation.HEIGHT_PIXELS,"source_scale":2},"presentation":serial(presentation),"physical_wall":serial(wall),"wall":serial(wall),"wall_display_segments":serial(display_segments),"portals":portals,"furniture":floor_items,"decor":decor,"spawn_m":serial(spawn),"config":serial(config),"space_spec":serial(spec),"logical_walls_complete":true,"status":"Runtime-derived geometry and opaque architectural cutaway; code placeholders, not formal art approval"}
 result.window_display_specs=exported_windows(serial(config),floor_items,decor)
 var pieces:Array=BedroomView.architecture_pieces(layout) if chapter==1 else InstitutionView.architecture_pieces(layout) if chapter in [2,3] else Shell.architecture_pieces(layout,outdoor,Shell.portals(layout))
 result.architecture_surface={"pieces":serial(pieces),"faces":serial(Architecture.faces(pieces)),"includes_fixed_partitions":chapter in [2,3,4,5],"includes_shower_walls":chapter in [2,3],"source":"Actual game architecture union; internal block faces/edges removed before projection"}
 if has_property(layout,"spatial_version"):result.spatial_version=layout.spatial_version
 if has_property(layout,"walls"):result.partitions=serial(layout.walls)
 if chapter==0:result.id="HIDDEN_PLAZA";result.title="隐藏广场 / E1路线"
 if not layout.walkable(spawn):failures.append(result.id+": spawn blocked")
 for item in floor_items:
  var rect:Array=item.rect
  if rect[0]<-.001 or rect[1]<-.001 or rect[0]+rect[2]>size.x+.001 or rect[1]+rect[3]>size.y+.001:
   if str(item.get("kind","")) not in ["wall","window"]:failures.append(result.id+": out-of-bounds "+str(item.id))
 rooms.append(result)

func _initialize() -> void:
 add_room(1,"bedroom","卧室",Bedroom.new(),["lobby"])
 var names:Dictionary={"ward":"小病房","lobby":"接待候诊区","clinic":"精神科诊室","pharmacy":"配药室","office":"医护办公室","stairs":"楼梯间","corridor":"二层走廊","activity":"活动室","group_therapy":"团体治疗室","quiet":"安静室","bathroom":"卫浴间","double_ward":"双人病房","workshop":"康复作业室"}
 for level in [2,3]:
  var ids:Array=["ward","lobby","clinic","pharmacy","office"] if level==2 else names.keys()
  for id in ids:
   var floor_layout=Institution.new(str(id),level)
   var doors:Array=[]
   for p in floor_layout.portals:doors.append(str(p.toward))
   add_room(level,str(id),str(names[id]),floor_layout,doors)
 for id in CortexMap.ALL_ROOMS:add_room(4,str(id),str(CortexMap.ROOM_NAMES[id]),Cortex.new(str(id),2),CortexMap.doors(str(id)))
 for id in CombatMap.rooms():add_room(5,str(id),CombatMap.title(str(id)),Combat.new(str(id),true,3),CombatMap.doors(str(id)))
 for id in StreetMap.rooms():add_room(6,str(id),StreetMap.title(str(id)),Street.new(str(id)),StreetMap.doors(str(id)))
 add_room(0,"hidden_street","隐藏广场",Hidden.new(),[])
 var out_path:String="res://../deliverables/space_templates_corrected_20261019/runtime_spaces.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):out_path=arg.trim_prefix("--output=")
 var absolute:String=ProjectSettings.globalize_path(out_path)
 DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
 var file=FileAccess.open(absolute,FileAccess.WRITE)
 var fingerprints:Dictionary={}
 for path:String in ["data/room_spaces.json","data/institution_spaces.json","data/neural_spaces.json","data/street_spaces.json","data/street_chapter.json","scripts/world/bedroom_layout.gd","scripts/world/institution_layout.gd","scripts/world/cortex_layout.gd","scripts/world/combat_layout.gd","scripts/world/street_layout.gd","scripts/world/hidden_layout.gd","scripts/world/room_layout.gd","scripts/world/spatial_presentation.gd","scripts/world/architectural_surface.gd","scripts/world/spatial_shell.gd","scripts/world/spatial_revision.gd","data/space_history_20261019/room_spaces.json","data/space_history_20261019/institution_spaces.json","data/space_history_20261019/neural_spaces.json","data/space_history_20261019/street_spaces.json","scripts/world/spatial_geometry.gd","scripts/world/spatial_boundary.gd","scripts/world/spatial_prop.gd","scripts/world/room_view.gd","scripts/world/metric_bedroom_view.gd","scripts/world/metric_institution_view.gd","scripts/world/combat_view.gd","scripts/world/campaign_view.gd","scripts/core/bed_body.gd","scripts/core/campaign_session.gd","scripts/core/combat_chapter.gd","scripts/core/cortex_map.gd","scripts/core/combat_map.gd","scripts/core/street_map.gd"]:
  fingerprints[path]=FileAccess.get_sha256("res://"+path)
 file.store_string(JSON.stringify({"schema":2,"generated_at":Time.get_datetime_string_from_system(),"presentation":serial(Presentation.metadata()),"source_sha256":fingerprints,"scene_count":rooms.size(),"coordinate_system":"x=right,z=depth,h=height in metres; shared fixed parallel oblique 2D; opaque cutaways do not change full physical walls or logical dimensions","rooms":rooms,"failures":failures},"  "));file.close()
 print("RUNTIME_SPACE_EXPORT ",rooms.size()," scenes; ",failures.size()," issues -> ",absolute)
 for issue in failures:print("SPACE_ISSUE ",issue)
 quit(0 if failures.is_empty() else 1)
