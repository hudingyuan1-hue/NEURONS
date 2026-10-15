extends RefCounted
## Natural L1 animal actions; saved primitive data, no sprite-frame callbacks.
var app
var enabled:bool=true
var data:Dictionary={}
var dialogue:Dictionary={}

func _init(owner) -> void:
 app=owner
 dialogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_dialogue.json")).groups

func start_attempt(fixture:Dictionary={}) -> void:
 var step:int=mini(4,maxi(0,app.rules.actual_attempt-1))
 var dog:bool=bool(fixture.get("dog",app.rng.randf()<0.40+step*0.05))
 var cat:bool=bool(fixture.get("cat",app.rng.randf()<0.35+step*0.05))
 var index:int=int(fixture.get("cat_point",app.rng.randi_range(0,10)))
 data={"dog":{"present":dog,"alive":true,"pos":[3.1,1.6],"phase":"idle","route":[],"target":-1,"left":0.0,"remaining":3},
  "cat":{"present":cat,"pos":xy(app.layout.furniture[index].at),"point":index,"rounds":0,"phase":"occupy","left":0.0,"route":[]},
  "fighting":dog and cat,"tracked_search":"","counted":{},"blocked_search":"","blocked_left":0.0,"dog_serial":0,"key_drop":[]}
 data.dialogue_choices={};data.dialogue_played={}
 if data.fighting:
  data.dog.pos=[3.15,1.6];data.cat.pos=[3.5,1.6]
 if not enabled:return
 if dog:app.rules.observe("人物","dog","大黄，戴着红项圈；本周目实际见到。")
 if cat:app.rules.observe("人物","cat","一只黑猫占着物件旁的位置。")
 if dog and cat:
  cue("DOG_CAT_FIGHT","arrival")
 elif dog:
  cue("DOG_OPEN","arrival")
  app.add_dialogue("大黄 · 可爱","汪...(●'◡'●)")
  app.add_dialogue("角色 · 开心","汪...大黄很可爱哦")
  app.add_dialogue("玩家 · 无语","我是在期待什么?...赶紧给我说正事啊喂")
  cue("DOG_HELP","request")
  app.add_dialogue("大黄 · 认真","汪!")
  app.add_dialogue("玩家 · 认真","这家伙现在是要找那小狗帮忙了...得注意一下")
  cue("DOG_THANK","initial")
 elif cat:
  cue("CAT_OPEN","arrival")

func cue(id:String,node:String,allowed:Array=[]) -> void:
 var key:String=id+":"+node
 if not data.has("dialogue_played"):data.dialogue_played={}
 if not data.has("dialogue_choices"):data.dialogue_choices={}
 if data.dialogue_played.has(key):return
 var variants:Array=dialogue[id].variants
 if not data.dialogue_choices.has(key):
  data.dialogue_choices[key]=app.rng.randi_range(0,variants.size()-1) if allowed.is_empty() else allowed[app.rng.randi_range(0,allowed.size()-1)]
 data.dialogue_played[key]=true
 for line in variants[int(data.dialogue_choices[key])]:app.add_dialogue(str(line.speaker),str(line.text))

func start_exploration_line() -> void:
 if app.session.has_key() or app.rules.mode!="exploration" or app.family.busy():return
 cue("S1_START","attempt",[] if app.rules.actual_attempt<=1 else [2,4])

func xy(p:Vector2) -> Array:
 return [p.x,p.y]

func position(id:String) -> Vector2:
 var p:Array=data[id].pos
 return Vector2(float(p[0]),float(p[1]))

func present(id:String) -> bool:
 return enabled and not data.is_empty() and bool(data[id].present)

func move(id:String,to:Vector2,delta:float,speed:float=1.0) -> bool:
 var actor:Dictionary=data[id]
 var route:=PackedVector2Array()
 for p in actor.route:route.append(Vector2(float(p[0]),float(p[1])))
 if route.is_empty() and position(id).distance_to(to)>0.04:route=app.layout.path(position(id),to)
 var result:Dictionary=app.layout.move_path(position(id),route,speed*delta)
 actor.pos=xy(result.position)
 actor.route=Array(result.route).map(func(p):return [p.x,p.y])
 return position(id).distance_to(to)<=0.04

func reserved(index:int) -> bool:
 return present("dog") and data.dog.phase in ["walk","search"] and int(data.dog.target)==index

func tick(delta:float) -> void:
 if not enabled or data.is_empty() or app.room_id!="bedroom" or app.session.data.level!=1:return
 if not data.fighting:
  track_hero_search(delta)
  advance_dog(delta)
 var cat:Dictionary=data.cat
 if cat.present and cat.phase=="attack":
  cat.left-=delta
  if cat.left<=0:
   var distance:float=position("cat").distance_to(app.hero_pos)
   if distance>0.4:
    move("cat",app.hero_pos,delta,2.0)
   elif app.rules.commit_hit("cat:%d"%app.rules.actual_attempt,distance,app.layout.clear_segment(position("cat"),app.hero_pos),true,true):
    app.rules.observe("人物","cat_hit:%d"%app.rules.actual_attempt,"黑猫实际抓伤了角色，生命和精神各降低10。")
    app.audio.cue("hit","cat:%d"%app.rules.actual_attempt)
    if app.rules.hp>0:cue("CAT_HIT_FEEDBACK","injury")
    leave_cat()
 if cat.present and cat.phase=="leave":
  if move("cat",Vector2(3.95,3.6),delta,1.8):
   cat.present=false
   if app.rules.hp>0:cue("CAT_EXIT","window")
   else:app.add_dialogue("黑猫","喵@#￥%……")

func track_hero_search(delta:float) -> void:
 var cat:Dictionary=data.cat
 var id:String=str(app.rules._search_id)
 if app.rules.search_active and id!=data.tracked_search:
  data.tracked_search=id
  if cat.present and cat.phase=="occupy" and app.target_index==int(cat.point):
   data.blocked_search=id
   data.blocked_left=0.5 # Visible attempted-contact test timing; no extra search.
 if not str(data.blocked_search).is_empty() and app.rules.search_active and data.blocked_search==id:
  data.blocked_left-=delta
  if data.blocked_left<=0 and cat.phase=="occupy":
   app.rules.cancel_search()
   app.hero_state="idle";app.target_index=-1
   cue("CAT_BLOCK",str(data.blocked_search))
   data.blocked_search=""
 if not str(data.tracked_search).is_empty() and app.rules.settled.has(data.tracked_search) and not data.counted.has(data.tracked_search):
  data.counted[data.tracked_search]=true
  if cat.present and cat.phase=="occupy":
   cat.rounds+=1
   if int(cat.rounds)>=3:leave_cat()

func anomaly(point:int,result:Dictionary) -> void:
 if not present("cat") or data.fighting or data.cat.phase!="occupy" or int(data.cat.point)!=point:return
 if not result.get("success",false) or result.get("id","")=="CONTROL":return
 data.cat.phase="attack";data.cat.left=0.22
 app.rules.cancel_search()
 data.blocked_search=""
 cue("CAT_HIT_START","scare")

func leave_cat() -> void:
 data.cat.phase="leave";data.cat.route=[]
 data.fighting=false

func advance_dog(delta:float) -> void:
 if not present("dog") or not data.dog.alive:return
 var dog:Dictionary=data.dog
 if app.has_key():dog.phase="idle";dog.route=[];return
 if dog.phase=="idle" and int(dog.remaining)>0 and app.rules.search_active:
  var choices:Array=[]
  for i in [0,2,10]: # Open bed underside / chair / exposed fan base. No sealed cabinets.
   var target:String="bedroom:%d"%i
   if target in app.session.data.targets and not target in app.completed and i!=app.target_index:choices.append(i)
  if not choices.is_empty():dog.target=choices[app.rng.randi_range(0,choices.size()-1)];dog.phase="walk";dog.route=[]
 if dog.phase=="walk":
  if move("dog",app.layout.furniture[int(dog.target)].at,delta,1.2):
   dog.phase="search";dog.left=4.0*(1.0-0.05*mini(4,app.rules.actual_attempt-1))
 if dog.phase=="search":
  dog.left-=delta
  if dog.left<=0:
   var target:String="bedroom:%d"%int(dog.target)
   var receipt:String="dog_search:%d:%s"%[app.rules.actual_attempt,target]
   if not app.rules._completed_targets.has(target):
    app.rules._completed_targets[target]=true;app.completed.append(target)
    app.rules.settled[receipt]="completed";app.rules.neurons+=1
    app.rules._record("dog_search_completed",receipt,{"target":target,"neurons":1})
   dog.remaining-=1
   if target==app.session.data.key_target:
    app.session.data.key_owner="dog";app.rules.owners.key="dog"
    dog.phase="bring";dog.route=[]
   else:
    dog.phase="idle"
    if int(dog.remaining)==0:cue("DOG_THANK","complete")
 if dog.phase=="bring":
  if move("dog",app.hero_pos,delta,1.2):
   dog.key_contact_pending=true

func settle_key_contact() -> void:
 # S5 R3: a search that reaches completion at this verdict is preserved.
 # Transfer then cancels only unfinished work; harmful contacts run first.
 if not enabled or data.is_empty() or app.room_id!="bedroom" or not data.dog.get("key_contact_pending",false):return
 data.dog.key_contact_pending=false
 if not present("dog") or not data.dog.alive or app.rules.hp<=0:return
 var receipt:String="dog_key:%d"%app.rules.actual_attempt
 if app.rules.commit_transfer(receipt,"key","dog","hero",position("dog").distance_to(app.hero_pos),app.layout.clear_segment(position("dog"),app.hero_pos),true,true):
  app.rules.cancel_search()
  app.hero_route=PackedVector2Array();app.target_index=-1
  app.session.data.key_seen=true;app.session.data.key_owner="hero"
  app.rules.observe("物品","key","大黄实际叼回并交付了一把钥匙。")
  data.dog.phase="idle";data.dog.route=[]
  cue("DOG_THANK","key")

func kill_dog() -> void:
 if not present("dog") or not data.dog.alive:return
 if app.session.data.key_owner=="dog":
  data.key_drop=xy(position("dog"))
  app.session.data.key_owner="floor";app.rules.owners.key="floor"
  app.session.data.key_seen=app.layout.clear_segment(position("dog"),app.hero_pos)
 data.dog.alive=false;data.dog.phase="dead";data.dog.route=[]
 data.fighting=false

func actors() -> Array:
 var result:Array=[]
 if not enabled or data.is_empty() or app.room_id!="bedroom":return result
 for id in ["dog","cat"]:
  if present(id):result.append({"type":"actor","data":id,"depth":app.layout.project(position(id)).y})
 return result
