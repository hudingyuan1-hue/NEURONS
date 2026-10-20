extends RefCounted
## Stable visual IDs. No observations, identity guesses, clocks or receipts.
static var _data:Dictionary={}
static var _textures:Dictionary={}
static func data() -> Dictionary:
 if _data.is_empty() and FileAccess.file_exists("res://data/narrative_visuals.json"):
  _data=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative_visuals.json"))
 return _data
static func texture(id:String) -> Texture2D:
 if _textures.has(id):return _textures[id]
 var all:Dictionary=data()
 if all.get("regions",{}).has(id):
  var spec:Dictionary=all.regions[id];var source:Texture2D=texture(str(spec.texture))
  if source==null:return null
  var rect:Array=spec.normalized_rect;var size:Vector2=source.get_size()
  var atlas:=AtlasTexture.new();atlas.atlas=source
  atlas.region=Rect2(Vector2(float(rect[0]),float(rect[1]))*size,Vector2(float(rect[2]),float(rect[3]))*size)
  _textures[id]=atlas;return atlas
 var spec:Dictionary=all.get("textures",{}).get(id,{})
 if spec.is_empty():return null
 var path:String=str(spec.texture)
 if not ResourceLoader.exists(path):return null
 var source:Texture2D=load(path)
 _textures[id]=source;return source
static func card(id:String) -> Texture2D:
 return texture(str(data().get("card_bindings",{}).get(id,"")))
static func portrait(observation:Dictionary) -> Texture2D:
 var all:Dictionary=data()
 var explicit:String=str(observation.get("identity_id",""))
 var identity:String=explicit if not explicit.is_empty() else str(all.get("observation_actor_aliases",{}).get(str(observation.get("id","")),""))
 if identity.is_empty():return null
 var spec:Dictionary=all.get("portraits",{}).get(identity,{})
 if spec.is_empty():return null
 var key:String="portrait:"+identity
 if _textures.has(key):return _textures[key]
 var path:String=str(spec.texture)
 if not ResourceLoader.exists(path):return null
 var result:Texture2D=load(path)
 if spec.has("normalized_rect"):
  var raw:Array=spec.normalized_rect;var size:Vector2=result.get_size()
  var cropped:=AtlasTexture.new();cropped.atlas=result
  cropped.region=Rect2(Vector2(float(raw[0]),float(raw[1]))*size,Vector2(float(raw[2]),float(raw[3]))*size)
  result=cropped
 _textures[key]=result;return result
static func paint(canvas:CanvasItem,source:Texture2D,rect:Rect2,cover:bool=true,tint:Color=Color.WHITE) -> void:
 if source==null:return
 var size:Vector2=source.get_size()
 if size.x<=0 or size.y<=0:return
 var factor:float=maxf(rect.size.x/size.x,rect.size.y/size.y) if cover else minf(rect.size.x/size.x,rect.size.y/size.y)
 if cover:
  var region:=Rect2((size-rect.size/factor)*.5,rect.size/factor)
  canvas.draw_texture_rect_region(source,rect,region,tint)
 else:
  var drawn:=Rect2(rect.position+(rect.size-size*factor)*.5,size*factor)
  canvas.draw_texture_rect(source,drawn,false,tint)
