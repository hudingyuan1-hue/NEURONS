extends RefCounted
const Materials=preload("res://scripts/world/spatial_materials.gd")
const ProductionProps=preload("res://scripts/world/production_props.gd")
static var _current_material:String="furniture_wood"
## Read-only recognisable structural placeholders, not a cuboid per object.
## A rect is a footprint envelope, never a requirement for a rectangular outline.
static func _p(layout,p:Vector2,h:float) -> Vector2:return layout.project(p)-Vector2(0,h)
static func _oval(rect:Rect2,segments:int=24) -> PackedVector2Array:
 var ring:=PackedVector2Array()
 for i in range(segments):ring.append(rect.get_center()+Vector2(cos(TAU*i/segments)*rect.size.x*.5,sin(TAU*i/segments)*rect.size.y*.5))
 return ring
static func _face(canvas,layout,ring:PackedVector2Array,height:float,tone:Color,bottom:float=0) -> void:
 if Materials.enabled():
  Materials.prop_face(canvas,layout,ring,height,tone,_current_material,bottom)
  return
 var top:=PackedVector2Array()
 for p in ring:top.append(_p(layout,p,height))
 # Only camera-facing walls of the shape. No rectangular box is added beneath.
 for i in range(ring.size()):
  var a:Vector2=ring[i];var b:Vector2=ring[(i+1)%ring.size()];var d:Vector2=b-a
  if Vector2(d.y,-d.x).dot(Vector2(-6,56))<=0:continue
  canvas.draw_colored_polygon(PackedVector2Array([_p(layout,a,bottom),_p(layout,b,bottom),_p(layout,b,height),_p(layout,a,height)]),tone.darkened(.2))
 canvas.draw_colored_polygon(top,tone)
 if top.size()>1:top.append(top[0]);canvas.draw_polyline(top,tone.darkened(.3),.8,true)
static func _quad(rect:Rect2) -> PackedVector2Array:return PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
static func _top(canvas,layout,rect:Rect2,h:float,tone:Color) -> void:
 var points:=PackedVector2Array()
 for p in _quad(rect):points.append(_p(layout,p,h))
 if not Materials.draw_polygon(canvas,points,_quad(rect),_current_material,tone):canvas.draw_colored_polygon(points,tone)
static func _legs(canvas,layout,r:Rect2,h:float,tone:Color) -> void:
 for x in [.12,.88]:
  for z in [.16,.84]:
   var p:Vector2=r.position+Vector2(r.size.x*x,r.size.y*z)
   canvas.draw_line(_p(layout,p,0),_p(layout,p,h),tone.darkened(.36),3,true)

static func _vertical_panel(canvas,layout,a:Vector2,b:Vector2,bottom:float,top:float,tone:Color,material:String="") -> void:
 var points:=PackedVector2Array([_p(layout,a,bottom),_p(layout,b,bottom),_p(layout,b,top),_p(layout,a,top)])
 var coords:=PackedVector2Array([Vector2(a.x+a.y,-bottom/78),Vector2(b.x+b.y,-bottom/78),Vector2(b.x+b.y,-top/78),Vector2(a.x+a.y,-top/78)])
 if not Materials.draw_polygon(canvas,points,coords,_current_material if material.is_empty() else material,tone,.88):canvas.draw_colored_polygon(points,tone)

static func _bookcase(canvas,layout,r:Rect2,h:float,tone:Color) -> void:
 var saved:String=_current_material;_current_material="furniture_wood"
 var front_west:bool=r.size.y>r.size.x
 var width:float=r.size.y if front_west else r.size.x
 var depth:float=r.size.x if front_west else r.size.y
 var side:float=minf(.085,width*.1)
 if front_west:
  _face(canvas,layout,_quad(Rect2(r.position,Vector2(r.size.x,side))),h,tone)
  _face(canvas,layout,_quad(Rect2(r.position+Vector2(0,r.size.y-side),Vector2(r.size.x,side))),h,tone)
  _vertical_panel(canvas,layout,Vector2(r.end.x-.025,r.position.y+side),r.end-Vector2(.025,side),4,h-3,tone.darkened(.24))
 else:
  _face(canvas,layout,_quad(Rect2(r.position,Vector2(side,r.size.y))),h,tone)
  _face(canvas,layout,_quad(Rect2(r.position+Vector2(r.size.x-side,0),Vector2(side,r.size.y))),h,tone)
  _vertical_panel(canvas,layout,r.position+Vector2(side,.035),r.position+Vector2(r.size.x-side,.035),4,h-3,tone.darkened(.24))
 var levels:int=maxi(2,mini(5,int(h/30)))
 for shelf in range(levels+1):
  var level:float=5+shelf*(h-5)/levels
  _face_at_height(canvas,layout,_quad(r),level-3,level,tone)
  if shelf>=levels:continue
  var count:int=maxi(3,mini(9,int(width/.16)))
  for index in range(count):
   var step:float=(width-side*2)/count
   var at:Vector2=r.position+(Vector2(depth*.05,side+index*step) if front_west else Vector2(side+index*step,depth*.28))
   var book:Rect2=Rect2(at,Vector2(depth*.7,step*.72) if front_west else Vector2(step*.72,depth*.65))
   var height:float=(h-5)/levels*(.65+.1*sin(index*2.7+shelf))
   var color:Color=[Color("65797f"),Color("998366"),Color("8a655c"),Color("9c9e8b")][(index+shelf)%4]
   _current_material="aged_paper";_face_at_height(canvas,layout,_quad(book),level+1,level+height,color)
   var a:Vector2=book.position if front_west else book.position+Vector2(0,book.size.y)
   var b:Vector2=book.position+Vector2(0,book.size.y) if front_west else book.end
   _vertical_panel(canvas,layout,a,b,level+1,level+height,color)
   canvas.draw_line(_p(layout,a,level+height*.82),_p(layout,b,level+height*.82),color.lightened(.3),.8,true)
  _current_material="furniture_wood"
 _current_material=saved

static func _bed(canvas,layout,r:Rect2,h:float,tone:Color) -> void:
 var frame:String="painted_metal" if Materials.context(layout)=="institution" else "furniture_wood"
 _current_material=frame;_legs(canvas,layout,r,h-8,tone)
 _face_at_height(canvas,layout,_quad(r),maxf(5,h-15),h-8,tone.darkened(.15))
 _current_material="ivory_fabric"
 var mattress:Rect2=r.grow(-minf(.065,r.size.x*.06))
 _face_at_height(canvas,layout,_quad(mattress),h-8,h+2,Color("c9ccbb"))
 var along_y:bool=r.size.y>=r.size.x
 var pillow:Rect2=Rect2(mattress.position+Vector2(.05,.05),Vector2(mattress.size.x-.1,minf(.37,mattress.size.y*.25))) if along_y else Rect2(mattress.position+Vector2(.05,.05),Vector2(minf(.37,mattress.size.x*.25),mattress.size.y-.1))
 _face_at_height(canvas,layout,_oval(pillow,16),h+2,h+7,Color("d4cfb7"))
 var blanket:Rect2=Rect2(mattress.position+Vector2(0,mattress.size.y*.33),Vector2(mattress.size.x,mattress.size.y*.67)) if along_y else Rect2(mattress.position+Vector2(mattress.size.x*.33,0),Vector2(mattress.size.x*.67,mattress.size.y))
 _face_at_height(canvas,layout,_quad(blanket),h+2,h+4,Color("8c9c9d"))
 _current_material=frame
 var a:Vector2=r.position;var b:Vector2=r.position+Vector2(r.size.x,0) if along_y else r.position+Vector2(0,r.size.y)
 _vertical_panel(canvas,layout,a,b,h-3,h+25,tone)
 for p:Vector2 in [a,b]:canvas.draw_line(_p(layout,p,0),_p(layout,p,h+27),tone.darkened(.25),3,true)
 var shift:=Vector2(0,r.size.y) if along_y else Vector2(r.size.x,0)
 _vertical_panel(canvas,layout,a+shift,b+shift,h-3,h+12,tone)

static func _basin(canvas,layout,r:Rect2,h:float,tone:Color,toilet:bool=false) -> void:
 _current_material="painted_metal"
 if toilet:
  _face(canvas,layout,_oval(r.grow(-minf(.09,r.size.x*.12))),h*.5,tone)
  _face_at_height(canvas,layout,_oval(r),h*.45,h*.62,Color("c8c9b6"))
  var tank:=Rect2(r.position,Vector2(r.size.x,r.size.y*.28))
  _face(canvas,layout,_quad(tank),h,tone)
 else:
  _legs(canvas,layout,r,h-7,tone)
  _face_at_height(canvas,layout,_oval(r,28),h-7,h,tone)
 var bowl:Rect2=Rect2(r.position+r.size*Vector2(.15,.24),r.size*Vector2(.7,.62))
 var points:=PackedVector2Array()
 for p:Vector2 in _oval(bowl):points.append(_p(layout,p,h*.62+1 if toilet else h+1))
 canvas.draw_colored_polygon(points,Color("4b6061"))
 points.append(points[0]);canvas.draw_polyline(points,Color("c2c9ba"),2,true)
 if not toilet:
  var tap:Vector2=_p(layout,r.position+Vector2(r.size.x*.5,r.size.y*.12),h)
  canvas.draw_polyline(PackedVector2Array([tap,tap+Vector2(0,-14),tap+Vector2(11,-14),tap+Vector2(11,-7)]),Color("b7c3bc"),3,true)
  var drain:Vector2=_p(layout,r.get_center(),h-8)
  canvas.draw_polyline(PackedVector2Array([drain,drain+Vector2(0,20),drain+Vector2(-12,20),drain+Vector2(-12,9)]),tone.darkened(.15),4,true)

static func _bag(canvas,layout,r:Rect2,h:float,tone:Color) -> void:
 var points:=PackedVector2Array();var center:Vector2=_p(layout,r.get_center(),0);var width:float=maxf(14,r.size.x*38)
 for v:Vector2 in [Vector2(-.7,0),Vector2(-1,-.2),Vector2(-.82,-.72),Vector2(-.35,-1),Vector2(.35,-1),Vector2(.9,-.78),Vector2(1,-.24),Vector2(.65,.04)]:points.append(center+Vector2(v.x*width,v.y*h))
 var uv:=PackedVector2Array()
 for p:Vector2 in points:uv.append((p-center)/78)
 if not Materials.draw_polygon(canvas,points,uv,"ivory_fabric",tone,.83):canvas.draw_colored_polygon(points,tone)
 canvas.draw_line(center+Vector2(-width*.35,-h),center+Vector2(width*.35,-h),tone.darkened(.32),4,true)
 canvas.draw_arc(center-Vector2(0,h),width*.3,PI,TAU,16,tone.darkened(.25),2,true)

static func draw(canvas,layout,item:Dictionary,tone:Color=Color("84968c")) -> void:
 if not item.get("render",true):return
 if ProductionProps.draw(canvas,layout,item,{},tone.a):return
 if item.has("collision_rects"):
  for rect:Rect2 in item.collision_rects:
   var piece:Dictionary=item.duplicate();piece.erase("collision_rects");piece.rect=rect;draw(canvas,layout,piece,tone)
  return
 var r:Rect2=item.rect;var h:float=maxf(1,float(item.get("height",float(item.get("height_m",.6))*78)))
 var kind:String=str(item.get("kind",""));var name:String=str(item.get("name",""));var center:Vector2=r.get_center()
 _current_material=Materials.prop_id(kind,name)
 if kind in ["bed","exam_bed"] or name.contains("病床"):
  _bed(canvas,layout,r,h,tone);return
 if kind in ["books","shelf","material_rack"] or name.contains("书架"):
  _bookcase(canvas,layout,r,h,tone);return
 if kind in ["sink","toilet"]:
  _basin(canvas,layout,r,h,tone,kind=="toilet");return
 if kind=="bag":
  _bag(canvas,layout,r,h,tone);return
 if kind in ["lamp","wall_lamp"]:
  _face(canvas,layout,_oval(r),4,tone.darkened(.3))
  var at:Vector2=_p(layout,center,h*.72)
  canvas.draw_line(_p(layout,center,4),at,tone.darkened(.3),3,true)
  var width:float=maxf(10,minf(29,r.size.x*38))
  var shade:=PackedVector2Array([at+Vector2(-width,4),at+Vector2(-width*.55,-h*.25),at+Vector2(width*.55,-h*.25),at+Vector2(width,4)])
  canvas.draw_colored_polygon(shade,Color("c8ba90"));canvas.draw_line(shade[0],shade[3],Color("dbcca3"),2,true);return
 if kind=="bin":
  _face(canvas,layout,_oval(r),h,tone)
  var rim:=PackedVector2Array()
  for p:Vector2 in _oval(r.grow(-minf(.07,r.size.x*.1))):rim.append(_p(layout,p,h+1))
  canvas.draw_colored_polygon(rim,tone.darkened(.52));rim.append(rim[0]);canvas.draw_polyline(rim,tone.lightened(.2),2,true);return
 if kind=="sofa":
  _current_material="furniture_wood";_legs(canvas,layout,r,12,tone)
  _current_material="ivory_fabric"
  _face_at_height(canvas,layout,_quad(r),12,h*.55,tone)
  var arm:float=minf(.18,r.size.x*.12)
  _face_at_height(canvas,layout,_quad(Rect2(r.position,Vector2(arm,r.size.y))),h*.5,h*.78,tone)
  _face_at_height(canvas,layout,_quad(Rect2(r.position+Vector2(r.size.x-arm,0),Vector2(arm,r.size.y))),h*.5,h*.78,tone)
  _vertical_panel(canvas,layout,r.position,r.position+Vector2(r.size.x,0),h*.45,h,tone)
  for i in range(2):
   var cushion:=Rect2(r.position+Vector2(arm+i*(r.size.x-arm*2)*.5,.12),Vector2((r.size.x-arm*2)*.48,r.size.y-.17))
   _face_at_height(canvas,layout,_quad(cushion),h*.55,h*.65,tone.lightened(.08))
  return
 if kind in ["rubble","debris"]:
  _current_material="concrete"
  for i in range(7):
   var at:Vector2=r.position+r.size*Vector2(.12+.12*i,.25+.4*absf(sin(i*2.1)))
   var size:Vector2=r.size*Vector2(.12,.14)
   var ring:=PackedVector2Array([at,at+Vector2(size.x,0),at+size,at+Vector2(-size.x*.2,size.y*.8)])
   _face(canvas,layout,ring,maxf(2,minf(h,12)*(1+sin(i))*.5),tone.lightened(.03*(i%3)))
  return
 if kind=="gate":
  _current_material="painted_metal"
  var a:Vector2=r.position if r.size.y>r.size.x else r.position+Vector2(0,r.size.y*.5)
  var b:Vector2=r.position+Vector2(0,r.size.y) if r.size.y>r.size.x else a+Vector2(r.size.x,0)
  for i in range(9):
   var p:Vector2=a.lerp(b,float(i)/8);canvas.draw_line(_p(layout,p,0),_p(layout,p,h),tone.darkened(.15),2.5,true)
  for level in [.1,.8,1.0]:canvas.draw_line(_p(layout,a,h*level),_p(layout,b,h*level),tone,3,true)
  return
 if kind=="case":
  _current_material="furniture_wood";_legs(canvas,layout,r,h*.45,tone)
  _face_at_height(canvas,layout,_quad(r),h*.45,h*.52,tone)
  var points:=PackedVector2Array();var coords:=PackedVector2Array()
  for p:Vector2 in _quad(r):points.append(_p(layout,p,h));coords.append(p)
  var glass:Color=Color(.6,.72,.7,.28)
  Materials.draw_polygon(canvas,points,coords,"smoky_glass",glass)
  for i in range(4):
   var a:Vector2=_quad(r)[i];var b:Vector2=_quad(r)[(i+1)%4]
   canvas.draw_line(_p(layout,a,h),_p(layout,b,h),tone.lightened(.2),1.5,true)
   canvas.draw_line(_p(layout,a,h*.52),_p(layout,a,h),tone.lightened(.1),2,true)
  return
 if kind=="recorder":
  _current_material="painted_metal";_face(canvas,layout,_quad(r.grow(-minf(.05,r.size.x*.1))),minf(h,25),tone)
  var at:Vector2=_p(layout,center,minf(h,25)+1)
  for side in [-1,1]:
   canvas.draw_circle(at+Vector2(side*9,0),7,tone.darkened(.4));canvas.draw_arc(at+Vector2(side*9,0),5,0,TAU,18,Color("a1aaa2"),1,true)
  canvas.draw_line(at+Vector2(-10,7),at+Vector2(12,7),Color("b5b4a3"),2,true);return
 if kind in ["rack","sign","panel"]:
  var at:Vector2=_p(layout,center,h)
  _legs(canvas,layout,r,minf(h,30),tone)
  if kind=="rack":
   canvas.draw_line(_p(layout,center,0),at,tone.darkened(.3),4,true)
   for i in range(3):
    var hook:Vector2=at+Vector2((i-1)*16,10+abs(i-1)*7)
    canvas.draw_polyline(PackedVector2Array([hook+Vector2(-4,-9),hook,at+Vector2(0,28)]),tone.darkened(.15),3,true)
  else:_vertical_panel(canvas,layout,r.position,r.position+Vector2(r.size.x,0),h*.35,h,tone)
  return
 if kind=="floor":return
 if any_word(name+str(item.get("silhouette_note","")),["脑回","折叶"]):
  _current_material="cortical_fibers"
  # Thin curved leaves with visible gaps, not a solid extrusion of the envelope.
  for leaf in range(5):
   var ring:=PackedVector2Array();var x:float=r.position.x+r.size.x*(.08+.2*leaf)
   var thickness:float=minf(.09,r.size.x*.04)
   for i in range(13):
    var t:float=float(i)/12;ring.append(Vector2(x+r.size.x*.045*sin(t*PI),r.position.y+r.size.y*(.06+.88*t)))
   for i in range(12,-1,-1):
    var t:float=float(i)/12;ring.append(Vector2(x+thickness+r.size.x*.045*sin(t*PI),r.position.y+r.size.y*(.06+.88*t)))
   _face(canvas,layout,ring,h*(.88+.12*sin(leaf)),tone.lightened(.025*leaf))
  return
 if any_word(name+str(item.get("silhouette_note","")),["U形","U型","U字"]):
  var band:float=minf(r.size.x*.24,r.size.y*.3)
  for part:Rect2 in [Rect2(r.position,Vector2(r.size.x,band)),Rect2(r.position,Vector2(band,r.size.y)),Rect2(r.position+Vector2(r.size.x-band,0),Vector2(band,r.size.y))]:
   _legs(canvas,layout,part,h-6,tone);_face(canvas,layout,_quad(part),h,tone,h-6)
  return
 if kind in ["pit","drain","puddle"]:
  var ring:PackedVector2Array=_oval(r);var points:=PackedVector2Array()
  for p in ring:points.append(_p(layout,p,1))
  if kind!="pit":canvas.draw_colored_polygon(points,tone.darkened(.5))
  points.append(points[0]);canvas.draw_polyline(points,tone.lightened(.12),2,true)
  return
 if kind in ["pipe","railing"]:
  var along_x:bool=r.size.x>=r.size.y
  var from:Vector2=r.position+Vector2(0,r.size.y*.5) if along_x else r.position+Vector2(r.size.x*.5,0)
  var to:Vector2=from+Vector2(r.size.x,0) if along_x else from+Vector2(0,r.size.y)
  for i in range(5):
   var p:Vector2=from.lerp(to,float(i)/4)
   canvas.draw_line(_p(layout,p,0),_p(layout,p,h),tone.darkened(.2),3,true)
  canvas.draw_line(_p(layout,from,h),_p(layout,to,h),tone,5 if kind=="pipe" else 3,true)
  canvas.draw_line(_p(layout,from,h*.5),_p(layout,to,h*.5),tone.darkened(.12),2,true)
  return
 if kind in ["wall","facade","shower"]:
  _face(canvas,layout,_quad(r),h,tone);return
 if kind in ["fountain","statue"]:
  _current_material="concrete"
  _face(canvas,layout,_oval(r),minf(15,h*.22),tone)
  var basin:=PackedVector2Array()
  for p:Vector2 in _oval(r.grow(-minf(.22,r.size.x*.14))):basin.append(_p(layout,p,minf(16,h*.22)+1))
  canvas.draw_colored_polygon(basin,Color("536e70"));basin.append(basin[0]);canvas.draw_polyline(basin,Color("b2b7a2"),2,true)
  var pedestal:=Rect2(center-r.size*.09,r.size*.18)
  _face(canvas,layout,_quad(pedestal),h*.6,tone.darkened(.15))
  var at:Vector2=_p(layout,center,h*.6);var figure:=PackedVector2Array()
  for v:Vector2 in [Vector2(-.15,0),Vector2(-.12,-.32),Vector2(-.3,-.57),Vector2(-.16,-.62),Vector2(-.08,-.44),Vector2(-.1,-.75),Vector2(.1,-.75),Vector2(.15,-.43),Vector2(.31,-.62),Vector2(.38,-.58),Vector2(.24,-.3),Vector2(.14,0)]:figure.append(at+v*h*.6)
  canvas.draw_colored_polygon(figure,tone.darkened(.12));canvas.draw_circle(at-Vector2(0,h*.53),h*.075,tone)
  return
 if kind in ["plant","tree","organic","core","node","fountain","pedestal"] or any_word(name,["核心","绿植","喷泉","环形台","节点","圆台"]):
  _face(canvas,layout,_oval(r.grow(-minf(.04,r.size.x*.1))),minf(h,16),tone.darkened(.13))
  if kind in ["plant","tree"] or any_word(name,["绿植","枯树"]):
   var at:Vector2=_p(layout,center,12);canvas.draw_line(at,at-Vector2(0,h*.72),tone.darkened(.4),3,true)
   for i in range(5):
    var end:Vector2=at+Vector2(cos(i*1.9)*h*.3,-h*(.4+.1*(i%3)))
    canvas.draw_line(at-Vector2(0,h*.25),end,tone.darkened(.1),3,true)
    var leaves:=PackedVector2Array();var uv:=PackedVector2Array();var radius:float=maxf(4,h*.18)
    for point in range(9):
     var angle:float=TAU*point/9;var v:Vector2=end+Vector2(cos(angle),sin(angle))*(radius*(.82+.18*sin(point*2.7+i)))
     leaves.append(v);uv.append(v/78)
    if not Materials.draw_polygon(canvas,leaves,uv,"sage_paint",Color("788d78")):canvas.draw_colored_polygon(leaves,tone.lightened(.12))
  else:
   var at:Vector2=_p(layout,center,16+h*.28);canvas.draw_circle(at,minf(r.size.x*25,h*.35),tone.lightened(.2))
   canvas.draw_arc(at,minf(r.size.x*30,h*.45),.15,TAU-.15,32,tone.darkened(.35),3,true)
  return
 if kind=="fan" or name.contains("风扇"):
  _face(canvas,layout,_oval(r),5,tone.darkened(.3));var at:Vector2=_p(layout,center,h*.74)
  canvas.draw_line(_p(layout,center,5),at,tone.darkened(.3),4,true);canvas.draw_circle(at,h*.25,tone.darkened(.4));canvas.draw_arc(at,h*.25,0,TAU,32,tone.lightened(.3),2,true)
  for i in range(3):
   var angle:float=i*TAU/3;var blade:=PackedVector2Array([at,at+Vector2.from_angle(angle-.3)*h*.18,at+Vector2.from_angle(angle+.28)*h*.21,at+Vector2.from_angle(angle+.6)*h*.1])
   canvas.draw_colored_polygon(blade,tone.lightened(.1))
  for i in range(10):canvas.draw_line(at,at+Vector2.from_angle(i*TAU/10)*h*.24,tone.lightened(.35),.65,true)
  canvas.draw_arc(at,h*.16,0,TAU,28,tone.lightened(.28),.7,true);canvas.draw_circle(at,3,tone.lightened(.3))
  return
 if kind in ["chair","stool","chairs","bench"] or any_word(name,["圆凳","座椅","长椅","靠背椅"]):
  var seat:float=minf(h*.5,38)
  _legs(canvas,layout,r,seat,tone)
  if kind=="stool" or name.contains("凳"):_face(canvas,layout,_oval(r),seat,tone,maxf(0,seat-4))
  else:
   _top(canvas,layout,r,seat,tone.lightened(.1))
   var a:Vector2=_p(layout,r.position,seat);var b:Vector2=_p(layout,r.position+Vector2(r.size.x,0),seat)
   canvas.draw_colored_polygon(PackedVector2Array([a,b,b-Vector2(0,h-seat),a-Vector2(0,h-seat)]),tone.darkened(.12))
  return
 if kind in ["desk","table","console","clamp","cart","cleaner_cart","bed","examination"] or any_word(name,["工作台","会议桌","检查台","测试台","推车","病床"]):
  _legs(canvas,layout,r,h-6,tone)
  if any_word(name,["弧","曲","会议"]):_face_at_height(canvas,layout,_oval(r,28),h-6,h,tone)
  else:_face_at_height(canvas,layout,_quad(r),h-5,h,tone)
  if kind=="bed" or name.contains("病床"):
   _top(canvas,layout,Rect2(r.position+r.size*Vector2(.04,.08),r.size*Vector2(.92,.84)),h+3,Color("bfc8bf"))
   _top(canvas,layout,Rect2(r.position+r.size*Vector2(.08,.12),r.size*Vector2(.25,.7)),h+6,Color("d8d4be"))
  elif kind=="clamp":
   var at:Vector2=_p(layout,center,h+2)
   for s in [-1,1]:canvas.draw_arc(at+Vector2(s*9,0),10,-PI*.7 if s==1 else PI*.3,PI*.7 if s==1 else PI*1.7,12,tone.darkened(.4),4,true)
  elif kind=="console":_screen(canvas,layout,r.grow(-minf(r.size.x*.1,.1)),h+24,tone)
  if kind in ["console","desk","table"]:
   var controls:Vector2=_p(layout,r.get_center()+Vector2(0,r.size.y*.15),h+2)
   if kind=="console":
    for i in range(4):canvas.draw_circle(controls+Vector2((i-1.5)*8,0),2,[Color("979b7e"),Color("819e96"),Color("b29b73"),Color("9e817c")][i])
   elif kind=="desk":
    canvas.draw_colored_polygon(PackedVector2Array([controls+Vector2(-15,-4),controls+Vector2(5,-4),controls+Vector2(10,6),controls+Vector2(-11,6)]),Color("c6c4ac"))
  return
 if kind in ["screen","terminal","mirror","board"] or any_word(name,["屏","镜","示意板","指令板","规划板"]):
  if name.contains("弧"):
   var previous:Vector2=Vector2.INF
   for i in range(17):
    var angle:float=PI+PI*i/16;var p:Vector2=center+Vector2(cos(angle)*r.size.x*.5,sin(angle)*r.size.y*.5)
    if previous.is_finite():canvas.draw_colored_polygon(PackedVector2Array([_p(layout,previous,10),_p(layout,p,10),_p(layout,p,h),_p(layout,previous,h)]),tone.darkened(.28 if i%4 else .16))
    previous=p
   return
  _screen(canvas,layout,r,h,tone);return
 if kind in ["cable","groove","rug","debris","foliage"] or (kind not in ["box","case","cabinet","drawer"] and any_word(name,["纤维束","凹槽","地毯","杂物"])):
  if kind=="rug" or name.contains("地毯"):_face(canvas,layout,_oval(r),2,tone);return
  for i in range(6):
   var p:Vector2=r.position+r.size*Vector2(.08+i*.15,.4+.18*sin(i*2.4))
   canvas.draw_line(_p(layout,p,1),_p(layout,p+Vector2(r.size.x*.16,r.size.y*.22),minf(h,10)),tone.lightened(i*.025),maxf(2,h*.3),true)
  return
 # Cabinets and boxes are rectilinear by construction, with readable openings.
 _face(canvas,layout,_quad(r),h,tone)
 if kind in ["drawer","cabinet","books","locker"] or any_word(name,["柜","书架"]):
  var front_west:bool=r.size.y>r.size.x
  var a:Vector2=r.position if front_west else r.position+Vector2(0,r.size.y)
  var b:Vector2=r.position+Vector2(0,r.size.y) if front_west else r.end
  if kind=="drawer":
   for i in range(1,4):
    canvas.draw_line(_p(layout,a,h*i/4),_p(layout,b,h*i/4),tone.darkened(.35),1,true)
    var handle:Vector2=_p(layout,a.lerp(b,.5),h*(float(i)-.5)/4)
    canvas.draw_line(handle-Vector2(5,0),handle+Vector2(5,0),Color("bbb7a0"),2,true)
  else:
   canvas.draw_line(_p(layout,a.lerp(b,.5),5),_p(layout,a.lerp(b,.5),h-4),tone.darkened(.35),1,true)
   for portion in [.44,.56]:
    var handle:Vector2=_p(layout,a.lerp(b,portion),h*.5)
    canvas.draw_line(handle-Vector2(0,3),handle+Vector2(0,3),Color("b7b69f"),2,true)

static func any_word(name:String,words:Array) -> bool:
 for word:String in words:
  if name.contains(word):return true
 return false
static func _face_at_height(canvas,layout,ring:PackedVector2Array,bottom:float,top:float,tone:Color) -> void:
 if Materials.enabled():
  Materials.prop_face(canvas,layout,ring,top,tone,_current_material,bottom)
  return
 var a:=PackedVector2Array();var b:=PackedVector2Array()
 for p in ring:a.append(_p(layout,p,bottom));b.append(_p(layout,p,top))
 for i in range(ring.size()):
  var j:int=(i+1)%ring.size();var d:Vector2=ring[j]-ring[i]
  if Vector2(d.y,-d.x).dot(Vector2(-6,56))>0:canvas.draw_colored_polygon(PackedVector2Array([a[i],a[j],b[j],b[i]]),tone.darkened(.18))
 canvas.draw_colored_polygon(b,tone);b.append(b[0]);canvas.draw_polyline(b,tone.darkened(.3),1,true)
static func _screen(canvas,layout,r:Rect2,h:float,tone:Color) -> void:
 var center:Vector2=r.get_center();var base:Vector2=_p(layout,center,0);var at:Vector2=_p(layout,center,h*.6)
 var width:float=maxf(14,minf(140,r.size.x*75+r.size.y*10));var high:float=maxf(18,h*.62)
 canvas.draw_line(base,at,tone.darkened(.4),4,true)
 canvas.draw_style_box(_panel(tone.darkened(.38)),Rect2(at-Vector2(width*.5,high*.6),Vector2(width,high)))
 canvas.draw_line(at-Vector2(width*.4,-high*.2),at+Vector2(width*.4,high*.1),Color("93b1aa"),2,true)
static func _panel(tone:Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=tone;style.corner_radius_top_left=5;style.corner_radius_top_right=5;style.corner_radius_bottom_left=5;style.corner_radius_bottom_right=5
 return style

