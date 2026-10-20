extends RefCounted
## Optional, physical reading contacts. No key lookup, rewards or NPC control.
## Hospital owns scheduling and world pause. Primitive state lives in its save.
var _hospital:WeakRef
var owner:
 get:return _hospital.get_ref()
var config:Dictionary={}

func _init(hospital) -> void:
 _hospital=weakref(hospital)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/hospital_observations.json"))

func state() -> Dictionary:
 if owner==null or owner.data.is_empty():return {}
 if not owner.data.has("observation_state"):
  owner.data.observation_state={"active":{},"completed":{},"read":{},"links":{}}
 return owner.data.observation_state

func specification(id:String) -> Dictionary:
 for target in config.get("targets",[]):
  if str(target.id)==id:return target
 return {}

func hospital_ready() -> bool:
 return owner!=null and owner.enabled and not owner.data.is_empty() and owner.app.session.data.level==2

func actor_here(id:String) -> bool:
 return owner.present(id) and str(owner.actor(id).room)==owner.app.room_id

func item_owner(target:Dictionary) -> String:
 return str(owner.app.rules.owners.get(str(target.get("item","")),str(target.get("home_owner",""))))

func target_room(target:Dictionary) -> String:
 var location:String=item_owner(target)
 if location=="hero":return owner.app.room_id
 match str(target.kind):
  "patient_check","sample","photo","patient_order":
   var id:String=str(target.actor)
   return str(owner.actor(id).room) if owner.present(id) else str(target.room)
  "cup":
   if location=="counter":return str(owner.data.get("cup_place",{}).get("room",""))
   if location=="pharmacist" and owner.present("pharmacist"):return str(owner.actor("pharmacist").room)
  "pharmacy_clip":
   if owner.present("pharmacist"):return str(owner.actor("pharmacist").room)
  "visit_record":
   if not owner.data.get("registered",false) and owner.data.get("prescribed",false):return "clinic"
  "archive_report":
   if location in ["archivist","guard"] and owner.present(location):return str(owner.actor(location).room)
 return str(target.room)

func target_position(target:Dictionary) -> Vector2:
 var location:String=item_owner(target)
 if location=="hero":return owner.app.hero_pos
 match str(target.kind):
  "patient_check","sample","photo","patient_order":return owner.position(str(target.actor))
  "cup":
   if location=="counter":
    var at:Array=owner.data.get("cup_place",{}).get("pos",[])
    if at.size()==2:return Vector2(float(at[0]),float(at[1]))
   if location=="pharmacist":return owner.position("pharmacist")
  "pharmacy_clip":return owner.position("pharmacist")
  "archive_report":
   if location in ["archivist","guard"]:return owner.position(location)
 var room_layout=owner.layout_for(target_room(target))
 var index:int=int(target.furniture)
 return room_layout.furniture[index].at if index>=0 and index<room_layout.furniture.size() else Vector2.INF

func available(target:Dictionary) -> bool:
 if not hospital_ready() or target.is_empty():return false
 var location:String=item_owner(target)
 match str(target.kind):
  "bag":return str(owner.data.get("bag",""))=="ward"
  "patient_check":return owner.data.get("nurse_checked",false) and owner.present("nurse")
  "ticket":return location=="hero" and owner.data.get("registered",false)
  "visit_record":return not str(owner.data.get("visit","")).is_empty() and (owner.data.get("registered",false) or owner.data.get("prescribed",false))
  "prescription":return owner.data.get("prescribed",false) and location=="hero"
  "cup":
   if location=="hero":return true
   if location=="counter":return owner.data.get("cup_place",{}).get("pos",[]).size()==2
   return location=="pharmacist" and owner.present("pharmacist")
  "pharmacy_clip":return owner.data.get("dispensed",false) and location=="pharmacist" and owner.present("pharmacist")
  "file":return location==str(target.home_owner) or location=="hero"
  "medicine_record":
   if owner.data.get("swallowed",false) or owner.data.get("refused",false):return true
   return false
  "archive_report":
   var report:Dictionary=owner.data.get("records_state",{}).get("report",{})
   if report.is_empty():return false
   return location=="office:10" or location=="hero" or (location in ["archivist","guard"] and owner.present(location))
  "patient_order":return owner.data.get("wheelchair_order",false) and owner.present("guide")
  "photo":return location=="wheelchair" and owner.present("wheelchair")
  "sample":return owner.data.get("sample",false) and owner.present("doctor") and str(owner.app.rules.owners.get("hospital_sample","doctor"))=="doctor"
 return true

func revision(target:Dictionary) -> String:
 var result:String=str(config.version)
 if str(target.id)=="laundry_stub":result+="/complete" if str(owner.data.get("bag",""))=="removed" else "/pending"
 if str(target.id)=="hospital_medicine_record":
  result+="/"+medicine_record_kind()
 return result

func medicine_record_kind() -> String:
 var visit:String=str(owner.data.get("visit",""))
 for entry in owner.app.rules.institutional_records:
  if str(entry.get("id",""))=="false_medicine:"+visit:return "false_label"
 return "swallowed" if owner.data.get("swallowed",false) else "refused"

func total_duration() -> float:
 var timing:Dictionary=config.timing
 return float(timing.prepare)+float(timing.contact)+float(timing.finish)

func candidate(room:String,furniture_index:int=-1) -> Dictionary:
 if not hospital_ready() or room!=owner.app.room_id:return {}
 var value:Dictionary=state()
 var result:Dictionary={}
 var nearest:float=INF
 for target in config.targets:
  if furniture_index>=0 and int(target.furniture)!=furniture_index:continue
  if not available(target) or target_room(target)!=room:continue
  # A completed five-second search already constitutes a real page read.
  # Offer only genuinely unread pages, plus a changed laundry completion.
  var records_state:Dictionary=owner.data.get("records_state",{})
  if str(target.id) in records_state.get("read",[]):
   if str(target.id)!="laundry_stub" or str(owner.data.get("bag",""))!="removed" or records_state.get("laundry_completed",false):continue
  if str(value.completed.get(str(target.id),""))==revision(target):continue
  var at:Vector2=target_position(target)
  if not at.is_finite():continue
  var distance:float=owner.app.hero_pos.distance_to(at)
  if distance<nearest:
   nearest=distance
   result={"id":str(target.id),"name":str(target.name),"room":room,"pos":at,"source":str(target.source),"duration":total_duration()}
 return result

func body_free(allow_control:bool=false) -> bool:
 var rules=owner.app.rules
 return rules.hp>0 and not rules.loading and not rules.transitioning and not rules.absent and not rules.gripped and not rules.body_busy() and (allow_control or rules.control_left<=0) and not rules.search_active and owner.app.action_phase not in ["return_bed","resting"] and owner.data.get("body",{}).is_empty() and str(owner.data.get("holder","")).is_empty() and float(owner.data.get("medicine_stop",0))<=0

func in_contact(target:Dictionary) -> bool:
 if target_room(target)!=owner.app.room_id:return false
 var at:Vector2=target_position(target)
 return at.is_finite() and owner.app.hero_pos.distance_to(at)<=float(config.contact_distance) and owner.app.layout.clear_segment(owner.app.hero_pos,at)

func begin(id:String,controlled:bool=false) -> bool:
 if not hospital_ready() or not state().active.is_empty() or not body_free(controlled) or not owner.app.dialogue_queue.is_empty():return false
 var target:Dictionary=specification(id)
 if target.is_empty() or not available(target) or not in_contact(target):return false
 if str(state().completed.get(id,""))==revision(target):return false
 var at:Vector2=target_position(target)
 state().active={"id":id,"name":str(target.name),"room":owner.app.room_id,"pos":[at.x,at.y],"elapsed":0.0,"phase":"prepare","phase_progress":0.0,"revision":revision(target)}
 state().active.controlled=controlled
 var origin:String="controlled" if controlled else "autonomous"
 if not owner.app.rules.public_action.is_empty():owner.app.rules.finish_public_action(str(owner.app.rules.public_action.get("origin",origin)))
 owner.app.rules.begin_public_action("observe",id,origin,owner.app.room_id)
 return true

func tick(delta:float) -> void:
 if not hospital_ready():
  cancel();return
 var value:Dictionary=state()
 if value.active.is_empty():return
 if not is_finite(delta) or delta<=0:return
 var active:Dictionary=value.active
 var target:Dictionary=specification(str(active.id))
 if str(active.room)!=owner.app.room_id or not body_free(bool(active.get("controlled",false))) or not available(target) or not in_contact(target) or str(active.revision)!=revision(target) or (active.get("controlled",false) and owner.app.rules.control_left<=0):
  cancel();return
 # Formal dialogue/menu clocks belong to the caller. Injury/grip above wins
 # before its queued line can pause this already-interrupted contact.
 if not owner.app.dialogue_queue.is_empty():return
 owner.app.hero_state="give"
 var elapsed_delta:float=minf(delta,owner.app.rules.control_left) if active.get("controlled",false) else delta
 active.elapsed=float(active.elapsed)+elapsed_delta
 var prepare:float=float(config.timing.prepare)
 var contact:float=float(config.timing.contact)
 var finish:float=float(config.timing.finish)
 if float(active.elapsed)<prepare:
  active.phase="prepare";active.phase_progress=float(active.elapsed)/prepare
 elif float(active.elapsed)<prepare+contact:
  active.phase="contact";active.phase_progress=(float(active.elapsed)-prepare)/contact
 elif float(active.elapsed)<prepare+contact+finish:
  active.phase="finish";active.phase_progress=(float(active.elapsed)-prepare-contact)/finish
 else:complete(target)

func cancel() -> void:
 if owner==null or owner.data.is_empty() or not owner.data.has("observation_state"):return
 var action:Dictionary=owner.app.rules.public_action
 if not state().active.is_empty() and action.get("kind","")=="observe" and action.get("target","")==state().active.id:owner.app.rules.finish_public_action(str(action.get("origin","autonomous")))
 state().active={}

func blocks_hero() -> bool:
 return hospital_ready() and not state().active.is_empty()

func observed_fields(target:Dictionary) -> Dictionary:
 var fields:Dictionary={}
 for key in target.get("fields",{}):
  var glyph:String=str(target.fields[key])
  fields[key]=owner.config.get("unconfirmed_glyphs",{}).get(glyph,config.glyphs.get(glyph,null))
 return fields

func complete(target:Dictionary) -> void:
 var id:String=str(target.id)
 var current_revision:String=revision(target)
 if not owner.claim("observe:"+id+":"+current_revision,"hospital_observation",{"target":id,"source":target.source}):
  cancel();return
 var value:Dictionary=state()
 var fields:Dictionary=observed_fields(target)
 if value.active.get("controlled",false):owner.app.rules.controlled_execution("observe",id)
 value.completed[id]=current_revision
 value.read[id]={"source":target.source,"room":owner.app.room_id,"fields":fields,"revision":current_revision,"visit_reference":str(owner.data.get("visit",""))}
 if target.has("document_relation"):value.read[id].document_relation=str(target.document_relation)
 var text:String=str(target.text)
 if id=="laundry_stub" and str(owner.data.get("bag",""))=="removed":
  text="实际搬运已完成后，重新读到污衣交接存根的袋号、对象和完成记录；具体字形待核，未补造领标与袋号同号结论。"
  owner.observe("laundry_handoff_complete",text)
 if id=="hospital_medicine_record":
  match medicine_record_kind():
   "false_label":text="实际读到服药表写着已服用；纸面内容与实际未服另账，后来读表不等于见过完整贴签过程。"
   "swallowed":text="实际读到本次服药表写着已服用；真实吞服结果仍由已经发生的吞服事件单独保存。"
   _:text="实际读到本次拒服登记；登记本身不造成药效，也不证明后来贴过已服用标签。"
 for known_id in target.known:owner.observe(str(known_id),text)
 if not id in owner.data.known_pages:owner.data.known_pages.append(id)
 cancel()
 update_links()

func readable_field(id:String,key:String):
 var entry:Dictionary=state().read.get(id,{})
 return entry.get("fields",{}).get(key,null)

func same_number(ids:Array,key:String) -> bool:
 var number=null
 for id in ids:
  var value=readable_field(str(id),key)
  if value==null or str(value).strip_edges().is_empty():return false
  if number==null:number=value
  elif str(number)!=str(value):return false
 return true

func note_link(id:String,text:String) -> void:
 if state().links.has(id):return
 state().links[id]=true;owner.observe(id,text)

func past_case_pair_proved() -> bool:
 # S3:T17R5 explicitly supplies this one case's four original pages. Their
 # semantic source relation is known; the concrete numeral glyph is not.
 # This is not the rule that null numbers compare equal (same_number rejects
 # them), nor permission to merge arbitrary or incompletely read case files.
 var authored:Dictionary=config.get("document_relations",{}).get("past_case",{})
 var group:String=str(authored.get("id",""));var members:Array=authored.get("members",[])
 var expected:Array=["case_removal","case_death","case_fees","case_discharge"]
 if not authored.get("same_person",false) or group.is_empty() or members.size()!=expected.size():return false
 var number:Variant=null
 for id in expected:
  if id not in members or not state().read.has(id):return false
  var actual:Dictionary=state().read[id]
  # Old saves have the same completed stable original IDs, source and read
  # revisions but predate this metadata field. Do not grant an unread page.
  var identity:String=str(actual.get("document_relation",""))
  if not actual.has("document_relation"):
   if str(actual.get("revision","")).is_empty() or str(actual.get("source","")) not in ["S3:T17R4","S3:T17R5"]:return false
   identity=str(specification(id).get("document_relation",""))
  if identity!=group:return false
  var value:Variant=actual.get("fields",{}).get("case_number",null)
  if value==null or str(value).strip_edges().is_empty():continue
  if number==null:number=value
  elif str(number)!=str(value):return false
 return true

func update_links() -> void:
 if past_case_pair_proved():
  note_link("hospital_case_link","实际逐页读完原文明示为同一既往案件的摘除、死亡、费用与离院材料，建立该组原件的对应关系；具体编号字形仍未提供，未补写号码，也未把该既往死者当成在场活人。")
 # S3:T17 explicitly identifies these two texts as the same person's pair.
 # Reading both proves the rewrite; their undelivered number stays unknown.
 var complaint:Dictionary=config.get("document_relations",{}).get("complaint_pair",{})
 if complaint.get("same_person",false) and state().read.has("complaint_original") and state().read.has("complaint_rewrite"):
  note_link("complaint_changed","实际分别读到原文明确为同一人的投诉与异常报告，发现投诉被改写；具体编号字形仍待核，机构表述不替代事实。")
 var signed=readable_field("presigned_form","signature_date")
 if signed==null:signed=readable_field("hospital_prescription_clip","signature_date")
 var registered=readable_field("hospital_registration_time","registration_time")
 # Comparable delivered timestamps must be numeric or ISO-formatted. No
 # invented dates or partial local date strings are ordered by guesswork.
 if signed!=null and registered!=null:
  var comparable:bool=(signed is int or signed is float) and (registered is int or registered is float)
  var earlier:bool=float(signed)<float(registered) if comparable else false
  if signed is String and registered is String:
   comparable=str(signed).length()>=19 and str(registered).length()>=19 and str(signed).substr(4,1)=="-" and str(signed).substr(7,1)=="-" and str(registered).substr(4,1)=="-" and str(registered).substr(7,1)=="-"
   earlier=str(signed)<str(registered) if comparable else false
  if comparable and earlier:note_link("presigned_before_registration","分别读到处方签字日期与本次登记时间，并核对出签字早于登记。")
