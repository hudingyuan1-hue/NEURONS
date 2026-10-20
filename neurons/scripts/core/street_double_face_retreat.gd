extends RefCounted
## S3:P1728–1734. Existing neutral witness retreats after actual injury;
## this adds no counter, target memory, clue or new timing/speed parameter.
const ID="double_face"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func state() -> Dictionary:
 if not battle.data.has("double_face_retreat"):
  battle.data.double_face_retreat={"pending":false,"left":0.0,"origin":[],"room":"","distance":0.0,"serial":0}
 return battle.data.double_face_retreat
func injured(source:String="") -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 # An interrupted unfinished turn is discarded, never replayed after recovery.
 # Completed orientation and already witnessed casts remain historical facts.
 battle.data.face_pending={};a.face_turn_progress=1.0 if a.get("face_turned",false) else 0.0
 s.pending=false;s.left=0.0
 if not a.present or a.hp<=0:return
 var at:Vector2=battle.position(ID);var origin:Vector2=at+battle.vector(a.direction).normalized()
 if source=="hero" and a.room==app.room_id:origin=app.hero_pos
 elif battle.data.actors.has(source):
  var other:Dictionary=battle.data.actors[source]
  if other.present and other.hp>0 and other.room==a.room and battle.can_see(str(a.room),at,battle.position(source)):origin=battle.position(source)
 # Unknown/occluded sources use this body's own backward direction, not a
 # hidden attacker's location. Freeze the local origin; never track a target.
 if at.distance_squared_to(origin)<.0001:origin=at+Vector2.RIGHT
 s.pending=true;s.left=float(battle.config.test_parameters.display_retreat_s);s.origin=battle.xy(origin);s.room=str(a.room);s.distance=0.0;s.serial+=1
func actor_step(delta:float) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0:
  s.pending=false;s.left=0.0;return true
 if a.hurt>0:
  # Old snapshots can lack this module while already containing a real hurt.
  if not s.pending:injured()
  a.hurt=maxf(0,float(a.hurt)-delta);a.phase="idle";return true
 if not s.pending:return false
 if a.room!=s.room:s.pending=false;s.left=0.0;return false
 if a.room!=app.room_id:return true
 var amount:float=minf(delta,float(s.left))
 a.phase="display_retreat"
 _move(amount)
 s.left=maxf(0,float(s.left)-amount)
 if s.left<=.000001:s.left=0.0;s.pending=false;a.phase="idle"
 return true
func bodies() -> Array:
 var result:Array=[];var a:Dictionary=actor()
 if a.room==app.room_id:result.append({"pos":app.hero_pos,"radius":.43})
 for id in battle.data.actors:
  var other:Dictionary=battle.data.actors[id]
  if id!=ID and other.present and other.hp>0 and other.room==a.room:result.append({"pos":battle.position(str(id)),"radius":.43})
 return result
func legal_step(from:Vector2,to:Vector2,occupied:Array) -> bool:
 var room:String=str(actor().room);var floor=battle.floor_for(room);var size:Vector2=floor.world_size();var radius:float=float(floor.body_radius)
 if to.x<radius or to.y<radius or to.x>size.x-radius or to.y>size.y-radius:return false
 if not floor.walkable(to) or not floor.clear_segment(from,to,radius) or not floor.segment_avoids_bodies(from,to,occupied):return false
 # Short real sweeps retain complete bed/chair geometry, rather than only
 # accepting an endpoint on the other side of a moving physical footprint.
 var count:int=maxi(1,ceili(from.distance_to(to)/.025))
 for n in range(1,count+1):
  if battle.bed_blocks(room,from.lerp(to,float(n)/count),radius,ID):return false
 # This is local avoidance, not a newly authorized room transition. Do not
 # retreat into an exit aperture or occupy its existing approach lane.
 for toward in battle.map.doors(room):
  var mouth:Dictionary=floor.portal(str(toward))
  if mouth.is_empty():continue
  var threshold:Vector2=mouth.threshold
  if to.distance_to(threshold)<.65 and to.distance_to(threshold)<from.distance_to(threshold):return false
 return true
func _move(delta:float) -> void:
 var a:Dictionary=actor();var s:Dictionary=state();var floor=battle.floor_for(str(a.room));var at:Vector2=battle.position(ID);var origin:Vector2=battle.vector(s.origin)
 var away:Vector2=(at-origin).normalized();var distance:float=float(battle.config.test_parameters.actor_speed_m_s)*float(floor.speed_factor(at))*delta
 var occupied:Array=bodies();var best:Vector2=at;var score:float=0.0
 # Only physical outward/lateral steps are candidates. An obstructed retreat
 # waits; generic pursuit detours must not carry a neutral witness at attacker.
 for angle in [0.0,PI*.25,-PI*.25,PI*.5,-PI*.5]:
  var candidate:Vector2=at+away.rotated(float(angle))*distance
  var gain:float=candidate.distance_to(origin)-at.distance_to(origin)
  if gain>score and legal_step(at,candidate,occupied):best=candidate;score=gain
 if best.distance_squared_to(at)<=.00000001:return
 a.pos=battle.xy(best);a.direction=battle.xy((best-at).normalized());s.distance+=at.distance_to(best)
