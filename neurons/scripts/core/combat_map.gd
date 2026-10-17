extends RefCounted
## S1:P327–473. Existing cortical links, then the seven deep structures.
const Cortex=preload("res://scripts/core/cortex_map.gd")
const DEEP=["hippocampus","thalamus","cerebellum","hypothalamus","basal","amygdala","brainstem"]
const DEEP_NAMES={"hippocampus":"海马回廊","thalamus":"丘脑中继厅","cerebellum":"小脑折列室","hypothalamus":"下丘脑温控室","basal":"基底核选动环","amygdala":"杏仁核双室","brainstem":"脑干脉冲井","street_exit":"Street入口（后续开发边界）"}
const DEEP_GRAPH={"hippocampus":["verify","thalamus"],"thalamus":["hippocampus","cerebellum","hypothalamus","basal","amygdala","brainstem"],"cerebellum":["thalamus","amygdala"],"hypothalamus":["thalamus","basal"],"basal":["thalamus","hypothalamus"],"amygdala":["thalamus","cerebellum"],"brainstem":["thalamus","street_exit"]}
const SIZE=Vector2(11.2,7.6)

static func rooms() -> Array:return Cortex.ALL_ROOMS+DEEP
static func title(id:String) -> String:return str(Cortex.ROOM_NAMES.get(id,DEEP_NAMES.get(id,id)))
static func doors(id:String) -> Array:
 if DEEP_GRAPH.has(id):return DEEP_GRAPH[id].duplicate()
 var result:Array=Cortex.doors(id)
 if id=="verify":result[result.find("combat_exit")]="hippocampus"
 return result

static func doorway(room:String,to:String) -> Vector2:
 if Cortex.DOOR_POSITIONS.has(room):return Cortex.doorway(room,"combat_exit" if room=="verify" and to=="hippocampus" else to)*2.0
 var index:int=doors(room).find(to)
 if index<0:return Vector2(-1,-1)
 if room=="thalamus":return [Vector2(.48,1.8),Vector2(.48,5.7),Vector2(3.5,7.12),Vector2(7.7,7.12),Vector2(10.72,5.7),Vector2(10.72,1.8)][index]
 return Vector2(.48,3.8) if index==0 else Vector2(10.72,3.8)

static func next_room(from:String,to:String) -> String:
 if from==to:return from
 var pending:Array=[from];var seen:Dictionary={from:""}
 while not pending.is_empty():
  var current:String=str(pending.pop_front())
  for neighbor in doors(current):
   if neighbor=="street_exit" or seen.has(neighbor):continue
   seen[neighbor]=current
   if neighbor==to:
    var step:String=to
    while seen[step]!=from:step=str(seen[step])
    return step
   pending.append(neighbor)
 return ""

static func deep(id:String) -> bool:return id in DEEP
