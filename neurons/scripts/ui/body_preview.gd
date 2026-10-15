extends RefCounted
## UI-only layered 2D drawing. No rules, damage or resource writes.

static func gut_amount(left:float) -> float:
 if left<=0:return 0.0
 return clampf(minf((2.0-left)/0.22,left/0.22),0,1)

static func draw(canvas:Node2D,angle:int,time:float,left:float) -> void:
 var bend:float=gut_amount(left)
 var center:=Vector2(285,330+sin(time*1.4)*3)
 var width:float=1.0 if angle%2==0 else 0.38
 var cloth:=Color("89b5c5")
 var skin:=Color("d4c8ac")
 var lean:=Vector2(12,21)*bend
 var top:Vector2=center+Vector2(0,-75)+lean
 var hip:Vector2=center+Vector2(0,35)
 canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-31*width,0),top+Vector2(31*width,0),hip+Vector2(25*width,0),hip+Vector2(-25*width,0)]),cloth)
 for side in [-1,1]:
  canvas.draw_line(hip+Vector2(side*18*width,-5),center+Vector2(side*22*width,133),cloth.darkened(0.08 if side<0 else 0),19)
  canvas.draw_line(center+Vector2(side*22*width,133),center+Vector2(side*22*width+10,133),Color("5d727b"),10)
 var head:Vector2=center+Vector2(0,-102)+lean
 canvas.draw_circle(head,25,skin)
 canvas.draw_arc(head,25,PI,TAU,15,Color("42494b"),9)
 if angle==0:
  for side in [-1,1]:canvas.draw_circle(head+Vector2(side*8,0),2,Color("333c3b"))
  canvas.draw_line(head+Vector2(-4,11),head+Vector2(4,11),Color("746d65"),1)
 elif angle in [1,3]:
  var facing:float=1.0 if angle==1 else -1.0
  canvas.draw_circle(head+Vector2(facing*14,0),2,Color("333c3b"))
  canvas.draw_line(head+Vector2(facing*20,5),head+Vector2(facing*27,7),skin,4)
 else:
  canvas.draw_arc(head+Vector2(0,1),21,0,PI,12,Color("42494b"),5)
  canvas.draw_line(top+Vector2(0,6),hip-Vector2(0,6),cloth.darkened(0.18),1)
 if left>0:
  for ring in range(6,0,-1):
   canvas.draw_circle(center+Vector2(4,5),ring*3.2,Color(0.78,0.2,0.16,(0.045+(6-ring)*0.012)*maxf(0.25,bend)))
 for side in [-1,1]:
  var shoulder:Vector2=top+Vector2(side*26*width,16)
  var elbow:Vector2=center+Vector2(side*70*width,-59)
  var palm:Vector2=center+Vector2(side*113*width,-59)
  elbow=elbow.lerp(center+Vector2(side*42*width,-5),bend)
  palm=palm.lerp(center+Vector2(side*10*width,8),bend)
  canvas.draw_line(shoulder,elbow,cloth,17)
  canvas.draw_line(elbow,palm,cloth,15)
  canvas.draw_circle(palm,7,skin)
