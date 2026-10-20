extends RefCounted
## Painted furniture layers at existing metric draw slots. Application state
## still owns actions, drawer progress, contacts and receipts; no gameplay writes.
static var force_preview:bool=false
static var _data:Dictionary={}
static var _textures:Dictionary={}
const HEIGHT:float=78.0

static func document() -> Dictionary:
 if _data.is_empty():
  var value=JSON.parse_string(FileAccess.get_file_as_string("res://data/production_props.json"))
  if value is Dictionary:_data=value
 return _data

static func enabled() -> bool:return force_preview or bool(document().get("enabled",false))

static func available(layout,item:Dictionary) -> bool:
 if not enabled():return false
 var config=layout.get("config")
 if not config is Dictionary or not config.has("door") or not config.has("window"):return false
 var slot:Dictionary=document().get("slots",{}).get("bedroom:"+str(item.get("id","")),{})
 return not slot.is_empty() and bool(slot.get("runtime_binding_prepared",true))

static func _sprite(id:String) -> Dictionary:return document().get("sprites",{}).get(id,{})

static func _texture(id:String) -> Texture2D:
 if _textures.has(id):return _textures[id]
 var sprite:Dictionary=_sprite(id)
 if sprite.is_empty():return null
 var result:Texture2D=load(str(sprite.texture))
 if result!=null:_textures[id]=result
 return result

static func _v(value) -> Vector2:return value if value is Vector2 else Vector2(float(value[0]),float(value[1]))
static func _point(layout,p:Vector2,h:float) -> Vector2:return layout.project(p)-Vector2(0,h)
static func _ring(rect:Rect2) -> Array:return [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]

static func _polygon(canvas:Node2D,id:String,destination:PackedVector2Array,source:Array,alpha:float=1) -> void:
 var texture:Texture2D=_texture(id)
 if texture==null:return
 var uv:=PackedVector2Array();var size:Vector2=texture.get_size()
 for p in source:uv.append(_v(p)/size)
 canvas.draw_polygon(destination,PackedColorArray([Color(1,1,1,alpha)]),uv,texture)

static func _source_transform(layout,rect:Rect2,height:float,points:Array) -> Transform2D:
 var a:Vector2=_v(points[0]);var b:Vector2=_v(points[1]);var c:Vector2=_v(points[2])
 var from:=Transform2D(b-a,c-a,a)
 var target:Vector2=_point(layout,rect.position,height)
 var to:=Transform2D(_point(layout,rect.position+Vector2(rect.size.x,0),height)-target,_point(layout,rect.position+Vector2(0,rect.size.y),height)-target,target)
 return to*from.affine_inverse()

static func _whole_transform(canvas:Node2D,id:String,transform:Transform2D,alpha:float=1) -> void:
 var image:Texture2D=_texture(id)
 if image==null:return
 var size:Vector2=image.get_size();var source:Array=[Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]
 var points:=PackedVector2Array()
 for p:Vector2 in source:points.append(transform*p)
 _polygon(canvas,id,points,source,alpha)

static func _plane(canvas:Node2D,layout,id:String,rect:Rect2,height:float,alpha:float=1) -> void:
 var calibration:Dictionary=_sprite(id).calibration
 _whole_transform(canvas,id,_source_transform(layout,rect,height,calibration.source_plane_px),alpha)

static func _prism(canvas:Node2D,layout,id:String,rect:Rect2,height:float,bottom:float=0,alpha:float=1) -> void:
 var calibration:Dictionary=_sprite(id).calibration
 var p:Array=_ring(rect);var top:=PackedVector2Array();var base:=PackedVector2Array()
 for point:Vector2 in p:top.append(_point(layout,point,bottom+height));base.append(_point(layout,point,bottom))
 # Reproject each real face, so a painted tall cupboard cannot silently shrink
 # its depth or change the shared camera. Texture pixels retain their brushwork.
 _polygon(canvas,id,PackedVector2Array([top[0],top[3],base[3],base[0]]),calibration.source_west_px,alpha)
 _polygon(canvas,id,PackedVector2Array([top[3],top[2],base[2],base[3]]),calibration.source_south_px,alpha)
 _polygon(canvas,id,top,calibration.source_top_px,alpha)

static func _height_transform(layout,item:Dictionary,id:String) -> Transform2D:
 var calibration:Dictionary=_sprite(id).calibration
 var anchor:Vector2=_v(calibration.ground_anchor_px)
 var height:float=float(item.get("height",float(item.get("height_m",.6))*HEIGHT))
 var scale:float=height/maxf(1,anchor.y-float(calibration.top_y_px))
 return Transform2D(Vector2(scale,0),Vector2(0,scale),layout.project((item.rect as Rect2).get_center())-anchor*scale)

static func _desk(canvas:Node2D,layout,item:Dictionary,alpha:float) -> void:
 var rect:Rect2=item.rect;var height:float=float(item.height);var calibration:Dictionary=_sprite("desk").calibration
 var image:Texture2D=_texture("desk")
 # Four independently placed painted legs meet the actual floor. Their height
 # does not inherit the image generator's sometimes exaggerated table legs.
 for part:Dictionary in calibration.leg_parts:
  var fraction:Vector2=_v(part.world_fraction);var foot:Vector2=layout.project(rect.position+rect.size*fraction)
  var raw:Array=part.source_rect_px;var source:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
  var width:float=3.6
  canvas.draw_texture_rect_region(image,Rect2(foot-Vector2(width*.5,height),Vector2(width,height)),source,Color(1,1,1,alpha))
 var transform:Transform2D=_source_transform(layout,rect,height,calibration.source_plane_px)
 var destination:=PackedVector2Array()
 for p in calibration.tabletop_polygon_px:destination.append(transform*_v(p))
 _polygon(canvas,"desk",destination,calibration.tabletop_polygon_px,alpha)

static func _drawer_front(canvas:Node2D,layout,rect:Rect2,bottom:float,top:float,alpha:float) -> void:
 var a:Vector2=rect.position+Vector2(0,rect.size.y);var b:Vector2=rect.end
 var target:=PackedVector2Array([_point(layout,a,top),_point(layout,b,top),_point(layout,b,bottom),_point(layout,a,bottom)])
 _polygon(canvas,"bedside_drawer",target,_sprite("bedside_drawer").calibration.source_south_px,alpha)

static func _bedside(canvas:Node2D,layout,item:Dictionary,open:float,alpha:float) -> void:
 var rect:Rect2=item.rect;var height:float=float(item.height)
 _prism(canvas,layout,"bedside",rect,height,0,alpha)
 var gap:float=height*.035;var level:float=(height-gap*4)/3
 for index in range(3):
  if index==1 and open>.001:continue
  var bottom:float=gap+(level+gap)*index
  _drawer_front(canvas,layout,rect,bottom,bottom+level,alpha)
 if open>.001:
  var moving:=Rect2(rect.position+Vector2(.025,.28*clampf(open,0,1)),rect.size-Vector2(.05,.015))
  _prism(canvas,layout,"bedside_drawer",moving,level,gap+(level+gap),alpha)

static func handle(layout,item:Dictionary,open:float=0) -> Vector2:
 var rect:Rect2=item.rect;var height:float=float(item.height)
 return _point(layout,Vector2(rect.get_center().x,rect.end.y+.28*clampf(open,0,1)),height*.5)

static func _fan(canvas:Node2D,layout,item:Dictionary,time:float,alpha:float) -> void:
 var transform:Transform2D=_height_transform(layout,item,"fan")
 var calibration:Dictionary=_sprite("fan").calibration;var rotor:Dictionary=_sprite("fan_rotor").calibration
 var center:Vector2=transform*_v(calibration.rotor_center_px)
 var scale:float=transform.x.length()*float(calibration.rotor_diameter_source_px)/float(rotor.diameter_px)
 var angle:float=time*5
 var basis_x:=Vector2.from_angle(angle)*scale;var basis_y:=Vector2.from_angle(angle+PI*.5)*scale
 var pivot:Vector2=_v(rotor.pivot_px)
 var rotating:=Transform2D(basis_x,basis_y,center-basis_x*pivot.x-basis_y*pivot.y)
 _whole_transform(canvas,"fan_rotor",rotating,alpha)
 # Wires and the hub sit over the rotating blades, with genuinely clear gaps.
 _whole_transform(canvas,"fan",transform,alpha)

static func draw(canvas:Node2D,layout,item:Dictionary,state:Dictionary={},alpha:float=1) -> bool:
 if not available(layout,item):return false
 var id:String=str(item.id);var rect:Rect2=item.rect;var height:float=float(item.get("height",float(item.get("height_m",.6))*HEIGHT))
 match id:
  "bed":
   _plane(canvas,layout,id,rect,height,alpha)
   var blanket:=Rect2(rect.position+rect.size*Vector2(.33,0),rect.size*Vector2(.67,1))
   var up:float=height+.035*HEIGHT
   if bool(state.get("bedding_lifted",false)):
    blanket=Rect2(blanket.position+Vector2(.15,.06),blanket.size*Vector2(.75,.84));up+=.1*HEIGHT
   _plane(canvas,layout,"bed_blanket",blanket,up,alpha)
  "bedside":_bedside(canvas,layout,item,float(state.get("open",0)),alpha)
  "desk":_desk(canvas,layout,item,alpha)
  "books","wardrobe":_prism(canvas,layout,id,rect,height,0,alpha)
  "chair","rack":_whole_transform(canvas,id,_height_transform(layout,item,id),alpha)
  "fan":_fan(canvas,layout,item,float(state.get("world_visual_time",0)),alpha)
  _:return false
 return true
