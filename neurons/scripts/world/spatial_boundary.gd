extends RefCounted
## Continuous non-rectangular wall strips, in the same metre-space as movement.
const Geometry=preload("res://scripts/world/spatial_geometry.gd")
const CAMERA:=Vector2(-6,56)
static var _cache:Dictionary={}

static func _offset(ring:PackedVector2Array,thickness:float) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for i in range(ring.size()):
  var a:Vector2=(ring[i]-ring[(i-1+ring.size())%ring.size()]).normalized()
  var b:Vector2=(ring[(i+1)%ring.size()]-ring[i]).normalized()
  var na:=Vector2(a.y,-a.x);var nb:=Vector2(b.y,-b.x)
  var v:Vector2=(na+nb)/maxf(.2,1.0+na.dot(nb))*thickness
  if v.length()>thickness*3:v=v.normalized()*thickness*3
  result.append(ring[i]+v)
 return result

static func _face(points:Array,edges:Array,normal:Vector2,group:String,top:bool=false) -> Dictionary:
 return {"points":points,"edges":edges,"normal":normal,"side":"top" if top else "west" if absf(normal.x)>absf(normal.y) else "south","group":group}

static func _v(p:Vector2,h:float) -> Vector3:return Vector3(p.x,h,p.y)

static func _cut_intervals(ring:PackedVector2Array,actual_portals:Array) -> Array:
 var lengths:Array[float]=[0.0]
 for i in range(ring.size()):lengths.append(lengths[-1]+ring[i].distance_to(ring[(i+1)%ring.size()]))
 var total:float=lengths[-1];var result:Array=[]
 for portal:Dictionary in actual_portals:
  if not portal.has("at"):continue
  var p:Vector2=portal.get("wall_point",portal.at);var distance:float=INF;var center:float=0
  for i in range(ring.size()):
   var close:Vector2=Geometry2D.get_closest_point_to_segment(p,ring[i],ring[(i+1)%ring.size()])
   if close.distance_to(p)<distance:distance=close.distance_to(p);center=lengths[i]+close.distance_to(ring[i])
  var width:float=float(portal.get("width_m",1.0))
  for shift in [-total,0.0,total]:
   result.append({"a":center-width*.5+shift,"b":center+width*.5+shift,"height":float(portal.get("height_m",2.2)),"sill":float(portal.get("sill_m",-1))})
 return result

static func _windows(spec:Dictionary,size:Vector2) -> Array:
 var result:Array=[]
 for f:Dictionary in spec.get("furniture",[])+spec.get("decor",[]):
  if str(f.get("kind",""))!="window" or not f.has("wall_mount") or not f.get("render",true):continue
  var raw:Array=f.get("rect_m",[])
  if raw.size()!=4:continue
  var r:=Rect2(raw[0],raw[1],raw[2],raw[3]);var side:String=str(f.wall_mount)
  var at:Vector2=r.get_center();var width:float=r.size.x if side in ["north","south"] else r.size.y
  if side in ["north","south"]:at.y=0 if side=="north" else size.y
  else:at.x=0 if side=="west" else size.x
  var shown:Dictionary=preload("res://scripts/world/spatial_presentation.gd").window_display(side,width,float(f.get("sill_height_m",f.get("height_m",1.1))),float(f.get("opening_height_m",.6)))
  result.append({"at":at,"width_m":width,"sill_m":shown.sill_height_m,"height_m":float(shown.sill_height_m)+float(shown.opening_height_m)})
 return result

static func _strip(ia:Vector2,ib:Vector2,oa:Vector2,ob:Vector2,bottom:float,height:float,normal:Vector2,group:String,reveals:Array) -> Array:
 if height-bottom<=.00001:return []
 var result:Array=[]
 result.append(_face([_v(ia,height),_v(ib,height),_v(ob,height),_v(oa,height)],[[_v(ia,height),_v(ib,height)],[_v(oa,height),_v(ob,height)]],Vector2.ZERO,group,true))
 var near:bool=normal.dot(CAMERA)>0;var visible:Vector2=normal if near else -normal
 var va:Vector2=oa if near else ia;var vb:Vector2=ob if near else ib
 result.append(_face([_v(va,bottom),_v(vb,bottom),_v(vb,height),_v(va,height)],[[_v(va,height),_v(vb,height)],[_v(va,bottom),_v(vb,bottom)]],visible,group))
 for pair:Array in reveals:
  var p:Vector2=pair[0];var q:Vector2=pair[1]
  result.append(_face([_v(p,bottom),_v(q,bottom),_v(q,height),_v(p,height)],[[_v(p,bottom),_v(p,height)],[_v(q,bottom),_v(q,height)]],(ib-ia).normalized(),group))
 return result

static func pieces(layout,outdoor:bool,actual_portals:Array) -> Array:
 var spec:Dictionary=layout.space_spec();var size:Vector2=layout.world_size()
 var wall:Dictionary=spec.get("wall",{})
 var thickness:float=float(spec.get("wall_thickness_m",wall.get("thickness_m",.15)))
 var full_height:float=float(spec.get("wall_height_m",wall.get("height_m",2.55)))
 var apertures:Array=actual_portals.duplicate(true)
 if outdoor:
  # Open streets continue beneath the sky; doorway metadata is a passage
  # width/actor threshold, not permission to add an enclosing lintel.
  for aperture:Dictionary in apertures:aperture.height_m=1000.0
 apertures.append_array(_windows(spec,size))
 var cache_key:int=hash(spec.get("floor_polygon_m",[]))^hash(spec.get("floor_holes_m",[]))^hash(apertures)^hash([size,thickness,full_height,outdoor,spec.get("boundary_facades",[]),spec.get("hole_wall_height_m",.22)])
 if _cache.has(cache_key):return _cache[cache_key]
 var rings:Array=[Geometry.floor_polygon(spec,size)];rings.append_array(Geometry.floor_holes(spec,size))
 var all_faces:Array=[]
 for ri in range(rings.size()):
  var ring:PackedVector2Array=rings[ri];var strip_width:float=thickness
  if ri>0:
   # A guard lip follows a thin inner arc. A full outer-wall offset would
   # fold back across short radial ends and create self-intersecting caps.
   for edge in range(ring.size()):strip_width=minf(strip_width,ring[edge].distance_to(ring[(edge+1)%ring.size()])*.2)
  var outer:PackedVector2Array=_offset(ring,strip_width)
  var cuts:Array=_cut_intervals(ring,apertures) if ri==0 else []
  var s:float=0.0
  for i in range(ring.size()):
   var p:Vector2=ring[i];var q:Vector2=ring[(i+1)%ring.size()];var op:Vector2=outer[i];var oq:Vector2=outer[(i+1)%ring.size()]
   var d:Vector2=q-p;var length:float=d.length()
   if length<.0001:continue
   var normal:=Vector2(d.y,-d.x).normalized();var near:bool=normal.dot(CAMERA)>.001
   var group:String="near" if near else "far"
   var height:float=minf(full_height,.85) if near else full_height
   if ri>0:height=float(spec.get("hole_wall_height_m",.22))
   elif outdoor:
    height=.14
    for facade:Dictionary in spec.get("boundary_facades",[]):
     if int(facade.get("edge_index",-1))==i:height=float(facade.get("height_m",3.0));break
   var limits:Array[float]=[0.0,1.0]
   for cut:Dictionary in cuts:
    for x:float in [float(cut.a)-s,float(cut.b)-s]:
     if x>.00001 and x<length-.00001:limits.append(x/length)
   limits.sort()
   for j in range(limits.size()-1):
    var a:float=limits[j];var b:float=limits[j+1];var middle:float=s+(a+b)*.5*length
    var bottom:float=0.0;var sill:float=-1.0
    for cut:Dictionary in cuts:
     if middle>float(cut.a) and middle<float(cut.b):
      bottom=maxf(bottom,float(cut.height))
      if float(cut.sill)>=0:sill=float(cut.sill)
    var ia:Vector2=p.lerp(q,a);var ib:Vector2=p.lerp(q,b);var oa:Vector2=op.lerp(oq,a);var ob:Vector2=op.lerp(oq,b)
    var reveals:Array=[]
    if a>.00001:reveals.append([ia,oa])
    if b<.99999:reveals.append([ib,ob])
    all_faces.append_array(_strip(ia,ib,oa,ob,bottom,height,normal,group,reveals))
    if sill>=0:all_faces.append_array(_strip(ia,ib,oa,ob,0,minf(sill,height),normal,group,reveals))
   s+=length
 var result:Array=[{"custom_faces":all_faces,"group":"contour","height_m":full_height}]
 if _cache.size()>96:_cache.clear()
 _cache[cache_key]=result
 return result
