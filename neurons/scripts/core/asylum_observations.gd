extends RefCounted
## Remaining L3 physical observations. Existing records/trace/medical modules
## own their actual events; this module only grants genuinely completed reads.
var _asylum:WeakRef
var owner:
 get:return _asylum.get_ref()
var config:Dictionary={}

func _init(asylum) -> void:
 _asylum=weakref(asylum)
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/asylum_observations.json"))

func state() -> Dictionary:
 if owner==null or owner.data.is_empty():return {}
 if not owner.data.has("observations_state"):
  owner.data.observations_state={"active":{},"completed":{},"read":{},"links":{},"last_cancel":""}
 return owner.data.observations_state

func usable() -> bool:
 return owner!=null and owner.enabled and not owner.data.is_empty() and owner.app.session.data.level==3 and owner.app.rules.hp>0

func specification(id:String) -> Dictionary:
 for target in config.get("targets",[]):
  if str(target.id)==id:return target
 return {}

func matching_record(prefix:String) -> Dictionary:
 var id:String=prefix+str(owner.app.rules.actual_attempt)
 for record in owner.app.rules.institutional_records:
  if str(record.get("id",""))==id:return record
 return {}

func medicine_record() -> Dictionary:
 for prefix in ["asylum_false_medicine:","asylum_medicine:","asylum_refusal:"]:
  var record:Dictionary=matching_record(str(prefix))
  if not record.is_empty():return record
 return {}

func paper_actor(target:Dictionary) -> String:
 return "doctor" if str(target.get("kind",""))=="diagnosis" else ""

func target_room(target:Dictionary) -> String:
 var actor:String=paper_actor(target)
 if not actor.is_empty() and owner.present(actor):return str(owner.actor(actor).room)
 return str(target.get("room",""))

func target_position(target:Dictionary) -> Vector2:
 var actor:String=paper_actor(target)
 if not actor.is_empty() and owner.present(actor):return owner.position(actor)
 var room:String=target_room(target)
 if room.is_empty():return Vector2.INF
 if str(target.get("kind",""))=="door_panel":return owner.app.door_point_for("office","lobby")+Vector2(0,0.4)
 var layout=owner.layout_for(room);var index:int=int(target.get("furniture",-1))
 return layout.furniture[index].at if index>=0 and index<layout.furniture.size() else Vector2.INF

func available(target:Dictionary) -> bool:
 if not usable() or target.is_empty():return false
 match str(target.kind):
  "laundry_bag":return owner.data.get("carry",{}).get("bag","")=="ward"
  "laundry_vacancy":return owner.data.get("carry",{}).get("bag","")=="removed"
  "diagnosis":return owner.data.get("diagnosed",false) and not matching_record("asylum_diagnosis:").is_empty() and owner.present("doctor")
  "medicine_update":return not medicine_record().is_empty()
  "nurse_duty":return not owner.data.get("nurse_duty_state",{}).get("entries",[]).is_empty()
 return target_position(target).is_finite()

func revision(target:Dictionary) -> String:
 var variant:Variant="static"
 match str(target.kind):
  "diagnosis":variant=matching_record("asylum_diagnosis:")
  "medicine_update":variant=medicine_record()
  "nurse_duty":variant=owner.data.get("nurse_duty_state",{}).get("entries",[])
  "laundry_bag","laundry_vacancy":variant=owner.data.get("carry",{}).get("bag","")
  "display_back":variant=owner.data.get("ward_events",{}).get("work",{}).get("batch",null)
 return str(config.version)+":"+JSON.stringify(variant,"",true).sha256_text().substr(0,16)

func candidate(room:String,index:int=-1) -> Dictionary:
 if not usable() or room!=owner.app.room_id:return {}
 var value:Dictionary=state();var chosen:Dictionary={};var nearest:float=INF
 for target in config.targets:
  if index>=0 and int(target.furniture)!=index:continue
  if target_room(target)!=room or not available(target):continue
  if str(value.completed.get(str(target.id),""))==revision(target):continue
  if target.get("once_known",false) and str(target.id) in owner.app.rules.known:continue
  var at:Vector2=target_position(target)
  if not at.is_finite():continue
  var distance:float=owner.app.hero_pos.distance_to(at)
  if distance<nearest:
   nearest=distance;chosen={"id":str(target.id),"name":str(target.name),"room":room,"pos":at,"source":str(target.source),"furniture":int(target.furniture)}
 return chosen

func body_free(controlled:bool=false) -> bool:
 var rules=owner.app.rules
 return rules.hp>0 and not rules.loading and not rules.transitioning and not rules.absent and not rules.gripped and not rules.body_busy() and not rules.search_active and (controlled or rules.control_left<=0) and owner.data.get("body",{}).is_empty() and str(owner.data.get("holder","")).is_empty() and float(owner.data.get("medicine_stop",0.0))<=0 and owner.data.get("records_state",{}).get("reading",{}).is_empty() and owner.data.get("trace_events",{}).get("active",{}).is_empty() and owner.app.action_phase not in ["return_bed","resting"]

func in_contact(target:Dictionary) -> bool:
 if target_room(target)!=owner.app.room_id:return false
 var at:Vector2=target_position(target)
 return at.is_finite() and owner.app.hero_pos.distance_to(at)<=float(config.contact_distance) and owner.app.layout.clear_segment(owner.app.hero_pos,at)

func begin(id:String,controlled:bool=false) -> bool:
 if not usable() or not state().active.is_empty() or not body_free(controlled) or not owner.app.dialogue_queue.is_empty():return false
 if controlled and owner.app.rules.control_left<=0:return false
 var target:Dictionary=specification(id)
 if target.is_empty() or not available(target) or not in_contact(target):return false
 var version:String=revision(target)
 if str(state().completed.get(id,""))==version:return false
 var at:Vector2=target_position(target)
 state().active={"id":id,"name":str(target.name),"room":owner.app.room_id,"pos":[at.x,at.y],"elapsed":0.0,"phase":"prepare","phase_progress":0.0,"revision":version,"controlled":controlled,"pose":str(target.pose)}
 owner.app.hero_route=PackedVector2Array();owner.app.target_index=-1
 var origin:String="controlled" if controlled else "autonomous"
 if not owner.app.rules.public_action.is_empty():owner.app.rules.finish_public_action(str(owner.app.rules.public_action.get("origin",origin)))
 owner.app.rules.begin_public_action("observe",id,origin,owner.app.room_id)
 return true

func tick(delta:float) -> void:
 if not usable():cancel();return
 var value:Dictionary=state()
 if value.active.is_empty() or not is_finite(delta) or delta<=0:return
 var active:Dictionary=value.active;var target:Dictionary=specification(str(active.id))
 if str(active.room)!=owner.app.room_id or not body_free(bool(active.controlled)) or not available(target) or not in_contact(target) or str(active.revision)!=revision(target) or (active.controlled and owner.app.rules.control_left<=0):
  value.last_cancel="lost_contact_or_changed_source";cancel();return
 if not owner.app.dialogue_queue.is_empty():return
 owner.app.hero_state="give"
 active.elapsed+=minf(delta,owner.app.rules.control_left) if active.controlled else delta
 active.pos=[target_position(target).x,target_position(target).y]
 var elapsed:float=float(active.elapsed);var prepare:float=float(config.timing.prepare);var contact:float=float(config.timing.contact);var finish:float=float(config.timing.finish)
 if elapsed<prepare:active.phase="prepare";active.phase_progress=elapsed/prepare
 elif elapsed<prepare+contact:active.phase="contact";active.phase_progress=(elapsed-prepare)/contact
 elif elapsed<prepare+contact+finish:active.phase="finish";active.phase_progress=(elapsed-prepare-contact)/finish
 else:complete(target)

func cancel() -> void:
 if owner==null or owner.data.is_empty() or not owner.data.has("observations_state"):return
 var value:Dictionary=state();var action:Dictionary=owner.app.rules.public_action
 if not value.active.is_empty() and action.get("kind","")=="observe" and str(action.get("target",""))==str(value.active.id):owner.app.rules.finish_public_action(str(action.get("origin","autonomous")))
 value.active={}
 if owner.app.action_phase=="asylum_reading":owner.app.action_phase="autonomy";owner.app.hero_state="idle"

func blocks_hero() -> bool:return usable() and not state().active.is_empty()

func observed_fields(target:Dictionary) -> Dictionary:
 var fields:Dictionary={}
 for key in target.get("fields",{}):fields[key]=config.glyphs.get(str(target.fields[key]),null)
 match str(target.kind):
  "diagnosis":fields.paper=matching_record("asylum_diagnosis:").duplicate(true)
  "medicine_update":fields.paper=medicine_record().duplicate(true)
  "nurse_duty":fields.entries=owner.data.get("nurse_duty_state",{}).get("entries",[]).duplicate(true)
  "display_back":fields.batch=owner.data.get("ward_events",{}).get("work",{}).get("batch",config.glyphs.workshop_batch)
 return fields

func say(key:String) -> void:
 if key.is_empty():return
 if key=="COAT_RECOGNISE" and not "cuff_seam" in owner.app.rules.known:return
 var global_key:String="asylum_observation_line:"+key
 if owner.app.rules.settled.has(global_key):return
 owner.app.rules.settled[global_key]="heard"
 for line in config.dialogue.get(key,[]):owner.app.add_dialogue(str(line.speaker),str(line.text))

func complete(target:Dictionary) -> void:
 var value:Dictionary=state();var id:String=str(target.id);var version:String=revision(target)
 if not owner.claim("observe:"+id+":"+version,"asylum_observation",{"target":id,"source":str(target.source)}):cancel();return
 if owner.app.get("audio")!=null:
  var cue:String="SFX_SEARCH_CLOTH" if id in ["asylum_bed_straps","asylum_ward_coat_badge","asylum_clinic_coat_sleeve","asylum_quiet_scratches"] else "SFX_SEARCH_PAPER"
  owner.app.audio.cue(cue,"asylum_observe:%d:%s:%s"%[owner.app.rules.actual_attempt,id,version])
 var fields:Dictionary=observed_fields(target)
 if value.active.controlled:owner.app.rules.controlled_execution("observe",id)
 value.completed[id]=version
 value.read[id]={"source":str(target.source),"room":owner.app.room_id,"fields":fields,"revision":version,"attempt":owner.app.rules.actual_attempt,"operation":str(target.kind)}
 var text:String=str(target.text)
 if str(target.kind)=="diagnosis":text+=" 本次实际纸面内容："+str(fields.paper.get("text",""))
 if str(target.kind)=="medicine_update":text+=" 本次实际纸面内容："+str(fields.paper.get("text",""))
 owner.observe(id,text)
 # A changed actual document remains a separate read version in the book;
 # remembered older text is not silently overwritten or promoted to fact.
 if str(target.kind) in ["diagnosis","medicine_update","nurse_duty"]:owner.app.rules.observe("物品",id+"@"+version,text,"文书记录",str(target.source))
 if id=="asylum_clinic_coat_sleeve" and "cuff_seam" in owner.app.rules.known:
  value.links.coat_correspondence=true;owner.observe("asylum_coat_correspondence","实际比较已见卧室袖口与柜内大褂的破损缝线；只确认对应衣物特征，不确认两位医生为同一人。")
 if id=="asylum_waste_label_under":value.links.label_layers_exposed=true
 var dialogue:String=str(target.get("dialogue",""))
 cancel();say(dialogue)
 if str(target.kind)=="nurse_duty" and owner.get("nurse_duty")!=null:owner.nurse_duty.on_table_read()

func on_skill(result:Dictionary) -> void:
 if result.get("success",false) and str(result.get("id","")) in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"]:cancel()
