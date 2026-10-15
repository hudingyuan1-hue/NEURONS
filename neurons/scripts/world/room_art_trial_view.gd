extends "res://scripts/world/room_view.gd"
## Isolated candidate slice: painted parts, not a full-room overlay.
const FRAME=preload("res://assets/environment/bedside_trial_v001/cabinet_frame.png")
const FACE=preload("res://assets/environment/bedside_trial_v001/drawer_face.png")
const TRAY=preload("res://assets/environment/bedside_trial_v001/drawer_tray.png")
const FORE=preload("res://assets/environment/bedside_trial_v001/foreground_rail_v002.png")
const BOOK=preload("res://assets/environment/bedside_trial_v001/book.png")
const CLOCK=preload("res://assets/environment/bedside_trial_v001/alarm_clock.png")
const BED_EDGE=preload("res://assets/environment/bedside_trial_v001/bed_edge.png")
const ANCHOR=Vector2(8,40)
const HANDLE=Vector2(60.7394,25.7744)
var book_shift:=Vector2.ZERO
var clock_shift:=Vector2.ZERO

func art_origin() -> Vector2:
 return layout.project(layout.furniture[1].rect.position).round()-ANCHOR

func draw_layer(texture:Texture2D,offset:Vector2=Vector2.ZERO) -> void:
 # Explicit top-left destination and shared floor anchor. Mirrors the rect/
 # offset handling reviewed in Godot 4.7 Sprite2D::_get_rects; no bbox recentering.
 var rect:=Rect2(art_origin()+offset,texture.get_size())
 draw_texture_rect_region(texture,rect,Rect2(Vector2.ZERO,texture.get_size()),Color.WHITE,false,true)

func bedside_handle() -> Vector2:
 return art_origin()+HANDLE+Vector2(7*float(app.drawer_open.get("bedside",0)),0).round()

func bedside_hand() -> Vector2:
 var start:=layout.project(app.hero_pos)+Vector2(-12,-25)
 return start.lerp(bedside_handle(),clampf(app.rules.search_elapsed/0.18,0,1))

func draw_bedside(_f:Dictionary) -> void:
 var origin:=art_origin()
 var opening:float=float(app.drawer_open.get("bedside",0))
 var delta:=Vector2(roundf(7*opening),0)
 # Fixed cabinet contact shadow; moving drawer shadow is its own local pass.
 var r:Rect2=layout.furniture[1].rect
 var shadow:=PackedVector2Array([layout.project(r.position)+Vector2(1,1),layout.project(r.position+Vector2(r.size.x,0))+Vector2(2,1),layout.project(r.end)+Vector2(4,2),layout.project(r.position+Vector2(0,r.size.y))+Vector2(2,2)])
 draw_colored_polygon(shadow,Color(0.08,0.1,0.1,0.2))
 draw_layer(FRAME)
 # Empty well is fully painted into FRAME. Tray top is visible only in swept
 # space; neither closed face nor static moving-part shadow exists behind it.
 if delta.x>0:
  var a:=origin+Vector2(55.1742,11.8642)
  var b:=origin+Vector2(66.3666,30.4515)
  draw_polygon(PackedVector2Array([a,b,b+delta,a+delta]),PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),TRAY)
  draw_line(b+Vector2(0,9),b+delta+Vector2(0,9),Color(0.1,0.09,0.07,0.3),2)
 draw_layer(FACE,delta)
 draw_layer(BOOK,book_shift)
 draw_layer(CLOCK,clock_shift)
 draw_layer(FORE)

func draw_furniture(f:Dictionary) -> void:
 if f.id=="bedside":
  draw_bedside(f)
  if debug_geometry:
   draw_string(font,layout.project(f.rect.get_center())+Vector2(0,15),"试接入 / 柜体+抽屉",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e8e0c8"))
  return
 super.draw_furniture(f)
 if f.id=="bed":
  # Only neighboring south bed edge. Mattress/head/pillow stay labelled greybox.
  var r:Rect2=f.rect
  var p:=layout.project(r.position+Vector2(0,r.size.y)).round()
  draw_texture_rect(BED_EDGE,Rect2(p+Vector2(-3,-33),Vector2(178,36)),false)

func _draw() -> void:
 super._draw()
 # The existing greybox pose is retained. Repaint just the contacting hand over
 # the drawer at its measured handle, then preserve the lower foreground rail.
 if bedside_contact():
  var hand:=bedside_hand()
  var shoulder:=layout.project(app.hero_pos)+Vector2(-7,-32)
  draw_line(shoulder,hand,Color("7e9291"),4)
  draw_circle(hand,2,Color("c5b49b"))
  draw_layer(FORE)
