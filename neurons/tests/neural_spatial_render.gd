extends SceneTree
## Representative actual Godot 2D renders of the shared metre contracts.
## This is geometry evidence, not autonomous gameplay or approved final art.
const Cortex=preload("res://scripts/world/cortex_layout.gd")
const Combat=preload("res://scripts/world/combat_layout.gd")
const CMap=preload("res://scripts/core/cortex_map.gd")
const BMap=preload("res://scripts/core/combat_map.gd")
const View=preload("res://scripts/world/combat_view.gd")
class Painter extends Node2D:
 var layout
 var view
 var chapter:int=5
 var room:String=""
 var font:Font=ThemeDB.fallback_font
 func poly(points:Array,color:Color) -> void:draw_colored_polygon(PackedVector2Array(points),color)
 func prism(rect:Rect2,height:float,color:Color) -> void:
  var a:Vector2=layout.project(rect.position)
  var b:Vector2=layout.project(rect.position+Vector2(rect.size.x,0))
  var c:Vector2=layout.project(rect.end)
  var d:Vector2=layout.project(rect.position+Vector2(0,rect.size.y))
  var up:=Vector2(0,-height)
  poly([a,b,b+up,a+up],color.darkened(.12));poly([b,c,c+up,b+up],color.darkened(.28))
  poly([c,d,d+up,c+up],color.darkened(.18));poly([a+up,b+up,c+up,d+up],color.lightened(.16))
  draw_polyline(PackedVector2Array([a+up,b+up,c+up,d+up,a+up]),color.darkened(.38),1)
 func _draw() -> void:
  draw_rect(Rect2(-100,-100,2000,1100),Color("222b31"))
  var size:Vector2=layout.world_size()
  var spec:Dictionary=layout.space_spec()
  var floor_points:Array=[layout.project(Vector2.ZERO),layout.project(Vector2(size.x,0)),layout.project(size),layout.project(Vector2(0,size.y))]
  if spec.has("floor_polygon_m"):
   floor_points.clear()
   for p:Array in spec.floor_polygon_m:floor_points.append(layout.project(Vector2(float(p[0]),float(p[1]))))
  poly(floor_points,Color("a8aaa0") if BMap.deep(room) else Color("76686d"))
  for row in range(1,ceili(size.y/.5)):
   var end:float=size.x
   if spec.has("wall_ranges_m") and row*.5<float(spec.wall_ranges_m.east[0]):end=float(spec.wall_ranges_m.north[1])
   draw_line(layout.project(Vector2(0,row*.5)),layout.project(Vector2(end,row*.5)),Color(.3,.35,.35,.18),1)
  view.canvas=self;view.app={"layout":layout,"room_id":room};view.battle={"map":BMap};view.draw_architecture(false)
  var items:Array=layout.furniture+layout.decor
  items.sort_custom(func(a,b):return layout.project((a.rect as Rect2).end).y<layout.project((b.rect as Rect2).end).y)
  for item:Dictionary in items:
   if item.get("logical_exclusion",false):continue
   prism(item.rect,float(item.height),Color("9eaaa4") if BMap.deep(room) else Color("9e8982"))
   draw_string(font,layout.project(item.rect.get_center())-Vector2(0,float(item.height)+8),str(item.name),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e4e2d3"))
  if chapter==4:
   for partition:Dictionary in spec.get("partitions",[]):
    if partition.get("logical_exclusion",false):continue
    var r:Array=partition.rect_m
    prism(Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])),float(partition.height_m)*78,Color("66626b"))
  var foot:Vector2=layout.project(layout.spawn()+Vector2(.3,.3))
  draw_circle(foot,15,Color(0,0,0,.3))
  poly([foot+Vector2(-15,-110),foot+Vector2(15,-110),foot+Vector2(18,-38),foot+Vector2(-18,-38)],Color("8eaeb8"))
  draw_circle(foot-Vector2(0,120.5),16,Color("c2b8a0"))
  for side in [-1,1]:draw_line(foot+Vector2(side*9,-38),foot+Vector2(side*12,0),Color("8eaeb8"),8)
  view.draw_architecture(true)
  for toward in CMap.doors(room) if chapter==4 else BMap.doors(room):
   var portal:Dictionary=layout.portal(str(toward));var at:Vector2=layout.project(portal.at)
   draw_circle(at,8,Color("a8c6b4"));draw_string(font,at+Vector2(10,5),str(toward),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e0e3d5"))
  draw_string(font,Vector2(35,850),"L%d %s | %.1fm x %.1fm | adult1.75m / wall %.2fm x %.2fm | actual Godot geometry, art placeholders"%[chapter,room,size.x,size.y,float(layout.space_spec().wall_thickness_m),float(layout.space_spec().wall_height_m)],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("e2e3db"))
var painter
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1800,940)
 DisplayServer.window_set_size(root.size)
 painter=Painter.new();painter.position.y=30;painter.view=View.new();root.add_child(painter)
 var folder:String="res://../docs/validation/neural_spaces_20261018/render"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for sample:Array in [[4,"atrium"],[4,"memory"],[4,"rhythm"],[5,"thalamus"],[5,"cerebellum"],[5,"hypothalamus"],[5,"amygdala"],[5,"brainstem"]]:
  painter.chapter=int(sample[0]);painter.room=str(sample[1])
  painter.layout=Cortex.new(painter.room,2) if painter.chapter==4 else Combat.new(painter.room,true,3)
  painter.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  var capture:Image=root.get_texture().get_image()
  var error:Error=capture.save_png(folder+"/L%d_%s.png"%[painter.chapter,painter.room])
  if error!=OK:push_error("could not save representative render");quit(1);return
 print("NEURAL_SPATIAL_RENDER 8 actual rendered contract views")
 quit(0)
