extends RefCounted
## Painterly production materials on the EXISTING 2D metric faces.
## Only presentation pixels/UVs are changed. No imported room silhouette,
## physics mesh, portal, navigation, actor or action state is introduced.
static var force_preview:bool=false
static var _document:Dictionary={}
static var _textures:Dictionary={}
static var _layout_specs:Dictionary={}

static func document() -> Dictionary:
 if _document.is_empty():
  var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/production_materials.json"))
  if parsed is Dictionary:_document=parsed
 return _document

static func enabled() -> bool:
 return force_preview or bool(document().get("enabled",false))

static func texture(id:String) -> Texture2D:
 if _textures.has(id):return _textures[id]
 var entry:Dictionary=document().get("materials",{}).get(id,{})
 if entry.is_empty():return null
 var loaded:Texture2D=load(str(entry.texture))
 if loaded!=null:_textures[id]=loaded
 return loaded

static func _spec(layout) -> Dictionary:
 var key:int=layout.get_instance_id()
 if _layout_specs.has(key) and _layout_specs[key].ref.get_ref()==layout:return _layout_specs[key].spec
 var source:Dictionary={}
 if layout.has_method("space_spec"):source=layout.space_spec()
 else:
  var config=layout.get("config")
  if config is Dictionary:source=config
 var result:Dictionary={}
 for field:String in ["floor_polygon_m","boundary_style","environment","room_id","door","window"]:
  if source.has(field):result[field]=source[field]
 if _layout_specs.size()>256:_layout_specs.clear()
 _layout_specs[key]={"ref":weakref(layout),"spec":result}
 return result

static func context(layout) -> String:
 var spec:Dictionary=_spec(layout)
 var boundary:String=str(spec.get("boundary_style",""))
 if boundary in ["white_matter","deep_fold"]:return "white_matter" if boundary=="white_matter" else "deep_neural"
 if boundary=="cortex_fold":return "cortex"
 if str(spec.get("environment",""))=="open_air_urban" or boundary in ["open_street","street"]:return "street"
 if spec.has("door") and spec.has("window"):return "bedroom"
 if str(spec.get("room_id",""))=="hidden_street":return "street"
 return "institution"

static func floor_id(layout) -> String:
 var kind:String=context(layout)
 if kind=="bedroom":return "aged_floorboards"
 if kind=="cortex":return "cortical_fibers"
 if kind in ["white_matter","deep_neural"]:return "white_matter"
 if kind=="street":
  var spec:Dictionary=_spec(layout)
  return "asphalt" if str(spec.get("room_id",layout.get("room_id"))).contains("narrow") else "street_stone"
 return "institution_tile"

static func wall_id(layout) -> String:
 var kind:String=context(layout)
 if kind=="cortex":return "cortical_fibers"
 if kind in ["white_matter","deep_neural"]:return "white_matter"
 return "worn_plaster"

static func _span(id:String) -> float:
 return maxf(.1,float(document().get("materials",{}).get(id,{}).get("world_span_m",2.0)))

static func draw_polygon(canvas:Node2D,points:PackedVector2Array,coordinates:PackedVector2Array,id:String,tone:Color=Color.WHITE,shade:float=1.0) -> bool:
 if not enabled() or points.size()<3 or points.size()!=coordinates.size():return false
 var image:Texture2D=texture(id)
 if image==null:return false
 var uvs:=PackedVector2Array()
 for point:Vector2 in coordinates:uvs.append(point/_span(id))
 # Individual atlas crops prevent neighbour-cell bleed when UVs repeat.
 # Mirroring gives matching edge values without stretching a room-sized image.
 canvas.texture_repeat=CanvasItem.TEXTURE_REPEAT_MIRROR
 var mean:float=maxf(.15,(tone.r+tone.g+tone.b)/3.0)
 var tint:Color=Color(lerpf(1,tone.r/mean,.35)*shade,lerpf(1,tone.g/mean,.35)*shade,lerpf(1,tone.b/mean,.35)*shade,tone.a)
 if tone.a>.99:
  # Calm grouped paint remains dominant. Texture is selective surface detail,
  # not a high-contrast wallpaper repeated over every architectural plane.
  canvas.draw_colored_polygon(points,Color(tone.r*shade,tone.g*shade,tone.b*shade,1))
  tint.a=.48 if id in ["worn_plaster","sage_paint","ivory_fabric","concrete"] else .32 if id in ["cortical_fibers","white_matter"] else .68
 canvas.draw_polygon(points,PackedColorArray([tint]),uvs,image)
 return true

static func floor(canvas:Node2D,layout,ring:PackedVector2Array,tone:Color) -> bool:
 var points:=PackedVector2Array()
 for point:Vector2 in ring:points.append(layout.project(point))
 return draw_polygon(canvas,points,ring,floor_id(layout),tone,.93 if context(layout)=="deep_neural" else 1.0)

static func _wall_u(layout,p:Vector3) -> float:
 var spec:Dictionary=_spec(layout);var size:Vector2=layout.world_size()
 var raw=spec.get("floor_polygon_m",[[0,0],[size.x,0],[size.x,size.y],[0,size.y]])
 var nearest:float=INF;var value:float=0;var distance:float=0
 var point:=Vector2(p.x,p.z)
 for index in range(raw.size()):
  var a:Vector2=raw[index] if raw[index] is Vector2 else Vector2(float(raw[index][0]),float(raw[index][1]))
  var next=raw[(index+1)%raw.size()]
  var b:Vector2=next if next is Vector2 else Vector2(float(next[0]),float(next[1]))
  var close:Vector2=Geometry2D.get_closest_point_to_segment(point,a,b)
  if close.distance_squared_to(point)<nearest:
   nearest=close.distance_squared_to(point);value=distance+a.distance_to(close)
  distance+=a.distance_to(b)
 return value

static func _height_clip(points:Array,height:float,above:bool) -> Array:
 var result:Array=[]
 if points.is_empty():return result
 var previous:Vector3=points[-1];var previous_in:bool=previous.y>=height if above else previous.y<=height
 for point:Vector3 in points:
  var inside:bool=point.y>=height if above else point.y<=height
  if inside!=previous_in:
   var t:float=(height-previous.y)/(point.y-previous.y)
   result.append(previous.lerp(point,t))
  if inside:result.append(point)
  previous=point;previous_in=inside
 return result

static func _wall_patch(canvas:Node2D,layout,face:Dictionary,points:Array,id:String,tone:Color,height_pixels:float) -> void:
 if points.size()<3:return
 var projected:=PackedVector2Array();var uvs:=PackedVector2Array()
 var top:bool=str(face.side)=="top"
 var organic:bool=context(layout) in ["cortex","white_matter","deep_neural"]
 var shade:float=1.04 if top else .85 if str(face.side)=="west" else .95
 if organic:shade=1.0 if top else .8 if str(face.side)=="west" else .89
 for p:Vector3 in points:
  projected.append(layout.project(Vector2(p.x,p.z))-Vector2(0,p.y*height_pixels))
  # A continuous arc-length coordinate follows arbitrary/mitered outer walls.
  # Top faces share floor coordinates, so gaps cannot be painted over.
  uvs.append(Vector2(p.x,p.z) if top else Vector2(_wall_u(layout,p),-p.y))
 draw_polygon(canvas,projected,uvs,id,tone,shade)

static func architecture_face(canvas:Node2D,layout,face:Dictionary,tone:Color,height_pixels:float=78.0) -> bool:
 if not enabled():return false
 var id:String=wall_id(layout)
 if context(layout)=="institution" and str(face.side)!="top":
  # Continuous painted dado, clipped from each real face; no extra solids.
  _wall_patch(canvas,layout,face,_height_clip(face.points,1.08,false),"sage_paint",tone,height_pixels)
  _wall_patch(canvas,layout,face,_height_clip(face.points,1.08,true),id,tone,height_pixels)
 else:_wall_patch(canvas,layout,face,face.points,id,tone,height_pixels)
 return true

static func prop_id(kind:String,name:String="") -> String:
 if kind in ["bed","exam_bed","curtain","rug","sofa","bag"]:return "ivory_fabric"
 if kind in ["plant","tree","growth"]:return "bark"
 if kind in ["window","mirror","screen"]:return "smoky_glass"
 if kind in ["box","case"]:return "aged_paper"
 if kind in ["core","node","organic","model"]:return "cortical_fibers"
 if kind in ["railing","pipe","fan","sink","toilet","cart","cleaner_cart","machine","locker","gate","clamp","lamp","wall_lamp","terminal","console"]:return "painted_metal"
 if name.contains("石") or kind in ["facade","statue","fountain","rubble","debris","pit","drain"]:return "concrete"
 return "furniture_wood"

static func prop_face(canvas:Node2D,layout,ring:PackedVector2Array,height:float,tone:Color,id:String="furniture_wood",bottom:float=0.0) -> void:
 var top:=PackedVector2Array()
 for point:Vector2 in ring:top.append(layout.project(point)-Vector2(0,height))
 for index in range(ring.size()):
  var a:Vector2=ring[index];var b:Vector2=ring[(index+1)%ring.size()];var d:Vector2=b-a
  if Vector2(d.y,-d.x).dot(Vector2(-6,56))<=0:continue
  var points:=PackedVector2Array([layout.project(a)-Vector2(0,bottom),layout.project(b)-Vector2(0,bottom),layout.project(b)-Vector2(0,height),layout.project(a)-Vector2(0,height)])
  var coords:=PackedVector2Array([Vector2(a.x+a.y,-bottom/78.0),Vector2(b.x+b.y,-bottom/78.0),Vector2(b.x+b.y,-height/78.0),Vector2(a.x+a.y,-height/78.0)])
  if not draw_polygon(canvas,points,coords,id,tone,.82):canvas.draw_colored_polygon(points,tone.darkened(.2))
 if not draw_polygon(canvas,top,ring,id,tone):canvas.draw_colored_polygon(top,tone)
 if top.size()>1:top.append(top[0]);canvas.draw_polyline(top,Color(.19,.18,.2,tone.a*.5),.65,true)
