extends RefCounted
## S3:T59R2–3/P1950–1957. Presentation is separate from awakening/awareness.
## Evidence pairs are retained only after their actual source nodes proved them.
## Unknown glyphs cannot produce a case match or unlock later presentation.
const StreetMap=preload("res://scripts/core/street_map.gd")
var owner_ref:WeakRef
var app:
 get:return owner_ref.get_ref()

const CALM_LINE="先看清楚，再动。"
const THERAPY_LINE="他原来不是这样说的。"
const HOSPITAL_LINE="不是检查单写错了，是结果被换了。"
const COLD_LINE="问过了。答案一直是那张纸。"
const UNSPARING_LINE="我看见了。现在得走。"
const NORMAL_KINDS=["search","observe","navigation","door","take"]

func _init(owner) -> void:owner_ref=weakref(owner)

func state() -> Dictionary:
 if not app.session.data.has("character_presentation"):
  app.session.data.character_presentation={"version":1,"stage":0,"stage_receipts":{},"pending":[],"spoken":{},"used_actions":{},"evidence":{}}
 var value:Dictionary=app.session.data.character_presentation
 if not value.has("evidence"):value.evidence={}
 return value

func view_state() -> Dictionary:
 var stage:int=int(state().stage);var steady:bool=stage>=1
 return {"stage":stage,"label":["初期","沉稳","冷漠","冷血"][clampi(stage,0,3)],"stance":"restrained" if steady else "lively","expression":"reserved" if steady else "animated","allow_early_jokes":not steady,"prioritize_escape":stage>=3,"source":"S3:T59R2–5/P1953–1954"}

func actually_observed(id:String) -> bool:
 for entry in app.rules.observations:
  if str(entry.get("id",""))==id and str(entry.get("kind",""))=="亲历事实":return true
 return false

func calm_cause() -> Dictionary:
 for id in ["dog_death","parents_collapse"]:
  if app.rules.awakening_receipts.has(id):return {"id":"awakening:"+id,"source":"S3:T59R3/P1950"}
 for id in ["forced_transfer_seen","patient_removed_seen"]:
  if actually_observed(str(id)):return {"id":"observation:"+str(id),"source":"S3:T59R3"}
 # Injury, a general scar page or a false diagnosis alone does not prove a
 # false record about this same actual injury. Do not infer that third route.
 return {}

func _queue(id:String,text:String,cause:String,source:String) -> void:
 var s:Dictionary=state()
 if s.spoken.has(id):return
 for item in s.pending:
  if str(item.id)==id:return
 s.pending.append({"id":id,"text":text,"cause":cause,"source":source})

func normal_action_completed(receipt:String,kind:String,room:String,context:Dictionary={}) -> Dictionary:
 # The caller owns the successful endpoint. finish_public_action is also
 # called on cancellation, so it is deliberately NOT a completion signal.
 if receipt.is_empty() or kind not in NORMAL_KINDS or room!=app.room_id:return {"ok":false,"reason":"not_normal_completion"}
 if app.rules.hp<=0 or app.rules.tutorial_demo or app.rules.loading or app.rules.transitioning or app.rules.absent:return {"ok":false,"reason":"unavailable"}
 if kind=="search" and str(app.rules.settled.get(receipt,""))!="completed":return {"ok":false,"reason":"unfinished_search"}
 var s:Dictionary=state()
 if s.used_actions.has(receipt):return {"ok":false,"reason":"duplicate"}
 collect_evidence()
 var cause:Dictionary={};var target:int=int(s.stage)+1
 if target==1:cause=calm_cause()
 elif target==2:cause=cold_cause()
 elif target==3:cause=escape_cause(kind,context)
 if cause.is_empty():return {"ok":true,"advanced":false,"stage":int(s.stage)}
 s.stage=target;s.used_actions[receipt]=kind
 s.stage_receipts[str(target)]={"cause":str(cause.id),"normal_action":receipt,"kind":kind,"room":room,"source":str(cause.source)}
 var id:String={1:"steady",2:"cold",3:"unsparing"}[target]
 var text:String={1:CALM_LINE,2:COLD_LINE,3:UNSPARING_LINE}[target]
 _queue(id,text,str(cause.id),"S3:T59R%d/P1952/P1957"%(target+2))
 app.rules._record("character_stage_changed","character_stage:"+str(target),s.stage_receipts[str(target)])
 return {"ok":true,"advanced":true,"stage":target}

func collect_evidence() -> void:
 var evidence:Dictionary=state().evidence
 var therapy:String=therapy_cause()
 if not therapy.is_empty():evidence.therapy_retraction=therapy
 var hospital:String=hospital_cause()
 if not hospital.is_empty():evidence.hospital_case=hospital
 var medication:String=false_medicine_cause()
 if not medication.is_empty():evidence.asylum_false_medicine=medication

func false_medicine_cause() -> String:
 if not actually_observed("asylum_false_medicine_seen") or app.asylum==null or app.asylum.data.is_empty():return ""
 var value:Dictionary=app.asylum.data
 if not value.get("refused",false) or value.get("swallowed",false):return ""
 var key:String="asylum:%d:false_medicine"%app.rules.actual_attempt
 if str(value.get("receipts",{}).get(key,""))!="asylum_false_medicine_written":return ""
 var record_id:String="asylum_false_medicine:"+str(app.rules.actual_attempt)
 for record in app.rules.institutional_records:
  if str(record.get("id",""))==record_id:return key+"|"+record_id
 return ""

func cold_cause() -> Dictionary:
 var proof:Dictionary=state().evidence
 if not proof.has("hospital_case"):return {}
 for key in ["therapy_retraction","asylum_false_medicine"]:
  if proof.has(key):return {"id":str(proof.hospital_case)+"|"+str(proof[key]),"source":"S3:T59R4/P1952"}
 # A complaint rewrite, an unpaired photo or an institution's assertion alone
 # is not one of the two independent contradiction classes specified here.
 return {}

func witnessed_street_loss() -> String:
 if int(app.session.data.level)!=6 or app.street==null or app.street.data.is_empty():return ""
 var data:Dictionary=app.street.data
 if not data.get("ending",{}).is_empty():return ""
 var deaths:Dictionary=data.get("speed_deaths",{})
 for target in app.street.config.good_ids:
  var loss:Dictionary=deaths.get(str(target),{})
  if loss.is_empty() or not loss.get("witnessed",false):continue
  var receipt:String=str(loss.get("receipt",""));var source:String=str(loss.get("source",""))
  if receipt.is_empty() or source.is_empty() or source=="hero":continue
  if not actually_observed("street_loss_seen:%d:%s"%[app.rules.actual_attempt,target]):continue
  var original_reaction:String=receipt+":loss_reaction"
  if str(data.get("loss_reactions",{}).get("acknowledged",{}).get(original_reaction,""))!="spoken":continue
  for fact in app.rules.facts:
   if str(fact.get("kind",""))=="street_good_death" and str(fact.get("event_id",""))==receipt+":growth" and str(fact.get("target",""))==str(target) and str(fact.get("source",""))==source and fact.get("eligible_source",false) and fact.get("qualified",false) and fact.get("witnessed",false):return receipt
 return ""

func escape_cause(kind:String,context:Dictionary) -> Dictionary:
 if kind not in ["navigation","door"] or str(context.get("origin",""))!="autonomous" or not safe_gap():return {}
 var loss:String=witnessed_street_loss()
 if loss.is_empty():return {}
 var room:String=app.room_id;var toward:String=str(context.get("toward",""))
 var expected:String="ending_gate" if room=="street_end" else StreetMap.next_room(room,"street_end")
 if kind=="navigation":
  if toward!=expected or expected.is_empty():return {}
  var start:Variant=context.get("from_position",null)
  if not start is Array or start.size()!=2:return {}
  var before:=Vector2(float(start[0]),float(start[1]));var goal:Vector2=app.street.hero_portal(expected).at
  # The existing 4cm arrival tolerance is presentation observation, not a
  # new movement rule. A rollback, sideways dodge or controlled move fails.
  if app.hero_pos.distance_to(goal)>.04 or before.distance_to(goal)<=app.hero_pos.distance_to(goal)+.000001:return {}
 else:
  var previous:String=str(context.get("from_room",""))
  if previous.is_empty() or room not in StreetMap.doors(previous) or toward!=room or StreetMap.next_room(previous,"street_end")!=room:return {}
 return {"id":loss+":continued_escape","source":"S3:T59R5/P1952/P1954"}

func therapy_cause() -> String:
 if not actually_observed("asylum_heard_original") or not actually_observed("asylum_heard_retraction"):return ""
 if app.asylum==null or app.asylum.data.is_empty():return ""
 var therapy:Dictionary=app.asylum.data.get("ward_events",{}).get("therapy",{})
 if not therapy.get("heard_original",false) or not therapy.get("heard_retraction",false):return ""
 # Both heard flags must belong to an actually completed local episode,
 # rather than combining remembered one-sided hearings from two attempts.
 var receipts:Dictionary=app.asylum.data.get("receipts",{})
 for key in receipts:
  var original:String=str(key)
  if not original.ends_with(":speaker_original") or str(receipts[key])!="asylum_original_spoken":continue
  var retraction:String=original.trim_suffix("speaker_original")+"speaker_retraction"
  if str(receipts.get(retraction,""))=="asylum_retraction_spoken":return original+"|"+retraction
 return ""

func hospital_cause() -> String:
 if not actually_observed("hospital_case_link") or app.hospital==null or app.hospital.data.is_empty():return ""
 var observed:Dictionary=app.hospital.data.get("observation_state",{})
 if not observed.get("links",{}).has("hospital_case_link"):return ""
 if app.hospital.observations==null or not app.hospital.observations.past_case_pair_proved():return ""
 return "hospital_case_link"

func safe_gap() -> bool:
 var r=app.rules
 if r.hp<=0 or r.tutorial_demo or r.loading or r.transitioning or r.absent or r.gripped or r.body_busy() or r.search_active or r.control_left>0 or not r.action.is_empty():return false
 if not app.dialogue_queue.is_empty() or app.world_paused() or not app.motion.is_empty() or not app.hero_route.is_empty() or app.action_phase!="autonomy":return false
 if app.family!=null and app.family.collapse_active():return false
 var level:int=int(app.session.data.level)
 if level==2 and app.hospital!=null and app.hospital.blocks_hero():return false
 if level==3 and app.asylum!=null and app.asylum.blocks_hero():return false
 if level==4 and app.cortex!=null and app.cortex.blocks_hero():return false
 if level>=5 and app.active_battle()!=null and not app.active_battle().reactions.safe():return false
 return true

func tick() -> void:
 if app==null or app.rules.tutorial_demo:return
 collect_evidence()
 var evidence:Dictionary=state().evidence
 if evidence.has("therapy_retraction"):_queue("therapy_retraction",THERAPY_LINE,str(evidence.therapy_retraction),"S3:P1956–1957")
 if evidence.has("hospital_case"):_queue("hospital_case",HOSPITAL_LINE,str(evidence.hospital_case),"S3:P1956–1957")
 var s:Dictionary=state()
 if s.pending.is_empty() or not safe_gap():return
 var item:Dictionary=s.pending.pop_front();var id:String=str(item.id)
 if s.spoken.has(id):return
 s.spoken[id]={"cause":str(item.cause),"source":str(item.source)}
 # Existing source/death dialogue has priority. This dispatch changes no
 # target, path, movement clock, knowledge, resistance, awakening or resource.
 app.add_dialogue("角色 · 自言自语",str(item.text))
 app.rules._record("character_reflection","character_reflection:"+id,{"cause":str(item.cause),"source":str(item.source)})
