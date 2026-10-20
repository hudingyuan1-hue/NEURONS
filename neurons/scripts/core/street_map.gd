extends RefCounted
## S1:P476–503. Two single-mouth branches; no extra maps beyond the gate.
const ROOMS=["street_plaza","street_side","street_narrow","street_twisted","street_maintenance","street_node","street_end"]
const NAMES={"street_plaza":"初始广场","street_side":"侧室","street_narrow":"狭窄通道","street_twisted":"扭曲街道","street_maintenance":"维护通道","street_node":"异化节点","street_end":"出口","ending_gate":"终点门框"}
const GRAPH={"street_plaza":["street_narrow","street_side"],"street_side":["street_plaza"],"street_narrow":["street_plaza","street_twisted"],"street_twisted":["street_narrow","street_node","street_maintenance"],"street_maintenance":["street_twisted"],"street_node":["street_twisted","street_end"],"street_end":["street_node","ending_gate"]}
const SIZES={"street_plaza":Vector2(16,11),"street_side":Vector2(7,13),"street_narrow":Vector2(18,8),"street_twisted":Vector2(20,12),"street_maintenance":Vector2(12,8),"street_node":Vector2(17,12),"street_end":Vector2(16,11)}
const SpatialRevision=preload("res://scripts/world/spatial_revision.gd")
static func _space(room:String,revision:int=SpatialRevision.CURRENT) -> Dictionary:
 return SpatialRevision.document("street_spaces.json",revision).rooms.get(room,{})
static func rooms() -> Array:return ROOMS.duplicate()
static func title(id:String) -> String:return str(NAMES.get(id,id))
static func doors(id:String) -> Array:return GRAPH.get(id,[]).duplicate()
static func deep(_id:String) -> bool:return false
static func doorway(room:String,to:String,revision:int=SpatialRevision.CURRENT) -> Vector2:
 if to not in GRAPH.get(room,[]):return Vector2(-1,-1)
 for entry:Dictionary in _space(room,revision).get("portals",[]):
  if str(entry.toward)==to:return Vector2(float(entry.at[0]),float(entry.at[1]))
 var dimensions:Array=_space(room,revision).get("size_m",[SIZES[room].x,SIZES[room].y])
 var size:=Vector2(float(dimensions[0]),float(dimensions[1]))
 if to in ["street_side","street_maintenance"]:return Vector2(size.x*.35,.48)
 var west:bool=to=="street_plaza" or to=="street_narrow" and room=="street_twisted" or to=="street_twisted" and room in ["street_node","street_maintenance"] or to=="street_node" and room=="street_end"
 return Vector2(.48,size.y*.5) if west else Vector2(size.x-.48,size.y*.5)
static func doorway_spec(room:String,to:String,revision:int=SpatialRevision.CURRENT) -> Dictionary:
 if to not in GRAPH.get(room,[]):return {}
 for entry:Dictionary in _space(room,revision).get("portals",[]):
  if str(entry.toward)!=to:continue
  var result:Dictionary=entry.duplicate(true)
  for field:String in ["at","wall_point","threshold","landing","inward"]:
   result[field]=Vector2(float(entry[field][0]),float(entry[field][1]))
  return result
 var at:Vector2=doorway(room,to,revision)
 if at.x<0:return {}
 var dimensions:Array=_space(room,revision).get("size_m",[SIZES[room].x,SIZES[room].y])
 var size:=Vector2(float(dimensions[0]),float(dimensions[1]))
 var inward:Vector2=Vector2.RIGHT if at.x<1 else Vector2.LEFT if at.x>size.x-1 else Vector2.DOWN
 var wall:String="west" if inward==Vector2.RIGHT else "east" if inward==Vector2.LEFT else "north"
 var on_wall:Vector2=Vector2(0,at.y) if wall=="west" else Vector2(size.x,at.y) if wall=="east" else Vector2(at.x,0)
 return {"at":at,"wall_point":on_wall,"threshold":at-inward*.23,"landing":at+inward*.38,"inward":inward,"toward":to,"width_m":1.4,"height_m":2.2,"wall":wall}
static func next_room(from:String,to:String) -> String:
 var queue:Array=[from];var seen:Dictionary={from:""}
 while not queue.is_empty():
  var current:String=str(queue.pop_front())
  for neighbor in doors(current):
   if neighbor=="ending_gate" or seen.has(neighbor):continue
   seen[neighbor]=current
   if neighbor==to:
    var step:String=to
    while seen[step]!=from:step=str(seen[step])
    return step
   queue.append(neighbor)
 return ""
