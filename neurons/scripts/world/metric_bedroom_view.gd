extends RefCounted
## Metric L1 presentation only. No navigation, event or ownership mutation.
## Draw coordinates are world pixels; the caller's Camera2D owns zoom.
const SHELL = preload("res://assets/environment/bedroom_shell_v001.png")
const Presentation=preload("res://scripts/world/spatial_presentation.gd")
const Architecture=preload("res://scripts/world/architectural_surface.gd")
const Materials=preload("res://scripts/world/spatial_materials.gd")
const SpatialProp=preload("res://scripts/world/spatial_prop.gd")
const ProductionProps=preload("res://scripts/world/production_props.gd")
const HEIGHT_PIXELS := Presentation.HEIGHT_PIXELS
const HERO_HEIGHT := 1.75 * HEIGHT_PIXELS
const ATLAS_BODY_HEIGHT := 57.0 # Existing placeholder: head y15, foot y72.
const INK := Color("354447")
var canvas:Node2D
var app
var layout
var catalog
var font:Font = ThemeDB.fallback_font
var _prop_material:String="furniture_wood"

static func _height(f:Dictionary) -> float:
 return float(f.get("height_m",float(f.get("height",40.0))/HEIGHT_PIXELS))*HEIGHT_PIXELS

static func architecture_pieces(room_layout) -> Array:
 # Full drawing union, used by both render passes and the exported locator.
 # Pieces are construction inputs; their internal seams are never inked.
 var size:Vector2=room_layout.world_size()
 var t:float=float(room_layout.config.wall.thickness_m)
 var full:float=float(room_layout.config.wall.height_m)
 var low:float=minf(full,Presentation.NEAR_CUT_HEIGHT_M)
 var door:Dictionary=room_layout.config.door
 var da:float=float(door.center_m[0])-float(door.clear_width_m)*.5
 var db:float=da+float(door.clear_width_m)
 var dh:float=float(door.height_m)
 var result:Array=[]
 for rect in [Rect2(0,-t,da,t),Rect2(db,-t,size.x-db,t)]:
  result.append({"rect":rect,"height_m":full,"group":"far"})
 if full>dh:result.append({"rect":Rect2(da,-t,db-da,t),"bottom_m":dh,"height_m":full-dh,"group":"far"})
 result.append({"rect":Rect2(size.x,0,t,size.y),"height_m":full,"group":"far"})
 for segment:Dictionary in Presentation.wall_display_segments("west",size.y,full):
  result.append({"rect":Rect2(-t,float(segment.start),t,float(segment.end)-float(segment.start)),"height_m":float(segment.height_m),"group":"near"})
 var window:Dictionary=room_layout.config.window
 var wa:float=float(window.center_m[0])-float(window.width_m)*.5
 var wb:float=wa+float(window.width_m)
 var view:Dictionary=Presentation.window_display("south",float(window.width_m),float(window.sill_height_m),float(window.opening_height_m))
 var sill:float=float(view.sill_height_m)
 var top:float=sill+float(view.opening_height_m)
 var cap:float=minf(full,float(view.wall_cap_height_m))
 var side_width:float=.12
 var left:float=maxf(0,wa-side_width);var right:float=minf(size.x,wb+side_width)
 for rect in [Rect2(0,size.y,left,t),Rect2(right,size.y,size.x-right,t)]:
  if rect.size.x>0:result.append({"rect":rect,"height_m":low,"group":"near"})
 for rect in [Rect2(left,size.y,wa-left,t),Rect2(wb,size.y,right-wb,t)]:
  if rect.size.x>0:result.append({"rect":rect,"height_m":cap,"group":"near"})
 result.append({"rect":Rect2(wa,size.y,wb-wa,t),"height_m":sill,"group":"near"})
 if cap>top:result.append({"rect":Rect2(wa,size.y,wb-wa,t),"bottom_m":top,"height_m":cap-top,"group":"near"})
 # Only the exterior thickness cells are closed. Net floor size and all
 # original openings/positions are unchanged.
 for c in [{"at":Vector2(-t,-t),"h":full,"g":"far"},{"at":Vector2(size.x,-t),"h":full,"g":"far"},{"at":Vector2(-t,size.y),"h":low,"g":"near"},{"at":Vector2(size.x,size.y),"h":low,"g":"near"}]:
  result.append({"rect":Rect2(c.at,Vector2(t,t)),"height_m":c.h,"group":c.g})
 return result

func _architecture(near:bool) -> void:
 Architecture.draw(canvas,layout,architecture_pieces(layout),{"group":"near" if near else "far","top":Color("c3beaa"),"west":Color("8d9488"),"south":Color("b4b8a7"),"edge":Color("747c72"),"edge_width":.7})

static func _find(layout_value,id:String) -> Dictionary:
 for f in layout_value.furniture:
  if str(f.id)==id:return f
 return {}

static func _projected_face(layout_value,rect:Rect2,height:float) -> PackedVector2Array:
 var up:=Vector2(0,-height)
 return PackedVector2Array([layout_value.project(rect.position)+up,layout_value.project(rect.position+Vector2(rect.size.x,0))+up,layout_value.project(rect.end)+up,layout_value.project(rect.position+Vector2(0,rect.size.y))+up])

static func _prism_faces(layout_value,rect:Rect2,height:float,bottom:float=0.0) -> Array:
 var base:PackedVector2Array=_projected_face(layout_value,rect,bottom)
 var top:PackedVector2Array=_projected_face(layout_value,rect,bottom+height)
 # The shared oblique basis exposes WEST and SOUTH vertical faces.
 return [top,PackedVector2Array([base[0],base[3],top[3],top[0]]),PackedVector2Array([base[2],base[3],top[3],top[2]])]

static func _stroke_face(a:Vector2,b:Vector2,width:float) -> PackedVector2Array:
 var offset:Vector2=(b-a).normalized().orthogonal()*width*0.5
 return PackedVector2Array([a-offset,a+offset,b+offset,b-offset])

static func _moved_box_rects(layout_value,f:Dictionary) -> Array:
 var result:Array=[]
 if str(f.id)!="box":return result
 var base:Rect2=f.rect
 for rect:Rect2 in layout_value.movable_blockers:
  if rect.size.is_equal_approx(base.size) and not rect.position.is_equal_approx(base.position):result.append(rect)
 return result

static func _furniture_faces(layout_value,f:Dictionary) -> Array:
 var rect:Rect2=f.rect
 var h:float=_height(f)
 if not _moved_box_rects(layout_value,f).is_empty():h=float(f.get("lower_height_m",0.45))*HEIGHT_PIXELS
 var center:Vector2=layout_value.project(rect.get_center())
 var faces:Array=[]
 match str(f.id):
  "desk","chair":
   var seat:float=minf(h,0.46*HEIGHT_PIXELS) if str(f.id)=="chair" else h
   faces.append_array(_prism_faces(layout_value,rect,6,seat-6))
   for corner in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
    var foot:Vector2=layout_value.project(corner)
    faces.append(_stroke_face(foot,foot-Vector2(0,seat),5))
   if str(f.id)=="chair":
    var left:Vector2=layout_value.project(rect.position)
    var right:Vector2=layout_value.project(rect.position+Vector2(rect.size.x,0))
    faces.append(_stroke_face(left-Vector2(0,seat),left-Vector2(0,h),5))
    faces.append(_stroke_face(right-Vector2(0,seat),right-Vector2(0,h),5))
    faces.append(_stroke_face(left-Vector2(0,h-8),right-Vector2(0,h-8),12))
  "stool":
   var seat:float=0.44*HEIGHT_PIXELS
   faces.append_array(_prism_faces(layout_value,rect,5,seat-5))
   faces.append_array(_prism_faces(layout_value,rect.grow(-0.035),float(f.get("attachment_height_m",0.3))*HEIGHT_PIXELS,seat))
   for side in [-1,1]:faces.append(_stroke_face(center+Vector2(side*14,0),center+Vector2(side*11,-seat),5))
  "rack":
   faces.append(_stroke_face(center,center-Vector2(0,h),5))
   faces.append(_stroke_face(center-Vector2(19,0),center+Vector2(19,0),5))
   faces.append(_stroke_face(center+Vector2(-27,-h+12),center+Vector2(27,-h+12),6))
   faces.append(PackedVector2Array([center+Vector2(-19,-h+13),center+Vector2(21,-h+13),center+Vector2(30,-h+44),center+Vector2(18,-h+49),center+Vector2(16,-18),center+Vector2(-15,-18),center+Vector2(-19,-h+47),center+Vector2(-30,-h+42)]))
  "fan":
   var head:Vector2=center-Vector2(0,h-24)
   var circle:=PackedVector2Array()
   for i in range(24):circle.append(head+Vector2.from_angle(TAU*i/24.0)*25)
   faces.append(circle)
   faces.append(_stroke_face(center,head,6))
   faces.append(_stroke_face(center-Vector2(20,0),center+Vector2(20,0),7))
  _:
   faces.append_array(_prism_faces(layout_value,rect,h))
   if str(f.id)=="bed":faces.append_array(_prism_faces(layout_value,Rect2(rect.position+Vector2(0.06,0.05),Vector2(0.42,rect.size.y-0.1)),8,h))
 return faces

static func furniture_at_pixel(layout_value,pixel:Vector2) -> int:
 # Reverse exactly the furniture depth used by draw. Never unproject the
 # visible upper cabinet face into an unrelated patch of floor.
 var ordered:Array=[]
 for index in range(layout_value.furniture.size()):
  var f:Dictionary=layout_value.furniture[index]
  ordered.append({"index":index,"depth":Presentation.footprint_depth(layout_value,f.rect),"faces":_furniture_faces(layout_value,f)})
  for moved:Rect2 in _moved_box_rects(layout_value,f):
   ordered.append({"index":index,"depth":Presentation.footprint_depth(layout_value,moved),"faces":_prism_faces(layout_value,moved,float(f.get("upper_height_m",0.45))*HEIGHT_PIXELS)})
 ordered.sort_custom(func(a,b):return float(a.depth)>float(b.depth) if not is_equal_approx(float(a.depth),float(b.depth)) else int(a.index)>int(b.index))
 for entry in ordered:
  for face in entry.faces:
   if Geometry2D.is_point_in_polygon(pixel,face):return int(entry.index)
 return -1

static func _door_rect(layout_value) -> Rect2:
 var spec:Dictionary=layout_value.config.door
 var foot:Vector2=layout_value.project(Vector2(float(spec.center_m[0]),float(spec.center_m[1])))
 var width:float=float(spec.clear_width_m)*float(layout_value.projection_x)
 var height:float=float(spec.height_m)*HEIGHT_PIXELS
 return Rect2(foot+Vector2(-width*0.5,-height),Vector2(width,height))

static func door_hit(layout_value,pixel:Vector2) -> bool:
 return _door_rect(layout_value).has_point(pixel)

static func _rest_pose(app_value,layout_value) -> Dictionary:
 var f:Dictionary=_find(layout_value,"bed")
 var t:float=clampf((1.2-float(app_value.action_left))/0.3,0,1)
 var from:Vector2=layout_value.project(app_value.hero_pos)-Vector2(0,HERO_HEIGHT*0.5)
 var to:Vector2=layout_value.project((f.rect as Rect2).get_center())-Vector2(0,_height(f)+8)
 return {"center":from.lerp(to,smoothstep(0.0,1.0,t)),"angle":-PI*0.5*smoothstep(0.0,1.0,t),"t":t}

static func hero_body_rect(app_value,layout_value) -> Rect2:
 if str(app_value.action_phase)=="resting":
  var pose:Dictionary=_rest_pose(app_value,layout_value)
  var extent:=Vector2(25,HERO_HEIGHT*0.5).lerp(Vector2(HERO_HEIGHT*0.5,25),float(pose.t))
  return Rect2(pose.center-extent,extent*2)
 var crouch:float=0.68 if str(app_value.hero_state)=="search" and app_value.search_actions!=null and app_value.search_actions.pose=="low" else 1.0
 return Rect2(layout_value.project(app_value.hero_pos)+Vector2(-25,-HERO_HEIGHT*crouch),Vector2(50,HERO_HEIGHT*crouch+4))

static func _cabinet_transform(app_value,layout_value,catalog_value) -> Dictionary:
 var f:Dictionary=_find(layout_value,"bedside")
 var spec:Dictionary=catalog_value.furniture()
 var rect:Rect2=f.rect
 # All source layers share one scale. Source geometry is a trial asset, not
 # a promise that arbitrary replacement art matches a different projection.
 var width:float=absf(layout_value.project(rect.end).x-layout_value.project(rect.position).x)
 var scale_value:float=width/59.0
 var source_foot:=Vector2(float(spec.foot[0]),float(spec.foot[1]))
 var origin:Vector2=layout_value.project(rect.position)-source_foot*scale_value
 # Top aligns to the real height; an independent base joins the feet.
 origin.y+=30.0*scale_value-_height(f)
 return {"origin":origin,"scale":scale_value,"spec":spec,"furniture":f,
  "shift":Vector2(float(spec.travel[0]),float(spec.travel[1]))*scale_value*float(app_value.drawer_open.get("bedside",0.0))}

static func bedside_handle(app_value,layout_value,catalog_value) -> Vector2:
 var item:Dictionary=_find(layout_value,"bedside")
 if not item.is_empty() and ProductionProps.available(layout_value,item):
  return ProductionProps.handle(layout_value,item,float(app_value.drawer_open.get("bedside",0)))
 var transform:Dictionary=_cabinet_transform(app_value,layout_value,catalog_value)
 var handle:Array=transform.spec.handle
 return transform.origin+Vector2(float(handle[0]),float(handle[1]))*float(transform.scale)+transform.shift

static func _reach(app_value) -> float:
 if not app_value.rules.search_active or app_value.search_actions==null:return 0.0
 if app_value.target_index<0:return 0.0
 var f:Dictionary=app_value.layout.furniture[app_value.target_index]
 if app_value.hero_pos.distance_to(f.at)>0.05:return 0.0
 var spec:Dictionary=app_value.search_actions.point(str(f.id))
 if spec.is_empty():return clampf(float(app_value.rules.search_elapsed)/0.25,0,1)
 var progress:float=float(app_value.rules.search_elapsed)/maxf(0.01,float(app_value.rules.search_duration))
 var amount:float=0.0
 for step in spec.steps:
  var contact:float=float(step.at)
  var reach:float=clampf((progress-(contact-0.08))/0.08,0,1) if progress<=contact else 1.0-clampf((progress-contact-0.025)/0.08,0,1)
  amount=maxf(amount,reach)
 return amount

static func bedside_hand(app_value,layout_value,catalog_value) -> Vector2:
 var foot:Vector2=layout_value.project(app_value.hero_pos)
 var handle:Vector2=bedside_handle(app_value,layout_value,catalog_value)
 var side:float=1.0 if handle.x>=foot.x else -1.0
 return (foot+Vector2(side*23,-HERO_HEIGHT*0.45)).lerp(handle,_reach(app_value))

func draw(target:Node2D,owner,room_layout,asset_catalog) -> void:
 canvas=target;app=owner;layout=room_layout;catalog=asset_catalog
 if app==null or layout==null:return
 canvas.draw_set_transform(Vector2.ZERO)
 _surfaces()
 var ordered:Array=[]
 for f in layout.furniture:ordered.append({"kind":"furniture","value":f,"depth":Presentation.footprint_depth(layout,f.rect)})
 if str(app.action_phase)!="resting":ordered.append({"kind":"actor","value":"hero","depth":layout.project(app.hero_pos).y})
 if app.home!=null:
  for a in app.home.actors():
   if str(a.data)=="cat" and str(app.home.data.cat.phase)=="held" and app.family!=null and app.family.present("father"):continue
   ordered.append({"kind":"actor","value":a.data,"depth":a.depth})
 if app.family!=null:
  for a in app.family.actors():ordered.append({"kind":"actor","value":a.data,"depth":a.depth})
 var box:Dictionary=_find(layout,"box")
 var box_state:Dictionary=_state("box")
 if not box.is_empty() and box_state.has("upper_shift"):
  var offset:Array=box_state.upper_shift
  var moved:=Rect2((box.rect as Rect2).position+Vector2(float(offset[0]),float(offset[1])),(box.rect as Rect2).size)
  ordered.append({"kind":"box","value":moved,"depth":Presentation.footprint_depth(layout,moved)})
 if app.family!=null and not app.family.data.get("gift",{}).is_empty():
  var index:int=0
  for id in app.family.data.gift:
   if app.rules.owners.get(str(id),"")!="floor":continue
   ordered.append({"kind":"gift","value":layout.project(layout.door_position())+Vector2(-12+index*18,0),"food_kind":str(app.family.data.food_types.get(str(id),"candy")),"depth":layout.project(layout.door_position()).y})
   index+=1
 var key_owner:String=str(app.session.data.get("key_owner",""))
 if not key_owner.is_empty() and app.key_visible() and not app.has_key():
  var key_pos:Vector2=app.key_position()
  ordered.append({"kind":"key","value":layout.project(key_pos)-Vector2(0,6),"depth":layout.project(key_pos).y})
 ordered.sort_custom(func(a,b):return float(a.depth)<float(b.depth))
 for entry in ordered:
  match str(entry.kind):
   "furniture":_furniture(entry.value)
   "actor":_actor(str(entry.value))
   "box":_prism(entry.value,float(box.get("upper_height_m",0.45))*HEIGHT_PIXELS,Color("b9a17d"))
   "gift":_food(entry.value,str(entry.food_kind))
   "key":_key(entry.value)
 _front_edges()
 _targets()
 canvas.draw_set_transform(Vector2.ZERO)

func _state(id:String) -> Dictionary:
 if app.search_actions==null:return {}
 return app.search_actions.states.get(str(app.room_id)+":"+id,{})

func _poly(points:Array,color:Color) -> void:
 canvas.draw_colored_polygon(PackedVector2Array(points),color)

func _textured(points:Array,uv_points:Array,color:Color) -> void:
 var uvs:=PackedVector2Array()
 for p in uv_points:uvs.append(p/Vector2(640,360))
 canvas.draw_polygon(PackedVector2Array(points),PackedColorArray([color]),uvs,SHELL)

func _surface_rect(rect:Rect2,height:float=0.0) -> Array:
 var up:=Vector2(0,-height)
 return [layout.project(rect.position)+up,layout.project(rect.position+Vector2(rect.size.x,0))+up,layout.project(rect.end)+up,layout.project(rect.position+Vector2(0,rect.size.y))+up]

func _surfaces() -> void:
 canvas.draw_rect(Rect2(-1000,-1000,3200,2400),Color("263136"))
 var size:Vector2=layout.world_size()
 var p:Array=_surface_rect(Rect2(Vector2.ZERO,size))
 _poly([p[0]+Vector2(-10,10),p[1]+Vector2(10,10),p[2]+Vector2(12,18),p[3]+Vector2(-10,18)],Color("1c272a"))
 # Crop only floor material: none of the old image's silhouette or walls.
 if not Materials.floor(canvas,layout,PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]),Color("ddd0ba")):
  _textured(p,[Vector2(190,175),Vector2(430,175),Vector2(430,285),Vector2(190,285)],Color("ddd0ba"))
 _architecture(false)
 canvas.draw_line(p[0]-Vector2(0,8),p[1]-Vector2(0,8),Color("7e8173"),5)
 var door_bottom:Vector2=layout.project(Vector2(float(layout.config.door.center_m[0]),0))
 var door_rect:Rect2=_door_rect(layout)
 canvas.draw_rect(door_rect.grow(5),Color("494e47"))
 canvas.draw_rect(door_rect,Color("806e54"))
 canvas.draw_rect(door_rect.grow(-7),Color("b19a70"),false,2)
 canvas.draw_circle(door_rect.position+Vector2(door_rect.size.x-13,door_rect.size.y*0.59),3,Color("dac48f"))
 if app.family!=null and app.family.data.get("blood_door",false):
  canvas.draw_rect(door_rect,Color(0.40,0.045,0.06,0.72))
  for i in range(9):
   var start:Vector2=door_rect.position+Vector2(8+i*9,0)
   canvas.draw_line(start,start+Vector2((i%3)-1,25+(i*23)%110),Color("64252a"),4)
  _poly([door_bottom+Vector2(-30,0),door_bottom+Vector2(8,-4),door_bottom+Vector2(34,6),door_bottom+Vector2(-8,14)],Color(0.35,0.07,0.09,0.7))
 # Fixed directional light footprint is independent of movable props.
 _poly([layout.project(Vector2(3.3,2.6)),layout.project(Vector2(4.6,2.6)),layout.project(Vector2(4.9,size.y)),layout.project(Vector2(3.6,size.y))],Color(0.92,0.83,0.57,0.14))

func _front_edges() -> void:
 var size:Vector2=layout.world_size()
 var spec:Dictionary=layout.config.window
 var half:float=float(spec.width_m)*0.5
 var center:float=float(spec.center_m[0])
 var start:float=center-half
 var end:float=center+half
 var view:Dictionary=Presentation.window_display("south",float(spec.width_m),float(spec.sill_height_m),float(spec.opening_height_m))
 var sill:float=float(view.sill_height_m)*HEIGHT_PIXELS
 var opening:float=float(view.opening_height_m)*HEIGHT_PIXELS
 var thickness:float=float(layout.config.wall.thickness_m)
 var y:float=size.y
 _architecture(true)
 # Only the actual recess and slim frame are additional geometry. The wall
 # below and beside the opening is already one continuous union surface.
 var a:Vector2=layout.project(Vector2(start,y+thickness*.52))-Vector2(0,sill)
 var b:Vector2=layout.project(Vector2(end,y+thickness*.52))-Vector2(0,sill)
 var ao:Vector2=layout.project(Vector2(start,y+thickness))-Vector2(0,sill)
 var bo:Vector2=layout.project(Vector2(end,y+thickness))-Vector2(0,sill)
 _poly([ao,bo,b,a],Color("c7bc9b"))
 _poly([ao,a,a-Vector2(0,opening),ao-Vector2(0,opening)],Color("7d887c"))
 _poly([bo,b,b-Vector2(0,opening),bo-Vector2(0,opening)],Color("7d887c"))
 _poly([a,b,b-Vector2(0,opening),a-Vector2(0,opening)],Color(0.52,0.69,0.71,0.12))
 canvas.draw_line(a,b,Color("aaa98e"),2)
 canvas.draw_line(a-Vector2(0,opening),b-Vector2(0,opening),Color("aaa98e"),2)
 for t in [0.0,0.5,1.0]:canvas.draw_line(a.lerp(b,t),a.lerp(b,t)-Vector2(0,opening),Color("aaa98e"),2)

func _prism(rect:Rect2,h:float,color:Color,bottom:float=0.0,material:String="") -> void:
 if Materials.enabled():
  Materials.prop_face(canvas,layout,SpatialProp._quad(rect),bottom+h,color,_prop_material if material.is_empty() else material,bottom)
  return
 var ground:Array=_surface_rect(rect,bottom)
 var top:Array=_surface_rect(rect,bottom+h)
 _poly([ground[0],ground[3],top[3],top[0]],color.darkened(0.23))
 _poly([ground[2],ground[3],top[3],top[2]],color.darkened(0.12))
 _poly(top,color)
 canvas.draw_polyline(PackedVector2Array([top[0],top[1],top[2],top[3],top[0]]),color.lightened(0.10),1.0)

func _furniture(f:Dictionary) -> void:
 _prop_material=Materials.prop_id(str(f.get("kind",f.id)),str(f.get("name","")))
 var r:Rect2=f.rect
 var h:float=_height(f)
 var color:Color=f.color
 var at:Vector2=layout.project(r.get_center())
 var props:Dictionary=_state(str(f.id))
 # Reveal a genuinely occluding tall prop without changing physical size.
 var bounds:Rect2=Presentation.prism_bounds(layout,r,h)
 if h>100 and Presentation.footprint_depth(layout,r)>layout.project(app.hero_pos).y and bounds.intersects(hero_body_rect(app,layout)):
  color.a=0.38
 if str(f.id)!="bedside" and _production_furniture(f,color,props):return
 match str(f.id):
  "bedside":_bedside(f)
  "bed":
   if Materials.enabled():
    var bed_item:Dictionary=f.duplicate();bed_item.kind="bed";SpatialProp.draw(canvas,layout,bed_item,color)
   else:
    _prism(r,h-12,Color("826e55"));_prism(r.grow(-0.035),12,Color("9aaeb0"),h-12)
    _prism(Rect2(r.position+Vector2(0.06,0.05),Vector2(0.42,r.size.y-0.1)),8,Color("d6d4bb"),h)
   if props.get("bedding_lifted",false):
    var edge:Vector2=layout.project(r.end)-Vector2(0,h)
    _poly([edge,edge+Vector2(-39,0),edge+Vector2(-28,-21),edge+Vector2(-3,-8)],Color("b1c0b7"))
   if str(app.action_phase)=="resting":_resting()
  "chair","desk":
   var seat_h:float=minf(h,0.46*HEIGHT_PIXELS) if str(f.id)=="chair" else h
   for corner in [r.position,r.end,r.position+Vector2(r.size.x,0),r.position+Vector2(0,r.size.y)]:
    var foot:Vector2=layout.project(corner)
    canvas.draw_line(foot,foot-Vector2(0,seat_h),color.darkened(0.2),5)
   _prism(r,6,color,seat_h-6)
   if str(f.id)=="chair":
    var left:Vector2=layout.project(r.position)
    var right:Vector2=layout.project(r.position+Vector2(r.size.x,0))
    for base in [left,right]:canvas.draw_line(base-Vector2(0,seat_h),base-Vector2(0,h),color,5)
    canvas.draw_line(left-Vector2(0,h-8),right-Vector2(0,h-8),color.lightened(0.1),12)
   else:
    for i in range(3):
     var paper:Vector2=layout.project(r.position+Vector2(0.14+i*0.32,0.20))-Vector2(0,h+3)
     paper.x+=8 if int(props.get("desk_shift",0))>i else 0
     _poly([paper,paper+Vector2(23,0),paper+Vector2(28,11),paper+Vector2(5,11)],[Color("c5b59a"),Color("758d8e"),Color("d9d1b6")][i])
  "box":
   var lower:float=float(f.get("lower_height_m",0.45))*HEIGHT_PIXELS
   _prism(r,lower,Color("6c8993"))
   if not props.has("upper_shift"):_prism(r,h-lower,Color("b9a17d"),lower)
  "stool":
   var seat:float=0.44*HEIGHT_PIXELS
   for side in [-1,1]:canvas.draw_line(at+Vector2(side*14,0),at+Vector2(side*11,-seat),Color("57849a"),5)
   _prism(r,5,Color("789eac"),seat-5)
   var box_height:float=float(f.get("attachment_height_m",0.3))*HEIGHT_PIXELS
   _prism(r.grow(-0.035),box_height,Color("bca583"),seat)
   if props.get("open",false):
    canvas.draw_line(at-Vector2(0,seat+box_height),at+Vector2(-26,-seat-box_height-16),Color("d0b996"),8)
    canvas.draw_line(at-Vector2(0,seat+box_height),at+Vector2(24,-seat-box_height-12),Color("d0b996"),8)
  "rack":
   canvas.draw_line(at,at-Vector2(0,h),Color("82725d"),5)
   canvas.draw_line(at-Vector2(19,0),at+Vector2(19,0),Color("82725d"),5)
   canvas.draw_line(at+Vector2(-27,-h+12),at+Vector2(27,-h+12),Color("82725d"),6)
   _poly([at+Vector2(-19,-h+13),at+Vector2(21,-h+13),at+Vector2(30,-h+44),at+Vector2(18,-h+49),at+Vector2(16,-18),at+Vector2(-15,-18),at+Vector2(-19,-h+47),at+Vector2(-30,-h+42)],Color("d1d4c7"))
   if str(app.action_phase)=="observe_cuff":canvas.draw_line(at+Vector2(18,-h+48),at+Vector2(36,-h+36),Color("e0dec8"),8)
  "fan":
   var center:Vector2=at-Vector2(0,h-24)
   canvas.draw_line(at,center,Color("637d80"),6)
   canvas.draw_line(at-Vector2(20,0),at+Vector2(20,0),Color("536f73"),7)
   canvas.draw_circle(center,24,Color("354d53"))
   for i in range(3):
    var angle:float=float(app.world_visual_time)*5+TAU*i/3.0
    canvas.draw_line(center,center+Vector2.from_angle(angle)*20,Color("88a2a0"),6)
   canvas.draw_arc(center,25,0,TAU,32,Color("9eb3ab"),2)
  _:
   _prism(r,h,color)
   var left:Vector2=layout.project(r.position+Vector2(0,r.size.y))
   var right:Vector2=layout.project(r.end)
   if str(f.id)=="books":
    for shelf in range(5):
     var level:float=7+float(shelf)*h/5.0
     canvas.draw_line(left-Vector2(0,level),right-Vector2(0,level),color.darkened(0.35),4)
     for i in range(5):
      var book:Vector2=left.lerp(right,float(i+1)/6.0)-Vector2(0,level+2)
      canvas.draw_line(book,book-Vector2(0,h/5.0-7),[Color("647d83"),Color("b4a177"),Color("a27666")][i%3],6)
   else:
    var mid:Vector2=(left+right)*0.5
    canvas.draw_line(mid-Vector2(0,5),mid-Vector2(0,h-6),color.darkened(0.4),2)
    for side in [-1,1]:canvas.draw_circle(mid+Vector2(side*7,-h*0.5),2.4,Color("cabb91"))
   if str(f.id)=="storage" and props.get("uniform_out",false):
    var cloth:Vector2=at-Vector2(0,h*0.7)
    _poly([cloth,cloth+Vector2(32,2),cloth+Vector2(36,29),cloth+Vector2(3,25)],Color("aab9b6"))
    canvas.draw_line(cloth+Vector2(10,17),cloth+Vector2(22,20),Color("965d59"),5)
    if props.get("label_viewed",false):canvas.draw_rect(Rect2(cloth+Vector2(12,3),Vector2(10,4)),Color("d9d5bc"))
 _label(at+Vector2(-22,18),str(f.name),Color("d2d1b9"),12)

func _production_furniture(f:Dictionary,color:Color,props:Dictionary) -> bool:
 var state:Dictionary=props.duplicate();state.world_visual_time=float(app.world_visual_time)
 if not ProductionProps.draw(canvas,layout,f,state,color.a):return false
 var r:Rect2=f.rect;var h:float=_height(f);var at:Vector2=layout.project(r.get_center())
 # Existing independently moving contents remain owned by the actual action
 # state. They are not baked into a new furniture or background image.
 if str(f.id)=="desk":
  for i in range(3):
   var paper:Vector2=layout.project(r.position+Vector2(.14+i*.32,.20))-Vector2(0,h+3)
   paper.x+=8 if int(props.get("desk_shift",0))>i else 0
   _poly([paper,paper+Vector2(23,0),paper+Vector2(28,11),paper+Vector2(5,11)],[Color("c5b59a"),Color("758d8e"),Color("d9d1b6")][i])
 elif str(f.id)=="rack":
  _poly([at+Vector2(-19,-h+13),at+Vector2(21,-h+13),at+Vector2(30,-h+44),at+Vector2(18,-h+49),at+Vector2(16,-18),at+Vector2(-15,-18),at+Vector2(-19,-h+47),at+Vector2(-30,-h+42)],Color("d1d4c7"))
  if str(app.action_phase)=="observe_cuff":canvas.draw_line(at+Vector2(18,-h+48),at+Vector2(36,-h+36),Color("e0dec8"),8)
 elif str(f.id)=="bed" and str(app.action_phase)=="resting":_resting()
 _label(at+Vector2(-22,18),str(f.name),Color("d2d1b9"),12)
 return true

func _bedside(f:Dictionary) -> void:
 var painted:bool=ProductionProps.draw(canvas,layout,f,{"open":float(app.drawer_open.get("bedside",0))})
 if catalog.current.is_empty():
  if not painted:_prism(f.rect,_height(f),f.color)
  return
 var transform:Dictionary=_cabinet_transform(app,layout,catalog)
 var origin:Vector2=transform.origin
 var scale_value:float=transform.scale
 var spec:Dictionary=transform.spec
 var shift:Vector2=transform.shift
 var tint:=Color(str(spec.tint))
 var size:=Vector2(float(spec.canvas[0]),float(spec.canvas[1]))*scale_value
 # Feet fill only the physical base gap introduced by the trial art's ratio.
 if not painted:
  _prism(f.rect,maxf(5.0,_height(f)-30.0*scale_value+5.0),Color("695f4b"))
  canvas.draw_texture_rect(catalog.texture(spec.body),Rect2(origin,size),false,tint)
 if not painted and shift.length()>0.01:
  var a:Vector2=origin+Vector2(55.1742,11.8642)*scale_value
  var b:Vector2=origin+Vector2(66.3666,30.4515)*scale_value
  canvas.draw_polygon(PackedVector2Array([a,b,b+shift,a+shift]),PackedColorArray([tint]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),catalog.texture(spec.tray))
 if not painted:canvas.draw_texture_rect(catalog.texture(spec.drawer),Rect2(origin+shift,size),false,tint)
 var props:Dictionary=_state("bedside")
 for entry in [["book","book_shift"],["clock","clock_shift"]]:
  var delta:Array=props.get(entry[1],[0,0])
  if spec.has(entry[0]):canvas.draw_texture_rect(catalog.texture(spec[entry[0]]),Rect2(origin+Vector2(float(delta[0]),float(delta[1]))*scale_value,size),false,tint)
 if not painted:canvas.draw_texture_rect(catalog.texture(spec.front),Rect2(origin,size),false,tint)

func _label(at:Vector2,value:String,color:Color=Color("d8ded0"),size:int=13) -> void:
 canvas.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _actor(id:String) -> void:
 if id=="hero":_hero();return
 if id in ["dog","cat"]:_animal(id);return
 if id not in ["mother","father"]:return
 var at:Vector2=layout.project(app.family.position(id))
 var state:Dictionary=app.family.data[id]
 var h:float=(1.62 if id=="mother" else 1.78)*HEIGHT_PIXELS
 var color:=Color("b6a190") if id=="mother" else Color("718389")
 var facing_array:Array=state.get("facing",[0,1])
 var facing:=Vector2(float(facing_array[0]),float(facing_array[1]))
 var forward:Vector2=(layout.project(app.family.position(id)+facing)-at).normalized()
 var stride:float=sin(float(app.world_visual_time)*9)*5 if not state.get("route",[]).is_empty() else 0.0
 if app.family.collapse_active():color=color.lerp(Color("82474e"),0.65);at.x+=sin(float(app.family.data.collapse.elapsed)*33)*3
 canvas.draw_circle(at,18,Color(0.06,0.08,0.08,0.3))
 canvas.draw_rect(Rect2(at+Vector2(-17,-h*0.76),Vector2(34,h*0.52)),color)
 canvas.draw_circle(at-Vector2(0,h*0.87),h*0.13,color.lightened(0.18))
 canvas.draw_circle(at-Vector2(0,h*0.87)+forward*11,2.5,Color("ded3b6"))
 for side in [-1,1]:
  canvas.draw_line(at+Vector2(side*10,-h*0.25),at+Vector2(side*10+side*stride,0),color,9)
  canvas.draw_line(at+Vector2(side*15,-h*0.70),at+Vector2(side*26,-h*0.37),color,8)
 if id=="father":
  var pose:Dictionary=app.family.father_presentation()
  if not pose.is_empty() and float(pose.reach)>0:
   var contact:Vector2=_father_contact(pose)
   var side:float=1 if contact.x>=at.x else -1
   var shoulder:Vector2=at+Vector2(side*15,-h*0.70)
   var hand:Vector2=(at+Vector2(side*26,-h*0.37)).lerp(contact,float(pose.reach))
   canvas.draw_line(shoulder,hand,color.lightened(0.15),8);canvas.draw_circle(hand,5,Color("c8bfa4"))
   if bool(pose.held):canvas.draw_arc(contact,7,0,TAU,16,Color("e1bd96"),2)
  _label(at+Vector2(-30,-h-12),"父亲 · "+str(pose.get("label",state.phase)))
 else:
  var phase:String=str(state.phase)
  if phase in ["comfort","transfer"]:
   var hero:Vector2=layout.project(app.hero_pos)
   var duration:float=float(app.family.config.test_parameters.get("transfer_duration",0.6))
   var reach:float=clampf(float(state.elapsed)/maxf(0.01,duration),0,1)
   var hand:Vector2=at+Vector2(24 if hero.x>at.x else -24,-h*0.4)
   var destination:Vector2=hero+Vector2(0,-HERO_HEIGHT*0.88 if phase=="comfort" else -HERO_HEIGHT*0.48)
   hand=hand.lerp(destination,reach)
   canvas.draw_line(at+Vector2(14 if hero.x>at.x else -14,-h*0.7),hand,color,8)
   if phase=="transfer" and app.rules.owners.get(app.family.food_id(str(state.branch)),"")=="mother":_food(hand,str(state.branch))
  _label(at+Vector2(-25,-h-12),"母亲 · "+{"approach":"接近","comfort":"抚慰","transfer":"递物","leave":"离开","drop":"放下物品"}.get(phase,phase))
 canvas.draw_line(at,at+forward*22,Color("c5c7a9"),2)
 if id=="father" and app.home!=null and app.home.present("cat") and str(app.home.data.cat.phase)=="held":
  var hold:Vector2=at-Vector2(0,h*0.52)
  for side in [-1,1]:canvas.draw_line(at+Vector2(side*15,-h*0.70),hold+Vector2(side*21,0),color,8)
  _animal("cat")

func _father_contact(pose:Dictionary) -> Vector2:
 var point:Vector2=app.hero_pos
 if float(pose.get("release",0))>0:
  var saved:Array=pose.release_point;point=Vector2(float(saved[0]),float(saved[1]))
 var hero:Vector2=layout.project(point)
 var father:Vector2=layout.project(app.family.position("father"))
 return hero+Vector2(20 if father.x>=hero.x else -20,-HERO_HEIGHT*0.55)

func _hero() -> void:
 var at:Vector2=layout.project(app.hero_pos)
 var phase:float=float(app.world_visual_time)
 if app.hero_state=="search":phase=float(app.rules.search_elapsed)
 elif app.hero_state=="scratch":phase=maxf(0,0.5-float(app.rules.reaction_left))
 elif app.hero_state=="hit":phase=maxf(0,0.25-float(app.rules.hurt_left))
 elif app.hero_state=="give":phase=maxf(0,0.6-float(app.action_left))
 var family_pose:Dictionary=app.family.father_presentation() if app.family!=null else {}
 var contact_pose:bool=(app.hero_state=="search" and app.target_index>=0) or bool(family_pose.get("held",false)) or app.hero_state=="eat"
 # Existing search atlas always reaches to its own right. Use its idle head
 # and legs with independently drawn upper limbs for actual world contacts.
 var frame:Dictionary=catalog.actor_frame("idle" if contact_pose else str(app.hero_state),app.hero_facing,phase)
 var scale_value:float=HERO_HEIGHT/ATLAS_BODY_HEIGHT
 var crouch:float=0.68 if app.hero_state=="search" and app.search_actions!=null and app.search_actions.pose=="low" else 1.0
 var scale2:=Vector2(scale_value,scale_value*crouch)
 canvas.draw_circle(at,18,Color(0.05,0.07,0.08,0.28))
 var production:bool=app.get("production_actors")!=null and app.production_actors.draw_hero(canvas,at,HERO_HEIGHT)
 if contact_pose and not production:
  _actor_piece(frame,at,scale2,Rect2(0,0,64,32))
  _actor_piece(frame,at,scale2,Rect2(0,50,64,30))
  var tone:=Color("8cacbb") if str(catalog.active_set)=="a" else Color("829e9b")
  var top:float=(72.0-32.0)*scale2.y
  var bottom:float=(72.0-50.0)*scale2.y
  _poly([at+Vector2(-14,-top),at+Vector2(14,-top),at+Vector2(21,-bottom),at+Vector2(-21,-bottom)],tone)
  var hand_side:float=1.0
  if app.hero_state=="search" and app.target_index>=0:hand_side=1 if _search_hand(layout.furniture[app.target_index]).x>=at.x else -1
  elif bool(family_pose.get("held",false)):hand_side=1 if _father_contact(family_pose).x>=at.x else -1
  canvas.draw_line(at+Vector2(-hand_side*14,-top+4),at+Vector2(-hand_side*25,-HERO_HEIGHT*0.42*crouch),tone,7)
 elif not production:canvas.draw_texture_rect_region(frame.texture,Rect2(at-frame.foot*scale2,frame.size*scale2),frame.source)
 var forward:Vector2=(layout.project(app.hero_pos+app.hero_facing)-at).normalized()
 canvas.draw_line(at,at+forward*24,Color("e3bb7d"),2)
 if app.hero_state=="search" and app.target_index>=0:
  var f:Dictionary=layout.furniture[app.target_index]
  var hand:Vector2=_search_hand(f)
  var shoulder:Vector2=at+Vector2(17 if hand.x>=at.x else -17,-HERO_HEIGHT*0.70*crouch)
  if not production:canvas.draw_line(shoulder,hand,Color("90b6c0"),7);canvas.draw_circle(hand,4,Color("d6c8ac"))
 if app.family!=null:
  var pose:Dictionary=family_pose
  if bool(pose.get("held",false)):
   var hand:Vector2=_father_contact(pose)
   if not production:canvas.draw_line(at+Vector2(17 if hand.x>=at.x else -17,-HERO_HEIGHT*0.70),hand,Color("a8c7cc"),7)
   _label(at+Vector2(-27,32),"被抓握 · 带行" if pose.phase=="drag" else "被抓握 · 转身",Color("edc8a5"),12)
  if app.hero_state=="eat" and not app.family.data.get("eating",{}).is_empty():
   var eating:Dictionary=app.family.data.eating
   var t:float=clampf(float(eating.elapsed)/float(app.family.config.timing.eat),0,1)
   var reach:float=clampf(t/0.30,0,1) if t<0.78 else clampf((1-t)/0.22,0,1)
   var hand:Vector2=(at+Vector2(27,-HERO_HEIGHT*0.37)).lerp(at+Vector2(12,-HERO_HEIGHT*0.86),reach)
   if not production:canvas.draw_line(at+Vector2(16,-HERO_HEIGHT*0.68),hand,Color("9dbec5"),7)
   _food(hand,str(app.family.data.food_types.get(str(eating.item),"porridge")))
  elif not app.family.data.get("inventory",[]).is_empty():
   var held_slot:int=0
   for id in app.family.data.inventory:
    if app.rules.owners.get(str(id),"")!="hero":continue
    _food(at+Vector2(27+held_slot*16,-HERO_HEIGHT*0.42),str(app.family.data.food_types.get(str(id),"candy")))
    held_slot+=1
 if app.has_key() and str(app.session.data.get("key_owner",""))=="hero":_key(at+Vector2(-31,-HERO_HEIGHT*0.44))
 var label:String=app.search_actions.action_label if app.hero_state=="search" and app.search_actions!=null else {"idle":"自主观察","walk":"行走","scratch":"抓挠","hit":"受击","give":"取物","fear":"惊恐","eat":"食用"}.get(str(app.hero_state),str(app.hero_state))
 _label(at+Vector2(-28,-HERO_HEIGHT*crouch-13),label)

func _actor_piece(frame:Dictionary,at:Vector2,scale_value:Vector2,piece:Rect2) -> void:
 var source:Rect2=frame.source
 canvas.draw_texture_rect_region(frame.texture,Rect2(at+(piece.position-frame.foot)*scale_value,piece.size*scale_value),Rect2(source.position+piece.position,piece.size))

func _search_hand(f:Dictionary) -> Vector2:
 var at:Vector2=layout.project(app.hero_pos)
 if str(f.id)=="bedside":return bedside_hand(app,layout,catalog)
 var rect:Rect2=f.rect
 var touch:=Vector2(clampf(app.hero_pos.x,rect.position.x,rect.end.x),clampf(app.hero_pos.y,rect.position.y,rect.end.y))
 var height:float=minf(_height(f),HERO_HEIGHT*0.65)
 if app.search_actions.pose=="low":height=minf(height,18)
 elif app.search_actions.pose=="high":height=minf(_height(f),HERO_HEIGHT*0.91)
 var destination:Vector2=layout.project(touch)-Vector2(0,height)
 var side:float=1 if destination.x>=at.x else -1
 var rest:Vector2=at+Vector2(side*25,-HERO_HEIGHT*(0.28 if app.search_actions.pose=="low" else 0.45))
 return rest.lerp(destination,_reach(app))

func _resting() -> void:
 var pose:Dictionary=_rest_pose(app,layout)
 if app.get("production_actors")!=null and app.production_actors.draw_resting(canvas,pose.center,float(pose.angle),HERO_HEIGHT):return
 var frame:Dictionary=catalog.actor_frame("idle",app.hero_facing,0.0)
 var scale_value:float=HERO_HEIGHT/ATLAS_BODY_HEIGHT
 canvas.draw_set_transform(pose.center,float(pose.angle))
 canvas.draw_texture_rect_region(frame.texture,Rect2(-Vector2(frame.foot.x,frame.foot.y-ATLAS_BODY_HEIGHT*0.5)*scale_value,frame.size*scale_value),frame.source)
 canvas.draw_set_transform(Vector2.ZERO)

func _animal(id:String) -> void:
 var at:Vector2=layout.project(app.home.position(id))
 var state:Dictionary=app.home.data[id]
 var dog:bool=id=="dog"
 if not dog and str(state.phase)=="held" and app.family!=null and app.family.present("father"):
  at=layout.project(app.family.position("father"))-Vector2(0,1.78*HEIGHT_PIXELS*0.52)
 var scale_value:float=1.5 if dog else 1.15
 var color:=Color("bb9959") if dog else Color("2a353b")
 var direction:float=1.0
 var route:Array=state.get("route",[])
 if not route.is_empty():
  var next:Array=route[0]
  direction=1.0 if layout.project(Vector2(float(next[0]),float(next[1]))).x>=at.x else -1.0
 var body:=Rect2(at+Vector2(-20,-22)*scale_value,Vector2(40,19)*scale_value)
 if dog and not bool(state.alive):
  _poly([at+Vector2(-27,0),at+Vector2(-19,-10),at+Vector2(-6,-7),at+Vector2(5,-15),at+Vector2(26,-5),at+Vector2(21,6),at+Vector2(-11,9)],Color("784044"))
  canvas.draw_line(at+Vector2(-15,-3),at+Vector2(13,1),Color("a66d63"),5)
  _label(at+Vector2(-28,-23),"大黄 · 肉泥占位",Color("c8a598"),12);return
 canvas.draw_circle(at,17*scale_value,Color(0.07,0.08,0.08,0.22))
 canvas.draw_rect(body,color)
 var head:Vector2=at+Vector2(direction*22,-26)*scale_value
 canvas.draw_circle(head,10*scale_value,color.lightened(0.1))
 canvas.draw_line(head+Vector2(-4,-5)*scale_value,head+Vector2(-7,-14)*scale_value,color,4)
 canvas.draw_line(at+Vector2(-direction*19,-17)*scale_value,at+Vector2(-direction*32,-28)*scale_value,color,5)
 for side in [-1,1]:canvas.draw_line(at+Vector2(side*13,-9)*scale_value,at+Vector2(side*13,0)*scale_value,color,5)
 if dog:canvas.draw_line(head+Vector2(-direction*5,1)*scale_value,head+Vector2(-direction*5,10)*scale_value,Color("ab5c53"),4)
 if str(state.phase)=="attack":canvas.draw_line(head,head+Vector2(direction*21,13),color.lightened(0.3),4)
 if dog and str(app.session.data.get("key_owner",""))=="dog":_key(head+Vector2(direction*10,7))
 _label(at+Vector2(-25,-49*scale_value),("大黄" if dog else "黑猫")+" · "+{"walk":"行走","search":"搜寻","bring":"衔回","occupy":"占据","attack":"抓挠","leave":"离开","idle":"停留","held":"被抱住"}.get(str(state.phase),str(state.phase)),Color("cbd1be"),12)

func _food(at:Vector2,kind:String) -> void:
 if kind=="porridge":
  _poly([at+Vector2(-12,-5),at+Vector2(12,-5),at+Vector2(8,5),at+Vector2(-8,5)],Color("bfcac0"))
  canvas.draw_line(at+Vector2(-11,-5),at+Vector2(11,-5),Color("e2d6b1"),4)
 else:canvas.draw_rect(Rect2(at-Vector2(7,5),Vector2(14,10)),Color("87634d") if kind=="chocolate" else Color("c6b077"))

func _key(at:Vector2) -> void:
 canvas.draw_circle(at,5,Color("e8c77a"),false,2)
 canvas.draw_line(at+Vector2(5,0),at+Vector2(17,0),Color("e8c77a"),3)
 canvas.draw_line(at+Vector2(13,0),at+Vector2(13,5),Color("e8c77a"),2)

func _targets() -> void:
 var door_foot:Vector2=layout.project(layout.door_position())
 var blood:bool=app.family!=null and app.family.data.get("blood_door",false)
 var door_label:String="渗血的门" if blood else "门"
 if not blood:
  for id in app.visible_doors:
   door_label=app.room_title(str(id));break
 _label(door_foot+Vector2(-32,22),door_label,Color("e8c1ae") if blood else Color("d6dfca"),14)
 if app.target_index>=0 and app.target_index<layout.furniture.size():
  var target:Dictionary=layout.furniture[app.target_index]
  var at:Vector2=layout.project(target.at)
  canvas.draw_arc(at,15,0,TAU,32,Color("dac596"),1.5)
  if app.rules.search_active:canvas.draw_arc(at,18,-PI*0.5,-PI*0.5+TAU*float(app.rules.search_elapsed)/maxf(0.01,float(app.rules.search_duration)),40,Color("9bcbb7"),3)
 if canvas.get("debug_geometry")==true:
  for f in layout.furniture:
   var points:Array=_surface_rect(f.rect);points.append(points[0])
   canvas.draw_polyline(PackedVector2Array(points),Color(1,0.4,0.3,0.7),1)
  for point in app.hero_route:canvas.draw_circle(layout.project(point),2,Color("90d8bc"))
