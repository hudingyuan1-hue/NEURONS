extends RefCounted
## L4 source topology: S1:P220–323; S3:P1280–1284; S4:T6R5.
## Local metre coordinates are a 2D implementation choice, not new room links.
const FIRST_ROOMS=["atrium","memory","visual","decision","body"]
const SECOND_ROOMS=["bridge","rhythm","index","switch","verify","identity"]
const ALL_ROOMS=FIRST_ROOMS+SECOND_ROOMS
const SPAWN=Vector2(0.95,2.9)
const SEARCH_SECONDS=7.0
const POINTS={
 "atrium":["皮层核心","脑回墙体","脑沟通道"],
 "memory":["病历架","查阅桌","地毯陈设组","旧电视","录音机","照片墙","档案柜"],
 "visual":["旧电视","影像控制台","影像档案柜","弧形屏基座","观影座椅组","杂物堆"],
 "decision":["病历档案柜","资料终端","行动指令板","决策会议桌","绿植","路线规划板","记录仪器"],
 "body":["姿态检测屏底座","观察镜框","身体定位示意板","肢体模型区","身体感知检查台","触觉测试台","器械柜","身体映射区边缘凹槽"],
 "bridge":["中枢连接控制台","左侧检测终端","右侧检测终端","维护设备柜"],
 "rhythm":["脉冲检测仪","神经纤维束","接驳节点","线路维护柜"],
 "index":["档案推车","查询工作台","档案柜组","索引终端","维护储物柜","身份档案显示屏底座"],
 "switch":["切换控制台","信号检测屏底座","线路维护柜"],
 "verify":["身份识别终端","核验控制台","等候长椅组","门禁面板","维护终端","身份信息显示屏底座","资料柜"],
 "identity":["记录终端①","核验台①","双面身份镜","核验台②","编号档案柜①","编号档案柜②","记录终端②"],
}
const ROOM_NAMES={
 "atrium":"褶皱中庭",
 "memory":"记忆档案室",
 "visual":"视觉影像室",
 "decision":"意象决策室",
 "body":"身体感知室",
 "bridge":"胼胝桥",
 "rhythm":"节律支路",
 "index":"索引档案室",
 "switch":"切换分岔路",
 "verify":"核验出口",
 "identity":"身份核查室",
}
const GRAPH={
 "atrium":["memory","visual","decision","body"],
 "memory":["atrium","visual"],
 "visual":["atrium","memory"],
 "decision":["atrium","bridge"],
 "body":["atrium"],
 "bridge":["decision","index","rhythm","switch"],
 "rhythm":["bridge","identity"],
 "index":["bridge","switch"],
 "switch":["index","bridge","verify"],
 "verify":["switch","identity","combat_exit"],
 "identity":["rhythm","verify"],
}
const DOOR_POSITIONS={
 "atrium":{"memory":Vector2(0.24,1.1),"visual":Vector2(5.36,1.1),"decision":Vector2(2.8,0.24),"body":Vector2(2.8,3.56)},
 "memory":{"atrium":Vector2(5.36,2.8),"visual":Vector2(2.8,0.24)},
 "visual":{"atrium":Vector2(0.24,2.8),"memory":Vector2(2.8,0.24)},
 "decision":{"atrium":Vector2(2.8,3.56),"bridge":Vector2(2.8,0.24)},
 "body":{"atrium":Vector2(2.8,0.24)},
 "bridge":{"decision":Vector2(0.9,0.24),"index":Vector2(5.36,1.0),"rhythm":Vector2(2.8,3.56),"switch":Vector2(0.24,1.0)},
 "rhythm":{"bridge":Vector2(0.85,0.24),"identity":Vector2(5.36,2.9)},
 "index":{"bridge":Vector2(1.1,0.24),"switch":Vector2(4.5,3.56)},
 "switch":{"index":Vector2(0.24,1.0),"bridge":Vector2(2.8,0.24),"verify":Vector2(5.36,2.9)},
 "verify":{"switch":Vector2(0.24,2.8),"identity":Vector2(5.36,2.8),"combat_exit":Vector2(2.8,0.24)},
 "identity":{"rhythm":Vector2(0.24,1.0),"verify":Vector2(5.36,1.0)},
}
static func candidates(floor_number:int=0) -> Array:
 var result:Array=[]
 var rooms:Array=FIRST_ROOMS if floor_number==1 else SECOND_ROOMS if floor_number==2 else ALL_ROOMS
 for room in rooms:
  for index in range(POINTS[room].size()):result.append("%s:%d"%[room,index])
 return result

static func doors(room:String) -> Array:
 return GRAPH.get(room,[]).duplicate()

static func doorway(room:String,to:String) -> Vector2:
 return DOOR_POSITIONS.get(room,{}).get(to,Vector2(-1,-1))

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
