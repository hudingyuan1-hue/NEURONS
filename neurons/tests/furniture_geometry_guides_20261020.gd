extends SceneTree
## Transparent projection guides for real furniture art production only.
## Dimensions/placements are read from the current bedroom; no gameplay writes.
const Bedroom=preload("res://scripts/world/bedroom_layout.gd")
const Props=preload("res://scripts/world/spatial_prop.gd")
const Presentation=preload("res://scripts/world/spatial_presentation.gd")
const Materials=preload("res://scripts/world/spatial_materials.gd")
var folder:String="res://../docs/validation/asset_production_20261020/furniture"

class GuideCanvas extends Node2D:
 var layout
 var items:Array=[]
 var records:Array=[]
 func _draw() -> void:
  var Prop=preload("res://scripts/world/spatial_prop.gd")
  var Present=preload("res://scripts/world/spatial_presentation.gd")
  records.clear()
  for index in range(items.size()):
   var entry:Dictionary=items[index];var item:Dictionary=entry.item;var rect:Rect2=item.rect;var h:float=float(item.height)
   var bounds:Rect2=Present.prism_bounds(layout,rect,h+32)
   if entry.role=="fan_rotor":bounds=Rect2(layout.project(rect.get_center())-Vector2(26,h*.74+26),Vector2(52,52))
   if entry.role=="blanket":bounds=Present.prism_bounds(layout,Rect2(rect.position+Vector2(rect.size.x*.33,0),rect.size*Vector2(.67,1)),4,h+2)
   if entry.role=="drawer":bounds=Present.prism_bounds(layout,rect,18,h*.35)
   var row:int=floori(float(index)/3)
   var cell:=Vector2((index%3)*512,row*512)
   var zoom:float=minf(410/maxf(bounds.size.x,1),410/maxf(bounds.size.y,1))
   var offset:Vector2=cell+Vector2(256,256)-bounds.get_center()*zoom
   draw_set_transform(offset,0,Vector2(zoom,zoom))
   if entry.role in ["carcass","wardrobe_open"]:
    var side:float=minf(.06,rect.size.x*.15)
    if rect.size.y>rect.size.x:
     Prop._face(self,layout,Prop._quad(Rect2(rect.position,Vector2(rect.size.x,side))),h,Color("88785e"))
     Prop._face(self,layout,Prop._quad(Rect2(rect.position+Vector2(0,rect.size.y-side),Vector2(rect.size.x,side))),h,Color("88785e"))
     Prop._vertical_panel(self,layout,Vector2(rect.end.x,rect.position.y),rect.end,3,h,Color("5d5549"))
    else:
     Prop._face(self,layout,Prop._quad(Rect2(rect.position,Vector2(side,rect.size.y))),h,Color("88785e"))
     Prop._face(self,layout,Prop._quad(Rect2(rect.position+Vector2(rect.size.x-side,0),Vector2(side,rect.size.y))),h,Color("88785e"))
     Prop._vertical_panel(self,layout,rect.position,rect.position+Vector2(rect.size.x,0),3,h,Color("5d5549"))
    for level in [3,h*.35,h*.7,h]:Prop._face_at_height(self,layout,Prop._quad(rect),level-3,level,Color("88785e"))
   elif entry.role=="drawer":
    Prop._face_at_height(self,layout,Prop._quad(rect),h*.35,h*.35+14,Color("9b8466"))
    var at:Vector2=layout.project(rect.get_center()+Vector2(0,rect.size.y*.5))-Vector2(0,h*.35+7)
    draw_line(at-Vector2(7,0),at+Vector2(7,0),Color("b9ad8c"),2,true)
   elif entry.role=="blanket":
    var part:=Rect2(rect.position+Vector2(rect.size.x*.33,0),rect.size*Vector2(.67,1))
    Prop._face_at_height(self,layout,Prop._quad(part),h+2,h+4,Color("a6aead"))
   elif entry.role=="fan_rotor":
    var at:Vector2=layout.project(rect.get_center())-Vector2(0,h*.74)
    for blade in range(3):
     var angle:float=blade*TAU/3
     draw_colored_polygon(PackedVector2Array([at,at+Vector2.from_angle(angle-.3)*20,at+Vector2.from_angle(angle+.35)*23,at+Vector2.from_angle(angle+.65)*10]),Color("829795"))
    draw_circle(at,3,Color("b9c0ad"))
   elif entry.role=="coat":
    var at:Vector2=layout.project(rect.get_center())
    var points:=PackedVector2Array()
    for v:Vector2 in [Vector2(-.12,-1),Vector2(.12,-1),Vector2(.34,-.86),Vector2(.4,-.59),Vector2(.24,-.54),Vector2(.2,-.12),Vector2(-.2,-.12),Vector2(-.24,-.54),Vector2(-.4,-.59),Vector2(-.34,-.86)]:points.append(at+Vector2(v.x*78,v.y*h))
    draw_colored_polygon(points,Color("d0d3c7"))
    draw_line(at+Vector2(0,-h*.86),at+Vector2(0,-h*.15),Color("919c96"),1.2,true)
   elif entry.role=="clock":
    var at:Vector2=layout.project(rect.get_center())-Vector2(0,h*.5)
    draw_circle(at,h*.45,Color("b6b4a0"));draw_circle(at,h*.35,Color("d9d9c2"))
    draw_line(at,at+Vector2(h*.2,-h*.1),Color("536061"),1.5,true);draw_line(at,at-Vector2(0,h*.24),Color("536061"),1.5,true)
   elif entry.role=="paper":Prop._face_at_height(self,layout,Prop._quad(rect),0,3,Color("d5d2bc"))
   else:Prop.draw(self,layout,item,item.color)
   var anchor:Vector2=layout.project(rect.get_center())
   if entry.role=="fan_rotor":anchor-=Vector2(0,h*.74)
   var corners:Array=[]
   for point:Vector2 in Prop._quad(rect):
    var pixel:Vector2=layout.project(point)*zoom+offset-cell
    corners.append([pixel.x,pixel.y])
   var point:Vector2=anchor*zoom+offset-cell
   records.append({"id":entry.id,"original_furniture_id":item.id,"role":entry.role,"cell_index":index,"cell_xy":[index%3,row],"cell_rect_px":[cell.x,cell.y,512,512],"guide_anchor_px":[point.x,point.y],"guide_pixels_per_world_pixel":zoom,"world_rect_m":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"world_height_m":float(item.height)/78,"guide_ground_corners_px":corners,"anchor_mode":"attachment_center" if entry.role=="fan_rotor" else "footprint_center","geometry_is_only_orientation_scale_guide":true})
  draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
 root.size=Vector2i(1536,1024);root.content_scale_size=Vector2i(1536,1024);root.transparent_bg=true
 call_deferred("run")

func run() -> void:
 Materials.force_preview=false
 var layout=Bedroom.new();var by_id:Dictionary={}
 for item:Dictionary in layout.furniture:by_id[str(item.id)]=item
 var definitions:Array=[
  {"name":"atlas_a","entries":[["bed","bed","body"],["bedside","bedside","carcass"],["desk","desk","body"],["chair","chair","body"],["bedside_drawer","bedside","drawer"],["bed_blanket","bed","blanket"]]},
  {"name":"atlas_b","entries":[["fan","fan","body"],["rack","rack","body"],["books","books","body"],["wardrobe","wardrobe","body"],["fan_rotor","fan","fan_rotor"],["wardrobe_open","wardrobe","wardrobe_open"]]}
 ]
 var absolute:String=ProjectSettings.globalize_path(folder);DirAccess.make_dir_recursive_absolute(absolute)
 var record:Dictionary={"coordinate_canvas_px":[1536,1024],"grid":[3,2],"source":"Current room_spaces.json actual bedroom dimensions, fixed approved 2D oblique projection; no new placements.","atlases":{}}
 for definition:Dictionary in definitions:
  var panel:=GuideCanvas.new();panel.layout=layout
  for entry:Array in definition.entries:panel.items.append({"id":entry[0],"item":by_id[entry[1]].duplicate(true),"role":entry[2]})
  root.add_child(panel)
  for frame in range(3):await process_frame
  await RenderingServer.frame_post_draw
  var path:String=absolute.path_join(str(definition.name)+"_geometry_guide.png")
  var image:Image=root.get_texture().get_image();var result:int=image.save_png(path)
  record.atlases[definition.name]={"path":path,"save_error":result,"actual_image_px":[image.get_width(),image.get_height()],"logical_to_image_scale":[float(image.get_width())/1536,float(image.get_height())/1024],"items":panel.records.duplicate(true)}
  panel.queue_free();await process_frame
 var file=FileAccess.open(absolute.path_join("geometry_guides.json"),FileAccess.WRITE);file.store_string(JSON.stringify(record,"  "));file.close()
 print("FURNITURE_GUIDES 2 atlases / 12 layers")
 quit(0)
