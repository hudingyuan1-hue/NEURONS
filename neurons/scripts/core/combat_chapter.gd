extends RefCounted
## L5 state machine: unique actors, explicit contact receipts and real portals.
const Map=preload("res://scripts/core/combat_map.gd")
const Floor=preload("res://scripts/world/combat_layout.gd")
const Bed=preload("res://scripts/core/bed_body.gd")
const Reactions=preload("res://scripts/core/combat_reactions.gd")
var reactions
var map=Map
var chapter_id:int=5
const Noises=preload("res://scripts/core/combat_noises.gd")
var noises
const Observations=preload("res://scripts/core/combat_observations.gd")
var observations
var app
var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_chapter.json"))
var data:Dictionary={}
var layouts:Dictionary={}

func _init(owner) -> void:
 app=owner;reactions=Reactions.new(self);observations=Observations.new(self);noises=Noises.new(self)
func vector(a:Array) -> Vector2:return Vector2(float(a[0]),float(a[1]))
func xy(p:Vector2) -> Array:return [p.x,p.y]
func floor_for(room:String):
 if not layouts.has(room):
  layouts[room]=Floor.new(room,int(data.get("geometry_version",1))>=2)
  if data.has("prop_rects"):
   for id in data.prop_rects.get(room,{}):
    for f in layouts[room].furniture:
     if str(f.id)==str(id):
      var saved:Array=data.prop_rects[room][id];f.rect=Rect2(float(saved[0]),float(saved[1]),float(saved[2]),float(saved[3]))
   layouts[room].rebuild_grid()
 return layouts[room]
func spec(id:String) -> Dictionary:
 for entry in config.actors:
  if entry.id==id:return entry
 return {}
func position(id:String) -> Vector2:return vector(data.actors[id].pos)
func start() -> void:
 layouts.clear()
 data={"version":1,"geometry_version":2,"clock":0.0,"actors":{},"last_left":{},"last_spawn":{},"next_attack":0.0,"grip_until":0.0,"holder":"","grip_safe_until":0.0,"serial":0,"pulse_clock":0.0,"pulse_receipts":{},"route_left":0.0,"door_left":-1.0,"destination":"","boundary":false,"bandage_elapsed":0.0,"bandage_done":false,"cart_shift":0.0,"prop_rects":{}}
 for s in config.actors:
  data.actors[s.id]={"room":s.room,"pos":xy(Vector2(1.2,1.2)),"hp":s.hp,"present":s.id=="self","pending":false,"checks":0,"phase":"idle","elapsed":0.0,"cooldown":0.0,"direction":[1.0,0.0],"route":[],"goal":[],"last_seen":[],"last_seen_at":-100.0,"follow":"","attack_id":"","hits":{},"hostile":s.relation=="enemy","hurt":0.0,"face_turned":false,"attack_target":"hero"}
 data.actors.self.pos=xy(Vector2(7.3,4.8))
 reactions.normalize();observations.normalize();noises.normalize()

func on_enter(from:String,room:String) -> void:
 if data.is_empty():start()
 data.route_left=0.0;data.door_left=-1.0;data.destination=""
 data.controlled_door="";app.controlled_route=false
 if not from.is_empty():
  data.last_left[from]=data.clock
  for id in data.actors:
   var a:Dictionary=data.actors[id]
   if not a.present or a.hp<=0 or a.room!=from or map.deep(from)!=map.deep(room):continue
   if spec(str(id)).relation=="friend" and str(id)!="dog":continue
   if float(data.clock)-float(a.last_seen_at)>.5:continue
   var doorway:Vector2=map.doorway(from,room)
   if doorway.x>=0 and not a.last_seen.is_empty() and vector(a.last_seen).distance_to(doorway)<1.2:a.follow=room
 var receipt:String="explored:%d:"%chapter_id+room
 if not app.session.data.receipts.has(receipt):
  app.session.data.receipts[receipt]=true;app.rules.neurons+=1
  app.rules._record("scene_first_explored",receipt,{"level":chapter_id,"room":room,"neurons":1})
 if map.deep(room) or app.session.data.get("street_returning",false):return
 var chance:float=minf(.75,.55+.05*mini(4,app.rules.actual_attempt-1))
 for s in config.actors:
  if s.room!=room or s.id=="self":continue
  var a:Dictionary=data.actors[s.id]
  if a.present or a.pending or a.hp<=0 or int(a.checks)>=3:continue
  if int(a.checks)>0 and (not data.last_left.has(room) or float(data.clock)-float(data.last_left[room])<20.0):continue
  var probability:float=chance if int(a.checks)==0 else chance*.5
  a.checks+=1
  if app.rng.randf()<probability:a.pending=true

func _spawn() -> void:
 var room:String=app.room_id
 if app.session.data.get("street_returning",false):return
 if float(data.clock)-float(data.last_spawn.get(room,-100.0))<float(config.test_parameters.spawn_spacing_s):return
 var pending:Array=[]
 for id in data.actors:
  if data.actors[id].pending and data.actors[id].room==room:pending.append(id)
 if pending.is_empty():return
 # A batch enters through a free doorway; wait rather than spawn on the host.
 var portal:Dictionary=app.layout.portal(str(map.doors(room)[0]))
 var at:Vector2=portal.landing
 if at.distance_to(app.hero_pos)<1.3:return
 var offsets:Array=[Vector2.ZERO,Vector2(.5,.4),Vector2(-.5,.4)]
 for i in range(pending.size()):
  var a:Dictionary=data.actors[pending[i]];var candidate:Vector2=at+offsets[i%offsets.size()]
  if not app.layout.walkable(candidate):continue
  if str(pending[i])=="assistant":
   candidate=at+Vector2(portal.inward)*.8
   if not bed_clear(room,candidate,portal.inward):continue
   a.direction=xy(portal.inward)
  a.pos=xy(candidate);a.pending=false;a.present=true
  app.rules._record("combat_actor_arrived","combat:%d:arrive:%s"%[app.rules.actual_attempt,pending[i]],{"actor":pending[i],"room":room})
 data.last_spawn[room]=data.clock

func tick(delta:float) -> void:
 if data.is_empty() or int(app.session.data.level)!=chapter_id:return
 data.clock+=delta;data.pulse_clock+=delta
 _spawn()
 if not str(data.holder).is_empty() and data.clock>=data.grip_until:
  var holder:String=str(data.holder)
  if data.actors.has(holder):data.actors[holder].phase="recover";data.actors[holder].elapsed=0.0
  data.holder="";app.rules.gripped=false;data.grip_safe_until=data.clock+.8
 var left:float=delta
 while left>.000001 and app.rules.hp>0 and not data.get("boundary",false):
  var step:float=minf(.025,left);left-=step
  for id in data.actors:_actor(str(id),step)
  _pulse()
  if app.rules.hp>0:_hero(step)
  if int(app.session.data.level)!=chapter_id:return
 noises.tick(delta)
 reactions.tick(delta)
 observations.speak()

func _move_actor(id:String,goal:Vector2,delta:float) -> void:
 var a:Dictionary=data.actors[id];var space=floor_for(str(a.room));var at:Vector2=position(id)
 if at.distance_to(goal)<.05:return
 if a.goal.is_empty() or vector(a.goal).distance_to(goal)>.4 or a.route.is_empty():
  a.goal=xy(goal);a.route=[]
  var path:PackedVector2Array=space.path(at,goal)
  for p in path:a.route.append(xy(p))
 var path:=PackedVector2Array()
 for p in a.route:path.append(vector(p))
 var speed:float=float(config.test_parameters.actor_speed_m_s)*float(space.speed_factor(at))
 var moved:Dictionary=space.move_path(at,path,speed*delta)
 if id=="assistant" and moved.position.distance_to(at)>.00001:
  var facing:Vector2=(moved.position-at).normalized()
  var turn:Vector2=vector(a.direction).rotated(clampf(vector(a.direction).angle_to(facing),-float(config.test_parameters.bed_turn_rad_s)*delta,float(config.test_parameters.bed_turn_rad_s)*delta))
  var swept:Dictionary=bed_sweep(str(a.room),at,moved.position,vector(a.direction),turn)
  if not swept.complete:a.route=[];return
  a.direction=xy(turn)
 # Retain bodies as physical obstacles; wait or take a side instead of overlap.
 var blocked:bool=str(a.room)==app.room_id and moved.position.distance_to(app.hero_pos)<.43 and at.distance_to(app.hero_pos)>=.43
 for other in data.actors:
  if other==id:continue
  var b:Dictionary=data.actors[other]
  if b.present and b.hp>0 and b.room==a.room and moved.position.distance_to(position(other))<.42 and at.distance_to(position(other))>=.42:blocked=true
 if id!="assistant" and bed_blocks(str(a.room),moved.position,.25,id):blocked=true
 if id=="assistant":
  if str(a.room)==app.room_id and Bed.touches(moved.position,vector(a.direction),app.hero_pos,.23):blocked=true
  for other in data.actors:
   var body:Dictionary=data.actors[other]
   if other!=id and body.present and body.hp>0 and body.room==a.room and Bed.touches(moved.position,vector(a.direction),position(other),.25):blocked=true
 if blocked:
  a.route=[]
  for side in [Vector2(.4,.4),Vector2(-.4,.4),Vector2(.4,-.4),Vector2(-.4,-.4)]:
   var alternative:Vector2=at+side
   if space.walkable(alternative) and alternative.distance_to(app.hero_pos)>.6 and space.clear_segment(at,alternative,space.body_radius):
    var detour:Dictionary=space.move_path(at,PackedVector2Array([at,alternative]),speed*delta)
    a.pos=xy(detour.position);break
  return
 a.pos=xy(moved.position);a.route=[]
 for p in moved.route:a.route.append(xy(p))

func bed_rect(at:Vector2,direction:Vector2) -> Rect2:return Bed.bounds(at,direction)
func bed_portals(room:String) -> Array:
 var portals:Array=[]
 for to in map.doors(room):portals.append(floor_for(room).portal(str(to)))
 return portals
func bed_neighbor_clear(room:String,at:Vector2,direction:Vector2) -> bool:
 var size:Vector2=floor_for(room).world_size()
 var rect:Rect2=Bed.bounds(at,direction)
 if rect.position.x>=.15 and rect.position.y>=.15 and rect.end.x<=size.x-.15 and rect.end.y<=size.y-.15:return true
 for to in map.doors(room):
  var mouth:Dictionary=floor_for(room).portal(str(to))
  if (at-mouth.at).length()>2.3 or direction.dot(-Vector2(mouth.inward))<.7:continue
  if to==str(config.get("exit_id","street_exit")) or map.deep(room)!=map.deep(str(to)):return false
  var space=floor_for(str(to));var entry:Dictionary=space.portal(room)
  if not Bed.clear(space,entry.landing,entry.inward,bed_portals(str(to))):return false
  if str(to)==app.room_id and Bed.touches(entry.landing,entry.inward,app.hero_pos,.23):return false
  for other in data.actors:
   var body:Dictionary=data.actors[other]
   if other!="assistant" and body.present and body.hp>0 and body.room==to and Bed.touches(entry.landing,entry.inward,position(other),.25):return false
  return true
 return false
func bed_clear(room:String,at:Vector2,direction:Vector2) -> bool:return Bed.clear(floor_for(room),at,direction,bed_portals(room)) and bed_neighbor_clear(room,at,direction)
func bed_sweep(room:String,from:Vector2,to:Vector2,old_direction:Vector2,new_direction:Vector2) -> Dictionary:
 var swept:Dictionary=Bed.sweep(floor_for(room),from,to,old_direction,new_direction,bed_portals(room))
 var at:Vector2=from;var direction:Vector2=old_direction;var accepted:Array=[]
 for pose in swept.poses:
  if not bed_neighbor_clear(room,pose.at,pose.direction):return {"position":at,"direction":direction,"complete":false,"poses":accepted}
  at=pose.at;direction=pose.direction;accepted.append(pose)
 return swept
func bed_blocks(room:String,point:Vector2,radius:float,exclude:String="") -> bool:
 var a:Dictionary=data.actors.assistant
 return exclude!="assistant" and a.present and a.room==room and Bed.touches(position("assistant"),vector(a.direction),point,radius)
func _retreat_bed(delta:float) -> void:
 var a:Dictionary=data.actors.assistant;var amount:float=minf(float(a.get("retreat_left",0)),delta*.8)
 if amount<=0:return
 var before:Vector2=position("assistant");var desired:Vector2=before-vector(a.direction)*amount
 var moved:Dictionary=bed_sweep(str(a.room),before,desired,vector(a.direction),vector(a.direction))
 if str(a.room)==app.room_id and Bed.touches(moved.position,moved.direction,app.hero_pos,.22):a.retreat_left=0;return
 a.pos=xy(moved.position);a.retreat_left=maxf(0,float(a.get("retreat_left",0))-before.distance_to(moved.position))
 if not moved.complete:a.retreat_left=0

func _actor(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 if not a.present:return
 if int(a.hp)<=0:
  if id=="assistant" and a.phase=="attack":_advance_attack(id,delta)
  elif id=="assistant":_retreat_bed(delta)
  return
 if id=="assistant" and float(a.get("retreat_left",0))>0 and a.phase not in ["windup","attack"]:
  _retreat_bed(delta)
  if a.phase=="recover":_advance_attack(id,delta)
  else:a.cooldown=maxf(0,float(a.cooldown)-delta)
  return
 a.hurt=maxf(0,float(a.hurt)-delta)
 if a.hurt>0:return
 var s:Dictionary=spec(id);var same:bool=a.room==app.room_id
 var at:Vector2=position(id)
 var visible:bool=same and at.distance_to(app.hero_pos)<=float(config.test_parameters.vision_m) and can_see(str(a.room),at,app.hero_pos)
 var partner:String="mother" if id=="father" else "father" if id=="mother" else ""
 var partner_visible:bool=false
 if not partner.is_empty():
  var other_parent:Dictionary=data.actors[partner]
  partner_visible=other_parent.present and other_parent.hp>0 and other_parent.room==a.room and at.distance_to(position(partner))<=float(config.test_parameters.vision_m) and can_see(str(a.room),at,position(partner))
 if visible:a.last_seen=xy(app.hero_pos);a.last_seen_at=data.clock;a.investigation={}
 if s.relation=="friend" and str(a.follow).is_empty():
  if same:_friend(id,delta)
  return
 if a.phase in ["windup","attack","recover","grip"]:
  _advance_attack(id,delta);return
 a.cooldown=maxf(0,float(a.cooldown)-delta)
 if not a.hostile and str(a.follow).is_empty():
  if id=="double_head" and not a.get("home",[]).is_empty():_move_actor(id,vector(a.home),delta)
  return
 if not str(a.follow).is_empty():
  var to:String=str(a.follow);var space=floor_for(str(a.room));var portal:Dictionary=space.portal(to)
  if portal.is_empty():a.follow="";return
  _move_actor(id,portal.threshold,delta)
  if position(id).distance_to(portal.threshold)<.05:
   var target_portal:Dictionary=floor_for(to).portal(str(a.room))
   var landing:Vector2=target_portal.landing
   if id=="assistant":
    if not bed_clear(to,landing,target_portal.inward):
     a.follow="";a.retreat_left=.8;return
    a.direction=xy(target_portal.inward)
   if to==app.room_id and landing.distance_to(app.hero_pos)<.65:return
   a.room=to;a.pos=xy(landing);a.follow="";a.route=[];a.last_seen=[]
  return
 if not visible and not partner_visible:
  if noises.investigate(id,delta):return
  if not a.last_seen.is_empty():
   _move_actor(id,vector(a.last_seen),delta)
   if position(id).distance_to(vector(a.last_seen))<.12:
    a.last_seen=[]
    if id=="double_head":a.hostile=false;a.follow=""
  return
 var attack:Dictionary=config.attacks.get(str(s.attack),{})
 if attack.is_empty():return
 var target:Vector2=app.hero_pos
 var target_id:String="hero"
 if partner_visible:target=position(partner);target_id=partner
 var distance:float=at.distance_to(target)
 if target_id=="hero" and hero_attack_slots(str(a.room))>=2:
  # S1:P501 / S3:P1589: queued actors must not keep closing a third side.
  if distance<2.4:
   var away:Vector2=(at-target).normalized();var room_space=floor_for(str(a.room))
   for direction in [away,Vector2(-away.y,away.x),Vector2(away.y,-away.x)]:
    var waiting:Vector2=room_space.clipped_step(at,at+direction*.8)
    if waiting.distance_to(target)>distance and waiting.distance_to(at)>.1:_move_actor(id,waiting,delta);break
  return
 if distance>attack_start_distance(id,attack):
  var goal:Vector2=target+(at-target).normalized()*(2.25 if id=="assistant" else .72)
  if floor_for(str(a.room)).walkable(goal):_move_actor(id,goal,delta)
 elif a.cooldown<=0 and (target_id!="hero" or data.clock>=data.next_attack) and (target_id!="hero" or not app.rules.gripped):
  var slots:int=hero_attack_slots(str(a.room))
  if (target_id=="hero" and slots>=2) or (str(s.attack) in ["grab","restraint","isolate","drag","push","drug"] and target_id=="hero" and data.clock<data.grip_safe_until):return
  if id=="assistant":
   var wanted:Vector2=(target-at).normalized()
   var turn:Vector2=vector(a.direction).rotated(clampf(vector(a.direction).angle_to(wanted),-float(config.test_parameters.bed_turn_rad_s)*delta,float(config.test_parameters.bed_turn_rad_s)*delta))
   var pose:Dictionary=bed_sweep(str(a.room),at,at,vector(a.direction),turn)
   if pose.complete:a.direction=xy(turn)
   if not pose.complete or absf(turn.angle_to(wanted))>.03:return
  if id=="double_head" and a.get("home",[]).is_empty():a.home=xy(at)
  data.serial+=1;a.attack_id="combat:%d:%d:%s:%d"%[chapter_id,app.rules.actual_attempt,id,data.serial]
  a.phase="windup";a.elapsed=0.0;a.direction=xy((target-at).normalized());a.hits={};a.route=[];a.attack_target=target_id
  if id=="twitch":a.echo_knee=reactions.has_knee_history();a.tap_count=0
  if target_id=="hero":data.next_attack=data.clock+.8
  app.audio.cue("SFX_COMBAT_WINDUP",str(a.attack_id)+":windup")
  app.rules._record("combat_attack_started",str(a.attack_id),{"actor":id,"room":a.room,"direction":a.direction})

func attack_start_distance(id:String,attack:Dictionary) -> float:
 return 2.35 if id=="assistant" else float(attack.reach)+.25

func hero_attack_slots(room:String) -> int:
 var slots:int=0
 for other in data.actors:
  var b:Dictionary=data.actors[other]
  if b.present and b.hp>0 and b.room==room and b.phase in ["windup","attack","recover","grip","drug_hold"] and b.get("attack_target","hero")=="hero":slots+=1
 return slots

func _advance_attack(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id];var s:Dictionary=spec(id);var attack:Dictionary=config.attacks.get(str(s.attack),{})
 if a.phase=="grip":return
 a.elapsed+=delta
 if a.phase=="windup":
  if id=="twitch":
   var count:int=int(a.get("tap_count",0))
   if count==0 and a.elapsed>=.2:
    if a.room==app.room_id and reactions.visible(id):a.direction=xy((app.hero_pos-position(id)).normalized())
    a.tap_count=1;app.audio.cue("SFX_FOOTSTEP",str(a.attack_id)+":heel1")
   if int(a.get("tap_count",0))==1 and a.elapsed>=.7:
    a.tap_count=2;app.audio.cue("SFX_FOOTSTEP",str(a.attack_id)+":heel2")
  if a.elapsed>=float(attack.windup):
   a.phase="attack";a.elapsed=0.0
   if id=="assistant":app.audio.cue("SFX_BED_ROLL",str(a.attack_id)+":roll")
  return
 if a.phase=="attack":
  var at:Vector2=position(id);var direction:Vector2=vector(a.direction)
  if float(attack.travel)>0:
   var space=floor_for(str(a.room));var next:Vector2=space.clipped_step(at,at+direction*float(attack.travel)/float(attack.active)*delta)
   if id=="assistant":
    var swept:Dictionary=bed_sweep(str(a.room),at,next,direction,direction)
    next=swept.position
    if not swept.complete:a.elapsed=float(attack.active)
   a.pos=xy(next)
   if next.distance_to(at)<.0001:a.elapsed=float(attack.active)
  if a.room==app.room_id:
   if _contains(id,app.hero_pos) and not a.hits.has("hero"):
    var duck:bool=id!="doctor" and app.rules.reaction_skill=="GUT" and app.rules.reaction_left>.2 and str(attack.height)=="chest"
    var withdraw:bool=id!="mother" and str(attack.height)=="arm" and app.rules.reaction_skill=="WITHDRAW" and app.rules.reaction_left>0
    if not duck and not withdraw:
     a.hits.hero=true;_damage_hero(str(a.attack_id),int(attack.hp),int(attack.sp),id)
     if id=="assistant":
      if app.rules.hp>0:app.hero_pos=app.layout.clipped_step(app.hero_pos,app.hero_pos+direction*float(config.test_parameters.bed_push_m))
      a.elapsed=float(attack.active) # Stop the bed after actual body impact, then retreat.
     if str(s.attack) in ["grab","restraint","isolate","drag","push","drug"] and app.rules.hp>0 and str(data.holder).is_empty():
      data.holder=id;data.grip_until=data.clock+1.2;app.rules.gripped=true;a.phase="grip";return
  for other in data.actors:
   if other==id:continue
   var b:Dictionary=data.actors[other]
   var target:bool=spec(other).relation in ["friend","neutral"] or (id=="father" and other=="mother") or (id=="mother" and other=="father")
   if target and b.present and b.room==a.room and b.hp>0 and not a.hits.has(other) and _contains(id,position(other)):
    a.hits[other]=true;damage_actor(id,str(other),int(attack.hp),str(a.attack_id)+":"+other)
    if b.hp<=0 and data.holder==other:data.holder="";app.rules.gripped=false;data.grip_safe_until=data.clock+.8
  if a.elapsed>=float(attack.active):
   a.phase="recover";a.elapsed=0.0
   if id=="assistant":a.retreat_left=.65
 elif a.phase=="recover" and a.elapsed>=float(attack.recover):
  a.phase="idle";a.elapsed=0.0;a.cooldown=float(attack.cooldown)
  if id=="double_head":a.hostile=false;a.follow="";a.last_seen=[]

func damage_actor(source:String,target:String,hp:int,receipt:String) -> void:
 var b:Dictionary=data.actors[target]
 b.hp=0 if source=="father" and target=="dog" else maxi(0,int(b.hp)-hp);b.hurt=.25
 app.rules._record("combat_actor_hit",receipt,{"source":source,"target":target,"hp":b.hp,"level":chapter_id})

func _contains(id:String,target:Vector2) -> bool:
 var a:Dictionary=data.actors[id];var attack:Dictionary=config.attacks[str(spec(id).attack)]
 var delta:Vector2=target-position(id);var direction:Vector2=vector(a.direction)
 if id=="assistant":return Bed.touches(position(id),direction,target,.21) and floor_for(str(a.room)).clear_segment(position(id),target)
 return delta.dot(direction)>=-.21 and delta.dot(direction)<=float(attack.reach)+.21 and absf(delta.cross(direction))<=float(attack.width)+.21 and floor_for(str(a.room)).clear_segment(position(id),target)

func _damage_hero(receipt:String,hp:int,sp:int,source:String) -> bool:
 if app.rules.hp<=0 or app.rules.settled.has(receipt):return false
 app.rules.settled[receipt]="combat_hit";app.rules.hp=maxi(0,app.rules.hp-hp);app.rules.change_sp(-sp)
 observations.cancel()
 app.rules.cancel_search();app.rules.reaction_left=0;app.rules.action.clear()
 if not app.rules.pending_neural.is_empty():
  var pending_id:String=str(app.rules.pending_neural.event_id)
  app.rules.settled[pending_id]="interrupted"
  app.rules._record("skill_interrupted",pending_id,{"cause":receipt})
 app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.motion.clear();app.hero_route=PackedVector2Array()
 if app.rules.hp>0 and app.rules.hurt_left<=0:app.rules.hurt_left=.25
 if app.rules.hp<=0:app.rules.end_control();app.rules.gripped=false;data.holder=""
 app.rules.vitality_lost.emit();app.audio.cue("SFX_HIT",receipt)
 app.rules._record("combat_hit",receipt,{"source":source,"hp_damage":hp,"sp_damage":sp,"room":app.room_id})
 return true

func _friend(id:String,delta:float) -> void:
 var a:Dictionary=data.actors[id]
 if id=="dog":
  var goal:Vector2=app.hero_pos+Vector2(.65,.3)
  for enemy in data.actors:
   var b:Dictionary=data.actors[enemy]
   if b.present and b.hp>0 and b.room==app.room_id and b.hostile and position(enemy).distance_to(app.hero_pos)<3 and can_see(app.room_id,position(id),position(enemy)):
    goal=app.hero_pos.lerp(position(enemy),.5);break
  if app.layout.walkable(goal):_move_actor(id,goal,delta)
 elif id=="corner":
  var suggested:String="atrium"
  for enemy in data.actors:
   var b:Dictionary=data.actors[enemy]
   if b.present and b.hp>0 and b.room==app.room_id and b.hostile and b.phase in ["windup","attack"] and _contains(enemy,map.doorway(app.room_id,"atrium")):suggested="memory";break
  a.point_to=suggested;a.phase="point";a.direction=xy((map.doorway(app.room_id,suggested)-position(id)).normalized())
 elif id=="nurse":
  if data.bandage_done or app.rules.hp>=100 or app.rules.hp<=0:return
  var unsafe:bool=app.rules.gripped or app.rules.hurt_left>0
  for other in data.actors:
   var b:Dictionary=data.actors[other]
   if b.present and b.hp>0 and b.hostile and b.room==app.room_id and position(other).distance_to(app.hero_pos)<4 and app.layout.clear_segment(position(other),app.hero_pos):unsafe=true
  if unsafe:a.phase="idle";return
  var goal:Vector2=app.hero_pos+(position(id)-app.hero_pos).normalized()*.6
  if app.layout.walkable(goal):_move_actor(id,goal,delta)
  if position(id).distance_to(app.hero_pos)>.75:a.phase="idle";return
  a.phase="bandage";data.bandage_elapsed+=delta
  if data.bandage_elapsed>=3.0:
   data.bandage_done=true;app.rules.hp=mini(100,app.rules.hp+20);a.phase="idle"
   app.rules._record("combat_bandage_completed","bandage:%d:%d"%[chapter_id,app.rules.actual_attempt],{"hp":20,"source":"S4:T13R6"})
   app.status_note="小护士实际包扎完成：生命+20；本次第五关治疗已用。"
 elif id=="faceless" and float(data.cart_shift)<.8:
  var cart:Dictionary=app.layout.furniture[0];var rect:Rect2=cart.rect
  var stand:Vector2=Vector2(rect.position.x-.4,rect.get_center().y)
  if app.layout.walkable(stand):_move_actor(id,stand,delta)
  if position(id).distance_to(stand)>.08:return
  var shift:float=minf(delta*.3,.8-float(data.cart_shift));var moved:=Rect2(rect.position+Vector2(shift,0),rect.size)
  if moved.grow(.21).has_point(app.hero_pos):return
  for other in app.layout.furniture:
   if other.id!=cart.id and moved.grow(.05).intersects(other.rect):return
  cart.rect=moved;a.pos=xy(position(id)+Vector2(shift,0));data.cart_shift+=shift
  if not data.prop_rects.has(app.room_id):data.prop_rects[app.room_id]={}
  data.prop_rects[app.room_id][str(cart.id)]=[moved.position.x,moved.position.y,moved.size.x,moved.size.y]
  app.layout.rebuild_grid();a.phase="push"

func move_hero(delta:float) -> void:
 var before:Vector2=app.hero_pos
 var endpoint:Vector2=app.hero_route[-1] if not app.hero_route.is_empty() else before
 app.move_hero(delta*float(config.test_parameters.hero_speed_m_s)/1.15)
 var bodies:Array=[];var blocked:bool=false
 for id in data.actors:
  var a:Dictionary=data.actors[id]
  if not a.present or a.hp<=0 or a.room!=app.room_id:continue
  var body:Vector2=position(id);bodies.append({"pos":body,"radius":.47})
  if app.hero_pos.distance_to(body)<.46 and before.distance_to(body)>=.46:blocked=true
 if bed_blocks(app.room_id,app.hero_pos,.21):blocked=true
 if blocked:
  app.hero_pos=before
  var bed:Dictionary=data.actors.assistant
  var previous:Array[Rect2]=app.layout.movable_blockers.duplicate()
  if bed.present and bed.room==app.room_id:app.layout.movable_blockers.append(bed_rect(position("assistant"),vector(bed.direction)))
  app.layout.rebuild_grid();app.hero_route=app.layout.path_around_bodies(before,endpoint,bodies)
  app.layout.movable_blockers=previous;app.layout.rebuild_grid()
 if app.controlled_route and app.rules.control_left>0 and app.hero_pos.distance_to(before)>.0001:app.rules.record_control_action("navigation","floor")

func hero_portal(to:String) -> Dictionary:return app.layout.portal(to)
func hero_doorway(to:String) -> Vector2:return hero_portal(to).at
func cross_door(to:String) -> void:app.enter_room(to)

func _hero(delta:float) -> void:
 if data.boundary:return
 if data.get("control_was_active",false) and app.rules.control_left<=0 and float(data.door_left)<0:
  app.hero_route=PackedVector2Array();data.controlled_door="";app.controlled_route=false
 data.control_was_active=app.rules.control_left>0
 if not app.rules.action.is_empty():
  app.rules.advance_kick(delta);kick_contact();app.hero_state="give";return
 if not app.motion.is_empty():
  if app.rules.hurt_left>0 or app.rules.stun_left>0:app.motion.clear();app.hero_route=PackedVector2Array();return
  if not app.rules.body_busy() and not app.rules.gripped:
   var moved:Dictionary=app.layout.move_path(app.hero_pos,app.hero_route,float(app.motion.speed)*delta*app.layout.speed_factor(app.hero_pos))
   if bed_blocks(app.room_id,moved.position,.21):app.motion.clear();app.hero_route=PackedVector2Array();return
   app.hero_pos=moved.position;app.hero_route=moved.route;app.hero_state="walk"
   if app.hero_route.is_empty():
    if app.motion.has("impact"):app.layout.record_rack_contact(app.hero_pos,vector(app.motion.impact))
    app.motion.clear()
  return
 if observations.advance(delta):return
 if app.rules.body_busy() or app.rules.gripped:
  app.hero_state="tinnitus" if float(app.rules.effects.get("TINNITUS",0))>0 and app.rules.hurt_left<=0 and app.rules.stun_left<=0 and not app.rules.gripped else "hit"
  return
 if not app.family.data.eating.is_empty():app.hero_state="eat";return
 var nurse:Dictionary=data.actors.nurse
 if app.rules.control_left<=0 and nurse.present and nurse.hp>0 and nurse.room==app.room_id and nurse.phase=="bandage":app.hero_state="idle";return
 if float(data.door_left)>=0:
  data.door_left=maxf(0,float(data.door_left)-delta);app.hero_state="give"
  if data.door_left<=0:
   var to:String=str(data.destination)
   var threshold:Vector2=hero_portal(to).threshold
   if app.hero_pos.distance_to(threshold)>.035:
    if app.hero_route.is_empty():app.hero_route=app.layout.path(app.hero_pos,threshold)
    move_hero(delta);return
   if to==str(config.get("exit_id","street_exit")):exit_crossed()
   else:cross_door(to)
  return
 if app.rules.control_left>0:
  var chosen:String=str(data.get("controlled_door",""))
  if not chosen.is_empty():
   var point:Vector2=hero_doorway(chosen)
   if (app.hero_route.is_empty() and app.hero_pos.distance_to(point)>.04) or (not app.hero_route.is_empty() and app.hero_route[-1].distance_to(point)>.05):app.hero_route=app.layout.path(app.hero_pos,point)
  move_hero(delta*app.layout.speed_factor(app.hero_pos))
  if not chosen.is_empty() and app.hero_pos.distance_to(hero_doorway(chosen))<.04:
   data.destination=chosen;data.door_left=.6;data.controlled_door="";app.hero_route=PackedVector2Array()
  return
 observations.try_autonomous()
 if not data.inspection.is_empty():return
 data.route_left=maxf(0,float(data.route_left)-delta)
 var exit_room:String=str(config.get("exit_room","brainstem"))
 var to:String=str(config.get("exit_id","street_exit")) if app.room_id==exit_room else map.next_room(app.room_id,exit_room)
 var goal:Vector2=hero_doorway(to)
 var evade:bool=false
 if app.room_id=="brainstem" and pulse_phase() in ["warning","active"] and app.layout.pulse_zone.grow(.21).has_point(app.hero_pos):
  var zone:Rect2=app.layout.pulse_zone
  var left_goal:=Vector2(zone.position.x-.35,app.hero_pos.y)
  var right_goal:=Vector2(zone.end.x+.35,app.hero_pos.y)
  var candidate:Vector2=left_goal if app.hero_pos.distance_to(left_goal)<app.hero_pos.distance_to(right_goal) else right_goal
  if app.layout.walkable(candidate):goal=candidate;evade=true
 elif app.room_id=="brainstem" and pulse_phase() in ["warning","active"]:
  var zone:Rect2=app.layout.pulse_zone
  if (app.hero_pos.x<zone.position.x and goal.x>zone.position.x) or (app.hero_pos.x>zone.end.x and goal.x<zone.end.x):
   var waiting:=Vector2(zone.position.x-.4 if app.hero_pos.x<zone.position.x else zone.end.x+.4,app.hero_pos.y)
   if app.layout.walkable(waiting):goal=waiting;evade=true
 for id in data.actors:
  var a:Dictionary=data.actors[id]
  if not a.present or a.hp<=0 or a.room!=app.room_id or not a.hostile:continue
  if position(id).distance_to(app.hero_pos)>float(config.test_parameters.hero_vision_m) or not can_see(app.room_id,app.hero_pos,position(id)):continue
  if float(app.rules.effects.get("FEAR",0))>0:
   var away:Vector2=(app.hero_pos-position(id)).normalized()
   var retreat:Vector2=app.layout.clipped_step(app.hero_pos,app.hero_pos+away*float(config.test_parameters.dodge_m))
   if retreat.distance_to(app.hero_pos)>.05:goal=retreat;evade=true;break
  if a.phase in ["windup","attack"] and position(id).distance_to(app.hero_pos)<2.8:
   var direction:Vector2=vector(a.direction);var side:=Vector2(-direction.y,direction.x)
   var escape_goal:Vector2=goal
   var escape_path:PackedVector2Array=app.layout.path(app.hero_pos,escape_goal)
   var waypoint:Vector2=escape_path[1] if escape_path.size()>1 else escape_goal
   var onward:Vector2=(waypoint-app.hero_pos).normalized()
   var best:float=-INF;var choice:Vector2=app.hero_pos
   for retreat in [side,-side,-direction,(side-direction).normalized(),(-side-direction).normalized(),onward,(onward+side).normalized(),(onward-side).normalized()]:
    var candidate:Vector2=app.layout.clipped_step(app.hero_pos,app.hero_pos+retreat*float(config.test_parameters.dodge_m))
    if candidate.distance_to(app.hero_pos)<.1 or bed_blocks(app.room_id,candidate,.21):continue
    var free:bool=true;var danger:float=0
    var perceived_bodies:Array=[]
    for other in data.actors:
     var b:Dictionary=data.actors[other]
     if not b.present or b.hp<=0 or b.room!=app.room_id or not can_see(app.room_id,app.hero_pos,position(other)):continue
     perceived_bodies.append({"pos":position(other),"radius":.47})
     if candidate.distance_to(position(other))<.52:free=false;break
     if b.hostile and b.phase in ["windup","attack"] and _contains(str(other),candidate):danger+=2
    if not free or not app.layout.segment_avoids_bodies(app.hero_pos,candidate,perceived_bodies):continue
    var score:float=candidate.distance_to(app.hero_pos)-candidate.distance_to(waypoint)*.65-danger+(0.5 if not _contains(id,candidate) else 0.0)
    if score>best:best=score;choice=candidate
   if best>-INF:goal=choice;evade=true;break
 for other in data.actors:
  var body:Dictionary=data.actors[other]
  if not body.present or body.hp<=0 or body.room!=app.room_id or position(other).distance_to(app.hero_pos)>float(config.test_parameters.hero_vision_m) or not can_see(app.room_id,app.hero_pos,position(other)):continue
  if position(other).distance_to(goal)<.52:
   var approach:Vector2=position(other)+(app.hero_pos-position(other)).normalized()*.82
   if app.layout.walkable(approach):goal=approach;evade=true
 if data.route_left<=0 or app.hero_route.is_empty() or vector(data.get("hero_goal",[0,0])).distance_to(goal)>.15:
  var bodies:Array=[]
  for other in data.actors:
   var body:Dictionary=data.actors[other]
   if body.present and body.hp>0 and body.room==app.room_id and position(other).distance_to(app.hero_pos)<=float(config.test_parameters.hero_vision_m) and can_see(app.room_id,app.hero_pos,position(other)):bodies.append({"pos":position(other),"radius":.47})
  app.hero_route=app.layout.path_around_bodies(app.hero_pos,goal,bodies);data.hero_goal=xy(goal);data.route_left=float(config.test_parameters.route_recheck_s)
 move_hero(delta*app.layout.speed_factor(app.hero_pos))
 if not evade and app.hero_pos.distance_to(goal)<.04:data.destination=to;data.door_left=.6;app.hero_route=PackedVector2Array()

func exit_crossed() -> void:
 app.unlock_street()

func pulse_phase() -> String:
 var time:float=fmod(float(data.get("pulse_clock",0)),6.0)
 return "warning" if time<1.5 else "active" if time<1.8 else "interval"

func _pulse() -> void:
 if chapter_id!=5:return
 var epoch:int=int(floor(float(data.pulse_clock)/6.0))
 if pulse_phase()!="active":return
 for room in ["brainstem"]:
  var zone:Rect2=floor_for(room).pulse_zone
  if app.room_id==room and zone.has_point(app.hero_pos):
   var receipt:String="pulse:%d:%d:hero"%[app.rules.actual_attempt,epoch]
   if _damage_hero(receipt,20,0,"brainstem_pulse"):
    var side:float=-1.0 if app.hero_pos.x<zone.get_center().x else 1.0
    app.hero_pos=app.layout.clipped_step(app.hero_pos,app.hero_pos+Vector2(side,0))
  for id in data.actors:
   var a:Dictionary=data.actors[id];var receipt:String="pulse:%d:%d:%s"%[app.rules.actual_attempt,epoch,id]
   if a.present and a.hp>0 and a.room==room and zone.has_point(position(id)) and not data.pulse_receipts.has(receipt):
    data.pulse_receipts[receipt]=true;a.hp=maxi(0,int(a.hp)-20)
    var at:Vector2=position(id);var sign_value:float=-1.0 if at.x<zone.get_center().x else 1.0
    a.pos=xy(floor_for(room).clipped_step(at,at+Vector2(sign_value,0)))
    if data.holder==id:data.holder="";app.rules.gripped=false;data.grip_safe_until=data.clock+.8

func kick_contact() -> void:
 if app.rules.action.is_empty():return
 var direction:Array=app.rules.action.direction;var forward:=Vector2(float(direction[0]),float(direction[1]))
 for id in data.actors:
  var a:Dictionary=data.actors[id]
  if not a.present or a.hp<=0 or a.room!=app.room_id:continue
  if id=="cat" and a.phase=="windup":continue
  var offset:Vector2=position(id)-app.hero_pos
  if not app.rules.kick_contact(id,offset.length(),forward.dot(offset.normalized())>.6,app.layout.clear_segment(app.hero_pos,position(id))):continue
  a.hp=maxi(0,int(a.hp)-15);a.hostile=true if id=="double_head" else a.hostile
  if id=="double_head" and a.get("home",[]).is_empty():a.home=xy(position(id))
  if id=="assistant" and a.phase=="attack":
   a.hurt=0.0 # The moving bed completes its already-launched trajectory.
  else:a.pos=xy(app.layout.clipped_step(position(id),position(id)+offset.normalized()*.8));a.hurt=.8;a.phase="idle";a.cooldown=1.5
  if data.holder==id:data.holder="";app.rules.gripped=false;data.grip_safe_until=data.clock+.8
  app.audio.cue("SFX_HIT",str(app.rules.action.id)+":"+id)

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false):return
 if result.id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:observations.cancel()
 if result.id=="TINNITUS":app.hero_route=PackedVector2Array();data.route_left=0.0
 if result.id=="PORES":
  for id in data.actors:
   var a:Dictionary=data.actors[id]
   if a.present and a.hp>0 and a.hostile and a.room==app.room_id and position(id).distance_to(app.hero_pos)<=float(config.test_parameters.hero_vision_m) and app.layout.clear_segment(app.hero_pos,position(id)):
    app.hero_facing=(position(id)-app.hero_pos).normalized();break
 reactions.on_skill(result)

func can_see(room:String,from:Vector2,to:Vector2) -> bool:return floor_for(room).clear_segment(from,to)

func context() -> Dictionary:
 var perceived:bool=false
 for id in data.get("actors",{}):
  var a:Dictionary=data.actors[id]
  if a.present and a.hp>0 and a.hostile and a.room==app.room_id and position(id).distance_to(app.hero_pos)<=float(config.test_parameters.hero_vision_m) and can_see(app.room_id,app.hero_pos,position(id)):perceived=true;break
 return {"perceived_threat":perceived}
