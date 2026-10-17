extends RefCounted
## S3:P1813–1819 / S4:T21R3: one existing box, actual impact, no damage.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)

func normalize() -> void:
 if not battle.data.get("box",{}).is_empty():return
 var a:Dictionary=battle.data.actors.labor
 battle.data.box={"id":"street_labor_box","phase":"held" if a.hp>0 else "ground","room":a.room,"pos":a.pos.duplicate(),"height":.9 if a.hp>0 else 0.0,"elapsed":0.0,"target":[],"origin":[],"sound_sent":false,"heard":[],"released":false,"diverted":false,"line_sent":false}

func tick(delta:float) -> void:
 normalize()
 var b:Dictionary=battle.data.box;var a:Dictionary=battle.data.actors.labor
 var phase:String=str(b.phase)
 if phase in ["flight","fall"]:
  _fly(delta);return # Flight survives the thrower's death or injury.
 if phase=="ground":
  if a.present and a.hp>0 and a.room==app.room_id:battle._yield("labor",delta)
  _outcome();return
 if not a.present:return
 b.room=a.room;b.pos=a.pos.duplicate()
 if a.hp<=0:
  b.phase="ground";b.height=0.0;b.target=[] # No invented throw/landing sound.
  return
 if a.hurt>0:
  a.hurt=maxf(0,float(a.hurt)-delta);b.phase="held";b.elapsed=0;b.target=[];a.phase="idle";return
 if a.room!=app.room_id:return
 if phase=="held":
  var searching:bool=false
  for id in battle.data.actors:
   if _searching(str(id)) and battle.noises.audible_distance(str(battle.data.actors[id].room),battle.position(str(id)),str(a.room),battle.position("labor"))<=6:
    searching=true;break
  if not searching:battle._yield("labor",delta);return
  var landing:Vector2=_landing()
  if landing.x<0:return
  b.target=battle.xy(landing);b.elapsed=0.0;b.phase="prepare";a.phase="box_prepare"
 elif phase=="prepare":
  # A valid threat and free return lane must still exist at release.
  b.elapsed+=delta
  if not _safe_landing(battle.vector(b.target)):
   b.phase="held";b.target=[];b.elapsed=0;a.phase="idle";return
  if b.elapsed>=float(battle.config.test_parameters.box_prepare_s):
   b.phase="flight";b.origin=a.pos.duplicate();b.pos=a.pos.duplicate();b.height=.9;b.elapsed=0.0;b.released=true;a.phase="display"
   app.rules._record("street_box_released",receipt()+":release",{"room":b.room,"origin":b.origin,"target":b.target})

func receipt() -> String:return "street_box:%d"%int(app.session.data.attempts.get("6",app.rules.actual_attempt))

func _searching(id:String) -> bool:
 var a:Dictionary=battle.data.actors[id]
 if not a.present or a.hp<=0 or not a.hostile:return false
 if a.room==app.room_id and battle.position(id).distance_to(app.hero_pos)<=float(battle.config.test_parameters.vision_m) and battle.can_see(app.room_id,battle.position(id),app.hero_pos):return false
 return not a.last_seen.is_empty() or not a.get("investigation",{}).is_empty() or not str(a.follow).is_empty()

func _safe_landing(at:Vector2) -> bool:
 var b:Dictionary=battle.data.box;var space=battle.floor_for(str(b.room))
 if not space.walkable(at) or at.distance_to(battle.position("labor"))>4.0001:return false
 # Single-mouth maintenance branch: reserve its entire immediate return lane.
 for to in battle.map.doors(str(b.room)):
  var portal:Dictionary=space.portal(str(to))
  if at.distance_to(portal.at)<1.6 or at.distance_to(Geometry2D.get_closest_point_to_segment(at,portal.landing,portal.landing+Vector2(portal.inward)*1.6))<.7:return false
 if b.room==app.room_id and at.distance_to(app.hero_pos)<.7:return false
 return true

func _landing() -> Vector2:
 var at:Vector2=battle.position("labor");var best:=Vector2(-1,-1);var score:float=-INF
 for distance in [2.0,3.0,4.0]:
  for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
   var candidate:Vector2=at+direction*distance
   if not _safe_landing(candidate):continue
   var value:float=candidate.distance_to(app.hero_pos)
   if value>score:score=value;best=candidate
 return best

func _fly(delta:float) -> void:
 var b:Dictionary=battle.data.box;var space=battle.floor_for(str(b.room))
 if b.phase=="fall":
  b.height=maxf(0,float(b.height)-delta*float(battle.config.test_parameters.box_fall_m_s))
  if b.height<=0:b.phase="ground"
  return
 b.elapsed+=delta
 var t:float=minf(1,float(b.elapsed)/float(battle.config.test_parameters.box_flight_s))
 var old:Vector2=battle.vector(b.pos);var desired:Vector2=battle.vector(b.origin).lerp(battle.vector(b.target),t)
 var next:Vector2=space.clipped_step(old,desired)
 b.pos=battle.xy(next);b.height=(1-t)*.9+sin(t*PI)*.7
 if next.distance_to(desired)>.002:
  b.phase="fall";_impact()
 elif t>=1:
  b.phase="ground";b.height=0.0;_impact()

func _impact() -> void:
 var b:Dictionary=battle.data.box
 if b.sound_sent:return
 b.sound_sent=true
 var at:Vector2=battle.vector(b.pos)
 app.rules._record("physical_sound",receipt()+":impact",{"room":b.room,"at":b.pos.duplicate(),"object":b.id,"source":"S3:P1816"})
 if b.room==app.room_id and at.distance_to(app.hero_pos)<=6:app.audio.cue("SFX_DRAWER",receipt()+":impact") # Existing short wooden contact sound.
 for id in battle.data.actors:
  if _searching(str(id)) and battle.noises.hear(str(id),str(b.room),at,receipt()+":impact"):b.heard.append(str(id))

func _outcome() -> void:
 var b:Dictionary=battle.data.box
 if b.heard.is_empty() or b.line_sent or b.room!=app.room_id or app.rules.hp<=0:return
 var danger:bool=false
 for id in battle.data.actors:
  var a:Dictionary=battle.data.actors[id]
  if not a.present or a.hp<=0 or not a.hostile or a.room!=app.room_id:continue
  if battle.position(str(id)).distance_to(app.hero_pos)<3 and battle.can_see(app.room_id,battle.position(str(id)),app.hero_pos):danger=true
 for id in b.heard:
  var a:Dictionary=battle.data.actors[id]
  if a.present and a.hp>0 and a.room==b.room and battle.position(str(id)).distance_to(battle.vector(b.pos))<.65 and battle.position(str(id)).distance_to(app.hero_pos)>2:b.diverted=true
 if b.diverted and not danger and app.dialogue_queue.is_empty():
  b.line_sent=true;app.add_dialogue("角色 · 低声","刚才那一下，把它引开了。")
