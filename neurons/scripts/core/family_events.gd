extends RefCounted
## S3 household branches. Each receipt represents an actual completed action.
var app
var enabled:bool=true
var config:Dictionary={}
var data:Dictionary={}
var dialogue:Dictionary={}
var system_lines:Dictionary={}

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_rules.json"))
 var script_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_dialogue.json"))
 dialogue=script_data.cues;system_lines=script_data.system
 config.probabilities.ordinary_nodes=config.probabilities.ordinary_nodes.map(func(n):return int(n))

func start_attempt() -> void:
 var inventory:Array=data.get("inventory",[]).duplicate()
 var food_types:Dictionary=data.get("food_types",{}).duplicate()
 var gifts:Array=data.get("gift",[]).duplicate()
 var eating_serial:int=int(data.get("eating_serial",0))
 data={"mother":actor(),"father":actor(),"checks":{},"queued":[],"extra_checked":false,"fact_cursor":app.rules.facts.size(),"actions":0,"pressure":0.0,"blood_door":false,"collapse":{},"food_types":{},"inventory":[],"gift":[],"gift_roll":-1.0,"eating":{},"mother_rest":false,"rescued":false,"startle":{},"hidden_pending":false}
 data.inventory=inventory;data.food_types=food_types
 data.gift=gifts;data.gift_wait=0.0;data.gift_pick=0.0;data.picking_gift=false;data.auto_food_used=false
 data.spawn_order=[]
 data.dialogue_choices={}
 data.eating_serial=eating_serial
 data.system_prompts={}

func restore_state(saved:Dictionary) -> void:
 data=saved.duplicate(true)
 if data.is_empty():return
 if not data.has("dialogue_choices"):data.dialogue_choices={}
 # Godot JSON decodes numbers as floats; variant indices remain integers.
 for id in data.dialogue_choices:data.dialogue_choices[id]=int(data.dialogue_choices[id])

func cue(id:String) -> void:
 if not data.has("dialogue_choices"):data.dialogue_choices={}
 var entry:Dictionary=dialogue[id]
 if not data.dialogue_choices.has(id):data.dialogue_choices[id]=app.rng.randi_range(0,entry.lines.size()-1)
 app.add_dialogue(str(entry.speaker),str(entry.lines[int(data.dialogue_choices[id])]))

func hero_pose() -> String:
 if not data.is_empty() and not data.eating.is_empty():return "eat"
 return "scratch" if present("mother") and data.mother.phase=="comfort" else ""

func actor() -> Dictionary:
 return {"present":false,"used":false,"pos":[4.6,0.22],"route":[],"phase":"absent","elapsed":0.0,"branch":"","facing":[0.0,1.0],"release_left":0.0}

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
 var displacement:Vector2=result.position-position(id)
 if displacement.length_squared()>0.000001:
  var old:Array=body.get("facing",[0.0,1.0])
  var direction:=Vector2(float(old[0]),float(old[1]))
  body.facing=xy(Vector2.from_angle(rotate_toward(direction.angle(),displacement.angle(),delta*5.0)))
 body.pos=xy(result.position);body.route=Array(result.route).map(func(p):return [p.x,p.y])
 return position(id).distance_to(to)<=0.4

func present(id:String) -> bool:
 return enabled and app.room_id=="bedroom" and int(app.session.data.level)==1 and not data.is_empty() and bool(data[id].present)

func busy() -> bool:
 if not enabled or data.is_empty():return false
 var home_scene:bool=app.room_id=="bedroom" and int(app.session.data.level)==1
 return present("mother") and not data.mother.phase in ["leave","absent"] or present("father") and not data.father.phase in ["leave","absent","rescued"] or not data.eating.is_empty() or home_scene and (float(data.get("gift_wait",0))>0 or data.get("picking_gift",false))

func blocks_hero() -> bool:
 if not busy():return false
 if app.rules.control_left>0 and not app.rules.gripped:return false
 if present("mother") and data.mother.phase=="waiting_rest" and not present("father"):return false
 return true

func world_rate() -> float:
 if app.room_id!="bedroom" or int(app.session.data.level)!=1:return 1.0
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
 body.pos=xy(app.layout.door_position())
 if not data.has("spawn_order"):data.spawn_order=[]
 data.spawn_order.append(who)
 if data.spawn_order.size()>1:
  # The doorway's adjacent space changes with room geometry. Try both real
  # sides instead of spawning the second parent inside a moved coat rack.
  for offset in [Vector2(-0.45,0.25),Vector2(0.45,0.25),Vector2(0,0.6)]:
   var side:Vector2=app.layout.door_position()+offset
   if app.layout.walkable(side) and app.layout.clear_segment(app.layout.door_position(),side,app.layout.body_radius):
    body.pos=xy(side);break
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 if not app.rules.public_action.is_empty():app.rules.finish_public_action(str(app.rules.public_action.origin))
 app.rules.observe("人物",who,"本周目实际见到"+("母亲" if who=="mother" else "父亲"))
 if present("mother") and present("father"):
  lock_collapse();return
 cue("MOTHER_ENTRY" if who=="mother" else "FATHER_ENTRY")

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
 if collapse_active() or app.rules.hp<=0 or not app.dialogue_queue.is_empty():return
 if app.room_id=="bedroom" and app.session.data.level==1:
  if present("mother") and present("father"):lock_collapse();return
  # Eating does not grant a pause of the father's pressure, approach or grip.
  # A newly completed grab is checked before swallowing can settle this tick.
  advance_father(delta)
  if collapse_active() or app.rules.hp<=0 or not app.dialogue_queue.is_empty():return
 if not data.eating.is_empty():advance_eating(delta);return
 if app.room_id!="bedroom" or app.session.data.level!=1:return
 if float(data.get("gift_wait",0))>0:data.gift_wait=maxf(0,float(data.gift_wait)-delta);return
 if data.get("picking_gift",false):advance_gift(delta);return
 advance_mother(delta)

func advance_mother(delta:float) -> void:
 if not present("mother"):return
 var mother:Dictionary=data.mother
 match str(mother.phase):
  "intro":
   on_node("mother_enter")
   if collapse_active():return
   if app.rules.sp<100:
    mother.branch="porridge";mother.phase="approach"
    cue("HERO_ADMIT_MOTHER")
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
    mother.phase="wait_cat_exit";mother.route=[]
  "wait_cat_exit":
   if not app.home.present("cat"):mother.phase="approach"
  "approach":
   if move("mother",app.hero_pos,delta):
    if app.rules.body_busy() or app.rules.gripped:return
    mother.elapsed=0.0
    if mother.branch=="porridge" and not mother.get("reassured",false):
     mother.phase="comfort";cue("MOTHER_CONDITION")
    else:
     mother.phase="transfer";ensure_food(str(mother.branch),"mother")
     if mother.branch=="chocolate" and not mother.get("offered",false):
      mother.offered=true;app.add_dialogue("母亲 · 担心","来 宝贝 妈妈给你带了给小零食...")
  "comfort":
   if app.rules.body_busy() or app.rules.gripped:return
   mother.elapsed+=delta
   if mother.elapsed>=float(config.test_parameters.mother_head_scratch):
    mother.reassured=true;mother.phase="transfer";mother.elapsed=0.0
    ensure_food(str(mother.branch),"mother")
    cue("HERO_CONDITION");cue("MOTHER_REST")
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
     if not collapse_active():
      app.status_note="你获得一碗粥" if mother.branch=="porridge" else "你获得一块巧克力"
      if mother.branch=="porridge":
       app.add_dialogue("母亲 · 关心","妈妈给你熬了粥 喝了休息吧")
       app.add_dialogue("角色 · 呆滞","... ...")
      else:
       app.add_dialogue("角色 · 开心","谢谢妈")
       app.add_dialogue("母亲 · 担心","快睡吧 等会他来了...")
  "request_rest":
   if try_auto_food():return
   data.mother_rest=true
   app.action_phase="return_bed";app.hero_route=app.layout.path(app.hero_pos,app.layout.bed_position())
   mother.phase="waiting_rest"
  "waiting_rest":
   if app.action_phase=="autonomy" and app.rules.reaction_left<=0 and not app.rules.body_busy():
    app.action_phase="return_bed";app.hero_route=app.layout.path(app.hero_pos,app.layout.bed_position())
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
   if move("mother",app.layout.door_position(),delta):mother.present=false;mother.phase="absent"

func advance_father(delta:float) -> void:
 if not present("father"):return
 var father:Dictionary=data.father
 father.release_left=maxf(0.0,float(father.get("release_left",0.0))-delta)
 # Optional presentation receipts migrate old in-progress saves without
 # replaying existing prompts or advancing pressure before the missing hint.
 var shown:Dictionary=data.get("system_prompts",{})
 if father.phase=="think" and not shown.has("FATHER_THINK"):
  system_prompt("FATHER_THINK");return
 if rescue_context() and not shown.has("FATHER_RESCUE"):
  if father.get("forced_low_sp",false) and app.rules.sp<60:system_prompt("FATHER_LOW_SP")
  system_prompt("FATHER_RESCUE");return
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
    cue("FATHER_CAT_QUESTION")
    app.add_dialogue("角色 · 害怕","没...没有...我刚在忙忙一些...一些...")
    app.add_dialogue("父亲 · 大笑","忙? 我看你不忙啊 要不要出来走走？")
    system_prompt("FATHER_THINK")
  "think":
   app.home.data.cat.pos=xy(position("father")+Vector2(0.1,0))
   if app.rules.sp<60:begin_abduct(true)
  "approach":
   father.elapsed+=delta
   # Stop at real arm's reach during the remaining preparation time. Moving
   # all the way to the host while waiting collapsed both bodies to one point.
   var reached:bool=position("father").distance_to(app.hero_pos)<=0.4 and app.layout.clear_segment(position("father"),app.hero_pos)
   if not reached:reached=move("father",app.hero_pos,delta)
   if reached:
    father.route=[]
    var toward:Vector2=app.hero_pos-position("father")
    if toward.length_squared()>0.0001:father.facing=xy(toward.normalized())
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
     father.facing=xy((app.hero_pos-position("father")).normalized())
    else:
     reward_startle(false)
     father.phase="approach";father.elapsed=0.0;father.route=[]
  "steady":
   father.elapsed+=delta
   var current:Array=father.get("facing",[0.0,1.0])
   var heading:=Vector2(float(current[0]),float(current[1]))
   var toward:Vector2=app.layout.door_position()-position("father")
   if toward.length_squared()>0.0001:father.facing=xy(Vector2.from_angle(rotate_toward(heading.angle(),toward.angle(),delta*2.4)))
   if father.elapsed>=float(config.timing.father_stabilize):father.phase="drag";father.route=[]
  "drag":
   var at:Vector2=position("father")
   var route:PackedVector2Array=app.layout.path(app.hero_pos,at)
   var moved:Dictionary=app.layout.move_path(app.hero_pos,route,float(config.timing.father_drag_speed)*delta)
   app.hero_pos=moved.position;app.hero_state="hit"
   if app.hero_pos.distance_to(at)<0.5:move("father",app.layout.door_position(),delta)
   if app.hero_pos.distance_to(app.layout.door_position())<0.13:
    on_node("before_blood_door")
    if not collapse_active():
     data.hidden_pending=true;app.rules.end_control();app.rules.transitioning=true
     app.status_note="父亲带至血门，进入独立广场片段"
  "leave","rescued":
   if app.home.present("cat") and app.home.data.cat.phase=="held":app.home.data.cat.pos=xy(position("father"))
   if move("father",app.layout.door_position(),delta):
    father.present=false;father.phase="absent"
    if app.home.present("cat") and app.home.data.cat.phase=="held":app.home.data.cat.present=false
    if father.get("departure_reflection_pending",false):
     father.departure_reflection_pending=false
     app.add_dialogue("角色 · 凝重","他绝对不是我父亲 我在他身上感受到无比浓重的[恶意]...这是怎么回事...难道?")
     app.add_dialogue("玩家 · 长舒一口气","确实是浓重的恶意呀...父不父亲我不知道...但...总算渡过了")
     app.add_dialogue("玩家 · 凝重","话说...这家伙不会因此[觉醒]吧")
  "stagger":
   father.elapsed+=delta
   if father.elapsed>=2.0:father.phase="approach";father.elapsed=0;father.route=[]
 if not data.startle.is_empty() and app.motion.is_empty() and data.startle.get("held",false):reward_startle(true)

func system_prompt(id:String) -> void:
 if not data.has("system_prompts"):data.system_prompts={}
 if data.system_prompts.has(id):return
 data.system_prompts[id]=true
 app.add_dialogue("系统 · 神经干预","\n".join(system_lines[id].lines))

func prompt_info() -> Dictionary:
 if not present("father") or collapse_active() or app.rules.hp<=0 or data.hidden_pending:return {}
 if data.father.phase=="think":return {"mode":"think","lines":system_lines.FATHER_THINK.lines,"skills":app.rules.skill_states.keys()}
 if rescue_context():
  var lines:Array=system_lines.FATHER_RESCUE.lines.duplicate()
  if data.father.get("forced_low_sp",false) and app.rules.sp<60:lines=system_lines.FATHER_LOW_SP.lines+lines
  return {"mode":"rescue","lines":lines,"skills":["KNEE","STARTLE","FEAR","JOY"]}
 return {}

func begin_abduct(low_sp:bool=false) -> void:
 data.father.forced_low_sp=low_sp
 data.father.phase="approach";data.father.elapsed=0;data.father.route=[]
 data.blood_door=true
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
 app.add_dialogue("父亲 · 高兴","儿砸 这次爸不砸你存钱罐了 䵴䵰䶷？")
 app.add_dialogue("角色 · 害怕","... ...")
 app.add_dialogue("玩家 · 担心","这?这什么情况？")
 app.add_dialogue("父亲 · 高兴","儿䴡 跟爸䶼䴰䶲去䶳了 䵴䵰䶷 哈鉿𨉣奤紦𨉣鉿！！！")
 app.add_dialogue("玩家 · 担心","不行不行 完了完了 这说的什么玩意啊 得救救这家伙")
 if low_sp and app.rules.sp<60:system_prompt("FATHER_LOW_SP")
 system_prompt("FATHER_RESCUE")

func rescue_context() -> bool:
 return present("father") and data.father.phase in ["approach","grab","steady","drag","stagger"]

func start_release_pose() -> void:
 # Presentation only: the actual release still commits in its original skill
 # callback. The saved world-clock tail neither locks the body nor adds time.
 data.father.release_left=0.35
 data.father.release_point=xy(app.hero_pos)

func father_presentation() -> Dictionary:
 if not present("father"):return {}
 var father:Dictionary=data.father
 var phase:String=str(father.phase)
 var release:float=float(father.get("release_left",0.0))
 var label:String={"intro":"门口出现","approach":"接近 · 准备抓取","grab":"伸手抓取","steady":"已抓住 · 转身","drag":"抓握带行","stagger":"受阻 · 松手","rescued":"松手离开","leave":"离开","cat_approach":"接近黑猫","think":"抱猫劝说","kill_dog":"门口发动"}.get(phase,phase)
 if release>0:label="松手 · 收回手臂"
 return {"phase":phase,"label":label,"elapsed":float(father.elapsed),"facing":father.get("facing",[0.0,1.0]),"held":app.rules.gripped and phase in ["steady","drag"],"reach":clampf(float(father.elapsed)/float(config.timing.father_grab),0,1) if phase=="grab" else 1.0 if app.rules.gripped and phase in ["steady","drag"] else release/0.35,"release":release,"release_point":father.get("release_point",xy(app.hero_pos)),"moving":not father.route.is_empty()}

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
  start_release_pose()
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
 if data.is_empty() or data.startle.is_empty() or not data.startle.held or not app.rules.gripped:return
 var start:Array=data.startle.start
 if Vector2(float(start[0]),float(start[1])).distance_to(app.hero_pos)>0.001:
  start_release_pose()
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
   start_release_pose()
   app.rules.gripped=false;app.rules.change_sp(10)
   data.father.phase="stagger";data.father.elapsed=0.0
   var endpoint:Vector2=position("father")+offset.normalized()*0.3
   if app.layout.walkable(endpoint) and app.layout.clear_segment(position("father"),endpoint,app.layout.body_radius):data.father.pos=xy(endpoint)

func expel_father() -> void:
 data.father.phase="leave";data.father.route=[];data.blood_door=false;data.pressure=0
 data.father.departure_reflection_pending=true
 app.add_dialogue("角色 · 大吼","滚!!!滚!!!滚!!!给我滚出去!!!")
 app.add_dialogue("父亲 · 无所谓","啊...这家伙翅膀硬了呀...哟吼吼...哈哈哈哈哈")
 app.add_dialogue("角色 · 愤怒盯着","... ...")
 app.add_dialogue("父亲 · 冷漠","... ...")
 app.add_dialogue("父亲 · 妥协","行吧...臭小子")

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
   data.eating_serial=int(data.get("eating_serial",0))+1
   data.eating={"item":id,"elapsed":0.0,"started":false,"serial":data.eating_serial};data.auto_food_used=true;return true
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
 app.hero_route=app.layout.path(app.hero_pos,app.layout.door_position())
 return true

func advance_gift(delta:float) -> void:
 if app.rules.hp<=0 or app.rules.gripped or app.rules.body_busy():return
 if app.hero_route.is_empty() and app.hero_pos.distance_to(app.layout.door_position())>.05:
  app.hero_route=app.layout.path(app.hero_pos,app.layout.door_position())
 app.move_hero(delta)
 if app.hero_pos.distance_to(app.layout.door_position())>0.05:return
 data.gift_pick+=delta
 if float(data.gift_pick)<float(config.test_parameters.gift_pickup):return
 for id in data.gift.duplicate():
  if app.rules.commit_transfer("gift_pick:"+id,id,"floor","hero",app.hero_pos.distance_to(app.layout.door_position()),true,true,true):
   data.inventory.append(id);data.gift.erase(id)
   app.rules.observe("物品",id,"实际拾取门口礼物："+str(data.food_types[id])+"，尚未食用。")
 data.picking_gift=false;data.auto_food_used=false

func advance_eating(delta:float) -> void:
 if app.rules.hp<=0 or app.rules.stun_left>0 or app.rules.gripped:data.eating.clear();return
 if app.rules.body_busy():return
 if not data.eating.get("started",false):
  data.eating.started=true
  app.audio.cue("SFX_SEARCH_CLOTH","eat_prepare:%s:%d"%[data.eating.item,int(data.eating.get("serial",0))])
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
  app.vitality_panel.action_completed(receipt)
  on_node(receipt)
  if app.rules.hp>0 and not collapse_active():
   # Neutral original alternatives, with no invented food/DRYMOUTH meaning.
   var selected:int=app.rng.randi_range(0,dialogue.FOOD_TASTE.lines.size()-1)
   if not data.has("food_feedback"):data.food_feedback={}
   data.food_feedback[receipt]=selected
   app.add_dialogue(str(dialogue.FOOD_TASTE.speaker),str(dialogue.FOOD_TASTE.lines[selected]))
 data.eating.clear()

func lock_collapse() -> void:
 if collapse_active():return
 data.collapse={"elapsed":0.0,"index":0,"first":str(data.get("spawn_order",["mother"])[0])}
 app.rules.cancel_search();app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.action.clear()
 app.rules.end_control();app.rules.hp=0;app.rules.sp=0
 app.first_damage=true;app.first_damage_pending=false
 app.vitality_panel.damaged();app.vitality_panel.present_after_feedback()
 data.eating.clear();data.mother_rest=false;data.blood_door=false
 app.hero_route=PackedVector2Array();app.motion.clear();app.dialogue_queue.clear()
 app.action_phase="collapse";app.action_left=0;app.hero_state="hit"
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
