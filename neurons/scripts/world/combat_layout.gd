extends "res://scripts/world/room_layout.gd"
## Independent L5 geometry. L4 saves/layouts remain unchanged.
const Map=preload("res://scripts/core/combat_map.gd")
const CortexLayout=preload("res://scripts/world/cortex_layout.gd")
var room_id:String=""
var contact_events:Array=[]
var decor:Array=[]
var rack_rect:=Rect2()
var cold_zone:=Rect2()
var pulse_zone:=Rect2(4.8,.8,1.6,6.0)

func _init(room:String="atrium",with_rack:bool=true) -> void:
 room_id=room;geometry_version=2;body_radius=.21;bounds_size=Map.SIZE
 furniture.clear();movable_blockers.clear()
 if room in Map.Cortex.ALL_ROOMS:
  var source=CortexLayout.new(room)
  for item in source.furniture+source.decor:
   var f:Dictionary=item.duplicate(true)
   var rect:Rect2=item.rect
   # Reuse the established arrangement; open wider passages at fixed adult scale.
   f.rect=Rect2(rect.get_center()*2.0-rect.size*.78,rect.size*1.56)
   f.at=Vector2(item.at)*2.0;f.height=float(item.height)*1.7
   if f.get("solid",true):f.erase("collision_rects");furniture.append(f)
  for wall in source.walls:
   furniture.append(prop("隔断",Rect2(wall.position*2.0,wall.size*2.0),1.7,"wall"))
 else:build_deep()
 if room=="hippocampus" and with_rack:
  rack_rect=Rect2(3.1,2.5,.18,.9)
  var rack:Dictionary=prop("记忆陈列衣架",rack_rect,1.7,"rack");rack.id="memory_clothes_rack";furniture.append(rack)
 rebuild_grid()

func prop(name_value:String,rect:Rect2,height_m:float,kind:String="cabinet") -> Dictionary:
 return {"id":name_value,"name":name_value,"rect":rect,"at":rect.get_center(),"kind":kind,"height":height_m*78,"color":Color("8b9a96")}

func build_deep() -> void:
 var source:Dictionary={
  "hippocampus":["记忆陈列","航迹地图","时光装置","记忆胶囊","档案柜","陈列墙","记录终端"],
  "thalamus":["中继核心","维护面板","电缆接点","监测屏","控制台","设备柜"],
  "cerebellum":["折叶阵列","控制终端","校准机械臂","姿态架","平衡平台","工具柜","储物柜"],
  "hypothalamus":["温控台","传感器","监测屏","维护设备","冷却管路与液罐","阀组","设备柜","加热装置"],
  "basal":["动作选择核心","状态屏","维护区","测试舱","路径终端","校准台","机械臂"],
  "amygdala":["警报灯","监测屏","观察位","封抑柜","低刺激灯","安抚座椅","情绪记录台","隔离储柜"],
  "brainstem":["脉冲核心与护栏","生命监测终端","检修平台","维生控制台","导管接口"]}
 var labels:Array=source.get(room_id,[])
 for i in range(labels.size()):
  var name_value:String=str(labels[i])
  var rect:=Rect2(1.4+(i%4)*2.1,.8 if i<4 else 5.9,1.15,.65)
  if i==0 and room_id in ["thalamus","basal","hippocampus"]:rect=Rect2(4.4,2.8,2.4,1.8)
  if room_id=="brainstem" and i==0:rect=Rect2(5.1,2.7,1.0,2.2)
  furniture.append(prop(name_value,rect,1.0 if i==0 else .85,"core" if i==0 else "console"))
 if room_id=="cerebellum":
  furniture[0].rect=Rect2(3.5,2.4,.4,2.4)
  furniture.append(prop("折叶隔断",Rect2(6.8,2.8,.4,2.4),1.8,"wall"))
 if room_id=="amygdala":
  furniture.append(prop("双室隔断北",Rect2(5.4,.3,.2,2.7),2.0,"wall"))
  furniture.append(prop("双室隔断南",Rect2(5.4,4.6,.2,2.7),2.0,"wall"))
 if room_id=="hypothalamus":cold_zone=Rect2(2.0,2.2,2.6,3.1)
 if room_id=="thalamus":furniture[5].rect=Rect2(8.6,3.3,1.1,.6)

func project(p:Vector2) -> Vector2:return Vector2(70+p.x*96+p.y*30,200+p.y*56)
func unproject(p:Vector2) -> Vector2:
 var z:float=(p.y-200)/56.0
 return Vector2((p.x-70-z*30)/96.0,z)

func portal(toward:String) -> Dictionary:
 var at:Vector2=Map.doorway(room_id,toward)
 if at.x<0:return {}
 var inward:Vector2=Vector2.RIGHT if at.x<1 else Vector2.LEFT if at.x>10 else Vector2.DOWN if at.y<1 else Vector2.UP
 return {"at":at,"threshold":at-inward*.23,"landing":at+inward*.38,"inward":inward,"toward":toward,"wall":"west" if inward==Vector2.RIGHT else "east" if inward==Vector2.LEFT else "north" if inward==Vector2.DOWN else "south","width_m":1.2,"height_m":2.2}

func spawn() -> Vector2:return Vector2(1.3,3.8)
func speed_factor(at:Vector2) -> float:return .8 if cold_zone.has_area() and cold_zone.has_point(at) else 1.0

func clipped_step(from:Vector2,to:Vector2) -> Vector2:
 var last:Vector2=from
 var steps:int=maxi(1,ceili(from.distance_to(to)/.025))
 for i in range(1,steps+1):
  var next:Vector2=from.lerp(to,float(i)/steps)
  if not clear_segment(last,next,body_radius):
   record_rack_contact(last,next)
   break
  last=next
 return last

func record_rack_contact(from:Vector2,to:Vector2) -> void:
 if rack_rect.has_area() and from.distance_to(to)>.000001 and segment_hits_rect(from,to,rack_rect.grow(body_radius)):
  contact_events.append(rack_rect.get_center())

func move_path(at:Vector2,route:PackedVector2Array,distance:float) -> Dictionary:
 var moved:Dictionary=super.move_path(at,route,distance)
 if not moved.route.is_empty() and Vector2(moved.position).distance_to(at)<distance-.00001:
  var target:Vector2=Vector2(moved.position).move_toward(moved.route[0],distance)
  record_rack_contact(moved.position,target)
 return moved
