extends RefCounted
## L3 topology, not an extra hospital floor. S1:P94–146/P155–216;
## S3:P1055–1059; S4:T6R4/T24R4. One logical metre uses RoomLayout.project().
## The five inherited rooms have no key-search candidates. Stable indices below
## are the original 1/4/8/6/4/7/7/8 order and must not follow drawing order.
const POINTS={
 "ward":[], "lobby":[], "clinic":[], "pharmacy":[], "office":[],
 "stairs":["平台窗台"],
 "corridor":["护士站办公桌","花坛","候诊椅组","桌旁柜子"],
 "activity":["电视柜","窗①","沙发组","茶几","活动桌","绿植","窗②","书架"],
 "group_therapy":["储物柜","窗①","团体座椅组","绿植","窗②","白板"],
 "quiet":["固定储物柜","普通储物柜","软垫休息椅","高窗"],
 "bathroom":["洗手池①","洗手池②","公共地漏","淋浴间①","淋浴间②","高窗","马桶"],
 "double_ward":["衣柜","储物柜","单人床①","单人床②","床头柜①","床头柜②","窗"],
 "workshop":["操作桌①","操作桌②","矮柜","洗手池","窗","作品展示板","材料柜","材料架"]
}
const UPPER_ROOMS=["stairs","corridor","activity","group_therapy","quiet","bathroom","double_ward","workshop"]
const ROOM_NAMES={
 "ward":"单人病房", "lobby":"接待登记区", "clinic":"精神科接诊室",
 "pharmacy":"配药治疗室", "office":"护士站与医护办公室", "stairs":"楼梯",
 "corridor":"病区走廊及护士站", "activity":"公共活动室", "group_therapy":"团体治疗室",
 "quiet":"安静室", "bathroom":"卫生间与淋浴区", "double_ward":"双人病房", "workshop":"作业康复室"
}
const GRAPH={
 "ward":["lobby"], "lobby":["ward","clinic","pharmacy","office","stairs"],
 "clinic":["lobby"], "pharmacy":["lobby"], "office":["lobby"],
 "stairs":["lobby","corridor","cortex_exit"],
 "corridor":["stairs","activity","group_therapy","quiet","bathroom","double_ward","workshop"],
 "activity":["corridor"], "group_therapy":["corridor"], "quiet":["corridor"],
 "bathroom":["corridor"], "double_ward":["corridor"], "workshop":["corridor"]
}

static func candidates() -> Array:
 var result:Array=[]
 for room in UPPER_ROOMS:
  for index in range(POINTS[room].size()):result.append("%s:%d"%[room,index])
 return result

static func doors(room:String) -> Array:
 return GRAPH.get(room,[]).duplicate()

static func doorway(room:String,to:String) -> Vector2:
 var adjacent:Array=GRAPH.get(room,[])
 if not to in adjacent:return Vector2(-1,-1)
 if room=="ward":return Vector2(4.6,0.22)
 if room=="lobby":return Vector2(1.25+adjacent.find(to)*0.78,0.24)
 if room in ["clinic","pharmacy","office"]:return Vector2(1.25,0.24)
 if room=="stairs":return {"lobby":Vector2(1.25,0.24),"corridor":Vector2(2.8,0.24),"cortex_exit":Vector2(4.37,0.24)}[to]
 if room=="corridor":return Vector2(0.55+adjacent.find(to)*0.7,0.24)
 return Vector2(2.8,0.24)

static func next_room(from:String,to:String) -> String:
 if from==to:return from
 if not GRAPH.has(from):return ""
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
