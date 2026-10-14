extends Node2D

var app:Node
var layout:RoomLayout
var debug_geometry := false
var font := ThemeDB.fallback_font
const INK := Color("293333")
const ROOM_SHELL := preload("res://assets/environment/bedroom_shell_v001.png")

func poly(points:Array,color:Color) -> void:
 draw_colored_polygon(PackedVector2Array(points),color)

func prism(r:Rect2,h:float,col:Color) -> void:
 var a:=layout.project(r.position)
 var b:=layout.project(r.position+Vector2(r.size.x,0))
 var c:=layout.project(r.end)
 var d:=layout.project(r.position+Vector2(0,r.size.y))
 var up:=Vector2(0,-h)
 poly([a,b,b+up,a+up],col.darkened(0.12))
 poly([b,c,c+up,b+up],col.darkened(0.28))
 poly([c,d,d+up,c+up],col.darkened(0.18))
 poly([a+up,b+up,c+up,d+up],col.lightened(0.16))
 draw_polyline(PackedVector2Array([a+up,b+up,c+up,d+up,a+up]),col.darkened(0.38),1.0)

func _draw() -> void:
 if layout==null or app==null:
  return
 draw_rect(Rect2(-800,-600,2200,1600),Color("222c30"))
 var p0:=layout.project(Vector2.ZERO)
 var p1:=layout.project(Vector2(5.6,0))
 var p2:=layout.project(layout.SIZE)
 var p3:=layout.project(Vector2(0,3.8))
 poly([p0+Vector2(-10,3),p1+Vector2(10,3),p2+Vector2(12,15),p3+Vector2(-10,15)],Color("172125"))
 poly([p0,p1,p2,p3],Color("b6a483"))
 # Room surfaces are independent of all movable objects.
 for y in range(20):
  var z:=float(y)*0.2
  draw_line(layout.project(Vector2(0,z)),layout.project(Vector2(5.6,z)),Color("a59475"),0.6)
  for x in range(6):
   var xx:=float(x)+0.5*float(y%2)
   draw_line(layout.project(Vector2(xx,z)),layout.project(Vector2(xx,z+0.2)),Color("a08e71"),0.5)
 poly([p0,p1,p1+Vector2(0,-84),p0+Vector2(0,-84)],Color("b0b1a1"))
 poly([p0,p3,p3+Vector2(0,-84),p0+Vector2(0,-84)],Color("c6c1ae"))
 draw_line(p0+Vector2(0,-4),p1+Vector2(0,-4),Color("6d7067"),4)
 draw_line(p0+Vector2(0,-4),p3+Vector2(0,-4),Color("898977"),4)
 # The opaque source is retained. Only this geometric silhouette is rendered;
 # alpha/color threshold processing never removes pale painted material.
 var outline:=PackedVector2Array([p0+Vector2(0,-84),p1+Vector2(0,-84),p1,p2,p3,p0])
 var uv:=PackedVector2Array()
 for point in outline:
  uv.append(point/Vector2(640,360))
 draw_polygon(outline,PackedColorArray([Color.WHITE]),uv,ROOM_SHELL)
 var door:=layout.project(Vector2(4.28,0))
 var door_color:=Color("6f6250") if app.scenario!=2 else Color("734e48")
 draw_rect(Rect2(door+Vector2(0,-76),Vector2(69,76)),door_color)
 draw_rect(Rect2(door+Vector2(5,-70),Vector2(58,66)),door_color.lightened(0.12),false,2)
 draw_circle(door+Vector2(56,-34),2,Color("c7b68b"))
 # Southern window represented as a low cutaway sill, no new exit.
 var win:=layout.project(Vector2(3.9,3.8))
 draw_line(win,win+Vector2(60,0),Color("a6c4c3"),4)
 poly([layout.project(Vector2(2.95,1.8)),layout.project(Vector2(4.2,1.8)),layout.project(Vector2(3.8,3.7)),layout.project(Vector2(2.6,3.7))],Color(0.94,0.88,0.67,0.16))
 var ordered:Array[Dictionary]=[]
 for f in layout.furniture:
  ordered.append({"type":"furniture","data":f,"depth":layout.project((f.rect as Rect2).end).y})
 ordered.append({"type":"actor","data":"hero","depth":layout.project(app.hero_pos).y})
 if app.scenario in [1,2,3]:
  ordered.append({"type":"actor","data":"npc","depth":layout.project(app.npc_pos).y})
 ordered.sort_custom(func(a,b):return a.depth<b.depth)
 for entry in ordered:
  if entry.type=="furniture":
   draw_furniture(entry.data)
  else:
   draw_actor(entry.data)
 if app.target_index>=0:
  var target:Dictionary=layout.furniture[app.target_index]
  var point:=layout.project(target.at)
  draw_arc(point,7,0,TAU,24,Color("d6c493"),1)
  if app.rules.search_active:
   draw_arc(point,9,-PI/2,-PI/2+TAU*app.rules.search_elapsed/app.rules.search_duration,36,Color("9ac3b4"),2)
 if debug_geometry:
  for f in layout.furniture:
   var r:Rect2=f.rect
   var pts:=PackedVector2Array([layout.project(r.position),layout.project(r.position+Vector2(r.size.x,0)),layout.project(r.end),layout.project(r.position+Vector2(0,r.size.y)),layout.project(r.position)])
   draw_polyline(pts,Color(1,0.3,0.3,0.8),1)
  for p in app.hero_route:
   draw_circle(layout.project(p),1.1,Color("84ddbd"))
  draw_circle(layout.project(app.hero_pos),4,Color("efbe78"),false,1)

func draw_furniture(f:Dictionary) -> void:
 var r:Rect2=f.rect
 var center:=layout.project(r.get_center())
 var h:float=f.height
 var col:Color=f.color
 if f.kind=="fan":
  draw_set_transform(center)
  draw_circle(Vector2.ZERO,9,col.darkened(0.3))
  draw_line(Vector2.ZERO,Vector2(0,-h+12),col,3)
  draw_circle(Vector2(0,-h+12),13,Color("2f464b"))
  for i in range(3):
   var angle:float=app.world_visual_time*5+TAU*i/3.0
   draw_line(Vector2(0,-h+12),Vector2(cos(angle)*11,sin(angle)*11-h+12),col,3)
  draw_arc(Vector2(0,-h+12),13,0,TAU,28,col.lightened(0.3),1.2)
  draw_set_transform(Vector2.ZERO)
 elif f.kind=="rack":
  draw_line(center,center+Vector2(0,-h),Color("725c48"),3)
  draw_line(center+Vector2(-10,0),center+Vector2(10,0),Color("725c48"),3)
  draw_line(center+Vector2(-12,-h+9),center+Vector2(12,-h+9),Color("725c48"),3)
  poly([center+Vector2(2,-h+7),center+Vector2(15,-h+12),center+Vector2(19,-16),center+Vector2(0,-18)],Color("d9d9cd"))
 elif f.kind=="bed":
  prism(r,13,Color("80664b"))
  prism(r.grow(-0.06),h,col)
  prism(Rect2(r.position+Vector2(0.07,0.08),Vector2(0.4,r.size.y-0.16)),h+4,Color("d8cfb6"))
  var a:=layout.project(r.position+Vector2(0.65,0.06))+Vector2(0,-h-1)
  var b:=layout.project(r.position+Vector2(0.65,r.size.y-0.06))+Vector2(0,-h-1)
  draw_line(a,b,Color("b2bcb5"),4)
 elif f.kind=="desk" or f.kind=="chair" or f.kind=="stool":
  for corner in [r.position,r.end,r.position+Vector2(r.size.x,0),r.position+Vector2(0,r.size.y)]:
   var p:=layout.project(corner)
   draw_line(p,p+Vector2(0,-h),col.darkened(0.3),3)
  prism(r,h,col)
  if f.kind=="desk":
   var p:=center+Vector2(-20,-h-2)
   poly([p,p+Vector2(18,0),p+Vector2(24,7),p+Vector2(6,7)],Color("e3ddc5"))
   draw_line(p+Vector2(10,1),p+Vector2(16,6),Color("777968"),1)
  if f.kind=="chair":
   draw_line(center+Vector2(-11,-h),center+Vector2(-11,-h-18),col,3)
   draw_line(center+Vector2(8,-h),center+Vector2(8,-h-18),col,3)
   draw_line(center+Vector2(-11,-h-17),center+Vector2(8,-h-17),col,7)
  if f.kind=="stool":
   prism(r.grow(-0.06),h+9,Color("b69c71"))
 else:
  prism(r,h,col)
  var front:=layout.project(r.position+Vector2(0,r.size.y))
  var end:=layout.project(r.end)
  if f.kind=="books":
   for level in range(5):
    var yy:float=-10-level*11
    draw_line(front+Vector2(2,yy),end+Vector2(-2,yy),col.darkened(0.45),2)
    for book in range(5):
     var x:float=4+book*7
     draw_line(front+Vector2(x,yy-1),front+Vector2(x,yy-8),[Color("596c72"),Color("c4ad83"),Color("8d6558")][book%3],4)
  elif f.kind=="wardrobe":
   var middle:Vector2=(front+end)/2
   draw_line(middle+Vector2(0,-h+3),middle+Vector2(0,-3),col.darkened(0.4),1)
   draw_circle(middle+Vector2(-4,-h/2),1.5,Color("cab48b"))
   draw_circle(middle+Vector2(4,-h/2),1.5,Color("cab48b"))
  elif f.kind=="drawer":
   for level in range(2):
    var yy:float=-h*0.3-level*h*0.45
    var shift:=Vector2.ZERO
    shift=Vector2(0,3*float(app.drawer_open.get(f.id,0.0)))
    draw_line(front+Vector2(2,yy)+shift,end+Vector2(-2,yy)+shift,col.darkened(0.4),1)
    draw_line((front+end)/2+Vector2(-4,yy-4)+shift,(front+end)/2+Vector2(4,yy-4)+shift,Color("d2c3a3"),2)
 if debug_geometry:
  draw_string(font,center+Vector2(-10,13),f.name,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e8e0c8"))

func draw_actor(who:String) -> void:
 var p:Vector2=app.hero_pos if who=="hero" else app.npc_pos
 var center:=layout.project(p)
 var role:String="hero" if who=="hero" else ["","mother","father","cat"][app.scenario]
 var phase:float=app.world_visual_time
 var moving:bool=(app.hero_route.size()>0) if who=="hero" else app.npc_moving
 var state:String=app.hero_state if who=="hero" else app.npc_state
 var col:Color={"hero":Color("6d8282"),"mother":Color("a07568"),"father":Color("565b60"),"cat":Color("303239")}[role]
 draw_set_transform(center)
 draw_set_transform(center,0,Vector2(1,0.35))
 draw_circle(Vector2.ZERO,10,Color(0.08,0.1,0.1,0.3))
 var facing:Vector2=app.hero_facing if who=="hero" else app.npc_facing
 draw_set_transform(center,0,Vector2(-1 if facing.x<0 else 1,1))
 if role=="cat":
  draw_circle(Vector2(0,-7),8,col)
  draw_circle(Vector2(7,-15),6,col)
  poly([Vector2(3,-18),Vector2(3,-24),Vector2(8,-20)],col)
  poly([Vector2(9,-20),Vector2(14,-24),Vector2(13,-16)],col)
  draw_circle(Vector2(10,-15),1,Color("d2bd75"))
  draw_arc(Vector2(-8,-9),7,PI*0.3,PI*1.5,10,col,3)
 else:
  var stride:float=sin(phase*11)*4 if moving else 0.0
  var bend:float=0.0
  if state=="search":
   bend=7+sin(phase*4)*2
  if state=="scratch":
   bend=sin(phase*42)*1.5
  if state=="hit":
   bend=-7.0
  draw_line(Vector2(-5,-21),Vector2(-5+stride,-3),col.darkened(0.2),7)
  draw_line(Vector2(5,-21),Vector2(5-stride,-3),col.darkened(0.35),7)
  draw_line(Vector2(-8+stride,-2),Vector2(-1+stride,-2),INK,4)
  draw_line(Vector2(2-stride,-2),Vector2(9-stride,-2),INK,4)
  poly([Vector2(-9,-42+bend),Vector2(8,-42+bend),Vector2(11,-20),Vector2(-9,-20)],col)
  if role=="mother":
   poly([Vector2(-5,-38+bend),Vector2(6,-38+bend),Vector2(9,-21),Vector2(-8,-21)],Color("cec0a1"))
   for i in range(3):draw_circle(Vector2(-3+4*(i%2),-28-i*3),1,Color("8d6e63"))
  var head:=Vector2(bend*0.5,-49+bend)
  draw_circle(head,8,Color("c5b49b"))
  draw_arc(head,8,PI,TAU+0.3,12,Color("434442") if role=="hero" else Color("654b41"),5)
  draw_line(head+Vector2(1,0),head+Vector2(4,0),INK,1)
  if role=="father":
   draw_rect(Rect2(head+Vector2(-5,-2),Vector2(11,5)),Color("7d664e"),false,1)
  var hand:Vector2=Vector2(12,-25+bend)
  if state in ["search","give","grab"]:hand=Vector2(20,-31+bend+sin(phase*5)*2)
  if state=="scratch":hand=Vector2(4+sin(phase*30)*3,-38)
  if (app.scenario==1 and app.scene_phase=="mother_give") or (app.grabbed and app.scene_phase!="startle_escape"):
   var shared:Vector2=(layout.project(app.hero_pos)+layout.project(app.npc_pos))*0.5+Vector2(0,-28)
   hand=(shared-center)*Vector2(-1 if facing.x<0 else 1,1)
  draw_line(Vector2(7,-39+bend),hand,col.lightened(0.1),5)
  draw_circle(hand,2.8,Color("c5b49b"))
  draw_line(Vector2(-7,-39+bend),Vector2(-10,-24+bend),col.darkened(0.1),5)
  # The movable bowl is drawn only on its current owner.
  var owner:String=app.rules.owners.get("porridge","")
  if (role=="mother" and owner=="mother" and app.scenario==1) or (role=="hero" and owner=="hero"):
   draw_bowl(hand+Vector2(3,-1))
 if who=="hero":
  draw_circle(Vector2(0,-66),2,Color("b3d2bc"))
 if debug_geometry:
  draw_circle(Vector2.ZERO,3,Color("ff8c77"),false,1)
 draw_set_transform(Vector2.ZERO)

func draw_bowl(p:Vector2) -> void:
 poly([p+Vector2(-6,-2),p+Vector2(6,-2),p+Vector2(4,4),p+Vector2(-4,4)],Color("dedfce"))
 draw_line(p+Vector2(-6,-2),p+Vector2(6,-2),Color("b6a17a"),2)
