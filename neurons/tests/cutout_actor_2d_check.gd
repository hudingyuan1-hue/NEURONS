extends SceneTree
## Uses an in-memory diagnostic atlas. These pixels are never production art.
const Actor=preload("res://scripts/presentation/cutout_actor_2d.gd")
var checks:int=0
var failures:Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)

func fixture() -> Dictionary:
 var points:Dictionary={
  "pelvis":[100,110],"spine":[100,90],"chest":[100,60],"neck":[100,35],"head":[100,20],
  "left_upper_arm":[75,60],"left_forearm":[60,85],"left_hand":[55,110],
  "right_upper_arm":[125,60],"right_forearm":[140,85],"right_hand":[145,110],
  "left_thigh":[88,110],"left_shin":[88,155],"left_foot":[88,200],
  "right_thigh":[112,110],"right_shin":[112,155],"right_foot":[112,200]}
 var bones:Dictionary={};var parts:Array=[];var n:int=0
 var image:=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 for name:String in Actor.BONE_PARENTS:bones[name]={"parent":Actor.BONE_PARENTS[name],"rest_px":points[name]}
 for name:String in Actor.REQUIRED_PARTS:
  var x:int=(n%4)*16;var y:int=(n/4)*16
  image.fill_rect(Rect2i(x+2,y+2,12,12),Color.WHITE)
  parts.append({"id":name,"bone":"chest" if name=="torso" else name,"region_px":[x,y,16,16],"pivot_px":[8,8],"z_index":n})
  n+=1
 return {"id":"TEST_ONLY","enabled":true,"canvas_px":[200,240],"foot_anchor_px":[100,220],"body_height_px":200,"stride_m":.8,"stance_fraction":.6,
  "sockets":{"left_hand":{"bone":"left_hand","offset_px":[2,3]}},
  "poses":{"hit":{"chest":[[0,0],[.2,-8],[.7,-5],[1,0]]}},
  "directions":{"D0":{"atlas_texture":ImageTexture.create_from_image(image),"bones":bones,"parts":parts}}}

func limb_lengths(actor,side:String) -> Vector2:
 return Vector2(actor.bone_position(side+"_thigh").distance_to(actor.bone_position(side+"_shin")),actor.bone_position(side+"_shin").distance_to(actor.bone_position(side+"_foot")))

func run() -> void:
 var actor:=Actor.new();root.add_child(actor)
 var disabled:Dictionary=fixture();disabled.enabled=false
 check(not actor.configure(disabled),"Disabled configuration never appears as formal art")
 check(not actor.is_available(),"Missing formal atlas requests fallback")
 check(actor._sprites.is_empty(),"Fallback does not render diagnostic colored parts")
 var config:Dictionary=fixture()
 check(actor.configure(config),"Valid transparent memory atlas is available")
 check(actor.skeleton is Skeleton2D,"Actual Skeleton2D is constructed")
 check(actor._bones.size()==17 and actor._sprites.size()==15,"Seventeen bones and fifteen authored pieces")
 check(not actor.is_processing(),"Rig has no autonomous animation process")
 check(actor.is_available(0) and not actor.is_available(1),"Availability is per direction")
 check(actor.bone_position("left_foot").is_equal_approx(Vector2(-12,-20)),"Absolute source joints assemble relative to foot anchor")
 var walk:Dictionary={"state":"walk","travel_m":.1,"ground_axis":[1,0],"ground_px_per_m":40.0,"elapsed":.1,"duration":1,"action_uid":"move-1"}
 actor.sample_pose(walk)
 var pose:Dictionary=actor.pose_snapshot()
 check(actor.foot_contacts.left.planted and not actor.foot_contacts.right.planted,"Opposite feet alternate support and swing")
 var before:Vector2=actor.bone_position("left_foot")+Vector2(.1*40,0)
 walk.travel_m=.11;actor.sample_pose(walk)
 var after:Vector2=actor.bone_position("left_foot")+Vector2(.11*40,0)
 check(before.distance_to(after)<.005,"Planted foot cancels actual root travel without sliding")
 check(limb_lengths(actor,"left").distance_to(Vector2(45,45))<.001,"Leg lengths stay fixed under IK")
 check(limb_lengths(actor,"right").distance_to(Vector2(45,45))<.001,"Swing leg length stays fixed")
 actor.sample_pose(walk);var repeat:Dictionary=actor.pose_snapshot()
 actor.sample_pose(walk)
 check(repeat==actor.pose_snapshot(),"Repeated same phase produces identical transforms")
 walk.elapsed=1000.0;actor.sample_pose(walk)
 check(repeat==actor.pose_snapshot(),"Walking ignores elapsed world time at fixed travel distance")
 walk.travel_m=.5;actor.sample_pose(walk)
 check(not actor.foot_contacts.left.planted and actor.foot_contacts.right.planted,"Half cycle exchanges the planted side")
 var frozen:Dictionary=actor.pose_snapshot()
 actor.sample_pose({"state":"hit","direction":1,"travel_m":1000,"elapsed":1000,"paused":true})
 check(frozen==actor.pose_snapshot(),"Pause freezes both pose and direction")
 actor.sample_pose({"state":"search_low","elapsed":.3,"duration":1,"hand_targets":{"left_hand":[-35,-110]}})
 check(actor.socket_position("left_hand").distance_to(Vector2(-35,-110))<.01,"Hand socket aligns with supplied contact target")
 actor.sample_pose({"state":"hit","progress":1.0,"action_uid":"hit-12"})
 check(absf(actor._bones.chest.rotation)<.0001,"One shot reaches authored end pose")
 check(actor.pose_snapshot().action_uid=="hit-12","Caller action identity remains attached to visual sample")
 actor.sample_pose({"state":"idle","elapsed":0,"hand_targets":{"right_hand":[900,-900]}})
 check(actor.clamped_targets.has("right_hand"),"Out of reach targets are reported without stretching")
 var right_upper:float=actor.bone_position("right_upper_arm").distance_to(actor.bone_position("right_forearm"))
 check(absf(right_upper-Vector2(15,25).length())<.001,"Unreachable hand preserves actual upper arm length")
 config=fixture();config.directions.D0.parts[0].scale=[2,1.5];config.directions.D0.parts[0].rotation_degrees=30;config.directions.D0.parts[0].offset_px=[3,4]
 actor.configure(config)
 var sprite:Sprite2D=actor._sprites[0]
 check(sprite.offset==Vector2(-8,-8) and sprite.position==Vector2(3,4),"Part pivot is applied before scale and rotation")
 check(sprite.scale==Vector2(2,1.5) and absf(sprite.rotation-deg_to_rad(30))<.0001,"Author scale and axis correction are supported")
 check(sprite.to_global(Vector2(8,8)+sprite.offset).distance_to(actor._bones.head.to_global(Vector2(3,4)))<.001,"Scaled rotated pivot remains on authored joint offset")
 config=fixture();config.directions.D0.parts.pop_back()
 check(not actor.configure(config),"Missing a required part requests fallback")
 config=fixture();config.directions.D0.parts[0].region_px=[63,63,16,16]
 check(not actor.configure(config),"Atlas region outside source texture requests fallback")
 config=fixture();config.directions.D0.atlas_texture=null;config.directions.D0.atlas="res://assets/DOES_NOT_EXIST.png"
 check(not actor.configure(config),"Missing atlas source requests fallback without loading failure")
 check(not actor.errors.is_empty(),"Unavailable atlas has a useful diagnostic")
 config=fixture();config.directions.D0.parts[0].scale=[0,1]
 check(not actor.configure(config),"Zero piece scale requests fallback")
 config=fixture();config.directions.D0.parts[0].pivot_px="unannotated"
 check(not actor.configure(config),"Malformed pivot requests fallback without a parser or runtime error")
 config=fixture();config.directions.D0.parts[0].rotation_degrees="unknown"
 check(not actor.configure(config),"Malformed optional axis correction requests fallback")
 config=fixture();config.directions.D0.parts[0].id="torso"
 check(not actor.configure(config),"Duplicate part identity cannot appear as a complete character")
 actor.configure(fixture());actor.sample_pose({"state":"walk","travel_m":.2,"locomotion_weight":0})
 check(actor.bone_position("left_foot").is_equal_approx(Vector2(-12,-20)),"Zero locomotion weight returns the authored rest without resetting travel")
 actor.sample_pose({"state":"walk","travel_m":.2,"ground_px_per_m":40,"moving":false,"locomotion_weight":.5})
 check(not actor.foot_contacts.is_empty(),"Caller can blend out a stopped gait without restarting its phase")
 actor.sample_pose({"state":"search","root_rotation":.15,"hand_targets":{"left_hand":[-35,-130]}})
 check(actor.socket_position("left_hand").distance_to(Vector2(-35,-130))<.01,"Root visual tilt preserves the supplied rig-local hand contact")
 actor.sample_pose({"state":"walk","travel_m":.1,"stride_axis_px":[40,-5],"ground_axis":[0,1],"ground_px_per_m":1000})
 before=actor.bone_position("left_foot")+Vector2(40,-5)*.1
 actor.sample_pose({"state":"walk","travel_m":.11,"stride_axis_px":[40,-5],"ground_axis":[0,1],"ground_px_per_m":1000})
 after=actor.bone_position("left_foot")+Vector2(40,-5)*.11
 check(before.distance_to(after)<.005,"Explicit projected stride vector overrides fallback axes and cancels both screen coordinates")
 check(actor.clamped_targets.is_empty(),"Valid projected gait reaches both foot targets")
 actor.configure(fixture())
 check(not actor.load_config("res://data/DOES_NOT_EXIST.json") and not actor.is_available(),"Failed config load cannot leave a previous character available")
 config=fixture();config.directions.D0.bones.left_shin.rest_px=[85,155];config.directions.D0.bones.right_shin.rest_px=[115,155]
 actor.configure(config)
 var stable_bends:bool=true
 for index in 64:
  actor.sample_pose({"state":"walk","travel_m":.8*index/64.0,"stride_axis_px":[40,-5]})
  for side:String in ["left","right"]:
   var upper:Vector2=actor.bone_position(side+"_thigh");var middle:Vector2=actor.bone_position(side+"_shin");var end:Vector2=actor.bone_position(side+"_foot")
   var cross:float=(middle-upper).cross(end-upper)
   if (side=="left" and cross>.0001) or (side=="right" and cross<-.0001):stable_bends=false
 check(stable_bends,"Full gait retains each source knee bend side instead of flipping")
 config=fixture();config.directions.D0.soft_skinning=true
 check(actor.configure(config) and actor._meshes.size()==9 and actor._sprites.size()==6,"Optional local meshes replace only hip and limb slices")
 var weights_valid:bool=true;var neighbor_used:bool=false
 for mesh:Polygon2D in actor._meshes:
  var sums:=PackedFloat32Array();sums.resize(mesh.polygon.size());sums.fill(0)
  for index in mesh.get_bone_count():
   var weights:PackedFloat32Array=mesh.get_bone_weights(index)
   if weights.size()!=sums.size() or not actor.skeleton.has_node(mesh.get_bone_path(index)):weights_valid=false
   for vertex in weights.size():
    sums[vertex]+=weights[vertex]
    if weights[vertex]>.01 and weights[vertex]<.99:neighbor_used=true
  for total:float in sums:
   if absf(total-1)>.0001:weights_valid=false
 check(weights_valid and neighbor_used,"Every mesh vertex has normalized weights on valid adjacent bones")
 actor.sample_pose({"state":"walk","travel_m":.15,"stride_axis_px":[40,-5]})
 check(limb_lengths(actor,"left").distance_to(Vector2(45,45))<.001,"Soft skinning does not change the physical IK bone chain")
 actor.sample_pose({"state":"search_low","progress":0})
 var low_start:Vector2=actor.bone_position("pelvis")
 actor.sample_pose({"state":"search_low","progress":.5})
 var low_middle:Vector2=actor.bone_position("pelvis")
 actor.sample_pose({"state":"search_low","progress":1})
 check(low_start.distance_to(actor.bone_position("pelvis"))<.001 and low_middle.y>low_start.y,"Low action smoothly enters and returns to rest on its actual clock")
 actor.sample_pose({"state":"search_low","progress":.5,"crouch_weight":.25})
 check(absf((actor.bone_position("pelvis").y-low_start.y)/(low_middle.y-low_start.y)-.25)<.001,"Caller can retain a partial crouch during a visual interruption")
 config=fixture();config.directions.D0.soft_skinning=true;config.directions.D0.depth_projection=true
 actor.configure(config)
 var depth_lengths:Array=[];var depth_anchors:bool=true;var depth_model:bool=true
 for index in 64:
  actor.sample_pose({"state":"walk","travel_m":.8*index/64.0,"stride_axis_px":[8,30]})
  for side:String in ["left","right"]:
   var contact:Dictionary=actor.foot_contacts[side]
   if Vector2(contact.target).distance_to(contact.actual)>.001:depth_anchors=false
   if not contact.has("model_leg_lengths_m") or absf(float(contact.model_leg_lengths_m[0])-45.0/(actor.body_height()/1.75))>.00001:depth_model=false
  depth_lengths.append(limb_lengths(actor,"left"))
 check(depth_anchors and actor.clamped_targets.is_empty(),"Depth-facing legs retain exact projected foot contacts through the full cycle")
 check(depth_model and Vector2(depth_lengths[0]).distance_to(depth_lengths[16])>.1,"Anatomical model lengths stay fixed while screen segments foreshorten naturally")
 actor.queue_free()
 var report:Dictionary={"checks":checks,"failures":failures,"failed":failures.size(),"scope":"Independent visual rig technical checks; synthetic atlas only; no formal artwork or game play acceptance"}
 var output:String=ProjectSettings.globalize_path("res://../tmp/asset_production_20261020/rig_component_check.json")
 var file:=FileAccess.open(output,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
