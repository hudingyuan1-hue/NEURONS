extends RefCounted
## L4 actual actors and lower-floor events. Source facts, knowledge and paper
## classifications remain separate; no display art controls settlement.
const Appearance=preload("res://scripts/core/appearance_history.gd")
const Map=preload("res://scripts/core/cortex_map.gd")
var app
var config:Dictionary={}
var data:Dictionary={}
var enabled:bool=true
var upper_events

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/cortex_events.json"))

func start_attempt(carry:Dictionary={}) -> void:
 if not data.is_empty() and data.has("paper"):remember_physical_materials()
 data={"actors":{},"groups":{},"room_left":{},"batches":{},"clock":0.0,"receipts":{},"body":{},"holder":"","regrab_elapsed":0.8,"carry":carry.duplicate(true),"observation":{},"visible_reaction":{},"completed_observations":{},"observed_fields":{},"back":{"phase":"idle","elapsed":0.0,"front_seen":false,"back_seen":false},"paper":{"phase":"idle","elapsed":0.0,"progress":0.0,"attempted":false,"gripped":false,"read":false,"taken":false,"remaining":"whole","read_fields":{},"source":{},"original":{},"revised":{}},"video":{"phase":"idle","elapsed":0.0,"playing":false,"playback":0.0,"mask_count":0,"overlay":false,"overlay_seen":false,"source":{}},"mimic":{"phase":"idle","elapsed":0.0,"source":{},"attempted":false,"witnessed":false,"written":false},"clamp":{"phase":"idle","elapsed":0.0,"attempted":false,"hand_out":false,"retract_left":0.0,"hurt":false,"pain_light":false},"upper_state":{}}
 for id in config.rooms:
  data.actors[id]={"room":str(config.rooms[id]),"pos":[0.0,0.0],"route":[],"phase":"absent","elapsed":0.0,"facing":[0,-1],"stand_done":false}
  data.groups[id]={"checks":0,"pending":false,"drawn":false}
 bind_evidence()
 restore_physical_materials()
 data.playbacks={}

func restore(saved:Dictionary) -> void:
 if saved.is_empty():
  if int(app.session.data.level)==4:start_attempt()
  else:data={}
 else:
  data=saved.duplicate(true)
  if not data.has("playbacks"):data.playbacks={}

func physical_materials() -> Dictionary:
 if not app.session.data.has("cortex_lower_persistent"):app.session.data.cortex_lower_persistent={}
 return app.session.data.cortex_lower_persistent
func remember_physical_materials() -> void:
 var value:Dictionary=physical_materials()
 value.paper={"source":data.paper.source.duplicate(true),"remaining":data.paper.remaining,"progress":data.paper.progress,"taken":data.paper.taken,"read":data.paper.read,"read_fields":data.paper.read_fields.duplicate(true),"attempted":data.paper.attempted,"original_owner":str(app.rules.owners.get("cortex_original_page","memory_table")),"fragment_owner":str(app.rules.owners.get("cortex_page_fragment","none")),"scraps_owner":str(app.rules.owners.get("cortex_page_scraps","none")),"collected":bool(data.paper.get("collected",false))}
 value.video={"source":data.video.source.duplicate(true),"mask_count":data.video.mask_count,"overlay_seen":data.video.overlay_seen}
func restore_physical_materials() -> void:
 var value:Dictionary=physical_materials();var paper:Dictionary=value.get("paper",{})
 if not paper.is_empty() and paper.get("source",{}).get("event_id","")==data.paper.source.get("event_id",""):
  for key in ["remaining","progress","taken","read","read_fields","attempted"]:data.paper[key]=paper[key]
  data.paper.phase="done" if data.paper.taken or data.paper.remaining in ["corner","fragments"] else "interrupted" if data.paper.attempted else "idle"
  if float(data.paper.progress)>0 and data.paper.remaining=="whole":data.paper.remaining="partly_torn"
  app.rules.owners.cortex_original_page=str(paper.original_owner);app.rules.owners.cortex_page_fragment=str(paper.fragment_owner)
  app.rules.owners.cortex_page_scraps=str(paper.get("scraps_owner","none"));data.paper.collected=bool(paper.get("collected",false))
 else:
  app.rules.owners.cortex_original_page="memory_table";app.rules.owners.cortex_page_fragment="none";app.rules.owners.cortex_page_scraps="none"
 var video:Dictionary=value.get("video",{})
 if not video.is_empty() and video.get("source",{}).get("event_id","")==data.video.source.get("event_id",""):
  data.video.mask_count=int(video.mask_count);data.video.overlay_seen=bool(video.overlay_seen)
  if int(data.video.mask_count)>=data.video.mask_targets.size():data.video.phase="done"

func usable() -> bool:return enabled and not data.is_empty() and int(app.session.data.level)==4 and not app.session.data.get("cortex_exit_crossed",false) and app.rules.hp>0
func actor(id:String) -> Dictionary:return data.get("actors",{}).get(id,{})
func xy(value:Vector2) -> Array:return [value.x,value.y]
func position(id:String) -> Vector2:
 var p:Array=actor(id).get("pos",[0.0,0.0])
 return Vector2(float(p[0]),float(p[1]))
func present(id:String) -> bool:return enabled and not actor(id).is_empty() and actor(id).get("phase","absent") not in ["absent","gone"]
func layout_for(room:String):return app.layout if room==app.room_id else app.layout_for_room(room)
func near(id:String,distance:float=1.2) -> bool:
 return usable() and present(id) and str(actor(id).room)==app.room_id and position(id).distance_to(app.hero_pos)<=distance and app.layout.clear_segment(position(id),app.hero_pos)
func visible(id:String,at:Vector2,room:String,distance:float=2.0) -> bool:
 return present(id) and str(actor(id).room)==room and position(id).distance_to(at)<=distance and layout_for(room).clear_segment(position(id),at)
func actor_sees(id:String,at:Vector2,room:String,distance:float=2.0) -> bool:
 if not visible(id,at,room,distance):return false
 var offset:Vector2=at-position(id);var facing:Array=actor(id).get("facing",[0,-1])
 return offset.length()<0.035 or Vector2(float(facing[0]),float(facing[1])).dot(offset.normalized())>0.15
func hero_sees(id:String,distance:float=2.0) -> bool:
 if not near(id,distance):return false
 var offset:Vector2=position(id)-app.hero_pos
 return offset.length()<0.035 or app.hero_facing.dot(offset.normalized())>0.15
func face_target(id:String,at:Vector2) -> void:
 if present(id) and position(id).distance_to(at)>0.001:actor(id).facing=xy((at-position(id)).normalized())
func actor_contact(id:String,at:Vector2,room:String,distance:float=0.7) -> bool:
 if not visible(id,at,room,distance):return false
 var offset:Vector2=at-position(id);var facing:Array=actor(id).get("facing",[0,-1])
 return offset.length()<0.035 or Vector2(float(facing[0]),float(facing[1])).dot(offset.normalized())>0.35
func point(room:String,index:int) -> Vector2:
 var layout=layout_for(room)
 return layout.furniture[index].at if index>=0 and index<layout.furniture.size() else Vector2.INF
func beside(room:String,at:Vector2,prefer:Vector2=Vector2(0.5,0)) -> Vector2:
 var layout=layout_for(room)
 for offset in [prefer,-prefer,Vector2(0,0.5),Vector2(0,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
  if room==app.room_id and (at+offset).distance_to(app.hero_pos)<.32:continue
  if layout.walkable(at+offset) and layout.clear_segment(at,at+offset):return at+offset
 return at

func move(id:String,to:Vector2,delta:float) -> bool:
 if not present(id) or not to.is_finite():return false
 var a:Dictionary=actor(id);var floor_layout=layout_for(str(a.room))
 if position(id).distance_to(to)<0.035:return true
 var path:PackedVector2Array=PackedVector2Array()
 for p in a.route:path.append(Vector2(float(p[0]),float(p[1])))
 if path.is_empty() or path[-1].distance_to(to)>0.08:path=floor_layout.path(position(id),to)
 var moved:Dictionary=floor_layout.move_path(position(id),path,float(config.presentation.walk_speed)*delta)
 var next:Vector2=moved.position
 var bodies:Array=[]
 if str(a.room)==app.room_id:bodies.append({"pos":app.hero_pos,"radius":.32})
 for other in data.actors:
  if other!=id and present(str(other)) and str(actor(str(other)).room)==str(a.room):bodies.append({"pos":position(str(other)),"radius":.3})
 if not floor_layout.segment_avoids_bodies(position(id),next,bodies):
  path=floor_layout.path_around_bodies(position(id),to,bodies)
  if path.is_empty():return false
  moved=floor_layout.move_path(position(id),path,float(config.presentation.walk_speed)*delta);next=moved.position
 # Actors cannot walk through the protagonist or one another. Navigation
 # may wait for a genuine obstruction; no remote snap to the contact point.
 if str(a.room)==app.room_id and next.distance_to(app.hero_pos)<0.32 and position(id).distance_to(app.hero_pos)>=0.32:return false
 for other in data.actors:
  if other==id or not present(str(other)) or str(actor(str(other)).room)!=str(a.room):continue
  if next.distance_to(position(str(other)))<0.3 and position(id).distance_to(position(str(other)))>=0.3:return false
 if next.distance_to(position(id))>0.0001:a.facing=xy((next-position(id)).normalized())
 a.pos=xy(next);a.route=Array(moved.route).map(func(p):return xy(p))
 return position(id).distance_to(to)<0.035

func travel(id:String,room:String,delta:float) -> bool:
 if not present(id):return false
 var a:Dictionary=actor(id)
 if str(a.room)==room:return true
 var step:String=Map.next_room(str(a.room),room)
 if step.is_empty() or step.ends_with("exit"):return false
 # The logical graph does not encode the current metre contour or door side.
 # Use this saved attempt's actual layout for both ends, including legacy rooms.
 var outgoing:Dictionary=layout_for(str(a.room)).portal(step)
 if outgoing.is_empty():return false
 if move(id,outgoing.at,delta):
  var previous:String=str(a.room);var incoming:Dictionary=layout_for(step).portal(previous)
  if incoming.is_empty():return false
  var entry:Vector2=incoming.at
  if step==app.room_id and app.hero_pos.distance_to(entry)<0.45:return false
  for other in data.actors:
   if other!=id and present(str(other)) and str(actor(str(other)).room)==step and position(str(other)).distance_to(entry)<0.4:return false
  a.room=step;a.pos=xy(entry);a.route=[]
 return str(a.room)==room

func claim(id:String,kind:String,details:Dictionary={}) -> bool:
 var key:String="cortex:%d:%s"%[app.rules.actual_attempt,id]
 if data.receipts.has(key) or app.rules.hp<=0:return false
 data.receipts[key]=kind
 var fields:Dictionary=details.duplicate(true);fields.level=4;fields.attempt=app.rules.actual_attempt
 app.rules._record(kind,key,fields)
 # Existing development material cues only: each real successful claim owns
 # its sound receipt. Offscreen facts stay silent, and restoring state never
 # invokes this path or schedules delayed playback. Material fit is un-audited.
 var sound_map:Dictionary={
  "cortex_paper_pinched":["memory","SFX_SEARCH_PAPER"],
  "cortex_paper_torn":["memory","SFX_SEARCH_PAPER"],
  "cortex_name_label_extracted":["index","SFX_SEARCH_PAPER"],
  "cortex_action_recorded":["decision","SFX_SEARCH_PAPER"],
  "cortex_video_masked":["visual","SFX_DRAWER"],
  "cortex_clamp_handle_started":["body","SFX_DRAWER"],
  "cortex_clamp_missed":["body","SFX_DRAWER"]}
 if sound_map.has(kind) and app.get("audio")!=null and int(app.session.data.level)==4 and app.room_id==str(sound_map[kind][0]):
  app.audio.cue(str(sound_map[kind][1]),key)
 return true
func say(key:String) -> void:
 if not claim("line:"+key,"cortex_dialogue"):return
 for line in config.dialogue.get(key,[]):app.add_dialogue(str(line.speaker),str(line.text))
func observe(id:String,text:String) -> void:
 if not id in app.rules.known:app.rules.known.append(id)
 app.rules.observe("物品",id,text,"亲历事实","皮层与白质实际观察")
func record(id:String,text:String) -> void:
 for entry in app.rules.institutional_records:
  if entry.get("id","")==id:return
 app.rules.institutional_records.append({"id":id,"text":text,"source":"皮层与白质记录","attempt":app.rules.actual_attempt})
func damage(id:String,hp:int,sp:int) -> bool:
 if not claim(id,"cortex_damage",{"hp_damage":hp,"sp_damage":sp}):return false
 app.rules.hp=maxi(0,app.rules.hp-hp);app.rules.change_sp(-sp)
 if hp>0:app.rules.vitality_lost.emit()
 if app.get("audio")!=null:app.audio.cue("hit","cortex:%d:%s"%[app.rules.actual_attempt,id])
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1;cancel_observation("hurt")
 if app.rules.hp>0 and hp>0:app.rules.hurt_left=maxf(app.rules.hurt_left,0.25)
 return true
func set_body(kind:String,id:String) -> void:
 if not data.body.is_empty():return
 cancel_observation("physical_contact")
 data.body={"kind":kind,"actor":id,"elapsed":0.0}
 # Preserve an already-opening door and its exact remaining opening time.
 app.rules.cancel_search();app.hero_route=PackedVector2Array();app.target_index=-1
func clear_body() -> void:
 data.body={}
 if str(data.holder).is_empty():app.rules.gripped=false
func blocks_hero() -> bool:
 return usable() and (not data.body.is_empty() or not str(data.holder).is_empty() or not data.observation.is_empty())
func eligible() -> bool:
 return usable() and not app.has_key() and not app.rules.search_active and app.action_phase=="autonomy" and not app.rules.body_busy() and not app.rules.gripped and app.rules.control_left<=0 and not blocks_hero()
func approach_contact(id:String,delta:float) -> bool:
 if not near(id,0.65) and present(id) and str(actor(id).room)==app.room_id:move(id,beside(app.room_id,app.hero_pos),delta)
 return near(id,0.65)

func on_enter(from:String,room:String) -> void:
 if not enabled or int(app.session.data.level)!=4:return
 if data.is_empty():start_attempt()
 if not from.is_empty():data.room_left[from]=float(data.clock)
 if from!=room:cancel_observation("room_left")
 if upper_events!=null:upper_events.on_enter(from,room)
 for id in config.rooms:
  if str(config.rooms[id])!=room:continue
  var state:Dictionary=data.groups[id]
  if state.drawn or int(state.checks)>=3:continue
  if int(state.checks)>0 and (not data.room_left.has(room) or float(data.clock)-float(data.room_left[room])<float(config.timing.return_check)):continue
  var chance:float=0.45+0.05*mini(app.rules.actual_attempt-1,4)
  if int(state.checks)>0:chance*=0.5
  state.checks+=1
  if app.rng.randf()<chance:state.drawn=true;state.pending=true

func spawn_pending() -> void:
 for id in config.rooms:
  var group:Dictionary=data.groups[id];var room:String=str(config.rooms[id])
  if not group.pending or room!=app.room_id or float(data.clock)-float(data.batches.get(room,-100.0))<float(config.timing.spawn_batch):continue
  var doors:Array=Map.doors(room)
  if doors.is_empty():continue
  var floor_layout=layout_for(room)
  var entry:Vector2=floor_layout.portal(str(doors[0])).at
  if not floor_layout.walkable(entry) or app.hero_pos.distance_to(entry)<0.5:continue
  var free:bool=true
  for other in data.actors:
   if present(str(other)) and str(actor(str(other)).room)==room and position(str(other)).distance_to(entry)<0.5:free=false
  if not free:continue
  var a:Dictionary=actor(id)
  if a.phase=="absent":a.phase="idle";a.pos=xy(entry);a.route=[]
  group.pending=false;data.batches[room]=float(data.clock)
  claim("spawn:"+id,"cortex_actor_entered",{"actor":id,"room":room})

func tick(delta:float) -> void:
 if not enabled or int(app.session.data.level)!=4 or app.session.data.get("cortex_exit_crossed",false):return
 if app.rules.hp<=0:release_all();return
 if not is_finite(delta) or delta<=0 or not app.dialogue_queue.is_empty():return
 if data.is_empty():start_attempt()
 data.clock+=delta;spawn_pending()
 advance_visible_reaction(delta)
 data.regrab_elapsed=0.0 if app.rules.body_busy() or app.rules.gripped else float(data.regrab_elapsed)+delta
 advance_stands(delta)
 advance_clamp(delta)
 if app.rules.hp<=0 or not app.dialogue_queue.is_empty():return
 advance_paper(delta)
 if not app.dialogue_queue.is_empty():return
 advance_playbacks(delta)
 advance_video(delta)
 if not app.dialogue_queue.is_empty():return
 advance_back(delta)
 if not app.dialogue_queue.is_empty():return
 advance_mimic(delta)
 if not app.dialogue_queue.is_empty():return
 if upper_events!=null:upper_events.tick(delta)
 if app.rules.hp<=0 or not app.dialogue_queue.is_empty():return
 advance_observation(delta)
 remember_physical_materials()

func advance_stands(delta:float) -> void:
 for id in config.rooms:
  if not present(id) or actor(id).get("stand_done",false):continue
  var room:String=str(actor(id).room);var at:Vector2=point(room,int(config.stand_furniture[id]))
  if move(id,beside(room,at),delta):
   actor(id).stand_done=true
   # Only a completed genuine arrival establishes the idle watch direction.
   # Existing/saved facing and explicitly staged test actors are untouched.
   face_target(id,layout_for("verify").portal("combat_exit").at if id=="face_press" else at)

func bind_evidence() -> void:
 # This is a representation of already-existing records, never a newly
 # invented past episode. Unknown authored name/signature glyphs stay null.
 var transfer:Dictionary={};var perpetrators:Array=[]
 for fact in app.rules.facts:
  var kind:String=str(fact.get("kind",""));var event_id:String=str(fact.get("event_id",""))
  if kind=="patient_transport_completed" and event_id.begins_with("hospital:"):
   transfer=fact.duplicate(true);transfer.subject="hospital_wheelchair_patient";perpetrators=["guide","porter"];break
  if kind=="asylum_bed_transfer_delivered" and str(fact.get("target",""))=="transport_patient" and event_id.begins_with("asylum:"):
   transfer=fact.duplicate(true);transfer.subject="asylum_transport_patient";perpetrators=["asylum_porter"];break
 data.video.source=transfer;data.video.mask_targets=perpetrators
 var factual:Dictionary=transfer.duplicate(true)
 if factual.is_empty():
  for fact in app.rules.facts:
   if str(fact.get("kind","")) in ["hospital_medicine_refused","asylum_medicine_refused","hospital_transfer_started","family_conflict"]:factual=fact.duplicate(true);break
 data.paper.source=factual
 data.paper.original={"source_event":factual.duplicate(true),"number":config.glyphs.shared_number,"name":null,"signature":null,"injury":null}
 data.paper.revised={"source_event_id":null,"number":config.glyphs.shared_number,"name":null,"signature":null,"injury":null,"actual_records":[]}
 # Only a verified event/document pair can populate a cross-version claim.
 # Unrelated collected paperwork is never relabelled the matching revision.
 if upper_events!=null:
  var pair:Dictionary=upper_events.source_material()
  if not pair.is_empty():
   data.paper.revised.source_event_id=pair.id
   for entry in app.rules.institutional_records:
    if str(entry.get("id",""))==str(pair.get("record_id","")):data.paper.revised.actual_records.append(entry.duplicate(true))
   for fact in app.rules.facts:
    if str(fact.get("event_id",""))==str(pair.id):data.paper.source=fact.duplicate(true);data.paper.original.source_event=fact.duplicate(true);break

func definitions() -> Array:
 var result:Array=config.targets.duplicate(true)
 if upper_events!=null and upper_events.has_method("observation_defs"):
  for raw in upper_events.observation_defs():
   var item:Dictionary=raw.duplicate(true)
   if not item.has("name"):item.name=str(item.get("label",item.id))
   if not item.has("furniture"):item.furniture=int(item.get("furniture_index",-1))
   if not item.has("source"):item.source="S3:P1164–1283"
   item.upper=true;result.append(item)
 return result
func specification(id:String) -> Dictionary:
 for target in definitions():
  if str(target.id)==id:return target
 return {}
func target_position(target:Dictionary) -> Vector2:
 var id:String=str(target.get("actor",""))
 if not id.is_empty():return position(id) if present(id) else Vector2.INF
 return point(str(target.room),int(target.get("furniture",-1)))
func available(target:Dictionary) -> bool:
 if not usable() or target.is_empty() or not target_position(target).is_finite():return false
 if target.get("upper",false):return upper_events!=null and upper_events.observation_available(str(target.id))
 match str(target.kind):
  "original":return data.paper.remaining!="fragments" or bool(data.paper.taken)
  "watch":return not data.video.source.is_empty()
  "replay":return not data.paper.source.is_empty()
  "decision_record":return bool(data.mimic.written)
 return true
func observation_revision(target:Dictionary) -> String:
 if target.get("upper",false) and upper_events!=null and upper_events.has_method("observation_revision"):return upper_events.observation_revision(str(target.id))
 match str(target.kind):
  "pain_record":return "hurt" if data.clamp.hurt else "unhurt"
  "body_map":return str(app.rules.hp)+":"+str(data.clamp.hurt)
  "original":return str(data.paper.remaining)
 return "1"
func approach_position(target:Dictionary) -> Vector2:
 var at:Vector2=target_position(target)
 if not at.is_finite():return at
 if not str(target.get("actor","")).is_empty():
  if app.hero_pos.distance_to(at)<=0.65:return app.hero_pos
  return beside(str(target.room),at)
 return at
func candidate(room:String,index:int=-1) -> Dictionary:
 if not usable() or room!=app.room_id:return {}
 var best:Dictionary={};var nearest:float=INF
 for target in definitions():
  if str(target.room)!=room or (index>=0 and int(target.get("furniture",-1))!=index) or not available(target):continue
  if str(data.completed_observations.get(str(target.id),""))==observation_revision(target):continue
  var at:Vector2=approach_position(target)
  if not at.is_finite() or not app.layout.walkable(at):continue
  if app.hero_pos.distance_to(at)>0.035 and app.layout.path(app.hero_pos,at).is_empty():continue
  var distance:float=app.hero_pos.distance_to(at)
  if distance<nearest:
   nearest=distance;best=target.duplicate(true);best.pos=at;best.furniture=int(target.get("furniture",-1))
 return best
func observation_body_free(controlled:bool) -> bool:
 var rules=app.rules
 return usable() and not rules.loading and not rules.transitioning and not rules.absent and not rules.body_busy() and not rules.gripped and not rules.search_active and data.body.is_empty() and str(data.holder).is_empty() and (rules.control_left>0 if controlled else rules.control_left<=0)
func in_contact(target:Dictionary) -> bool:
 if str(target.room)!=app.room_id:return false
 var at:Vector2=target_position(target);var offset:Vector2=at-app.hero_pos
 return at.is_finite() and offset.length()<=0.65 and app.layout.clear_segment(app.hero_pos,at) and (offset.length()<0.035 or app.hero_facing.dot(offset.normalized())>0.15)
func begin_observation(id:String,controlled:bool=false) -> bool:
 if not data.observation.is_empty() or not observation_body_free(controlled) or not app.dialogue_queue.is_empty():return false
 var target:Dictionary=specification(id)
 if not available(target) or not in_contact(target):return false
 if str(data.completed_observations.get(id,""))==observation_revision(target) and target.kind!="replay":return false
 var origin:String="controlled" if controlled else "autonomous"
 data.observation={"id":id,"kind":str(target.kind),"room":app.room_id,"phase":"prepare","elapsed":0.0,"origin":origin,"controlled":controlled,"contact":false,"revision":observation_revision(target)}
 if not app.rules.public_action.is_empty():app.rules.finish_public_action(str(app.rules.public_action.get("origin",origin)))
 app.rules.begin_public_action("observe",id,origin,app.room_id)
 app.hero_route=PackedVector2Array();app.target_index=-1;app.hero_state="give"
 return true
func cancel_observation(reason:String="interrupted") -> void:
 if data.is_empty() or data.observation.is_empty():return
 var action:Dictionary=data.observation
 if str(action.kind)=="original":data.paper.gripped=false
 if str(action.kind)=="watch":data.video.playing=false;data.video.overlay=false
 if str(action.kind)=="replay":
  var playback:Dictionary=data.get("playbacks",{}).get(str(action.id),{})
  if not playback.is_empty() and playback.phase=="playing":playback.phase="interrupted"
 if app.rules.public_action.get("target","")==action.id:app.rules.finish_public_action(str(action.origin))
 data.last_observation_cancel=reason;data.observation={}
 if app.action_phase in ["cortex_reading","cortex_observing"]:app.action_phase="autonomy";app.hero_state="idle"
func advance_observation(delta:float) -> void:
 if data.observation.is_empty():return
 var action:Dictionary=data.observation;var target:Dictionary=specification(str(action.id))
 if not usable() or app.rules.gripped or app.rules.loading or app.rules.transitioning or not data.body.is_empty() or not available(target) or not in_contact(target) or (action.controlled and app.rules.control_left<=0):cancel_observation("lost_contact_or_body");return
 # A temporary tinnitus pause does not itself drop a page or withdraw a
 # hand. Explicit cancelling reactions are handled at their actual callback.
 if app.rules.body_busy():return
 action.elapsed+=minf(delta,app.rules.control_left) if action.controlled else delta
 var elapsed:float=float(action.elapsed);var prepare:float=float(config.presentation.prepare)
 action.phase="prepare" if elapsed<prepare else "contact"
 app.hero_state="give"
 if not action.contact and elapsed>=prepare:
  action.contact=true
  if target.kind=="original":data.paper.gripped=not bool(data.paper.taken)
  if target.kind=="watch":data.video.playing=true
  if target.kind=="replay":start_playback(str(target.id),str(action.origin))
  claim("observation_contact:"+str(target.id),"cortex_observation_contact",{"target":str(target.id),"origin":str(action.origin)})
 if target.kind=="original" and elapsed>=prepare+float(config.presentation.read) and data.paper.remaining=="whole" and not data.paper.read:
  data.paper.read=true;data.paper.read_fields=data.paper.original.duplicate(true)
  observe("cortex_original_visible_fields","实际读到原页仍可见的事件材料；未提供的姓名、签字、编号字形保持未知。")
 var duration:float=float(config.presentation.original_read) if target.kind in ["original","watch"] else prepare+float(config.presentation.read)+float(config.presentation.finish)
 if elapsed<duration:return
 action.phase="finish"
 if target.kind=="back_face" and data.back.phase!="done":return
 if target.kind=="original" and data.paper.phase in ["approach","pinch","tear"]:return
 if target.kind=="replay" and data.get("playbacks",{}).get(str(target.id),{}).get("phase","")!="finished":return
 complete_observation(target)

func complete_observation(target:Dictionary) -> void:
 if data.observation.is_empty():return
 var action:Dictionary=data.observation.duplicate(true);var fields:Dictionary={"origin":str(action.origin),"room":app.room_id}
 var id:String=str(target.id);var rev:String=observation_revision(target)
 if not claim("observation:"+id+":"+rev,"cortex_observation_completed",{"target":id,"origin":str(action.origin)}):cancel_observation("already_read");return
 if target.get("upper",false):
  if upper_events!=null:upper_events.on_observation(id,fields)
 else:
  match str(target.kind):
   "back_face":
    fields.face_absent=true;fields.number=config.glyphs.shared_number;data.back.front_seen=true
    observe(id,"实际看清转头并转身后的正面仍没有脸；同编号不构成身份认定。");say("BACK_FACE")
    if data.back.back_seen and config.glyphs.shared_number!=null:say("BACK_NUMBER")
   "doorplate","wristband":
    fields.number=config.glyphs.shared_number;observe(id,"已实际查看旧物；具体编号尚无可核字形，未据此认定人物身份。")
   "original":
    fields.page_state=str(data.paper.remaining);fields.source=data.paper.source.duplicate(true);fields.read_fields=data.paper.read_fields.duplicate(true)
    if data.paper.phase=="idle" and data.paper.remaining=="whole":
     data.paper.read=true;data.paper.taken=true;app.rules.owners.cortex_original_page="hero";data.paper.read_fields=data.paper.original.duplicate(true)
    observe(id,"实际查看原始展示材料与仍可见的部分；未读姓名、签字、伤情不补全，未发生经历不当作回忆。")
   "revised":fields.record=data.paper.revised.duplicate(true);observe(id,"已读实际修订件；其中机构记载单独保存，不改变真实结果。")
   "memory_index":fields.source=data.paper.source.duplicate(true);observe(id,"实际核对病历架上的检索和版本位置；未提供字形保持未知。")
   "replay":
    var playback:Dictionary=data.playbacks[id]
    fields.source=playback.source.duplicate(true);fields.played_seconds=float(playback.elapsed);fields.voice_available=false
    observe(id,"实际播完已有事件材料的画面占位重现；当前无正式录音，不重复伤害、治疗、奖励或觉醒。")
   "watch":fields.source=data.video.source.duplicate(true);fields.mask_count=int(data.video.mask_count);observe(id,"实际观看所选真实转运片段；遮挡和面孔叠入不改变原患者身份。")
   "visual_archive":fields.source=data.video.source.duplicate(true);observe(id,"实际查阅影像材料标签；记录写死亡与已确认死亡分别核对。")
   "decision_board":
    fields.columns=["接受","拒绝"];fields.filed_under="已同意";fields.actual_decisions=actual_decisions()
    observe(id,"实际看清接受与拒绝两栏均归入已同意；只记录真实发生的决定，读板不是认同。");say("CONSENT")
   "decision_record":fields.action=data.mimic.source.duplicate(true);fields.classification="自主行为";observe(id,"实际读到复述者把已见动作归作自主行为；真实神经干预/掌控来源保留。");say("MIMIC_READ")
   "pain_record":
    fields.pain_light=bool(data.clamp.pain_light);fields.record="无异常";fields.actual_clamp_hurt=bool(data.clamp.hurt)
    observe(id,"实际看清检查记录仍写无异常；仅实际夹伤时疼痛灯亮，不把记录当作无伤证明。")
    if data.clamp.hurt:say("CLAMP_RECORD")
   "body_map":fields.actual_injuries=actual_injuries();observe(id,"自身映射仅展示已有真实伤情；模型束缚痕迹不是角色亲历。")
 data.completed_observations[id]=rev;data.observed_fields[id]=fields
 remember_physical_materials()
 if action.controlled:app.rules.controlled_execution("observe",id)
 cancel_observation("completed")

func actual_decisions() -> Array:
 var result:Array=[]
 for fact in app.rules.facts:
  if str(fact.get("kind","")) in ["hospital_medicine_refused","asylum_medicine_refused","asylum_medicine_swallowed","hospital_medicine_swallowed"]:result.append(fact.duplicate(true))
 return result
func actual_injuries() -> Array:
 return Appearance.incidents(app.rules.facts)

func start_playback(id:String,origin:String) -> void:
 if data.paper.source.is_empty():return
 if not data.has("playbacks"):data.playbacks={}
 var playback:Dictionary=data.playbacks.get(id,{})
 # The saved source is a copy of an existing actual receipt, never a call
 # into the original event's settlement or a fabricated recorded voice.
 if playback.is_empty() or playback.get("phase","")=="finished":
  playback={"phase":"playing","elapsed":0.0,"duration":3.5,"source":data.paper.source.duplicate(true),"origin":origin,"voice_available":false}
  data.playbacks[id]=playback
 else:playback.phase="playing";playback.origin=origin
func advance_playbacks(delta:float) -> void:
 for id in data.get("playbacks",{}):
  var playback:Dictionary=data.playbacks[id]
  if playback.phase!="playing" or data.observation.get("id","")!=id or not data.observation.get("contact",false):continue
  if app.rules.body_busy() or not in_contact(specification(str(id))):continue
  playback.elapsed=minf(float(playback.duration),float(playback.elapsed)+delta)
  if float(playback.elapsed)>=float(playback.duration):playback.phase="finished"

func advance_back(delta:float) -> void:
 if not present("backward") or not actor("backward").stand_done:return
 var event:Dictionary=data.back
 if event.phase=="idle":
  if not near("backward",2.0):return
  event.back_seen=hero_sees("backward");event.phase="head";event.elapsed=0.0
 if event.phase=="done":return
 event.elapsed+=delta
 if event.phase=="head" and float(event.elapsed)>=float(config.presentation.turn_head):event.phase="body";event.elapsed=0.0
 elif event.phase=="body" and float(event.elapsed)>=float(config.presentation.turn_body):
  event.phase="done";actor("backward").facing=xy((app.hero_pos-position("backward")).normalized())
  claim("back_turn","cortex_back_turned",{"actor":"backward","face_absent":true})

func advance_paper(delta:float) -> void:
 var event:Dictionary=data.paper
 if event.phase in ["done","interrupted"]:return
 if not present("stitched"):
  if event.attempted:event.phase="interrupted"
  return
 var at:Vector2=point("memory",1)
 if event.phase=="idle":
  if not event.gripped or event.attempted or event.taken or app.rules.owners.get("cortex_original_page","")!="memory_table":return
  event.attempted=true;event.phase="approach";event.elapsed=0.0
 if event.phase=="approach":
  if not move("stitched",beside("memory",at),delta):return
  face_target("stitched",at)
  event.phase="pinch";event.elapsed=0.0;return
 if event.phase=="pinch":
  event.elapsed+=delta
  if float(event.elapsed)<float(config.presentation.prepare):return
  if event.taken:event.phase="done";return
  event.phase="tear";event.elapsed=0.0
  claim("paper_pinch","cortex_paper_pinched",{"source_event":event.source.get("event_id",null)})
  if event.gripped and hero_sees("stitched"):say("TEAR_START")
  return
 if event.phase=="collect":
  if not actor_contact("stitched",at,"memory"):event.phase="interrupted";return
  event.elapsed+=delta
  if float(event.elapsed)<float(config.presentation.read):return
  if app.rules.owners.get("cortex_page_scraps","")=="memory_table" and claim("paper_collected","cortex_paper_scraps_collected",{"item":"cortex_page_scraps","from":"memory_table","to":"stitched"}):
   app.rules.owners.cortex_page_scraps="stitched";event.collected=true
  event.phase="retreat";event.elapsed=0.0
  event.retreat_to=xy(paper_retreat_position(at));remember_physical_materials();return
 if event.phase=="retreat":
  var target:Array=event.retreat_to
  if move("stitched",Vector2(float(target[0]),float(target[1])),delta):
   face_target("stitched",at);event.phase="done"
   claim("paper_retreat","cortex_paper_retreat_completed",{"actor":"stitched","position":xy(position("stitched"))})
  return
 if event.phase!="tear":return
 if not actor_contact("stitched",at,"memory"):event.phase="interrupted";return
 event.elapsed+=delta;event.progress=clampf(float(event.elapsed)/float(config.timing.tear),0,1)
 remember_physical_materials()
 if float(event.progress)<1:return
 var kept:bool=bool(event.gripped) and app.room_id=="memory" and app.hero_pos.distance_to(at)<=0.65 and app.layout.clear_segment(app.hero_pos,at)
 event.remaining="corner" if kept else "fragments";event.taken=kept;event.phase="collect";event.elapsed=0.0;event.collected=false
 # The acquired corner and the remainder are distinct physical pieces.
 # No separate corner exists when the entire torn page is left on the table.
 app.rules.owners.cortex_original_page="torn";app.rules.owners.cortex_page_fragment="hero" if kept else "none";app.rules.owners.cortex_page_scraps="memory_table"
 remember_physical_materials()
 claim("paper_torn","cortex_paper_torn",{"remaining":event.remaining,"holder":app.rules.owners.cortex_page_fragment,"read_fields":event.read_fields.duplicate(true)})
 if kept:say("TEAR_KEEP")
 elif app.room_id=="memory" and hero_sees("stitched") and not event.read:say("TEAR_LOST")

func paper_retreat_position(at:Vector2) -> Vector2:
 var floor_layout=layout_for("memory")
 for offset in [Vector2(-0.5,-0.65),Vector2(-0.5,0.65),Vector2(0,-0.8),Vector2(-0.9,0)]:
  var target:Vector2=at+offset
  if target.distance_to(position("stitched"))<0.4 or not floor_layout.walkable(target):continue
  if not floor_layout.path(position("stitched"),target).is_empty():return target
 # A blocked retreat waits at the real location, rather than teleporting.
 return at+Vector2(-0.5,-0.65)

func advance_video(delta:float) -> void:
 var event:Dictionary=data.video
 if event.playing and not event.source.is_empty():
  event.playback+=delta
  event.overlay=float(event.playback)>=float(config.presentation.overlay_at) and float(event.playback)<float(config.presentation.overlay_at)+float(config.presentation.overlay_for)
  if event.overlay and not event.overlay_seen and data.observation.get("kind","")=="watch" and in_contact(specification(str(data.observation.id))):
   event.overlay_seen=true;observe("cortex_overlay_seen","实际播放时短暂看见自己的面孔叠入画面；未据此认定亲历或改变患者身份。");say("OVERLAY");return
 else:event.overlay=false
 if not present("blindfold") or event.source.is_empty():return
 if event.phase=="idle":
  if not event.playing:return
  event.phase="approach";event.elapsed=0.0
 if event.phase=="approach":
  if move("blindfold",beside("visual",point("visual",1)),delta):face_target("blindfold",point("visual",1));event.phase="operate";event.elapsed=0.0
  return
 if event.phase!="operate":return
 var at:Vector2=point("visual",1)
 if not actor_contact("blindfold",at,"visual"):event.phase="interrupted";return
 event.elapsed+=delta
 if float(event.elapsed)<float(config.timing.mask):return
 var target:String=str(event.mask_targets[int(event.mask_count)])
 event.mask_count+=1;event.phase="done" if int(event.mask_count)>=event.mask_targets.size() else "operate";event.elapsed=0.0
 claim("video_mask:%d"%int(event.mask_count),"cortex_video_masked",{"source_event":event.source.get("event_id",null),"mask":int(event.mask_count),"target":target,"patient_movement_preserved":true})
 remember_physical_materials()
 if event.playing and data.observation.get("kind","")=="watch" and hero_sees("blindfold",2.0):
  observe("cortex_mask_operation_seen","实际同时看见控制台操作和画面施害者面部遮挡，患者动作仍保留。");say("MASK")

func capture_mimic(source:Dictionary) -> void:
 if data.mimic.attempted or not actor_sees("repeater",app.hero_pos,app.room_id,2.0) or not actor("repeater").stand_done:return
 data.mimic.source=source.duplicate(true);data.mimic.attempted=true;data.mimic.phase="imitate";data.mimic.elapsed=0.0;data.mimic.witnessed=hero_sees("repeater")
 claim("mimic_seen","cortex_intervention_witnessed",{"source":source.duplicate(true)})
func advance_visible_reaction(delta:float) -> void:
 var reaction:Dictionary=data.get("visible_reaction",{})
 if reaction.is_empty():return
 if str(reaction.room)!=app.room_id or app.rules.hp<=0: data.visible_reaction={};return
 reaction.elapsed+=delta
 var ready:bool=true
 if reaction.skill=="KNEE":ready=not app.rules.action.is_empty() and app.rules.action.get("phase","")=="attack"
 elif reaction.skill=="STARTLE":
  var initial:Array=reaction.started_at
  ready=app.hero_pos.distance_to(Vector2(float(initial[0]),float(initial[1])))>0.001
 if ready and float(reaction.elapsed)<=0.65:
  capture_mimic({"kind":"reaction","skill":str(reaction.skill),"origin":"neural_intervention","event_id":str(reaction.event_id),"visible_pose":str(reaction.pose),"source_room":str(reaction.room)})
 if float(reaction.elapsed)>=0.65:data.visible_reaction={}
func visible_reaction_pose() -> Dictionary:
 if not usable() or data.get("visible_reaction",{}).is_empty():return {}
 return data.visible_reaction.duplicate(true)
func imitated_pose(id:String) -> Dictionary:
 if id!="repeater" or not usable() or data.mimic.phase!="imitate":return {}
 return {"pose":str(data.mimic.source.get("visible_pose","walk" if data.mimic.source.get("kind","")=="movement" else "read")),"elapsed":float(data.mimic.elapsed),"source":data.mimic.source.duplicate(true)}
func advance_mimic(delta:float) -> void:
 var event:Dictionary=data.mimic
 if not present("repeater"):return
 # Entering CONTROL has no visible action. Capture only after actual motion
 # or a committed interaction, preserving the source of the begun action.
 if not event.attempted and app.rules.control_left>0 and app.room_id=="decision":
  var prior:Array=event.get("hero_prior",xy(app.hero_pos));var prior_pos:Vector2=Vector2(float(prior[0]),float(prior[1]))
  if app.hero_pos.distance_to(prior_pos)>0.001:
   capture_mimic({"kind":"movement","origin":"controlled","control_event":app.rules.control_event,"from":prior,"to":xy(app.hero_pos)})
  elif not data.observation.is_empty() and data.observation.get("contact",false):capture_mimic({"kind":"observe","origin":str(data.observation.origin),"target":str(data.observation.id),"control_event":app.rules.control_event})
  event.hero_prior=xy(app.hero_pos)
 if event.phase=="imitate":
  event.elapsed+=delta
  if float(event.elapsed)<float(config.presentation.imitate):return
  claim("mimic_action","cortex_action_imitated",{"source":event.source.duplicate(true),"effects_repeated":false})
  event.phase="approach_board";event.elapsed=0.0
  if event.witnessed and app.rules.awareness_feedback.is_empty():observe("cortex_mimic_seen","实际看见复述者模仿一次可见动作；没有复制神经效果。");say("MIMIC")
  return
 if event.phase=="approach_board":
  if move("repeater",beside("decision",point("decision",2)),delta):face_target("repeater",point("decision",2));event.phase="write";event.elapsed=0.0
  return
 if event.phase!="write":return
 var at:Vector2=point("decision",2)
 if not actor_contact("repeater",at,"decision"):event.phase="interrupted";return
 event.elapsed+=delta
 if float(event.elapsed)<float(config.presentation.write):return
 event.phase="done";event.written=true
 claim("mimic_written","cortex_action_recorded",{"source":event.source.duplicate(true),"institutional_classification":"自主行为"})
 record("cortex_mimic:%d"%app.rules.actual_attempt,"自主行为。机构归类；实际动作来源："+JSON.stringify(event.source))
 if near("repeater",2.0):say("MIMIC_WRITE")

func touch_anchor() -> Vector2:
 var at:Vector2=point("body",5);var table:Vector2=layout_for("body").furniture[5].rect.get_center()
 return at+(table-at).normalized()*0.3
func touch_alignment() -> bool:
 if app.room_id!="body":return false
 var stand:Vector2=point("body",5);var offset:Vector2=touch_anchor()-app.hero_pos
 return app.hero_pos.distance_to(stand)<=0.65 and app.layout.clear_segment(app.hero_pos,stand) and (offset.length()<0.035 or app.hero_facing.dot(offset.normalized())>0.35)
func searching_touch() -> bool:
 return app.rules.search_active and app.target_index==5 and app.rules.search_elapsed>=float(config.presentation.prepare) and touch_alignment()
func clamp_hand_state() -> Dictionary:
 var event:Dictionary=data.clamp
 var extension:float=0.0
 if event.phase=="release" and data.holder=="misaligned":extension=1.0
 elif event.phase in ["approach","windup"] and not event.hand_out:
  extension=clampf(float(event.retract_left)/float(config.presentation.retract_hand),0,1) if float(event.retract_left)>0 else 1.0
 elif event.phase=="idle" and searching_touch():extension=1.0
 var stand:Vector2=point("body",5)
 var reachable:bool=app.room_id=="body" and app.hero_pos.distance_to(stand)<=0.65 and app.layout.clear_segment(app.hero_pos,stand)
 return {"contact":reachable and extension>0,"extension":extension if reachable else 0.0,"anchor":xy(touch_anchor())}
func retract_clamp_hand(delta:float) -> void:
 var event:Dictionary=data.clamp
 if event.hand_out:return
 # A turn away initiates the same physical 0.2 s withdrawal even when
 # CONTROL/KNEE preserved the hand after cancelling the search. A late turn
 # does not grant immediate immunity while the hand is still in the jaws.
 if float(event.retract_left)<=0 and (not touch_alignment() or (not searching_touch() and not event.get("keep_hand_until_close",false))):event.retract_left=float(config.presentation.retract_hand)
 if float(event.retract_left)>0:
  event.retract_left=maxf(0,float(event.retract_left)-delta)
  if float(event.retract_left)<=0:event.hand_out=true
func advance_clamp(delta:float) -> void:
 var event:Dictionary=data.clamp
 if event.phase=="release":
  event.elapsed+=delta
  if float(event.elapsed)>=float(config.timing.clamp_release):release_clamp()
  return
 if event.phase in ["done","interrupted"]:return
 if not present("misaligned"):
  if event.attempted:event.phase="interrupted"
  return
 if event.phase=="idle":
  if not searching_touch():return
  event.phase="approach";event.attempted=true;event.elapsed=0.0;event.source_search=app.rules._search_id
  event.origin=str(app.rules.public_action.get("origin","autonomous"))
  claim("clamp_attempt","cortex_clamp_attempt",{"search":event.source_search,"origin":event.origin})
 if event.phase=="approach":
  retract_clamp_hand(delta)
  if not move("misaligned",beside("body",point("body",5)),delta):return
  face_target("misaligned",point("body",5))
  event.phase="windup";event.elapsed=0.0
  claim("clamp_handle","cortex_clamp_handle_started",{"room":"body","actor":"misaligned"})
  if hero_sees("misaligned"):say("CLAMP_START")
  return
 if event.phase!="windup":return
 retract_clamp_hand(delta)
 event.elapsed+=delta
 if float(event.elapsed)<float(config.timing.clamp_windup):return
 var at:Vector2=point("body",5)
 var contact:bool=bool(clamp_hand_state().contact) and actor_contact("misaligned",at,"body")
 if contact and str(data.holder).is_empty() and float(data.regrab_elapsed)>=0.8:
  data.holder="misaligned";app.rules.gripped=true;set_body("cortex_clamp","misaligned")
  event.hurt=true;event.pain_light=true
  damage("clamp_damage",10,0)
  observe("cortex_clamp_injury","触觉夹具实际闭合夹伤手部；生命扣除10，疼痛灯亮。")
  record("cortex_clamp:%d"%app.rules.actual_attempt,"无异常。此为检查记录；不覆盖实际手部夹伤。")
  claim("clamp_wound","cortex_injury",{"part":"hand","source":"clamp","hp_damage":0})
 else:claim("clamp_missed","cortex_clamp_missed",{"hand_retracted":bool(event.hand_out)})
 event.phase="release";event.elapsed=0.0
func release_clamp() -> void:
 var event:Dictionary=data.clamp
 if data.holder=="misaligned":data.holder="";app.rules.gripped=false;data.regrab_elapsed=0.0
 if data.body.get("kind","")=="cortex_clamp":clear_body()
 event.phase="done"
 if app.room_id=="body" and near("misaligned",2.0):say("CLAMP_HURT" if event.hurt else "CLAMP_MISS")

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false) or data.is_empty():return
 var id:String=str(result.get("id",""))
 if id!="CONTROL":
  var pose:String={"SKIN":"scratch","GUT":"abdomen","PORES":"look_skin","TEMP":"shiver","TINNITUS":"head_tilt","DRYMOUTH":"lips","KNEE":"kick","WITHDRAW":"withdraw","STARTLE":"recoil","FEAR":"fear","JOY":"smile"}.get(id,"")
  if not pose.is_empty():data.visible_reaction={"skill":id,"event_id":str(result.get("event_id","")),"pose":pose,"elapsed":0.0,"room":app.room_id,"started_at":xy(app.hero_pos)}
 else:data.mimic.hero_prior=xy(app.hero_pos)
 if id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:cancel_observation("skill:"+id)
 if data.clamp.phase in ["approach","windup"] and id in ["KNEE","CONTROL"]:data.clamp.keep_hand_until_close=true
 if data.clamp.phase=="windup" and id in ["SKIN","GUT","WITHDRAW","STARTLE","FEAR"]:data.clamp.retract_left=float(config.presentation.retract_hand)
 if upper_events!=null:upper_events.on_skill(result)
func kick_contact() -> void:
 if not usable():return
 if upper_events!=null and upper_events.has_method("kick_contact"):upper_events.kick_contact()
 for id in ["stitched","blindfold","misaligned","repeater"]:
  if not near(id,1.0):continue
  var offset:Vector2=position(id)-app.hero_pos
  if not app.rules.kick_contact("cortex_"+id,offset.length(),offset.length()<0.035 or offset.normalized().dot(app.hero_facing)>0.35,app.layout.clear_segment(app.hero_pos,position(id))):continue
  claim("kick:"+id,"cortex_actor_kicked",{"actor":id})
  if id=="misaligned" and data.clamp.phase in ["approach","windup"]:data.clamp.phase="release";data.clamp.elapsed=0.0;data.clamp.hand_out=true
  elif id=="stitched" and data.paper.phase in ["approach","pinch","tear","collect","retreat"]:
   if data.paper.phase in ["approach","pinch","tear"]:data.paper.remaining="partly_torn" if float(data.paper.progress)>0 else "whole"
   data.paper.phase="interrupted"
   remember_physical_materials()
  elif id=="blindfold" and data.video.phase in ["approach","operate"]:data.video.phase="interrupted"
  elif id=="repeater" and data.mimic.phase in ["imitate","approach_board","write"]:data.mimic.phase="interrupted"
func on_search_complete(index:int,found_key:bool) -> void:
 if upper_events!=null:upper_events.on_search_complete(index,found_key)
func release_all() -> void:
 if data.is_empty():return
 remember_physical_materials()
 if upper_events!=null and upper_events.has_method("release_all"):upper_events.release_all("death")
 cancel_observation("death");data.body={};data.holder="";app.rules.gripped=false
 if data.clamp.phase=="release":data.clamp.phase="done"
func actors() -> Array:
 var result:Array=[]
 if not usable():return result
 for id in data.actors:
  if present(id) and str(actor(id).room)==app.room_id:result.append({"type":"actor","data":"cortex_"+str(id),"depth":app.layout.project(position(id)).y})
 return result
func observation_markers() -> Array:
 var result:Array=[]
 if not usable():return result
 for target in definitions():
  if target.room!=app.room_id or not available(target):continue
  var at:Vector2=target_position(target)
  var item:Dictionary=target.duplicate(true)
  item.pos=xy(at);item.label=str(target.name);item.read=str(data.completed_observations.get(str(target.id),""))==observation_revision(target)
  result.append(item)
 return result
func presentation_markers() -> Array:
 if not usable():return []
 var result:Array=[]
 if app.room_id=="memory":
  result.append({"id":"cortex_paper","kind":"paper","room":"memory","pos":xy(point("memory",1)),"phase":str(data.paper.phase),"progress":float(data.paper.progress),"state":str(data.paper.remaining),"held":bool(data.paper.gripped),"owner":str(app.rules.owners.get("cortex_original_page","memory_table")),"fragment_owner":str(app.rules.owners.get("cortex_page_fragment","none")),"scraps_owner":str(app.rules.owners.get("cortex_page_scraps","none")),"collector_pos":xy(position("stitched")),"collect_progress":clampf(float(data.paper.elapsed)/float(config.presentation.read),0,1) if data.paper.phase=="collect" else 1.0})
  for id in data.get("playbacks",{}):
   var playback:Dictionary=data.playbacks[id];var target:Dictionary=specification(str(id))
   result.append({"id":id,"kind":"replay","room":"memory","pos":xy(target_position(target)),"phase":str(playback.phase),"progress":clampf(float(playback.elapsed)/float(playback.duration),0,1),"playing":playback.phase=="playing","source":playback.source.duplicate(true),"source_event":str(playback.source.get("event_id","")),"medium":"recorder" if id=="cortex_audio_replay" else "screen","voice_available":false})
 if app.room_id=="visual":
  var faces:Array=[]
  for i in range(data.video.mask_targets.size()):faces.append({"actor":str(data.video.mask_targets[i]),"masked":i<int(data.video.mask_count),"role":"perpetrator"})
  if not data.video.source.is_empty():faces.append({"actor":str(data.video.source.get("subject","")),"masked":false,"role":"patient"})
  result.append({"id":"cortex_video","kind":"video","room":"visual","pos":xy(point("visual",3)),"phase":str(data.video.phase),"progress":fmod(float(data.video.playback),3.5)/3.5,"playing":bool(data.video.playing),"mask_count":int(data.video.mask_count),"faces":faces,"overlay":bool(data.video.overlay),"has_source":not data.video.source.is_empty(),"source":data.video.source.duplicate(true),"source_event":str(data.video.source.get("event_id",""))})
 if app.room_id=="body":
  result.append({"id":"cortex_clamp","kind":"clamp","room":"body","pos":xy(touch_anchor()),"phase":str(data.clamp.phase),"progress":clampf(float(data.clamp.elapsed)/float(config.timing.clamp_windup),0,1),"hand_out":bool(data.clamp.hand_out),"hand":clamp_hand_state(),"hurt":bool(data.clamp.hurt),"pain_light":bool(data.clamp.pain_light)})
 if app.room_id=="decision":
  result.append({"id":"cortex_mimic_board","kind":"record","room":"decision","pos":xy(point("decision",2)),"phase":str(data.mimic.phase),"progress":clampf(float(data.mimic.elapsed)/float(config.presentation.write),0,1),"written":bool(data.mimic.written),"source":data.mimic.source.duplicate(true)})
 return result
func action_label(id:String) -> String:
 var event:Dictionary={}
 match id:
  "backward":event=data.back
  "stitched":event=data.paper
  "blindfold":event=data.video
  "repeater":event=data.mimic
  "misaligned":event=data.clamp
  _:
   if upper_events!=null and upper_events.has_method("action_label"):return upper_events.action_label(id)
 if event.is_empty():return "待机"
 return {"idle":"待机","head":"转头","body":"转身","approach":"接近","pinch":"捏住纸边","tear":"撕拉","collect":"收拢碎纸","retreat":"退回桌侧","operate":"操作遮挡","imitate":"模仿动作","approach_board":"走向记录板","write":"落笔","windup":"扳动手柄","release":"复位释放","done":"完成","interrupted":"已打断"}.get(str(event.phase),str(event.phase))
