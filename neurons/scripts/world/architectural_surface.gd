extends RefCounted
## Display-only union of axis-aligned architectural solids. Metres remain the
## input contract; no navigation, collision, portal or rule data is changed.
## Always pass the complete building pieces. Optional groups split drawing
## around actors without exposing internal faces or seams between those groups.
const HEIGHT_PIXELS:float=78.0
const SNAP:float=0.00001
const CACHE_LIMIT:int=96
const Materials=preload("res://scripts/world/spatial_materials.gd")
static var _cache:Dictionary={}

static func _snap(value:float) -> float:
 return snappedf(value,SNAP)

static func _normalise(pieces:Array) -> Array:
 var result:Array=[]
 for piece:Dictionary in pieces:
  if piece.has("custom_faces"):continue
  var rect:Rect2=piece.rect
  var bottom:float=float(piece.get("bottom_m",0.0))
  var height:float=float(piece.get("height_m",0.0))
  if rect.size.x<=0 or rect.size.y<=0 or height<=0:continue
  var bounds:Array=[_snap(rect.position.x),_snap(rect.end.x),_snap(bottom),_snap(bottom+height),_snap(rect.position.y),_snap(rect.end.y)]
  if bounds[1]<=bounds[0] or bounds[3]<=bounds[2] or bounds[5]<=bounds[4]:continue
  result.append({"bounds":bounds,"group":str(piece.get("group","all"))})
 return result

static func _geometry(pieces:Array) -> Dictionary:
 var solids:Array=_normalise(pieces)
 var key:String=JSON.stringify(solids)
 if _cache.has(key):return _cache[key]
 var geometry:Dictionary=_build(solids)
 if _cache.size()>=CACHE_LIMIT:_cache.erase(_cache.keys()[0])
 _cache[key]=geometry
 return geometry

## Cached read-only faces; each point is Vector3(x, height, z), in metres.
## The optional edges contain only physical boundaries of a whole coplanar
## exposed surface, never the edges of its coordinate-compression cells.
static func faces(pieces:Array) -> Array:
 var result:Array=_geometry(pieces).faces.duplicate()
 for piece:Dictionary in pieces:
  if piece.has("custom_faces"):result.append_array(piece.custom_faces)
 return result

static func _axis_values(solids:Array,start:int) -> Array:
 var found:Dictionary={}
 for solid:Dictionary in solids:
  found[solid.bounds[start]]=true;found[solid.bounds[start+1]]=true
 var result:Array=found.keys();result.sort()
 return result

static func _indices(values:Array) -> Dictionary:
 var result:Dictionary={}
 for i in range(values.size()):result[values[i]]=i
 return result

static func _add_face_cell(planes:Dictionary,side:String,index:int,value:float,u:Array,v:Array,cell:Vector2i,group:String) -> void:
 var key:String=side+":"+str(index)
 if not planes.has(key):planes[key]={"side":side,"value":value,"u":u,"v":v,"cells":{}}
 planes[key].cells[cell]=group

static func _build(solids:Array) -> Dictionary:
 if solids.is_empty():return {"faces":[]}
 var xs:Array=_axis_values(solids,0);var hs:Array=_axis_values(solids,2);var zs:Array=_axis_values(solids,4)
 var xi:Dictionary=_indices(xs);var hi:Dictionary=_indices(hs);var zi:Dictionary=_indices(zs)
 var occupied:Dictionary={}
 for solid:Dictionary in solids:
  var b:Array=solid.bounds;var group:String=solid.group
  for x in range(int(xi[b[0]]),int(xi[b[1]])):
   for h in range(int(hi[b[2]]),int(hi[b[3]])):
    for z in range(int(zi[b[4]]),int(zi[b[5]])):
     var cell:=Vector3i(x,h,z)
     # Overlap is one solid. Near ownership wins only its drawing pass.
     if not occupied.has(cell) or group=="near":occupied[cell]=group
 var planes:Dictionary={}
 for cell:Vector3i in occupied:
  var group:String=occupied[cell]
  if not occupied.has(cell+Vector3i(-1,0,0)):
   _add_face_cell(planes,"west",cell.x,float(xs[cell.x]),zs,hs,Vector2i(cell.z,cell.y),group)
  if not occupied.has(cell+Vector3i(0,0,1)):
   _add_face_cell(planes,"south",cell.z+1,float(zs[cell.z+1]),xs,hs,Vector2i(cell.x,cell.y),group)
  if not occupied.has(cell+Vector3i(0,1,0)):
   _add_face_cell(planes,"top",cell.y+1,float(hs[cell.y+1]),xs,zs,Vector2i(cell.x,cell.z),group)
 var result:Array=[];var plane_keys:Array=planes.keys();plane_keys.sort()
 for key:String in plane_keys:result.append_array(_merge_plane(planes[key]))
 return {"faces":result}

static func _point(plane:Dictionary,u:float,v:float) -> Vector3:
 match str(plane.side):
  "west":return Vector3(float(plane.value),v,u)
  "south":return Vector3(u,v,float(plane.value))
  _:return Vector3(u,float(plane.value),v)

static func _add_interval(lines:Dictionary,direction:String,line:int,a:int,b:int) -> void:
 var key:String=direction+":"+str(line)
 if not lines.has(key):lines[key]=[]
 lines[key].append(Vector2i(a,b))

static func _boundary_edges(plane:Dictionary,covered:Array) -> Array:
 var cells:Dictionary=plane.cells;var lines:Dictionary={}
 for cell:Vector2i in covered:
  if not cells.has(cell+Vector2i(0,-1)):_add_interval(lines,"u",cell.y,cell.x,cell.x+1)
  if not cells.has(cell+Vector2i(0,1)):_add_interval(lines,"u",cell.y+1,cell.x,cell.x+1)
  if not cells.has(cell+Vector2i(-1,0)):_add_interval(lines,"v",cell.x,cell.y,cell.y+1)
  if not cells.has(cell+Vector2i(1,0)):_add_interval(lines,"v",cell.x+1,cell.y,cell.y+1)
 var result:Array=[];var keys:Array=lines.keys();keys.sort()
 for key:String in keys:
  var parts:PackedStringArray=key.split(":");var horizontal:bool=parts[0]=="u";var line:int=int(parts[1])
  var intervals:Array=lines[key]
  intervals.sort_custom(func(a:Vector2i,b:Vector2i):return a.x<b.x)
  var start:int=intervals[0].x;var end:int=intervals[0].y
  for index in range(1,intervals.size()+1):
   if index<intervals.size() and intervals[index].x<=end:
    end=maxi(end,intervals[index].y);continue
   if horizontal:
    result.append([_point(plane,float(plane.u[start]),float(plane.v[line])),_point(plane,float(plane.u[end]),float(plane.v[line]))])
   else:
    result.append([_point(plane,float(plane.u[line]),float(plane.v[start])),_point(plane,float(plane.u[line]),float(plane.v[end]))])
   if index<intervals.size():start=intervals[index].x;end=intervals[index].y
 return result

static func _merge_plane(plane:Dictionary) -> Array:
 var remaining:Dictionary=plane.cells.duplicate();var result:Array=[]
 var order:Array=remaining.keys()
 order.sort_custom(func(a:Vector2i,b:Vector2i):return a.y<b.y if a.y!=b.y else a.x<b.x)
 for first:Vector2i in order:
  if not remaining.has(first):continue
  var group:String=str(remaining[first]);var width:int=1;var height:int=1
  while remaining.has(first+Vector2i(width,0)) and str(remaining[first+Vector2i(width,0)])==group:width+=1
  while true:
   var complete:bool=true
   for offset in range(width):
    var cell:Vector2i=first+Vector2i(offset,height)
    if not remaining.has(cell) or str(remaining[cell])!=group:complete=false;break
   if not complete:break
   height+=1
  var covered:Array=[]
  for y in range(height):
   for x in range(width):
    var cell:Vector2i=first+Vector2i(x,y);covered.append(cell);remaining.erase(cell)
  var u0:float=float(plane.u[first.x]);var u1:float=float(plane.u[first.x+width])
  var v0:float=float(plane.v[first.y]);var v1:float=float(plane.v[first.y+height])
  result.append({"side":str(plane.side),"group":group,"points":[_point(plane,u0,v0),_point(plane,u1,v0),_point(plane,u1,v1),_point(plane,u0,v1)],"edges":_boundary_edges(plane,covered)})
 return result

static func _pixel(layout,point:Vector3,height_pixels:float) -> Vector2:
 return layout.project(Vector2(point.x,point.z))-Vector2(0,point.y*height_pixels)

static func draw(canvas:Node2D,layout,pieces:Array,colors:Dictionary={}) -> void:
 var filter_group:String=str(colors.get("group",""))
 var height_pixels:float=float(colors.get("height_px_per_m",HEIGHT_PIXELS))
 var top:Color=colors.get("top",Color("a5b2a8"))
 var west:Color=colors.get("west",top.darkened(.23));var south:Color=colors.get("south",top.darkened(.12))
 var edge:Color=colors.get("edge",top.darkened(.23));var edge_width:float=float(colors.get("edge_width",1.1))
 var ordered:Array=[]
 for face:Dictionary in faces(pieces):
  if not filter_group.is_empty() and str(face.group)!=filter_group:continue
  var depth:float=-INF
  for point:Vector3 in face.points:depth=maxf(depth,layout.project(Vector2(point.x,point.z)).y)
  ordered.append({"face":face,"depth":depth})
 ordered.sort_custom(func(a,b):return float(a.depth)<float(b.depth) if not is_equal_approx(float(a.depth),float(b.depth)) else str(a.face.side)!="top" and str(b.face.side)=="top")
 for entry:Dictionary in ordered:
  var face:Dictionary=entry.face;var points:=PackedVector2Array()
  for point:Vector3 in face.points:points.append(_pixel(layout,point,height_pixels))
  var tone:Color=top if str(face.side)=="top" else west if str(face.side)=="west" else south
  if not Materials.architecture_face(canvas,layout,face,tone,height_pixels):canvas.draw_colored_polygon(points,tone)
  if edge_width<=0 or edge.a<=0:continue
  for line:Array in face.edges:
   canvas.draw_line(_pixel(layout,line[0],height_pixels),_pixel(layout,line[1],height_pixels),edge,edge_width,true)
