extends "res://scripts/world/room_layout.gd"
## Pure 2D, fixed metre footprints. Art replacement does not alter this topology.
## Search names/actions/completion lines: exact S3:T35–39/T41–46; seven seconds S4:T6R5.
## No observation, event, consent, reward, healing or rest is inferred by this layout.
const CortexMap=preload("res://scripts/core/cortex_map.gd")
const NeuralDisplay=preload("res://scripts/world/spatial_presentation.gd")
const SpatialGeometry=preload("res://scripts/world/spatial_geometry.gd")
const SpatialRevision=preload("res://scripts/world/spatial_revision.gd")
var spatial_revision:int=SpatialRevision.CURRENT
const ACTIONS={
 "atrium":[
  ["蹲下，沿底座裂隙拨开碎屑、摸查内侧；不触动整个核心。","裂隙里没有。","low","S3:T35R2"],
  ["侧身检查靠通路的指定凹槽，沿槽底摸查；旧门牌另作观察。","这里也没有藏东西。","middle","S3:T35R3"],
  ["蹲在侧边拨查堆积物，露出腕带后可辨认；不把整条通道当搜寻范围。","只剩这些碎片。","low","S3:T35R4"],
 ],
 "memory":[
  ["按顺序抽出一组文件，查看夹层与架板；文件复位，不倾倒整架。","夹层里没有。","middle","S3:T36R2"],
  ["移开未取得的展示材料，检查桌面压物处与桌底；翻开原件才进入人物事件。","桌边和下面都找过了。","middle","S3:T36R3"],
  ["蹲下掀起指定毯角，检查后放回；椅子、绿植不另计点。","毯子下面是空的。","low","S3:T36R4"],
  ["检查电视后侧及底座缝隙；观看屏幕不代替实体搜寻。","背后没有钥匙。","middle","S3:T36R5"],
  ["托起机身查看底部与可开启的收纳位置；播放键只控制录音。","机座下面也没有。","middle","S3:T36R6"],
  ["掀查指定松动相框的背侧，再复位；照片与编号须实际查看。","照片后面没有。","high","S3:T36R7"],
  ["打开可用柜门，翻查文件间隙与柜底；修订记录可另行阅读。","柜底也找过了。","middle","S3:T36R8"],
 ],
 "visual":[
  ["侧身查看后壳外侧与底座空隙；不拆屏、不拔线。","电视后面没有。","middle","S3:T37R2"],
  ["检查台下收纳处和台面夹缝；切换、播放影像另作互动。","这里没有钥匙。","middle","S3:T37R3"],
  ["翻查存放影像材料的格位及柜底；看清标签才获得对应信息。","这一格也没有。","middle","S3:T37R4"],
  ["沿指定基座凹口蹲查；屏幕内容不算基座搜寻结果。","基座里面是空的。","low","S3:T37R5"],
  ["顺次检查指定座椅下方与坐垫缝，保留中央及侧边通路。","座位下面也没有。","low","S3:T37R6"],
  ["分开外层物件，检查遮住的地面，再放稳；不生成额外材料奖励。","底下只剩杂物。","low","S3:T37R7"],
 ],
 "decision":[
  ["打开可用格位，查看文件后侧与底板；病例内容另行辨认。","文件后面没有。","middle","S3:T38R2"],
  ["检查机座及台下可达空隙；操作终端不产生实体钥匙。","下面也找过了。","middle","S3:T38R3"],
  ["查看板框下沿与附属存放槽；读到分类文字不等于完成搜寻。","槽里没有钥匙。","high","S3:T38R4"],
  ["沿桌侧检查桌底及接缝，不站到两端通路中央长期停留。","桌底是空的。","low","S3:T38R5"],
  ["扶住盆沿，查看盆后和托盘下方，再放稳。","花盆后面也没有。","low","S3:T38R6"],
  ["检查框架背侧与下沿；箭头只指示已存在的道路。","板后没有东西。","high","S3:T38R7"],
  ["查看机座收纳处与外侧凹槽；不清除已保存记录。","这里也没有。","middle","S3:T38R8"],
 ],
 "body":[
  ["蹲下查看基座凹口和底沿；屏幕显示另行读取。","底座里没有。","low","S3:T39R2"],
  ["沿框边摸查指定松动位置，查看后侧空隙；不击碎镜面。","镜框后面也没有。","high","S3:T39R3"],
  ["查看板框下沿与背侧存放处；身体编号属于线索。","这里没有钥匙。","high","S3:T39R4"],
  ["检查模型支座与陈列槽；观察约束痕迹不拆成新点。","支座下面是空的。","low","S3:T39R5"],
  ["检查台沿、台下及附属收纳处，不躺下休息。","检查台下面也没有。","middle","S3:T39R6"],
  ["探查台面凹槽及侧边存放处；手进入接触区时适用上述夹具事件。","现在找完了，没有钥匙。","middle","S3:T39R7"],
  ["打开可用柜门，检查分隔槽与柜底，不自动获得治疗道具。","器械之间也没有。","middle","S3:T39R8"],
  ["蹲在指定边缘拨查槽内，完成后起身；中央映射空地不另计点。","凹槽里没有。","low","S3:T39R9"],
 ],
 "bridge":[
  ["查看台下收纳处、台面夹缝；读取两侧记录另判。","控制台下面没有。","middle","S3:T41R2"],
  ["侧身检查机座凹槽与后侧空隙，不拔除连接线。","这一侧没有钥匙。","middle","S3:T41R3"],
  ["检查右侧机座及附属存放槽，与左侧分别计点。","这里也没有。","middle","S3:T41R4"],
  ["打开可用柜门，检查格位与柜底，再合回。","设备后面找过了。","middle","S3:T41R5"],
 ],
 "rhythm":[
  ["检查底座及可开启的存放槽；脉冲显示另作观察。","仪器下面没有。","low","S3:T42R2"],
  ["蹲查步道旁指定破损接头的外壳空隙；不搜索整束纤维。","接头里没有钥匙。","low","S3:T42R3"],
  ["查看步道侧节点护罩内可达位置，完成后合回护罩。","这个节点也没有。","middle","S3:T42R4"],
  ["检查柜内格位、线盘间隙及柜底；不要求完成维修。","线盘后面是空的。","middle","S3:T42R5"],
 ],
 "index":[
  ["检查上下层、挡边与文件下方，推车保持靠边。","车架下面没有。","low","S3:T43R2"],
  ["移开材料，检查压物处和台下；翻开原件时另判人物事件。","工作台上没有钥匙。","middle","S3:T43R3"],
  ["翻查指定柜组的格位与底部；不按柜门数量拆分奖励。","这些柜格都找过了。","middle","S3:T43R4"],
  ["检查机座及附属存放处；姓名查询与实体搜寻分别判定。","机座里也没有。","middle","S3:T43R5"],
  ["打开柜门，检查维护物件之间及柜底空隙。","储物柜里没有钥匙。","middle","S3:T43R6"],
  ["蹲查指定底座凹口；读到档案不代替搜寻完成。","底座下面是空的。","low","S3:T43R7"],
 ],
 "switch":[
  ["检查台下收纳处与面板边缘空隙；搜寻不改变房间连接。","控制台里没有钥匙。","middle","S3:T44R2"],
  ["沿底沿检查指定凹槽，屏幕信号另作观察。","底座里面没有。","low","S3:T44R3"],
  ["检查可用柜格及柜底，与节律支路同名柜分别计点。","这只柜子也没有。","middle","S3:T44R4"],
 ],
 "verify":[
  ["检查机座、台面夹缝；身份识别不代替取得钥匙。","终端下面没有。","middle","S3:T45R2"],
  ["查看台下收纳处与板面下沿；与识别终端分别计点。","控制台里也没有。","middle","S3:T45R3"],
  ["检查指定座位下方与椅缝，完成后起身继续。","椅子下面是空的。","low","S3:T45R4"],
  ["查看锁门外侧面板框及附属存放槽；开门另作互动。","面板边上没有钥匙。","middle","S3:T45R5"],
  ["检查机座收纳处及后侧可达空隙。","这里没有。","middle","S3:T45R6"],
  ["蹲查基座凹口与底沿；显示内容另行阅读。","底座里没有东西。","low","S3:T45R7"],
  ["翻查资料间隙与柜底；读取申请记录不产生签署行为。","资料后面也找过了。","middle","S3:T45R8"],
 ],
 "identity":[
  ["查看左侧机座与附属存放槽；屏幕记录另判。","左边终端没有。","middle","S3:T46R2"],
  ["检查左台下层、台沿与夹缝；核验和搜寻分别记录。","台子下面是空的。","middle","S3:T46R3"],
  ["查看镜框下沿及背侧可达凹槽，绕镜检查不增加第二个点。","镜框里没有钥匙。","middle","S3:T46R4"],
  ["检查右台对应实体部位，不因左台已搜而自动完成。","右边也没有。","middle","S3:T46R5"],
  ["翻查“已注销”档案所在柜格与柜底；不改档案状态。","这只柜子找过了。","middle","S3:T46R6"],
  ["翻查“当前使用”档案所在柜格与柜底，与柜①分别计点。","这里也没藏钥匙。","middle","S3:T46R7"],
  ["检查右侧终端机座及后侧空隙；两端内容不互相覆盖。","终端后面没有。","middle","S3:T46R8"],
 ],
}
const FOOTPRINTS={
 "atrium":[
  [2.1,1.2,1.4,1.3,1.8,1.85,"core",40],
  [0.3,0.15,1.1,0.3,0.8,0.75,"wall",45],
  [4.1,2.8,0.8,0.4,4.5,2.5,"debris",8],
 ],
 "memory":[
  [0.2,0.2,1.3,0.5,0.9,1.0,"books",50],
  [2.15,1.6,1.3,0.75,1.85,2.0,"desk",28],
  [0.3,2.8,1.4,0.65,1.0,2.5,"rug",1],
  [0.25,1.5,0.6,0.6,1.2,1.8,"screen",32],
  [3.95,2.9,0.6,0.45,4.25,2.6,"recorder",20],
  [4.9,0.8,0.25,0.9,4.6,1.25,"board",44],
  [3.8,0.25,1.4,0.45,4.5,1.0,"drawer",45],
 ],
 "visual":[
  [0.25,0.9,0.6,0.6,1.2,1.2,"screen",35],
  [4.15,0.9,1,0.5,3.85,1.15,"console",28],
  [4.7,2.0,0.6,0.75,4.4,2.4,"drawer",45],
  [1.85,0.5,1.9,0.35,2.8,1.15,"screen",50],
  [1.6,2.0,2.4,0.9,2.8,2.2,"chairs",18],
  [0.4,3.1,0.6,0.45,1.3,3.3,"debris",12],
 ],
 "decision":[
  [0.2,0.5,0.7,0.85,1.2,0.9,"drawer",48],
  [0.25,1.9,0.7,0.5,1.25,2.2,"console",28],
  [0.25,3.1,1.0,0.3,1.5,3.2,"board",48],
  [2.0,1.5,1.6,0.75,2.8,2.55,"desk",28],
  [4.6,3.0,0.5,0.5,4.3,3.2,"plant",35],
  [4.9,1.7,0.3,1.0,4.6,2.2,"board",48],
  [4.5,0.5,0.7,0.5,4.2,0.75,"recorder",25],
 ],
 "body":[
  [0.25,0.5,0.6,0.45,1.2,0.7,"screen",45],
  [0.25,1.3,0.3,0.6,0.85,1.6,"mirror",48],
  [0.25,2.2,0.3,0.6,0.85,2.5,"board",45],
  [0.25,3.2,0.8,0.35,1.35,3.35,"model",32],
  [4.1,0.8,1.2,0.6,3.8,1.1,"desk",28],
  [4.1,2.2,1.2,0.6,3.8,2.5,"clamp",28],
  [4.45,3.15,0.8,0.4,4.05,3.35,"drawer",40],
  [2.0,3.25,1.0,0.2,2.5,2.95,"groove",2],
 ],
 "bridge":[
  [2.15,1.45,1.3,0.65,2.8,2.4,"console",28],
  [0.25,2.4,0.65,0.55,1.2,2.65,"console",28],
  [4.7,2.4,0.65,0.55,4.4,2.65,"console",28],
  [3.5,0.25,1.4,0.45,4.2,1.0,"drawer",43],
 ],
 "rhythm":[
  [0.2,0.8,0.45,0.55,1.0,1.05,"console",32],
  [0.2,2.8,0.4,0.4,1.0,3.0,"cable",6],
  [2.25,3.1,0.5,0.35,2.5,2.8,"node",16],
  [3.6,3.1,0.7,0.4,3.95,2.8,"drawer",35],
 ],
 "index":[
  [0.25,1.1,0.65,0.55,1.2,1.35,"cart",26],
  [3.65,0.25,1.4,0.55,4.35,1.1,"desk",28],
  [0.25,2.3,0.65,1.1,1.2,2.8,"drawer",50],
  [2.15,1.55,1.3,0.65,2.8,2.5,"console",28],
  [2.0,3.05,1.0,0.5,2.5,2.75,"drawer",40],
  [4.85,1.75,0.45,0.6,4.5,2.05,"screen",45],
 ],
 "switch":[
  [2.2,1.5,1.2,0.6,2.8,2.4,"console",28],
  [0.5,2.8,0.65,0.6,1.5,3.1,"screen",42],
  [4.3,0.35,1.0,0.55,4.8,1.2,"drawer",38],
 ],
 "verify":[
  [0.3,0.65,0.75,0.5,1.35,0.9,"console",28],
  [4.5,0.65,0.75,0.5,4.2,0.9,"console",28],
  [1.75,2.8,2.1,0.45,2.8,2.5,"chairs",18],
  [3.5,0.2,0.35,0.35,3.55,0.85,"panel",25],
  [0.3,1.65,0.65,0.55,1.25,1.9,"console",28],
  [4.75,1.65,0.55,0.55,4.4,1.9,"screen",42],
  [4.4,3.05,0.85,0.5,4.0,3.3,"drawer",42],
 ],
 "identity":[
  [0.3,1.7,0.7,0.5,1.3,1.95,"console",28],
  [1.1,2.8,1.1,0.6,1.65,2.5,"desk",28],
  [2.65,1.5,0.3,1.35,2.3,2.15,"mirror",45],
  [3.4,2.8,1.1,0.6,3.95,2.5,"desk",28],
  [0.3,0.25,1.3,0.45,0.95,0.95,"drawer",46],
  [4.0,0.25,1.3,0.45,4.65,0.95,"drawer",46],
  [4.6,1.7,0.7,0.5,4.3,1.95,"console",28],
 ],
}
var room_id:String="atrium"
var walls:Array[Rect2]=[]
var decor:Array[Dictionary]=[]
var metric_spec:Dictionary={}

func _init(room:String="atrium",spatial_version:int=1,revision:int=SpatialRevision.CURRENT) -> void:
 spatial_revision=revision
 room_id=room
 furniture=[]
 movable_blockers.clear()
 if spatial_version>=2:
  geometry_version=2;body_radius=.21
  metric_spec=CortexMap.space_spec(room,revision)
  bounds_size=vector(metric_spec.size_m)
  for item:Dictionary in metric_spec.furniture:
   var index:int=furniture.size()
   var built:Dictionary=metric_item(item)
   var spec:Array=ACTIONS[room][index]
   built.data={"action":spec[0],"failure_hero":spec[1],"failure_player":"","pose":spec[2],"source":spec[3],"search_seconds":7.0,"completion_lines_only":true,"rest_point":false,"presentation_id":"cortex_prop:%s:%d"%[room,index]}
   furniture.append(built)
  for item:Dictionary in metric_spec.get("decor",[]):decor.append(metric_item(item))
  for item:Dictionary in metric_spec.get("partitions",[]):walls.append(rectangle(item.rect_m))
  super._init()
  return
 for shape in FOOTPRINTS.get(room,[]):
  var index:int=furniture.size()
  var spec:Array=ACTIONS[room][index]
  var rect:=Rect2(float(shape[0]),float(shape[1]),float(shape[2]),float(shape[3]))
  furniture.append({"id":"%s:%d"%[room,index],"name":CortexMap.POINTS[room][index],"rect":rect,
   "at":Vector2(float(shape[4]),float(shape[5])),"kind":str(shape[6]),"height":float(shape[7]),
   "color":Color("8c817f") if room in CortexMap.FIRST_ROOMS else Color("899894"),
   "data":{"action":spec[0],"failure_hero":spec[1],"failure_player":"","pose":spec[2],"source":spec[3],
    "search_seconds":7.0,"completion_lines_only":true,"rest_point":false,"presentation_id":"cortex_prop:%s:%d"%[room,index]}})
 if room=="visual":
  # One chair-group point; two physical banks retain central and lateral aisles.
  furniture[4]["collision_rects"]=[Rect2(1.6,2.0,.6,.9),Rect2(3.4,2.0,.6,.9)]
 elif room=="memory":
  furniture[2]["collision_rects"]=[]
  add_decor("memory_group_chair","地毯组椅子",Rect2(.4,3.0,.35,.4),"chair",18,true)
  add_decor("memory_group_plant","地毯组绿植",Rect2(1.2,3.05,.3,.35),"plant",30,true)
 elif room=="atrium":
  add_decor("old_doorplate","旧门牌",Rect2(.7,.2,.3,.08),"plate",48,false)
  add_decor("broken_wristband","断裂腕带",Rect2(4.6,2.9,.15,.08),"band",9,false)
 elif room=="rhythm":
  # S1:P291: one main bend, with room at the crossing to wait or pass alongside.
  walls.append(Rect2(1.8,0,3.8,1.7))
  add_decor("rhythm_support","固定支架",Rect2(2.25,1.85,1.4,.16),"support",45,false)
 elif room=="bridge":
  add_decor("bridge_fibers","桥下纤维束",Rect2(1.6,2.9,.35,.4),"cable",3,false)
 elif room=="body":
  # The mapping area is deliberately open; the eighth candidate is only its edge.
  add_decor("body_mapping_floor","身体映射区",Rect2(1.5,1.3,1.6,1.3),"mapping",0,false)
 elif room=="switch":
  add_decor("switch_fixed_marks","固定地纹",Rect2(1.8,.65,.4,.5),"floor_marks",0,false)
  add_decor("switch_fixed_frame","固定门框特征",Rect2(.2,.55,.12,.3),"frame",28,false)
 super._init()

func vector(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func rectangle(value:Array) -> Rect2:return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

func metric_item(item:Dictionary) -> Dictionary:
 var value:Dictionary=item.duplicate(true)
 value.rect=rectangle(item.rect_m);value.at=vector(item.stand_m)
 value.height=float(item.height_m)*78.0;value.color=Color("8c817f") if room_id in CortexMap.FIRST_ROOMS else Color("899894")
 if item.has("collision_rects_m"):
  value.collision_rects=[]
  for rect:Array in item.collision_rects_m:value.collision_rects.append(rectangle(rect))
 elif not item.get("solid",true):value.collision_rects=[]
 return value

func metric_point(old:Vector2) -> Vector2:
 if geometry_version<2:return old
 return Vector2(old.x/5.6*world_size().x,old.y/3.8*world_size().y)

func spawn() -> Vector2:
 return vector(metric_spec.spawn_m) if geometry_version>=2 else CortexMap.SPAWN

func portal(toward:String) -> Dictionary:
 if geometry_version>=2:
  for value:Dictionary in metric_spec.portals:
   if str(value.toward)!=toward:continue
   var result:Dictionary=value.duplicate(true)
   for key:String in ["at","threshold","landing","inward"]:result[key]=vector(value[key+"_m"] if key!="inward" else value.inward)
   if value.has("wall_point_m"):result.wall_point=vector(value.wall_point_m)
   return result
  return {}
 var at:Vector2=CortexMap.doorway(room_id,toward)
 if at.x<0:return {}
 var inward:Vector2=Vector2.RIGHT if at.x<.5 else Vector2.LEFT if at.x>5.1 else Vector2.DOWN if at.y<.5 else Vector2.UP
 return {"toward":toward,"at":at,"threshold":at-inward*.1,"landing":at+inward*.3,"inward":inward,"wall":"west" if inward==Vector2.RIGHT else "east" if inward==Vector2.LEFT else "north" if inward==Vector2.DOWN else "south","width_m":1.0,"height_m":2.2}

func space_spec() -> Dictionary:
 if geometry_version>=2:return metric_spec.duplicate(true)
 return {"chapter":4,"room_id":room_id,"geometry_version":1,"size_m":[SIZE.x,SIZE.y],"status":"legacy save geometry; use version2 for new template production"}

func project(p:Vector2) -> Vector2:
 return NeuralDisplay.project(p,Vector2(70,200)) if geometry_version>=2 else super.project(p)

func unproject(p:Vector2) -> Vector2:
 if geometry_version<2:return super.unproject(p)
 return NeuralDisplay.unproject(p,Vector2(70,200))

func add_decor(id:String,label:String,rect:Rect2,kind:String,height:float,solid:bool) -> void:
 decor.append({"id":id,"name":label,"rect":rect,"at":rect.get_center(),"kind":kind,"height":height,"color":Color("7c8a81"),"solid":solid})

func collision_rects(item:Dictionary) -> Array:
 return item.get("collision_rects",[item.rect])

func walkable(p:Vector2,radius:float=-1.0) -> bool:
 if radius<0.0:radius=body_radius
 if not p.is_finite():return false
 if geometry_version>=2:
  if not SpatialGeometry.inside_floor(metric_spec,world_size(),p,radius):return false
 elif not Rect2(Vector2(radius,radius),world_size()-Vector2.ONE*radius*2).has_point(p):return false
 for item in furniture:
  for rect in collision_rects(item):
   if footprint_contains((rect as Rect2).grow(radius),p):return false
 for rect in walls:
  if footprint_contains(rect.grow(radius),p):return false
 for item in decor:
  if item.solid and footprint_contains((item.rect as Rect2).grow(radius),p):return false
 for rect in movable_blockers:
  if footprint_contains(rect.grow(radius),p):return false
 return true

func clear_segment(a:Vector2,b:Vector2,radius:float=0.0) -> bool:
 if geometry_version>=2:
  if not walkable(a,radius) or not walkable(b,radius):return false
  if not SpatialGeometry.segment_inside_floor(metric_spec,world_size(),a,b,radius):return false
  for item:Dictionary in furniture:
   for rect:Rect2 in collision_rects(item):
    if segment_hits_rect(a,b,rect.grow(radius)):return false
  for rect:Rect2 in walls+movable_blockers:
   if segment_hits_rect(a,b,rect.grow(radius)):return false
  for item:Dictionary in decor:
   if item.solid and segment_hits_rect(a,b,(item.rect as Rect2).grow(radius)):return false
  return true
 var steps:int=maxi(2,ceili(a.distance_to(b)/0.03))
 for i in range(steps+1):
  if not walkable(a.lerp(b,float(i)/steps),radius):return false
 return true

func geometry_issues() -> Array:
 var issues:Array=[]
 var targets:Array=[]
 for item in furniture:
  targets.append({"id":item.id,"at":item.at})
  if not walkable(item.at):issues.append("blocked search stand "+str(item.id))
 for door in CortexMap.doors(room_id):targets.append({"id":"door:"+str(door),"at":portal(str(door)).at})
 for target in targets:
  for origin in targets:
   if target.id==origin.id:continue
   if not walkable(origin.at):issues.append("blocked origin "+str(origin.id));continue
   var route:PackedVector2Array=path(origin.at,target.at)
   if route.is_empty():issues.append("no route %s -> %s"%[origin.id,target.id]);continue
   var previous:Vector2=origin.at
   for step in route:
    if not clear_segment(previous,step,body_radius):issues.append("blocked segment %s -> %s"%[origin.id,target.id]);break
    previous=step
 return issues
