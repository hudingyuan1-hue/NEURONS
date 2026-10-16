extends RefCounted
## Persistent facts for the implemented exploration slice. No textures here.
const AsylumMap=preload("res://scripts/core/asylum_map.gd")
const ROOM_POINTS={
 "bedroom":["床","床头柜","靠背椅","书桌","蓝色圆凳与纸箱","杂物箱","衣帽架","衣柜","五层书架","储物柜","立式风扇"],
 "ward":[],
 "lobby":["挂号导诊台","叫号屏控制盒","自助机出票槽","绿植底托","宣传架","饮水机下柜"],
 "clinic":["医生桌抽屉","储物柜","洗手池下柜","检查床床沿与床底","器械柜","壁架","垃圾桶","窗台"],
 "pharmacy":["取药柜台","冷藏药柜开放层","洗手池下柜","储物柜","药架","处方配药台","宣传架"],
 "office":["资料架","窗台","饮水机下柜","垃圾桶","小边柜","文件柜","办公桌①","打印机出纸托盘","洗手池下柜","储物柜","办公桌②"]}
const GRAPH={"ward":["lobby"],"lobby":["ward","clinic","pharmacy","office"],"clinic":["lobby"],"pharmacy":["lobby"],"office":["lobby"]}
var data:Dictionary={}

func _init() -> void:
 data={"level":1,"cycle":1,"attempts":{"1":1,"2":1,"3":1},"targets":[],"key_target":"","key_seen":false,"key_owner":"",
  "unlocked":[1],"rooms":{},"receipts":{},"exploration_boundary":false,"profile":{}}

func new_attempt(level:int,rng:RandomNumberGenerator) -> void:
 var candidates:Array=[]
 var rooms:Array=["bedroom"] if level==1 else ["lobby","clinic","pharmacy","office"] if level==2 else AsylumMap.POINTS.keys()
 for room in rooms:
  for index in range(point_names(level,room).size()):candidates.append("%s:%d"%[room,index])
 for i in range(candidates.size()-1,0,-1):
  var j:int=rng.randi_range(0,i)
  var temp=candidates[i]
  candidates[i]=candidates[j]
  candidates[j]=temp
 candidates.resize(10 if level==1 else 12 if level==2 else 14)
 data.level=level
 data.targets=candidates
 data.key_target=candidates[rng.randi_range(0,candidates.size()-1)]
 data.key_seen=false
 data.key_owner=data.key_target
 data.rooms={}
 data.exploration_boundary=false
 if not data.attempts.has(str(level)):data.attempts[str(level)]=1

static func point_names(level:int,room:String) -> Array:
 return AsylumMap.POINTS.get(room,[]) if level==3 else ROOM_POINTS.get(room,[])

func doors(room:String) -> Array:
 if int(data.level)==3:return AsylumMap.doors(room)
 var result:Array=GRAPH.get(room,[]).duplicate()
 if room=="lobby":result.append("stairs")
 return result

func has_key() -> bool:
 return data.key_owner=="hero"

func next_room(from:String,to:String) -> String:
 if int(data.level)==3:return AsylumMap.next_room(from,to)
 if from==to:return from
 var pending:Array=[from]
 var visited:Dictionary={from:""}
 while not pending.is_empty():
  var current:String=pending.pop_front()
  for neighbor in GRAPH.get(current,[]):
   if visited.has(neighbor):continue
   visited[neighbor]=current
   if neighbor==to:
    var step:String=to
    while visited[step]!=from:step=visited[step]
    return step
   pending.append(neighbor)
 return ""

