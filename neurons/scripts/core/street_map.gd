extends RefCounted
## S1:P476–503. Two single-mouth branches; no extra maps beyond the gate.
const ROOMS=["street_plaza","street_side","street_narrow","street_twisted","street_maintenance","street_node","street_end"]
const NAMES={"street_plaza":"初始广场","street_side":"侧室","street_narrow":"狭窄通道","street_twisted":"扭曲街道","street_maintenance":"维护通道","street_node":"异化节点","street_end":"出口","ending_gate":"终点门框"}
const GRAPH={"street_plaza":["street_narrow","street_side"],"street_side":["street_plaza"],"street_narrow":["street_plaza","street_twisted"],"street_twisted":["street_narrow","street_node","street_maintenance"],"street_maintenance":["street_twisted"],"street_node":["street_twisted","street_end"],"street_end":["street_node","ending_gate"]}
const SIZES={"street_plaza":Vector2(16,11),"street_side":Vector2(10,9),"street_narrow":Vector2(18,8),"street_twisted":Vector2(20,12),"street_maintenance":Vector2(12,8),"street_node":Vector2(17,12),"street_end":Vector2(16,11)}
static func rooms() -> Array:return ROOMS.duplicate()
static func title(id:String) -> String:return str(NAMES.get(id,id))
static func doors(id:String) -> Array:return GRAPH.get(id,[]).duplicate()
static func deep(_id:String) -> bool:return false
static func doorway(room:String,to:String) -> Vector2:
 if to not in GRAPH.get(room,[]):return Vector2(-1,-1)
 var size:Vector2=SIZES[room]
 if to in ["street_side","street_maintenance"]:return Vector2(size.x*.35,.48)
 var west:bool=to=="street_plaza" or to=="street_narrow" and room=="street_twisted" or to=="street_twisted" and room in ["street_node","street_maintenance"] or to=="street_node" and room=="street_end"
 return Vector2(.48,size.y*.5) if west else Vector2(size.x-.48,size.y*.5)
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
