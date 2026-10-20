extends Node
## Independent UI rig; only a formally enabled four-view configuration may draw.
const Rig=preload("res://scripts/presentation/cutout_actor_2d.gd")
var rig
var viewport:SubViewport
var config:Dictionary={}
var pose_data:Dictionary={}
var is_ready:bool=false
var last_reason:String="主角四向预览仍在校准"
var _frame:Dictionary={}
var _signature:String=""
func _ready() -> void:
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_rig.json"))
 var id:String=str(config.get("default",""))
 var value:Dictionary=config.get("rigs",{}).get(id,{}).duplicate(true)
 if not bool(value.get("production_ready",false)):return
 for direction:int in range(4):
  if not bool(value.get("directions",{}).get("D%d"%direction,{}).get("enabled",false)):return
 pose_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_body_preview_poses.json"))
 for skill:String in pose_data.get("poses",{}):
  var tracks:Dictionary=pose_data.poses[skill].get("tracks",{})
  if tracks.is_empty():last_reason="缺少对应预览轨迹";return
  value.poses["ui_"+skill]=tracks.duplicate(true)
 viewport=SubViewport.new();viewport.transparent_bg=true;viewport.disable_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
 rig=Rig.new();viewport.add_child(rig)
 if not rig.configure(value):return
 for direction:int in range(4):
  if not rig.is_available(direction):return
 is_ready=true;last_reason=""
func sample(angle:int,id:String,left:float,clock:float,reduced:bool) -> void:
 if not is_ready:return
 var direction:int=[3,0,1,2][posmod(angle,4)]
 rig.set_direction(direction)
 var duration:float=float(pose_data.get("duration_seconds",2.0))
 var progress:float=clampf(1.0-left/duration,0,1)
 var active:bool=left>0 and pose_data.poses.has(id)
 var context:Dictionary={"direction":direction,"state":"ui_"+id if active else "idle","elapsed":clock,"progress":progress,"duration":duration,"moving":false,"idle_weight":0.0 if reduced else 1.0,"hand_targets":{}}
 if active:
  var spec:Dictionary=pose_data.poses[id]
  var view:Dictionary=rig.rig_config.directions["D%d"%direction]
  var amount:float=sin(progress*PI)
  for hand:String in spec.get("hands",{}):
   var raw:Array=view.bones[hand].rest_px
   var rest:Vector2=Vector2(float(raw[0]),float(raw[1]))-rig.foot_anchor()
   var target:Array=spec.hands[hand]
   context.hand_targets[hand]=rest.lerp(Vector2(float(target[0]),float(target[1]))*rig.body_height(),amount)
 rig.sample_pose(context)
 var factor:float=300.0/rig.body_height()
 viewport.size=Vector2i(rig.canvas_size()*factor+Vector2(100,30))
 var foot:Vector2=rig.foot_anchor()*factor+Vector2(50,15)
 rig.scale=Vector2.ONE*factor;rig.position=foot
 _frame={"texture":viewport.get_texture(),"size":Vector2(viewport.size),"foot":foot,"body_height":300.0,"pose":id if active else "idle","direction":direction}
 var signature:String=var_to_str(context)
 if signature!=_signature:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;_signature=signature
func draw(canvas:CanvasItem,foot:Vector2,height:float=260.0) -> bool:
 if not is_ready or _frame.is_empty():return false
 var factor:float=height/float(_frame.body_height)
 canvas.draw_texture_rect(_frame.texture,Rect2(foot-_frame.foot*factor,_frame.size*factor),false)
 return true
func frame() -> Dictionary:return _frame.duplicate() if is_ready else {}
