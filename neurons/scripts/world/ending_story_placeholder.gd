extends RefCounted
## R1:P28-P30 only. Read-only 2D staging, not a character/species design,
## new playable map, completion signal or extra condition for either ending.
const OUTLINE:=Color("81908b")
const PALE:=Color("b8bdb0")

static func ellipse(center:Vector2,radii:Vector2) -> PackedVector2Array:
 var points:=PackedVector2Array()
 for i in range(32):points.append(center+Vector2(cos(TAU*i/32.0)*radii.x,sin(TAU*i/32.0)*radii.y))
 return points

static func draw(canvas:Node2D,ending:Dictionary,center:Vector2,frame_info:Dictionary={}) -> void:
 var phase:String=str(ending.get("phase",""))
 var id:String=str(ending.get("id",""))
 if id not in ["E2","E3"] or phase not in ["wake","planet"]:return
 var elapsed:float=maxf(0,float(ending.get("elapsed",0)))
 if phase=="wake":draw_bed(canvas,center,clampf(elapsed/3.0,0,1),id=="E3")
 elif id=="E2":draw_external_placeholder(canvas,center,clampf(elapsed/2.0,0,1))
 # frame_info is reserved for the caller's viewport geometry. No scene state
 # or animation-frame number controls damage, identity or ending settlement.

static func draw_bed(canvas:Node2D,at:Vector2,progress:float,player_view:bool) -> void:
 canvas.draw_rect(Rect2(at+Vector2(-230,-95),Vector2(460,205)),Color("182423"))
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-230,30),at+Vector2(230,30),at+Vector2(230,110),at+Vector2(-230,110)]),Color("24322f"))
 # An unlabelled room light and simple cot are staging placeholders. The
 # source assigns neither a new hospital identity nor a new bedroom layout.
 canvas.draw_line(at+Vector2(-55,-76),at+Vector2(55,-76),Color("b9bba8"),5)
 var bed:=PackedVector2Array([at+Vector2(-150,-13),at+Vector2(135,-13),at+Vector2(165,62),at+Vector2(-120,62)])
 canvas.draw_colored_polygon(bed,Color("737e75"))
 canvas.draw_polyline(PackedVector2Array([bed[0],bed[1],bed[2],bed[3],bed[0]]),OUTLINE,3)
 canvas.draw_line(bed[3],bed[3]+Vector2(0,29),OUTLINE,5)
 canvas.draw_line(bed[2],bed[2]+Vector2(0,29),OUTLINE,5)
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-140,-9),at+Vector2(-78,-9),at+Vector2(-62,40),at+Vector2(-124,40)]),Color("aab3a6"))
 # No hair, costume, sex, species or new injury is assigned to this silhouette.
 canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-78,-1),at+Vector2(85,5),at+Vector2(120,42),at+Vector2(-70,36)]),Color("a0aaa0"))
 canvas.draw_circle(at+Vector2(-98,0),19,PALE)
 var opened:float=smoothstep(.22,.57,progress)
 for x in [-104.0,-92.0]:
  var eye:Vector2=at+Vector2(x,-3)
  if opened<.12:canvas.draw_line(eye-Vector2(3,0),eye+Vector2(3,0),Color("394943"),2)
  else:canvas.draw_colored_polygon(ellipse(eye,Vector2(3,1.0+2.0*opened)),Color("394943"))
 canvas.draw_line(at+Vector2(-94,9),at+Vector2(-89,9),Color("7d877b"),1)
 if player_view:
  # The source calls for a change of viewpoint, not a new attacker or actor.
  var reach:float=18.0+14.0*opened
  for side in [-1.0,1.0]:
   var corner:Vector2=at+Vector2(side*208,-50)
   canvas.draw_line(corner,corner+Vector2(-side*reach,0),Color(.55,.64,.59,.50*opened),2)
   canvas.draw_line(corner,corner+Vector2(0,reach),Color(.55,.64,.59,.50*opened),2)
 else:
  # A visible gap interrupts the simple connection after the body wakes.
  var start:Vector2=at+Vector2(150,-38);var end:Vector2=at+Vector2(220,-38)
  var tone:=Color(.61,.70,.64,.7)
  if progress<.54:canvas.draw_line(start,end,tone,2)
  else:
   canvas.draw_line(start,start.lerp(end,.32),tone,2)
   canvas.draw_line(start.lerp(end,.70),end,tone,2)
   canvas.draw_line(start.lerp(end,.32),start.lerp(end,.32)+Vector2(-5,-5),tone,2)

static func draw_external_placeholder(canvas:Node2D,at:Vector2,progress:float) -> void:
 canvas.draw_rect(Rect2(at+Vector2(-230,-95),Vector2(460,205)),Color("182825"))
 var ground:=PackedVector2Array([at+Vector2(-230,63),at+Vector2(-125,43),at+Vector2(0,37),at+Vector2(125,43),at+Vector2(230,63),at+Vector2(230,110),at+Vector2(-230,110)])
 canvas.draw_colored_polygon(ground,Color("34423a"))
 canvas.draw_polyline(PackedVector2Array([ground[0],ground[1],ground[2],ground[3],ground[4]]),Color("70816f"),2)
 canvas.draw_colored_polygon(ellipse(at+Vector2(0,69),Vector2(36,9)),Color(.03,.08,.06,.40))
 # Deliberately elementary geometry: the external body's appearance is not
 # specified. Formal character art can replace these shapes independently.
 canvas.draw_colored_polygon(ellipse(at+Vector2(0,25),Vector2(19,43)),Color("7c8c78"))
 canvas.draw_circle(at+Vector2(0,-26),16,Color("a2ad93"))
 var perception:float=smoothstep(.05,.80,progress)
 canvas.draw_arc(at+Vector2(0,-26),22+4*perception,-.75,.75,20,Color(.66,.76,.61,.60*perception),2)
 canvas.draw_line(at+Vector2(24,18),at+Vector2(80+70*perception,10),Color(.55,.68,.51,.30*perception),1)
