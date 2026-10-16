extends RefCounted
## S3:P436/P656/T20: receive only an actually packed, source-bound container.
## Arrival is an explicit scene-transition hook, not a wheelchair_gone inference.
## The existing observation module owns the protagonist's reading action clock.
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

const DELIVERY_OWNER="asylum_intake_delivery"
const DESK_OWNER="asylum_registration_desk"
const NUMBER_ID="asylum_relic_bag_number"
const CONTENTS_ID="asylum_relic_bag_photo"

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_intake.json"))

func state() -> Dictionary:
 if owner==null or owner.data.is_empty():return {}
 if not owner.data.has("intake_state"):
  owner.data.intake_state={"phase":"waiting_source","elapsed":0.0,"phase_progress":0.0,"delivery":{},"room":"lobby","pos":[],"read":{},"last_wait":""}
 return owner.data.intake_state

func usable() -> bool:
 return owner!=null and owner.enabled and not owner.data.is_empty() and owner.app.session.data.level==3 and owner.app.rules.hp>0

func xy(at:Vector2) -> Array:return [at.x,at.y]
func point(at:Array) -> Vector2:return Vector2(float(at[0]),float(at[1])) if at.size()==2 else Vector2.INF
func receiver() -> String:return str(config.receiver)
func source_carry() -> Dictionary:return owner.data.get("carry",{})

func bound_source_trip(carry:Dictionary) -> bool:
 # A current live hospital job alone is not provenance. This chapter must
 # already carry that same actually started trip across its real door hook.
 var manifest:Dictionary=carry.get("relic_delivery",{})
 if int(manifest.get("version",0))==1 and not manifest.get("items",[]).is_empty() and not manifest.get("packed_receipts",{}).is_empty():return true
 var transport:Dictionary=carry.get("transport",{})
 if str(transport.get("kind",""))=="patient" and str(transport.get("phase","")) in ["paperwork","push","frame","fingers","leave","photo_prepare","photo_contact","photo_finish"]:
  for id in ["porter","wheelchair"]:
   if str(carry.get("actors",{}).get(id,{}).get("phase","absent")) in ["absent","gone"]:return false
  return true
 var packing:Dictionary=carry.get("relic_packing",{})
 return str(packing.get("phase","")) in ["shoe_route","shoe_prepare","shoe_contact","shoe_finish","carry_exit"] and not carry.get("transport_relics",{}).is_empty() and "patient_transport_completed" in carry.get("receipts",{}).values()

func carry_source_attempt(carry:Dictionary,hospital) -> int:
 for value in [carry.get("relic_context",{}).get("source_attempt",0),carry.get("relic_delivery",{}).get("source_attempt",0),carry.get("transport",{}).get("source_attempt",0),carry.get("hospital_attempt",0)]:
  var attempt:int=hospital.positive_source_attempt(value)
  if attempt>0:return attempt
 for key in carry.get("receipts",{}):
  if str(carry.receipts[key]) not in ["patient_transport_order","hospital_relics_fell","hospital_relic_packed","patient_transport_completed"]:continue
  var parts:PackedStringArray=str(key).split(":")
  if parts.size()>=3 and parts[0]=="hospital" and parts[1].is_valid_int() and parts[1].to_int()>0:return parts[1].to_int()
 return hospital.positive_source_attempt(owner.app.session.data.get("attempts",{}).get("2",0))

func refresh_source_trip() -> bool:
 var hospital=owner.app.get("hospital")
 var carry:Dictionary=source_carry()
 if hospital==null or not hospital.enabled or not bound_source_trip(carry):return false
 var source:int=carry_source_attempt(carry,hospital)
 if source<=0 or hospital.data.is_empty() or hospital.known_source_attempt()!=source:return false
 # Only the existing real source event is refreshed; no old medicine, rolls,
 # actor spawn or incoming original is synthesized by this read-only bridge.
 for key in ["hospital_attempt","relic_context","transport_relics","relic_delivery","relic_packing","transport","wheelchair_gone","wheelchair_order","receipts"]:
  if hospital.data.has(key):carry[key]=hospital.data[key].duplicate(true) if hospital.data[key] is Dictionary or hospital.data[key] is Array else hospital.data[key]
 return true

func validated_manifest() -> Dictionary:
 if not usable():return {}
 var carry:Dictionary=source_carry()
 var manifest:Dictionary=carry.get("relic_delivery",{})
 if int(manifest.get("version",0))!=1 or not manifest.get("ready",false) or not manifest.get("bag_departed",false):return {}
 # Packing contact is not arrival: the same carrier must actually finish its
 # outgoing path before the container can cross the chapter transition.
 if str(manifest.get("exit_room",""))!=str(config.room) or not point(manifest.get("exit_pos",[])).is_finite():return {}
 var attempt:int=int(manifest.get("source_attempt",0))
 var transport_key:String=str(manifest.get("transport_receipt",""))
 var receipts:Dictionary=carry.get("receipts",{})
 if attempt<=0 or transport_key!="hospital:%d:patient_transport"%attempt or receipts.get(transport_key,"")!=str(config.source_contract.transport_receipt_kind):return {}
 var bag:String=str(manifest.get("bag_id",""))
 if bag.is_empty() or bag in config.source_items:return {}
 if owner.app.rules.owners.get(bag,"")!=str(config.source_contract.incoming_bag_owner):return {}
 var source_owners:Dictionary=manifest.get("source_owners",{})
 var packed:Dictionary=manifest.get("packed_receipts",{})
 var items:Array=[]
 for id_value in manifest.get("items",[]):
  var id:String=str(id_value)
  if not config.source_items.has(id) or id in items:continue
  var pack_key:String=str(packed.get(id,""))
  if not pack_key.begins_with("hospital:%d:"%attempt) or receipts.get(pack_key,"")!=str(config.source_contract.packed_receipt_kind):continue
  if source_owners.get(id,"")!=str(config.source_items[id]):continue
  # A saved entry is not permission to recover a currently held/removed original.
  if owner.app.rules.owners.get(id,"")!=bag:continue
  items.append(id)
 if items.is_empty():return {}
 return {"version":1,"source_attempt":attempt,"transport_receipt":transport_key,"bag_id":bag,"items":items,"packed_receipts":packed.duplicate(true),"source_owners":source_owners.duplicate(true),"bag_departed":true,"exit_room":str(manifest.exit_room),"exit_pos":manifest.exit_pos.duplicate(),"bag_number":null}

func arrive_from_hospital() -> bool:
 if not usable() or str(state().phase)!="waiting_source":return false
 var manifest:Dictionary=validated_manifest()
 if manifest.is_empty():return false
 var at:Vector2=owner.app.door_point_for(str(config.room),str(config.incoming_from))
 if not at.is_finite() or not owner.layout_for(str(config.room)).walkable(at):return false
 if not owner.claim("relic_arrival:"+str(manifest.bag_id),"asylum_relic_delivery_arrived",{"bag":str(manifest.bag_id),"source_attempt":int(manifest.source_attempt),"source":"S3:P436/P656","items":manifest.items.duplicate()}):return false
 var value:Dictionary=state()
 value.delivery=manifest;value.room=str(config.room);value.pos=xy(at)
 owner.app.rules.owners[str(manifest.bag_id)]=DELIVERY_OWNER
 stage("approach")
 return true

func stage(phase:String) -> void:
 state().phase=phase;state().elapsed=0.0;state().phase_progress=0.0

func bag_id() -> String:return str(state().get("delivery",{}).get("bag_id",""))
func bag_holder() -> String:return str(owner.app.rules.owners.get(bag_id(),"")) if not bag_id().is_empty() else ""

func current_items() -> Array:
 var result:Array=[]
 for id in state().get("delivery",{}).get("items",[]):
  if owner.app.rules.owners.get(str(id),"")==bag_id():result.append(str(id))
 return result

func bag_position() -> Vector2:
 if not usable() or bag_id().is_empty():return Vector2.INF
 var holder:String=bag_holder()
 if holder==receiver():return owner.position(receiver()) if owner.present(receiver()) else Vector2.INF
 if holder in [DELIVERY_OWNER,DESK_OWNER]:return point(state().get("pos",[]))
 return Vector2.INF

func desk_position() -> Vector2:
 var layout=owner.layout_for(str(config.room));var index:int=int(config.desk_index)
 return layout.furniture[index].at if index>=0 and index<layout.furniture.size() else Vector2.INF

func receiver_free() -> bool:
 if not owner.present(receiver()) or str(owner.actor(receiver()).room)!=str(config.room):return false
 if owner.data.get("staff_targets",{}).has(receiver()):return false
 return owner.data.get("body",{}).get("actor","")!=receiver()

func actor_reserved(id:String) -> bool:
 return usable() and id==receiver() and str(state().phase) in ["approach","receive","carry","place"]

func receiver_contact(at:Vector2) -> bool:
 return at.is_finite() and owner.position(receiver()).distance_to(at)<=float(config.contact_distance) and owner.layout_for(str(config.room)).clear_segment(owner.position(receiver()),at)

func advance_clock(delta:float) -> String:
 var value:Dictionary=state();value.elapsed=float(value.elapsed)+delta
 var t:float=float(value.elapsed);var prepare:float=float(config.timing.prepare);var contact:float=float(config.timing.contact);var finish:float=float(config.timing.finish)
 if t<prepare:value.phase_progress=t/prepare;return "prepare"
 if t<prepare+contact:value.phase_progress=(t-prepare)/contact;return "contact"
 if t<prepare+contact+finish:value.phase_progress=(t-prepare-contact)/finish;return "finish"
 value.phase_progress=1.0;return "done"

func tick(delta:float) -> void:
 if not usable() or not is_finite(delta) or delta<=0 or not owner.app.dialogue_queue.is_empty():return
 var value:Dictionary=state()
 if str(value.phase)=="waiting_source":
  if not refresh_source_trip() or not arrive_from_hospital():return
 if str(value.phase) in ["stored","unavailable"]:return
 if bag_id().is_empty() or current_items().is_empty():value.last_wait="originals_removed";stage("unavailable");return
 var holder:String=bag_holder()
 if holder not in [DELIVERY_OWNER,receiver(),DESK_OWNER]:value.last_wait="bag_moved_by_other";stage("unavailable");return
 if not receiver_free():value.last_wait="receiver_absent_or_busy";return
 value.last_wait=""
 # Keep a diagnostic last real location even while the unique carrier owns
 # the bag. The owner remains the nurse until actual desk placement.
 if holder==receiver():value.pos=xy(owner.position(receiver()));value.room=str(owner.actor(receiver()).room)
 match str(value.phase):
  "approach":
   if holder!=DELIVERY_OWNER:value.last_wait="source_owner_changed";return
   if owner.move(receiver(),bag_position(),delta):stage("receive")
  "receive":
   if not receiver_contact(bag_position()):stage("approach");return
   if advance_clock(delta)=="done":
    if bag_holder()!=DELIVERY_OWNER:stage("unavailable");return
    if owner.claim("relic_received:"+bag_id(),"asylum_relic_container_received",{"bag":bag_id(),"receiver":receiver(),"items":current_items()}):
     owner.app.rules.owners[bag_id()]=receiver();stage("carry")
  "carry":
   if holder!=receiver():stage("unavailable");return
   if owner.move(receiver(),desk_position(),delta):stage("place")
  "place":
   if holder!=receiver():stage("unavailable");return
   var at:Vector2=desk_position()
   if not receiver_contact(at):stage("carry");return
   if advance_clock(delta)=="done":
    if owner.claim("relic_stored:"+bag_id(),"asylum_relic_container_stored",{"bag":bag_id(),"room":str(config.room),"items":current_items()}):
     value.pos=xy(at);owner.app.rules.owners[bag_id()]=DESK_OWNER;stage("stored")

func observation_target(id:String) -> Dictionary:
 if not usable() or str(state().phase)!="stored" or bag_holder()!=DESK_OWNER or current_items().is_empty():return {}
 if id not in [NUMBER_ID,CONTENTS_ID]:return {}
 # Read the visible bag label before inspecting its visible contents.
 if id==CONTENTS_ID and not state().read.has(NUMBER_ID):return {}
 return {"id":id,"room":str(config.room),"pos":xy(bag_position()),"furniture":int(config.desk_index),"holder":bag_id(),"version":str(config.version),"source":"S3:P656/P659–660"}

func observation_fields(id:String) -> Dictionary:
 var target:Dictionary=observation_target(id)
 if target.is_empty():return {}
 var result:Dictionary={"bag":bag_id(),"bag_number":null,"source_attempt":int(state().delivery.source_attempt),"transport_receipt":str(state().delivery.transport_receipt),"source":"S3:P656"}
 if id==NUMBER_ID:return result
 result.visible_items=current_items()
 result.photo_visible="family_photo" in current_items()
 result.shoe_visible="patient_shoe" in current_items()
 result.photo_recognised=bool(result.photo_visible and "hospital_family_photo_seen" in owner.app.rules.known)
 result.identity_confirmed=false
 return result

func observation_revision(id:String) -> String:
 var fields:Dictionary=observation_fields(id)
 return "" if fields.is_empty() else str(config.version)+":"+JSON.stringify(fields,"",true).sha256_text().substr(0,16)

func on_observation_complete(id:String) -> void:
 var fields:Dictionary=observation_fields(id)
 if fields.is_empty():return
 var previously_recognised:bool=bool(state().get("recognition_spoken",false))
 state().read[id]=fields.duplicate(true)
 if id!=CONTENTS_ID or not fields.get("photo_recognised",false):return
 if previously_recognised:return
 if not owner.claim("relic_photo_recognised:"+bag_id(),"asylum_relic_photo_recognised",{"bag":bag_id(),"identity_confirmed":false}):return
 state().recognition_spoken=true
 for line in config.dialogue.PHOTO_RECOGNISE:owner.app.add_dialogue(str(line.speaker),str(line.text))

func markers() -> Array:
 if not usable() or bag_id().is_empty() or bag_position()==Vector2.INF or current_items().is_empty():return []
 var offset:Vector2=Vector2(12,-24) if bag_holder()==receiver() else Vector2.ZERO
 var depth:float=owner.layout_for(str(config.room)).project(bag_position()).y+0.2
 if bag_holder()==DESK_OWNER:
  var layout=owner.layout_for(str(config.room));var desk:Dictionary=layout.furniture[int(config.desk_index)]
  offset=layout.project(desk.rect.get_center())-layout.project(bag_position())+Vector2(0,-float(desk.height)-3)
  depth=layout.project(desk.rect.end).y+0.2
 return [{"id":bag_id(),"room":str(config.room),"pos":xy(bag_position()),"kind":"bag","label":"未认领物品袋 · "+phase_label(),"holder":bag_holder(),"draw_offset":xy(offset),"depth":depth}]

func phase_label() -> String:
 return str({"approach":"等待接收","receive":"伸手接袋","carry":"携袋归台","place":"放下保存","stored":"已收存"}.get(str(state().phase),"来源待核"))
