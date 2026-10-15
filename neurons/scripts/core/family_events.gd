extends RefCounted
## S3 household branches. Each receipt represents an actual completed action.
var app
var enabled:bool=true
var config:Dictionary={}
var data:Dictionary={}

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_rules.json"))
 config.probabilities.ordinary_nodes=config.probabilities.ordinary_nodes.map(func(n):return int(n))

func start_attempt() -> void:
 var inventory:Array=data.get("inventory",[]).duplicate()
 var food_types:Dictionary=data.get("food_types",{}).duplicate()
 var gifts:Array=data.get("gift",[]).duplicate()
 data={"mother":actor(),"father":actor(),"checks":{},"queued":[],"extra_checked":false,"fact_cursor":app.rules.facts.size(),"actions":0,"pressure":0.0,"blood_door":false,"collapse":{},"food_types":{},"inventory":[],"gift":[],"gift_roll":-1.0,"eating":{},"mother_rest":false,"rescued":false,"startle":{},"hidden_pending":false}
 data.inventory=inventory;data.food_types=food_types
 data.gift=gifts;data.gift_wait=0.0;data.gift_pick=0.0;data.picking_gift=false;data.auto_food_used=false
 data.spawn_order=[]

func actor() -> Dictionary:
 return {"present":false,"used":false,"pos":[4.6,0.22],"route":[],"phase":"absent","elapsed":0.0,"branch":""}

func position(id:String) -> Vector2:
 var p:Array=data[id].pos
 return Vector2(float(p[0]),float(p[1]))

func xy(p:Vector2) -> Array:
 return [p.x,p.y]

func move(id:String,to:Vector2,delta:float) -> bool:
 var body:Dictionary=data[id]
 var route:=PackedVector2Array()
 for p in body.route:route.append(Vector2(float(p[0]),float(p[1])))
 if route.is_empty() and position(id).distance_to(to)>0.04:route=app.layout.path(position(id),to)
 var result:Dictionary=app.layout.move_path(position(id),route,float(config.test_parameters.parent_walk_speed)*delta)
 body.pos=xy(result.position);body.route=Array(result.route).map(func(p):return [p.x,p.y])
 return position(id).distance_to(to)<=0.4

func present(id:String) -> bool:
 return enabled and not data.is_empty() and bool(data[id].present)

func busy() -> bool:
 if not enabled or data.is_empty():return false
 return present("mother") and not data.mother.phase in ["leave","absent"] or present("father") and not data.father.phase in ["leave","absent","rescued"] or not data.eating.is_empty() or float(data.get("gift_wait",0))>0 or data.get("picking_gift",false)

func blocks_hero() -> bool:
 if not busy():return false
 if app.rules.control_left>0 and not app.rules.gripped:return false
 if present("mother") and data.mother.phase=="waiting_rest" and not present("father"):return false
 return true

func world_rate() -> float:
 return float(config.timing.father_world_rate) if present("father") and data.father.phase in ["approach","grab","steady","drag","think","cat_approach"] else 1.0

func collapse_active() -> bool:
 return not data.is_empty() and not data.collapse.is_empty()

func on_node(id:String,ordinary:bool=false) -> void:
 if not enabled or data.is_empty() or app.room_id!="bedroom" or app.session.data.level!=1 or data.hidden_pending or app.rules.hp<=0 or data.checks.has(id):return
 data.checks[id]=true
 if not data.queued.is_empty():
  var next:String=str(data.queued.pop_front())
  spawn(next);return
 var step:int=mini(4,maxi(0,app.rules.actual_attempt-1))
 if ordinary and not busy():
  var selected:Array=[]
  for who in ["mother","father"]:
   if data[who].used:continue
   var chance:float=float(config.probabilities[who+"_base"])+step*float(config.probabilities.growth_per_attempt)
   if app.rng.randf()<chance:selected.append(who)
  if selected.size()==2 and app.rng.randf()<0.5:selected.reverse()
  if not selected.is_empty():
   spawn(str(selected.pop_front()))
   data.queued.append_array(selected)
 elif not data.extra_checked and (present("mother") or present("father")):
  var other:String="father" if present("mother") else "mother"
  if data[other].used:return
  data.extra_checked=true
  if app.rng.randf()<float(config.probabilities.extra_base)+step*float(config.probabilities.growth_per_attempt):spawn(other)

func spawn(who:String) -> void:
 if data[who].used:return
 var body:Dictionary=data[who]
 body.used=true;body.present=true;body.phase="intro";body.elapsed=0.0
 body.pos=xy(app.layout.DOOR)
 if not data.has("spawn_order"):data.spawn_order=[]
 data.spawn_order.append(who)
 if data.spawn_order.size()>1:
  var side:Vector2=app.layout.DOOR+Vector2(-0.45,0.25)
  if app.layout.walkable(side):body.pos=xy(side)
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 if not app.rules.public_action.is_empty():app.rules.finish_public_action(str(app.rules.public_action.origin))
 app.rules.observe("人物",who,"本周目实际见到"+("母亲" if who=="mother" else "父亲"))
 if present("mother") and present("father"):
  lock_collapse();return
 app.add_dialogue("母亲 · 温柔" if who=="mother" else "父亲 · 剪影","宝贝 妈妈能进来吗?" if who=="mother" else "嘿 儿子 爹进门咯!!!")

func tick(delta:float) -> void:
 if not enabled or data.is_empty() or collapse_active() or data.hidden_pending:return
 if app.rules.hp<=0:return
 while int(data.fact_cursor)<app.rules.facts.size():
  var event:Dictionary=app.rules.facts[int(data.fact_cursor)]
  data.fact_cursor+=1
  if event.kind=="cat_hit":
   data.eating.clear()
   if data.mother.phase=="transfer":data.mother.phase="approach";data.mother.elapsed=0
  if event.kind in ["search_completed","search_cancelled"]:
   data.auto_food_used=false
   data.actions+=1
   if int(data.actions) in config.probabilities.ordinary_nodes:on_node("ordinary:"+str(event.event_id),true)
 if not data.eating.is_empty():advance_eating(delta);return
 if app.room_id!="bedroom" or app.session.data.level!=1:return
 if not app.dialogue_queue.is_empty():return
 if float(data.get("gift_wait",0))>0:data.gift_wait=maxf(0,float(data.gift_wait)-delta);return
 if data.get("picking_gift",false):advance_gift(delta);return
 if present("mother") and present("father"):lock_collapse();return
 advance_mother(delta)
 if not app.dialogue_queue.is_empty():return
 advance_father(delta)

func advance_mother(delta:float) -> void:
 if not present("mother"):return
 var mother:Dictionary=data.mother
 match str(mother.phase):
  "intro":
   on_node("mother_enter")
   if collapse_active():return
   if app.rules.sp<100:
    mother.branch="porridge";mother.phase="approach"
    app.add_dialogue("角色 · 呆滞","可以的 妈妈")
    app.add_dialogue("母亲 · 温柔","宝贝 你脸色看起来不太好")
   elif app.home.present("cat"):
    mother.branch="chocolate";mother.phase="chase_cat"
    app.add_dialogue("角色 · 摇头","妈 我现在很好 你不用进来")
    app.add_dialogue("母亲 · 怀疑","你的房间...有猫？")
    app.add_dialogue("角色 · 迟疑","对...对啊...我也不知道它怎么跑进来的")
    app.add_dialogue("母亲 · 担心","这会把他引来的...")
   elif app.home.present("dog") and app.home.data.dog.alive:
    mother.branch="gift";mother.phase="drop"
    app.add_dialogue("角色 · 摇头","妈 我现在很好 你不用进来")
    app.add_dialogue("大黄","汪!")
    app.add_dialogue("母亲 · 高兴剪影","大黄也在啊 大黄要照顾好他哦")
    app.add_dialogue("角色 · 开心","知道了 妈 我会照顾大黄的")
    app.add_dialogue("母亲 · 高兴剪影","好 宝贝 那妈妈去忙了 我在门口给你放了些东西哟...")
   else:
    mother.phase="leave"
    app.add_dialogue("角色 · 摇头","妈 我现在很好 你不用进来")
    app.add_dialogue("母亲 · 平静","那你忙，妈妈先走了。")
  "chase_cat":
   if not app.home.present("cat") or move("mother",app.home.position("cat"),delta):
    if app.home.present("cat"):app.home.leave_cat()
    mother.phase="approach";mother.route=[]
  "approach":
   if move("mother",app.hero_pos,delta):
    if app.rules.body_busy() or app.rules.gripped:return
    mother.phase="transfer";mother.elapsed=0.0
    ensure_food(str(mother.branch),"mother")
    app.add_dialogue("母亲 · 关心","妈妈给你熬了粥 喝了休息吧" if mother.branch=="porridge" else "来 宝贝 妈妈给你带了给小零食...")
  "transfer":
   if app.rules.body_busy() or app.rules.gripped:return
   mother.elapsed+=delta
   if mother.elapsed>=float(config.test_parameters.transfer_duration):
    var item:String=food_id(str(mother.branch))
    if app.rules.commit_transfer("give:"+item,item,"mother","hero",position("mother").distance_to(app.hero_pos),app.layout.clear_segment(position("mother"),app.hero_pos),true,true):
     if not item in data.inventory:data.inventory.append(item)
     app.rules.observe("物品",item,"实际接到"+("一碗粥" if mother.branch=="porridge" else "一块巧克力")+"；尚未食用。")
     mother.phase="request_rest";mother.elapsed=0.0;data.auto_food_used=false
     on_node("mother_handoff")
     if not collapse_active():app.add_dialogue("母亲 · 担心","宝贝 你需要好好休息" if mother.branch=="porridge" else "快睡吧 等会他来了...")
  "request_rest":
   if try_auto_food():return
   data.mother_rest=true
   app.action_phase="return_bed";app.hero_route=app.layout.path(app.hero_pos,app.layout.BED_STOP)
   mother.phase="waiting_rest"
  "waiting_rest":
   if app.action_phase=="autonomy" and app.rules.reaction_left<=0 and not app.rules.body_busy():
    app.action_phase="return_bed";app.hero_route=app.layout.path(app.hero_pos,app.layout.BED_STOP)
  "drop":
   if float(data.gift_roll)<0:data.gift_roll=app.rng.randf()
   var kinds:Array=["candy"] if data.gift_roll<0.6 else ["chocolate"] if data.gift_roll<0.9 else ["candy","chocolate"]
   for kind in kinds:
    var item:String=ensure_food(kind,"floor")
    if not item in data.gift:data.gift.append(item)
   mother.phase="absent";mother.present=false;data.gift_wait=float(config.timing.gift_wait)
   app.add_dialogue("角色 · 开心","好 谢谢妈妈...")
   app.add_dialogue("玩家 · 邪恶","收到~")
  "gift_wait":
   mother.elapsed+=delta
   if mother.elapsed>=float(config.timing.gift_wait):
    mother.present=false;mother.phase="absent"
  "leave":
   if move("mother",app.layout.DOOR,delta):mother.present=false;mother.phase="absent"

func advance_father(delta:float) -> void:
 if not present("father"):return
 var father:Dictionary=data.father
 if app.home.present("cat") and app.home.data.cat.phase=="held":app.home.data.cat.pos=xy(position("father")+Vector2(0.1,0))
 if father.phase in ["approach","grab","steady"] and app.rules.control_left<=0:
  app.hero_facing=(position("father")-app.hero_pos).normalized()
 if father.phase in ["approach","grab","steady","drag","think","cat_approach"]:
  data.pressure+=delta
  while data.pressure>=1.0:data.pressure-=1.0;app.rules.change_sp(-1)
 match str(father.phase):
  "intro":
   on_node("father_enter")
   if collapse_active():return
   var dog:bool=app.home.present("dog") and app.home.data.dog.alive
   var cat:bool=app.home.present("cat")
   if dog and not cat:
    father.phase="kill_dog"
    app.add_dialogue("大黄 · 警戒","汪汪汪!!!!")
    app.add_dialogue("父亲 · 剪影","哼.. ..这狗也在这")
    app.add_dialogue("父亲 · 讥讽","不过...再忠诚...也抵不过人心")
   elif cat and not dog:
    father.phase="cat_approach"
    app.add_dialogue("父亲 · 高兴","诶哟 小猫儿 你咋在这儿呢")
    app.add_dialogue("黑猫 · 撒娇","喵~")
   else:begin_abduct()
  "kill_dog":
   father.present=false;father.phase="absent"
   app.home.kill_dog()
   app.rules.record_awakening("dog_death")
   app.rules.observe("人物","dog_death","父亲离开并发动效果后，大黄变成肉泥。")
   app.add_dialogue("角色 · 震惊","这...!!!大黄!!!!...不要!!!")
   app.add_dialogue("角色 · 痛苦","不... ....")
   app.add_dialogue("玩家 · 沉重","...节哀吧...说不定...")
   app.add_dialogue("角色 · 沉默","... ...")
   app.add_dialogue("角色 · 癫狂","好...太好了...这个世界...哈哈哈哈")
  "cat_approach":
   if not app.home.present("cat"):begin_abduct();return
   if move("father",app.home.position("cat"),delta):
    app.home.data.cat.phase="held";app.home.data.fighting=false
    father.phase="think";data.blood_door=true
    app.add_dialogue("父亲 · 冷淡","爹说话 你怎么不回答呢?儿子")
    app.add_dialogue("角色 · 害怕","没...没有...我刚在忙忙一些...一些...")
    app.add_dialogue("父亲 · 大笑","忙? 我看你不忙啊 要不要出来走走？")
  "think":
   app.home.data.cat.pos=xy(position("father")+Vector2(0.1,0))
   if app.rules.sp<60:begin_abduct()
  "approach":
   father.elapsed+=delta
   var reached:bool=move("father",app.hero_pos,delta)
   if reached and father.elapsed>=float(config.timing.father_prepare):
    on_node("before_grab")
    if collapse_active():return
    father.phase="grab";father.elapsed=0.0
  "grab":
   father.elapsed+=delta
   if father.elapsed>=float(config.timing.father_grab):
    if position("father").distance_to(app.hero_pos)<=float(config.test_parameters.grab_distance) and app.layout.clear_segment(position("father"),app.hero_pos) and not (app.rules.reaction_skill=="WITHDRAW" and app.rules.reaction_left>0):
     app.rules.gripped=true;app.rules.cancel_search();app.hero_route=PackedVector2Array()
     if not data.startle.is_empty() and not data.startle.held:data.startle.clear()
     father.phase="steady";father.elapsed=0.0
    else:
     reward_startle(false)
     father.phase="approach";father.elapsed=0.0;father.route=[]
  "steady":
   father.elapsed+=delta
   if father.elapsed>=float(config.timing.father_stabilize):father.phase="drag";father.route=[]
  "drag":
   var at:Vector2=position("father")
   var route:PackedVector2Array=app.layout.path(app.hero_pos,at)
   var moved:Dictionary=app.layout.move_path(app.hero_pos,route,float(config.timing.father_drag_speed)*delta)
   app.hero_pos=moved.position;app.hero_state="hit"
   if app.hero_pos.distance_to(at)<0.5:move("father",app.layout.DOOR,delta)
   if app.hero_pos.distance_to(app.layout.DOOR)<0.13:
    on_node("before_blood_door")
    if not collapse_active():
     data.hidden_pending=true;app.rules.end_control();app.rules.transitioning=true
     app.status_note="已实际到血门；隐藏Street待B2接入，当前停在明确开发边界"
  "leave","rescued":
   if app.home.present("cat") and app.home.data.cat.phase=="held":app.home.data.cat.pos=xy(position("father"))
   if move("father",app.layout.DOOR,delta):
    father.present=false;father.phase="absent"
    if app.home.present("cat") and app.home.data.cat.phase=="held":app.home.data.cat.present=false
  "stagger":
   father.elapsed+=delta
   if father.elapsed>=2.0:father.phase="approach";father.elapsed=0;father.route=[]
 if not data.startle.is_empty() and app.motion.is_empty() and data.startle.get("held",false):reward_startle(true)

func begin_abduct() -> void:
 data.father.phase="approach";data.father.elapsed=0;data.father.route=[]
 data.blood_door=true
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 app.add_dialogue("父亲 · 高兴","儿砸 这次爸不砸你存钱罐了 䵴䵰䶷？")
 app.add_dialogue("角色 · 害怕","... ...")
 app.add_dialogue("玩家 · 担心","这?这什么情况？")
 app.add_dialogue("父亲 · 高兴","儿䴡 跟爸䶼䴰䶲去䶳了 䵴䵰䶷 哈鉿𨉣奤紦𨉣鉿！！！")
 app.add_dialogue("玩家 · 担心","不行不行 完了完了 这说的什么玩意啊 得救救这家伙")

func rescue_context() -> bool:
 return present("father") and data.father.phase in ["approach","grab","steady","drag","stagger"]

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false) or data.is_empty():return
 var id:String=str(result.id)
 if id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  data.eating.clear()
  if present("mother") and data.mother.phase=="transfer":data.mother.phase="approach";data.mother.elapsed=0.0;data.mother.route=[]
 if id=="DRYMOUTH" and present("mother") and data.mother.phase=="transfer":data.mother.elapsed-=2.0
 if id=="GUT" and present("mother") and data.mother.phase in ["request_rest","waiting_rest"]:
  data.mother_rest=false;data.mother.phase="leave";data.mother.route=[];app.action_phase="autonomy"
 if present("father") and data.father.phase=="think":expel_father();return
 if rescue_context() and id in ["FEAR","JOY"]:
  app.rules.gripped=false;data.blood_door=false;data.rescued=true;data.pressure=0
  data.father.phase="rescued";data.father.route=[]
  app.add_dialogue("角色 · 震惊","什么鬼!!!")
  app.route_to_door("lobby")
 if rescue_context() and id=="STARTLE" and (app.rules.gripped or data.father.phase=="grab"):
  data.startle={"id":result.event_id,"held":app.rules.gripped,"start":xy(app.hero_pos)}

func after_motion_started() -> void:
 if data.is_empty() or data.startle.is_empty() or app.motion.is_empty():return
 var endpoint:Array=app.motion.endpoint
 if Vector2(float(endpoint[0]),float(endpoint[1])).distance_to(app.hero_pos)>0.01 and data.startle.held:
  app.motion.allow_gripped=true

func after_motion_step() -> void:
 if data.is_empty() or data.startle.is_empty() or not data.startle.held:return
 var start:Array=data.startle.start
 if Vector2(float(start[0]),float(start[1])).distance_to(app.hero_pos)>0.001:
  app.rules.gripped=false;data.father.phase="approach";data.father.elapsed=0;data.father.route=[]

func reward_startle(held:bool) -> void:
 if data.startle.is_empty():return
 var start:Array=data.startle.start
 var moved:bool=Vector2(float(start[0]),float(start[1])).distance_to(app.hero_pos)>0.05
 if moved and (held or position("father").distance_to(app.hero_pos)>float(config.test_parameters.grab_distance)):
  var id:String="father_escape:"+str(data.startle.id)
  if not app.rules.settled.has(id):app.rules.settled[id]="escaped";app.rules.change_sp(5)
  data.startle.clear()

func kick_contact() -> void:
 if not rescue_context():return
 var direction:Array=app.rules.action.get("direction",[1,0])
 var facing:=Vector2(float(direction[0]),float(direction[1])).normalized()
 var offset:Vector2=position("father")-app.hero_pos
 if app.rules.kick_contact("father",offset.length(),offset.normalized().dot(facing)>0.65,app.layout.clear_segment(app.hero_pos,position("father"))):
  if app.rng.randf()<0.70:
   app.rules.gripped=false;app.rules.change_sp(10)
   data.father.phase="stagger";data.father.elapsed=0.0
   var endpoint:Vector2=position("father")+offset.normalized()*0.3
   if app.layout.walkable(endpoint) and app.layout.clear_segment(position("father"),endpoint,app.layout.RADIUS):data.father.pos=xy(endpoint)

func expel_father() -> void:
 data.father.phase="leave";data.father.route=[];data.blood_door=false;data.pressure=0
 app.add_dialogue("角色 · 大吼","滚!!!滚!!!滚!!!给我滚出去!!!")
 app.add_dialogue("父亲 · 无所谓","啊...这家伙翅膀硬了呀...哟吼吼...哈哈哈哈哈")
 app.add_dialogue("角色 · 愤怒盯着","... ...")
 app.add_dialogue("父亲 · 冷漠","... ...")
 app.add_dialogue("父亲 · 妥协","行吧...臭小子")
 app.add_dialogue("角色 · 凝重","他绝对不是我父亲 我在他身上感受到无比浓重的[恶意]...这是怎么回事...难道?")
 app.add_dialogue("玩家 · 长舒一口气","确实是浓重的恶意呀...父不父亲我不知道...但...总算渡过了")
 app.add_dialogue("玩家 · 凝重","话说...这家伙不会因此[觉醒]吧")

func food_id(kind:String) -> String:
 return "food:%s:%d"%[kind,app.rules.actual_attempt]

func ensure_food(kind:String,owner:String) -> String:
 var id:String=food_id(kind)
 if not data.food_types.has(id):data.food_types[id]=kind;app.rules.owners[id]=owner
 return id

func request_food(kind:String) -> bool:
 if app.rules.hp<=0 or app.rules.body_busy() or app.rules.gripped or collapse_active() or not data.eating.is_empty():return false
 for id in data.inventory:
  if data.food_types[id]==kind and app.rules.owners.get(id,"")=="hero":
   data.eating={"item":id,"elapsed":0.0,"started":false};data.auto_food_used=true;return true
 return false

func try_auto_food() -> bool:
 if data.is_empty() or data.get("auto_food_used",false):return false
 if app.rules.hp<=50 and request_food("chocolate"):return true
 if app.rules.sp<=50:
  for kind in ["porridge","candy","chocolate"]:
   if request_food(kind):return true
 return false

func request_gift() -> bool:
 if data.is_empty() or data.gift.is_empty() or app.rules.hp<=0 or app.rules.gripped or app.rules.body_busy():return false
 data.picking_gift=true;data.gift_pick=0.0
 app.hero_route=app.layout.path(app.hero_pos,app.layout.DOOR)
 return true

func advance_gift(delta:float) -> void:
 if app.rules.hp<=0 or app.rules.gripped or app.rules.body_busy():return
 app.move_hero(delta)
 if app.hero_pos.distance_to(app.layout.DOOR)>0.05:return
 data.gift_pick+=delta
 if float(data.gift_pick)<float(config.test_parameters.gift_pickup):return
 for id in data.gift.duplicate():
  if app.rules.commit_transfer("gift_pick:"+id,id,"floor","hero",app.hero_pos.distance_to(app.layout.DOOR),true,true,true):
   data.inventory.append(id);data.gift.erase(id)
   app.rules.observe("物品",id,"实际拾取门口礼物："+str(data.food_types[id])+"，尚未食用。")
 data.picking_gift=false;data.auto_food_used=false

func advance_eating(delta:float) -> void:
 if app.rules.hp<=0 or app.rules.stun_left>0 or app.rules.gripped:data.eating.clear();return
 if app.rules.body_busy():return
 if not data.eating.get("started",false):
  data.eating.started=true
  app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1;app.controlled_route=false
 data.eating.elapsed+=delta
 if float(data.eating.elapsed)+0.000001<float(config.timing.eat):return
 var id:String=str(data.eating.item)
 var receipt:String="eat:"+id
 if not app.rules.settled.has(receipt) and app.rules.owners.get(id,"")=="hero":
  app.rules.settled[receipt]="consumed";app.rules.owners[id]="consumed";data.inventory.erase(id)
  var kind:String=str(data.food_types[id])
  match kind:
   "porridge":app.rules.change_sp(100);app.rules.neurons+=5;app.rules.plexus+=1
   "candy":app.rules.change_sp(20);app.rules.neurons+=5
   "chocolate":app.rules.hp=mini(100,app.rules.hp+15);app.rules.change_sp(15);app.rules.neurons+=3;app.rules.plexus+=1
  app.rules.observe("物品",receipt,"已实际食用"+kind+"，结果已结算。")
  on_node(receipt)
 data.eating.clear()

func lock_collapse() -> void:
 if collapse_active():return
 data.collapse={"elapsed":0.0,"index":0,"first":str(data.get("spawn_order",["mother"])[0])}
 app.rules.cancel_search();app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.action.clear()
 app.rules.end_control();app.rules.hp=0;app.rules.sp=0
 app.first_damage=true;app.status_visible=true;app.first_damage_pending=false
 data.eating.clear();data.mother_rest=false;data.blood_door=false
 app.hero_route=PackedVector2Array();app.motion.clear();app.dialogue_queue.clear()
 app.rules.record_awakening("parents_collapse")

func advance_collapse(delta:float) -> bool:
 if not collapse_active():return false
 data.collapse.elapsed+=delta
 var beat:float=float(config.test_parameters.collapse_caption)
 if float(data.collapse.elapsed)<beat*2:
  var first:String=str(data.collapse.get("first","mother"))
  var second:String="father" if first=="mother" else "mother"
  if float(data.collapse.elapsed)>beat:
   move(second,position(first)+Vector2(-0.25,0.15),delta)
  app.dialogue_panel.show();app.dialogue_text.text="角色 · 诧异\n\n"+("妈？" if first=="mother" else "爸？")
  return false
 var lines:Array=["𩇬䵉䶴䂙？䨻䵊䴓，㱎㔿𩉻！","䶺䴔䶳，䆐䴒䶵，㗊𩇯䵙？","㱌！䶹䶱䴕，䲈䶼䴡。","乱䴨䶢䴩，䵙䴪䶳？","䴡䴡䴢？根本䶲是！","𩇬䵉䶴䂙䨻䵊䴓㱎㔿𩉻，䶺䴔䶳䆐䴒䶵㗊𩇯䵙？","䴲䶷䵽㱏㔽𩉼，䵿䶳䴴䵳䶸䴵㗊𩇱䵚？","𩍮!䶪!䵽!䴮!䶫!䴯!䵻!!!!!!!!!!!!!!!!!!!!!!"]
 var index:int=int((float(data.collapse.elapsed)-beat*2)/beat)
 data.collapse.index=index
 if index>=lines.size():
  app.dialogue_panel.hide();return true
 app.dialogue_panel.show();app.dialogue_text.text=("异化母亲" if index%2==0 else "异化父亲")+"\n\n"+str(lines[index])
 return false

func actors() -> Array:
 var out:Array=[]
 if data.is_empty() or not enabled or app.room_id!="bedroom":return out
 for id in ["mother","father"]:
  if present(id):out.append({"type":"actor","data":id,"depth":app.layout.project(position(id)).y})
 return out
