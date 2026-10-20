extends Node
## Transparent offscreen 2D rig, composited in the existing depth-sort slot.
## Never moves the hero, advances a rules clock or emits a gameplay receipt.
const Rig=preload("res://scripts/presentation/cutout_actor_2d.gd")
const State=preload("res://scripts/presentation/hero_visual_state.gd")
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
const HEIGHT:float=136.5
const RENDER_HEIGHT:float=300.0
var rig
var viewport:SubViewport
var catalog=Catalog.new()
var diagnostics:Dictionary={"travel_m":0.0,"locomotion_weight":0.0,"clamped_targets":[],"production_ready":false}
var _owner:WeakRef
var _foot:=Vector2.ZERO
var _render_scale:float=1.0
var _body_height:float=1.0
var _previous_position:=Vector2.INF
var _previous_room:String=""
var _previous_generation:int=-1
var _previous_world_time:float=0.0
var _travel:float=0.0
var _weight:float=0.0
var _sample:Dictionary={}
var _frame:Dictionary={}
var _production_ready:bool=false
var _pose_key:String=""

func setup(owner_app) -> void:
 _owner=weakref(owner_app);name="ProductionActors";process_priority=100
 rig=Rig.new();rig.name="MainCutout"
 viewport=SubViewport.new();viewport.name="CutoutCanvas";viewport.transparent_bg=true
 viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(viewport);viewport.add_child(rig)
 rig.load_config()
 _production_ready=bool(rig.rig_config.get("production_ready",false))
 for direction in range(4):_production_ready=_production_ready and rig.is_available(direction)
 diagnostics.production_ready=_production_ready
 _fit_view()

func _fit_view() -> void:
 _body_height=maxf(1,rig.body_height());_render_scale=RENDER_HEIGHT/_body_height
 # Extra horizontal space permits actual reaches without clipping the hands.
 var canvas:Vector2=rig.canvas_size()*_render_scale
 viewport.size=Vector2i(ceili(canvas.x+144),ceili(canvas.y+40))
 _foot=rig.foot_anchor()*_render_scale+Vector2(72,20)
 rig.scale=Vector2.ONE*_render_scale;rig.position=_foot
 _frame={"texture":viewport.get_texture(),"size":Vector2(viewport.size),"foot":_foot,"body_height":RENDER_HEIGHT,"ready":_production_ready}

func available() -> bool:
 return _production_ready and rig!=null and not _sample.is_empty() and rig.is_available()

func frame() -> Dictionary:
 return _frame if available() else {}

func visual_state() -> Dictionary:return _sample.duplicate(true)

func hand_pixel(name:String,hero_at:Vector2) -> Vector2:
 if not available():return Vector2.INF
 return hero_at+rig.socket_position(name)*HEIGHT/_body_height

func draw_hero(canvas:CanvasItem,at:Vector2,height:float=HEIGHT) -> bool:
 if not available():return false
 var scale_value:float=height/RENDER_HEIGHT
 canvas.draw_texture_rect(_frame.texture,Rect2(at-_foot*scale_value,Vector2(viewport.size)*scale_value),false)
 return true

func draw_resting(canvas:CanvasItem,center:Vector2,angle:float,height:float=HEIGHT) -> bool:
 if not available():return false
 var scale_value:float=height/RENDER_HEIGHT
 canvas.draw_set_transform(center,angle)
 canvas.draw_texture_rect(_frame.texture,Rect2(-(_foot-Vector2(0,RENDER_HEIGHT*.5))*scale_value,Vector2(viewport.size)*scale_value),false)
 canvas.draw_set_transform(Vector2.ZERO)
 return true

func _process(delta:float) -> void:
 var app=_owner.get_ref() if _owner!=null else null
 if app==null or not app.campaign_ready or app.layout==null:return
 update_visual(app,delta)

func update_visual(app,delta:float) -> void:
 var paused:bool=app.world_paused()
 var position:Vector2=app.hero_pos;var room:String=str(app.room_id)
 var generation:int=int(app.runtime_generation)
 var now:float=float(app.world_visual_time)
 var reset:bool=room!=_previous_room or generation!=_previous_generation or not _previous_position.is_finite() or now<_previous_world_time
 var distance:float=0.0 if reset else position.distance_to(_previous_position)
 # A scene/restore/teleport must never be interpreted as a giant walk step.
 if distance>.5:distance=0.0;reset=true
 if not paused:_travel+=distance
 var moving:bool=distance>.00001 and not paused
 if reset:_weight=0.0
 elif not paused:_weight=move_toward(_weight,1.0 if moving else 0.0,maxf(0,delta)/.085)
 _previous_position=position;_previous_room=room;_previous_generation=generation;_previous_world_time=now
 diagnostics.travel_m=_travel;diagnostics.locomotion_weight=_weight
 if not _production_ready:return
 if paused and not _sample.is_empty():
  viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
 _sample=State.sample(app,catalog)
 var requested_direction:int=int(_sample.direction)
 if rig.direction!=requested_direction:
  rig.set_direction(requested_direction);_fit_view()
 var context:Dictionary=_sample.duplicate(true)
 context.erase("hands");context.erase("item_hands");context.erase("resting")
 if moving or (_weight>.001 and str(context.state) in ["idle","walk"]):context.state="walk"
 context.moving=moving;context.locomotion_weight=_weight;context.travel_m=_travel;context.paused=paused
 var facing:Vector2=app.hero_facing.normalized()
 context.stride_axis_px=(app.layout.project(position+facing)-app.layout.project(position))*_body_height/HEIGHT
 context.hand_targets={}
 var at:Vector2=app.layout.project(position)
 for hand:String in _sample.hands:context.hand_targets[hand]=(Vector2(_sample.hands[hand])-at)*_body_height/HEIGHT
 # Direction changes may have their own calibrated canvas/foot, never stretch.
 var old_direction:int=rig.direction
 rig.sample_pose(context)
 if old_direction!=rig.direction:_fit_view()
 diagnostics.clamped_targets=rig.clamped_targets.duplicate()
 diagnostics.direction=rig.direction;diagnostics.state=context.state;diagnostics.pose=rig.pose_snapshot()
 var key:String=var_to_str(context)
 if key!=_pose_key:
  viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;_pose_key=key
