extends SceneTree
## Read-only production-rig capture. Run with a real renderer after importing art.
## Example: Godot_console --path neurons --script res://tests/capture_main_cutout_d0.gd
const Actor=preload("res://scripts/presentation/cutout_actor_2d.gd")
var output_dir:String="res://../tmp/asset_production_20261020/D0_pose_preview"
var manifest:Array=[]
var view_direction:int=0
var capture_skeletons:bool=false

func _initialize() -> void:call_deferred("run")

func json_safe(value):
 if value is Vector2 or value is Vector2i:return [value.x,value.y]
 if value is Rect2 or value is Rect2i:return [value.position.x,value.position.y,value.size.x,value.size.y]
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[str(key)]=json_safe(value[key])
  return result
 if value is Array:
  var result:Array=[]
  for item in value:result.append(json_safe(item))
  return result
 return value

func run() -> void:
 var args:PackedStringArray=OS.get_cmdline_user_args()
 for index in args.size()-1:
  if args[index]=="--output-dir":output_dir=args[index+1]
  if args[index]=="--direction":view_direction=clampi(int(args[index+1]),0,3)
 capture_skeletons=args.has("--skeleton")
 output_dir=ProjectSettings.globalize_path(output_dir)
 DirAccess.make_dir_recursive_absolute(output_dir)
 var viewport:=SubViewport.new();viewport.name="ActualD0Capture";viewport.disable_3d=true
 viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var actor:=Actor.new();viewport.add_child(actor)
 if not actor.load_config("res://data/character_rig.json","CHR_MAIN_PAJAMA") or not actor.is_available(0):
  push_error("D0 actual atlas/config unavailable; capture cannot substitute synthetic art. "+str(actor.errors));quit(2);return
 actor.set_direction(view_direction)
 var canvas:Vector2=actor.canvas_size();var margin:=Vector2(120,100)
 viewport.size=Vector2i(canvas+margin*2)
 actor.position=actor.foot_anchor()+margin
 var stride:float=float(actor._view.get("stride_m",actor.rig_config.get("stride_m",.55)))
 var stride_axis:Vector2=[Vector2(96,-6),Vector2(-16,-56),Vector2(-96,6),Vector2(16,56)][view_direction]*actor.body_height()/137.0
 var common:Dictionary={"direction":view_direction,"duration":1.0,"stride_m":stride,"stride_axis_px":stride_axis,"walk_pelvis_drop_fraction":.043}
 var samples:Array=[
  {"name":"idle","context":{"state":"idle","elapsed":0}},
  {"name":"walk_000","context":{"state":"walk","travel_m":0}},
  {"name":"walk_025","context":{"state":"walk","travel_m":stride*.25}},
  {"name":"walk_050","context":{"state":"walk","travel_m":stride*.5}},
  {"name":"walk_075","context":{"state":"walk","travel_m":stride*.75}},
  {"name":"reach_left","context":{"state":"search","progress":.65,"hand_targets":{"left_hand":Vector2(-210,-780)}}},
  {"name":"reach_right","context":{"state":"search","progress":.65,"hand_targets":{"right_hand":Vector2(300,-730)}}},
  {"name":"search_low","context":{"state":"search_low","progress":.65,"hand_targets":{"right_hand":Vector2(260,-480)}}}
 ]
 for sample:Dictionary in samples:
  var context:Dictionary=sample.context
  context.merge(common,false);context.action_uid="preview-"+sample.name
  actor.sample_pose(context)
  await process_frame
  await RenderingServer.frame_post_draw
  var picture:Image=viewport.get_texture().get_image()
  if picture==null or picture.is_empty():push_error("No real render output; do not run this GPU capture with --headless");quit(3);return
  var path:String=output_dir.path_join("CHR_MAIN_D%d_"%view_direction+sample.name+".png")
  var code:int=picture.save_png(path)
  if code!=OK:push_error("Unable to save "+path);quit(4);return
  var lengths:Dictionary={}
  for side:String in ["left","right"]:
   lengths[side+"_leg"]=[actor.bone_position(side+"_thigh").distance_to(actor.bone_position(side+"_shin")),actor.bone_position(side+"_shin").distance_to(actor.bone_position(side+"_foot"))]
   lengths[side+"_arm"]=[actor.bone_position(side+"_upper_arm").distance_to(actor.bone_position(side+"_forearm")),actor.bone_position(side+"_forearm").distance_to(actor.bone_position(side+"_hand"))]
  manifest.append({"name":sample.name,"path":path,"size":[picture.get_width(),picture.get_height()],"context":context,"pose":actor.pose_snapshot(),"limb_lengths_px":lengths,"used_rect":picture.get_used_rect(),"atlas":actor._view.get("atlas","")})
  if capture_skeletons:
   for node in actor._part_nodes.values():node.visible=false
   actor.debug_bones=true;await process_frame;await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(path.get_basename()+"_skeleton.png")
   actor.debug_bones=false
   for node in actor._part_nodes.values():node.visible=true
 var sweep:Dictionary={"samples":128,"clamped_samples":[],"max_foot_error_px":0.0,"max_leg_length_error_px":0.0,"max_model_leg_length_error_m":0.0,"depth_projection":actor._view.get("depth_projection",false),"parameters":common.duplicate(true)}
 var rest_lengths:Dictionary={}
 for side:String in ["left","right"]:
  rest_lengths[side]=[Vector2(actor._rests[side+"_thigh"]).distance_to(actor._rests[side+"_shin"]),Vector2(actor._rests[side+"_shin"]).distance_to(actor._rests[side+"_foot"])]
 for index in 128:
  var context:Dictionary=common.duplicate(true);context.state="walk";context.travel_m=stride*index/128.0;context.action_uid="gait-sweep"
  actor.sample_pose(context)
  if not actor.clamped_targets.is_empty():sweep.clamped_samples.append({"phase":index/128.0,"targets":actor.clamped_targets.duplicate()})
  for side:String in ["left","right"]:
   var contact:Dictionary=actor.foot_contacts[side]
   sweep.max_foot_error_px=maxf(sweep.max_foot_error_px,Vector2(contact.target).distance_to(contact.actual))
   var length_a:float=actor.bone_position(side+"_thigh").distance_to(actor.bone_position(side+"_shin"))
   var length_b:float=actor.bone_position(side+"_shin").distance_to(actor.bone_position(side+"_foot"))
   if actor._view.get("depth_projection",false):
    sweep.max_model_leg_length_error_m=maxf(sweep.max_model_leg_length_error_m,maxf(absf(float(contact.model_leg_lengths_m[0])-rest_lengths[side][0]/(actor.body_height()/1.75)),absf(float(contact.model_leg_lengths_m[1])-rest_lengths[side][1]/(actor.body_height()/1.75))))
   else:sweep.max_leg_length_error_px=maxf(sweep.max_leg_length_error_px,maxf(absf(length_a-rest_lengths[side][0]),absf(length_b-rest_lengths[side][1])))
 var file:=FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(json_safe({"source_config":"res://data/character_rig.json","captures":manifest,"gait_sweep":sweep,"scope":"Real D0 production rig visual preview; not gameplay or final art acceptance"}),"  "))
 print("Actual D0 cutout previews: "+str(manifest.size())+" at "+output_dir)
 quit(0)
