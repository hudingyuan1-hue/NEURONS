extends RefCounted
## UI-only layered 2D drawing. No rules, damage or resource writes.

static func gut_amount(left:float) -> float:
 if left<=0:return 0.0
 return clampf(minf((2.0-left)/0.22,left/0.22),0,1)

const IDS=["SKIN","GUT","PORES","TEMP","TINNITUS","DRYMOUTH","KNEE","WITHDRAW","STARTLE","FEAR","JOY","CONTROL"]

static func pose(id:String,left:float,time:float,reduced:bool=false) -> Dictionary:
 # UI presentation fractions, never skill duration/range/damage parameters.
 var a:float=gut_amount(left)
 var p:Dictionary={"amount":a,"lean":Vector2.ZERO,"head":Vector2.ZERO,"palms":[Vector2(-113,-59),Vector2(113,-59)],"elbows":[Vector2(-70,-59),Vector2(70,-59)],"knees":[Vector2(-22,83),Vector2(22,83)],"feet":[Vector2(-22,133),Vector2(22,133)],"region":Vector2.ZERO,"smile":false}
 if a<=0 or id not in IDS:return p
 match id:
  "SKIN":p.palms=[Vector2(30,-30),Vector2(42,-48)];p.elbows=[Vector2(-35,-10),Vector2(55,-30)];p.region=Vector2(44,-44)
  "GUT":p.lean=Vector2(12,21);p.palms=[Vector2(-10,8),Vector2(10,8)];p.elbows=[Vector2(-42,-5),Vector2(42,-5)];p.region=Vector2(4,5)
  "PORES":p.palms=[Vector2(-23,-18),Vector2(61,-40)];p.elbows=[Vector2(-44,-6),Vector2(57,-15)];p.head=Vector2(5,4);p.region=Vector2(49,-35)
  "TEMP":p.lean.x=0 if reduced else sin(time*27)*2;p.palms=[Vector2(-4,-26),Vector2(4,-29)];p.elbows=[Vector2(-40,-4),Vector2(40,-4)];p.region=Vector2(0,-26)
  "TINNITUS":p.head=Vector2(-8,5);p.palms=[Vector2(-21,-91),Vector2(52,12)];p.elbows=[Vector2(-54,-40),Vector2(56,-22)];p.region=Vector2(-22,-96)
  "DRYMOUTH":p.palms=[Vector2(-48,14),Vector2(7,-66)];p.elbows=[Vector2(-55,-20),Vector2(44,-28)];p.region=Vector2(4,-70)
  "KNEE":p.knees[1]=Vector2(47,52);p.feet[1]=Vector2(91,45);p.palms=[Vector2(-60,-21),Vector2(43,-17)];p.region=Vector2(47,52)
  "WITHDRAW":p.palms=[Vector2(-13,-31),Vector2(13,-31)];p.elbows=[Vector2(-42,-3),Vector2(42,-3)];p.region=Vector2(14,-31)
  "STARTLE":p.lean=Vector2(-13,-4);p.knees=[Vector2(-39,77),Vector2(25,82)];p.feet=[Vector2(-54,133),Vector2(28,133)];p.palms=[Vector2(-57,-43),Vector2(48,-46)];p.head=Vector2(-3,-3);p.region=Vector2(0,-56)
  "FEAR":p.lean=Vector2(-5,8);p.head=Vector2(-4,5);p.palms=[Vector2(-16,-35),Vector2(28,-37)];p.elbows=[Vector2(-40,-5),Vector2(43,-8)];p.region=Vector2(0,-54)
  "JOY":p.palms=[Vector2(-48,19),Vector2(48,19)];p.elbows=[Vector2(-55,-17),Vector2(55,-17)];p.head=Vector2(0,-2);p.smile=true;p.region=Vector2(0,-45)
  "CONTROL":p.palms=[Vector2(-52,17),Vector2(88,-43)];p.elbows=[Vector2(-53,-18),Vector2(56,-43)];p.region=Vector2(86,-43)
 return p

static func draw(canvas:Node2D,angle:int,time:float,left:float,id:String="GUT",reduced:bool=false) -> void:
 var state:Dictionary=pose(id,left,time,reduced)
 var bend:float=state.amount
 var center:=Vector2(285,330+(0.0 if reduced else sin(time*1.4)*3))
 var width:float=1.0 if angle%2==0 else 0.38
 var cloth:=Color("89b5c5")
 var skin:=Color("d4c8ac")
 var lean:Vector2=state.lean*bend
 var top:Vector2=center+Vector2(0,-75)+lean
 var hip:Vector2=center+Vector2(0,35)
 canvas.draw_colored_polygon(PackedVector2Array([top+Vector2(-31*width,0),top+Vector2(31*width,0),hip+Vector2(25*width,0),hip+Vector2(-25*width,0)]),cloth)
 for side in [-1,1]:
  var index:int=0 if side<0 else 1
  var knee:Vector2=Vector2(side*22,83).lerp(state.knees[index],bend)
  var foot:Vector2=Vector2(side*22,133).lerp(state.feet[index],bend)
  knee.x*=width;foot.x*=width
  canvas.draw_line(hip+Vector2(side*18*width,-5),center+knee,cloth.darkened(0.08 if side<0 else 0),19)
  canvas.draw_line(center+knee,center+foot,cloth.darkened(0.08 if side<0 else 0),17)
  canvas.draw_line(center+foot,center+foot+Vector2(10,0),Color("5d727b"),10)
 var head:Vector2=center+Vector2(0,-102)+lean+state.head*bend
 canvas.draw_circle(head,25,skin)
 canvas.draw_arc(head,25,PI,TAU,15,Color("42494b"),9)
 if angle==0:
  for side in [-1,1]:canvas.draw_circle(head+Vector2(side*8,0),2,Color("333c3b"))
  if state.smile and bend>0.2:canvas.draw_arc(head+Vector2(0,6),7,0.2,PI-0.2,8,Color("746d65"),1)
  else:canvas.draw_line(head+Vector2(-4,11),head+Vector2(4,11),Color("746d65"),1)
 elif angle in [1,3]:
  var facing:float=1.0 if angle==1 else -1.0
  canvas.draw_circle(head+Vector2(facing*14,0),2,Color("333c3b"))
  canvas.draw_line(head+Vector2(facing*20,5),head+Vector2(facing*27,7),skin,4)
 else:
  canvas.draw_arc(head+Vector2(0,1),21,0,PI,12,Color("42494b"),5)
  canvas.draw_line(top+Vector2(0,6),hip-Vector2(0,6),cloth.darkened(0.18),1)
 if left>0 and id=="GUT":
  for ring in range(6,0,-1):
   canvas.draw_circle(center+Vector2(4,5),ring*3.2,Color(0.78,0.2,0.16,(0.045+(6-ring)*0.012)*maxf(0.25,bend)))
 for side in [-1,1]:
  var shoulder:Vector2=top+Vector2(side*26*width,16)
  var elbow:Vector2=center+Vector2(side*70*width,-59)
  var palm:Vector2=center+Vector2(side*113*width,-59)
  var index:int=0 if side<0 else 1
  elbow=elbow.lerp(center+Vector2(state.elbows[index].x*width,state.elbows[index].y),bend)
  palm=palm.lerp(center+Vector2(state.palms[index].x*width,state.palms[index].y),bend)
  canvas.draw_line(shoulder,elbow,cloth,17)
  canvas.draw_line(elbow,palm,cloth,15)
  canvas.draw_circle(palm,7,skin)
 if left>0 and id!="GUT":
  var region:Vector2=center+Vector2(state.region.x*width,state.region.y)
  canvas.draw_arc(region,13,0,TAU,20,Color(0.75,0.87,0.66,0.65*bend),2)
  if id=="PORES":
   for offset in [Vector2(-5,-3),Vector2(1,2),Vector2(5,-4)]:canvas.draw_circle(region+offset,1.5,Color("a36c67"))
  elif id=="TEMP":
   for side in [-1,1]:canvas.draw_line(center+Vector2(side*47*width,-70),center+Vector2(side*50*width,-42),Color(0.6,0.8,0.85,bend*0.6),2)
