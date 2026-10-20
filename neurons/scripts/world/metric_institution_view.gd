extends RefCounted
## Metric institution presentation only. Reads physical state; never settles
## a rule, moves an actor or changes navigation. All coordinates are world pixels.
const Metric=preload("res://scripts/world/metric_bedroom_view.gd")
const Presentation=preload("res://scripts/world/spatial_presentation.gd")
const Architecture=preload("res://scripts/world/architectural_surface.gd")
const Boundary=preload("res://scripts/world/spatial_boundary.gd")
const Geometry=preload("res://scripts/world/spatial_geometry.gd")
const Materials=preload("res://scripts/world/spatial_materials.gd")
const SpatialProp=preload("res://scripts/world/spatial_prop.gd")
const HEIGHT:float=Presentation.HEIGHT_PIXELS
const HUMAN:float=1.75*HEIGHT # Visual ruler only, not canonical character height.
const INK:=Color("35464a")
const PHASES={
 "idle":"等候","walk":"行走","approach":"实际接近","grab":"伸手准备","reach":"抓握前摇","hold":"固定身体","drag":"抓握带行","release":"释放","sample":"取样接触",
 "registration":"核对登记","nurse_register":"核对登记","bandage":"包扎","exam":"检查","prescription":"填写处方","prescription_transfer":"递交处方","mix":"配药","cup_transfer":"递杯","raise_cup":"举杯吞服",
 "wrist_check":"核对腕带","wrist_reach":"抓腕前摇","wrist_hold":"实际扭腕","diagnosis":"记录陈述","medical_order_write":"填写医嘱","order_transfer":"递出医嘱","order_receive":"接收医嘱",
 "registration_followup":"追问记录","records_guard_drag":"抓握带离","ward_ordinary_hero_drag":"带至站侧","ward_isolation_drag":"带入观察位",
 "read":"翻看原件","write":"书写","prepare":"准备接触","contact":"实际接触","finish":"收手恢复","return":"返回","leave":"离开","exit":"离场",
 "paperwork":"填写转运单","push":"实际推行","frame":"经过门框","fingers":"门边接触","lift":"抬起","carry_exit":"携袋离开",
 "photo_prepare":"伸手取照","photo_contact":"收存照片","photo_finish":"收手","shoe_route":"接近遗物","shoe_prepare":"伸手取鞋","shoe_contact":"收存鞋子","shoe_finish":"收手",
 "search":"搜寻","scratch":"抓挠","hit":"受击","give":"交接动作","fear":"惊恐","eat":"食用","dead":"倒地","collapsed":"倒地"
}
var canvas:Node2D
var app
var layout
var catalog
var font:Font=ThemeDB.fallback_font
var actor_parts=Metric.new()
var architectural_pieces:Array=[]
var _prop_material:String="painted_metal"

static func _v(value:Variant) -> Vector2:
 return value if value is Vector2 else Vector2(float(value[0]),float(value[1]))

static func _h(f:Dictionary) -> float:
 return float(f.get("height_m",float(f.get("height",50))/HEIGHT))*HEIGHT

static func _bed(room_layout) -> Dictionary:
 for f in room_layout.furniture:
  if str(f.get("kind",""))=="bed":return f
 return {}

static func _low_search(owner,room_layout) -> bool:
 if not owner.rules.search_active or owner.target_index<0 or owner.target_index>=room_layout.furniture.size():return false
 var f:Dictionary=room_layout.furniture[owner.target_index]
 var label:String=str(f.get("name",""))
 return _h(f)<HEIGHT*.6 or label.contains("下") or label.contains("底") or label.contains("垃圾")

static func _rest_pose(owner,room_layout) -> Dictionary:
 var bed:Dictionary=_bed(room_layout)
 var t:float=smoothstep(0,.3,clampf(1.2-float(owner.action_left),0,1.2))
 var from:Vector2=room_layout.project(owner.hero_pos)-Vector2(0,HUMAN*.5)
 var to:Vector2=room_layout.project((bed.rect as Rect2).get_center())-Vector2(0,_h(bed)+8) if not bed.is_empty() else from
 return {"center":from.lerp(to,t),"angle":-PI*.5*t,"t":t}

static func hero_body_rect(owner,room_layout) -> Rect2:
 if owner.action_phase=="resting":
  var pose:Dictionary=_rest_pose(owner,room_layout)
  var extent:Vector2=Vector2(25,HUMAN*.5).lerp(Vector2(HUMAN*.5,25),float(pose.t))
  return Rect2(pose.center-extent,extent*2)
 var h:float=HUMAN*(.68 if _low_search(owner,room_layout) else 1.0)
 return Rect2(room_layout.project(owner.hero_pos)+Vector2(-25,-h),Vector2(50,h+4))

static func item_pixel(owner,room_layout,item:Dictionary) -> Vector2:
 var at:Vector2=room_layout.project(_v(item.pos))
 if room_layout.room_id=="workshop" and str(item.id) in ["asylum_work_box","asylum_product_label"] and owner.asylum.data.get("ward_events",{}).get("work",{}).get("box","")=="table2":
  return room_layout.project_at_height(room_layout.get_object_anchor("product_surface"),float(room_layout.config.object_anchors.product_surface.height_m))-Vector2(0,8)
 if str(item.get("kind",""))=="ward_window":
  var portal:Dictionary=room_layout.portal("ward" if room_layout.room_id=="lobby" else "lobby")
  return room_layout.project(portal.wall_point)-Vector2(0,float(room_layout.config.get("ward_window_height_m",1.35))*HEIGHT)
 var offset:Vector2=_v(item.get("draw_offset",[0,0]))*(HUMAN/57.0)
 if item.get("held",false) and offset==Vector2.ZERO:offset=Vector2(31,-HUMAN*.48)
 if str(owner.rules.owners.get(str(item.get("id","")),""))=="hero" and offset==Vector2.ZERO:offset=Vector2(31,-HUMAN*.48)
 return at+offset-Vector2(0,7)

static func _portal_face(room_layout,portal:Dictionary) -> PackedVector2Array:
 var axis:=Vector2(1,0) if str(portal.wall) in ["north","south"] else Vector2(0,1)
 var wall_point:Vector2=_v(portal.get("wall_point",portal.threshold))
 var a:Vector2=room_layout.project(wall_point-axis*float(portal.width_m)*.5)
 var b:Vector2=room_layout.project(wall_point+axis*float(portal.width_m)*.5)
 var up:=Vector2(0,float(portal.height_m)*HEIGHT)
 return PackedVector2Array([a,b,b-up,a-up])

static func door_at_pixel(room_layout,pixel:Vector2) -> String:
 for portal in room_layout.portals:
  if Geometry2D.is_point_in_polygon(pixel,_portal_face(room_layout,portal)):return str(portal.toward)
 return ""

static func _faces(room_layout,f:Dictionary) -> Array:
 if not f.get("render",true):return []
 if f.has("collision_rects"):
  var result:Array=[]
  for rect:Rect2 in f.collision_rects:
   var part:Dictionary=f.duplicate();part.erase("collision_rects");part.rect=rect
   result.append_array(_faces(room_layout,part))
  return result
 var r:Rect2=f.rect;var height:float=_h(f);var kind:String=str(f.get("kind","cabinet"))
 if kind=="window" and f.has("wall_mount"):return [_window_face(room_layout,f)]
 if kind=="rack":
  var proxy:Dictionary=f.duplicate();proxy.id="rack"
  return Metric._furniture_faces(room_layout,proxy)
 if kind in ["chair","chairs","bench","desk","table","counter","cart"]:
  var seat:float=.46*HEIGHT if kind in ["chair","chairs","bench"] else height
  var faces:Array=Metric._prism_faces(room_layout,r,6,maxf(0,seat-6))
  for p in [r.position,r.end,r.position+Vector2(r.size.x,0),r.position+Vector2(0,r.size.y)]:
   var base:Vector2=room_layout.project(p)
   faces.append(Metric._stroke_face(base,base-Vector2(0,seat),5))
  if kind in ["chair","chairs","bench"]:
   var a:Vector2=room_layout.project(r.position)-Vector2(0,height)
   var b:Vector2=room_layout.project(r.position+Vector2(r.size.x,0))-Vector2(0,height)
   faces.append(PackedVector2Array([a,b,b+Vector2(0,20),a+Vector2(0,20)]))
  return faces
 return Metric._prism_faces(room_layout,r,height)

static func _window_face(room_layout,f:Dictionary,inset:float=.52) -> PackedVector2Array:
 var r:Rect2=f.rect;var display:Dictionary=_window_display(f)
 var h:float=float(display.sill_height_m)*HEIGHT
 var opening:float=float(display.opening_height_m)*HEIGHT
 var center:Vector2=r.get_center()
 var side:String=str(f.wall_mount);var axis:Vector2
 var t:float=float(room_layout.config.wall.get("thickness_m",.15))
 if side in ["west","east"]:
  center.x=-t*inset if side=="west" else room_layout.world_size().x+t*inset;axis=Vector2(0,r.size.y*.5)
 else:
  center.y=-t*inset if side=="north" else room_layout.world_size().y+t*inset;axis=Vector2(r.size.x*.5,0)
 var a:Vector2=room_layout.project(center-axis)-Vector2(0,h)
 var b:Vector2=room_layout.project(center+axis)-Vector2(0,h)
 return PackedVector2Array([a,b,b-Vector2(0,opening),a-Vector2(0,opening)])

static func _window_display(f:Dictionary) -> Dictionary:
 var rect:Rect2=f.rect;var side:String=str(f.wall_mount)
 var width:float=rect.size.x if side in ["north","south"] else rect.size.y
 return Presentation.window_display(side,width,float(f.get("sill_height_m",_h(f)/HEIGHT)),float(f.get("opening_height_m",65.0/HEIGHT)))

static func _fixed_group(f:Dictionary) -> String:
 return "fixed:"+str(f.get("id",f.get("name","partition")))

static func _outer_rect(room_layout,side:String,start:float,length:float,t:float) -> Rect2:
 var size:Vector2=room_layout.world_size()
 match side:
  "north":return Rect2(start,-t,length,t)
  "south":return Rect2(start,size.y,length,t)
  "west":return Rect2(-t,start,t,length)
  _:return Rect2(size.x,start,t,length)

static func _append_piece(result:Array,rect:Rect2,height:float,bottom:float,group:String,source_id:String) -> void:
 if rect.size.x>0 and rect.size.y>0 and height>0:
  result.append({"rect":rect,"bottom_m":bottom,"height_m":height,"group":group,"source_id":source_id})

static func _wall_cap(side:String,at:float,length:float,physical_height:float,windows:Array) -> float:
 var height:float=physical_height
 for segment:Dictionary in Presentation.wall_display_segments(side,length,physical_height):
  if at>=float(segment.start)-.00001 and at<=float(segment.end)+.00001:
   height=float(segment.height_m);break
 # A real window reveal is part of the surrounding continuous wall, not a
 # separate pair of floor-to-frame posts. Functional high windows stay high.
 for window:Dictionary in windows:
  if at>=float(window.start)-.12 and at<=float(window.end)+.12:
   height=maxf(height,minf(physical_height,float(window.display.wall_cap_height_m)))
 return height

## Actual display solids exported verbatim for the drawing locators. Physical
## room dimensions/portals/search stands remain in the unchanged layout data.
static func architecture_pieces(room_layout) -> Array:
 if room_layout.config.get("floor_polygon_m",[]).size()>4:
  return Boundary.pieces(room_layout,false,room_layout.portals)
 var result:Array=[];var size:Vector2=room_layout.world_size()
 var spec:Dictionary=room_layout.config.get("wall",{})
 var t:float=float(spec.get("thickness_m",.15));var physical_height:float=float(spec.get("height_m",2.55))
 var endpoint_heights:Dictionary={}
 for side:String in ["north","east","south","west"]:
  var length:float=size.x if side in ["north","south"] else size.y
  var group:String="near" if side in ["west","south"] else "far"
  var holes:Array=[];var windows:Array=[];var edges:Array=[0.0,length]
  for portal:Dictionary in room_layout.portals:
   if str(portal.wall)!=side:continue
   var at:Vector2=_v(portal.get("wall_point",portal.threshold))
   var center:float=at.x if side in ["north","south"] else at.y
   var start:float=maxf(0,center-float(portal.width_m)*.5);var end:float=minf(length,center+float(portal.width_m)*.5)
   holes.append({"start":start,"end":end,"height":float(portal.height_m)})
   edges.append(start);edges.append(end)
  for f:Dictionary in room_layout.furniture:
   if str(f.get("kind",""))!="window" or str(f.get("wall_mount",""))!=side:continue
   var rect:Rect2=f.rect;var start:float=rect.position.x if side in ["north","south"] else rect.position.y
   var end:float=rect.end.x if side in ["north","south"] else rect.end.y
   windows.append({"start":start,"end":end,"display":_window_display(f)})
   for edge:float in [maxf(0,start-.12),start,end,minf(length,end+.12)]:edges.append(edge)
  for segment:Dictionary in Presentation.wall_display_segments(side,length,physical_height):
   edges.append(float(segment.start));edges.append(float(segment.end))
  edges.sort();var unique:Array=[]
  for edge:float in edges:
   if unique.is_empty() or absf(edge-float(unique.back()))>.00001:unique.append(edge)
  var endpoints:Array=[]
  for at:float in [0.0,length]:
   var height:float=_wall_cap(side,at,length,physical_height,windows)
   for hole:Dictionary in holes:
    if at>=float(hole.start)-.00001 and at<=float(hole.end)+.00001:height=0.0;break
   endpoints.append(height)
  endpoint_heights[side]=endpoints
  for index in range(unique.size()-1):
   var a:float=float(unique[index]);var b:float=float(unique[index+1]);var middle:float=(a+b)*.5
   if b-a<=.00001:continue
   var cap:float=_wall_cap(side,middle,length,physical_height,windows)
   var rect:Rect2=_outer_rect(room_layout,side,a,b-a,t)
   var hole_height:float=-1.0
   for hole:Dictionary in holes:
    if middle>float(hole.start) and middle<float(hole.end):hole_height=float(hole.height);break
   if hole_height>=0:
    _append_piece(result,rect,cap-hole_height,hole_height,group,"outer:"+side);continue
   var found:Dictionary={}
   for window:Dictionary in windows:
    if middle>float(window.start) and middle<float(window.end):found=window;break
   if found.is_empty():_append_piece(result,rect,cap,0,group,"outer:"+side)
   else:
    var sill:float=float(found.display.sill_height_m);var top:float=sill+float(found.display.opening_height_m)
    _append_piece(result,rect,minf(cap,sill),0,group,"outer:"+side)
    _append_piece(result,rect,cap-top,top,group,"outer:"+side)
 # The four original rectangular boundaries meet at their inner edge. Fill
 # the previously omitted exterior t*t corner at their shared shown height.
 var corners:Array=[
  {"rect":Rect2(-t,-t,t,t),"a":"north","ai":0,"b":"west","bi":0,"group":"near"},
  {"rect":Rect2(size.x,-t,t,t),"a":"north","ai":1,"b":"east","bi":0,"group":"far"},
  {"rect":Rect2(-t,size.y,t,t),"a":"south","ai":0,"b":"west","bi":1,"group":"near"},
  {"rect":Rect2(size.x,size.y,t,t),"a":"south","ai":1,"b":"east","bi":1,"group":"near"}]
 for corner:Dictionary in corners:
  var height:float=minf(float(endpoint_heights[corner.a][corner.ai]),float(endpoint_heights[corner.b][corner.bi]))
  _append_piece(result,corner.rect,height,0,str(corner.group),"outer:corner")
 # Fixed interior walls and actual three-sided shower partitions join the
 # same solid union. Open furniture such as chairs keeps its separate drawing.
 var fixed:Array=[];fixed.append_array(room_layout.static_walls)
 for f:Dictionary in room_layout.furniture+room_layout.decor:
  if str(f.get("kind","")) in ["wall","facade","shower"]:fixed.append(f)
 for f:Dictionary in fixed:
  if not bool(f.get("render",true)):continue
  var rects:Array=f.get("collision_rects",[f.rect]);var group:String=_fixed_group(f)
  for rect:Rect2 in rects:
   _append_piece(result,rect,_h(f)/HEIGHT,0,group,str(f.get("id",f.get("name","partition"))))
 return result

static func furniture_at_pixel(room_layout,pixel:Vector2) -> int:
 var ordered:Array=[]
 for index in range(room_layout.furniture.size()):
  var f:Dictionary=room_layout.furniture[index]
  ordered.append({"index":index,"depth":Presentation.footprint_depth(room_layout,f.rect),"faces":_faces(room_layout,f)})
 for f in room_layout.decor:
  if not f.get("collision",false):continue
  ordered.append({"index":-1,"depth":Presentation.footprint_depth(room_layout,f.rect),"faces":_faces(room_layout,f)})
 ordered.sort_custom(func(a,b):return float(a.depth)>float(b.depth))
 for entry in ordered:
  for face in entry.faces:
   if Geometry2D.is_point_in_polygon(pixel,face):return int(entry.index)
 return -1

func draw(target:Node2D,owner,room_layout,asset_catalog) -> void:
 canvas=target;app=owner;layout=room_layout;catalog=asset_catalog
 actor_parts.canvas=canvas;actor_parts.app=app;actor_parts.layout=layout;actor_parts.catalog=catalog;actor_parts.font=font
 canvas.draw_set_transform(Vector2.ZERO)
 architectural_pieces=architecture_pieces(layout)
 _surfaces();_walls(false);_stairs()
 var ordered:Array=[]
 for f in layout.furniture:ordered.append({"type":"furniture","data":f,"depth":Presentation.footprint_depth(layout,f.rect)})
 for f in layout.decor:
  if _decor_visible(f):ordered.append({"type":"furniture","data":f,"depth":Presentation.footprint_depth(layout,f.rect)})
 for f in layout.static_walls:ordered.append({"type":"wall","data":f,"depth":Presentation.footprint_depth(layout,f.rect)})
 ordered.append({"type":"actor","data":"hero","depth":layout.project(app.hero_pos).y})
 if canvas.has_method("extra_actors"):ordered.append_array(canvas.extra_actors())
 ordered.sort_custom(func(a,b):return float(a.depth)<float(b.depth))
 for entry in ordered:
  match str(entry.type):
   "furniture":_furniture(entry.data)
   "wall":_inner_wall(entry.data)
   "actor":_actor(str(entry.data))
 if app.key_visible() and not app.has_key():_key(layout.project(app.key_position())-Vector2(0,9))
 _walls(true)
 # Real window frames retain their configured sill/opening above a cut wall.
 # Drawing them here keeps near-side structural cuts from hiding their target.
 for f in layout.furniture:
  if str(f.get("kind",""))=="window" and str(f.get("wall_mount","")) in ["west","south"]:_window(f)
 _targets()
 canvas.draw_set_transform(Vector2.ZERO)

func _decor_visible(f:Dictionary) -> bool:
 if not f.get("render",true):return false
 if str(f.get("kind",""))=="marker":return false # Original physical marker owns actual relics.
 if str(f.get("id",""))=="ward_laundry_bag":return app.hospital!=null and str(app.hospital.data.get("bag",""))=="ward"
 return true

func _inner_wall(f:Dictionary) -> void:
 var color:Color=f.get("color",Color("9da9a3"));var rect:Rect2=f.rect;var h:float=_h(f)
 var bounds:Rect2=Presentation.prism_bounds(layout,rect,h)
 if h>90 and Presentation.footprint_depth(layout,rect)>layout.project(app.hero_pos).y and bounds.intersects(hero_body_rect(app,layout)):color.a=.38
 Architecture.draw(canvas,layout,architectural_pieces,{"group":_fixed_group(f),"top":color,"edge":color.darkened(.22),"edge_width":1.0})

func _poly(points:Variant,color:Color) -> void:
 canvas.draw_colored_polygon(PackedVector2Array(points),color)

func _label(at:Vector2,label:String,color:Color=Color("e1e4d3"),size:int=13) -> void:
 if label.is_empty():return
 var width:float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 canvas.draw_rect(Rect2(at+Vector2(-width*.5-4,-size),Vector2(width+8,size+5)),Color(.08,.13,.14,.82))
 canvas.draw_string(font,at+Vector2(-width*.5,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _prism(rect:Rect2,height:float,color:Color,bottom:float=0.0) -> void:
 if Materials.enabled():
  Materials.prop_face(canvas,layout,SpatialProp._quad(rect),bottom+height,color,_prop_material,bottom)
  return
 var faces:Array=Metric._prism_faces(layout,rect,height,bottom)
 _poly(faces[1],color.darkened(.23));_poly(faces[2],color.darkened(.12));_poly(faces[0],color)
 var edge:PackedVector2Array=faces[0].duplicate();edge.append(edge[0])
 canvas.draw_polyline(edge,color.lightened(.12),1.2)

func _surfaces() -> void:
 var size:Vector2=layout.world_size()
 canvas.draw_rect(Rect2(-2500,-2500,8000,8000),Color("233034"))
 if Materials.enabled():
  Geometry.draw_floor(canvas,layout,Color("a1b1a7"))
  return
 if layout.config.get("floor_polygon_m",[]).size()>4:
  Geometry.draw_floor(canvas,layout,Color("85928c"))
  Geometry.draw_floor_lines(canvas,layout,1.0,Color(.22,.32,.31,.16))
  return
 _prism(Rect2(Vector2.ZERO,size),12,Color("778a87"),-12)
 var base:=Color("a1b1a7") if int(layout.phase_level)==2 else Color("85928c")
 _poly(Metric._projected_face(layout,Rect2(Vector2.ZERO,size),0),base)
 # Stall floors belong below people/props, not to the depth-sorted walls.
 for item:Dictionary in layout.furniture:
  if str(item.get("kind",""))=="shower":_poly(Metric._projected_face(layout,item.rect,0),Color("9aa99e"))
 for x in range(1,ceili(size.x)):
  canvas.draw_line(layout.project(Vector2(x,0)),layout.project(Vector2(x,size.y)),Color(.22,.32,.31,.16),1)
 for z in range(1,ceili(size.y)):
  canvas.draw_line(layout.project(Vector2(0,z)),layout.project(Vector2(size.x,z)),Color(.22,.32,.31,.16),1)

func _walls(front:bool) -> void:
 var tone:=Color("a5b2a8")
 Architecture.draw(canvas,layout,architectural_pieces,{"group":"near" if front else "far","top":tone,"edge":tone.darkened(.22),"edge_width":1.0})
 var size:Vector2=layout.world_size();var physical_height:float=float(layout.config.wall.get("height_m",2.55))
 for portal:Dictionary in layout.portals:
  var side:String=str(portal.wall)
  if (side in ["west","south"])!=front:continue
  var at:Vector2=_v(portal.get("wall_point",portal.threshold))
  var center:float=at.x if side in ["north","south"] else at.y
  var length:float=size.x if side in ["north","south"] else size.y
  _portal(portal,front,_wall_cap(side,center,length,physical_height,[])*HEIGHT)

func _portal(portal:Dictionary,front:bool,display_height:float) -> void:
 var face:PackedVector2Array=_portal_face(layout,portal)
 var cutaway:bool=display_height<float(portal.height_m)*HEIGHT
 if not cutaway:_poly(face,Color("3c514f"))
 if int(app.session.data.level)==3 and app.room_id=="corridor" and str(portal.toward)=="quiet":
  var progress:float=float(app.asylum.data.get("isolation_state",{}).get("door_progress",0))
  if progress>0:_poly(face,Color(.34,.40,.38,progress))
 # Picking still uses the complete physical face; only the visible frame is cut.
 var color:=Color("c2ccb9") if front else Color("d0d6c2")
 if cutaway:
  var up:=Vector2(0,display_height)
  canvas.draw_line(face[0],face[0]-up,color,4)
  canvas.draw_line(face[1],face[1]-up,color,4)
 else:canvas.draw_polyline(PackedVector2Array([face[0],face[3],face[2],face[1]]),color,5)
 canvas.draw_line(face[0],face[1],Color("6e8176"),3)
 var threshold:Vector2=layout.project(_v(portal.threshold))
 var landing:Vector2=layout.project(_v(portal.landing))
 canvas.draw_line(threshold,landing,Color(.75,.81,.69,.4),2)
 var title:String=app.room_title(str(portal.toward))
 _label((face[0]+face[1])*.5+Vector2(0,23) if front else (face[2]+face[3])*.5-Vector2(0,8),title,Color("e2e5d1"),12)

func _stairs() -> void:
 var stairs:Dictionary=layout.config.get("stairs_geometry",{})
 for flight in stairs.get("flights",[]):
  var raw:Array=flight.rect_m;var rect:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
  var direction:Vector2=_v(flight.get("direction",[0,1]));var count:int=maxi(1,int(flight.get("steps",9)))
  var along_x:bool=absf(direction.x)>absf(direction.y)
  # Geometry is explicitly planar: short tread lips show steps, without
  # inventing an actor height axis or drawing feet through tall stair blocks.
  for step in range(count):
   var progress:int=step if (direction.x if along_x else direction.y)>0 else count-1-step
   var part:Rect2=rect
   if along_x:part.position.x+=rect.size.x*float(step)/count;part.size.x=rect.size.x/count
   else:part.position.y+=rect.size.y*float(step)/count;part.size.y=rect.size.y/count
   _prism(part,4.0,Color("82958f").lightened(.025*(progress%2)))
  var from:Vector2=layout.project(rect.get_center()-direction*minf(rect.size.x,rect.size.y)*.25)
  var to:Vector2=layout.project(rect.get_center()+direction*minf(rect.size.x,rect.size.y)*.25)
  canvas.draw_line(from,to,Color("c3cfbc"),2)
  var arrow:Vector2=(to-from).normalized()
  canvas.draw_line(to,to-arrow.rotated(.6)*10,Color("c3cfbc"),2);canvas.draw_line(to,to-arrow.rotated(-.6)*10,Color("c3cfbc"),2)

func _window(f:Dictionary) -> void:
 var face:PackedVector2Array=_window_face(layout,f)
 var outer:PackedVector2Array=_window_face(layout,f,1.0 if str(f.wall_mount) in ["west","south"] else 0.0)
 for edge_index in range(4):
  var next:int=(edge_index+1)%4
  _poly([outer[edge_index],outer[next],face[next],face[edge_index]],Color("a7ac96").darkened(.16 if edge_index!=0 else 0.0))
 _poly(face,Color(.53,.64,.60,.08))
 var edge:PackedVector2Array=face.duplicate();edge.append(face[0])
 canvas.draw_polyline(edge,Color("b8bca7"),3)
 canvas.draw_line(face[0].lerp(face[1],.5),face[3].lerp(face[2],.5),Color("afb8a4"),2)

func _furniture(f:Dictionary) -> void:
 if not f.get("render",true):return
 var rect:Rect2=f.rect;var h:float=_h(f);var tone:Color=f.get("color",Color("839b95"))
 var kind:String=str(f.get("kind","cabinet"));var at:Vector2=layout.project(rect.get_center())
 _prop_material=Materials.prop_id(kind,str(f.get("name","")))
 if kind in ["shower","wall","facade"]:
  var surface_tone:Color=tone
  if kind=="shower":surface_tone.a=.26
  Architecture.draw(canvas,layout,architectural_pieces,{"group":_fixed_group(f),"top":surface_tone,"edge":surface_tone.darkened(.22),"edge_width":1.0})
  # A movable privacy screen remains an event prop, independent of the fixed
  # three-sided partitions now included in the complete architectural union.
  if kind=="shower" and f.get("screen_target",false) and app.asylum.data.get("trace_events",{}).get("screen_closed",false):
   var a:Vector2=layout.project(rect.position+Vector2(0,rect.size.y));var b:Vector2=layout.project(rect.end)
   _poly([a,b,b-Vector2(0,h),a-Vector2(0,h)],Color("667e76"))
  _label(at-Vector2(0,h+8),str(f.get("name","")),Color("e1e3cf"),11)
  return
 if f.has("collision_rects"):
  for piece:Rect2 in f.collision_rects:
   if kind=="shower":
    var glass:Color=tone;glass.a=.26;_prism(piece,h,glass)
   else:
    var part:Dictionary=f.duplicate();part.erase("collision_rects");part.rect=piece;part.name="";_furniture(part)
  if kind=="shower" and f.get("screen_target",false) and app.asylum.data.get("trace_events",{}).get("screen_closed",false):
   var a:Vector2=layout.project(rect.position+Vector2(0,rect.size.y));var b:Vector2=layout.project(rect.end)
   _poly([a,b,b-Vector2(0,h),a-Vector2(0,h)],Color("667e76"))
  _label(at-Vector2(0,h+8),str(f.get("name","")),Color("e1e3cf"),11)
  return
 var bounds:Rect2=Presentation.prism_bounds(layout,rect,h)
 if h>110 and Presentation.footprint_depth(layout,rect)>layout.project(app.hero_pos).y and bounds.intersects(hero_body_rect(app,layout)):tone.a=.38
 if Materials.enabled() and kind in ["bed","exam_bed","chair","chairs","bench","desk","table","counter","cart","sink","toilet","plant","bag","books","shelf","wardrobe","fan","lamp"]:
  SpatialProp.draw(canvas,layout,f,tone)
  if not str(f.get("name","")).is_empty():_label(at-Vector2(0,h+8),str(f.name),Color("e1e3cf"),11)
  return
 match kind:
  "window":
   if f.has("wall_mount"):_window(f)
   else:_prism(rect,h,tone)
  "bed","exam_bed":
   _prism(rect,maxf(5,h-12),tone.darkened(.2));_prism(rect.grow(-.04),12,Color("c3cbb8"),maxf(0,h-12))
   var pillow:=Rect2(rect.position+Vector2(.07,.06),Vector2(rect.size.x-.14,minf(.42,rect.size.y-.12))) if rect.size.y>rect.size.x else Rect2(rect.position+Vector2(.07,.06),Vector2(minf(.42,rect.size.x-.14),rect.size.y-.12))
   _prism(pillow,8,Color("dde0cc"),h)
  "chair","chairs","bench","desk","table","counter","cart":
   var seat:float=.46*HEIGHT if kind in ["chair","chairs","bench"] else h
   for point in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
    var foot:Vector2=layout.project(point);canvas.draw_line(foot,foot-Vector2(0,seat),tone.darkened(.2),5)
   _prism(rect,6,tone,maxf(0,seat-6))
   if kind in ["chair","chairs","bench"]:
    var a:Vector2=layout.project(rect.position);var b:Vector2=layout.project(rect.position+Vector2(rect.size.x,0))
    canvas.draw_line(a-Vector2(0,seat),a-Vector2(0,h),tone,5);canvas.draw_line(b-Vector2(0,seat),b-Vector2(0,h),tone,5)
    _poly([a-Vector2(0,h),b-Vector2(0,h),b-Vector2(0,h-20),a-Vector2(0,h-20)],tone.lightened(.08))
    if kind=="chairs":
     for seat_index in range(1,maxi(2,int(rect.size.x/.6))):
      var split:Vector2=layout.project(rect.position+Vector2(seat_index*.6,0))
      canvas.draw_line(split-Vector2(0,h),split-Vector2(0,seat),tone.darkened(.25),2)
   if kind=="cart":
    for corner in [rect.position,rect.end]:canvas.draw_circle(layout.project(corner),5,Color("42585b"))
  "rack":
   canvas.draw_line(at,at-Vector2(0,h),Color("6e827f"),5)
   canvas.draw_line(at-Vector2(19,0),at+Vector2(19,0),Color("6e827f"),5)
   canvas.draw_line(at+Vector2(-27,-h+12),at+Vector2(27,-h+12),Color("a0b3aa"),6)
   _poly([at+Vector2(-19,-h+13),at+Vector2(21,-h+13),at+Vector2(30,-h+44),at+Vector2(18,-h+49),at+Vector2(16,-18),at+Vector2(-15,-18),at+Vector2(-19,-h+47),at+Vector2(-30,-h+42)],Color("cdd3c4"))
  "material_rack":
   for corner:Vector2 in [rect.position,rect.end,rect.position+Vector2(rect.size.x,0),rect.position+Vector2(0,rect.size.y)]:
    var foot:Vector2=layout.project(corner);canvas.draw_line(foot,foot-Vector2(0,h),tone.darkened(.2),4)
   for level in [.3,.8,1.3]:_prism(rect,4,tone,level*HEIGHT)
   var materials:Dictionary=app.asylum.data.get("ward_events",{}).get("work",{})
   if materials.get("paper","rack")=="rack":
    var stack:Vector2=at-Vector2(18,.8*HEIGHT+5)
    for sheet in range(3):canvas.draw_rect(Rect2(stack+Vector2(sheet*2,-sheet*3),Vector2(27,6)),Color("d2cebc"))
   if materials.get("label","rack")=="rack":canvas.draw_circle(at+Vector2(25,-1.3*HEIGHT-7),7,Color("c1b694"))
  "board":
   for end:Vector2 in [rect.position,rect.position+Vector2(rect.size.x,0)]:
    var foot:Vector2=layout.project(end);canvas.draw_line(foot,foot-Vector2(0,h),tone.darkened(.25),4)
   _prism(rect,HEIGHT,Color("c5cbbb"),maxf(0,h-HEIGHT))
   if layout.room_id=="group_therapy":
    var device:Vector2=at-Vector2(0,h-HEIGHT*.85)
    canvas.draw_rect(Rect2(device-Vector2(17,6),Vector2(34,12)),INK)
    if app.asylum.data.get("ward_events",{}).get("therapy",{}).get("recording",false):canvas.draw_circle(device+Vector2(10,0),3,Color("b16e5e"))
  "curtain":
   tone.a=.35
   _prism(rect,h,tone)
   canvas.draw_line(layout.project(rect.position)-Vector2(0,h),layout.project(rect.end)-Vector2(0,h),Color("93aaa1"),4)
  "parking":
   var edge:PackedVector2Array=Metric._projected_face(layout,rect,1);edge.append(edge[0])
   canvas.draw_polyline(edge,Color(.7,.8,.68,.45),2)
  "bag":
   _prism(rect,h,tone)
   canvas.draw_arc(at-Vector2(0,h),10,PI,TAU,16,tone.lightened(.2),3)
  "plant":
   _prism(rect,h*.35,Color("9b9a7c"))
   for side in [-1,0,1]:
    var tip:Vector2=at+Vector2(side*15,-h+abs(side)*10)
    canvas.draw_line(at-Vector2(0,h*.3),tip,Color("5b7465"),4)
    _poly([tip+Vector2(-10,3),tip-Vector2(2,12),tip+Vector2(12,-3),tip+Vector2(3,8)],Color("728e73"))
  _:
   _prism(rect,h,tone)
   if kind in ["screen","terminal","kiosk","machine","window"]:
    canvas.draw_rect(Rect2(at+Vector2(-20,-h+10),Vector2(40,29)),Color("334f54"))
   elif kind=="sink":
    canvas.draw_set_transform(at+Vector2(0,-h+6),0,Vector2(1,.32));canvas.draw_circle(Vector2.ZERO,17,Color("4e6667"));canvas.draw_set_transform(Vector2.ZERO)
    canvas.draw_line(at-Vector2(0,h),at-Vector2(0,h+15),Color("becac3"),4)
   elif kind in ["cabinet","shelf","drawer","books","wardrobe","fridge"]:
    var face:PackedVector2Array=Metric._prism_faces(layout,rect,h)[2]
    for portion in [.33,.66]:
     canvas.draw_line(face[0].lerp(face[3],portion),face[1].lerp(face[2],portion),tone.darkened(.24),2)
    var open:float=float(app.drawer_open.get(str(f.id),0))
    if f.get("locked_upper",false):
     open=material_drawer_open(f)
     var front:=Rect2(rect.position.x,rect.end.y+.02+open*.12,rect.size.x,.035)
     _prism(front,.35*HEIGHT,tone.lightened(.08),.8*HEIGHT)
     var handle:Vector2=material_handle(f)
     canvas.draw_line(handle-Vector2(11,0),handle+Vector2(11,0),Color("d5d5bb"),4)
     var lock:Vector2=layout.project(Vector2(rect.get_center().x,rect.end.y))-Vector2(0,1.38*HEIGHT)
     canvas.draw_arc(lock-Vector2(0,5),5,PI,TAU,12,INK,2);canvas.draw_rect(Rect2(lock-Vector2(6,4),Vector2(12,10)),INK)
    elif open>0:
     var center:Vector2=at-Vector2(0,h*.55)+Vector2(0,open*10)
     canvas.draw_line(center-Vector2(13,0),center+Vector2(13,0),Color("d2d3bb"),4)
 if not str(f.get("name","")).is_empty():_label(at-Vector2(0,h+8),str(f.name),Color("e1e3cf"),11)

func material_drawer_open(f:Dictionary) -> float:
 var event:Dictionary=app.asylum.data.get("ward_events",{}).get("clamp",{})
 if event.get("phase","")=="windup":return 1.0-clampf(float(event.get("elapsed",0))/float(app.asylum.ward_events.config.presentation_timing.drawer_windup),0,1)
 if event.get("phase","")=="release":return 0
 if event.get("phase","")=="done":return clampf(float(app.rules.search_elapsed)/.3,0,1) if app.rules.search_active and app.target_index==6 else 0
 return float(app.drawer_open.get(str(f.id),0))

func material_handle(f:Dictionary) -> Vector2:
 var rect:Rect2=f.rect
 return layout.project(Vector2(rect.get_center().x,rect.end.y+.02+material_drawer_open(f)*.12))-Vector2(0,float(f.contact_height_m)*HEIGHT)

func _phase_label(value:String) -> String:
 return str(PHASES.get(value,value if value.to_lower()==value.to_upper() else "事件进行中"))

func _actor(who:String) -> void:
 if who=="hero":_hero();return
 if who.begins_with("hospital_prop:") or who.begins_with("asylum_prop:"):
  var markers:Array=app.hospital.relic_markers() if who.begins_with("hospital_prop:") else canvas.asylum_props()
  for item in markers:
   if str(item.id)==who.get_slice(":",1) and str(item.room)==str(app.room_id):_item(item);return
  return
 var group=app.hospital if who.begins_with("hospital_") else app.asylum if who.begins_with("asylum_") else null
 if group==null:return
 var id:String=who.trim_prefix("hospital_").trim_prefix("asylum_")
 if not group.data.get("actors",{}).has(id):return
 # The living patient is already rendered on the moving-bed marker. Never
 # duplicate that person as a standing/walking body through the mattress.
 if group==app.asylum and id=="transport_patient":return
 var state:Dictionary=group.actor(id);var position:Vector2=group.position(id);var at:Vector2=layout.project(position)
 var phase:String=str(state.get("phase","idle"));var label:String=str(group.config.get("names",{}).get(id,id))
 var body:Dictionary=group.data.get("body",{})
 if str(body.get("actor",""))==id:phase=str(body.get("kind",phase))
 if group==app.asylum:
  var action:String=group.ward_events.action_label(id)
  if id=="med_nurse" and group.nurse_duty!=null:action=group.nurse_duty.action_label()
  if id=="registration_nurse" and group.intake!=null and group.intake.actor_reserved(id):action=group.intake.phase_label()
  if not action.is_empty():phase=action
 var wheelchair:bool=id=="wheelchair"
 var tone:=Color("8ca29c") if id not in ["patient","wheelchair","corner_patient","postop_patient"] else Color("819eae")
 var h:float=HUMAN*(.75 if wheelchair else 1.0)
 var direction:Vector2=_v(state.get("facing",[0,1]))
 _person(at,h,tone,direction,not state.get("route",[]).is_empty(),position,wheelchair)
 var contact:Dictionary=_paired_contact(group,id,state)
 if not contact.is_empty():
  _arm(at,h,_v(contact.pixel),float(contact.progress),tone)
  if contact.get("held",false):canvas.draw_arc(_v(contact.pixel),7,0,TAU,14,Color("d5ba91"),2)
 if group==app.hospital and id=="porter":
  var pack:Dictionary=group.relic_packing_action()
  if not pack.is_empty() and str(pack.room)==app.room_id:
   var to:Vector2=layout.project(_v(pack.pos))-Vector2(0,7)
   if position.distance_to(_v(pack.pos))<1.0:_arm(at,h,to,float(pack.progress),tone)
   phase=str(pack.label)
 _label(at-Vector2(0,h+29),label)
 _label(at-Vector2(0,h+10),_phase_label(phase),Color("e4c5a5"),11)

func _person(at:Vector2,h:float,tone:Color,facing:Vector2,moving:bool,position:Vector2,wheelchair:bool=false) -> void:
 canvas.draw_circle(at,18,Color(.04,.08,.08,.28))
 var stride:float=sin(float(app.world_visual_time)*9)*7 if moving else 0.0
 canvas.draw_rect(Rect2(at+Vector2(-17,-h*.76),Vector2(34,h*.5)),tone)
 canvas.draw_circle(at-Vector2(0,h*.87),h*.13,tone.lightened(.2))
 var forward:Vector2=(layout.project(position+facing)-layout.project(position)).normalized()
 canvas.draw_circle(at-Vector2(0,h*.87)+forward*10,2.5,Color("ded2b3"))
 for side in [-1,1]:
  var foot:Vector2=at+Vector2(side*10+side*stride,0)
  canvas.draw_line(at+Vector2(side*10,-h*.26),foot,tone,9)
  canvas.draw_line(at+Vector2(side*15,-h*.68),at+Vector2(side*26,-h*.37),tone,8)
 canvas.draw_line(at,at+forward*23,Color("d4b986"),2)
 if wheelchair:
  for side in [-1,1]:canvas.draw_arc(at+Vector2(side*23,-16),20,0,TAU,24,Color("40595c"),4)
  canvas.draw_line(at+Vector2(-26,-34),at+Vector2(26,-34),Color("c0c9bd"),5)

func _paired_contact(group,id:String,state:Dictionary) -> Dictionary:
 var body:Dictionary=group.data.get("body",{});var point:Vector2=app.hero_pos
 var held:bool=str(group.data.get("holder",""))==id and app.rules.gripped
 var active:bool=str(body.get("actor",""))==id
 var phase:String=str(body.get("kind",state.get("phase","")));var progress:float=clampf(float(body.get("elapsed",state.get("elapsed",0)))/.3,0,1)
 var guard:Dictionary=group.data.get("records_state",{}).get("guard",{})
 if id=="guard" and str(guard.get("target",""))=="patient" and str(guard.get("phase","")) in ["reach","drag"]:
  if not group.present("patient") or str(group.actor("patient").room)!=app.room_id:return {}
  point=group.position("patient");active=true;phase=str(guard.phase);held=phase=="drag"
  progress=clampf(float(guard.get("elapsed",0))/float(group.config.test_parameters.get("grab_prepare",.3)),0,1)
 if not active and not held:return {}
 if str(state.get("room",""))!=app.room_id or group.position(id).distance_to(point)>.95 or not layout.clear_segment(group.position(id),point):return {}
 if held:progress=1.0
 elif phase in ["approach","grab","reach","wrist_reach"]:
  if state.has("left"):progress=1.0-clampf(float(state.left)/float(group.config.test_parameters.get("grab_prepare",.3)),0,1)
  progress=minf(.92,progress)
 var at:Vector2=layout.project(point)
 var side:float=1 if layout.project(group.position(id)).x>=at.x else -1
 return {"pixel":at+Vector2(side*18,-HUMAN*.55),"progress":progress,"held":held}

func _arm(at:Vector2,h:float,target:Vector2,progress:float,tone:Color) -> void:
 var side:float=1 if target.x>=at.x else -1
 var shoulder:Vector2=at+Vector2(side*15,-h*.69)
 var hand:Vector2=(at+Vector2(side*26,-h*.37)).lerp(target,clampf(progress,0,1))
 canvas.draw_line(shoulder,hand,tone.lightened(.1),7);canvas.draw_circle(hand,4,Color("d6c6ab"))

func _hero() -> void:
 var at:Vector2=layout.project(app.hero_pos)
 if app.action_phase=="resting":
  var pose:Dictionary=_rest_pose(app,layout);var frame:Dictionary=catalog.actor_frame("idle",app.hero_facing,0)
  if app.get("production_actors")!=null and app.production_actors.draw_resting(canvas,pose.center,float(pose.angle),HUMAN):return
  var scale_value:float=HUMAN/57.0
  canvas.draw_set_transform(pose.center,float(pose.angle))
  canvas.draw_texture_rect_region(frame.texture,Rect2(-Vector2(frame.foot.x,frame.foot.y-28.5)*scale_value,frame.size*scale_value),frame.source)
  canvas.draw_set_transform(Vector2.ZERO);return
 var crouch:float=.68 if _low_search(app,layout) else 1.0
 var time:float=float(app.rules.search_elapsed) if app.rules.search_active else float(app.world_visual_time)
 if app.hero_state=="scratch":time=maxf(0,.5-float(app.rules.reaction_left))
 elif app.hero_state=="hit":time=maxf(0,.25-float(app.rules.hurt_left))
 elif app.hero_state=="give":time=maxf(0,.6-float(app.action_left))
 var contact:bool=app.rules.search_active or app.rules.gripped
 var frame:Dictionary=catalog.actor_frame("idle" if contact else str(app.hero_state),app.hero_facing,time)
 var scale2:=Vector2(HUMAN/57.0,HUMAN/57.0*crouch)
 canvas.draw_circle(at,18,Color(.04,.08,.08,.28))
 var production:bool=app.get("production_actors")!=null and app.production_actors.draw_hero(canvas,at,HUMAN)
 if contact and not production:
  actor_parts._actor_piece(frame,at,scale2,Rect2(0,0,64,32));actor_parts._actor_piece(frame,at,scale2,Rect2(0,50,64,30))
  canvas.draw_rect(Rect2(at+Vector2(-17,-40*scale2.y),Vector2(34,18*scale2.y)),Color("8caebc"))
  var free_side:float=-1.0
  if app.rules.search_active and app.target_index>=0 and layout.project((layout.furniture[app.target_index].rect as Rect2).get_center()).x<at.x:free_side=1.0
  canvas.draw_line(at+Vector2(free_side*15,-HUMAN*.69*crouch),at+Vector2(free_side*26,-HUMAN*.37*crouch),Color("8caebc"),7)
 elif not production:canvas.draw_texture_rect_region(frame.texture,Rect2(at-frame.foot*scale2,frame.size*scale2),frame.source)
 var group=app.hospital if int(app.session.data.level)==2 else app.asylum
 var body:Dictionary=group.data.get("body",{});var holder:String=str(group.data.get("holder",""))
 if app.rules.search_active and app.target_index>=0:
  var f:Dictionary=layout.furniture[app.target_index];var rect:Rect2=f.rect
  var touch:=Vector2(clampf(app.hero_pos.x,rect.position.x,rect.end.x),clampf(app.hero_pos.y,rect.position.y,rect.end.y))
  var hand_height:float=minf(_h(f),HUMAN*.65) if crouch==1 else .24*HEIGHT
  if str(f.get("kind",""))=="window" and f.has("wall_mount"):
   hand_height=float(_window_display(f).sill_height_m)*HEIGHT
   var inset:float=float(layout.config.wall.get("thickness_m",.15))*.52
   match str(f.wall_mount):
    "west":touch.x=-inset
    "east":touch.x=layout.world_size().x+inset
    "north":touch.y=-inset
    "south":touch.y=layout.world_size().y+inset
  var hand:Vector2=layout.project(touch)-Vector2(0,hand_height)
  if f.get("locked_upper",false):hand=material_handle(f)
  if not production:_arm(at,HUMAN*crouch,hand,clampf(float(app.rules.search_elapsed)/.25,0,1),Color("91b3c1"))
 elif not holder.is_empty() and group.data.get("actors",{}).has(holder):
  var contact_info:Dictionary=_paired_contact(group,holder,group.actor(holder))
  if not production and not contact_info.is_empty():_arm(at,HUMAN,_v(contact_info.pixel),1.0,Color("9ab8c2"))
 var reading:Dictionary=group.data.get("observation_state",{}).get("active",{}) if int(app.session.data.level)==2 else group.data.get("observations_state",{}).get("active",{})
 if int(app.session.data.level)==3 and reading.is_empty():reading=group.data.get("records_state",{}).get("reading",{})
 if not reading.is_empty():
  var progress:float=float(reading.get("phase_progress",clampf(float(reading.get("elapsed",0))/.25,0,1)))
  var phase:String=str(reading.get("phase","contact"))
  var reach:float=progress if phase=="prepare" else 1.0-progress if phase=="finish" else 1.0
  var hand:Vector2=at+Vector2(26+reach*9,-HUMAN*.55-reach*9)
  if not production:_arm(at,HUMAN,hand,1.0,Color("a9bdc0"))
  _paper(hand)
 if int(app.session.data.level)==3:
  var window_action:Dictionary=group.data.get("ward_window_state",{}).get("action",{})
  if not window_action.is_empty():
   var elapsed:float=float(window_action.elapsed)
   var reach:float=clampf(elapsed/group.WARD_WINDOW_PREPARE,0,1) if window_action.phase=="prepare" else clampf((group.WARD_WINDOW_PREPARE+group.WARD_WINDOW_CONTACT+group.WARD_WINDOW_FINISH-elapsed)/group.WARD_WINDOW_FINISH,0,1) if window_action.phase=="finish" else 1.0
   var hand:Vector2=item_pixel(app,layout,{"kind":"ward_window","pos":group.xy(group.ward_window_position())})
   if not production:_arm(at,HUMAN,hand,reach,Color("a9bdc0"))
 var cup:String="hospital_cup" if int(app.session.data.level)==2 else "asylum_cup"
 if app.rules.owners.get(cup,"")=="hero":
  var hand:Vector2=at+Vector2(29,-HUMAN*(.84 if str(body.get("kind",""))=="raise_cup" else .45))
  if not production:_arm(at,HUMAN,hand,1.0,Color("9db7be"))
  canvas.draw_rect(Rect2(hand+Vector2(-6,-8),Vector2(12,12)),Color("d5d9bd"))
 if app.has_key():_key(at+Vector2(-33,-HUMAN*.44))
 var forward:Vector2=(layout.project(app.hero_pos+app.hero_facing)-at).normalized()
 canvas.draw_line(at,at+forward*24,Color("edc483"),2)
 var label:String="自主观察" if str(app.hero_state)=="idle" else _phase_label(str(app.hero_state))
 if app.rules.gripped:label="被抓握 · "+_phase_label(str(body.get("kind","hold")))
 _label(at-Vector2(0,HUMAN*crouch+13),label)

func _paper(at:Vector2) -> void:
 canvas.draw_rect(Rect2(at+Vector2(-9,-13),Vector2(18,21)),Color("d4cdb0"))
 for y in [-7,-2,3]:canvas.draw_line(at+Vector2(-5,y),at+Vector2(5,y),Color("758179"),1)

func _item(item:Dictionary) -> void:
 var at:Vector2=item_pixel(app,layout,item);var kind:String=str(item.get("kind",""))
 match kind:
  "bag":
   canvas.draw_rect(Rect2(at+Vector2(-12,-22),Vector2(24,22)),Color("bcae85"));canvas.draw_arc(at+Vector2(0,-22),7,PI,TAU,12,Color("d7cba4"),3)
  "shoe":_poly([at+Vector2(-11,-8),at+Vector2(3,-9),at+Vector2(15,-2),at+Vector2(13,4),at+Vector2(-11,2)],Color("635d52"))
  "ward_window":
   var portal:Dictionary=layout.portal("ward" if app.room_id=="lobby" else "lobby")
   var axis:=Vector2(1,0) if str(portal.wall) in ["north","south"] else Vector2(0,1)
   var half:Vector2=(layout.project(portal.wall_point+axis*.26)-layout.project(portal.wall_point))
   var up:=Vector2(0,.16*HEIGHT)
   var frame:=PackedVector2Array([at-half-up,at+half-up,at+half+up,at-half+up])
   _poly(frame,Color("253c3e") if item.get("open",false) else Color("788f86"))
   var outline:PackedVector2Array=frame.duplicate();outline.append(frame[0]);canvas.draw_polyline(outline,Color("b9c7b8"),3)
   _label(at-Vector2(0,25),str(item.get("label","观察窗")),Color("e2e3cc"),11)
  "transport_bed","corpse":
   var p:Vector2=_v(item.pos);var rect:=Rect2(p-Vector2(1,.4),Vector2(2,.8))
   if kind=="corpse" and not item.get("on_board",false):
    _poly([at+Vector2(-62,-12),at+Vector2(55,-10),at+Vector2(63,12),at+Vector2(-59,14)],Color("8b9c91") if item.get("covered",false) else Color("9b8078"))
    if not item.get("covered",false):canvas.draw_circle(at+Vector2(-61,-3),12,Color("b39d8d"))
    return # A covered floor body is not yet a loaded transport board.
   _prism(rect,.6*HEIGHT,Color("718b85"));_prism(rect.grow(-.05),9,Color("b8c5b4"),.6*HEIGHT)
   if kind=="transport_bed":
    var top:Vector2=at-Vector2(0,.6*HEIGHT+12)
    var head:Vector2=top+Vector2(-59,-5)
    canvas.draw_circle(head,12,Color("c4c9b6"))
    canvas.draw_circle(head+Vector2(4,-2),2,INK)
    _poly([top+Vector2(-43,-15),top+Vector2(58,-12),top+Vector2(65,10),top+Vector2(-42,14)],Color("a4b7ae"))
    var exposed:bool=str(app.asylum.data.get("ward_events",{}).get("transfer",{}).get("phase",""))=="hand_grab"
    var shoulder:Vector2=top+Vector2(-32,6)
    var hand:Vector2=top+Vector2(-13,25) if exposed else top+Vector2(1,9)
    canvas.draw_line(shoulder,hand,Color("c4c9b6"),6)
    canvas.draw_circle(hand,4,Color("c4c9b6"))
    if exposed:canvas.draw_arc(hand,6,0,PI,10,Color("d1bd9a"),2)
    _label(head-Vector2(0,19),"被转运患者 · 活人卧姿占位",Color("e1e3cf"),11)
   if kind=="corpse" and not item.get("covered",false):canvas.draw_circle(at+Vector2(-55,-.6*HEIGHT),12,Color("b39d8d"))
  "trace":
   canvas.draw_set_transform(at,0,Vector2(1,.28));canvas.draw_circle(Vector2.ZERO,22,Color(.35,.06,.08,.55));canvas.draw_set_transform(Vector2.ZERO)
  "band":canvas.draw_arc(at,9,-.4,PI+.4,16,Color("d5d7bc"),4)
  "isolation_door":pass # The actual metric portal renders closing progress.
  "box":canvas.draw_rect(Rect2(at+Vector2(-14,-20),Vector2(28,20)),Color("b6a982"))
  _:_paper(at)

func _key(at:Vector2) -> void:
 canvas.draw_arc(at,5,0,TAU,16,Color("e7c77c"),2)
 canvas.draw_line(at+Vector2(5,0),at+Vector2(20,0),Color("e7c77c"),3)
 canvas.draw_line(at+Vector2(15,0),at+Vector2(15,5),Color("e7c77c"),3)

func _targets() -> void:
 if app.target_index<0 or app.target_index>=layout.furniture.size():return
 var at:Vector2=layout.project(layout.furniture[app.target_index].at)
 canvas.draw_arc(at,14,0,TAU,24,Color("dfc692"),2)
 if app.rules.search_active:canvas.draw_arc(at,19,-PI*.5,-PI*.5+TAU*float(app.rules.search_elapsed)/maxf(.01,float(app.rules.search_duration)),32,Color("a7d1bb"),3)
