extends "res://scripts/core/combat_chapter.gd"
## S1 Street + S4 contact rules. All 45 identities exist; no probability pool.
const StreetMap=preload("res://scripts/core/street_map.gd")
const StreetFloor=preload("res://scripts/world/street_layout.gd")
const Box=preload("res://scripts/core/street_box.gd")
var box
const LateralBed=preload("res://scripts/core/street_lateral_bed.gd")
var lateral_bed
const Materials=preload("res://scripts/core/street_materials.gd")
var materials

func _init(owner) -> void:
 super(owner);map=StreetMap;chapter_id=6;box=Box.new(self);lateral_bed=LateralBed.new(self);materials=Materials.new(self)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/street_chapter.json"))

func floor_for(room:String):
 if not layouts.has(room):
  layouts[room]=StreetFloor.new(room)
  for prop in layouts[room].furniture:
   var saved:Array=data.get("prop_rects",{}).get(room,{}).get(str(prop.id),[])
   if saved.size()==4:prop.rect=Rect2(saved[0],saved[1],saved[2],saved[3])
  layouts[room].rebuild_grid()
 return layouts[room]

func start() -> void:
 super.start()
 data.speed_deaths={};data.speed_stacks=0;data.ending={};data.pending_ending_achievements=[];data.box={};data.reports={}
 for s in config.actors:
  var a:Dictionary=data.actors[s.id];a.present=true;a.pending=false;a.pos=s.position_trial.duplicate();a.room=s.room
  var space=floor_for(str(s.room));var at:Vector2=position(str(s.id))
  var occupied:Array=[]
  for previous in data.actors:
   if str(previous)==str(s.id):break
   if data.actors[previous].room==s.room:occupied.append(position(previous))
  var best:Vector2=at;var distance:float=INF
  for y in range(12,ceili(space.world_size().y*10)-8,4):
   for x in range(20,ceili(space.world_size().x*10)-8,4):
    var candidate:=Vector2(x*.1,y*.1)
    if not space.walkable(candidate):continue
    var clear:bool=true
    for other in occupied:
     if candidate.distance_to(other)<.6:clear=false;break
    if clear and candidate.distance_squared_to(at)<distance:best=candidate;distance=candidate.distance_squared_to(at)
  a.pos=xy(best)
  a.home=a.pos.duplicate();a.portions=2 if s.id=="pharmacist" else 1 if s.id=="ward_nurse" else 0
  a.report_left=0.0;a.report_elapsed=0.0;a.report_target=[];a.cloth_clock=-6.0
 box.normalize()
 lateral_bed.normalize()
 materials.normalize()

func on_enter(from:String,room:String) -> void:
 data.route_left=0.0;data.door_left=-1.0;data.destination="";data.controlled_door="";app.controlled_route=false
 if not from.is_empty():
  for id in data.actors:
   var a:Dictionary=data.actors[id]
   if not a.present or a.hp<=0 or a.room!=from:continue
   if str(id)!="dog" and not a.hostile:continue
   if str(id)=="dog" or float(data.clock)-float(a.last_seen_at)<.5:a.follow=room
 var receipt:String="explored:6:"+room
 if not app.session.data.receipts.has(receipt):
  app.session.data.receipts[receipt]=true;app.rules.neurons+=1
  app.rules._record("scene_first_explored",receipt,{"level":6,"room":room,"neurons":1})

func _spawn() -> void:pass

func tick(delta:float) -> void:
 if not data.ending.is_empty():return
 super.tick(delta)
 if int(app.session.data.level)==chapter_id:materials.tick()

func _actor(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 if id=="labor":box.tick(delta);return
 if id=="transporter_asylum":lateral_bed.actor(delta);return
 if not a.present:return
 if materials.actor(id,delta):return
 if id=="stitched" and materials.prepare_stitched(delta):return
 if a.hp<=0:return
 if id=="ward_nurse" and a.phase=="drug_hold":
  a.elapsed+=delta
  if data.holder!=id:a.phase="recover";a.elapsed=0;return
  if a.hurt>0 or app.rules.hurt_left>0 or app.rules.stun_left>0:data.holder="";app.rules.gripped=false;a.phase="recover";a.elapsed=0;return
  if a.elapsed>=1.0 and float(app.rules.effects.get("DRYMOUTH",0))<=0 and int(a.portions)>0 and app.rules.hp>0:
   a.portions=0;app.rules.change_sp(-20);app.rules.stun_left=maxf(app.rules.stun_left,1.5)
   app.rules._record("street_medicine_swallowed",str(a.attack_id)+":swallow",{"sp":-20,"source":"S4:T16R4"})
   data.holder="";app.rules.gripped=false;data.grip_safe_until=data.clock+.8;a.phase="recover";a.elapsed=0
  return
 if id in ["pharmacist","ward_nurse"] and int(a.portions)<=0 and a.phase=="idle":
  _yield(id,delta);return
 if id in ["head_nurse","informant"]:
  _report(id,delta);return
 if str(spec(id).attack).is_empty():
  if a.hurt>0:a.hurt=maxf(0,float(a.hurt)-delta);return
  if a.room==app.room_id:
   a.phase="display"
   if id=="blind":a.cloth_clock=fmod(float(a.cloth_clock)+delta,10.0);a.phase="cloth" if a.cloth_clock>=0 and a.cloth_clock<4 else "idle"
   if id=="mimic" and data.clock-float(a.get("mimic_last",-10))>=3 and can_see(str(a.room),position(id),app.hero_pos) and position(id).distance_to(app.hero_pos)<6:
    if app.hero_state in ["walk","hit","scratch","give"]:a.mimic=app.hero_state;a.mimic_last=data.clock;a.phase="mimic"
   _yield(id,delta)
  return
 super._actor(id,delta)

func _advance_attack(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id];var previous:String=str(a.phase)
 if id=="ward_nurse" and previous=="attack":
  a.elapsed+=delta
  if a.room==app.room_id and _contains(id,app.hero_pos) and not a.hits.has("hero") and data.holder=="" and a.portions>0:
   a.hits.hero=true;data.holder=id;data.grip_until=data.clock+1.2;app.rules.gripped=true;a.phase="drug_hold";a.elapsed=0;return
  if a.elapsed>=.3:a.phase="recover";a.elapsed=0
  return
 super._advance_attack(id,delta)
 if id=="pharmacist" and previous=="windup" and a.phase=="attack":a.portions=maxi(0,int(a.portions)-1)
 if id in ["psychiatrist","guard_hospital"] and a.hits.has("hero") and not a.get("displacement_done",false):
  a.displacement_done=true
  var direction:Vector2=vector(a.direction)*(-1 if id=="psychiatrist" else 1)
  app.hero_pos=app.layout.clipped_step(app.hero_pos,app.hero_pos+direction)
 if previous=="idle" or a.phase=="idle":a.displacement_done=false

func _friend(id:String,delta:float) -> void:
 if id in ["dog","faceless"]:super._friend(id,delta);return
 if id=="corner":
  var enemy:String=materials.danger(id)
  if not enemy.is_empty():
   var corner:Dictionary=data.actors[id];corner.phase="idle"
   var away:Vector2=(position(id)-position(enemy)).normalized()
   for side in [away,Vector2(away.y,-away.x),Vector2(-away.y,away.x)]:
    var goal:Vector2=position(id)+side*.65
    if app.layout.walkable(goal) and goal.distance_to(app.hero_pos)>.6:_move_actor(id,goal,delta);break
   return
 if id=="nurse":
  for other in data.actors:
   var a:Dictionary=data.actors[other]
   if a.hp>0 and a.hostile and a.room==app.room_id and can_see(app.room_id,position(other),app.hero_pos) and position(other).distance_to(app.hero_pos)<6:return
  super._friend(id,delta);return
 var a:Dictionary=data.actors[id];a.phase="point" if id=="corner" else "display"
 var entry:String=str(map.doors(app.room_id)[0]);a.direction=xy((map.doorway(app.room_id,entry)-position(id)).normalized())
 _yield(id,delta)

func _yield(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 if a.room!=app.room_id or position(id).distance_to(app.hero_pos)>.9:return
 var away:Vector2=(position(id)-app.hero_pos).normalized()
 for offset in [away,Vector2(0,-1),Vector2(0,1)]:
  var goal:Vector2=position(id)+offset*.7
  if app.layout.walkable(goal):_move_actor(id,goal,delta);return

func _report(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 a.report_left=maxf(0,float(a.report_left)-delta)
 if a.hurt>0:a.hurt=maxf(0,float(a.hurt)-delta);a.report_elapsed=0;a.report_target=[];return
 if a.room!=app.room_id:return
 if a.report_target.is_empty():
  if a.report_left>0 or not can_see(app.room_id,position(id),app.hero_pos) or position(id).distance_to(app.hero_pos)>6:return
  a.report_target=xy(app.hero_pos);a.report_elapsed=0;a.phase="point"
  if id=="head_nurse":app.audio.cue("SFX_DRAWER","board:%d:%d"%[app.rules.actual_attempt,int(data.clock)])
 a.report_elapsed+=delta
 if a.report_elapsed<1:return
 for other in data.actors:
  var b:Dictionary=data.actors[other]
  if other==id or not b.hostile or b.hp<=0 or b.room!=a.room or str(other) in ["father","mother","cat","self","reverse","skinface","twitch"]:continue
  if position(other).distance_to(position(id))<=6 and can_see(str(a.room),position(other),position(id)):
   b.investigation={"room":a.room,"at":a.report_target.duplicate(),"receipt":"report:"+id}
 a.report_target=[];a.report_elapsed=0;a.report_left=8;a.phase="idle"

func can_see(room:String,from:Vector2,to:Vector2) -> bool:
 if not super.can_see(room,from,to):return false
 var blind:Dictionary=data.get("actors",{}).get("blind",{})
 if not blind.is_empty() and blind.hp>0 and blind.room==room and blind.phase=="cloth":
  if floor_for(room).segment_hits_rect(from,to,Rect2(position("blind")-Vector2(.6,.2),Vector2(1.2,1.0))):return false
 return true

func move_hero(delta:float) -> void:super.move_hero(delta*(1+.05*int(data.speed_stacks)))

func bed_blocks(room:String,point:Vector2,radius:float,exclude:String="") -> bool:
 return super.bed_blocks(room,point,radius,exclude) or (exclude!="transporter_asylum" and lateral_bed.touches(room,point,radius))

func _hero(delta:float) -> void:
 lateral_bed.normalize()
 if not data.actors.transporter_asylum.present or data.lateral_bed.room!=app.room_id:super._hero(delta);return
 var space=app.layout;var bed:Dictionary=data.lateral_bed
 var patch:Dictionary=lateral_bed.push_blocker(space,lateral_bed.rect(),{"at":lateral_bed.anchor(vector(bed.center),vector(bed.axis)),"axis":vector(bed.axis)})
 super._hero(delta)
 lateral_bed.pop_blocker(space,patch)

func _contains(id:String,target:Vector2) -> bool:
 if id=="transporter_asylum":return lateral_bed.touches(str(data.actors[id].room),target,.21)
 return super._contains(id,target)

func damage_actor(source:String,target:String,hp:int,receipt:String) -> void:
 var alive:bool=data.actors[target].hp>0
 super.damage_actor(source,target,hp,receipt)
 if alive and hp>0:materials.add_trace(str(data.actors[target].room),position(target),receipt)
 if not alive or data.actors[target].hp>0 or target not in config.good_ids or data.speed_deaths.has(target):return
 var witnessed:bool=data.actors[target].room==app.room_id and position(target).distance_to(app.hero_pos)<=float(config.test_parameters.hero_vision_m) and can_see(app.room_id,app.hero_pos,position(target)) and can_see(app.room_id,app.hero_pos,position(source))
 var old_stacks:int=int(data.speed_stacks)
 data.speed_deaths[target]={"source":source,"receipt":receipt,"witnessed":witnessed}
 if app.rules.hp>0 and not str(spec(source).attack).is_empty():data.speed_stacks=mini(3,int(data.speed_stacks)+1)
 app.rules._record("street_good_death",receipt+":growth",{"target":target,"source":source,"stacks":data.speed_stacks,"qualified":app.rules.hp>0,"witnessed":witnessed})
 if int(data.speed_stacks)>old_stacks:
  app.status_note="身体的步伐明显加快；已成立的移动变化不会解除抓握或恢复伤情。"
  app.rules.observe("角色","street_speed:%d:%d"%[app.rules.actual_attempt,data.speed_stacks],"实际感觉步伐加快；未因此自动确定未目击的死者或凶手。","亲历事实","S3:P1934–1942")

func _damage_hero(receipt:String,hp:int,sp:int,source:String) -> bool:
 var paid:bool=super._damage_hero(receipt,hp,sp,source)
 if paid and hp>0:materials.add_trace(app.room_id,app.hero_pos,receipt)
 return paid

func exit_crossed() -> void:
 if app.rules.hp<=0 or not data.ending.is_empty():return
 var id:String="E3" if int(app.rules.control_ms)>=120000 else "E2"
 var receipt:String="ending:%s:%s"%[id,str(app.session.data.get("key_seed_root",app.invader_id))]
 app.rules.settled[receipt]=id
 data.boundary=true;data.speed_stacks=0
 data.ending={"id":id,"phase":"registration","elapsed":0.0,"complete":false,"dialogue_sent":false,"receipt":receipt}
 data.pending_ending_achievements=["player_wins" if id=="E3" else "character_wins"]
 var controlled:bool=false
 for fact in app.rules.facts:
  if fact.kind=="skill_reacted" and str(fact.get("skill",""))=="CONTROL":controlled=true
 if id=="E2" and not controlled:data.pending_ending_achievements.append("autonomous_main_clear")
 app.rules._record("ending",receipt,{"ending":id,"level":6,"institutional_claim":"自行离院","hp":app.rules.hp,"sp":app.rules.sp})
 app.rules.institutional_records.append({"id":receipt,"text":"自行离院","source":"终点机构登记；不覆盖实际伤亡"})
 app.rules.end_control();app.rules.action.clear();app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.transitioning=true
 app.hero_route=PackedVector2Array();app.motion.clear();app.dialogue_queue.clear();app.show_dialogue()

func advance_ending(delta:float) -> void:
 if data.ending.is_empty() or app.paused_manual or app.menu.visible or app.audio_panel.visible or app.closing_left>0:return
 var e:Dictionary=data.ending
 app.audio.cue("MUS_END",str(e.receipt)+":music")
 if not data.pending_ending_achievements.is_empty():
  var result:Dictionary=app.achievements.grant_main(data.pending_ending_achievements,str(e.receipt))
  if result.ok:data.pending_ending_achievements=[]
 if e.complete:return
 if e.phase=="registration" and e.elapsed>=1.5 and not e.dialogue_sent:
  e.dialogue_sent=true;e.phase="dialogue"
  var recognized:bool=app.rules.awareness_stage>=3
  app.add_dialogue("角色 · 冷淡" if recognized else "角色 · 低声","你还在？" if recognized else "出来了。")
  app.add_dialogue("玩家 · 低声" if recognized else "玩家 · 沉默","……在。" if recognized else "……")
 if e.phase=="dialogue":
  if not app.dialogue_queue.is_empty():return
  e.phase="wake";e.elapsed=0
 e.elapsed+=delta
 if e.phase=="wake" and e.elapsed>=3:e.phase="planet" if e.id=="E2" else "complete";e.elapsed=0
 if e.phase=="planet" and e.elapsed>=2:e.phase="complete"
 e.complete=e.phase=="complete"
