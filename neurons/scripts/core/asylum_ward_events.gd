extends RefCounted
## S3:P824–843/P887–917/P1014–1054; S4:T15R8. A small L3 event module.
## All mutable state lives in the parent's saved JSON dictionary. Rendering
## may replace poses and sounds without deciding contact, ownership or facts.
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_ward_events.json"))

func state() -> Dictionary:
 if not owner.data.has("ward_events"):owner.data.ward_events={}
 var value:Dictionary=owner.data.ward_events
 if not value.has("clamp"):value.clamp={"phase":"idle","elapsed":0.0,"attempted":false,"hand_out":false,"retract_left":0.0,"hold_invalidated":false}
 if not value.has("work"):
  value.work={"phase":"take_paper","elapsed":0.0,"paper":"rack","label":"rack","box":"none","batch":null,"products":0,"table":"workshop:1"}
 if not value.has("therapy"):
  value.therapy={"phase":"idle","elapsed":0.0,"recording":false,"segment_exists":false,"original_spoken":false,"retraction_spoken":false,"heard_original":false,"heard_retraction":false,"saw_deletion":false,"paper":"therapist","speaker_number":null,"seat_required":false}
 # Persist the actual sheet/product alongside their pre-existing action state.
 # Loading an older action may recover current ownership, never fabricate a
 # handover history, signature, label glyph or a new usable material instance.
 if not value.therapy.has("statement_asset"):
  value.therapy.statement_asset={"id":"asylum_statement_paper","version":1,"holder":str(value.therapy.paper),"exposed":value.therapy.paper=="speaker","history":[]}
 if not value.therapy.has("signature_asset"):
  value.therapy.signature_asset={"id":"asylum_signature_record","version":1,"holder":"therapist","history":[]}
 if not value.work.has("box_asset"):
  value.work.box_asset={"id":"asylum_work_box","version":1,"history":[]}
 owner.app.rules.owners.asylum_statement_paper=str(value.therapy.statement_asset.holder)
 owner.app.rules.owners.asylum_signature_record=str(value.therapy.signature_asset.holder)
 sync_work_owners(value.work)
 if not value.has("transfer"):
  value.transfer={"phase":"idle","elapsed":0.0,"patient_number":null,"order":"porter","brake":true,"hand_done":false,"band_drop":{},"delivered":false,"isolation_authorized":false,"bed_room":"corridor","bed_pos":[],"seen":[]}
  # New actual attempts rebuild local uncollected props. A band already in
  # the protagonist's inventory is never reset or copied back onto a patient.
  if owner.app.rules.owners.get("asylum_transport_band","")=="ward_floor":owner.app.rules.owners.asylum_transport_band="transport_patient"
 if not value.has("postop"):
  value.postop={"phase":"idle","elapsed":0.0,"wound_visible":false,"hero_saw_wound":false,"informer_saw_wound":false,"informer_phase":"privacy_walk","informer_elapsed":0.0,"report_phase":"idle","report_elapsed":0.0,"report_id":"","last_room":"activity","last_pos":[]}
 if not value.has("reports"):value.reports=[]
 if not value.has("ordinary_job"):value.ordinary_job={"phase":"idle","elapsed":0.0,"report_id":"","target":"","holding":false,"full_witness":false}
 if not value.has("chief_internal"):value.chief_internal={"phase":"idle","elapsed":0.0,"report_id":"","last_room":"corridor","last_pos":[]}
 if not owner.data.has("staff_targets"):owner.data.staff_targets={}
 return value

func timing(key:String) -> float:return float(config.presentation_timing[key])
func xy(point:Vector2) -> Array:return [point.x,point.y]
func point(value:Array) -> Vector2:return Vector2(float(value[0]),float(value[1]))
func corridor_rule_point(key:String) -> Vector2:return owner.space_point("corridor",key,point(config.rules[key]))

func stage(event:Dictionary,phase:String) -> void:
 event.phase=phase;event.elapsed=0.0

func elapsed(event:Dictionary,delta:float,seconds:float) -> bool:
 event.elapsed=float(event.get("elapsed",0))+delta
 return float(event.elapsed)+0.000001>=seconds

func visible(id:String,at:Vector2,room:String,distance:float=2.0) -> bool:
 if not owner.present(id) or str(owner.actor(id).room)!=room:return false
 if owner.position(id).distance_to(at)>distance:return false
 return owner.layout_for(room).clear_segment(owner.position(id),at)

func hero_sees(id:String,distance:float=2.0) -> bool:
 return owner.near(id,distance)

func local_say(key:String,participants:Array) -> bool:
 for id in participants:
  if not hero_sees(str(id),2.4):return false
 if not owner.claim("ward_line:"+key,"asylum_dialogue",{"source":config.sources}):return false
 for line in config.dialogue.get(key,[]):
  var text:String=str(line.text)
  # The source's placeholder is retained as a placeholder, never parsed into
  # a number or used to unlock a same-number link.
  if key=="THERAPY_ORIGINAL" and state().therapy.speaker_number!=null:
   text=text.replace("【对应编号】",str(state().therapy.speaker_number))
  owner.app.add_dialogue(str(line.speaker),text)
 return not owner.app.dialogue_queue.is_empty()

func furniture(room:String,index:int) -> Dictionary:
 var layout=owner.layout_for(room)
 if index<0 or index>=layout.furniture.size():return {}
 return layout.furniture[index]

func target_point(room:String,index:int) -> Vector2:
 var item:Dictionary=furniture(room,index)
 return item.get("at",Vector2(2.8,1.1))

func sync_work_owners(work:Dictionary) -> void:
 var holder:String="labor_patient" if work.paper=="labor_patient" else "workshop_table2"
 if work.box!="none":owner.app.rules.owners.asylum_work_box=holder
 else:owner.app.rules.owners.erase("asylum_work_box")
 owner.app.rules.owners.asylum_work_paper="asylum_work_box" if work.box!="none" else ("workshop_material_rack" if work.paper=="rack" else str(work.paper))
 owner.app.rules.owners.asylum_work_label="asylum_work_box" if work.label=="box" else ("workshop_material_rack" if work.label=="rack" else str(work.label))

func work_contact(work:Dictionary,node:String) -> void:
 var asset:Dictionary=work.box_asset
 asset.version=int(asset.version)+1
 asset.history.append({"node":node,"phase":str(work.phase),"box":str(work.box),"paper":str(work.paper),"label":str(work.label),"attempt":owner.app.rules.actual_attempt})
 sync_work_owners(work)

func evidence_target(id:String) -> Dictionary:
 var value:Dictionary=state()
 if id=="asylum_statement_paper":
  var paper:Dictionary=value.therapy.statement_asset;var holder:String=str(paper.holder)
  if not paper.exposed or not owner.present(holder):return {}
  return {"id":id,"holder":holder,"room":str(owner.actor(holder).room),"pos":xy(owner.position(holder)),"furniture":2,"visible":true,"version":int(paper.version)}
 if id=="asylum_product_label":
  var work:Dictionary=value.work
  # A fetched loose label and a folded-but-unlabelled box are not a labelled
  # product. Physical paste contact must have happened; placing is separate.
  if work.box not in ["labelled","table2"] or work.label!="box":return {}
  if work.box=="table2" and int(work.products)<=0:return {}
  var at:Vector2=target_point("workshop",int(config.workshop.table_index))
  return {"id":id,"asset_id":"asylum_work_box","holder":"workshop_table2","room":"workshop","pos":xy(at),"furniture":int(config.workshop.table_index),"visible":true,"version":int(work.box_asset.version)}
 if id=="asylum_signature_record":
  # S1:P168 provides the existing attached record; S3:P888 supplies its
  # actual clipboard holder. P915 supplies no signer, name or signing node.
  var record:Dictionary=value.therapy.signature_asset;var holder:String=str(record.holder)
  if not owner.present(holder):return {}
  return {"id":id,"holder":holder,"room":str(owner.actor(holder).room),"pos":xy(owner.position(holder)),"furniture":5,"visible":true,"version":int(record.version)}
 return {}

func evidence_fields(id:String) -> Dictionary:
 var target:Dictionary=evidence_target(id)
 if target.is_empty():return {}
 if id=="asylum_statement_paper":
  return {"text":str(config.evidence.statement_text),"holder":target.holder,"document_version":int(target.version),"acknowledged":null,"actually_signed":null,"prefilled_name":null,"proxy_signature":null,"source":"S3:P914–915","note":"读纸不是同意、照读或亲手签署；未知签字栏不补造事实。"}
 if id=="asylum_signature_record":
  return {"holder":target.holder,"document_version":int(target.version),"prefilled_name":null,"actual_signature":null,"actual_signer":null,"proxy_signature":null,"signature_date":null,"source":"S1:P168 / S3:P888/P915","note":"实际翻看记录夹中的附属签字记录；具体字形未提供，不能由预填姓名或一页纸制造本人亲手落笔事实。"}
 var work:Dictionary=state().work
 return {"asset_id":"asylum_work_box","batch":work.batch,"folded":true,"label_pasted":true,"placed":work.box=="table2","holder":target.holder,"document_version":int(target.version),"contents":null,"source":"S3:P1037–1038/P1048","note":"实际成品标签；批次不等于患者编号，标签不证明箱内内容。"}

func evidence_revision(id:String) -> String:
 var fields:Dictionary=evidence_fields(id)
 return "" if fields.is_empty() else "ward-evidence-1:"+JSON.stringify(fields,"",true).sha256_text().substr(0,16)

func evidence_markers() -> Array:
 var result:Array=[]
 var paper:Dictionary=evidence_target("asylum_statement_paper")
 if not paper.is_empty():
  paper.kind="note";paper.label="统一陈述纸 · 在病友手中";paper.draw_offset=[12,-32];result.append(paper)
 var record:Dictionary=evidence_target("asylum_signature_record")
 if not record.is_empty():
  record.kind="note";record.label="签字记录附页 · 字形未定";record.draw_offset=[-12,-32];result.append(record)
 return result

func tick(delta:float) -> void:
 if owner.data.is_empty() or owner.app.session.data.level!=3:return
 state()
 if owner.app.rules.hp<=0:
  release_drawer();state().therapy.seat_required=false
  if state().ordinary_job.get("target","")=="hero":finish_ordinary("death")
  return
 if not owner.app.dialogue_queue.is_empty():return
 advance_clamp(delta)
 if owner.app.rules.hp<=0 or not owner.app.dialogue_queue.is_empty():return
 advance_work(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_therapy(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_transfer(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_postop(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_chief_internal(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_postop_report(delta)
 if not owner.app.dialogue_queue.is_empty():return
 advance_ordinary_report(delta)

func searching_drawer() -> bool:
 return owner.app.room_id=="workshop" and owner.app.rules.search_active and owner.app.target_index==int(config.workshop.material_cabinet_index)

func advance_clamp(delta:float) -> void:
 var event:Dictionary=state().clamp
 if not owner.present("supervisor"):
  if event.phase=="release":release_drawer()
  elif event.phase!="idle":stage(event,"done" if event.attempted else "idle")
  return
 if event.phase=="release":
  if elapsed(event,delta,minf(timing("drawer_release"),float(config.rules.drawer_release_limit))):release_drawer()
  return
 if event.phase=="done":return
 if event.phase=="idle":
  if not searching_drawer() or not hero_sees("supervisor",2.0):return
  event.search_id=str(owner.app.rules._search_id)
  stage(event,"approach")
 if event.phase=="approach":
  if not searching_drawer() or owner.app.room_id!="workshop":stage(event,"idle");return
  if not hero_sees("supervisor",2.0):stage(event,"idle");return
  if not owner.near("supervisor",0.55):owner.move("supervisor",owner.app.hero_pos,delta);return
  if not owner.can_begin_grip():return
  event.attempted=true;event.hold_invalidated=false;event.hand_out=false;event.retract_left=0.0
  owner.claim("drawer_attempt","asylum_drawer_attempt",{"source":"S3:P1019"})
  stage(event,"windup")
  local_say("CLAMP_NOTICE",["supervisor"])
  return
 if event.phase!="windup":return
 if str(owner.data.get("holder","")) not in ["","supervisor"]:event.hold_invalidated=true
 # Cancelling an action starts the visible withdrawal; a late cancellation
 # does not retrospectively remove a hand from an already closing drawer.
 if not searching_drawer() and not event.hand_out and float(event.retract_left)<=0:
  event.retract_left=timing("hand_retract")
 if float(event.retract_left)>0:
  event.retract_left=maxf(0,float(event.retract_left)-delta)
  if float(event.retract_left)<=0:event.hand_out=true
 if not elapsed(event,delta,timing("drawer_windup")):return
 var at:Vector2=target_point("workshop",int(config.workshop.material_cabinet_index))
 var hit:bool=not event.hand_out and owner.app.room_id=="workshop" and owner.app.hero_pos.distance_to(at)<=0.25 and owner.near("supervisor",0.65)
 owner.claim("drawer_close","asylum_drawer_contact",{"hit":hit,"hand_withdrawn":event.hand_out})
 if hit:
  var may_hold:bool=not event.hold_invalidated and owner.can_begin_grip()
  owner.damage("drawer_hurt",int(config.rules.drawer_hp),int(config.rules.drawer_sp))
  if owner.app.rules.hp<=0:release_drawer();return
  if may_hold:
   owner.data.holder="supervisor";owner.app.rules.gripped=true
   owner.set_body("ward_drawer_hold","supervisor")
  stage(event,"release")
  local_say("CLAMP_HURT",["supervisor"])
 else:
  stage(event,"release")
  if owner.app.room_id=="workshop" and owner.near("supervisor",2.0):local_say("CLAMP_MISS",["supervisor"])

func release_drawer() -> void:
 var event:Dictionary=state().clamp
 if str(owner.data.get("holder",""))=="supervisor":
  owner.data.holder="";owner.app.rules.gripped=false;owner.data.regrab_elapsed=0.0
 if owner.data.get("body",{}).get("kind","")=="ward_drawer_hold":owner.clear_body()
 stage(event,"done")

func advance_work(delta:float) -> void:
 if not owner.present("labor_patient") or str(owner.actor("labor_patient").room)!="workshop":return
 var event:Dictionary=state().work
 if owner.near("labor_patient",1.2) and not owner.app.has_key() and owner.app.rules.control_left<=0 and not owner.app.rules.body_busy():
  if local_say("LABOR",["labor_patient"]):return
 if event.phase in ["done","waiting_materials"]:return
 var target:Vector2=owner.space_point("workshop","worker_table",target_point("workshop",int(config.workshop.table_index)))
 if event.phase in ["take_paper","take_label"]:target=owner.space_point("workshop","worker_rack",target_point("workshop",int(config.workshop.material_rack_index)))
 if not owner.move("labor_patient",target,delta):return
 match str(event.phase):
  "take_paper":
   if event.paper!="rack":stage(event,"waiting_materials");return
   if elapsed(event,delta,timing("take_material")):
    event.paper="labor_patient";event.box="unfolded";stage(event,"fold")
    work_contact(event,"take_paper")
    owner.claim("paper_taken","asylum_material_taken",{"material":"visible_paper","table":2})
  "fold":
   if event.paper!="labor_patient":stage(event,"waiting_materials");return
   if elapsed(event,delta,timing("fold")):
    event.box="folded";stage(event,"flatten")
    work_contact(event,"fold")
    owner.claim("box_folded","asylum_work_partial",{"table":2})
  "flatten":
   if elapsed(event,delta,timing("flatten")):
    event.box="unlabelled";event.paper="table2";stage(event,"take_label")
    work_contact(event,"flatten")
  "take_label":
   if event.label!="rack":stage(event,"waiting_materials");return
   if elapsed(event,delta,timing("take_material")):
    event.label="labor_patient";stage(event,"paste")
    work_contact(event,"take_label")
    owner.claim("label_taken","asylum_material_taken",{"material":"visible_label","table":2})
  "paste":
   if event.box!="unlabelled" or event.label!="labor_patient":stage(event,"waiting_materials");return
   if elapsed(event,delta,timing("paste")):
    event.label="box";event.box="labelled";stage(event,"place")
    work_contact(event,"paste")
    owner.claim("label_pasted","asylum_work_partial",{"batch":event.batch})
  "place":
   if elapsed(event,delta,timing("place")):
    event.paper="box";event.box="table2";event.products=int(event.products)+1;stage(event,"done")
    work_contact(event,"place")
    owner.claim("box_placed","asylum_work_completed",{"table":2,"batch":event.batch,"resources":0})

func take_material(which:String) -> bool:
 if which not in ["paper","label"] or owner.app.room_id!="workshop" or owner.app.rules.body_busy() or owner.app.rules.gripped:return false
 var event:Dictionary=state().work
 if event[which]!="rack":return false
 var at:Vector2=target_point("workshop",int(config.workshop.material_rack_index))
 if owner.app.hero_pos.distance_to(at)>float(config.rules.pickup_distance) or not owner.app.layout.clear_segment(owner.app.hero_pos,at):return false
 event[which]="hero";owner.app.rules.owners["asylum_work_"+which]="hero"
 work_contact(event,"hero_took_"+which)
 owner.claim("take_material:"+which,"asylum_material_taken",{"material":which,"holder":"hero"})
 return true

func advance_therapy(delta:float) -> void:
 var event:Dictionary=state().therapy
 if event.phase in ["done","interrupted"]:return
 if not owner.present("therapist") or not owner.present("speaker"):
  if event.phase!="idle":event.seat_required=false;stage(event,"interrupted")
  return
 if str(owner.actor("therapist").room)!="group_therapy" or str(owner.actor("speaker").room)!="group_therapy":
  if event.phase!="idle":event.seat_required=false;stage(event,"interrupted")
  return
 var controls:Vector2=target_point("group_therapy",5)
 var seat:Vector2=target_point("group_therapy",2)
 if event.phase=="idle":stage(event,"setup")
 if event.phase=="setup":
  var a:bool=owner.move("therapist",controls,delta)
  var b:bool=owner.move("speaker",seat,delta)
  if a and b:stage(event,"start_recording")
  return
 match str(event.phase):
  "start_recording":
   if elapsed(event,delta,timing("device_press")):
    event.recording=true;event.seat_required=true;stage(event,"original")
    owner.claim("record_start","asylum_recording_started")
  "original":
   event.pending_heard_original=local_say("THERAPY_ORIGINAL",["speaker","therapist"])
   stage(event,"original_spoken")
  "original_spoken":
   event.original_spoken=true;event.segment_exists=event.recording
   event.heard_original=bool(event.get("pending_heard_original",false))
   owner.claim("speaker_original","asylum_original_spoken",{"number":event.speaker_number,"recorded":event.segment_exists})
   if event.heard_original:owner.observe("asylum_heard_original","实际听见发言病友讲到自己经历的转运编号；具体编号字形仍未提供，不作同号核对。")
   stage(event,"say_stop");local_say("THERAPY_STOP",["therapist","speaker"])
  "say_stop":
   # A spoken stop leaves the recorder running until the hand reaches its key.
   stage(event,"stop_recording")
  "stop_recording":
   if not owner.move("therapist",controls,delta):return
   if elapsed(event,delta,timing("device_press")):
    event.recording=false;stage(event,"delete_recording")
    owner.claim("record_stop","asylum_recording_stopped")
  "delete_recording":
   if not owner.move("therapist",controls,delta):return
   if elapsed(event,delta,timing("delete_recording")):
    event.segment_exists=false;event.saw_deletion=hero_sees("therapist",2.4)
    owner.claim("record_delete","asylum_recording_deleted",{"original_spoken":event.original_spoken})
    if event.saw_deletion:owner.observe("asylum_record_deletion_seen","实际看见治疗主任操作设备删除对应录音片段；已亲耳听到的内容仍保留。")
    stage(event,"approach_paper")
  "approach_paper":
   if owner.position("therapist").distance_to(owner.position("speaker"))>0.5:
    owner.move("therapist",owner.position("speaker"),delta);return
   if not owner.layout_for("group_therapy").clear_segment(owner.position("therapist"),owner.position("speaker")):return
   stage(event,"give_paper")
  "give_paper":
   if owner.position("therapist").distance_to(owner.position("speaker"))>0.65:stage(event,"approach_paper");return
   if not owner.layout_for("group_therapy").clear_segment(owner.position("therapist"),owner.position("speaker")):stage(event,"approach_paper");return
   if elapsed(event,delta,timing("paper_handoff")):
    event.paper="speaker"
    event.statement_asset.holder="speaker";event.statement_asset.exposed=true
    event.statement_asset.version=int(event.statement_asset.version)+1
    event.statement_asset.history.append({"node":"actual_handoff","from":"therapist","to":"speaker","attempt":owner.app.rules.actual_attempt})
    owner.app.rules.owners.asylum_statement_paper="speaker"
    owner.claim("statement_given","asylum_statement_given",{"holder":"speaker","asset_id":"asylum_statement_paper","version":int(event.statement_asset.version)})
    stage(event,"request_read");local_say("THERAPY_READ",["therapist","speaker"])
  "request_read":
   stage(event,"retraction_spoken")
   event.pending_heard_retraction=local_say("THERAPY_RETRACT",["speaker","therapist"])
  "retraction_spoken":
   if event.paper!="speaker":stage(event,"interrupted");event.seat_required=false;return
   event.retraction_spoken=true;event.heard_retraction=bool(event.get("pending_heard_retraction",false))
   owner.claim("speaker_retraction","asylum_retraction_spoken",{"text":"此前所述均不属实"})
   if event.heard_retraction:owner.observe("asylum_heard_retraction","实际听见发言病友照读：此前所述均不属实。未听到原发言时不补造其内容。")
   stage(event,"write_minutes")
  "write_minutes":
   if elapsed(event,delta,timing("minutes_write")):
    owner.record("asylum_group_minutes:%d"%owner.app.rules.actual_attempt,"团体治疗完整笔录（机构记录）；原发言、设备删除和被要求照读的撤回句分别保存。")
    owner.claim("minutes_written","asylum_minutes_written",{"retraction_spoken":event.retraction_spoken})
    stage(event,"stand_up")
  "stand_up":
   if owner.move("speaker",owner.space_point("group_therapy","speaker_release",Vector2(2.8,0.9)),delta):
    event.seat_required=false;stage(event,"done")
    owner.claim("speaker_released","asylum_speaker_left_seat")
    if event.heard_original and event.saw_deletion and owner.near("therapist",2.4):
     if local_say("THERAPY_QUESTION",["therapist"]):stage(event,"question_write")
  "question_write":
   if not owner.move("therapist",controls,delta):return
   if elapsed(event,delta,timing("minutes_write")):
    owner.record("asylum_group_question:%d"%owner.app.rules.actual_attempt,"角色当面质问删除原发言后，治疗主任实际写入质问记录；记录不造成身体伤害。")
    owner.claim("group_question_written","asylum_group_question_written")
    stage(event,"done")
  _:
   pass

func advance_transfer(delta:float) -> void:
 var event:Dictionary=state().transfer
 if event.phase in ["done","await_band"]:return
 if not owner.present("porter") or not owner.present("transport_patient"):return
 if str(owner.actor("porter").room)!=str(owner.actor("transport_patient").room):return
 event.bed_room=str(owner.actor("transport_patient").room)
 event.bed_pos=xy(owner.position("transport_patient"))
 if str(event.phase).begins_with("station_"):
  advance_transfer_station(delta)
  event.bed_room=str(owner.actor("transport_patient").room)
  event.bed_pos=xy(owner.position("transport_patient"))
  return
 if event.phase=="idle":
  if event.bed_room!="corridor":return
  var band_owner:String=str(owner.app.rules.owners.get("asylum_transport_band",""))
  if band_owner.is_empty():owner.app.rules.owners.asylum_transport_band="transport_patient"
  elif band_owner!="transport_patient":stage(event,"await_band");return
  # An initial signed order is an initial scene record, never a protagonist
  # witness. The actual check below binds its internal subject, not invented
  # visible number glyphs.
  owner.claim("transport_initial_order","asylum_transfer_order_initial",{"patient":"transport_patient","number":null,"witness":false})
  stage(event,"approach")
 if event.phase=="approach":
  if owner.position("porter").distance_to(owner.position("transport_patient"))>0.45:
   owner.move("porter",owner.position("transport_patient"),delta);return
  if not owner.layout_for(event.bed_room).clear_segment(owner.position("porter"),owner.position("transport_patient")):return
  stage(event,"check")
  return
 if event.phase=="check":
  if owner.app.rules.owners.get("asylum_transport_band","")!="transport_patient":stage(event,"await_band");return
  if elapsed(event,delta,timing("transfer_check")):
   owner.claim("transport_subject_check","asylum_transfer_subject_checked",{"subject":"transport_patient","subject_binding_verified":true,"visible_number":null,"protagonist_number_known":false})
   stage(event,"release_brake")
 elif event.phase=="release_brake":
  if elapsed(event,delta,timing("brake_release")):
   event.brake=false;stage(event,"push")
   owner.claim("bed_brake_released","asylum_bed_brake_released")
 elif event.phase=="push":
  if not event.hand_done and not event.get("station_considered",false):
   if begin_transfer_station():return
  if not event.hand_done:
   event.hand_done=true;stage(event,"hand_grab")
   owner.claim("patient_grasped_bed","asylum_patient_hand_visible",{"alive":true})
   if hero_sees("transport_patient",2.0):
    event.seen.append("hand");local_say("TRANSFER_HAND",["porter","transport_patient"])
   return
  if pair_travel("quiet",delta):stage(event,"park")
 elif event.phase=="hand_grab":
  if elapsed(event,delta,timing("patient_hand_return")):
   owner.claim("patient_hand_returned","asylum_patient_hand_returned")
   if owner.app.rules.owners.get("asylum_transport_band","")=="transport_patient":
    event.band_drop={"room":str(owner.actor("transport_patient").room),"pos":xy(owner.position("transport_patient")),"number":null,"read_elapsed":0.0,"read":false}
    owner.app.rules.owners.asylum_transport_band="ward_floor"
    owner.claim("transport_band_dropped","asylum_band_dropped",{"room":event.band_drop.room,"pos":event.band_drop.pos,"number":null})
   stage(event,"push")
   if hero_sees("transport_patient",2.0):
    owner.observe("asylum_transport_alive_seen","实际看见第三关推床患者在床单下伸手抓床沿；此人仍活着，不套用第二关轮椅患者身份。")
    local_say("TRANSFER_ALIVE",["transport_patient"])
 elif event.phase=="park":
  var at:Vector2=owner.space_point("quiet","transport_bed_park",Vector2(3.0,2.1))
  if not pair_move(at,delta):return
  if elapsed(event,delta,timing("park_bed")):
   event.brake=true;event.delivered=true;stage(event,"done")
   owner.claim("transport_delivered","asylum_bed_transfer_delivered",{"target":"transport_patient","room":"quiet","isolated":false,"treated":false,"dead":false})
   var report:Dictionary=report_for_id(str(event.get("station_report_id","")))
   if not report.is_empty():
    report.actual_delivery_actor="porter";report.delivery_outcome="delivered"
    report.last_room="quiet";report.last_pos=xy(owner.position("transport_patient"))
 event.bed_room=str(owner.actor("transport_patient").room)
 event.bed_pos=xy(owner.position("transport_patient"))

func begin_transfer_station() -> bool:
 var event:Dictionary=state().transfer
 event.station_considered=true;event.station_elapsed=0.0;event.station_outcome="not_available"
 if not owner.present("head_nurse") or str(owner.actor("head_nurse").room)!="corridor" or owner.data.staff_targets.has("head_nurse"):return false
 if str(owner.actor("porter").room)!="corridor" or str(owner.actor("transport_patient").room)!="corridor":return false
 if owner.app.rules.owners.get("asylum_transport_band","")!="transport_patient" or event.order!="porter":return false
 event.station_outcome="in_progress";event.station_report_id="transport-isolation-report:%d"%owner.app.rules.actual_attempt
 owner.data.staff_targets.head_nurse="transport_verification"
 stage(event,"station_route")
 return true

func transfer_station_contact() -> bool:
 for id in ["head_nurse","porter","transport_patient"]:
  if not owner.present(id) or str(owner.actor(id).room)!="corridor":return false
 var at:Vector2=owner.position("head_nurse")
 if at.distance_to(target_point("corridor",0))>0.65:return false
 for id in ["porter","transport_patient"]:
  if at.distance_to(owner.position(id))>0.65 or not owner.layout_for("corridor").clear_segment(at,owner.position(id)):return false
 return true

func finish_transfer_station(outcome:String) -> void:
 var event:Dictionary=state().transfer
 event.station_outcome=outcome
 if owner.data.staff_targets.get("head_nurse","")=="transport_verification":owner.data.staff_targets.erase("head_nurse")
 # The already verified original transport instruction remains valid. A
 # partially received paper stays with its actual holder; no remote return.
 owner.claim("transfer_station_end","asylum_optional_station_ended",{"outcome":outcome,"original_order_holder":event.order,"isolation_signed":event.isolation_authorized})
 stage(event,"push")

func advance_transfer_station(delta:float) -> void:
 var event:Dictionary=state().transfer
 event.station_elapsed=float(event.get("station_elapsed",0))+delta
 if not owner.present("head_nurse") or str(owner.actor("head_nurse").room)!="corridor" or owner.data.staff_targets.get("head_nurse","")!="transport_verification":finish_transfer_station("staff_unavailable");return
 if str(owner.actor("porter").room)!="corridor" or str(owner.actor("transport_patient").room)!="corridor":finish_transfer_station("pair_left_station");return
 if float(event.station_elapsed)>timing("optional_station_detour_limit"):finish_transfer_station("detour_timeout");return
 if event.phase=="station_route":
  var bed_ready:bool=pair_move(corridor_rule_point("transfer_station_bed"),delta)
  var nurse_ready:bool=bed_move("head_nurse",corridor_rule_point("transfer_station_nurse"),delta,["head_nurse"])
  if bed_ready and nurse_ready and transfer_station_contact():
   var resume:String=str(event.get("station_resume_phase","station_handoff"))
   event.erase("station_resume_phase");stage(event,resume)
  return
 if not transfer_station_contact():event.station_resume_phase=event.phase;stage(event,"station_route");return
 match str(event.phase):
  "station_handoff":
   if event.order!="porter":finish_transfer_station("original_order_unavailable");return
   if elapsed(event,delta,timing("report_handoff")):
    event.order="head_nurse"
    var report:Dictionary={"id":str(event.station_report_id),"event":"transport","source":"porter_transfer_order","target":"transport_patient","attempt":owner.app.rules.actual_attempt,"written":false,"received":true,"permit_given":false,"ordinary_taken":false,"ordinary_outcome":"","isolation_order":"","isolation_signed":false,"isolation_taken":false,"last_room":"corridor","last_pos":xy(owner.position("transport_patient")),"station_pos":xy(target_point("corridor",0)),"head_nurse_witnessed":false,"head_nurse_verified":false,"actual_delivery_actor":"porter","delivery_outcome":"","original_order_holder":"head_nurse","patient_number":null}
    state().reports.append(report)
    owner.claim("transfer_order_to_nurse","asylum_transfer_order_physically_received",{"holder":"head_nurse","target":"transport_patient","room":"corridor"})
    stage(event,"station_verify")
  "station_verify":
   if event.order!="head_nurse" or owner.app.rules.owners.get("asylum_transport_band","")!="transport_patient":finish_transfer_station("wrist_check_unavailable");return
   if elapsed(event,delta,timing("transfer_check")):
    var report:Dictionary=report_for_id(str(event.station_report_id))
    if report.is_empty():finish_transfer_station("report_unavailable");return
    report.head_nurse_verified=true
    owner.claim("transfer_nurse_verified","asylum_transfer_verified_at_station",{"patient":"transport_patient","visible_number":null,"protagonist_number_known":false})
    stage(event,"station_write")
  "station_write":
   if event.order!="head_nurse":finish_transfer_station("original_order_unavailable");return
   if elapsed(event,delta,timing("report_write")):
    var report:Dictionary=report_for_id(str(event.station_report_id))
    if report.is_empty() or not report.head_nurse_verified:finish_transfer_station("unverified_subject");return
    report.written=true
    owner.record("prepared:"+str(report.id),"护士长在护士站实际接收第三关转运单、核对同一患者及腕带后填写独立隔离处置联；尚未签发不构成隔离授权。")
    owner.claim("transfer_isolation_written","asylum_transfer_isolation_prepared",{"report":report.id,"signed":false})
    stage(event,"station_sign")
  "station_sign":
   if elapsed(event,delta,timing("isolation_sign")):
    var report:Dictionary=report_for_id(str(event.station_report_id))
    if report.is_empty() or not report.written or not report.head_nurse_verified:finish_transfer_station("unverified_subject");return
    report.isolation_order="isolate:"+str(report.id);report.isolation_signed=true;event.isolation_authorized=true
    owner.record(str(report.id),"护士长现场核单核腕带、实际填写并签发的独立隔离处置联；原转运单本身不授权关押，须原搬运实际送达后再交接隔离。")
    owner.claim("transfer_isolation_signed","asylum_isolation_authorization_signed",{"report":report.id,"order":report.isolation_order,"target":"transport_patient","issuer":"head_nurse","source":"actual_station_check"})
    stage(event,"station_return")
  "station_return":
   if elapsed(event,delta,timing("report_handoff")):
    event.order="porter"
    var report:Dictionary=report_for_id(str(event.station_report_id))
    if not report.is_empty():report.original_order_holder="porter"
    owner.claim("transfer_order_to_porter","asylum_transfer_order_returned",{"holder":"porter","room":"corridor"})
    finish_transfer_station("signed_and_returned")

func pair_move(to:Vector2,delta:float) -> bool:
 if str(owner.actor("porter").room)!=str(owner.actor("transport_patient").room):return false
 # Both original actors move through the same collision-checked path; a bed
 # marker follows the patient. No follower is snapped to the leading actor.
 var gap:float=owner.position("porter").distance_to(owner.position("transport_patient"))
 var reached:bool=false
 if gap<=0.7:reached=bed_move("transport_patient",to,delta)
 var porter_done:bool=bed_move("porter",owner.position("transport_patient"),delta)
 return reached and porter_done

func dynamic_bed_obstacles(room:String,exempt:Array=[],ignore_hero:bool=false) -> Array[Vector2]:
 var obstacles:Array[Vector2]=[]
 if owner.app.room_id==room and not ignore_hero:obstacles.append(owner.app.hero_pos)
 for id in owner.data.actors:
  if str(id) in exempt:continue
  if owner.present(str(id)) and str(owner.actor(str(id)).room)==room:obstacles.append(owner.position(str(id)))
 return obstacles

func blocked_bed_step(from:Vector2,to:Vector2,obstacles:Array[Vector2]) -> bool:
 for obstacle in obstacles:
  var before:float=from.distance_to(obstacle)
  var after:float=to.distance_to(obstacle)
  var closest:float=Geometry2D.get_closest_point_to_segment(obstacle,from,to).distance_to(obstacle)
  # Already touching objects may move apart. New motion cannot cross a body.
  if closest<0.42 and (before>=0.42 or closest<before-0.000001 or after<=before+0.000001):return true
 return false

func bed_move(id:String,to:Vector2,delta:float,exempt:Array=["porter","transport_patient"],ignore_hero:bool=false) -> bool:
 var room:String=str(owner.actor(id).room)
 var floor_layout=owner.layout_for(room)
 var from:Vector2=owner.position(id)
 if from.distance_to(to)<0.035:return true
 var obstacles:Array[Vector2]=dynamic_bed_obstacles(room,exempt,ignore_hero)
 var route:PackedVector2Array=PackedVector2Array()
 for p in owner.actor(id).route:route.append(point(p))
 if route.is_empty() or route[-1].distance_to(to)>0.08:route=floor_layout.path(from,to)
 if route.is_empty():return false
 var amount:float=float(owner.config.test_parameters.walk_speed)*delta
 var proposed:Dictionary=floor_layout.move_path(from,route,amount)
 if blocked_bed_step(from,proposed.position,obstacles):
  if floor_layout.geometry_version>=2:
   var bodies:Array=[]
   for obstacle in obstacles:bodies.append({"pos":obstacle,"radius":.42})
   route=floor_layout.path_around_bodies(from,to,bodies)
   if route.is_empty():return false
   proposed=floor_layout.move_path(from,route,amount)
   if blocked_bed_step(from,proposed.position,obstacles):return false
   owner.actor(id).route=Array(route).map(func(p):return xy(p))
   return owner.move(id,to,delta)
  # Temporarily mark occupied grid cells for this route computation only.
  # Restore every previous cell immediately; the room's furniture, graph and
  # other actors' paths are not changed, and no actor is teleported aside.
  var changed:Array=[]
  var region:Rect2i=floor_layout.grid.region
  for y in range(region.position.y,region.end.y):
   for x in range(region.position.x,region.end.x):
    var cell:Vector2i=Vector2i(x,y)
    var at:Vector2=Vector2(x,y)*float(floor_layout.CELL)
    if at.distance_to(from)<0.18:continue
    var occupied:bool=false
    for obstacle in obstacles:
     if at.distance_to(obstacle)<0.45:occupied=true;break
    if occupied and not floor_layout.grid.is_point_solid(cell):
     changed.append(cell);floor_layout.grid.set_point_solid(cell,true)
  var end_cell:Vector2i=Vector2i((to/float(floor_layout.CELL)+Vector2.ONE*0.0001).round())
  route=PackedVector2Array() if floor_layout.grid.is_point_solid(end_cell) else floor_layout.path(from,to)
  for cell in changed:floor_layout.grid.set_point_solid(cell,false)
  if route.is_empty():return false
  proposed=floor_layout.move_path(from,route,amount)
  if blocked_bed_step(from,proposed.position,obstacles):return false
 owner.actor(id).route=Array(route).map(func(p):return xy(p))
 return owner.move(id,to,delta)

func pair_travel(to:String,delta:float) -> bool:
 var room:String=str(owner.actor("transport_patient").room)
 if room==to:return true
 var next:String=owner.app.session.next_room(room,to)
 if next.is_empty() or next in ["stairs","lobby"]:return false
 if owner.isolation!=null and not owner.isolation.can_exit(room,next):return false
 var doorway:Vector2=owner.portal_for(room,next).threshold
 if not pair_move(doorway,delta):return false
 var arrival:Vector2=owner.portal_for(next,room).landing
 for id in ["porter","transport_patient"]:
  owner.actor(id).room=next;owner.actor(id).pos=xy(arrival);owner.actor(id).route=[]
 owner.claim("bed_room:"+next,"asylum_bed_crossed_door",{"from":room,"to":next})
 return next==to

func take_band() -> bool:
 var event:Dictionary=state().transfer
 if event.band_drop.is_empty() or owner.app.rules.owners.get("asylum_transport_band","")!="ward_floor":return false
 if owner.app.room_id!=str(event.band_drop.room) or owner.app.rules.body_busy() or owner.app.rules.gripped:return false
 var at:Vector2=point(event.band_drop.pos)
 if owner.app.hero_pos.distance_to(at)>float(config.rules.pickup_distance) or not owner.app.layout.clear_segment(owner.app.hero_pos,at):return false
 owner.app.rules.owners.asylum_transport_band="hero"
 owner.claim("transport_band_taken","asylum_item_taken",{"item":"asylum_transport_band","number":null})
 return true

func read_band(delta:float) -> bool:
 var event:Dictionary=state().transfer
 if event.band_drop.is_empty() or event.band_drop.read:return false
 if owner.app.rules.body_busy() or owner.app.rules.gripped:return false
 var holder:String=str(owner.app.rules.owners.get("asylum_transport_band",""))
 if holder!="hero":
  if holder!="ward_floor" or owner.app.room_id!=str(event.band_drop.room):return false
  var at:Vector2=point(event.band_drop.pos)
  if owner.app.hero_pos.distance_to(at)>float(config.rules.pickup_distance) or not owner.app.layout.clear_segment(owner.app.hero_pos,at):return false
 event.band_drop.read_elapsed=float(event.band_drop.read_elapsed)+delta
 if float(event.band_drop.read_elapsed)+0.000001<timing("item_read"):return false
 event.band_drop.read=true
 owner.observe("asylum_transport_band_seen","实际拿近查看第三关推床患者脱落的腕带；具体编号字形尚未提供，不解锁同号关联。")
 owner.claim("transport_band_read","asylum_item_read",{"item":"asylum_transport_band","number":null})
 return true

func private_with_postop() -> bool:
 if not hero_sees("postop_patient",1.2):return false
 for id in owner.data.actors:
  if str(id)=="postop_patient":continue
  if visible(str(id),owner.position("postop_patient"),"activity",2.0):return false
 return true

func advance_postop(delta:float) -> void:
 var event:Dictionary=state().postop
 if not owner.present("postop_patient"):return
 if not owner.present("informer"):event.informer_phase="absent"
 # The informant has to enter or turn around a real obstruction while the
 # wound is still exposed. A shared spawn never retroactively witnesses it.
 if event.informer_phase=="privacy_walk":
  if owner.travel("informer","corridor",delta):
   event.informer_phase="wait_outside";event.informer_elapsed=0.0
 elif event.informer_phase=="wait_outside":
  event.informer_elapsed=float(event.informer_elapsed)+delta
  if event.wound_visible or float(event.informer_elapsed)>=timing("informer_wait"):
   event.informer_phase="look_inside"
 elif event.informer_phase=="look_inside":
  if owner.travel("informer","activity",delta):
   var target:Vector2=owner.position("postop_patient")
   if visible("informer",target,"activity",2.0):
    if event.wound_visible:
     event.informer_saw_wound=true;event.last_room="activity";event.last_pos=xy(target)
     owner.claim("wound_informer_seen","asylum_wound_witness",{"observer":"informer","target":"postop_patient","while_exposed":true})
     event.informer_phase="report_route"
    elif event.phase=="idle":event.informer_phase="privacy_walk"
   else:owner.move("informer",target,delta)
 if event.informer_phase=="report_route":
  if owner.travel("informer","corridor",delta):event.informer_phase="at_station"
 if event.phase=="done":return
 if str(owner.actor("postop_patient").room)!="activity":
  event.wound_visible=false;stage(event,"done");return
 if event.phase=="idle":
  if not private_with_postop() or owner.app.has_key() or owner.app.rules.sp<50 or owner.app.rules.body_busy() or owner.app.rules.gripped or owner.app.rules.control_left>0:return
  stage(event,"prepare");local_say("POSTOP_INVITE",["postop_patient"])
  return
 if event.phase=="prepare":
  if not private_with_postop():stage(event,"idle");return
  if elapsed(event,delta,timing("wound_prepare")):
   event.wound_visible=true;stage(event,"expose")
   owner.claim("postop_wound_exposed","asylum_wound_exposed",{"patient":"postop_patient","alive":true})
 if event.phase=="expose":
  if hero_sees("postop_patient",2.0) and not event.hero_saw_wound:
   event.hero_saw_wound=true
   owner.observe("asylum_postop_wound_seen","实际看清仍存活术后病友掀衣露出的未愈合伤口；不凭敷料推断手术项目，不附加精神损失。")
  if elapsed(event,delta,timing("wound_exposure")):
   event.wound_visible=false;stage(event,"done")
   owner.claim("postop_wound_covered","asylum_wound_covered")
   if event.hero_saw_wound and hero_sees("postop_patient",2.0):local_say("POSTOP_WOUND",["postop_patient"])

func report_for_id(id:String) -> Dictionary:
 for report in state().reports:
  if str(report.id)==id:return report
 return {}

func advance_chief_internal(delta:float) -> void:
 var event:Dictionary=state().chief_internal
 if event.phase=="done":return
 if not owner.present("head_nurse"):
  if owner.data.staff_targets.get("head_nurse","")=="hero_report":owner.data.staff_targets.erase("head_nurse")
  if event.phase!="idle":stage(event,"done")
  return
 var internal_search:bool=owner.app.room_id=="corridor" and owner.app.rules.search_active and owner.app.target_index==0
 if event.phase=="idle":
  # Public duty-board observation, merely walking past, and an unread report
  # object in the room are not the internal-folder search being sanctioned.
  if not internal_search or not owner.near("head_nurse",2.0) or owner.data.staff_targets.has("head_nurse"):return
  owner.data.staff_targets.head_nurse="hero_report"
  event.last_room="corridor";event.last_pos=xy(owner.app.hero_pos)
  stage(event,"approach")
 if owner.near("head_nurse",2.0):event.last_room=owner.app.room_id;event.last_pos=xy(owner.app.hero_pos)
 if event.phase=="approach":
  if not internal_search or not owner.near("head_nurse",2.0):
   owner.data.staff_targets.erase("head_nurse");stage(event,"idle");return
  if not owner.near("head_nurse",0.55):owner.move("head_nurse",owner.app.hero_pos,delta);return
  owner.claim("chief_internal_seen","asylum_internal_search_seen",{"target":"hero","source":"actual_corridor_internal_folder_search"})
  if not owner.app.rules.owners.has("asylum_internal_report"):owner.app.rules.owners.asylum_internal_report="station"
  event.folder_closed=owner.app.rules.owners.asylum_internal_report!="hero"
  owner.claim("chief_folder_stop","asylum_folder_stop",{"closed":event.folder_closed,"file_holder":owner.app.rules.owners.asylum_internal_report,"key_taken":false})
  stage(event,"return_station");local_say("CHIEF_INTERNAL",["head_nurse"])
  return
 if event.phase=="return_station":
  if bed_move("head_nurse",corridor_rule_point("chief_station_side"),delta,["head_nurse"]):stage(event,"write")
 elif event.phase=="write":
  if str(owner.actor("head_nurse").room)!="corridor":return
  if not bed_move("head_nurse",corridor_rule_point("chief_station_side"),delta,["head_nurse"]):return
  if not elapsed(event,delta,timing("report_write")):return
  event.report_id="hero-internal-report:%d"%owner.app.rules.actual_attempt
  var report:Dictionary={"id":event.report_id,"event":"hero_internal_search","source":"chief_internal_witness","target":"hero","attempt":owner.app.rules.actual_attempt,"written":true,"received":true,"permit_given":false,"ordinary_taken":false,"ordinary_outcome":"","isolation_order":"","isolation_signed":false,"isolation_taken":false,"last_room":event.last_room,"last_pos":event.last_pos.duplicate(),"station_pos":xy(target_point("corridor",0)),"head_nurse_witnessed":true}
  state().reports.append(report)
  owner.record(str(report.id),"护士长实际看见角色翻查护士站内部报告后，接近制止并实际填写本次处理报告；普通经过或读取公开值班表不记为此事。")
  owner.claim("chief_internal_report_written","asylum_report_written",{"report":report.id,"target":"hero","actual_search":true})
  stage(event,"sign")
 elif event.phase=="sign":
  if str(owner.actor("head_nurse").room)!="corridor" or not bed_move("head_nurse",corridor_rule_point("chief_station_side"),delta,["head_nurse"]):return
  if not elapsed(event,delta,timing("isolation_sign")):return
  var report:Dictionary=report_for_id(str(event.report_id))
  if report.is_empty():return
  report.isolation_order="isolate:"+str(report.id);report.isolation_signed=true
  owner.claim("hero_isolation_signed","asylum_isolation_authorization_signed",{"order":report.isolation_order,"report":report.id,"issuer":"head_nurse","target":"hero"})
  owner.data.staff_targets.erase("head_nurse");stage(event,"done")

func ordinary_target_room(target:String) -> String:
 return owner.app.room_id if target=="hero" else str(owner.actor(target).get("room",""))

func ordinary_target_position(target:String) -> Vector2:
 return owner.app.hero_pos if target=="hero" else owner.position(target)

func ordinary_sees(target:String,distance:float=2.0) -> bool:
 if target=="hero":return owner.near("ordinary_orderly",distance)
 return owner.present(target) and visible("ordinary_orderly",owner.position(target),str(owner.actor(target).room),distance)

func station_handoff_stop(report:Dictionary) -> Vector2:
 var station:Vector2=point(report.station_pos)
 var floor_layout=owner.layout_for("corridor")
 var obstacles:Array[Vector2]=dynamic_bed_obstacles("corridor",["ordinary_orderly"])
 for offset in [Vector2(0.45,0),Vector2(0,0.45),Vector2(-0.45,0),Vector2(0,-0.45)]:
  var at:Vector2=station+offset
  if not floor_layout.walkable(at) or not floor_layout.clear_segment(at,station):continue
  var free:bool=true
  for occupied in obstacles:
   if at.distance_to(occupied)<0.42:free=false;break
  if free:return at
 return Vector2.INF

func advance_postop_report(delta:float) -> void:
 var event:Dictionary=state().postop
 if not event.informer_saw_wound or event.report_phase=="done" or not owner.present("informer"):return
 if event.informer_phase not in ["at_station","permit_walk","done"]:return
 if str(owner.actor("informer").room)!="corridor":return
 if event.report_phase=="idle":
  if not owner.present("head_nurse") or str(owner.actor("head_nurse").room)!="corridor":
   owner.move("informer",target_point("corridor",0),delta);return
  if owner.data.get("body",{}).get("actor","")=="head_nurse":return
  if owner.data.staff_targets.has("head_nurse"):return
  if owner.position("informer").distance_to(owner.position("head_nurse"))>0.5:
   owner.move("informer",owner.position("head_nurse"),delta);return
  if not owner.layout_for("corridor").clear_segment(owner.position("informer"),owner.position("head_nurse")):return
  owner.data.staff_targets.head_nurse="postop_report"
  event.report_phase="receive";event.report_elapsed=0.0
  local_say("INFORMER_REPORT",["informer","head_nurse"])
  return
 if event.report_phase in ["receive","write","sign","permit"]:
  if not owner.present("head_nurse") or str(owner.actor("head_nurse").room)!="corridor":return
  if owner.position("informer").distance_to(owner.position("head_nurse"))>0.65:
   owner.move("informer",owner.position("head_nurse"),delta);return
  event.report_elapsed=float(event.report_elapsed)+delta
 if event.report_phase=="receive" and float(event.report_elapsed)>=timing("report_handoff"):
  event.report_id="postop-report:%d"%owner.app.rules.actual_attempt
  var report:Dictionary={"id":event.report_id,"event":"postop_wound","source":"informer_testimony","target":"postop_patient","attempt":owner.app.rules.actual_attempt,"written":false,"received":true,"permit_given":false,"ordinary_taken":false,"ordinary_outcome":"","isolation_order":"","isolation_signed":false,"isolation_taken":false,"last_room":event.last_room,"last_pos":event.last_pos.duplicate(),"station_pos":xy(target_point("corridor",0)),"testimony":"他把伤口给别人看了。","head_nurse_witnessed":false}
  state().reports.append(report)
  owner.claim("postop_report_received","asylum_testimony_received",{"report":event.report_id,"target":"postop_patient","head_nurse_witnessed":false})
  event.report_phase="write";event.report_elapsed=0.0
 elif event.report_phase=="write" and float(event.report_elapsed)>=timing("report_write"):
  var report:Dictionary=report_for_id(str(event.report_id))
  if report.is_empty():return
  report.written=true
  owner.record(str(report.id),"告密病友举报术后病友展示伤口；护士长实际接收后填写处理报告。举报措辞与真实展示、护士长是否亲见分别保存。")
  owner.claim("postop_report_written","asylum_report_written",{"report":report.id,"target":report.target})
  event.report_phase="sign";event.report_elapsed=0.0
 elif event.report_phase=="sign" and float(event.report_elapsed)>=timing("isolation_sign"):
  var report:Dictionary=report_for_id(str(event.report_id))
  if report.is_empty():return
  report.isolation_order="isolate:"+str(report.id);report.isolation_signed=true
  owner.claim("postop_isolation_signed","asylum_isolation_authorization_signed",{"order":report.isolation_order,"report":report.id,"issuer":"head_nurse","target":report.target})
  event.report_phase="permit";event.report_elapsed=0.0
  local_say("INFORMER_PERMIT",["head_nurse","informer"])
 elif event.report_phase=="permit" and float(event.report_elapsed)>=timing("report_handoff"):
  var report:Dictionary=report_for_id(str(event.report_id))
  if report.is_empty():return
  report.permit_given=true
  owner.app.rules.owners["asylum_informer_permit:%d"%owner.app.rules.actual_attempt]="informer"
  owner.claim("informer_permit_given","asylum_permit_given",{"recipient":"informer","key":false,"resources":0})
  owner.data.staff_targets.erase("head_nurse")
  event.report_phase="permit_walk";event.informer_phase="permit_walk"
 if event.report_phase=="permit_walk":
  if owner.move("informer",target_point("corridor",2),delta):
   event.report_phase="done";event.informer_phase="done"
   owner.claim("informer_left_activity","asylum_informer_leave_completed",{"room":"corridor","vanished":false})

func advance_ordinary_report(delta:float) -> void:
 var job:Dictionary=state().ordinary_job
 if not owner.present("ordinary_orderly"):
  if job.phase!="idle":finish_ordinary("staff_left")
  return
 if job.phase=="idle" and not job.get("retreat_pos",[]).is_empty() and not owner.data.staff_targets.has("ordinary_orderly"):
  if str(owner.actor("ordinary_orderly").room)!=str(job.get("retreat_room","")) or bed_move("ordinary_orderly",point(job.retreat_pos),delta,["ordinary_orderly"]):job.retreat_pos=[]
  return
 if job.phase=="idle":
  if owner.data.staff_targets.has("ordinary_orderly") or owner.data.get("body",{}).get("actor","")=="ordinary_orderly" or not str(owner.data.get("holder","")).is_empty():return
  for report in state().reports:
   if str(report.get("event",""))=="transport":continue
   if int(report.attempt)!=owner.app.rules.actual_attempt or not report.written or report.ordinary_taken or not str(report.ordinary_outcome).is_empty():continue
   job.report_id=report.id;job.target=report.target;stage(job,"fetch")
   owner.data.staff_targets.ordinary_orderly="report_fetch"
   break
  if job.phase=="idle":return
 var report:Dictionary=report_for_id(str(job.report_id))
 if report.is_empty() or int(report.attempt)!=owner.app.rules.actual_attempt:finish_ordinary("cancelled");return
 var target:String=str(job.target)
 if job.phase=="fetch":
  if not owner.travel("ordinary_orderly","corridor",delta):return
  var stop:Vector2=station_handoff_stop(report)
  if stop==Vector2.INF:return
  if bed_move("ordinary_orderly",stop,delta,["ordinary_orderly"]):stage(job,"receive")
 elif job.phase=="receive":
  if str(owner.actor("ordinary_orderly").room)!="corridor" or owner.position("ordinary_orderly").distance_to(point(report.station_pos))>0.55 or not owner.layout_for("corridor").clear_segment(owner.position("ordinary_orderly"),point(report.station_pos)):
   stage(job,"fetch");return
  if elapsed(job,delta,timing("report_handoff")):
   report.ordinary_taken=true;owner.data.staff_targets.ordinary_orderly=target
   owner.claim("ordinary_report_taken:"+str(report.id),"asylum_ordinary_report_taken",{"report":report.id,"target":target})
   stage(job,"locate")
   if report.get("source","")=="chief_internal_witness":local_say("CHIEF_REPORT",["head_nurse","ordinary_orderly"])
 elif job.phase=="locate":
  if not owner.travel("ordinary_orderly",str(report.last_room),delta):return
  if (target!="hero" and not owner.present(target)) or ordinary_target_room(target)!=str(report.last_room):
   if owner.move("ordinary_orderly",point(report.last_pos),delta):finish_ordinary("not_found")
   return
  if not ordinary_sees(target):
   if owner.move("ordinary_orderly",point(report.last_pos),delta):finish_ordinary("not_found")
   return
  report.last_pos=xy(ordinary_target_position(target))
  if owner.position("ordinary_orderly").distance_to(ordinary_target_position(target))>0.55:
   owner.move("ordinary_orderly",ordinary_target_position(target),delta);return
  if target=="hero" and not owner.can_begin_grip():return
  stage(job,"reach")
  job.evaded=false;job.grab_invalidated=false
  if target=="hero":local_say("ORDINARY_HERO",["ordinary_orderly"])
  else:local_say("POSTOP_REMOVE",["ordinary_orderly",target])
 elif job.phase=="reach":
  if target=="hero" and (not str(owner.data.holder).is_empty() or owner.app.rules.body_busy()):job.grab_invalidated=true
  if not elapsed(job,delta,timing("npc_grab_prepare")):return
  if job.get("evaded",false) or job.get("grab_invalidated",false) or not ordinary_sees(target,0.65):finish_ordinary("missed");return
  if target=="hero":
   if not owner.can_begin_grip():finish_ordinary("missed");return
   if owner.app.has_method("cancel_asylum_read"):owner.app.cancel_asylum_read()
   if not owner.data.body.is_empty():owner.clear_body()
   owner.data.holder="ordinary_orderly";owner.app.rules.gripped=true
   owner.set_body("ward_ordinary_hero_drag","ordinary_orderly")
   job.holding=true;job.drag_elapsed=0.0
   owner.claim("ordinary_hero_grip","asylum_hero_gripped",{"actor":"ordinary_orderly","target":"hero"})
   owner.damage("ordinary_hero_twist",int(config.rules.ordinary_hero_hp),int(config.rules.ordinary_hero_sp))
   if owner.app.rules.hp<=0:finish_ordinary("death");return
   local_say("ORDINARY_HURT",["ordinary_orderly"])
  else:
   job.holding=true;job.full_witness=hero_sees("ordinary_orderly",2.4) and hero_sees(target,2.4)
   state().postop.wound_visible=false;stage(state().postop,"done")
   owner.claim("ordinary_postop_grip","asylum_npc_gripped",{"actor":"ordinary_orderly","target":target,"hero_damage":0})
  stage(job,"drag")
 elif job.phase=="drag":
  if target=="hero":
   job.drag_elapsed=float(job.get("drag_elapsed",0))+delta
   if str(owner.data.holder)!="ordinary_orderly" or str(owner.actor("ordinary_orderly").room)!=owner.app.room_id:finish_ordinary("cancelled");return
   if float(job.drag_elapsed)>=float(config.rules.ordinary_hero_drag_max):finish_ordinary("timeout");return
   if hero_pair_move(corridor_rule_point("station_side"),delta):finish_ordinary("delivered")
   return
  if job.full_witness and (not hero_sees("ordinary_orderly",2.4) or not hero_sees(target,2.4)):job.full_witness=false
  if npc_pair_travel("ordinary_orderly",target,"quiet",delta):stage(job,"park")
 elif job.phase=="park":
  if npc_pair_move("ordinary_orderly",target,owner.space_point("quiet","ordinary_patient_stop",Vector2(2.8,1.6)),delta):
   var witnessed:bool=job.full_witness
   finish_ordinary("delivered")
   if witnessed and hero_sees(target,2.4):local_say("POSTOP_WITNESS",[target])

func hero_pair_move(to:Vector2,delta:float) -> bool:
 var staff:String="ordinary_orderly"
 if str(owner.actor(staff).room)!=owner.app.room_id:return false
 var staff_done:bool=false
 if owner.position(staff).distance_to(owner.app.hero_pos)<=0.7:staff_done=bed_move(staff,to,delta,[staff],true)
 var at:Vector2=owner.position(staff)
 if owner.app.hero_pos.distance_to(at)<0.035:return staff_done
 var path:PackedVector2Array=owner.app.layout.path(owner.app.hero_pos,at)
 if path.is_empty():return false
 var moved:Dictionary=owner.app.layout.move_path(owner.app.hero_pos,path,float(owner.config.test_parameters.walk_speed)*delta)
 var obstacles:Array[Vector2]=dynamic_bed_obstacles(owner.app.room_id,[staff],true)
 if blocked_bed_step(owner.app.hero_pos,moved.position,obstacles):return false
 owner.app.hero_pos=moved.position;owner.app.hero_state="grab"
 return staff_done and owner.app.hero_pos.distance_to(at)<0.035

func npc_pair_move(staff:String,target:String,to:Vector2,delta:float) -> bool:
 if not owner.present(staff) or not owner.present(target) or str(owner.actor(staff).room)!=str(owner.actor(target).room):return false
 var reached:bool=false
 var exempt:Array=[staff,target]
 if owner.position(staff).distance_to(owner.position(target))<=0.7:reached=bed_move(target,to,delta,exempt)
 var staff_done:bool=bed_move(staff,owner.position(target),delta,exempt)
 return reached and staff_done

func npc_pair_travel(staff:String,target:String,to:String,delta:float) -> bool:
 var room:String=str(owner.actor(staff).room)
 if room==to:return true
 var next:String=owner.app.session.next_room(room,to)
 if next.is_empty() or next=="cortex_exit":return false
 if owner.isolation!=null and not owner.isolation.can_exit(room,next):return false
 if not npc_pair_move(staff,target,owner.portal_for(room,next).threshold,delta):return false
 var arrival:Vector2=owner.portal_for(next,room).landing
 for id in [staff,target]:
  owner.actor(id).room=next;owner.actor(id).pos=xy(arrival);owner.actor(id).route=[]
 return next==to

func finish_ordinary(outcome:String) -> void:
 var job:Dictionary=state().ordinary_job
 var report:Dictionary=report_for_id(str(job.report_id))
 if not report.is_empty():
  report.ordinary_outcome=outcome
  if outcome=="delivered":
   report.last_room=ordinary_target_room(str(job.target));report.last_pos=xy(ordinary_target_position(str(job.target)))
  owner.claim("ordinary_report_result:"+str(report.id),"asylum_ordinary_disposition_ended",{"report":report.id,"target":report.target,"outcome":outcome,"isolated":false})
 if str(job.get("target",""))=="hero":
  if str(owner.data.get("holder",""))=="ordinary_orderly":owner.data.holder="";owner.app.rules.gripped=false;owner.data.regrab_elapsed=0.0
  if owner.data.get("body",{}).get("kind","")=="ward_ordinary_hero_drag":owner.clear_body()
  if job.holding:
   var retreat:Vector2=corridor_rule_point("station_side")+Vector2(0.55,0)
   if owner.layout_for(str(owner.actor("ordinary_orderly").room)).walkable(retreat):job.retreat_pos=xy(retreat);job.retreat_room=str(owner.actor("ordinary_orderly").room)
 job.holding=false;stage(job,"idle");job.report_id="";job.target=""
 owner.data.staff_targets.erase("ordinary_orderly")

func pending_isolation_orders() -> Array:
 var result:Array=[]
 for report in state().reports:
  var delivered:bool=str(report.get("ordinary_outcome",""))=="delivered"
  if str(report.get("event",""))=="transport":delivered=state().transfer.delivered and str(report.get("actual_delivery_actor",""))=="porter" and str(report.get("delivery_outcome",""))=="delivered"
  if int(report.attempt)==owner.app.rules.actual_attempt and report.isolation_signed and not report.isolation_taken and delivered:result.append(report)
 return result

func take_isolation_order(id:String) -> bool:
 var report:Dictionary=report_for_id(id)
 if report.is_empty() or not report in pending_isolation_orders():return false
 if not owner.present("isolation_orderly") or str(owner.actor("isolation_orderly").room)!="corridor":return false
 if owner.position("isolation_orderly").distance_to(point(report.station_pos))>0.5:return false
 report.isolation_taken=true
 return owner.claim("isolation_order_taken:"+id,"asylum_isolation_authorization_taken",{"report":id,"order":report.isolation_order,"target":report.target})

func on_skill(result:Dictionary) -> void:
 if not result.get("success",false):return
 var event:Dictionary=state().clamp
 if event.phase=="windup" and str(result.get("id","")) in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:
  event.retract_left=timing("hand_retract")
 var job:Dictionary=state().ordinary_job
 if job.phase=="reach" and job.target=="hero" and str(result.get("id",""))=="WITHDRAW":job.evaded=true
 # Skills affect the protagonist. They never erase another patient's memory,
 # pause unrelated folding, or remotely stop a recorder or moving bed.

func kick_contact() -> void:
 pass

func on_search_complete(index:int,found_key:bool) -> void:
 if found_key:return
 # The map's completion feedback owns the 45 original search lines. This
 # module only commits additional physical observations when actually made.
 if owner.app.room_id=="workshop" and index==5:
  var work:Dictionary=state().work
  owner.observe("asylum_display_label_back_seen","实际扶稳作品展示板并检查背面的运输标签；具体批次字形尚未提供。")
  if work.batch!=null and owner.app.rules.known.has("cold_box_batch:"+str(work.batch)):
   owner.observe("asylum_work_batch_matched","实际读清本关标签与前关冷藏箱同一运输批次；不把批次等同患者编号。")
   local_say("LABOR_MATCH",["labor_patient"])

func markers() -> Array:
 var value:Dictionary=state();var result:Array=[]
 var transfer:Dictionary=value.transfer
 if owner.present("transport_patient"):
  result.append({"id":"asylum_transport_bed","room":owner.actor("transport_patient").room,"pos":xy(owner.position("transport_patient")),"kind":"transport_bed","label":"转运床 · 活人"})
 if not transfer.band_drop.is_empty() and owner.app.rules.owners.get("asylum_transport_band","")=="ward_floor":
  result.append({"id":"asylum_transport_band","room":transfer.band_drop.room,"pos":transfer.band_drop.pos,"kind":"band","label":"脱落腕带 · 编号未定"})
 var work:Dictionary=value.work
 if work.box!="none":
  var at:Vector2=owner.position("labor_patient") if work.paper=="labor_patient" and owner.present("labor_patient") else target_point("workshop",1)
  result.append({"id":"asylum_work_box","room":"workshop","pos":xy(at),"kind":"box","label":"纸盒 · "+phase_label(str(work.box))})
 result.append_array(evidence_markers())
 return result

func phase_label(phase:String) -> String:return str(config.phase_labels.get(phase,phase))

func action_label(id:String) -> String:
 var value:Dictionary=state()
 if id=="supervisor":return phase_label(str(value.clamp.phase))
 if id=="labor_patient":return phase_label(str(value.work.phase))
 if id in ["therapist","speaker"]:return phase_label(str(value.therapy.phase))
 if id in ["porter","transport_patient"]:return phase_label(str(value.transfer.phase))
 if id=="postop_patient":return phase_label(str(value.postop.phase))
 if id=="informer":return phase_label(str(value.postop.report_phase if value.postop.informer_phase in ["at_station","permit_walk","done"] else value.postop.informer_phase))
 if id=="head_nurse" and value.postop.report_phase not in ["idle","done"]:return phase_label(str(value.postop.report_phase))
 if id=="head_nurse" and value.chief_internal.phase not in ["idle","done"]:return phase_label(str(value.chief_internal.phase))
 if id=="head_nurse" and str(value.transfer.phase).begins_with("station_"):return phase_label(str(value.transfer.phase))
 if id=="ordinary_orderly" and value.ordinary_job.phase!="idle":return phase_label(str(value.ordinary_job.phase))
 if id=="ordinary_orderly" and not value.ordinary_job.get("retreat_pos",[]).is_empty():return "松手后实际退开"
 return ""
