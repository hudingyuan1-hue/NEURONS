extends RefCounted
## Visual configuration only: never accesses rules, navigation, ownership or clocks.
var presets:Dictionary={}
var current:Dictionary={}
var active_set:String=""
var textures:Dictionary={}
var errors:Array[String]=[]

func _init() -> void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation.json"))
 if data is Dictionary:
  presets=data.get("sets",{})
  select_set(str(data.get("default","a")))

func select_set(id:String) -> bool:
 if not presets.has(id):return false
 var proposed:Dictionary=presets[id].duplicate(true)
 if not proposed.has("CHR_MAIN") or not proposed.has("ENV_BEDSIDE"):
  errors.append("Required stable ID missing: CHR_MAIN or ENV_BEDSIDE")
  return false
 var candidate:Dictionary={}
 for asset_id in proposed:
  var spec:Dictionary=proposed[asset_id]
  for field in ["texture","body","drawer","front","tray","book","clock"]:
   if not spec.has(field):continue
   var path:String=spec[field]
   if not ResourceLoader.exists(path):
    errors.append("%s missing %s"%[asset_id,path])
    return false
   var tex=load(path)
   if not tex is Texture2D:return false
   if asset_id=="CHR_MAIN":
    var expected:=Vector2i(int(spec.cell[0])*int(spec.directions)*int(spec.frames),int(spec.cell[1])*spec.states.size())
    if tex.get_size()!=Vector2(expected):
     errors.append("CHR_MAIN atlas expected %s, got %s"%[expected,tex.get_size()])
     return false
   else:
    var dimensions:Array=spec.get("tray_size",spec.canvas) if field=="tray" else spec.canvas
    if tex.get_size()!=Vector2(float(dimensions[0]),float(dimensions[1])):
     errors.append("ENV_BEDSIDE canvas incompatible: %s"%path)
     return false
   candidate[path]=tex
  for state in spec.get("clips",{}):
   var clip:Dictionary=spec.clips[state]
   if not clip.has("frames") or int(clip.frames)<=0 or float(clip.get("frame_seconds",0.16))<=0:
    errors.append("CHR_MAIN %s invalid frame count or duration"%state)
    return false
   var path:String=str(clip.get("texture",""))
   if int(clip.get("directions",4))!=4 or not ResourceLoader.exists(path):
    errors.append("CHR_MAIN %s clip requires four directions and a valid texture"%state)
    return false
   var tex=load(path)
   if not tex is Texture2D or tex.get_size()!=Vector2(float(spec.cell[0])*int(clip.get("frames",1)),float(spec.cell[1])*4):
    errors.append("CHR_MAIN %s sheet incompatible: expected frames columns, four direction rows"%state)
    return false
   candidate[path]=tex
 current=proposed
 textures=candidate
 active_set=id
 return true

func actor_frame(state:String,facing:Vector2,phase:float) -> Dictionary:
 var spec:Dictionary=current.CHR_MAIN
 var direction:int=0 if absf(facing.x)>=absf(facing.y) else (1 if facing.y<0 else 3)
 if absf(facing.x)>=absf(facing.y) and facing.x<0:direction=2
 var row:int=spec.states.find(state)
 if row<0:row=0
 var index:int=maxi(0,int(phase/float(spec.frame_seconds)))
 var looping:bool=state in ["idle","walk"]
 var frame:int=index%int(spec.frames) if looping else mini(index,int(spec.frames)-1)
 var cell:=Vector2(float(spec.cell[0]),float(spec.cell[1]))
 if spec.get("clips",{}).has(state):
  var clip:Dictionary=spec.clips[state]
  var clip_index:int=maxi(0,int(phase/float(clip.get("frame_seconds",0.16))))
  clip_index=clip_index%int(clip.frames) if bool(clip.get("loop",looping)) else mini(clip_index,int(clip.frames)-1)
  return {"texture":textures[clip.texture],"source":Rect2(Vector2(clip_index*cell.x,direction*cell.y),cell),"size":cell,"foot":Vector2(float(spec.foot[0]),float(spec.foot[1]))}
 return {"texture":textures[spec.texture],"source":Rect2(Vector2((direction*int(spec.frames)+frame)*cell.x,row*cell.y),cell),
  "size":cell,"foot":Vector2(float(spec.foot[0]),float(spec.foot[1]))}

func furniture() -> Dictionary:
 return current.ENV_BEDSIDE

func texture(path:String) -> Texture2D:
 return textures.get(path)
