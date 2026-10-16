extends RefCounted
## One existing med_nurse, actual doors and actual writing. S3:P799–808.
## All progress is in owner.data; no wall-clock schedule, new actor or rewards.
const Map=preload("res://scripts/core/asylum_map.gd")
const RESERVATION="nurse_duty"
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_nurse_duty.json"))

func state() -> Dictionary:
 if not owner.data.has("nurse_duty_state"):
  owner.data.nurse_duty_state={"entries":[],"completed":{},"job":{},"swallow_pending":{},"swallow_written":false,"read_entries":[],"dialogue_sources":[],"duty_wait_seconds":null,"posted":false}
 if not owner.data.has("staff_targets"):owner.data.staff_targets={}
 normalize_completed_sources(owner.data.nurse_duty_state)
 return owner.data.nurse_duty_state

func normalize_completed_sources(value:Dictionary) -> void:
 # A written/clipped entry is the authoritative completed source. JSON may
 # have changed its numeric attempt from 1 to 1.0 while an old string key
 # still ends in :1. Keep the physical entry and its original ID/provenance;
 # only rebuild the receipt index from those explicit fields.
 var first_by_source:Dictionary={};var written_ids:Dictionary={}
 for entry in value.entries:
  if str(entry.get("id","")).is_empty() or str(entry.get("source_id","")).is_empty() or str(entry.get("source_kind","")).is_empty():continue
  var key:String=source_key(entry);var id:String=str(entry.id)
  written_ids[id]=true
  if first_by_source.has(key):
   # Historical versions could already have physically written two copies.
   # Do not erase either event or institutional record. Mark their common
   # source so loading that history cannot schedule a third new copy.
   entry.duplicate_source=true;entry.duplicate_of=str(first_by_source[key]);entry.duplicate_source_key=key
  else:first_by_source[key]=id
 var completed:Dictionary=value.completed
 for key in completed.keys():
  if written_ids.has(str(completed[key])):completed.erase(key)
 for key in first_by_source:completed[key]=first_by_source[key]
 var pending:Dictionary=value.get("job",{})
 if not pending.is_empty() and not pending.get("source",{}).is_empty() and first_by_source.has(source_key(pending.source)):
  # An old :1.0 job can already be in progress beside a completed :1 copy.
  # Keep even its partial-writing history, but do not let that stale job
  # finish a third copy after migration.
  if not value.has("duplicate_jobs"):value.duplicate_jobs=[]
  value.duplicate_jobs.append({"reason":"source_already_completed","source_key":source_key(pending.source),"existing_entry":str(first_by_source[source_key(pending.source)]),"job":pending.duplicate(true)})
  value.job={};unreserve()

func point(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func station_position() -> Vector2:return owner.space_point("corridor","station_write_pos",point(config.implementation_parameters.station_write_pos))
func xy(value:Vector2) -> Array:return [value.x,value.y]
func timing(key:String) -> float:return float(config.presentation_timing[key])
func stage(job:Dictionary,phase:String) -> void:job.phase=phase;job.elapsed=0.0
func elapsed(job:Dictionary,delta:float,seconds:float) -> bool:
 job.elapsed=float(job.get("elapsed",0.0))+delta
 return float(job.elapsed)+0.000001>=seconds

func record_with_id(id:String) -> Dictionary:
 for entry in owner.app.rules.institutional_records:
  if str(entry.get("id",""))==id:return entry
 return {}

func busy() -> bool:
 if not owner.present("med_nurse"):return true
 if owner.data.has("false_record"):return true
 if owner.data.get("body",{}).get("actor","")=="med_nurse":return true
 var held:String=str(owner.data.get("staff_targets",{}).get("med_nurse",""))
 if held not in ["",RESERVATION]:return true
 # Do not pull an onsite witness away in the middle of receiving this cup.
 # An upstairs nurse remains upstairs while an unaccompanied pharmacist acts.
 if str(owner.actor("med_nurse").room)=="pharmacy" and not owner.data.get("swallowed",false) and not owner.data.get("refused",false):
  var kind:String=str(owner.data.get("body",{}).get("kind",""))
  if kind in ["order_receive","mix","cup_transfer","raise_cup"] or owner.data.get("cup_full",false):return true
 return false

func reserve() -> void:owner.data.staff_targets.med_nurse=RESERVATION
func unreserve() -> void:
 if owner.data.staff_targets.get("med_nurse","")==RESERVATION:owner.data.staff_targets.erase("med_nurse")
 if owner.present("med_nurse") and str(owner.actor("med_nurse").phase).begins_with("nurse_duty_"):owner.actor("med_nurse").phase="idle"

func move_nurse(to:Vector2,delta:float) -> bool:
 if owner.ward_events!=null:return owner.ward_events.bed_move("med_nurse",to,delta,["med_nurse"])
 return owner.move("med_nurse",to,delta)

func arrival_free(room:String,at:Vector2) -> bool:
 if room==owner.app.room_id and at.distance_to(owner.app.hero_pos)<0.42:return false
 for id in owner.data.actors:
  if id!="med_nurse" and owner.present(str(id)) and str(owner.actor(str(id)).room)==room and owner.position(str(id)).distance_to(at)<0.42:return false
 return true

func travel_nurse(room:String,delta:float) -> bool:
 var a:Dictionary=owner.actor("med_nurse")
 if str(a.room)==room:return true
 # The linked pair enters through one pharmacy doorway. Give the pharmacist
 # time to actually clear it and reach the counter; racing into that gap
 # creates a physical head-on deadlock. Waiting never relaxes collision.
 if str(a.room)=="pharmacy" and owner.present("pharmacist") and str(owner.actor("pharmacist").room)=="pharmacy" and not owner.actor("pharmacist").get("work_stand_done",false):return false
 var next:String=Map.next_room(str(a.room),room)
 if next.is_empty() or next=="cortex_exit":return false
 if owner.isolation!=null and not owner.isolation.can_exit(str(a.room),next):return false
 if not move_nurse(owner.portal_for(str(a.room),next).threshold,delta):return false
 var previous:String=str(a.room);var at:Vector2=owner.portal_for(next,previous).landing
 if not arrival_free(next,at):return false
 a.room=next;a.pos=xy(at);a.route=[]
 owner.claim("nurse_door:%s:%s"%[previous,next],"asylum_nurse_crossed_door",{"from":previous,"to":next})
 return next==room

func source_key(source:Dictionary) -> String:
 var attempt=source.get("source_attempt",null)
 var attempt_key:String="null"
 if attempt!=null:
  # Unknown is distinct from a supplied zero. Invalid/fractional legacy
  # values also remain distinguishable rather than silently becoming zero.
  var text:String=str(attempt)
  if text.is_valid_float() and is_finite(float(text)) and is_equal_approx(float(text),float(int(float(text)))):
   attempt_key=str(int(float(text)))
  else:attempt_key="unresolved:"+var_to_str(attempt)
 return "%s:%s:%s"%[source.get("source_kind",""),source.get("source_id",""),attempt_key]

func paper_source(entry:Dictionary,kind:String,room:String,at:Vector2,category=null) -> Dictionary:
 return {"source_id":str(entry.get("id","")),"source_attempt":entry.get("attempt",null),"source_text":str(entry.get("text","")),"source_kind":kind,"source_actor":str(entry.get("source","")),"source_snapshot":entry.duplicate(true),"room":room,"pos":xy(at),"number":null,"number_match":null,"subject_identity":"","category":category,"eyewitness_origin":false}

func source_candidates() -> Array:
 var result:Array=[];var attempt:String=str(owner.app.rules.actual_attempt)
 # These papers exist only after base has actually completed their writing.
 for spec in [["asylum_false_medicine:","medicine_copy",null],["asylum_refusal:","refusal_copy","拒服"],["asylum_nurse_swallow:","swallow_copy",null]]:
  var entry:Dictionary=record_with_id(str(spec[0])+attempt)
  if entry.is_empty():continue
  var at:Vector2=owner.position("pharmacist") if owner.present("pharmacist") and str(owner.actor("pharmacist").room)=="pharmacy" else owner.layout_for("pharmacy").furniture[0].at
  if str(spec[1]) in ["medicine_copy","refusal_copy"] and owner.data.has("cup_place") and owner.data.cup_place.get("room","")=="pharmacy":at=point(owner.data.cup_place.pos)
  var source:Dictionary=paper_source(entry,str(spec[1]),"pharmacy",at,spec[2]);source.subject_identity="hero"
  # A copy keeps the original witness's provenance, never becomes a new one.
  source.eyewitness_origin=str(spec[1])=="swallow_copy"
  result.append(source)
 # A signed command can be read only where the real receiving pharmacist is.
 var order:String=str(owner.data.get("order_source",""))
 if not order.is_empty() and owner.app.rules.owners.get(order,"")=="asylum_pharmacist" and owner.present("pharmacist"):
  var entry:Dictionary=record_with_id("asylum_order:"+attempt)
  if order=="hospital_prescription":
   entry={}
   var visit:String=str(owner.data.get("carry",{}).get("prescription_visit",""))
   var current_visit:String=str(owner.data.get("carry",{}).get("visit",""))
   if not visit.is_empty() and visit==current_visit:
    var inherited:Dictionary=record_with_id("prescription:"+visit)
    if str(inherited.get("source",""))=="医院记录":entry=inherited
  if not entry.is_empty():
   var source:Dictionary=paper_source(entry,"medical_order",str(owner.actor("pharmacist").room),owner.position("pharmacist"));source.holder_actor="pharmacist";source.physical_owner="asylum_pharmacist";source.physical_id=order
   result.append(source)
 # Existing prior records are available in the actual archived copy, not by
 # reading global history from the upstairs desk. A held-away file is absent.
 if owner.records!=null:
  owner.records.state()
  if owner.app.rules.owners.get("asylum_prior_copy","")=="office:6":
   var at:Vector2=owner.layout_for("office").furniture[6].at
   for entry in owner.app.rules.institutional_records:
    if str(entry.get("source",""))!="医院记录":continue
    var source:Dictionary=paper_source(entry,"prior_copy","office",at)
    source.physical_id="asylum_prior_copy";source.physical_owner="office:6";result.append(source)
 # A written report at the real station can be read without taking its signed
 # isolation order or inventing a new ordinary-orderly dispatch.
 for report in owner.data.get("ward_events",{}).get("reports",[]):
  if not report.get("written",false):continue
  var entry:Dictionary={"id":str(report.id),"attempt":report.get("attempt",null),"text":str(report.get("testimony","")),"source":str(report.get("source",""))}
  var source:Dictionary=paper_source(entry,"ward_report","corridor",point(report.station_pos),"待处理")
  source.subject_identity=str(report.get("target",""));source.number=report.get("patient_number",null);source.source_snapshot=report.duplicate(true)
  result.append(source)
 return result

func next_source() -> Dictionary:
 for source in source_candidates():
  if not state().completed.has(source_key(source)):return source
 return {}

func source_exists(source:Dictionary) -> bool:
 for candidate in source_candidates():
  if source_key(candidate)==source_key(source):return true
 return false

func refreshed_source(source:Dictionary) -> Dictionary:
 for candidate in source_candidates():
  if source_key(candidate)==source_key(source):return candidate
 return {}

func contact_source(source:Dictionary,delta:float) -> bool:
 if not travel_nurse(str(source.room),delta):return false
 var at:Vector2=point(source.pos)
 if owner.position("med_nurse").distance_to(at)<=float(config.implementation_parameters.source_contact_distance) and owner.layout_for(str(source.room)).clear_segment(owner.position("med_nurse"),at):return true
 # Stop beside a holder instead of pathing into the holder's body.
 if source.has("holder_actor"):
  var from:Vector2=owner.position("med_nurse");var offset:Vector2=(from-at).normalized()
  if offset.length()<0.1:offset=Vector2.RIGHT
  move_nurse(at+offset*0.55,delta)
 else:move_nurse(at,delta)
 return false

func on_swallow(witnessed:bool) -> void:
 if owner.data.is_empty() or not witnessed or not owner.data.get("swallowed",false) or not owner.present("med_nurse"):return
 var value:Dictionary=state();var id:String="asylum_nurse_swallow:"+str(owner.app.rules.actual_attempt)
 if not record_with_id(id).is_empty() or value.swallow_written or not value.swallow_pending.is_empty():return
 value.swallow_pending={"phase":"return","elapsed":0.0,"room":str(owner.actor("med_nurse").room),"pos":xy(owner.position("med_nurse")),"attempt":owner.app.rules.actual_attempt,"source_id":id,"witnessed_complete_swallow":true}

func advance_swallow(delta:float) -> void:
 var value:Dictionary=state();var job:Dictionary=value.swallow_pending
 if job.is_empty():return
 if int(job.attempt)!=owner.app.rules.actual_attempt:value.swallow_pending={};unreserve();return
 reserve();owner.actor("med_nurse").phase="nurse_duty_swallow_write"
 if not travel_nurse(str(job.room),delta):return
 var at:Vector2=point(job.pos)
 if owner.position("med_nurse").distance_to(at)>0.15:
  move_nurse(at,delta);return
 if not owner.layout_for(str(job.room)).clear_segment(owner.position("med_nurse"),at):return
 if not elapsed(job,delta,timing("write")):return
 owner.record(str(job.source_id),"给药护士亲眼见到本次完整接杯与吞服；不再次触发药效。")
 owner.claim("nurse_swallow_written","asylum_nurse_swallow_written",{"source_id":str(job.source_id),"own_eyewitness":true})
 value.swallow_written=true;value.swallow_pending={};unreserve()

func advance_posting(delta:float) -> void:
 var value:Dictionary=state()
 reserve();owner.actor("med_nurse").phase="nurse_duty_to_station"
 if not travel_nurse("corridor",delta):return
 if not move_nurse(station_position(),delta):return
 value.posted=true
 owner.claim("nurse_duty_posted","asylum_nurse_reached_duty_station",{"actor":"med_nurse","actual_doors":true,"source":"S1:T10R3/S4:P109","new_paper":false})
 unreserve()

func tick(delta:float) -> void:
 if owner.data.is_empty() or owner.app.session.data.level!=3 or not is_finite(delta) or delta<=0:return
 if owner.app.rules.hp<=0 or not owner.app.dialogue_queue.is_empty():return
 var value:Dictionary=state()
 if busy():return
 if not value.swallow_pending.is_empty():advance_swallow(delta);return
 if value.job.is_empty():
  var source:Dictionary=next_source()
  if source.is_empty():
   if not value.get("posted",false):advance_posting(delta)
   else:unreserve()
   return
  value.job={"phase":"source","elapsed":0.0,"source":source,"read_completed":false,"number_checked":false,"written":false,"clipped":false}
 var job:Dictionary=value.job;reserve();owner.actor("med_nurse").phase="nurse_duty_"+str(job.phase)
 if job.phase in ["source","read","check"]:
  var source:Dictionary=refreshed_source(job.source)
  if source.is_empty():value.job={};unreserve();return
  job.source=source
  if not contact_source(source,delta):job.elapsed=0.0;return
  if job.phase=="source":stage(job,"read");return
  if job.phase=="read":
   if not elapsed(job,delta,timing("read")):return
   job.read_completed=true;stage(job,"check");return
  if not elapsed(job,delta,timing("number_check")):return
  job.number_checked=true
  # Null identifiers remain unknown. Checking a field is not inventing glyphs
  # or concluding that two unknown identifiers do/don't match.
  job.source.number_match=null
  owner.claim("nurse_source_read:"+source_key(source),"asylum_nurse_source_read",{"source_id":source.source_id,"number":source.number,"source_attempt":source.source_attempt})
  stage(job,"to_station");return
 if not travel_nurse("corridor",delta):return
 var station:Vector2=station_position()
 if not move_nurse(station,delta):return
 if job.phase=="to_station":stage(job,"write");return
 if job.phase=="write":
  if not elapsed(job,delta,timing("write")):return
  job.written=true;stage(job,"clip");return
 if job.phase=="clip":
  if not elapsed(job,delta,timing("clip")):return
  job.clipped=true
  var entry:Dictionary=job.source.duplicate(true)
  entry.id="asylum_duty:%d:%s"%[owner.app.rules.actual_attempt,source_key(job.source)]
  entry.copied_by="med_nurse";entry.copy_attempt=owner.app.rules.actual_attempt
  entry.read_completed=true;entry.number_checked=true;entry.written=true;entry.clipped=true
  entry.original_owner_changed=false;entry.own_swallow_witness=false
  value.entries.append(entry);value.completed[source_key(job.source)]=str(entry.id);value.posted=true
  owner.record(str(entry.id),"病区护士值班表转抄；来源：%s。原记录：%s。分类：%s。"%[entry.source_id,entry.source_text,"未定" if entry.category==null else str(entry.category)])
  owner.claim("nurse_duty_clipped:"+source_key(job.source),"asylum_nurse_duty_clipped",{"source_id":entry.source_id,"source_attempt":entry.source_attempt,"category":entry.category,"number":entry.number,"actual_body_effect":false})
  value.job={};unreserve()

func public_readable() -> bool:
 return not owner.data.is_empty() and not state().entries.is_empty()

func source_error_known(entry:Dictionary) -> bool:
 var id:String=str(entry.source_id)
 # Knowing one's own real refusal and then actually reading the corresponding
 # already-taken copy exposes that contradiction; this is not a claim to have
 # witnessed the original nurse's pen. A generic old known flag binds no visit.
 if id=="asylum_false_medicine:"+str(owner.app.rules.actual_attempt):return owner.data.get("refused",false) and not owner.data.get("swallowed",false)
 var carry:Dictionary=owner.data.get("carry",{})
 var prior_visit:String=str(carry.get("visit",""))
 if not prior_visit.is_empty() and id=="false_medicine:"+prior_visit:return carry.get("refused",false) and not carry.get("swallowed",false)
 return false

func on_table_read() -> void:
 if owner.data.is_empty() or owner.app.room_id!="corridor":return
 var at:Vector2=owner.layout_for("corridor").furniture[0].at
 if owner.app.hero_pos.distance_to(at)>0.7 or not owner.app.layout.clear_segment(owner.app.hero_pos,at):return
 var value:Dictionary=state()
 for entry in value.entries:
  if not entry.get("clipped",false) or int(entry.get("copy_attempt",0))!=owner.app.rules.actual_attempt:continue
  var id:String=str(entry.id)
  if not id in value.read_entries:value.read_entries.append(id)
  owner.observe("asylum_duty_read:"+id,"实际读到本次值班表转抄；来源："+str(entry.source_id)+"。转抄来源与实际身体事件分开。")
  if not source_error_known(entry) or str(entry.source_id) in value.dialogue_sources:continue
  if not owner.near("med_nurse",2.0):continue
  value.dialogue_sources.append(str(entry.source_id))
  owner.observe("asylum_duty_copied_error","实际读到已知错误源的本次转抄；没有把抄录变成新的服药或真实攻击。")
  if not owner.claim("nurse_copy_error_line","asylum_dialogue",{"source":"S3:P805–808","source_id":entry.source_id}):continue
  for line in config.dialogue.COPIED_ERROR:owner.app.add_dialogue(str(line.speaker),str(line.text))

func action_label() -> String:
 if owner.data.is_empty():return ""
 var value:Dictionary=state()
 if not value.swallow_pending.is_empty():return "给药护士：亲见吞服后实际填表"
 if value.job.is_empty():return ""
 return {"source":"病区护士：赴资料原处","read":"病区护士：读取原件","check":"病区护士：核对编号","to_station":"病区护士：走往二层护士站","write":"病区护士：填写值班表","clip":"病区护士：夹回资料"}.get(str(value.job.phase),"")
