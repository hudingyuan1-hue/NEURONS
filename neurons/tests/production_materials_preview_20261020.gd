extends SceneTree
## Real GPU 2D material/geometry inspection, separate from gameplay acceptance.
const Materials=preload("res://scripts/world/spatial_materials.gd")
const Geometry=preload("res://scripts/world/spatial_geometry.gd")
const Architecture=preload("res://scripts/world/architectural_surface.gd")
const Boundary=preload("res://scripts/world/spatial_boundary.gd")
const Props=preload("res://scripts/world/spatial_prop.gd")
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Institution=preload("res://scripts/world/institution_layout.gd")
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Street=preload("res://scripts/world/street_layout.gd")
const BedView=preload("res://scripts/world/metric_bedroom_view.gd")
const InstView=preload("res://scripts/world/metric_institution_view.gd")
var output:String="res://../docs/validation/asset_production_20261020/materials/gpu"

class MaterialCanvas extends Node2D:
 var layout
 var mode:String=""
 var caption:String=""
 var architectural_pieces:Array=[]
 var portals:Array=[]
 func _draw() -> void:
  var Geo=preload("res://scripts/world/spatial_geometry.gd")
  var Mat=preload("res://scripts/world/spatial_materials.gd")
  var Arch=preload("res://scripts/world/architectural_surface.gd")
  var Prop=preload("res://scripts/world/spatial_prop.gd")
  var BView=preload("res://scripts/world/metric_bedroom_view.gd")
  var IView=preload("res://scripts/world/metric_institution_view.gd")
  var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else layout.config
  var size:Vector2=layout.world_size()
  var bounds:=Rect2(layout.project(Vector2.ZERO),Vector2.ZERO)
  for p:Vector2 in Geo.floor_polygon(spec,size):bounds=bounds.expand(layout.project(p))
  for face:Dictionary in Arch.faces(architectural_pieces):
   for p:Vector3 in face.points:bounds=bounds.expand(layout.project(Vector2(p.x,p.z))-Vector2(0,p.y*78))
  var zoom:float=minf(1460/maxf(bounds.size.x,1),790/maxf(bounds.size.y,1))
  var offset:Vector2=Vector2(800,500)-bounds.get_center()*zoom
  draw_set_transform(offset,0,Vector2(zoom,zoom))
  Geo.draw_floor(self,layout,Color("a3a995"),Color("18202a"))
  Arch.draw(self,layout,architectural_pieces,{"group":"far","top":Color("c6c0ad"),"edge_width":.65,"edge":Color("6c716d")})
  # The real opening remains empty; only a slim painted frame is added.
  for portal:Dictionary in portals:
   var p:Vector2=portal.get("wall_point",portal.at)
   var inward:Vector2=portal.get("inward",Vector2.DOWN)
   if inward.dot(Vector2(-6,56))>=0:continue
   var axis:=Vector2(1,0) if str(portal.get("wall","north")) in ["north","south"] else Vector2(0,1)
   var half:float=float(portal.get("width_m",1))*.5;var h:float=float(portal.get("height_m",2.2))*78
   var a:Vector2=layout.project(p-axis*half);var b:Vector2=layout.project(p+axis*half)
   draw_polyline(PackedVector2Array([a,a-Vector2(0,h),b-Vector2(0,h),b]),Color("7b7365"),3,true)
  var items:Array=layout.furniture.duplicate()
  var decor=layout.get("decor")
  if decor is Array:items.append_array(decor)
  items.sort_custom(func(a,b):return layout.project((a.rect as Rect2).get_center()).y<layout.project((b.rect as Rect2).get_center()).y)
  for item:Dictionary in items:
   if not item.get("render",true):continue
   var kind:String=str(item.get("kind",item.get("id","")))
   if kind=="window":continue
   var copy:Dictionary=item.duplicate()
   if not copy.has("kind"):copy.kind=copy.id
   Prop.draw(self,layout,copy,item.get("color",Color("8c9589")))
  Arch.draw(self,layout,architectural_pieces,{"group":"near","top":Color("c6c0ad"),"edge_width":.65,"edge":Color("6c716d")})
  for item:Dictionary in items:
   if not item.get("render",true) or str(item.get("kind",""))!="window" or not item.has("wall_mount"):continue
   var face:PackedVector2Array=IView._window_face(layout,item)
   draw_colored_polygon(face,Color(.53,.63,.62,.35));face.append(face[0]);draw_polyline(face,Color("a8ab98"),2,true)
   draw_line(face[0].lerp(face[1],.5),face[3].lerp(face[2],.5),Color("a8ab98"),2,true)
  if mode=="bedroom":
   var frame=BView.new();frame.layout=layout;frame.canvas=self;frame._front_edges()
  draw_set_transform(Vector2.ZERO)
  draw_string(ThemeDB.fallback_font,Vector2(50,52),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("dbd2ba"))
  draw_string(ThemeDB.fallback_font,Vector2(50,965),"Same metric contour, openings and placements. GPU materials preview; no gameplay acceptance implied.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("9fa9a3"))

func _initialize() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
 root.size=Vector2i(1600,1000);root.content_scale_size=Vector2i(1600,1000)
 RenderingServer.set_default_clear_color(Color("202a30"))
 call_deferred("run")

func run() -> void:
 var absolute:String=ProjectSettings.globalize_path(output);DirAccess.make_dir_recursive_absolute(absolute)
 var rooms:Array=[{"id":"L1_bedroom","mode":"bedroom","layout":Bedroom.new()},{"id":"L3_double_ward","mode":"institution","layout":Institution.new("double_ward",3)},{"id":"L4_atrium","mode":"cortex","layout":Cortex.new("atrium",2)},{"id":"L6_street_plaza","mode":"street","layout":Street.new("street_plaza")}]
 var records:Array=[]
 for entry:Dictionary in rooms:
  var panel:=MaterialCanvas.new();panel.layout=entry.layout;panel.mode=entry.mode;panel.caption=str(entry.id)+" / hand-painted surfaces on fixed metric geometry"
  if entry.mode=="bedroom":
   panel.architectural_pieces=BedView.architecture_pieces(entry.layout)
  elif entry.mode=="institution":
   panel.architectural_pieces=InstView.architecture_pieces(entry.layout);panel.portals=entry.layout.portals
  else:
   for portal:Dictionary in entry.layout.space_spec().get("portals",[]):
    if portal.has("at"):panel.portals.append(portal)
    elif portal.has("toward"):panel.portals.append(entry.layout.portal(str(portal.toward)))
   panel.architectural_pieces=Boundary.pieces(entry.layout,entry.mode=="street",panel.portals)
  root.add_child(panel)
  for active:bool in [false,true]:
   Materials.force_preview=active;panel.queue_redraw()
   for frame in range(3):await process_frame
   await RenderingServer.frame_post_draw
   var path:String=absolute.path_join(str(entry.id)+("_materials.png" if active else "_baseline.png"))
   var result:int=root.get_texture().get_image().save_png(path)
   records.append({"room":entry.id,"material_override":active,"screenshot":path,"save_error":result,"context":Materials.context(entry.layout),"floor_material":Materials.floor_id(entry.layout),"size_m":[entry.layout.world_size().x,entry.layout.world_size().y]})
  panel.queue_free();await process_frame
 Materials.force_preview=false
 var file=FileAccess.open(absolute.path_join("preview_result.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"rendered":DisplayServer.get_name()!="headless","config_enabled":bool(Materials.document().get("enabled",false)),"records":records,"scope":"Real GPU 2D material overlay on actual fixed layout geometry. Does not prove actual gameplay, full prop formal-art quality or character/animation integration."},"  "));file.close()
 print("MATERIALS_PREVIEW ",records.size()," screenshots")
 quit(0)
