extends SceneTree
## Actual CortexEvents movement across rebuilt door coordinates, not a map mock.
const Events=preload("res://scripts/core/cortex_events.gd")
const Layout=preload("res://scripts/world/cortex_layout.gd")
const Map=preload("res://scripts/core/cortex_map.gd")
var failures:Array=[]
var checks:int=0
class Fixture extends RefCounted:
 var room_id:String=""
 var hero_pos:=Vector2(100,100)
 var layout
 var layouts:Dictionary={}
 var version:int=2
 func layout_for_room(room:String):
  if not layouts.has(room):layouts[room]=Layout.new(room,version)
  return layouts[room]
func _initialize() -> void:call_deferred("run")
func verify(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func actor(room:String,at:Vector2) -> Dictionary:
 return {"room":room,"pos":[at.x,at.y],"phase":"idle","route":[],"facing":[0,1],"stand_done":false}
func run() -> void:
 for version:int in [1,2]:
  var fixture:=Fixture.new();fixture.version=version
  var events=Events.new(fixture)
  for room:String in Map.ALL_ROOMS:
   for to:String in Map.doors(room):
    if to.ends_with("exit"):continue
    var floor_layout=fixture.layout_for_room(room)
    var outgoing:Dictionary=floor_layout.portal(to)
    var start:Vector2=outgoing.landing if floor_layout.walkable(outgoing.landing) else outgoing.at
    events.data={"actors":{"backward":actor(room,start)}}
    var arrived:bool=false
    for tick in range(150):
     if events.travel("backward",to,.1):arrived=true;break
    verify(arrived,"v%d actual travel %s -> %s"%[version,room,to])
    if arrived:
     var entry:Vector2=fixture.layout_for_room(to).portal(room).at
     verify(events.position("backward").distance_to(entry)<.0001,"v%d enters reciprocal real door %s -> %s"%[version,room,to])
  fixture.layouts.clear()
 var fixture:=Fixture.new()
 var events=Events.new(fixture)
 events.data={"actors":{}}
 for id:String in events.config.rooms:
  var room:String=str(events.config.rooms[id]);var floor_layout=fixture.layout_for_room(room)
  events.data.actors[id]=actor(room,floor_layout.portal(str(Map.doors(room)[0])).at)
 for tick in range(600):events.advance_stands(.1)
 for id:String in events.config.rooms:
  verify(events.actor(id).stand_done,"rebuilt room actual actor arrived "+id)
  verify(fixture.layout_for_room(str(events.actor(id).room)).walkable(events.position(id)),"actor stays on real floor "+id)
 var twitch_start:Vector2=events.position("twitch")
 var rhythm=fixture.layout_for_room("rhythm")
 verify(rhythm.clear_segment(twitch_start,twitch_start+Vector2(0,1.5),.21),"rhythm retains actual 1.5m support-pull sweep")
 var verify_floor=fixture.layout_for_room("verify")
 var wanted:Vector2=(verify_floor.portal("combat_exit").at-events.position("face_press")).normalized()
 var actual:Array=events.actor("face_press").facing
 verify(wanted.distance_to(Vector2(actual[0],actual[1]))<.001,"face press faces rebuilt exit")
 var file:=FileAccess.open("res://../tmp/spatial_rebuild_20261019/neural_actor_portals_result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual CortexEvents.travel and advance_stands, all directed internal links at legacy and rebuilt geometry, all 11 actor task stands, fixed support-pull sweep and exit watch facing. No new mechanics or event outcomes."},"  "));file.close()
 print("NEURAL_ACTOR_PORTALS ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
