extends RefCounted
## S3:P1756–1763: independent side-pushed bed, not the assistant's charge.
const CARRIER="transporter_asylum"
const Travel=preload("res://scripts/core/street_bed_travel.gd")
var travel
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner);travel=Travel.new(self)
func v(a:Array) -> Vector2:return battle.vector(a)
func xy(p:Vector2) -> Array:return battle.xy(p)
func anchor(center:Vector2,axis:Vector2) -> Vector2:return center-axis*battle.Bed.OFFSET

func normalize() -> void:
 if not battle.data.get("lateral_bed",{}).is_empty():
  if not battle.data.lateral_bed.has("id"):battle.data.lateral_bed.id="street_asylum_transport_bed"
  if not battle.data.lateral_bed.has("travel"):battle.data.lateral_bed.travel={}
  return
 var a:Dictionary=battle.data.actors[CARRIER]
 var push:=Vector2.RIGHT;var center:Vector2=battle.position(CARRIER)+push*.8
 for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
  var candidate:Vector2=battle.position(CARRIER)+direction*.8;var axis:=Vector2(-direction.y,direction.x)
  if battle.Bed.clear(battle.floor_for(str(a.room)),anchor(candidate,axis),axis):push=direction;center=candidate;break
 battle.data.lateral_bed={"id":"street_asylum_transport_bed","room":a.room,"center":xy(center),"axis":xy(Vector2(-push.y,push.x)),"push":xy(push),"operator":a.pos.duplicate(),"phase":"idle","elapsed":0.0,"distance":0.0,"velocity":0.0,"coasting":false,"hits":{},"attack_id":"","retreat_left":0.0,"seen_sign":false}

func touches(room:String,point:Vector2,radius:float) -> bool:
 normalize();var b:Dictionary=battle.data.lateral_bed
 return b.room==room and battle.data.actors[CARRIER].present and battle.Bed.touches(anchor(v(b.center),v(b.axis)),v(b.axis),point,radius)

func rect() -> Rect2:
 normalize();var b:Dictionary=battle.data.lateral_bed
 return battle.Bed.bounds(anchor(v(b.center),v(b.axis)),v(b.axis))

func push_blocker(space,blocker:Rect2,pose:Dictionary={}) -> Dictionary:
 # Keep the existing AStar map. Only cells covered by this temporary object
 # can change: a whole 20x12m rebuild per 25ms step is unnecessary.
 var previous:Array[Rect2]=space.movable_blockers.duplicate();var previous_oriented:Array=space.oriented_beds.duplicate()
 if pose.is_empty():space.movable_blockers.append(blocker)
 else:space.oriented_beds.append(pose)
 var grown:Rect2=blocker.grow(float(space.body_radius)+float(space.CELL));var changed:Array=[]
 for y in range(floori(grown.position.y/space.CELL),ceili(grown.end.y/space.CELL)+1):
  for x in range(floori(grown.position.x/space.CELL),ceili(grown.end.x/space.CELL)+1):
   var cell:=Vector2i(x,y)
   if not space.grid.region.has_point(cell):continue
   var was:bool=space.grid.is_point_solid(cell);var solid:bool=not space.walkable(Vector2(cell)*space.CELL)
   if was!=solid:changed.append({"cell":cell,"solid":was});space.grid.set_point_solid(cell,solid)
 return {"previous":previous,"previous_oriented":previous_oriented,"changed":changed}

func pop_blocker(space,state:Dictionary) -> void:
 space.movable_blockers=state.previous
 space.oriented_beds=state.previous_oriented
 for cell in state.changed:space.grid.set_point_solid(cell.cell,cell.solid)

func lane_clear(center:Vector2,axis:Vector2,push:Vector2) -> bool:
 var b:Dictionary=battle.data.lateral_bed;var space=battle.floor_for(str(b.room))
 var from:Vector2=anchor(center,axis);var to:Vector2=from+push
 if not battle.Bed.sweep(space,from,to,axis,axis).complete:return false
 # Conservatively reserve a route outside the *entire* swept footprint.
 # If this union is passable, every intermediate bed pose is passable too.
 var blocker:Rect2=battle.Bed.bounds(from,axis).merge(battle.Bed.bounds(to,axis))
 var state:Dictionary=push_blocker(space,blocker)
 var mouths:Array=battle.map.doors(str(b.room));var clear:bool=true
 for door in mouths:
  var p:Dictionary=space.portal(str(door))
  if not space.walkable(p.landing) or not space.walkable(p.threshold):clear=false;break
  for other in mouths:
   if door!=other and space.path(p.landing,space.portal(str(other)).landing).is_empty():clear=false;break
 pop_blocker(space,state)
 return clear

func _people_clear(center:Vector2,axis:Vector2,operator:Vector2,room:String="") -> bool:
 var b:Dictionary=battle.data.lateral_bed
 if room.is_empty():room=str(b.room)
 var other_bed:Dictionary=battle.data.actors.assistant
 if other_bed.present and other_bed.room==room and battle.Bed.overlaps_rect(anchor(center,axis),axis,battle.bed_rect(battle.position("assistant"),v(other_bed.direction))):return false
 if room==app.room_id and (battle.Bed.touches(anchor(center,axis),axis,app.hero_pos,.23) or operator.distance_to(app.hero_pos)<.43):return false
 for id in battle.data.actors:
  var a:Dictionary=battle.data.actors[id]
  if id!=CARRIER and a.present and a.hp>0 and a.room==room:
   if battle.Bed.touches(anchor(center,axis),axis,battle.position(str(id)),.25) or operator.distance_to(battle.position(str(id)))<.43:return false
 return true

func _translate(offset:Vector2,move_operator:bool=true) -> bool:
 var b:Dictionary=battle.data.lateral_bed;var space=battle.floor_for(str(b.room));var a:Dictionary=battle.data.actors[CARRIER]
 var start:Vector2=anchor(v(b.center),v(b.axis));var sweep:Dictionary=battle.Bed.sweep(space,start,start+offset,v(b.axis),v(b.axis))
 var operator:Vector2=battle.position(CARRIER)+offset if move_operator else battle.position(CARRIER)
 if not sweep.complete or not space.walkable(operator) or not _people_clear(v(b.center)+offset,v(b.axis),operator):return false
 b.center=xy(v(b.center)+offset);b.operator=xy(v(b.operator)+offset)
 if move_operator:a.pos=xy(operator)
 return true

func _orient(toward:Vector2,delta:float) -> bool:
 var b:Dictionary=battle.data.lateral_bed;var at:Vector2=battle.position(CARRIER)
 var current:Vector2=v(b.push);var wanted:Vector2=(toward-at).normalized()
 var push:Vector2=current.rotated(clampf(current.angle_to(wanted),-1.8*delta,1.8*delta));var axis:=Vector2(-push.y,push.x)
 var offset:float=move_toward(v(b.center).distance_to(at),.8,delta*.2)
 var center:Vector2=at+push*offset
 var sweep:Dictionary=battle.Bed.sweep(battle.floor_for(str(b.room)),anchor(v(b.center),v(b.axis)),anchor(center,axis),v(b.axis),axis)
 if not sweep.complete:return false
 for pose in sweep.poses:
  if not _people_clear(pose.at+pose.direction*battle.Bed.OFFSET,pose.direction,at):return false
 b.push=xy(push);b.axis=xy(axis);b.center=xy(center);b.operator=xy(at)
 return absf(push.angle_to(wanted))<.03

func actor(delta:float) -> void:
 normalize();var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[CARRIER]
 if not a.present:return
 if b.phase=="attack":_advance(delta);return
 if b.phase=="recover":
  b.elapsed+=delta
  if a.hp>0 and a.hurt<=0 and float(b.retreat_left)>0:
   var amount:float=minf(float(b.retreat_left),delta*.8)
   if _translate(-v(b.push)*amount):b.retreat_left-=amount
   else:b.retreat_left=0.0
  if b.elapsed>=.8-.000001:
   b.phase="idle";a.phase="idle";a.cooldown=2.0
  a.hurt=maxf(0,float(a.hurt)-delta);return
 if a.hp<=0:
  if b.phase=="windup":_recover(false)
  b.travel={};a.follow=""
  return # Stationary corpse/bed stay at their actual separate positions.
 if a.hurt>0:
  a.hurt=maxf(0,float(a.hurt)-delta)
  if b.phase=="windup":_recover(false)
  return
 if b.phase=="windup":
  b.elapsed+=delta;a.elapsed=b.elapsed
  if b.elapsed>=1.2-.000001:
   b.phase="attack";b.elapsed=0.0;b.velocity=1.0/.6;a.phase="attack";a.elapsed=0.0
   app.audio.cue("SFX_BED_ROLL",str(b.attack_id)+":roll")
  return
 a.cooldown=maxf(0,float(a.cooldown)-delta)
 if battle.position(CARRIER).distance_to(v(b.operator))>.08:
  battle._move_actor(CARRIER,v(b.operator),delta);return
 if not travel.phase().is_empty():travel.tick(delta);return
 var visible:bool=a.room==app.room_id and battle.position(CARRIER).distance_to(app.hero_pos)<=6 and battle.can_see(str(a.room),battle.position(CARRIER),app.hero_pos)
 if not visible:
  travel.tick(delta)
  return
 a.follow=""
 a.last_seen=xy(app.hero_pos);a.last_seen_at=battle.data.clock
 if not b.seen_sign and battle.position(CARRIER).distance_to(app.hero_pos)<=3 and battle.can_see(app.room_id,app.hero_pos,v(b.center)):
  b.seen_sign=true
  app.rules.observe("角色","street_bed_sign","实际看清推床上的‘离院’牌。","亲历事实","S3:P1763")
 if battle.hero_attack_slots(str(a.room))>=2:return
 var distance:float=battle.position(CARRIER).distance_to(app.hero_pos)
 if distance>2.4:
  var direction:Vector2=(app.hero_pos-battle.position(CARRIER)).normalized()
  for offset in [direction,Vector2(-direction.y,direction.x),Vector2(direction.y,-direction.x)]:
   if _translate(offset*float(battle.config.test_parameters.actor_speed_m_s)*delta):break
  return
 if a.cooldown>0 or battle.data.clock<battle.data.next_attack or app.rules.gripped:return
 if not _orient(app.hero_pos,delta) or not lane_clear(v(b.center),v(b.axis),v(b.push)):return
 battle.data.serial+=1;b.attack_id="street_lateral:%d:%d"%[app.rules.actual_attempt,battle.data.serial]
 b.phase="windup";b.elapsed=0.0;b.distance=0.0;b.hits={};b.coasting=false
 a.phase="windup";a.elapsed=0.0;a.direction=b.push.duplicate();a.attack_id=b.attack_id;a.hits={};a.attack_target="hero"
 battle.data.next_attack=battle.data.clock+.8
 app.audio.cue("SFX_COMBAT_WINDUP",str(b.attack_id)+":windup")
 app.rules._record("combat_attack_started",str(b.attack_id),{"actor":CARRIER,"room":a.room,"direction":b.push.duplicate(),"kind":"lateral_bed"})

func _recover(retreat:bool=true) -> void:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[CARRIER]
 b.phase="recover";b.elapsed=0.0;b.velocity=0.0;b.retreat_left=.65 if retreat and a.hp>0 and a.hurt<=0 else 0.0
 if a.hp>0:a.phase="recover";a.elapsed=0.0

func _advance(delta:float) -> void:
 var b:Dictionary=battle.data.lateral_bed;var a:Dictionary=battle.data.actors[CARRIER]
 b.elapsed+=delta;a.elapsed=b.elapsed
 if a.hp<=0 or a.hurt>0 or a.phase!="attack":b.coasting=true
 var speed:float=float(b.velocity)
 if b.coasting:b.velocity=maxf(0,speed-float(battle.config.test_parameters.lateral_coast_deceleration_m_s2)*delta)
 var amount:float=minf(1.0-float(b.distance),(speed+float(b.velocity))*.5*delta)
 var start:Vector2=anchor(v(b.center),v(b.axis));var space=battle.floor_for(str(b.room))
 var sweep:Dictionary=battle.Bed.sweep(space,start,start+v(b.push)*amount,v(b.axis),v(b.axis))
 var before:Vector2=v(b.center);var last:Vector2=before;var impact:bool=false
 for pose in sweep.poses:
  var previous_center:Vector2=last
  last=pose.at+pose.direction*battle.Bed.OFFSET
  if b.room==app.room_id and battle.Bed.touches(pose.at,pose.direction,app.hero_pos,.21) and not b.hits.has("hero"):
   b.hits.hero=true;a.hits.hero=true
   battle._damage_hero(str(b.attack_id),20,0,CARRIER)
   if app.rules.hp>0:app.hero_pos=space.clipped_step(app.hero_pos,app.hero_pos+v(b.push)*minf(1,float(battle.config.test_parameters.bed_push_m)))
   impact=true
  for id in battle.data.actors:
   if id==CARRIER:continue
   var target:Dictionary=battle.data.actors[id]
   if target.present and target.hp>0 and target.room==b.room and battle.Bed.touches(pose.at,pose.direction,battle.position(str(id)),.25):
    if battle.spec(str(id)).relation in ["friend","neutral"] and not b.hits.has(id):
     b.hits[id]=true;battle.damage_actor(CARRIER,str(id),20,str(b.attack_id)+":"+str(id))
    impact=true
  if impact:last=previous_center;break
 b.center=xy(last);var offset:Vector2=last-before;b.distance+=offset.length();b.operator=xy(v(b.operator)+offset)
 if a.hp>0 and a.hurt<=0 and not b.coasting:a.pos=xy(battle.position(CARRIER)+offset)
 if impact or not sweep.complete or b.distance>=.9999 or b.velocity<=0 or (b.elapsed>=.6 and not b.coasting):_recover(not b.coasting)
