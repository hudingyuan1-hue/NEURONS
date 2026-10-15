extends "res://scripts/world/room_view.gd"
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
var catalog=Catalog.new()

func extra_actors() -> Array:
 var actors:Array=app.home.actors() if app!=null and app.home!=null else []
 if app!=null and app.family!=null:actors.append_array(app.family.actors())
 if app!=null and app.search_actions!=null and app.room_id=="bedroom":
  var props:Dictionary=app.search_actions.state("box")
  if props.has("upper_shift"):
   var shift:Array=props.upper_shift
   var at:Vector2=layout.furniture[5].rect.end+Vector2(float(shift[0]),float(shift[1]))
   actors.append({"type":"actor","data":"upper_box","depth":layout.project(at).y})
 return actors

func draw_bedside(f:Dictionary) -> void:
 if catalog.current.is_empty():
  super.draw_bedside(f)
  return
 var spec:Dictionary=catalog.furniture()
 var origin:Vector2=layout.project(f.rect.position)-Vector2(float(spec.foot[0]),float(spec.foot[1]))
 var shift:Vector2=Vector2(float(spec.travel[0]),float(spec.travel[1]))*float(app.drawer_open.get(f.id,0.0))
 var tint:=Color(str(spec.tint))
 draw_texture(catalog.texture(spec.body),origin,tint)
 if shift.x>0 and spec.has("tray"):
  var a:=origin+Vector2(55.1742,11.8642)
  var b:=origin+Vector2(66.3666,30.4515)
  draw_polygon(PackedVector2Array([a,b,b+shift,a+shift]),PackedColorArray([tint]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),catalog.texture(spec.tray))
 draw_texture(catalog.texture(spec.drawer),origin+shift,tint)
 var props:Dictionary=app.search_actions.state("bedside") if app.search_actions!=null else {}
 var book:Array=props.get("book_shift",[0,0])
 var clock:Array=props.get("clock_shift",[0,0])
 if spec.has("book"):draw_texture(catalog.texture(spec.book),origin+Vector2(float(book[0]),float(book[1])),tint)
 if spec.has("clock"):draw_texture(catalog.texture(spec.clock),origin+Vector2(float(clock[0]),float(clock[1])),tint)
 draw_texture(catalog.texture(spec.front),origin,tint)

func bedside_handle() -> Vector2:
 var spec:Dictionary=catalog.furniture()
 return layout.project(layout.furniture[1].rect.position)-Vector2(float(spec.foot[0]),float(spec.foot[1]))+Vector2(float(spec.handle[0]),float(spec.handle[1]))+Vector2(float(spec.travel[0]),float(spec.travel[1]))*float(app.drawer_open.get("bedside",0.0))

func draw_actor(who:String) -> void:
 if who=="upper_box":
  var shift:Array=app.search_actions.state("box").upper_shift
  var base:Rect2=layout.furniture[5].rect
  prism(Rect2(base.position+Vector2(float(shift[0]),float(shift[1])),base.size),11,Color("ae926b"))
  return
 if who in ["mother","father"]:
  var at:Vector2=layout.project(app.family.position(who))
  var color:=Color("b9a28d") if who=="mother" else Color("66777b")
  if app.family.collapse_active():
   var phase:float=float(app.family.data.collapse.elapsed)
   at+=Vector2(sin(phase*53)*1.5,0)
   color=color.lerp(Color("654149"),minf(0.8,phase*0.16))
  draw_circle(at,10,Color(0.07,0.08,0.08,0.25))
  draw_rect(Rect2(at+Vector2(-8,-45),Vector2(16,32)),color)
  draw_circle(at+Vector2(0,-53),8,color.lightened(0.2))
  for side in [-1,1]:
   draw_line(at+Vector2(side*5,-15),at+Vector2(side*5,0),color,5)
   draw_line(at+Vector2(side*7,-40),at+Vector2(side*13,-19),color,4)
  draw_string(font,at+Vector2(-23,-66),"母亲·占位" if who=="mother" else "父亲·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d7dfcf"))
  return
 if who in ["dog","cat"]:
  var at:Vector2=layout.project(app.home.position(who))
  var color:=Color("c6a35e") if who=="dog" else Color("343d40")
  draw_set_transform(at)
  draw_circle(Vector2(0,-2),12,Color(0.07,0.08,0.08,0.25))
  if who=="dog" and not app.home.data.dog.alive:
   draw_rect(Rect2(-14,-7,27,7),Color("78504b"))
  else:
   draw_rect(Rect2(-12,-15,23,11),color)
   draw_rect(Rect2(7,-22,12,13),color.lightened(0.12))
   draw_line(Vector2(8,-18),Vector2(7,-26),color,3)
   draw_line(Vector2(-10,-13),Vector2(-17,-19),color,3)
   draw_line(Vector2(-7,-5),Vector2(-7,0),color,3)
   draw_line(Vector2(8,-5),Vector2(8,0),color,3)
   if who=="dog":draw_line(Vector2(7,-16),Vector2(7,-10),Color("a95f54"),2)
  draw_string(font,Vector2(-17,-29),"大黄·占位" if who=="dog" else "黑猫·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d7dfcf"))
  draw_set_transform(Vector2.ZERO)
  return
 if who!="hero" or catalog.current.is_empty():
  super.draw_actor(who)
  return
 var center:Vector2=layout.project(app.hero_pos)
 # Body action poses follow the same saved game clock as contact settlement.
 var phase:float=app.world_visual_time
 if app.hero_state=="search":phase=app.rules.search_elapsed
 elif app.hero_state=="scratch":phase=maxf(0,0.5-app.rules.reaction_left)
 elif app.hero_state=="hit":phase=maxf(0,0.25-app.rules.hurt_left)
 elif app.hero_state=="give":phase=maxf(0,(0.4 if app.action_phase=="pickup" else 0.6)-app.action_left)
 var frame:Dictionary=catalog.actor_frame(app.hero_state,app.hero_facing,phase)
 draw_set_transform(center,0,Vector2(1,0.35))
 draw_circle(Vector2.ZERO,10,Color(0.05,0.07,0.08,0.3))
 draw_set_transform(Vector2.ZERO)
 var crouch:float=0.68 if app.hero_state=="search" and app.search_actions!=null and app.search_actions.pose=="low" else 1.0
 draw_texture_rect_region(frame.texture,Rect2(center-Vector2(frame.foot.x,frame.foot.y*crouch),Vector2(frame.size.x,frame.size.y*crouch)),frame.source)
 if float(app.rules.effects.get("PORES",0))>0:
  for i in range(5):draw_circle(center+Vector2(9+i%2*3,-35+i*3),1.0,Color("9fcebc"))
 if float(app.rules.effects.get("DRYMOUTH",0))>0:draw_line(center+Vector2(7,-43),center+Vector2(10,-35),Color("d6c8b0"),2)
 if app.hero_state=="search":
  var hand:Vector2=bedside_hand() if app.room_id=="bedroom" and bedside_contact() else center+Vector2(16,-46 if app.search_actions!=null and app.search_actions.pose=="high" else -12 if crouch<1 else -28)
  if app.target_index>=0 and app.room_id=="bedroom" and app.layout.furniture[app.target_index].id!="bedside":
   var f:Dictionary=app.layout.furniture[app.target_index]
   var p:=Vector2(clampf(app.hero_pos.x,f.rect.position.x,f.rect.end.x),clampf(app.hero_pos.y,f.rect.position.y,f.rect.end.y))
   hand=layout.project(p)+Vector2(0,-minf(float(f.height),46.0) if app.search_actions.pose=="high" else -8 if crouch<1 else -float(f.height)*0.6)
  draw_line(center+Vector2(8,-38),hand,Color("8caebc"),4)
  draw_circle(hand,2.5,Color("d6c8b0"))
 draw_string(font,center+Vector2(-19,-64),app.search_actions.action_label if app.hero_state=="search" and app.search_actions!=null else app.hero_state,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e5e3cd"))
 draw_line(center+Vector2(0,-2),center+app.hero_facing*9,Color("f1c17d"),1)

func draw_furniture(f:Dictionary) -> void:
 if app.search_actions==null or app.room_id!="bedroom":super.draw_furniture(f);return
 # Tall foreground props remain physical but reveal an obscured interaction.
 # Only presentation alpha changes; depth ordering/collision stay intact.
 if float(f.height)>=40 and app.rules.search_active and app.target_index>=0 and app.layout.furniture[app.target_index].id!=f.id:
  var hero:Vector2=layout.project(app.hero_pos)
  var left:Vector2=layout.project(f.rect.position)
  var right:Vector2=layout.project(f.rect.end)
  var bounds:=Rect2(Vector2(minf(left.x,right.x),left.y-float(f.height)),Vector2(absf(right.x-left.x),right.y-left.y+float(f.height)))
  if right.y>hero.y and bounds.intersects(Rect2(hero+Vector2(-12,-57),Vector2(24,57))):
   f=f.duplicate()
   var color:Color=f.color
   f.color=Color(color.r,color.g,color.b,0.35)
 var props:Dictionary=app.search_actions.state(f.id)
 if f.id=="box":
  prism(f.rect,9,Color("627c86"))
  if props.has("upper_shift"):return # Moved upper box has its own depth entry.
  var shift:Array=props.get("upper_shift",[0,0])
  var upper:=Rect2(f.rect.position+Vector2(float(shift[0]),float(shift[1])),f.rect.size)
  if not props.has("upper_shift"):draw_set_transform(Vector2(0,-9))
  prism(upper,11,Color("ae926b"))
  draw_set_transform(Vector2.ZERO)
  return
 if f.id=="stool":
  var center:Vector2=layout.project(f.rect.get_center())
  for side in [-1,1]:draw_line(center+Vector2(side*8,0),center+Vector2(side*8,-14),Color("577e94"),3)
  draw_set_transform(center+Vector2(0,-14),0,Vector2(1,0.4));draw_circle(Vector2.ZERO,13,Color("759db7"));draw_set_transform(Vector2.ZERO)
  draw_set_transform(Vector2(0,-14));prism(f.rect.grow(-0.05),9,Color("b7a07b"));draw_set_transform(Vector2.ZERO)
  if props.get("open",false):draw_rect(Rect2(center+Vector2(-10,-26),Vector2(19,5)),Color("4e4436"));draw_line(center+Vector2(-10,-26),center+Vector2(-16,-35),Color("c3ac83"),4)
  return
 super.draw_furniture(f)
 if f.id=="bed" and props.get("bedding_lifted",false):
  var edge:Vector2=layout.project(f.rect.end)+Vector2(-17,-28)
  draw_colored_polygon(PackedVector2Array([edge,edge+Vector2(-25,-4),edge+Vector2(-15,-12),edge+Vector2(4,-6)]),Color("9daaa6"))
 if f.id=="desk":
  var at:Vector2=layout.project(f.rect.get_center())+Vector2(-45,-30)
  var moved:int=int(props.get("desk_shift",0))
  for i in range(3):
   var p:Vector2=at+Vector2(i*23+ (4 if moved>i else 0),i%2*6)
   draw_rect(Rect2(p,Vector2(16,4)),[Color("a5b4b3"),Color("c6ad7c"),Color("91715f")][i])
   draw_line(p+Vector2(0,4),p+Vector2(16,4),Color("e0d7be"),1)
 if f.id=="storage" and props.get("uniform_out",false):
  var at:Vector2=layout.project(f.rect.position)+Vector2(-10,-20)
  draw_colored_polygon(PackedVector2Array([at,at+Vector2(22,3),at+Vector2(25,20),at+Vector2(1,16)]),Color("aab4b3"))
  draw_rect(Rect2(at+Vector2(7,9),Vector2(8,3)),Color("8a5e59"))
  if props.get("label_viewed",false):draw_rect(Rect2(at+Vector2(6,2),Vector2(7,3)),Color("d9d3bc"))
 if f.id=="rack" and app.action_phase=="observe_cuff":
  var at:Vector2=layout.project(f.rect.get_center())+Vector2(-2,-25)
  draw_line(at,at+Vector2(-15,-6),Color("d9d9cd"),5)
  for i in range(4):draw_line(at+Vector2(-13+i*3,-6),at+Vector2(-12+i*3,-3),Color("6b7473"),1)

func _draw() -> void:
 super._draw()
 if app==null:return
 if app.family!=null and not app.family.data.is_empty() and app.family.data.blood_door:
  draw_rect(Rect2(layout.project(Vector2(4.28,0))+Vector2(0,-76),Vector2(69,76)),Color(0.45,0.1,0.12,0.7))
 if app.family!=null and not app.family.data.is_empty() and not app.family.data.gift.is_empty():
  var at:Vector2=layout.project(app.layout.DOOR)+Vector2(-8,0)
  draw_rect(Rect2(at+Vector2(-4,-5),Vector2(8,5)),Color("b28d69"))
 for id in app.visible_doors:
  var point:Vector2=layout.project(app.door_point(id))
  draw_arc(point,9,PI,TAU,16,Color("9dc2bb"),2)
  draw_string(font,point+Vector2(-15,-13),app.room_title(id),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e2dfc9"))
 if app.key_visible() and not app.has_key():
  var point:Vector2=layout.project(app.key_position())+Vector2(0,-12)
  draw_circle(point,3,Color("eac978"),false,1)
  draw_line(point+Vector2(3,0),point+Vector2(11,0),Color("eac978"),2)

