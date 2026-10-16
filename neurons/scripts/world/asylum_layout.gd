extends "res://scripts/world/room_layout.gd"
## L3 upper-floor collision placeholders; no runtime art or narrative rewards.
## S1:P133–216 gives topology/objects; S3:T29/T34 gives actions and original
## completion-only lines; S4:T6R4 gives six seconds per successful search.
const AsylumMap=preload("res://scripts/core/asylum_map.gd")
var room_id:String="stairs"

const ACTIONS={
 "stairs":[["查看窗台、窗框下沿及可触及缝隙","窗沿没有。","站稳点。","high"]],
 "corridor":[
  ["查看抽屉、桌面夹层与文件夹下方","这里只有资料。","钥匙不在里面。","middle"],
  ["查看花坛沿口与外侧底部","边上没有。","不用把土全翻了。","low"],
  ["检查座面下方、椅缝及同组椅脚旁","这排下面都没有。","椅缝里也没有。","low"],
  ["逐格开柜，拨开可移动物件","柜子里也没有。","关上再走。","middle"]],
 "activity":[
  ["检查柜格、抽屉与电视底座旁","只有这些杂物。","不是钥匙。","middle"],
  ["查看窗台与下框","这边窗台没有。","看看另一边。","high"],
  ["查看坐垫缝、扶手旁与可触及底部","缝里也没有。","找完把垫子放好。","low"],
  ["检查台面、下层与物件底部","茶几下面没有。","就剩这些纸。","low"],
  ["查看桌面物件之间、桌沿与下方","这里没找到。","桌底也看过了。","middle"],
  ["检查盆沿、底托及盆后地面","盆后面也没有。","下一处。","low"],
  ["查看另一处窗台和框沿","这扇下面也没有。","两边都找过了。","high"],
  ["查看可触及书缝、书后及层板","书后面没有。","别把整架推倒了。","middle"]],
 "group_therapy":[
  ["翻查柜格与盒子后方","柜里没有钥匙。","都是这里用的东西。","middle"],
  ["检查窗沿、窗框下缝","这边没有。","看清就行。","high"],
  ["查看座面下方与固定椅之间的缝隙","椅子下面也没有。","不用把它搬起来。","low"],
  ["查看盆边、底托与后方","这里只有灰。","起来吧。","low"],
  ["查看另一扇窗的可触及边沿","这里也空着。","换一处。","high"],
  ["查看托槽及附带资料夹","槽里没有钥匙。","夹子下面呢？","high"]],
 "quiet":[
  ["打开可开启柜格，查看格底与物件后方","格子里没有。","后面也摸过了。","middle"],
  ["逐层检查柜格及底部","这一层也没有。","下面再看一下。","middle"],
  ["掀起活动软垫，检查缝隙和座面下方","下面有抓痕，没有钥匙。","看清就放回去。","low"],
  ["站立抬手检查可触及下沿","窗沿没有。","不用往上爬。","high"]],
 "bathroom":[
  ["蹲下查看池下、管道旁及底部","这边下面没有。","别碰到管子。","low"],
  ["查看另一池下的独立空间","这边也没有。","两个都找过了。","low"],
  ["查看格栅与可触及边缝","缝里没有钥匙。","看清卡住的是什么。","low"],
  ["查看置物处、地面及本隔间小地漏","这里没有。","地上的也看过了。","low"],
  ["检查另一间置物处及小地漏","这一间也没有。","往门边退一点。","low"],
  ["查看可触及的窗下沿及框缝","窗框下面没有。","别踩那些湿的地方。","high"],
  ["查看水箱可开启处及底座外侧","这里也没找到。","找完把盖子放好。","low"]],
 "double_ward":[
  ["分格翻查衣物间与柜底","衣服之间没有。","别混到另一边去。","middle"],
  ["检查柜格、盒后与底层","柜里没有钥匙。","柜门别碰到旁边的人。","middle"],
  ["掀被角，查看床沿与可触及床底","这张床没有。","下面也看一下。","low"],
  ["检查平整被褥、床沿与床底","铺得这么整齐，也没有。","找完放回原样。","low"],
  ["查看对应台面与抽屉","抽屉里没有。","床号先对清楚。","middle"],
  ["查看另一柜台面及抽屉夹层","这边也没找到。","这是另一人的柜子。","middle"],
  ["查看窗沿、下框及可触及缝隙","窗边没有。","再看别处。","high"]],
 "workshop":[
  ["查看纸张、绘画工具之间与桌下","纸下面没有钥匙。","别把画揉坏了。","middle"],
  ["检查半成品旁、托盘及桌沿下方","盒子旁边也没有。","没贴完的先放回去。","middle"],
  ["查看柜格、抽屉与底层","矮柜里没有。","里面找完了。","low"],
  ["查看池下及管道旁","下面没有。","起来吧。","low"],
  ["查看窗台与框沿","窗台也没有。","下一处。","high"],
  ["查看托架、可接触背面与资料夹","后面不是钥匙，是标签。","先看清写的什么。","high"],
  ["只检查未上锁取料抽屉及开放格","这一格没有钥匙。","手先收回来。","middle"],
  ["查看纸料、标签卷之间及层板","材料后面也没有。","别把整叠弄散了。","middle"]]
}

func _init(room:String="stairs") -> void:
 room_id=room
 furniture=[]
 movable_blockers.clear()
 match room:
  "stairs":
   add_item(Rect2(0.3,2.95,1.35,0.3),Vector2(1.0,2.65),"window",41.0)
  "corridor":
   add_item(Rect2(0.2,1.4,1.35,0.6),Vector2(1.0,2.25),"desk")
   add_item(Rect2(0.2,2.95,0.65,0.6),Vector2(1.12,3.15),"plant",24.0)
   add_item(Rect2(2.0,2.95,1.5,0.45),Vector2(2.8,2.65),"chairs",18.0)
   add_item(Rect2(4.7,2.4,0.6,1.1),Vector2(4.4,2.9),"drawer",35.0)
  "activity":
   add_item(Rect2(0.2,0.85,1.15,0.4),Vector2(1.63,1.0),"drawer",35.0)
   add_item(Rect2(0.2,1.6,0.25,0.6),Vector2(0.75,1.9),"window",43.0)
   add_item(Rect2(0.2,2.7,1.65,0.6),Vector2(1.0,2.4),"sofa",23.0)
   add_item(Rect2(2.15,2.75,0.85,0.55),Vector2(2.55,2.4),"table",18.0)
   add_item(Rect2(3.55,2.65,1.3,0.6),Vector2(4.1,2.35),"desk")
   add_item(Rect2(4.8,1.85,0.45,0.45),Vector2(4.5,2.05),"plant",37.0)
   add_item(Rect2(5.05,0.9,0.3,0.6),Vector2(4.75,1.2),"window",43.0)
   add_item(Rect2(3.65,0.6,1.25,0.4),Vector2(4.25,1.3),"books",58.0)
  "group_therapy":
   add_item(Rect2(0.2,0.7,0.6,1.0),Vector2(1.08,1.15),"drawer",48.0)
   add_item(Rect2(0.2,2.8,0.25,0.55),Vector2(0.75,3.05),"window",43.0)
   add_item(Rect2(1.7,1.3,2.2,1.75),Vector2(2.8,1.8),"chairs",18.0)
   furniture[-1]["collision_rects"]=[Rect2(1.7,1.65,0.35,1.0),Rect2(3.55,1.65,0.35,1.0),Rect2(2.05,2.72,1.5,0.33),Rect2(1.9,1.3,0.5,0.33),Rect2(3.2,1.3,0.5,0.33)]
   add_item(Rect2(4.75,2.9,0.5,0.5),Vector2(4.45,3.15),"plant",37.0)
   add_item(Rect2(5.05,1.8,0.3,0.65),Vector2(4.75,2.05),"window",43.0)
   add_item(Rect2(4.3,0.65,0.9,0.25),Vector2(4.75,1.18),"board",54.0)
  "quiet":
   add_item(Rect2(0.25,0.85,0.65,1.1),Vector2(1.2,1.4),"drawer",49.0)
   add_item(Rect2(4.7,0.85,0.65,1.1),Vector2(4.4,1.4),"drawer",49.0)
   add_item(Rect2(0.6,2.9,1.3,0.55),Vector2(1.2,2.6),"chair",23.0)
   add_item(Rect2(4.1,3.15,1.1,0.25),Vector2(4.65,2.85),"window",54.0)
  "bathroom":
   add_item(Rect2(0.25,0.8,0.65,0.55),Vector2(1.2,1.1),"sink",30.0)
   add_item(Rect2(0.25,1.8,0.65,0.55),Vector2(1.2,2.05),"sink",30.0)
   add_item(Rect2(2.25,1.65,0.2,0.2),Vector2(2.75,1.75),"drain",1.0)
   furniture[-1]["collision_rects"]=[]
   add_item(Rect2(3.65,1.4,1.15,0.55),Vector2(4.2,1.1),"shower",42.0)
   add_item(Rect2(3.65,2.8,1.15,0.55),Vector2(4.2,2.5),"shower",42.0)
   add_item(Rect2(0.25,3.2,1.1,0.25),Vector2(0.8,2.9),"window",54.0)
   add_item(Rect2(2.1,2.9,0.65,0.55),Vector2(2.4,2.6),"toilet",28.0)
  "double_ward":
   add_item(Rect2(0.2,0.7,0.65,0.7),Vector2(1.15,1.05),"wardrobe",65.0)
   add_item(Rect2(4.75,0.7,0.65,0.7),Vector2(4.45,1.05),"drawer",43.0)
   add_item(Rect2(0.3,1.8,1.8,0.9),Vector2(2.4,2.25),"bed",27.0)
   add_item(Rect2(3.5,1.8,1.8,0.9),Vector2(3.2,2.25),"bed",27.0)
   add_item(Rect2(0.35,3.0,0.55,0.5),Vector2(1.2,3.2),"drawer",24.0)
   add_item(Rect2(4.7,3.0,0.55,0.5),Vector2(4.4,3.2),"drawer",24.0)
   add_item(Rect2(2.2,3.15,1.2,0.25),Vector2(2.8,2.85),"window",43.0)
  "workshop":
   add_item(Rect2(0.25,1.4,1.45,0.7),Vector2(1.2,1.1),"desk")
   add_item(Rect2(3.9,1.4,1.45,0.7),Vector2(4.6,1.1),"desk")
   add_item(Rect2(0.25,2.85,0.65,0.55),Vector2(1.2,3.1),"drawer",20.0)
   add_item(Rect2(0.25,0.55,0.65,0.5),Vector2(1.2,0.8),"sink",30.0)
   add_item(Rect2(1.9,3.2,0.9,0.25),Vector2(2.35,2.9),"window",43.0)
   add_item(Rect2(3.1,3.15,1.0,0.25),Vector2(3.6,2.85),"board",48.0)
   add_item(Rect2(4.7,2.85,0.65,0.65),Vector2(4.4,3.15),"drawer",46.0)
   add_item(Rect2(4.75,0.55,0.55,0.5),Vector2(4.45,0.8),"rack",49.0)
 super._init()

func add_item(rect:Rect2,at:Vector2,kind:String,height:float=28.0) -> void:
 var index:int=furniture.size()
 var spec:Array=ACTIONS[room_id][index]
 var table:String="T29R%d"%(2+index) if room_id=="stairs" else ""
 if room_id=="corridor":table="T29R%d"%(3+index)
 elif room_id=="activity":table="T29R%d"%(7+index)
 elif room_id=="group_therapy":table="T29R%d"%(15+index)
 elif room_id=="quiet":table="T34R%d"%(2+index)
 elif room_id=="bathroom":table="T34R%d"%(6+index)
 elif room_id=="double_ward":table="T34R%d"%(13+index)
 elif room_id=="workshop":table="T34R%d"%(20+index)
 furniture.append({"id":"%s:%d"%[room_id,index],"name":AsylumMap.POINTS[room_id][index],"rect":rect,"at":at,
  "height":height,"color":Color("718482") if room_id in ["stairs","corridor","quiet","bathroom"] else Color("8b8c7f"),"kind":kind,
  "data":{"action":spec[0],"failure_hero":spec[1],"failure_player":spec[2],"pose":spec[3],"search_seconds":6.0,"source":"S3:"+table,
   "completion_lines_only":true,"rest_point":false}})
 # S3:P1052: an unseen scratch/label cannot leak through a result line.
 if room_id=="quiet" and index==2 or room_id=="workshop" and index==5:
  furniture[-1].data["failure_requires_observation"]=true
  furniture[-1].data["failure_unobserved"]="这里没有钥匙。"
 if room_id=="double_ward" and index in [2,3,4,5]:
  furniture[-1].data["bed_slot"]=1 if index in [2,4] else 2

func collision_rects(item:Dictionary) -> Array:
 return item.get("collision_rects",[item.rect])

func walkable(p:Vector2,radius:float=RADIUS) -> bool:
 if not Rect2(Vector2(radius,radius),SIZE-Vector2.ONE*radius*2).has_point(p):return false
 for item in furniture:
  for rect in collision_rects(item):
   if (rect as Rect2).grow(radius).has_point(p):return false
 for rect in movable_blockers:
  if rect.grow(radius).has_point(p):return false
 return true

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 var steps:int=maxi(2,ceili(a.distance_to(b)/0.03))
 for i in range(steps+1):
  if not walkable(a.lerp(b,float(i)/steps),radius):return false
 return true

func geometry_issues() -> Array:
 ## Small executable diagnostic for integration tests. Checks real grid paths
 ## and every movement segment, rather than treating an image as navigation.
 var issues:Array=[]
 var adjacent:Array=AsylumMap.doors(room_id)
 for target in adjacent:
  var origin:Vector2=AsylumMap.doorway(room_id,str(target))
  if not walkable(origin):issues.append("blocked doorway %s -> %s"%[room_id,target])
  for item in furniture:
   var route:PackedVector2Array=path(origin,item.at)
   if route.is_empty():
    issues.append("no route %s -> %s"%[target,item.id])
    continue
   var previous:Vector2=origin
   for step in route:
    if not clear_segment(previous,step,RADIUS):issues.append("blocked segment %s -> %s"%[target,item.id])
    previous=step
 return issues
