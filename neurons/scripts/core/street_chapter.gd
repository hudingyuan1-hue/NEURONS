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
const Displays=preload("res://scripts/core/street_displays.gd")
var displays
const Archivist=preload("res://scripts/core/street_archivist.gd")
var archivist
const Reports=preload("res://scripts/core/street_reports.gd")
var report_signals
const LaundryBag=preload("res://scripts/core/street_laundry_bag.gd")
var laundry_bag
const Losses=preload("res://scripts/core/street_losses.gd")
var losses
const Clamp=preload("res://scripts/core/street_clamp.gd")
var clamp
const Embrace=preload("res://scripts/core/street_embrace.gd")
var embrace
const Medicine=preload("res://scripts/core/street_medicine.gd")
var medicine
const Splash=preload("res://scripts/core/street_splash.gd")
var splash
const Bottle=preload("res://scripts/core/street_bottle.gd")
var bottle
const Belt=preload("res://scripts/core/street_belt.gd")
var belt
const Restraint=preload("res://scripts/core/street_restraint.gd")
var restraint
const GraspMotion=preload("res://scripts/core/street_grasp_motion.gd")
var grasp_motion
const Director=preload("res://scripts/core/street_director.gd")
var director
const Mother=preload("res://scripts/core/street_mother.gd")
var mother
const LocalSweeps=preload("res://scripts/core/street_sweeps.gd")
var local_sweeps

func _init(owner) -> void:
 super(owner);map=StreetMap;chapter_id=6;box=Box.new(self);lateral_bed=LateralBed.new(self);materials=Materials.new(self);displays=Displays.new(self);archivist=Archivist.new(self);report_signals=Reports.new(self);laundry_bag=LaundryBag.new(self);losses=Losses.new(self);clamp=Clamp.new(self);embrace=Embrace.new(self);medicine=Medicine.new(self);splash=Splash.new(self);bottle=Bottle.new(self);belt=Belt.new(self);restraint=Restraint.new(self);grasp_motion=GraspMotion.new(self);director=Director.new(self)
 mother=Mother.new(self);local_sweeps=LocalSweeps.new(self)
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
 displays.normalize()
 archivist.state()
 report_signals.normalize()
 laundry_bag.sync()
 losses.state()
 clamp.sync()

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
 if int(app.session.data.level)==chapter_id:materials.tick();displays.tick(delta);archivist.tick();report_signals.tick(delta);losses.tick(delta)

func _actor(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 if id=="mother":
  mother.before_actor();super._actor(id,delta);mother.sync();return
 if id in LocalSweeps.IDS:
  local_sweeps.before_actor(id);super._actor(id,delta);local_sweeps.sync(id);return
 if id=="director":
  director.before_actor();super._actor(id,delta);director.sync();return
 if id in GraspMotion.IDS:
  grasp_motion.before_actor(id)
  if not data.ending.is_empty():return
  if a.phase=="grip" and data.holder==id:grasp_motion.tick_hold(id,delta);return
  super._actor(id,delta);grasp_motion.sync(id);return
 if id=="assistant_asylum":
  if restraint.before_actor(delta):return
  super._actor(id,delta);restraint.sync();return
 if id=="warder":
  belt.before_actor();super._actor(id,delta);belt.sync();return
 if id=="father":
  bottle.before_actor();super._actor(id,delta);bottle.sync();return
 if id=="pharmacist":
  splash.before_actor()
  if a.portions>0 or a.phase!="idle":super._actor(id,delta)
  elif a.present and a.hp>0:
   if a.hurt>0:a.hurt=maxf(0,float(a.hurt)-delta)
   else:_yield(id,delta)
  splash.tick(delta);splash.sync();return
 if id=="labor":box.tick(delta);return
 if id=="transporter_asylum":lateral_bed.actor(delta);return
 if id=="transporter_hospital":
  laundry_bag.sync()
  super._actor(id,delta);laundry_bag.sync();return
 if id=="dislocated":
  clamp.before_actor();super._actor(id,delta);clamp.sync();return
 if id=="isolation":
  embrace.before_actor();super._actor(id,delta);embrace.sync();return
 if id=="ward_nurse":medicine.before_actor()
 if not a.present:return
 if id=="archivist_asylum" and archivist.actor(delta):return
 if displays.actor(id,delta):return
 if materials.actor(id,delta):return
 if id=="stitched" and materials.prepare_stitched(delta):return
 if a.hp<=0:return
 if id=="ward_nurse" and a.phase=="drug_hold":
  medicine.tick_hold(delta);return
 if id in ["pharmacist","ward_nurse"] and int(a.portions)<=0 and a.phase=="idle":
  _yield(id,delta);return
 if id in ["head_nurse","informant"]:
  _report(id,delta);return
 if str(spec(id).attack).is_empty():
  if a.hurt>0:a.hurt=maxf(0,float(a.hurt)-delta);return
  if a.room==app.room_id:
   a.phase="display"
   _yield(id,delta)
  return
 super._actor(id,delta)
 if id=="ward_nurse":medicine.sync()

func attack_start_distance(id:String,attack:Dictionary) -> float:
 if id=="mother":return float(config.test_parameters.mother_start_m)
 if id in LocalSweeps.IDS:return float(attack.reach)
 # Stop inside actual bag reach, rather than repeatedly swinging from the
 # generic rectangle's extra approach margin with no possible body contact.
 if id=="transporter_hospital":return float(attack.reach)
 if id=="director":return float(config.test_parameters.director_start_m)
 if id in GraspMotion.IDS:return float(config.test_parameters.grasp_start_m)
 if id=="assistant_asylum":return float(config.test_parameters.restraint_start_m)
 if id=="dislocated":return float(config.test_parameters.clamp_start_m)
 if id=="isolation":return float(config.test_parameters.embrace_start_m)
 if id=="ward_nurse":return float(config.test_parameters.medicine_start_m)
 if id=="pharmacist":return float(attack.reach)
 if id in ["father","warder"]:return float(attack.reach)
 return super.attack_start_distance(id,attack)

func _advance_attack(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id];var previous:String=str(a.phase)
 if id=="mother":
  if a.phase=="attack":
   mother.prepare(delta);a.elapsed+=delta;mother.resolve_contact()
   if a.phase=="attack" and a.elapsed>=float(config.attacks.grab.active):a.phase="recover";a.elapsed=0.0
  else:super._advance_attack(id,delta)
  mother.sync();return
 if id in LocalSweeps.IDS:
  local_sweeps.prepare(id,delta);super._advance_attack(id,delta);local_sweeps.sync(id);return
 if id=="director":
  director.prepare(delta);super._advance_attack(id,delta);director.sync();return
 if id in GraspMotion.IDS:
  grasp_motion.prepare(id,delta);super._advance_attack(id,delta)
  if previous=="attack" and a.phase=="grip" and data.holder==id:grasp_motion.begin_hold(id)
  grasp_motion.sync(id);return
 if id=="assistant_asylum":
  restraint.prepare(delta);super._advance_attack(id,delta);restraint.sync();return
 if id=="warder":
  belt.prepare(delta);super._advance_attack(id,delta);belt.sync();return
 if id=="father":
  bottle.prepare(delta);super._advance_attack(id,delta);bottle.sync();return
 if id=="transporter_hospital":
  laundry_bag.prepare_step(delta);super._advance_attack(id,delta);laundry_bag.finish_step(previous);return
 if id=="dislocated":
  clamp.prepare(delta);super._advance_attack(id,delta);clamp.finish(previous);return
 if id=="isolation":
  embrace.prepare(delta);super._advance_attack(id,delta);embrace.finish();return
 if id=="ward_nurse" and previous=="attack":
  medicine.advance_head(delta);return
 if id=="pharmacist":
  if previous=="attack":
   a.elapsed+=delta
   if a.elapsed>=float(config.attacks.splash.active):a.phase="recover";a.elapsed=0
  else:
   super._advance_attack(id,delta)
   if previous=="windup" and a.phase=="attack":splash.launch()
  splash.sync();return
 super._advance_attack(id,delta)
 if id=="ward_nurse":medicine.sync()

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

func _report_receivers(id:String) -> Array:return report_signals.receivers(id)
func _report(id:String,delta:float) -> void:report_signals.actor(id,delta)

func can_see(room:String,from:Vector2,to:Vector2) -> bool:
 if not super.can_see(room,from,to):return false
 var blind:Dictionary=data.get("actors",{}).get("blind",{})
 if not blind.is_empty() and blind.present and blind.hp>0 and blind.room==room and blind.phase=="cloth":
  if floor_for(room).segment_hits_rect(from,to,Rect2(position("blind")-Vector2(.6,.2),Vector2(1.2,1.0))):return false
 return true

func move_hero(delta:float) -> void:super.move_hero(delta*(1+.05*int(data.speed_stacks)))

func bed_blocks(room:String,point:Vector2,radius:float,exclude:String="") -> bool:
 return super.bed_blocks(room,point,radius,exclude) or (exclude!="transporter_asylum" and lateral_bed.touches(room,point,radius)) or displays.blocks(room,point,radius,exclude)

func _entry_point(from:String,to:String,offset:float) -> Vector2:
 var entry:Dictionary=floor_for(to).portal(from);var inward:Vector2=entry.inward
 return Vector2(entry.landing)+Vector2(-inward.y,inward.x)*offset

func _landing_clear(from:String,to:String,offset:float) -> bool:
 if to not in map.rooms():return true
 var point:Vector2=_entry_point(from,to,offset)
 if not floor_for(to).walkable(point) or bed_blocks(to,point,.21):return false
 for id in data.actors:
  var a:Dictionary=data.actors[id]
  if a.present and a.hp>0 and a.room==to and point.distance_to(position(str(id)))<.43:return false
 return true

func hero_portal(to:String) -> Dictionary:
 var portal:Dictionary=app.layout.portal(to).duplicate()
 if portal.is_empty():return portal
 var inward:Vector2=portal.inward;var tangent:=Vector2(-inward.y,inward.x)
 var side:float=maxf(0,float(portal.width_m)*.5-app.layout.body_radius-.02)
 for offset in [0.0,-side,side,-side*.5,side*.5]:
  var shift:Vector2=tangent*float(offset);var free:bool=true
  for key in ["at","threshold","landing"]:
   var point:Vector2=Vector2(portal[key])+shift
   if not app.layout.walkable(point) or bed_blocks(app.room_id,point,.21):free=false;break
   for id in data.actors:
    var a:Dictionary=data.actors[id]
    if a.present and a.hp>0 and a.room==app.room_id and point.distance_to(position(str(id)))<.43:free=false;break
  if not free or not _landing_clear(app.room_id,to,-float(offset)):continue
  for key in ["at","threshold","landing"]:portal[key]=Vector2(portal[key])+shift
  portal.lane_offset=float(offset);return portal
 return portal # Every real lane is occupied: wait, never bypass the collision.

func cross_door(to:String) -> void:
 var mouth:Dictionary=app.layout.portal(to);var outward:Vector2=-Vector2(mouth.inward)
 var offset:float=(app.hero_pos-Vector2(mouth.at)).dot(Vector2(-outward.y,outward.x))
 if not _landing_clear(app.room_id,to,offset):data.door_left=.1;return
 var from:String=app.room_id;var entry:Vector2=_entry_point(from,to,offset)
 app.enter_room(to);app.hero_pos=entry;app.keep_metric_actor_visible()

func _hero(delta:float) -> void:
 lateral_bed.normalize()
 var patches:Array=[];var space=app.layout
 if displays.chair_present(app.room_id):patches.append(lateral_bed.push_blocker(space,displays.chair_rect(position("wheelchair"))))
 if data.actors.transporter_asylum.present and data.lateral_bed.room==app.room_id:
  var bed:Dictionary=data.lateral_bed
  patches.append(lateral_bed.push_blocker(space,lateral_bed.rect(),{"at":lateral_bed.anchor(vector(bed.center),vector(bed.axis)),"axis":vector(bed.axis)}))
 super._hero(delta)
 patches.reverse()
 for patch in patches:lateral_bed.pop_blocker(space,patch)

func _contains(id:String,target:Vector2) -> bool:
 if id=="mother":return mother.contains(target)
 if id in LocalSweeps.IDS:return local_sweeps.contains(id,target)
 if id=="director":return director.contains(target)
 if id in GraspMotion.IDS:return grasp_motion.contains(id,target)
 if id=="assistant_asylum":return restraint.contains(target)
 if id=="warder":return belt.contains(target)
 if id=="father":return bottle.contains(target)
 if id=="pharmacist":return splash.contains(target)
 if id=="ward_nurse":return medicine.contains(target)
 if id=="isolation":return embrace.contains(target)
 if id=="dislocated":return clamp.contains(target)
 if id=="transporter_hospital":return laundry_bag.contains(target)
 if id=="transporter_asylum":return lateral_bed.touches(str(data.actors[id].room),target,.21)
 return super._contains(id,target)

func damage_actor(source:String,target:String,hp:int,receipt:String) -> void:
 var alive:bool=data.actors[target].hp>0
 super.damage_actor(source,target,hp,receipt)
 if alive and hp>0:materials.add_trace(str(data.actors[target].room),position(target),receipt)
 if target=="dislocated":clamp.before_actor()
 if target=="isolation":embrace.before_actor()
 if target=="ward_nurse":medicine.before_actor()
 if target=="pharmacist":splash.before_actor()
 if target=="father":bottle.before_actor()
 if target=="warder":belt.before_actor()
 if target=="assistant_asylum":restraint.before_actor(0)
 if target in GraspMotion.IDS:grasp_motion.before_actor(target)
 if target=="director":director.before_actor()
 if target=="mother":mother.before_actor()
 if target in LocalSweeps.IDS:local_sweeps.before_actor(target)
 losses.record(source,target,alive,receipt)

func _damage_hero(receipt:String,hp:int,sp:int,source:String) -> bool:
 var paid:bool=super._damage_hero(receipt,hp,sp,source)
 if paid and hp>0:materials.add_trace(app.room_id,app.hero_pos,receipt)
 return paid

func kick_contact() -> void:
 var old:Dictionary={}
 for id in data.actors:old[id]={"hp":data.actors[id].hp,"pos":data.actors[id].pos.duplicate()}
 super.kick_contact()
 for id in data.actors:
  var a:Dictionary=data.actors[id]
  if int(a.hp)>=int(old[id].hp):continue
  if id=="director":director.before_actor()
  if id=="mother":mother.before_actor()
  if id in LocalSweeps.IDS:local_sweeps.before_actor(id)
  if id=="transporter_asylum":
   var space=floor_for(str(a.room));var b:Dictionary=data.lateral_bed
   var patch:Dictionary=lateral_bed.push_blocker(space,lateral_bed.rect(),{"at":lateral_bed.anchor(vector(b.center),vector(b.axis)),"axis":vector(b.axis)})
   a.pos=xy(space.clipped_step(vector(old[id].pos),vector(a.pos)))
   lateral_bed.pop_blocker(space,patch)
  materials.add_trace(str(a.room),position(str(id)),str(app.rules.action.id)+":"+str(id))

func exit_crossed() -> void:
 if app.rules.hp<=0 or not data.ending.is_empty():return
 var id:String="E3" if int(app.rules.control_ms)>=120000 else "E2"
 var receipt:String="ending:%s:%s"%[id,str(app.session.data.get("key_seed_root",app.invader_id))]
 app.rules.settled[receipt]=id
 data.boundary=true;data.speed_stacks=0
 losses.close_attempt()
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
