extends Node2D
## Visual-only cutout rig. The caller owns time, movement, contacts and receipts.
## No autonomous process, gameplay callbacks, audio tracks or collision bodies.
const BONE_PARENTS={
 "pelvis":"","spine":"pelvis","chest":"spine","neck":"chest","head":"neck",
 "left_upper_arm":"chest","left_forearm":"left_upper_arm","left_hand":"left_forearm",
 "right_upper_arm":"chest","right_forearm":"right_upper_arm","right_hand":"right_forearm",
 "left_thigh":"pelvis","left_shin":"left_thigh","left_foot":"left_shin",
 "right_thigh":"pelvis","right_shin":"right_thigh","right_foot":"right_shin"}
const REQUIRED_PARTS=["head","torso","pelvis","left_upper_arm","left_forearm","left_hand","right_upper_arm","right_forearm","right_hand","left_thigh","left_shin","left_foot","right_thigh","right_shin","right_foot"]
var debug_bones:bool=false:
 set(value):debug_bones=value;queue_redraw()
var errors:Array[String]=[]
var rig_config:Dictionary={}
var direction:int=0
var last_context:Dictionary={}
var foot_contacts:Dictionary={}
var clamped_targets:Array[String]=[]
var skeleton:Skeleton2D
var _view:Dictionary={}
var _bones:Dictionary={}
var _rests:Dictionary={}
var _sprites:Array[Sprite2D]=[]
var _meshes:Array[Polygon2D]=[]
var _part_nodes:Dictionary={}
var _part_z:Dictionary={}
var gait_body_drop_px:float=0.0
var _textures:Dictionary={}
var _ready_views:Dictionary={}
var _available:bool=false

func _vector(value,default:Vector2=Vector2.ZERO) -> Vector2:
 if value is Vector2:return value
 if value is Array and value.size()>=2:return Vector2(float(value[0]),float(value[1]))
 return default

func _numeric_array(value,count:int) -> bool:
 if not value is Array or value.size()!=count:return false
 for number in value:
  if (not number is int and not number is float) or not is_finite(float(number)):return false
 return true

func _view_for(key:String) -> Dictionary:
 var views=rig_config.get("directions",{})
 if not views is Dictionary:return {}
 var value=views.get(key,{})
 return value if value is Dictionary else {}

func _reject(key:String,message:String) -> bool:
 errors.append(key+": "+message)
 return false

func _unload_error(message:String) -> bool:
 configure({"enabled":false,"directions":{}})
 errors.assign([message])
 return false

func load_config(path:String="res://data/character_rig.json",id:String="") -> bool:
 if not FileAccess.file_exists(path):return _unload_error("Rig JSON is missing: "+path)
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary:return _unload_error("Invalid rig JSON: "+path)
 if data.has("rigs"):
  var selected:String=id if not id.is_empty() else str(data.get("default",""))
  if not data.rigs is Dictionary or not data.rigs.has(selected) or not data.rigs[selected] is Dictionary:return _unload_error("Unknown rig ID: "+selected)
  return configure(data.rigs[selected])
 return configure(data)

func configure(value:Dictionary,initial_direction:int=0) -> bool:
 rig_config=value.duplicate(true);errors.clear();_textures.clear();_ready_views.clear()
 last_context.clear();foot_contacts.clear();clamped_targets.clear()
 var views=rig_config.get("directions",{})
 if views is Dictionary:
  for key:String in views:_ready_views[key]=_validate_view(key)
 else:errors.append("directions must be a dictionary")
 _build_direction(clampi(initial_direction,0,3))
 return _available

func _texture_for(key:String):
 if _textures.has(key):return _textures[key]
 var view:Dictionary=_view_for(key)
 var texture=view.get("atlas_texture")
 if not texture is Texture2D:
  var path:String=str(view.get("atlas",""))
  texture=load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
 _textures[key]=texture
 return texture

func _validate_view(key:String) -> bool:
 var view:Dictionary=_view_for(key)
 if not rig_config.get("enabled",false) or not view.get("enabled",true):return false
 var texture=_texture_for(key)
 if not texture is Texture2D:return _reject(key,"atlas texture is missing")
 var height=view.get("body_height_px",rig_config.get("body_height_px",0))
 if (not height is int and not height is float) or not is_finite(float(height)) or float(height)<=0:return _reject(key,"body_height_px must be positive")
 for field:String in ["canvas_px","foot_anchor_px"]:
  if not _numeric_array(view.get(field,rig_config.get(field,[])),2):return _reject(key,field+" must contain two finite numbers")
 var bones=view.get("bones",{})
 if not bones is Dictionary:return _reject(key,"bones must be a dictionary")
 for bone:String in BONE_PARENTS:
  if not bones.has(bone) or not bones[bone] is Dictionary or not _numeric_array(bones[bone].get("rest_px",[]),2):return _reject(key,"missing valid rest_px for "+bone)
  if bones[bone].has("parent") and str(bones[bone].parent)!=str(BONE_PARENTS[bone]):return _reject(key,"unexpected parent for "+bone)
 var seen:Dictionary={}
 var parts=view.get("parts",[])
 if not parts is Array:return _reject(key,"parts must be an array")
 for part in parts:
  if not part is Dictionary:return _reject(key,"part must be a dictionary")
  var raw=part.get("region_px",[])
  if not _numeric_array(raw,4) or not bones.has(str(part.get("bone",""))):return _reject(key,"invalid region or bone for part")
  var region:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
  if region.size.x<=0 or region.size.y<=0 or not Rect2(Vector2.ZERO,texture.get_size()).encloses(region):return _reject(key,"part region is outside its atlas")
  if not _numeric_array(part.get("pivot_px",[]),2):return _reject(key,"part pivot must contain two finite numbers")
  if part.has("offset_px") and not _numeric_array(part.offset_px,2):return _reject(key,"invalid part offset")
  if part.has("scale"):
   if not _numeric_array(part.scale,2) or float(part.scale[0])<=0 or float(part.scale[1])<=0:return _reject(key,"part scale must be positive")
  var rotation=part.get("rotation_degrees",0)
  if (not rotation is int and not rotation is float) or not is_finite(float(rotation)):return _reject(key,"invalid part axis rotation")
  var id:String=str(part.get("id",""))
  if id.is_empty() or seen.has(id):return _reject(key,"missing or duplicate part ID")
  seen[id]=true
 for id:String in REQUIRED_PARTS:
  if not seen.has(id):return _reject(key,"missing required part "+id)
 return true

func is_available(view_direction:int=-1) -> bool:
 if view_direction<0:return _available
 return bool(_ready_views.get("D%d"%clampi(view_direction,0,3),false))

func set_direction(value:int) -> void:
 value=clampi(value,0,3)
 if value==direction and skeleton!=null:return
 _build_direction(value)

func _build_direction(value:int) -> void:
 direction=value;_available=is_available(value)
 _view=_view_for("D%d"%direction).duplicate(true)
 _bones.clear();_rests.clear();_sprites.clear();_meshes.clear();_part_nodes.clear();_part_z.clear()
 if skeleton!=null:remove_child(skeleton);skeleton.free()
 skeleton=Skeleton2D.new();skeleton.name="Skeleton2D";add_child(skeleton)
 var raw_bones=_view.get("bones",{})
 if not raw_bones is Dictionary:return
 var foot:Vector2=foot_anchor()
 for key:String in BONE_PARENTS:
  if not raw_bones.has(key) or not raw_bones[key] is Dictionary or not _numeric_array(raw_bones[key].get("rest_px",[]),2):continue
  var rest:Vector2=_vector(raw_bones[key].get("rest_px",[]))
  _rests[key]=rest-foot
  var parent_name:String=str(BONE_PARENTS[key])
  var bone:=Bone2D.new();bone.name=key;bone.set_autocalculate_length_and_angle(false)
  bone.set_length(float(raw_bones[key].get("length_px",32)))
  if parent_name.is_empty():skeleton.add_child(bone);bone.position=rest-foot
  elif _bones.has(parent_name):_bones[parent_name].add_child(bone);bone.position=rest-_vector(raw_bones[parent_name].rest_px)
  else:bone.free();continue
  bone.rest=bone.transform;_bones[key]=bone
 if _available:
  var texture:Texture2D=_texture_for("D%d"%direction)
  for part:Dictionary in _view.get("parts",[]):
   var part_name:String=str(part.id)
   if bool(_view.get("soft_skinning",false)) and (part_name=="pelvis" or part_name.ends_with("_upper_arm") or part_name.ends_with("_forearm") or part_name.ends_with("_thigh") or part_name.ends_with("_shin")):
    _build_skin_mesh(part,texture)
    continue
   var raw:Array=part.region_px
   var sprite:=Sprite2D.new();sprite.name=str(part.id);sprite.texture=texture
   sprite.centered=false;sprite.region_enabled=true;sprite.region_rect=Rect2(raw[0],raw[1],raw[2],raw[3])
   var piece_scale:Vector2=_vector(part.get("scale",[1,1]),Vector2.ONE)
   sprite.region_filter_clip_enabled=true;sprite.scale=piece_scale
   # Sprite offset is evaluated before scale/rotation, keeping the piece pivot
   # on its bone even when an atlas part needs an authored axis correction.
   sprite.offset=-_vector(part.pivot_px)
   sprite.position=_vector(part.get("offset_px",[]))
   sprite.rotation=deg_to_rad(float(part.get("rotation_degrees",0)))
   sprite.z_index=int(part.get("z_index",0));sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
   _bones[str(part.bone)].add_child(sprite);_sprites.append(sprite)
   _part_nodes[str(part.id)]=sprite;_part_z[str(part.id)]=sprite.z_index
 queue_redraw()

func _skin_weights(part:Dictionary,at:Vector2,uv:Vector2,size:Vector2) -> Dictionary:
 var name:String=str(part.bone)
 if str(part.id)=="pelvis":
  var lower:float=smoothstep(.22,.95,uv.y/size.y)*.85
  var right:float=smoothstep(.40,.60,uv.x/size.x)
  return {"pelvis":1-lower,"left_thigh":lower*(1-right),"right_thigh":lower*right}
 var parent:String=str(BONE_PARENTS.get(name,""));var child:String=""
 for candidate:String in BONE_PARENTS:
  if str(BONE_PARENTS[candidate])==name:child=candidate;break
 var axis:Vector2=Vector2(_rests[child])-Vector2(_rests[name]) if not child.is_empty() else Vector2.DOWN*100
 var t:float=(at-Vector2(_rests[name])).dot(axis)/maxf(.01,axis.length_squared())
 var parent_weight:float=(1-smoothstep(-.18,.22,t)) if not parent.is_empty() else 0.0
 var child_weight:float=smoothstep(.78,1.22,t) if not child.is_empty() else 0.0
 var result:Dictionary={name:maxf(0,1-parent_weight-child_weight)}
 if not parent.is_empty():result[parent]=parent_weight
 if not child.is_empty():result[child]=child_weight
 return result

func _build_skin_mesh(part:Dictionary,texture:Texture2D) -> void:
 var region:Array=part.region_px;var size:=Vector2(region[2],region[3])
 var pivot:Vector2=_vector(part.pivot_px);var scale_px:Vector2=_vector(part.get("scale",[1,1]),Vector2.ONE)
 var angle:float=deg_to_rad(float(part.get("rotation_degrees",0)))
 var offset:Vector2=_vector(part.get("offset_px",[]));var origin:Vector2=_rests[str(part.bone)]
 var vertices:=PackedVector2Array();var uv:=PackedVector2Array();var weights:Array[Dictionary]=[]
 const COLS:int=5
 const ROWS:int=10
 for row in ROWS+1:
  for column in COLS+1:
   var pixel:=Vector2(size.x*column/COLS,size.y*row/ROWS)
   var at:Vector2=origin+((pixel-pivot)*scale_px).rotated(angle)+offset
   vertices.append(at);uv.append(Vector2(region[0],region[1])+pixel)
   weights.append(_skin_weights(part,at,pixel,size))
 var triangles:Array=[]
 for row in ROWS:
  for column in COLS:
   var first:int=row*(COLS+1)+column
   triangles.append(PackedInt32Array([first,first+1,first+COLS+2]))
   triangles.append(PackedInt32Array([first,first+COLS+2,first+COLS+1]))
 var mesh:=Polygon2D.new();mesh.name=str(part.id)+"_skin";mesh.texture=texture
 mesh.polygon=vertices;mesh.uv=uv;mesh.polygons=triangles;mesh.antialiased=true
 mesh.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;mesh.z_index=int(part.get("z_index",0))
 skeleton.add_child(mesh);mesh.skeleton=NodePath("..")
 var used:Dictionary={}
 for values:Dictionary in weights:
  for bone:String in values:used[bone]=true
 for bone:String in used:
  var values:=PackedFloat32Array()
  for vertex:Dictionary in weights:values.append(float(vertex.get(bone,0)))
  # Polygon2D bone paths are relative to its Skeleton2D, not the polygon.
  mesh.add_bone(skeleton.get_path_to(_bones[bone]),values)
 _meshes.append(mesh)
 _part_nodes[str(part.id)]=mesh;_part_z[str(part.id)]=mesh.z_index

func foot_anchor() -> Vector2:return _vector(_view.get("foot_anchor_px",rig_config.get("foot_anchor_px",[])))
func canvas_size() -> Vector2:return _vector(_view.get("canvas_px",rig_config.get("canvas_px",[1122,1402])))
func body_height() -> float:return float(_view.get("body_height_px",rig_config.get("body_height_px",1250)))

func _reset_rest() -> void:
 skeleton.transform=Transform2D.IDENTITY
 for bone:Bone2D in _bones.values():bone.apply_rest()
 for id:String in _part_nodes:_part_nodes[id].z_index=int(_part_z[id])

func bone_position(name:String) -> Vector2:
 if not _bones.has(name):return Vector2.INF
 return to_local(_bones[name].global_position)

func socket_position(name:String) -> Vector2:
 var sockets:Dictionary=_view.get("sockets",rig_config.get("sockets",{}))
 var spec:Dictionary=sockets.get(name,{"bone":name,"offset_px":[0,0]})
 var bone_name:String=str(spec.get("bone",name))
 if not _bones.has(bone_name):return Vector2.INF
 return to_local(_bones[bone_name].to_global(_vector(spec.get("offset_px",[]))))

func _set_canvas_rotation(name:String,angle:float) -> void:
 if _bones.has(name):_bones[name].global_rotation=global_rotation+angle

func _two_bone(upper:String,middle:String,end:String,target:Vector2,bend_hint:float=0.0) -> bool:
 if not _bones.has(upper) or not _bones.has(middle) or not _bones.has(end) or not target.is_finite():return false
 var root:Vector2=bone_position(upper)
 var first:Vector2=Vector2(_rests[middle])-Vector2(_rests[upper])
 var second:Vector2=Vector2(_rests[end])-Vector2(_rests[middle])
 var a:float=first.length();var b:float=second.length()
 if a<.001 or b<.001:return false
 var offset:Vector2=target-root
 var requested:float=offset.length();var distance:float=clampf(requested,absf(a-b)+.001,a+b-.001)
 if requested<.00001:offset=Vector2.DOWN
 var theta:float=offset.angle()
 var deviation:float=acos(clampf((a*a+distance*distance-b*b)/(2*a*distance),-1,1))
 var positive:Vector2=root+Vector2.RIGHT.rotated(theta+deviation)*a
 var negative:Vector2=root+Vector2.RIGHT.rotated(theta-deviation)*a
 # Preserve the authored bend side instead of flipping around a near-straight
 # limb when two equally close elbows exchange their distance to rest.
 if is_zero_approx(bend_hint):
  var rest_curve:float=first.cross(first+second)
  if absf(rest_curve)>.0001:bend_hint=-signf(rest_curve)
 var elbow:Vector2=positive if bend_hint>0 else negative if bend_hint<0 else positive if positive.distance_squared_to(bone_position(middle))<=negative.distance_squared_to(bone_position(middle)) else negative
 var reached:Vector2=root+offset.normalized()*distance
 _set_canvas_rotation(upper,(elbow-root).angle()-first.angle())
 _set_canvas_rotation(middle,(reached-elbow).angle()-second.angle())
 _set_canvas_rotation(end,0.0)
 var valid:bool=absf(requested-distance)<.02
 if not valid:clamped_targets.append(end)
 return valid

func _walk_target(side:String,phase:float,axis:Vector2,span:float,lift:float,stance:float,weight:float) -> Dictionary:
 var stride:float=fposmod(phase,1.0)
 var planted:bool=stride<stance
 var forward:float=0.0;var raise:float=0.0
 if planted:forward=lerpf(span*.5,-span*.5,stride/stance)
 else:
  var swing:float=(stride-stance)/(1.0-stance)
  var t2:float=swing*swing;var t3:float=t2*swing
  var tangent:float=-span*(1-stance)/stance
  forward=(2*t3-3*t2+1)*(-span*.5)+(t3-2*t2+swing)*tangent+(-2*t3+3*t2)*(span*.5)+(t3-t2)*tangent
  raise=pow(sin(swing*PI),2)*lift
 var foot:String=side+"_foot"
 var target:Vector2=Vector2(_rests[foot])+(axis*forward-Vector2(0,raise))*weight
 return {"phase":stride,"planted":planted,"target":target,"forward_px":forward*weight,"lift_px":raise*weight}

func _depth_hip_drop(side:String,pose:Dictionary,axis_per_m:Vector2) -> float:
 var unit:float=body_height()/1.75
 var upper:Vector2=_rests[side+"_thigh"];var middle:Vector2=_rests[side+"_shin"];var end:Vector2=_rests[side+"_foot"]
 var length:float=(upper.distance_to(middle)+middle.distance_to(end))*.995/unit
 var forward_m:float=float(pose.forward_px)/maxf(.01,axis_per_m.length())
 var lift_m:float=float(pose.lift_px)/unit
 var height_m:float=(end.y-upper.y)/unit
 return maxf(0,height_m-lift_m-sqrt(maxf(.001,length*length-forward_m*forward_m)))*unit

func _projected_segment(name:String,child:String,at:Vector2,child_at:Vector2) -> void:
 # A constant anatomical segment foreshortens in a depth-facing projection.
 # This affine basis preserves its painted width while mapping its long axis
 # to the projected joint pair; it is visual, never a gameplay bone length.
 var rest_axis:Vector2=Vector2(_rests[child])-Vector2(_rests[name])
 var projected_axis:Vector2=child_at-at
 var u:Vector2=rest_axis.normalized();var v:Vector2=u.orthogonal()
 var mapped_u:Vector2=projected_axis/maxf(.001,rest_axis.length())
 var mapped_v:Vector2=projected_axis.normalized().orthogonal()
 var bx:Vector2=mapped_u*u.x+mapped_v*v.x
 var by:Vector2=mapped_u*u.y+mapped_v*v.y
 _bones[name].global_transform=global_transform*Transform2D(bx,by,at)

func _depth_leg(side:String,pose:Dictionary,axis_per_m:Vector2) -> void:
 var upper_name:String=side+"_thigh";var middle_name:String=side+"_shin";var end_name:String=side+"_foot"
 var upper_rest:Vector2=_rests[upper_name];var middle_rest:Vector2=_rests[middle_name];var end_rest:Vector2=_rests[end_name]
 var upper_at:Vector2=bone_position(upper_name);var target:Vector2=pose.target
 var unit:float=body_height()/1.75
 var a:float=upper_rest.distance_to(middle_rest)/unit;var b:float=middle_rest.distance_to(end_rest)/unit
 var forward_m:float=float(pose.get("forward_px",0))/maxf(.01,axis_per_m.length())
 var root_m:=Vector2(0,(end_rest.y-upper_at.y)/unit)
 var foot_m:=Vector2(forward_m,float(pose.get("lift_px",0))/unit)
 var delta:Vector2=foot_m-root_m;var requested:float=delta.length()
 var distance:float=clampf(requested,absf(a-b)+.000001,a+b-.000001)
 var along:float=(a*a-b*b+distance*distance)/(2*maxf(.000001,distance))
 var offset:float=sqrt(maxf(0,a*a-along*along))
 var center:Vector2=root_m+delta.normalized()*along
 var first:Vector2=center+delta.normalized().orthogonal()*offset
 var second:Vector2=center-delta.normalized().orthogonal()*offset
 var knee_m:Vector2=first if first.x>second.x else second
 var knee_at:Vector2=upper_at+axis_per_m*knee_m.x+Vector2(lerpf(0,end_rest.x-upper_rest.x,a/(a+b)),(root_m.y-knee_m.y)*unit)
 _projected_segment(upper_name,middle_name,upper_at,knee_at)
 _projected_segment(middle_name,end_name,knee_at,target)
 _bones[end_name].global_transform=global_transform*Transform2D(0.0,target)
 if absf(requested-distance)>.0001:clamped_targets.append(end_name)
 foot_contacts[side]={"phase":pose.get("phase",0),"planted":pose.get("planted",true),"target":target,"actual":bone_position(end_name),"model_leg_lengths_m":[a,b],"projection":"anatomical leg plane to authored screen stride axis"}

func _required_hip_drop(side:String,pose:Dictionary) -> float:
 var upper:Vector2=_rests[side+"_thigh"];var middle:Vector2=_rests[side+"_shin"];var end:Vector2=_rests[side+"_foot"]
 var length:float=(upper.distance_to(middle)+middle.distance_to(end))*.995
 var delta:Vector2=Vector2(pose.target)-upper
 var vertical:float=sqrt(maxf(.001,length*length-delta.x*delta.x))
 return maxf(0,delta.y-vertical)

func _walk_leg(side:String,pose:Dictionary) -> void:
 var foot:String=side+"_foot";var target:Vector2=pose.target
 var bends:Dictionary=_view.get("knee_bend",{})
 _two_bone(side+"_thigh",side+"_shin",foot,target,float(bends.get(side,0)))
 foot_contacts[side]={"phase":pose.phase,"planted":pose.planted,"target":target,"actual":bone_position(foot)}

func _curve(keys:Array,progress:float) -> float:
 if keys.is_empty():return 0.0
 if progress<=float(keys[0][0]):return float(keys[0][1])
 for index in range(1,keys.size()):
  var left:Array=keys[index-1];var right:Array=keys[index]
  if progress<=float(right[0]):
   var ratio:float=(progress-float(left[0]))/maxf(.00001,float(right[0])-float(left[0]))
   return lerpf(float(left[1]),float(right[1]),smoothstep(0,1,ratio))
 return float(keys[-1][1])

func sample_pose(context:Dictionary) -> void:
 # A paused sample does not advance, reset or switch a posed direction.
 if bool(context.get("paused",false)) and not last_context.is_empty():return
 set_direction(int(context.get("direction",direction)))
 if _bones.size()!=BONE_PARENTS.size():return
 last_context=context.duplicate(true);foot_contacts.clear();clamped_targets.clear();gait_body_drop_px=0;_reset_rest()
 var state:String=str(context.get("state","idle"))
 var elapsed:float=maxf(0,float(context.get("elapsed",0)))
 var duration:float=maxf(.00001,float(context.get("duration",1)))
 var progress:float=clampf(float(context.get("progress",elapsed/duration)),0,1)
 var height:float=body_height()
 var moving:bool=bool(context.get("moving",true))
 var weight:float=clampf(float(context.get("locomotion_weight",1.0 if moving else 0.0)),0,1)
 if state=="walk" and weight>0:
  var stride_m:float=maxf(.1,float(context.get("stride_m",_view.get("stride_m",rig_config.get("stride_m",1.1)))))
  var phase:float=fposmod(float(context.get("travel_m",0))/stride_m,1.0)
  var stance:float=clampf(float(rig_config.get("stance_fraction",.6)),.51,.75)
  var axis:Vector2=_vector(context.get("ground_axis",[]),[Vector2.RIGHT,Vector2(-.47,-.88),Vector2.LEFT,Vector2(.47,.88)][direction]).normalized()
  var px_per_m:float=float(context.get("ground_px_per_m",height/136.5*96.0))
  var stride_axis:Vector2=_vector(context.get("stride_axis_px",[]))
  if stride_axis.length_squared()>.0001:axis=stride_axis.normalized();px_per_m=stride_axis.length()
  var span:float=stride_m*stance*px_per_m
  var drop:float=clampf(float(context.get("walk_pelvis_drop_fraction",_view.get("walk_pelvis_drop_fraction",rig_config.get("walk_pelvis_drop_fraction",.026)))),0,.15)
  var lift:float=height*float(_view.get("walk_lift_fraction",.025))
  var left:Dictionary=_walk_target("left",phase,axis,span,lift,stance,weight)
  var right:Dictionary=_walk_target("right",phase+.5,axis,span,lift,stance,weight)
  var depth_projection:bool=bool(_view.get("depth_projection",false))
  gait_body_drop_px=maxf(_depth_hip_drop("left",left,axis*px_per_m),_depth_hip_drop("right",right,axis*px_per_m)) if depth_projection else maxf(_required_hip_drop("left",left),_required_hip_drop("right",right)) if bool(_view.get("adaptive_pelvis",false)) else (height*drop+absf(sin(phase*TAU))*height*.006)*weight
  _bones.pelvis.position.y+=gait_body_drop_px
  if depth_projection:
   _depth_leg("left",left,axis*px_per_m);_depth_leg("right",right,axis*px_per_m)
  else:_walk_leg("left",left);_walk_leg("right",right)
  _bones.left_upper_arm.rotation=deg_to_rad(sin(phase*TAU)*8)*weight
  _bones.right_upper_arm.rotation=deg_to_rad(-sin(phase*TAU)*8)*weight
 elif state=="idle":
  _bones.chest.position.y-=sin(elapsed*TAU/3.2)*height*.0015*float(context.get("idle_weight",1))
 else:
  var tracks:Dictionary=rig_config.get("poses",{}).get(state,{})
  for name:String in tracks:
   if _bones.has(name):_bones[name].rotation=deg_to_rad(_curve(tracks[name],progress))
  if state in ["search_low","crouch"] or str(context.get("pose",""))=="low":
   # The action clock also owns entering and leaving the low pose; changing
   # the visual state must not instantly drop the body by a full crouch.
   # Interrupted actions may supply the provider's retained blend weight.
   var low_weight:float=clampf(float(context.get("crouch_weight",_curve([[0,0],[.18,1],[.82,1],[1,0]],progress))),0,1)
   _bones.pelvis.position.y+=height*float(_view.get("crouch_drop_fraction",.13))*low_weight
   _bones.chest.rotation=deg_to_rad(12 if direction in [0,3] else -12)*low_weight
   var bends:Dictionary=_view.get("knee_bend",{})
   for side:String in ["left","right"]:
    if bool(_view.get("depth_projection",false)):
     var axis:Vector2=_vector(context.get("stride_axis_px",[]),Vector2(-16,-56) if direction==1 else Vector2(16,56))
     if not context.has("stride_axis_px"):axis*=height/137.0
     _depth_leg(side,{"target":_rests[side+"_foot"]},axis)
    else:_two_bone(side+"_thigh",side+"_shin",side+"_foot",_rests[side+"_foot"],float(bends.get(side,0)))
 var targets:Dictionary=context.get("hand_targets",{})
 var sockets:Dictionary=_view.get("sockets",rig_config.get("sockets",{}))
 var root_angle:float=float(context.get("root_rotation",0.0))
 for side:String in ["left","right"]:
  var name:String=side+"_hand"
  if not targets.has(name):continue
  var target:Vector2=_vector(targets[name]).rotated(-root_angle)
  var socket:Dictionary=sockets.get(name,{})
  var offset:Vector2=_vector(socket.get("offset_px",[]))
  var hand_angles:Dictionary=context.get("hand_angles",{})
  var hand_angle:float=float(hand_angles.get(name,_bones[name].global_rotation-global_rotation))
  var bends:Dictionary=_view.get("elbow_bend",{})
  _two_bone(side+"_upper_arm",side+"_forearm",name,target-offset.rotated(hand_angle),float(bends.get(side,0)))
  _set_canvas_rotation(name,hand_angle)
  if _part_nodes.has(side+"_upper_arm"):_part_nodes[side+"_upper_arm"].z_index=11
  if _part_nodes.has(side+"_forearm"):_part_nodes[side+"_forearm"].z_index=12
  if _part_nodes.has(name):_part_nodes[name].z_index=13
 skeleton.rotation=root_angle
 queue_redraw()

func pose_snapshot() -> Dictionary:
 var result:Dictionary={"direction":direction,"available":_available,"bones":{},"feet":foot_contacts.duplicate(true),"clamped_targets":clamped_targets.duplicate(),"gait_body_drop_px":gait_body_drop_px,"action_uid":str(last_context.get("action_uid",""))}
 for key:String in _bones:result.bones[key]={"position":bone_position(key),"rotation":float(_bones[key].rotation)}
 return result

func _draw() -> void:
 if not debug_bones:return
 for key:String in _bones:
  var at:Vector2=bone_position(key);var parent:String=str(BONE_PARENTS[key])
  if _bones.has(parent):draw_line(bone_position(parent),at,Color("d0a765"),3,true)
  draw_circle(at,4,Color("d8d8d2"))
