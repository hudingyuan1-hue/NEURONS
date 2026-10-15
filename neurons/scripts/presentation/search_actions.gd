extends RefCounted
## Primitive prop/action state, separate from actor atlases and reward clocks.
var app
var config:Dictionary={}
var states:Dictionary={}
var receipts:Dictionary={}
var base_rects:Dictionary={}
var pose:String="mid"
var action_label:String=""
var observing_index:int=-1

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/search_actions.json"))

func state(id:String) -> Dictionary:
 var key:String=app.room_id+":"+id
 if not states.has(key):states[key]={}
 return states[key]

func enter_room() -> void:
 base_rects.clear()
 for f in app.layout.furniture:base_rects[f.id]=f.rect
 apply_geometry()

func point(id:String) -> Dictionary:
 for entry in config.points:
  if entry.id==id:return entry
 return {}

func tick(completed_this_tick:bool=false) -> void:
 if app.room_id!="bedroom" or app.target_index<0 or not (app.rules.search_active or completed_this_tick):return
 var f:Dictionary=app.layout.furniture[app.target_index]
 if app.hero_pos.distance_to(f.at)>0.04:return
 var entry:Dictionary=point(f.id)
 if entry.is_empty():return
 var progress:float=app.rules.search_elapsed/app.rules.search_duration
 pose="mid";action_label="准备接触"
 var props:Dictionary=state(f.id)
 for step in entry.steps:
  if progress<float(step.at):break
  pose=str(step.pose);action_label=str(step.action)
  var key:String=str(app.rules._search_id)+":"+str(step.action)
  if receipts.has(key):continue
  receipts[key]=true
  match str(step.action):
   "移开书本":props.book_shift=[9.0,-1.0]
   "查看闹钟后方":props.clock_shift=[0.0,-4.0]
   "拉开抽屉":props.drawer_started=true
   "挪开椅子":props.shift=config.test_parameters.chair_shift.duplicate();apply_geometry()
   "移开上层箱":props.upper_shift=config.test_parameters.box_shift.duplicate();apply_geometry()
   "翻动第一叠书":props.desk_shift=1
   "翻动第二叠书":props.desk_shift=2
   "拨开文具纸张":props.desk_shift=3
   "打开纸箱":props.open=true
   "扶住白大褂":observe("coat_seen","实际看见卧室衣帽架上的白色医生大褂；尚未确认主人或袖口细节。")
   "掀被角":props.bedding_lifted=true
   "看见露角血迹":observe("uniform_blood","实际看见储物柜病服露角上的血迹。")
   "取出展开病服":props.uniform_out=true;observe("uniform_seen","实际展开并认出了病服；未推定其主人。")
   "翻看磨损领标":
    props.label_viewed=true
    observe("uniform_damaged_label","看清了领口有磨损标签，具体字形仍待素材核验。")
    if config.uniform_label_fragment!=null:observe("uniform_label_fragment","实际读到编号片段："+str(config.uniform_label_fragment))
   "放回病服":props.uniform_out=false
  app.rules._record("prop_action",key,{"point":f.id,"action":step.action})

func observe(id:String,text:String) -> void:
 if id in app.rules.known:return
 app.rules.known.append(id)
 app.rules.observe("物品",id,text,"亲历事实","卧室实际检查")

func on_complete(index:int,has_key:bool) -> void:
 if app.room_id!="bedroom":return
 var f:Dictionary=app.layout.furniture[index]
 if has_key:
  app.add_dialogue("角色 · 得意","哈！找到了！")
  app.add_dialogue("玩家 · 无语","可算找着了。")
  return
 var entry:Dictionary=point(f.id)
 if entry.is_empty():return
 var key:String="comment:%d:%s"%[app.rules.actual_attempt,f.id]
 if not receipts.has(key):
  receipts[key]=true
  if not entry.role_lines.is_empty():app.add_dialogue("角色",str(entry.role_lines[app.rng.randi_range(0,entry.role_lines.size()-1)]))
  if not entry.player_lines.is_empty():app.add_dialogue("玩家",str(entry.player_lines[0]))
 if f.id=="rack" and not "cuff_seam" in app.rules.known:
  observing_index=index
  app.action_phase="observe_cuff";app.action_left=float(config.test_parameters.cuff_observation_seconds)
  app.hero_state="search"

func finish_cuff() -> void:
 observe("coat_seen","实际看见卧室的白色医生大褂；未确认主人。")
 observe("cuff_seam","实际翻起袖口并看清破损后的缝补线迹。")
 app.add_dialogue("角色 · 疑惑","袖子破过……还缝了一次。")
 app.add_dialogue("玩家 · 疑惑","谁缝的？")
 observing_index=-1

func apply_geometry() -> void:
 if app.room_id!="bedroom":return
 app.layout.movable_blockers.clear()
 for f in app.layout.furniture:
  if not base_rects.has(f.id):continue
  var base:Rect2=base_rects[f.id]
  var props:Dictionary=state(f.id)
  if props.has("shift"):
   var shift:Array=props.shift
   f.rect=Rect2(base.position+Vector2(float(shift[0]),float(shift[1])),base.size)
  if f.id=="box" and props.has("upper_shift"):
   var shift:Array=props.upper_shift
   app.layout.movable_blockers.append(Rect2(base.position+Vector2(float(shift[0]),float(shift[1])),base.size))
 app.layout._init()
 if app.home!=null and not app.home.data.is_empty():
  app.home.data.dog.route=[];app.home.data.cat.route=[]
 if app.family!=null and not app.family.data.is_empty():
  app.family.data.mother.route=[];app.family.data.father.route=[]
