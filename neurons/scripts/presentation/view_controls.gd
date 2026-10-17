extends RefCounted
## Camera and optional 2D focus simulation. No gameplay state or world clocks.
var app
var dragging:bool=false
var manual_view:bool=false
var miniature:bool=false
var focus:ColorRect
var material:ShaderMaterial

func _init(owner) -> void:
 app=owner
 var layer:=CanvasLayer.new();layer.layer=20
 app.world_viewport.add_child(layer)
 focus=ColorRect.new();focus.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(focus)
 material=ShaderMaterial.new()
 var shader:=Shader.new()
 shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float focus_y = 0.5;
uniform float blur_pixels = 1.4;
void fragment() {
 vec2 uv = SCREEN_UV;
 float weight = smoothstep(0.20, 0.49, abs(uv.y - focus_y));
 vec2 d = SCREEN_PIXEL_SIZE * blur_pixels * weight;
 vec4 sharp = texture(scene_tex, uv);
 vec3 soft = sharp.rgb * 0.28;
 soft += texture(scene_tex, uv + vec2(d.x,0.0)).rgb * 0.12;
 soft += texture(scene_tex, uv - vec2(d.x,0.0)).rgb * 0.12;
 soft += texture(scene_tex, uv + vec2(0.0,d.y)).rgb * 0.12;
 soft += texture(scene_tex, uv - vec2(0.0,d.y)).rgb * 0.12;
 soft += texture(scene_tex, uv + d).rgb * 0.06;
 soft += texture(scene_tex, uv - d).rgb * 0.06;
 soft += texture(scene_tex, uv + vec2(d.x,-d.y)).rgb * 0.06;
 soft += texture(scene_tex, uv + vec2(-d.x,d.y)).rgb * 0.06;
 COLOR = vec4(mix(sharp.rgb, soft, weight), sharp.a);
}"""
 material.shader=shader;focus.material=material;focus.hide()

func reset() -> void:
 dragging=false;manual_view=false

func bounds() -> Rect2:
 var size:Vector2=app.layout.world_size()
 var result:=Rect2(app.layout.project(Vector2.ZERO),Vector2.ZERO)
 for p in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:result=result.expand(app.layout.project(p))
 # Include wall tops and near furniture. Limits are presentation bounds only.
 result.position-=Vector2(60,210 if int(app.layout.geometry_version)>=2 else 95)
 result.size+=Vector2(120,285 if int(app.layout.geometry_version)>=2 else 140)
 return result

func clamp_camera() -> void:
 var rect:Rect2=bounds()
 var half:Vector2=Vector2(app.world_viewport.size)/app.camera.zoom*0.5
 var low:Vector2=rect.position+half;var high:Vector2=rect.end-half
 for axis in range(2):
  app.camera.position[axis]=clampf(app.camera.position[axis],low[axis],high[axis]) if low[axis]<=high[axis] else rect.get_center()[axis]
 app.camera.force_update_scroll()

func handle(event:InputEvent) -> bool:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE:
  dragging=event.pressed and not app.world_paused() and Rect2(0,145,1280,440).has_point(event.position)
  if dragging:manual_view=true
  return true
 if event is InputEventMouseMotion and dragging:
  if app.world_paused() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):dragging=false;return true
  app.camera.position-=event.relative*Vector2(app.world_viewport.size)/Vector2(1280,720)/app.camera.zoom
  clamp_camera();return true
 return false

func tick() -> void:
 if dragging and (app.world_paused() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or not app.get_window().has_focus()):dragging=false
 focus.size=Vector2(app.world_viewport.size)
 focus.visible=miniature and not app.reduced_effects and app.opening_ui==null and app.tutorial_ui==null
 if not focus.visible:return
 var pixel:Vector2=app.world_viewport.get_canvas_transform()*app.layout.project(app.hero_pos)
 # Keep the whole actor/contact band sharp, not just the feet.
 material.set_shader_parameter("focus_y",clampf((pixel.y-55.0)/float(app.world_viewport.size.y),0.25,0.75))
 material.set_shader_parameter("blur_pixels",1.1+float(app.zoom_index)*0.35)
