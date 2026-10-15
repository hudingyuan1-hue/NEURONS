extends "res://scripts/world/room_view.gd"
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
var catalog=Catalog.new()

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
 if spec.has("book"):draw_texture(catalog.texture(spec.book),origin,tint)
 if spec.has("clock"):draw_texture(catalog.texture(spec.clock),origin,tint)
 draw_texture(catalog.texture(spec.front),origin,tint)

func bedside_handle() -> Vector2:
 var spec:Dictionary=catalog.furniture()
 return layout.project(layout.furniture[1].rect.position)-Vector2(float(spec.foot[0]),float(spec.foot[1]))+Vector2(float(spec.handle[0]),float(spec.handle[1]))+Vector2(float(spec.travel[0]),float(spec.travel[1]))*float(app.drawer_open.get("bedside",0.0))

func draw_actor(who:String) -> void:
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
 draw_texture_rect_region(frame.texture,Rect2(center-frame.foot,frame.size),frame.source)
 if app.hero_state=="search":
  var hand:Vector2=bedside_hand() if app.room_id=="bedroom" and bedside_contact() else center+Vector2(16,-28)
  draw_line(center+Vector2(8,-38),hand,Color("8caebc"),4)
  draw_circle(hand,2.5,Color("d6c8b0"))
 draw_string(font,center+Vector2(-19,-64),app.hero_state,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e5e3cd"))
 draw_line(center+Vector2(0,-2),center+app.hero_facing*9,Color("f1c17d"),1)

func _draw() -> void:
 super._draw()
 if app==null:return
 for id in app.visible_doors:
  var point:Vector2=layout.project(app.door_point(id))
  draw_arc(point,9,PI,TAU,16,Color("9dc2bb"),2)
  draw_string(font,point+Vector2(-15,-13),app.room_title(id),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e2dfc9"))
 if app.key_visible() and not app.has_key():
  var point:Vector2=layout.project(app.key_position())+Vector2(0,-12)
  draw_circle(point,3,Color("eac978"),false,1)
  draw_line(point+Vector2(3,0),point+Vector2(11,0),Color("eac978"),2)

