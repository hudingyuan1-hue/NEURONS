extends RefCounted
## Complete architecture is independent from foreground visibility.
## Read-only 2D drawing; no collision, action timing, or world-state mutation.
const HEIGHT:float=78.0
const Presentation=preload("res://scripts/world/spatial_presentation.gd")
const Surface=preload("res://scripts/world/architectural_surface.gd")
const Geometry=preload("res://scripts/world/spatial_geometry.gd")
const Boundary=preload("res://scripts/world/spatial_boundary.gd")

static func wall_rect(size:Vector2,side:String,a:float,b:float,t:float) -> Rect2:
 match side:
  "north":return Rect2(a,-t,b-a,t)
  "south":return Rect2(a,size.y,b-a,t)
  "west":return Rect2(-t,a,t,b-a)
 return Rect2(size.x,a,t,b-a)

static func portals(layout,actual_portals:Array=[]) -> Array:
 if not actual_portals.is_empty():return actual_portals
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var result:Array=[]
 for item in spec.get("portals",[]):
  if layout.has_method("portal"):
   var actual:Dictionary=layout.portal(str(item.toward))
   if not actual.is_empty():result.append(actual)
 return result

static func _wall_pieces(layout,side:String,foreground:bool,height_override:float,actual_portals:Array) -> Array:
 var size:Vector2=layout.world_size()
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var height:float=float(spec.get("wall_height_m",spec.get("wall",{}).get("height_m",2.55)))
 if height_override>=0:height=height_override
 var thick:float=float(spec.get("wall_thickness_m",spec.get("wall",{}).get("thickness_m",.15)))
 var cuts:Array=[]
 for p in portals(layout,actual_portals):
  if str(p.get("wall",""))!=side:continue
  var at:Vector2=p.get("wall_point",p.at)
  var middle:float=at.x if side in ["north","south"] else at.y
  cuts.append({"a":middle-float(p.width_m)*.5,"b":middle+float(p.width_m)*.5,"h":float(p.height_m)})
 var length:float=size.x if side in ["north","south"] else size.y
 var limits:Array=spec.get("wall_ranges_m",{}).get(side,[0.0,length])
 var start:float=float(limits[0]);length=float(limits[1])
 var full_length:float=size.x if side in ["north","south"] else size.y
 var segments:Array=Presentation.wall_display_segments(side,full_length,height) if foreground and height_override<0 else [{"start":start,"end":length,"height_m":height}]
 var edges:Array[float]=[start,length]
 for segment in segments:
  for edge in [float(segment.start),float(segment.end)]:
   if edge>start and edge<length and not edges.has(edge):edges.append(edge)
 for cut in cuts:
  for edge in [float(cut.a),float(cut.b)]:
   if edge>start and edge<length and not edges.has(edge):edges.append(edge)
 edges.sort()
 var result:Array=[]
 for i in range(edges.size()-1):
  var a:float=edges[i];var b:float=edges[i+1];var middle:float=(a+b)*.5
  var shown:float=height
  for segment in segments:
   if middle>=float(segment.start) and middle<=float(segment.end):shown=float(segment.height_m);break
  var bottom:float=0.0
  for cut in cuts:
   if middle>float(cut.a) and middle<float(cut.b):bottom=maxf(bottom,float(cut.h))
  if shown<=bottom:continue
  result.append({"rect":wall_rect(size,side,a,b,thick),"bottom_m":bottom,"height_m":shown-bottom,"group":"near" if side in ["south","west"] else "far"})
 return result

static func architectural_decor_ids(layout) -> Dictionary:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var result:Dictionary={}
 for item:Dictionary in spec.get("decor",[]):
  if str(item.get("kind",""))=="wall" and not item.get("logical_exclusion",false) and item.get("render",true):result[str(item.id)]=true
 return result

static func architectural_partition_ids(layout) -> Dictionary:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var result:Dictionary={}
 for item:Dictionary in spec.get("partitions",[]):
  if item.get("logical_exclusion",false) or not item.get("render",true) or float(item.get("height_m",0))<=0:continue
  if item.get("rect_m",[]).size()!=4:continue
  result[str(item.id)]="fixed:"+str(item.id)
 return result

static func _ground_piece_at(pieces:Array,point:Vector2) -> Dictionary:
 var result:Dictionary={"height_m":0.0,"group":"far"}
 for piece:Dictionary in pieces:
  if float(piece.get("bottom_m",0))>.000001 or not (piece.rect as Rect2).has_point(point):continue
  if float(piece.height_m)>float(result.height_m):result={"height_m":float(piece.height_m),"group":piece.group}
 return result

static func _corner_pieces(layout,pieces:Array,thickness:float) -> Array:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var size:Vector2=layout.world_size();var outline:Array=[]
 for value in spec.get("floor_polygon_m",[[0,0],[size.x,0],[size.x,size.y],[0,size.y]]):outline.append(Vector2(float(value[0]),float(value[1])))
 var area:float=0.0
 for index in range(outline.size()):area+=(outline[index] as Vector2).cross(outline[(index+1)%outline.size()])
 if area<0:outline.reverse()
 var result:Array=[]
 for index in range(outline.size()):
  var point:Vector2=outline[index];var before:Vector2=outline[(index-1+outline.size())%outline.size()];var after:Vector2=outline[(index+1)%outline.size()]
  var incoming:Vector2=(point-before).normalized();var outgoing:Vector2=(after-point).normalized()
  # Only a real convex right-angle junction has a missing outside t×t.
  # Concave bends already overlap; absent walls/intentional openings stay open.
  if incoming.cross(outgoing)<.9999:continue
  if absf(incoming.x*incoming.y)>.00001 or absf(outgoing.x*outgoing.y)>.00001:continue
  var first_normal:=Vector2(incoming.y,-incoming.x);var second_normal:=Vector2(outgoing.y,-outgoing.x)
  # A short real jamb beside a doorway still reaches this corner. Probe
  # immediately along each edge, rather than half a wall thickness away.
  var first:Dictionary=_ground_piece_at(pieces,point-incoming*minf(.00001,point.distance_to(before)*.001)+first_normal*thickness*.5)
  var second:Dictionary=_ground_piece_at(pieces,point+outgoing*minf(.00001,point.distance_to(after)*.001)+second_normal*thickness*.5)
  var height:float=minf(float(first.height_m),float(second.height_m))
  if height<=.000001:continue
  var end:Vector2=point+(first_normal+second_normal)*thickness
  result.append({"rect":Rect2(Vector2(minf(point.x,end.x),minf(point.y,end.y)),Vector2.ONE*thickness),"bottom_m":0.0,"height_m":height,"group":"near" if first.group=="near" or second.group=="near" else "far"})
 return result

static func architecture_pieces(layout,outdoor:bool=false,actual_portals:Array=[]) -> Array:
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var thickness:float=float(spec.get("wall_thickness_m",spec.get("wall",{}).get("thickness_m",.15)))
 var result:Array=[]
 var contour:bool=spec.has("floor_polygon_m")
 if contour:result.append_array(Boundary.pieces(layout,outdoor,portals(layout,actual_portals)))
 else:
  for side:String in ["north","east","south","west"]:
   var near:bool=side in ["south","west"]
   result.append_array(_wall_pieces(layout,side,near,-1.0 if not outdoor or not near else .14,actual_portals))
 # These existing thin L-bend walls belong to the same architectural surface;
 # they keep their exact rectangles, height and logical exclusion boundary.
 for item:Dictionary in spec.get("decor",[]):
  if str(item.get("kind",""))!="wall" or item.get("logical_exclusion",false) or not item.get("render",true):continue
  var rect:Array=item.get("rect_m",[])
  if rect.size()!=4:continue
  result.append({"rect":Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])),"bottom_m":0.0,"height_m":float(item.height_m),"group":"far","source_id":str(item.id)})
 # Fixed partitions share the complete solid union, but retain their original
 # depth-sorted drawing slot so actors can stand in front of or behind them.
 var fixed_ids:Dictionary=architectural_partition_ids(layout)
 for item:Dictionary in spec.get("partitions",[]):
  if not fixed_ids.has(str(item.id)):continue
  var rect:Array=item.rect_m
  result.append({"rect":Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])),"bottom_m":0.0,"height_m":float(item.height_m),"group":str(fixed_ids[str(item.id)]),"source_id":str(item.id)})
 if not contour:result.append_array(_corner_pieces(layout,result,thickness))
 return result

static func draw_architecture(canvas,layout,foreground:bool,outdoor:bool=false,colors:Dictionary={},actual_portals:Array=[],group_override:String="") -> void:
 var tint:=Color("697b7c")
 var palette:Dictionary={"top":tint.lightened(.16),"west":tint.darkened(.28),"south":tint.darkened(.18),"edge":tint.darkened(.38),"edge_width":1.0}
 palette.merge(colors,true);palette.group=group_override if not group_override.is_empty() else "near" if foreground else "far"
 # Both passes use the complete union, so cross-pass coplanar seams disappear.
 Surface.draw(canvas,layout,architecture_pieces(layout,outdoor,actual_portals),palette)

static func draw_wall(canvas,layout,side:String,foreground:bool,height_override:float=-1.0) -> void:
 var tint:=Color("697b7c")
 Surface.draw(canvas,layout,_wall_pieces(layout,side,foreground,height_override,[]),{"top":tint.lightened(.16),"west":tint.darkened(.28),"south":tint.darkened(.18),"edge":tint.darkened(.38)})

static func draw_back(canvas,layout,outdoor:bool=false) -> void:
 var size:Vector2=layout.world_size()
 var spec:Dictionary=layout.space_spec() if layout.has_method("space_spec") else {}
 var floor_points:Array=[]
 var outline:Array=spec.get("floor_polygon_m",[[0,0],[size.x,0],[size.x,size.y],[0,size.y]])
 for p in outline:floor_points.append(layout.project(Vector2(float(p[0]),float(p[1]))))
 Geometry.draw_floor(canvas,layout,Color("697c7b") if outdoor else Color("56636b"))
 Geometry.draw_floor_lines(canvas,layout,1.0,Color(.75,.78,.72,.13))
 if not outdoor:
  draw_architecture(canvas,layout,false)
 else:
  canvas.draw_polyline(PackedVector2Array(floor_points+[floor_points[0]]),Color("93a09b"),3)
  draw_urban_back(canvas,layout)

static func draw_front(canvas,layout) -> void:
 draw_architecture(canvas,layout,true)

static func draw_urban_back(canvas,layout) -> void:
 # Existing street boundary facades, no roof, extra doors, shops or rooms.
 # Same collision boundary and exact portal openings as the outdoor layout.
 draw_architecture(canvas,layout,false,true)

static func draw_urban_front(canvas,layout) -> void:
 # Camera-facing road edges remain open air; low kerbs describe the ground
 # extent without enclosing the road inside a four-wall indoor box.
 draw_architecture(canvas,layout,true,true)
