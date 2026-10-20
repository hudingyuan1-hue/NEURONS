extends SceneTree
## Real renderer evidence for externally clocked four-direction cutout motion.
## This board is a visual component check; it does not assert game acceptance.
const Actor=preload("res://scripts/presentation/cutout_actor_2d.gd")
const AXES=[Vector2(96,-6),Vector2(-16,-56),Vector2(-96,6),Vector2(16,56)]
const FPS:int=30
const SECONDS:float=7.0
var output_dir:String="res://../tmp/asset_production_20261020/main_motion_r1"

class Board extends Node2D:
 var caption:String=""
 var targets:Array[Vector2]=[]
 func _draw() -> void:
  draw_rect(Rect2(0,0,1400,1500),Color("252b2c"))
  for direction in 4:
   var origin:=Vector2((direction%2)*700,(direction/2)*750)
   draw_rect(Rect2(origin+Vector2(8,8),Vector2(684,734)),Color("363e3d"))
   for x in range(20,700,40):draw_line(origin+Vector2(x,500),origin+Vector2(x,710),Color("46504c"),1)
   for y in range(500,720,30):draw_line(origin+Vector2(20,y),origin+Vector2(680,y),Color("46504c"),1)
   draw_string(ThemeDB.fallback_font,origin+Vector2(24,40),"D%d | %s"%[direction,caption],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("d0d3c6"))
   draw_string(ThemeDB.fallback_font,origin+Vector2(24,72),"Visual rig board / real atlas / external phase",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b4b9ad"))
  for target:Vector2 in targets:
   draw_arc(target,8,0,TAU,24,Color("d7b66e"),2,true)
   draw_line(target-Vector2(11,0),target+Vector2(11,0),Color("d7b66e"),1,true)
   draw_line(target-Vector2(0,11),target+Vector2(0,11),Color("d7b66e"),1,true)

func _initialize() -> void:call_deferred("run")

func safe(value):
 if value is Vector2:return [value.x,value.y]
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[str(key)]=safe(value[key])
  return result
 if value is Array:
  var result:Array=[]
  for item in value:result.append(safe(item))
  return result
 return value

func envelope(progress:float) -> float:
 return smoothstep(0,.22,progress)*(1-smoothstep(.78,1,progress))

func run() -> void:
 var args:PackedStringArray=OS.get_cmdline_user_args()
 for index in args.size()-1:
  if args[index]=="--output-dir":output_dir=args[index+1]
 output_dir=ProjectSettings.globalize_path(output_dir)
 DirAccess.make_dir_recursive_absolute(output_dir.path_join("frames"))
 var viewport:=SubViewport.new();viewport.size=Vector2i(1400,1500);viewport.disable_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var board:=Board.new();viewport.add_child(board)
 var actors:Array=[];var bases:Array[Vector2]=[];var rig_scales:Array[float]=[]
 for direction in 4:
  var actor:=Actor.new();viewport.add_child(actor)
  actor.load_config("res://data/character_rig.json","CHR_MAIN_PAJAMA");actor.set_direction(direction)
  if not actor.is_available():push_error("Missing actual direction %d: %s"%[direction,str(actor.errors)]);quit(2);return
  var scale_px:float=300.0/actor.body_height();actor.scale=Vector2.ONE*scale_px;actor.z_index=10
  var origin:=Vector2((direction%2)*700,(direction/2)*750)
  var base:Vector2=origin+[Vector2(200,600),Vector2(360,640),Vector2(490,600),Vector2(290,490)][direction]
  actors.append(actor);bases.append(base);rig_scales.append(scale_px)
 var travel:float=0.0;var frames:Array=[];var max_hand_error:float=0.0;var clamp_frames:Array=[]
 for frame in int(SECONDS*FPS):
  if frame%10==0:print("pose frame ",frame)
  var seconds:float=frame/float(FPS);var speed:float=.55*smoothstep(.35,.55,seconds)*(1-smoothstep(2.55,2.75,seconds))
  travel+=speed/FPS
  var locomotion:float=smoothstep(.35,.55,seconds)*(1-smoothstep(2.75,2.95,seconds))
  var state:String="walk" if locomotion>.00001 else "idle"
  var action_progress:float=0;var hand_weight:float=0
  if seconds>=3.2 and seconds<4.7:state="search";action_progress=(seconds-3.2)/1.5;hand_weight=envelope(action_progress)
  elif seconds>=4.7 and seconds<6.7:
   state="search_low";action_progress=(seconds-4.7)/2.0
   hand_weight=smoothstep(.16,.32,action_progress)*(1-smoothstep(.68,.84,action_progress))
  board.caption="%s %.2fs"%[state,seconds];board.targets.clear()
  var samples:Array=[]
  for direction in 4:
   var actor=actors[direction];var axis:Vector2=AXES[direction]*actor.body_height()/137.0
   actor.position=bases[direction]+axis*travel*rig_scales[direction]
   var context:Dictionary={"direction":direction,"state":state,"travel_m":travel,"stride_axis_px":axis,"elapsed":seconds,"progress":action_progress,"locomotion_weight":locomotion,"action_uid":"board-%s"%state}
   actor.sample_pose(context)
   if frame==96:print("reached base pose 96 D",direction)
   if hand_weight>0:
    var rest_hand:Vector2=actor.socket_position("right_hand")
    var target:Vector2=Vector2(170,-480) if state=="search_low" else Vector2(180,-760)
    var eased_target:Vector2=rest_hand.lerp(target,hand_weight)
    context.hand_targets={"right_hand":eased_target};actor.sample_pose(context)
    if frame==96:print("reached hand pose 96 D",direction)
    max_hand_error=maxf(max_hand_error,actor.socket_position("right_hand").distance_to(eased_target))
    board.targets.append(actor.position+eased_target*rig_scales[direction])
   if not actor.clamped_targets.is_empty():clamp_frames.append({"frame":frame,"direction":direction,"targets":actor.clamped_targets.duplicate()})
   samples.append(actor.pose_snapshot())
  board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  var picture:Image=viewport.get_texture().get_image()
  if picture==null or picture.is_empty():push_error("Real GPU required");quit(3);return
  picture.save_png(output_dir.path_join("frames/%04d.png"%frame))
  frames.append({"frame":frame,"seconds":seconds,"travel_m":travel,"state":state,"poses":samples})
 var file:=FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(safe({"fps":FPS,"seconds":SECONDS,"frames":frames,"clamped_frames":clamp_frames,"max_hand_error_px":max_hand_error,"scope":"Four real atlas directions, continuous walk/stop/reach/crouch; component visual evidence, no game acceptance"}),"  "))
 print("Continuous real-rig frames: %d, clamp frames %d, max hand error %.6f"%[frames.size(),clamp_frames.size(),max_hand_error]);quit(0)
