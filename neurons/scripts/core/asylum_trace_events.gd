extends RefCounted
## S3:P950–1013. Independent deceased, persistent traces, two living owners.
## A remembered statement and a verified number/date relation are different.
const Map=preload("res://scripts/core/asylum_map.gd")
var _owner:WeakRef
var owner:
 get:return _owner.get_ref()
var config:Dictionary={}

func _init(events) -> void:
 _owner=weakref(events)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_trace_events.json"))

func state() -> Dictionary:
 if not owner.data.has("trace_events"):
  owner.data.trace_events={"corpse":{"identity":"independent_deceased","room":"bathroom","pos":owner.xy(owner.space_point("bathroom","corpse_origin",Vector2(4.2,1.1))),"covered":false,"on_board":false,"moved_out":false},"cleaner":{"phase":"idle","elapsed":0.0,"relic_index":0,"wash_index":0},"screen_closed":false,"washed":[],"read":{},"active":{},"conversation":{"phase":"idle","elapsed":0.0,"shown":{},"complete":false,"stopped":false},"corner":{"phase":"idle","elapsed":0.0,"done":false,"witness":false}}
 var result:Dictionary=owner.data.trace_events
 for id in ["asylum_corpse_wristband","asylum_meal_list"]:
  if not owner.app.rules.owners.has(id):owner.app.rules.owners[id]=str(config.relics[id].owner)
 for id in ["asylum_patient_transfer_note","asylum_corner_transfer_note"]:
  if not owner.app.rules.owners.has(id):owner.app.rules.owners[id]=str(config.notes[id].actor)
 if not owner.data.has("staff_targets"):owner.data.staff_targets={}
 return result

func vector(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func relic_point(id:String) -> Vector2:return owner.space_point("bathroom","relic_"+id,vector(config.relics[id].pos))
func wash_point(region:Dictionary) -> Vector2:return owner.space_point("bathroom","wash_"+str(region.id),vector(region.pos))
func say(key:String) -> void:
 if not owner.claim("trace_line:"+key,"asylum_trace_dialogue"):return
 for line in config.dialogue.get(key,[]):owner.app.add_dialogue(str(line.speaker),str(line.text))
func known(id:String,text:String,kind:String="亲历事实") -> void:
 if not id in owner.app.rules.known:owner.app.rules.known.append(id)
 owner.app.rules.observe("物品",id,text,kind,"精神病院现场")
func usable() -> bool:
 return owner!=null and owner.enabled and not owner.data.is_empty() and owner.app.session.data.level==3 and owner.app.rules.hp>0
func blocks_hero() -> bool:
 return usable() and not state().active.is_empty()
func staff_busy(id:String) -> bool:
 return not str(owner.data.staff_targets.get(id,"")).is_empty() or str(owner.data.body.get("actor",""))==id or str(owner.data.holder)==id

func actors_clear(id:String,from:Vector2,to:Vector2,room:String,ignore:Array=[]) -> bool:
 var clearance:float=float(config.parameters.body_clearance)
 if room==owner.app.room_id and Geometry2D.get_closest_point_to_segment(owner.app.hero_pos,from,to).distance_to(owner.app.hero_pos)<clearance:return false
 for other in owner.data.actors:
  if str(other)==id or str(other) in ignore or not owner.present(str(other)) or str(owner.actor(str(other)).room)!=room:continue
  var at:Vector2=owner.position(str(other))
  if Geometry2D.get_closest_point_to_segment(at,from,to).distance_to(at)<clearance:return false
 return true
func safe_move(id:String,to:Vector2,delta:float,ignore:Array=[]) -> bool:
 if not owner.present(id):return false
 var a:Dictionary=owner.actor(id)
 var origin:Vector2=owner.position(id)
 if origin.distance_to(to)<0.035:return true
 var floor_layout=owner.layout_for(str(a.room))
 # Keep the unconsumed real corner waypoint. Replanning from every fractional
 # position rounds away that corner and can point diagonally through furniture.
 var route:PackedVector2Array=PackedVector2Array()
 for waypoint in a.route:route.append(vector(waypoint))
 if route.is_empty() or route[-1].distance_to(to)>0.08:route=floor_layout.path(origin,to)
 if route.is_empty():return false
 var moved:Dictionary=floor_layout.move_path(origin,route,float(config.parameters.walk_speed)*delta)
 if not actors_clear(id,origin,moved.position,str(a.room),ignore):return false
 a.pos=owner.xy(moved.position);a.route=Array(moved.route).map(func(p):return owner.xy(p))
 return owner.position(id).distance_to(to)<0.035
func safe_travel(id:String,room:String,delta:float,ignore:Array=[]) -> bool:
 if not owner.present(id):return false
 var a:Dictionary=owner.actor(id)
 if str(a.room)==room:return true
 var next:String=Map.next_room(str(a.room),room)
 if next.is_empty() or next=="cortex_exit":return false
 if owner.isolation!=null and not owner.isolation.can_exit(str(a.room),next):return false
 if not safe_move(id,owner.portal_for(str(a.room),next).threshold,delta,ignore):return false
 var entry:Vector2=owner.portal_for(next,str(a.room)).landing
 if not actors_clear(id,entry,entry,next,ignore):return false
 a.room=next;a.pos=owner.xy(entry);a.route=[]
 return str(a.room)==room

func tick(delta:float) -> void:
 if not usable():return
 state()
 advance_read(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_corner(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_conversation(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_cleaner(delta)

func advance_cleaner(delta:float) -> void:
 if not owner.present("cleaner"):return
 var value:Dictionary=state();var event:Dictionary=value.cleaner;var corpse:Dictionary=value.corpse
 if event.phase=="idle":
  if not owner.near("cleaner",float(config.parameters.notice_distance)) or owner.app.room_id!="bathroom":return
  event.phase="screen";event.elapsed=0.0;say("COVER");return
 if event.phase=="done":return
 if event.phase in ["screen","cover","board"]:
  if not safe_travel("cleaner","bathroom",delta):return
  if not safe_move("cleaner",vector(corpse.pos),delta):return
  event.elapsed+=delta
  if float(event.elapsed)<float(config.parameters.contact_seconds):return
  event.elapsed=0.0
  if event.phase=="screen":value.screen_closed=true;event.phase="cover"
  elif event.phase=="cover":corpse.covered=true;event.phase="board"
  else:corpse.on_board=true;event.phase="exit";owner.claim("corpse_board","asylum_corpse_loaded",{"identity":"independent_deceased"})
  return
 if event.phase=="exit":
  if str(owner.actor("cleaner").room)!="bathroom":return
  var exit:Vector2=owner.portal_for("bathroom","corridor").threshold
  var reached:bool=safe_move("cleaner",exit,delta)
  corpse.pos=owner.xy(owner.position("cleaner"))
  if not reached:return
  var entry:Vector2=owner.portal_for("corridor","bathroom").landing
  if not actors_clear("cleaner",entry,entry,"corridor"):return
  owner.actor("cleaner").room="corridor";owner.actor("cleaner").pos=owner.xy(entry);owner.actor("cleaner").route=[]
  corpse.room="corridor";corpse.pos=owner.xy(entry);corpse.moved_out=true;event.phase="park"
  owner.claim("corpse_exit","asylum_corpse_moved_out",{"identity":"independent_deceased","to":"corridor"});return
 if event.phase=="park":
  if safe_move("cleaner",owner.space_point("corridor","corridor_parking",vector(config.corridor_parking)),delta):event.phase="return"
  corpse.pos=owner.xy(owner.position("cleaner"));return
 if event.phase=="return":
  if safe_travel("cleaner","bathroom",delta):event.phase="relic";event.elapsed=0.0
  return
 if event.phase=="relic":
  if not safe_travel("cleaner","bathroom",delta):return
  var ids:Array=config.relic_order
  if int(event.relic_index)>=ids.size():event.phase="wash";event.elapsed=0.0;return
  var id:String=str(ids[int(event.relic_index)])
  var item:Dictionary=config.relics[id]
  if owner.app.rules.owners.get(id,"")!=str(item.owner):event.relic_index+=1;event.elapsed=0.0;return
  if not safe_move("cleaner",relic_point(id),delta):return
  event.elapsed+=delta
  if float(event.elapsed)<float(config.parameters.contact_seconds):return
  # No collection can reclaim the protagonist's already-owned item.
  if owner.app.rules.owners.get(id,"")==str(item.owner):
   owner.app.rules.owners[id]="asylum_cleaner_bucket"
   owner.claim("cleaner_pickup:"+id,"asylum_relic_collected",{"id":id,"from":str(item.owner)})
  event.relic_index+=1;event.elapsed=0.0;return
 if event.phase=="wash":
  if not safe_travel("cleaner","bathroom",delta):return
  var regions:Array=config.wash_regions
  if int(event.wash_index)>=regions.size():event.phase="done";return
  var region:Dictionary=regions[int(event.wash_index)]
  if not safe_move("cleaner",wash_point(region),delta):return
  event.elapsed+=delta
  if float(event.elapsed)<float(config.parameters.wash_seconds):return
  if not str(region.id) in value.washed:value.washed.append(str(region.id))
  owner.claim("wash:"+str(region.id),"asylum_trace_washed",{"region":str(region.id)})
  event.wash_index+=1;event.elapsed=0.0

func medical_listener() -> bool:
 for id in config.medical_staff:
  if not owner.present(str(id)):continue
  var room:String=str(owner.actor(str(id)).room)
  if room=="double_ward":return true
  if room=="corridor" and owner.position(str(id)).distance_to(owner.portal_for("corridor","double_ward").at)<=float(config.parameters.door_notice):return true
 return false
func double_actor_here(id:String) -> bool:
 return owner.present(id) and str(owner.actor(id).room)=="double_ward"
func orderly_sees_corner() -> bool:
 if not owner.present("ordinary_orderly") or not double_actor_here("corner_patient"):return false
 var target:Vector2=owner.position("corner_patient")
 if owner.visible("ordinary_orderly",target,"double_ward",float(config.parameters.notice_distance)):return true
 if str(owner.actor("ordinary_orderly").room)!="corridor":return false
 var outside:Vector2=owner.portal_for("corridor","double_ward").at
 var inside:Vector2=owner.portal_for("double_ward","corridor").at
 var distance:float=owner.position("ordinary_orderly").distance_to(outside)
 return distance<=float(config.parameters.door_notice) and distance+inside.distance_to(target)<=float(config.parameters.notice_distance) and owner.layout_for("corridor").clear_segment(owner.position("ordinary_orderly"),outside) and owner.layout_for("double_ward").clear_segment(inside,target)
func advance_conversation(delta:float) -> void:
 var value:Dictionary=state();var event:Dictionary=value.conversation
 if event.phase=="idle" and owner.app.rules.sp<50:return
 var listener:bool=medical_listener()
 if listener:
  if event.phase!="idle":event.stopped=true;event.shown={};event.phase="stopped"
  return
 if event.complete:
  event.shown={};event.phase="complete";return
 if value.corner.done:return
 if owner.app.room_id!="double_ward" or not owner.near("corner_patient",1.2):return
 if event.phase=="stopped":return
 if event.phase=="idle":
  if owner.app.has_key() or owner.app.action_phase in ["return_bed","resting"] or owner.app.rules.sp<=0:return
  event.phase="prepare";event.elapsed=0.0
  if double_actor_here("patient") and owner.near("patient",2.0):
   say("SAME_CAR")
   known("asylum_same_car_statement","跨关精神病人实际陈述两人同车送来；是当事人陈述，尚未核对两张凭条的日期车次。","当事人陈述")
  return
 if event.phase=="prepare":
  event.elapsed+=delta
  if float(event.elapsed)<float(config.parameters.contact_seconds):return
  event.shown.asylum_corner_transfer_note=true
  if double_actor_here("patient") and owner.near("patient",2.0):event.shown.asylum_patient_transfer_note=true
  event.phase="shown";say("CORNER_SHOW")

func advance_corner(delta:float) -> void:
 var value:Dictionary=state();var event:Dictionary=value.corner
 if event.done:return
 if event.phase=="idle":
  if not owner.present("ordinary_orderly") or not double_actor_here("corner_patient") or not value.conversation.shown.get("asylum_corner_transfer_note",false):return
  if staff_busy("ordinary_orderly"):return
  if not orderly_sees_corner():return
  owner.data.staff_targets.ordinary_orderly="corner_patient";event.phase="approach";event.elapsed=0.0
  event.last_room="double_ward";event.last_pos=owner.xy(owner.position("corner_patient"))
  event.witness=owner.near("corner_patient",2.0)
  owner.actor("ordinary_orderly").phase="trace_corner_approach"
  return
 if not owner.present("ordinary_orderly") or not owner.present("corner_patient"):
  finish_corner(false);return
 var room:String=str(owner.actor("ordinary_orderly").room)
 if str(owner.actor("corner_patient").room)!=room and event.phase!="approach":finish_corner(false);return
 if event.phase=="approach":
  if room!="double_ward":
   if room=="corridor":safe_travel("ordinary_orderly","double_ward",delta)
   else:finish_corner(false)
   return
  if not double_actor_here("corner_patient") or not owner.visible("ordinary_orderly",owner.position("corner_patient"),"double_ward",float(config.parameters.notice_distance)):
   if safe_move("ordinary_orderly",vector(event.last_pos),delta,["corner_patient"]):finish_corner(false)
   return
  event.last_pos=owner.xy(owner.position("corner_patient"))
  var target:Vector2=owner.position("corner_patient")
  if owner.position("ordinary_orderly").distance_to(target)>0.55:
   safe_move("ordinary_orderly",target,delta,["corner_patient"]);return
  event.phase="reach";event.elapsed=0.0;owner.actor("ordinary_orderly").phase="trace_corner_reach"
  value.conversation.shown={};value.conversation.stopped=true;value.conversation.phase="stopped"
  if owner.near("ordinary_orderly",2.0):say("ORDERLY")
  return
 if event.phase=="reach":
  event.elapsed+=delta
  if float(event.elapsed)<float(config.parameters.reach_seconds):return
  if owner.position("ordinary_orderly").distance_to(owner.position("corner_patient"))>0.65 or not owner.layout_for(room).clear_segment(owner.position("ordinary_orderly"),owner.position("corner_patient")):
   finish_corner(false);return
  if not owner.claim("corner_grip","asylum_corner_gripped"):finish_corner(false);return
  event.phase="drag";owner.actor("ordinary_orderly").phase="trace_corner_drag";owner.actor("corner_patient").phase="trace_held"
  if owner.near("corner_patient",2.0):say("CORNER_HELD")
  return
 if event.phase=="drag":
  event.witness=bool(event.witness) and owner.near("corner_patient",2.0)
  var destination:Vector2=owner.portal_for("double_ward","corridor").threshold if room=="double_ward" else owner.space_point("corridor","corner_waiting",vector(config.corner_waiting))
  var arrived:bool=owner.position("ordinary_orderly").distance_to(destination)<0.035
  if owner.position("ordinary_orderly").distance_to(owner.position("corner_patient"))<=0.6:arrived=safe_move("ordinary_orderly",destination,delta,["corner_patient"])
  var leader:Vector2=owner.position("ordinary_orderly")
  var follower:Vector2=owner.position("corner_patient")
  var gap:Vector2=leader-follower
  var follow_target:Vector2=follower
  if arrived and room=="double_ward":follow_target=destination
  elif gap.length()>0.42:follow_target=leader-gap.normalized()*0.42
  safe_move("corner_patient",follow_target,delta,["ordinary_orderly"])
  if owner.position("corner_patient").distance_to(destination)>(0.05 if room=="double_ward" else 0.55):return
  if room=="double_ward":
   var entry:Vector2=owner.portal_for("corridor","double_ward").landing
   if not actors_clear("ordinary_orderly",entry,entry,"corridor",["corner_patient"]):return
   for id in ["ordinary_orderly","corner_patient"]:
    owner.actor(id).room="corridor";owner.actor(id).pos=owner.xy(entry);owner.actor(id).route=[]
  else:finish_corner(true)

func finish_corner(delivered:bool) -> void:
 var value:Dictionary=state();var event:Dictionary=value.corner
 event.done=true;event.phase="released";event.delivered=delivered
 owner.data.staff_targets.erase("ordinary_orderly")
 if owner.present("ordinary_orderly"):owner.actor("ordinary_orderly").phase="idle";owner.actor("ordinary_orderly").route=[]
 if owner.present("corner_patient"):owner.actor("corner_patient").phase="idle";owner.actor("corner_patient").route=[]
 owner.claim("corner_end","asylum_corner_release",{"delivered":delivered})
 if delivered and bool(event.witness):known("asylum_corner_removed_seen","亲见普通护工抓住仍出示凭条的角落病友，实际送至走廊候诊位并松手；凭条归属及已读信息保留。");say("WITNESS_CORNER")

func relic_location(id:String) -> Dictionary:
 var value:Dictionary=state()
 if id=="corpse_tag":return {"room":value.corpse.room,"pos":value.corpse.pos,"visible":not value.corpse.covered and not value.screen_closed}
 if config.relics.has(id):
  var item:Dictionary=config.relics[id];var holder:String=str(owner.app.rules.owners.get(id,""))
  if holder=="hero":return {"room":owner.app.room_id,"pos":owner.xy(owner.app.hero_pos),"visible":true}
  if holder=="asylum_cleaner_bucket" and owner.present("cleaner"):return {"room":owner.actor("cleaner").room,"pos":owner.xy(owner.position("cleaner")),"visible":true}
  return {"room":"bathroom","pos":owner.xy(relic_point(id)),"visible":holder==str(item.owner) and not str(item.region) in value.washed}
 if config.notes.has(id):
  var who:String=str(config.notes[id].actor)
  if str(owner.app.rules.owners.get(id,""))=="hero":return {"room":owner.app.room_id,"pos":owner.xy(owner.app.hero_pos),"visible":true}
  return {"room":str(owner.actor(who).get("room","")),"pos":owner.xy(owner.position(who)),"visible":double_actor_here(who) and value.conversation.shown.get(id,false)}
 return {}
func contact(id:String) -> bool:
 var location:Dictionary=relic_location(id)
 if location.is_empty() or not location.visible or str(location.room)!=owner.app.room_id:return false
 var at:Vector2=vector(location.pos)
 return owner.app.hero_pos.distance_to(at)<=float(config.parameters.read_distance) and owner.app.layout.clear_segment(owner.app.hero_pos,at)
func begin_read(id:String) -> bool:
 if not usable() or not state().active.is_empty() or owner.app.rules.body_busy() or owner.app.rules.gripped or not owner.data.body.is_empty() or not owner.app.dialogue_queue.is_empty() or not contact(id):return false
 owner.app.rules.cancel_search();owner.app.hero_route=PackedVector2Array();owner.app.target_index=-1
 state().active={"id":id,"kind":"read","elapsed":0.0,"controlled":owner.app.rules.control_left>0,"room":owner.app.room_id,"holder":str(owner.app.rules.owners.get(id,""))}
 state().active.origin="controlled" if state().active.controlled else "autonomous"
 owner.app.rules.begin_public_action("observe",id,str(state().active.origin),owner.app.room_id)
 return true
func read_at(room:String,index:int) -> bool:
 var id:String=""
 if room=="bathroom":id={2:"asylum_corpse_wristband",3:"corpse_tag",4:"asylum_meal_list"}.get(index,"")
 elif room=="double_ward":id="asylum_patient_transfer_note" if index in [2,4] else "asylum_corner_transfer_note" if index in [3,5] else ""
 return not id.is_empty() and begin_read(id)
func take_relic(id:String) -> bool:
 if not usable() or not config.relics.has(id) or not state().active.is_empty() or owner.app.rules.body_busy() or owner.app.rules.gripped or not owner.data.body.is_empty() or not owner.app.dialogue_queue.is_empty() or not contact(id) or owner.app.rules.owners.get(id,"")=="hero":return false
 owner.app.rules.cancel_search();owner.app.hero_route=PackedVector2Array();owner.app.target_index=-1
 state().active={"id":id,"kind":"take","elapsed":0.0,"controlled":owner.app.rules.control_left>0,"room":owner.app.room_id,"holder":str(owner.app.rules.owners.get(id,""))}
 state().active.origin="controlled" if state().active.controlled else "autonomous"
 owner.app.rules.begin_public_action("take",id,str(state().active.origin),owner.app.room_id)
 return true
func cancel_read() -> void:
 if not state().active.is_empty():owner.app.rules.finish_public_action(str(state().active.get("origin","controlled" if state().active.get("controlled",false) else "autonomous")))
 state().active={}
func advance_read(delta:float) -> void:
 var value:Dictionary=state();var active:Dictionary=value.active
 if active.is_empty():return
 var id:String=str(active.id)
 if owner.app.room_id!=str(active.room) or owner.app.rules.body_busy() or owner.app.rules.gripped or not owner.data.body.is_empty() or not contact(id) or str(owner.app.rules.owners.get(id,""))!=str(active.holder) or (active.controlled and owner.app.rules.control_left<=0):cancel_read();return
 active.elapsed+=minf(delta,owner.app.rules.control_left) if active.controlled else delta
 var duration:float=float(config.parameters.read_seconds if active.kind=="read" else config.parameters.contact_seconds)
 if float(active.elapsed)+0.000001<duration:return
 if active.kind=="take":
  if owner.claim("take:"+id,"asylum_relic_taken",{"id":id,"from":active.holder}):owner.app.rules.owners[id]="hero"
 else:complete_read(id)
 if active.controlled:owner.app.rules.controlled_execution(str(active.kind),id)
 cancel_read()

func complete_read(id:String) -> void:
 var value:Dictionary=state()
 var fields:Dictionary=config.glyphs.get(id,{}).duplicate(true)
 if value.read.has(id) and value.read[id].fields==fields:return
 value.read[id]={"fields":fields,"room":owner.app.room_id}
 known(id,str(config.read_text.get(id,"实际看清本物件的可辨部分；未交付字形继续未知。")))
 if id=="corpse_tag":say("CORPSE_SEEN")
 if config.notes.has(id):
  var count:int=int(value.read.has("asylum_patient_transfer_note"))+int(value.read.has("asylum_corner_transfer_note"))
  value.conversation.read_count=count
  if count==1:say("ONE_NOTE")
  if count==2:
   value.conversation.complete=true
   var first:Dictionary=value.read.asylum_patient_transfer_note.fields
   var second:Dictionary=value.read.asylum_corner_transfer_note.fields
   if supplied(first.get("date")) and supplied(first.get("vehicle")) and supplied(first.get("number")) and supplied(second.get("date")) and supplied(second.get("vehicle")) and supplied(second.get("number")) and first.date==second.date and first.vehicle==second.vehicle and first.number!=second.number:
    known("asylum_same_vehicle_verified","实际分别读清两份凭条，日期车次相同而个人编号不同；不套用轮椅患者或本节推床患者。" );say("BOTH_NOTES")
  return
 var ids:Array=["corpse_tag","asylum_corpse_wristband","asylum_meal_list"]
 for other in ids:
  if str(other)==id or not value.read.has(str(other)):continue
  var number:Variant=value.read[str(other)].fields.get("number")
  if supplied(number) and supplied(fields.get("number")) and number==fields.number:
   known("asylum_deceased_relic_match","实际读清独立死者两件物件的可辨编号并核对一致；名单只证明记录存在，不证明仍活着。" );say("RELIC_MATCH");break
func supplied(value) -> bool:return value!=null and not str(value).strip_edges().is_empty()

func on_skill(result:Dictionary) -> void:
 if result.get("success",false) and str(result.get("id","")) in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:cancel_read()
 # The skill acts on the protagonist; an unrelated cleaner or NPC grip is
 # never cancelled, and the dead remain separate from every living identity.
func kick_contact() -> void:pass
func on_search_complete(index:int,found_key:bool) -> void:
 if found_key:return
 if owner.app.room_id in ["bathroom","double_ward"]:read_at(owner.app.room_id,index)

func render_state() -> Array:
 if not usable():return []
 var value:Dictionary=state();var result:Array=[]
 var corpse:Dictionary=value.corpse
 result.append({"id":"asylum_independent_corpse","room":corpse.room,"pos":corpse.pos.duplicate(),"covered":corpse.covered,"screen_closed":value.screen_closed and corpse.room=="bathroom","on_board":corpse.on_board,"kind":"corpse"})
 for id in config.relics:
  var location:Dictionary=relic_location(str(id))
  if location.visible and owner.app.rules.owners.get(id,"")!="hero":result.append({"id":id,"room":location.room,"pos":location.pos.duplicate(),"kind":"relic","holder":owner.app.rules.owners.get(id,"")})
 for region in config.wash_regions:
  if not str(region.id) in value.washed:result.append({"id":"trace_"+str(region.id),"room":"bathroom","pos":owner.xy(wash_point(region)),"kind":"trace"})
 for id in value.conversation.shown:
  if value.conversation.shown[id]:
   var location:Dictionary=relic_location(str(id))
   if location.visible:result.append({"id":id,"room":location.room,"pos":location.pos.duplicate(),"kind":"note"})
 return result
