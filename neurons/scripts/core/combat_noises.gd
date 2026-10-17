extends RefCounted
## S3:P1530–1532. Only real collision requests make the rack sound.
var owner_ref:WeakRef
var combat:
 get:return owner_ref.get_ref()
var app:
 get:return combat.app
func _init(owner) -> void:owner_ref=weakref(owner)
func normalize() -> void:
 if not combat.data.has("rack_sound"):combat.data.rack_sound={"serial":0,"swing":0.0,"quiet":0.0,"latched":false}

func tick(delta:float) -> void:
 normalize()
 var state:Dictionary=combat.data.rack_sound
 state.swing=maxf(0,float(state.swing)-delta);state.quiet+=delta
 var contacts:Array=app.layout.contact_events.duplicate();app.layout.contact_events.clear()
 if contacts.is_empty():
  if state.quiet>=float(combat.config.test_parameters.rack_settle_s):state.latched=false
  return
 state.quiet=0.0
 if state.latched:return
 state.latched=true;state.swing=float(combat.config.test_parameters.rack_settle_s);state.serial+=1
 var at:Vector2=contacts[0];var receipt:String="rack:%d:%d"%[app.rules.actual_attempt,state.serial]
 app.audio.cue("SFX_RACK_CONTACT",receipt)
 app.rules._record("physical_sound",receipt,{"room":app.room_id,"at":combat.xy(at),"object":"memory_clothes_rack","source":"S3:P1530"})
 hear("self",app.room_id,at,receipt)

func hear(id:String,room:String,at:Vector2,receipt:String) -> bool:
 var a:Dictionary=combat.data.actors[id]
 if not a.present or a.hp<=0:return false
 if a.room==app.room_id and combat.position(id).distance_to(app.hero_pos)<=float(combat.config.test_parameters.vision_m) and combat.can_see(app.room_id,combat.position(id),app.hero_pos):return false
 var stand:Vector2=investigation_point(room,at,combat.position(id))
 var length:float=audible_distance(str(a.room),combat.position(id),room,stand)
 if length>float(combat.config.test_parameters.hearing_m):return false
 a.investigation={"room":room,"at":combat.xy(stand),"source_at":combat.xy(at),"receipt":receipt}
 # Keep the launched attack and its locked direction. Investigate afterwards.
 app.rules._record("sound_heard",receipt+":"+id,{"actor":id,"room":room,"at":combat.xy(at)})
 return true

func investigation_point(room:String,at:Vector2,listener:Vector2) -> Vector2:
 var space=combat.floor_for(room)
 if space.walkable(at):return at
 var chosen:=Vector2(-1,-1);var distance:float=INF
 for offset in [Vector2(.4,0),Vector2(-.4,0),Vector2(0,.8),Vector2(0,-.8)]:
  var candidate:Vector2=at+offset
  if space.walkable(candidate) and candidate.distance_to(listener)<distance:chosen=candidate;distance=candidate.distance_to(listener)
 return chosen

func audible_distance(from_room:String,from:Vector2,to_room:String,to:Vector2) -> float:
 if to.x<0:return INF
 var room:String=from_room;var at:Vector2=from;var length:float=0
 for i in range(8):
  var next:String=room if room==to_room else combat.map.next_room(room,to_room)
  if next.is_empty():return INF
  var goal:Vector2=to if room==to_room else combat.floor_for(room).portal(next).threshold
  var path:PackedVector2Array=combat.floor_for(room).path(at,goal)
  if path.is_empty():return INF
  for j in range(1,path.size()):length+=path[j-1].distance_to(path[j])
  if room==to_room:return length
  at=combat.floor_for(next).portal(room).landing;room=next;length+=.6
 return INF

func investigate(id:String,delta:float) -> bool:
 var a:Dictionary=combat.data.actors[id];var target:Dictionary=a.get("investigation",{})
 if target.is_empty():return false
 var room:String=str(a.room);var to:String=str(target.room)
 var next:String=room if room==to else combat.map.next_room(room,to)
 if next.is_empty():a.investigation={};return false
 var goal:Vector2=combat.vector(target.at) if room==to else combat.floor_for(room).portal(next).threshold
 combat._move_actor(id,goal,delta)
 if combat.position(id).distance_to(goal)>.08:return true
 if room==to:a.investigation={};a.last_seen=[];a.route=[];return true
 var landing:Vector2=combat.floor_for(next).portal(room).landing
 if next==app.room_id and landing.distance_to(app.hero_pos)<.65:return true
 a.room=next;a.pos=combat.xy(landing);a.route=[];a.goal=[]
 return true
