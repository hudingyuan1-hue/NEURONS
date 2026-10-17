extends "res://scripts/core/interaction_rules.gd"
## Campaign extension. Timing/receipts are independent of sprite frames.
signal vitality_lost
signal physical_transfer(event_id:String,item:String,to:String)
signal achievement_requested(keys:Array,event_id:String)
const CONFIG_PATH="res://data/skills.json"
var skill_states:Dictionary={}
var effects:Dictionary={}
var pending_neural:Dictionary={}
var control_left:float=0.0
var control_ms:int=0
var control_fraction_ms:float=0.0
var control_stage:int=0
var control_stage_receipts:Dictionary={}
var control_feedback:Array=[]
var pending_global_growth:int=0
var awakening_receipts:Dictionary={}
var mode:String="exploration"
var gripped:bool=false
var loading:bool=false
var transitioning:bool=false
var absent:bool=false
var kick_until:float=0.0
var combat_regen:float=0.0
var action_serial:int=0
var action:Dictionary={}
var observations:Array=[]
var book_extensions:Dictionary={}
var reaction_skill:String=""
var evidence:Array=[]
var awareness_stage:int=0
var awareness_feedback:Array=[]
var public_action:Dictionary={}
var public_serial:int=0
var trial:Dictionary={}
var trial_attempt:int=0
var trial_evidence_count:int=0
var intervention_lock:bool=false
var lock_after_serial:int=0
var control_context:Dictionary={}
var control_event:String=""
var control_evidence_receipts:Dictionary={}
var tutorial_demo:bool=false
var body_feedback:Array=[]
var config:Dictionary={}

func _init() -> void:
 config=JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
 for spec in config.skills:
  skill_states[spec.id]={"unlocked":spec.id=="SKIN","power":int(spec.power),"resistance":0,"reactions":0,"growth":false,"until":0.0}

func spec(id:String) -> Dictionary:
 for entry in config.skills:
  if entry.id==id:return entry
 return {}

func sync_skin() -> void:
 skill_states.SKIN.power=skin_power
 skill_states.SKIN.resistance=skin_resistance
 skill_states.SKIN.reactions=skin_reactions
 skill_states.SKIN.growth=skin_pending_resistance
 skill_states.SKIN.until=cooldown_until

func unlock(id:String) -> Dictionary:
 if hp<=0 or transitioning:return _rejected("unavailable")
 var entry:Dictionary=spec(id)
 if entry.is_empty():return _rejected("unknown")
 if skill_states[id].unlocked:return _rejected("already_unlocked")
 var required:Array=entry.prerequisites
 var eligible:bool=false if entry.prerequisite_mode=="any" else true
 for parent in required:
  if entry.prerequisite_mode=="any":eligible=eligible or bool(skill_states[parent].unlocked)
  else:eligible=eligible and bool(skill_states[parent].unlocked)
 if not eligible:return _rejected("prerequisites")
 if plexus<int(entry.unlock_cost):return _rejected("insufficient_clusters")
 plexus-=int(entry.unlock_cost)
 skill_states[id].unlocked=true
 return {"ok":true,"id":id}

func upgrade(id:String) -> Dictionary:
 if hp<=0 or transitioning or not skill_states.has(id):return _rejected("unavailable")
 if not skill_states[id].unlocked:return _rejected("locked")
 if plexus<1:return _rejected("insufficient_clusters")
 sync_skin()
 plexus-=1
 skill_states[id].power+=1
 if id=="SKIN":skin_power=int(skill_states[id].power)
 return {"ok":true,"id":id}

func exchange() -> Dictionary:
 if hp<=0 or transitioning:return _rejected("unavailable")
 if neurons<10:return _rejected("insufficient_neurons")
 neurons-=10
 plexus+=1
 return {"ok":true}

func emergency_available() -> bool:
 sync_skin()
 if mode!="combat" or plexus!=0 or neurons>=10:return false
 for id in skill_states:
  var state:Dictionary=skill_states[id]
  if state.unlocked and int(state.power)>int(state.resistance)+global_resistance:return false
 return true

func emergency_reconnect() -> Dictionary:
 if hp<=0 or transitioning or not emergency_available():return _rejected("unavailable")
 if neurons<5:return _rejected("insufficient_neurons")
 neurons-=5
 skin_power=skin_resistance+global_resistance+1
 sync_skin()
 return {"ok":true}

func availability(id:String, context:Dictionary={}) -> String:
 sync_skin()
 if not skill_states.has(id):return "unknown"
 if not skill_states[id].unlocked:return "locked"
 if hp<=0 or transitioning or loading or absent:return "unavailable"
 if control_left>0:return "control_active"
 if intervention_lock and mode=="exploration" and not context.get("father_rescue",false):return "recognition_lock"
 if not pending_neural.is_empty() or not pending_skin.is_empty():return "pending"
 var mental:bool=id in ["FEAR","JOY"] and stun_left<=0
 var rescue:bool=(context.get("father_rescue",false) and id in ["KNEE","STARTLE","FEAR","JOY"] or context.get("medical_rescue",false) and id=="KNEE") and stun_left<=0
 if (body_busy() or gripped) and not mental and not rescue:return "body_unavailable"
 if not action.is_empty():
  if action.phase!="prepare" or not id in ["SKIN","WITHDRAW","STARTLE"]:return "action_active"
 if float(effects.get(id,0))>0:return "effect_active"
 if world_time+0.000001<float(skill_states[id].until) or (id=="KNEE" and world_time+0.000001<kick_until):return "cooldown"
 if context.get("valid",true)==false:return "invalid_target"
 if mode=="combat" and id=="SKIN" and not context.has("direction"):return "direction_required"
 if mode=="combat" and id=="PORES" and not context.get("perceived_threat",false):return "no_perceived_threat"
 if neurons<int(spec(id).cost):return "insufficient_neurons"
 return ""

func submit_skill(id:String, context:Dictionary={}) -> Dictionary:
 var reason:String=availability(id,context)
 if not reason.is_empty():return _rejected(reason)
 var entry:Dictionary=spec(id)
 var state:Dictionary=skill_states[id]
 _cast_serial+=1
 var event_id:String="neural:%d:%d"%[actual_attempt,_cast_serial]
 var success:bool=int(state.power)>int(state.resistance)+global_resistance
 neurons-=int(entry.cost)
 if id!="CONTROL" or not success:state.until=world_time+float(entry.cooldown)
 if id=="KNEE":kick_until=world_time+4.0
 pending_neural={"ok":true,"success":success,"id":id,"event_id":event_id,"power":state.power,"resistance":int(state.resistance)+global_resistance,"context":context.duplicate(true),"reason":"queued" if success else "resisted"}
 pending_skin=pending_neural.duplicate(true) # Existing scene pause gate, one payment.
 if id=="SKIN":cooldown_until=float(state.until)
 _record("skill_submitted",event_id,{"skill":id,"cost":entry.cost,"success":success})
 return pending_neural.duplicate(true)

func submit_skin() -> Dictionary:
 return submit_skill("SKIN")

func apply_pending() -> Dictionary:
 if pending_neural.is_empty():return super.apply_pending()
 var result:Dictionary=pending_neural.duplicate(true)
 pending_neural.clear()
 pending_skin.clear()
 var id:String=result.id
 var event_id:String=result.event_id
 if settled.has(event_id):return _rejected("already_settled")
 settled[event_id]="resisted"
 var mental:bool=id in ["FEAR","JOY"] and stun_left<=0
 var rescue:bool=(result.context.get("father_rescue",false) and id in ["KNEE","STARTLE","FEAR","JOY"] or result.context.get("medical_rescue",false) and id=="KNEE") and stun_left<=0
 if hp<=0 or ((body_busy() or gripped) and not mental and not rescue) or transitioning:
  result.success=false
  result.reason="interrupted"
  if id=="CONTROL":skill_states.CONTROL.until=world_time+20.0
 if not result.success:
  result.search_cancelled=false
  _record("skill_resisted" if result.reason!="interrupted" else "skill_interrupted",event_id,{"skill":id})
  if id=="CONTROL" and result.reason!="interrupted" and not tutorial_demo:achievement_requested.emit(["control_resisted"],event_id+":resisted")
  return result
 var before:bool=search_active
 var conscious:bool=stun_left<=0
 if id in ["SKIN","WITHDRAW","STARTLE"] and not action.is_empty() and action.phase=="prepare":action.clear()
 if id in ["SKIN","GUT","KNEE","WITHDRAW","STARTLE","FEAR","CONTROL"] and (mode=="exploration" or id!="GUT"):cancel_search()
 var timing:Dictionary=config.timing
 reaction_skill=id
 match id:
  "SKIN":
   if mode=="exploration":reaction_left=float(timing.skin_reaction)
  "GUT":reaction_left=float(timing.gut_reaction)
  "PORES":effects[id]=float(timing.pores) if mode=="exploration" else 0.25
  "TEMP":effects[id]=float(timing.temp)
  "TINNITUS":effects[id]=float(timing.tinnitus_exploration if mode=="exploration" else timing.tinnitus_combat)
  "DRYMOUTH":effects[id]=float(timing.drymouth_transfer_delay if mode=="exploration" else timing.drymouth_combat)
  "WITHDRAW":reaction_left=float(timing.withdraw)
  "FEAR":
   change_sp(-15)
   effects[id]=float(timing.fear_retry if mode=="exploration" else timing.fear_combat)
  "JOY":
   change_sp(20)
   effects.erase("FEAR")
  "CONTROL":
   control_left=float(timing.control)
   control_context=result.context.duplicate(true)
   control_event=event_id
  "KNEE":begin_kick(result.context,false)
 settled[event_id]="reaction"
 note_reaction(id)
 result.search_cancelled=before and not search_active
 result.reason="reacted"
 var old_awareness:int=awareness_stage
 if id!="CONTROL" and conscious:
  var changed:bool=result.search_cancelled or id in ["STARTLE","WITHDRAW","KNEE"] or (id=="TINNITUS" and result.context.get("action","")=="navigation")
  if public_action.get("kind","")=="navigation" and id in ["SKIN","GUT","TEMP","TINNITUS","KNEE","WITHDRAW","STARTLE","FEAR"]:changed=true
  add_evidence(event_id,id,result.context,changed)
 if not tutorial_demo and old_awareness==awareness_stage:
  body_feedback=body_feedback.filter(func(entry):return entry.skill!=id)
  body_feedback.append({"skill":id,"event_id":event_id,"lines":spec(id).exploration_dialogue if mode=="exploration" else spec(id).combat_dialogue})
 _record("skill_reacted",event_id,{"skill":id,"context":result.context})
 return result

func note_reaction(id:String) -> void:
 if tutorial_demo:return
 var state:Dictionary=skill_states[id]
 if not state.growth:
  state.reactions+=1
  if int(state.reactions)>=3:
   state.reactions=0
   state.growth=true
 if id=="SKIN":
  skin_reactions=int(state.reactions)
  skin_pending_resistance=bool(state.growth)

func change_sp(amount:int) -> void:
 var previous:int=sp
 sp=clampi(sp+amount,0,100)
 if sp<previous:vitality_lost.emit()
 if sp>=20:_sp_depleted=false
 if previous>0 and sp==0 and not _sp_depleted and hp>0:
  _sp_depleted=true
  cancel_search()
  stun_left=maxf(stun_left,1.0)

func next_actual_attempt() -> void:
 sync_skin()
 for id in skill_states:
  if skill_states[id].growth:
   skill_states[id].resistance+=1
   skill_states[id].growth=false
 global_resistance+=pending_global_growth
 pending_global_growth=0
 skin_resistance=int(skill_states.SKIN.resistance)
 skin_pending_resistance=false
 effects.clear()
 action.clear()
 end_control()
 gripped=false
 trial.clear();intervention_lock=false;public_action.clear()

func record_awakening(id:String) -> bool:
 if awakening_receipts.has(id):return false
 awakening_receipts[id]=true
 pending_global_growth+=1
 if not tutorial_demo:achievement_requested.emit(["first_awakening"],"awakening:"+id)
 return true

func body_busy() -> bool:
 return super.body_busy() or float(effects.get("TINNITUS",0))>0 or float(effects.get("MEDICINE",0))>0

func movement_rate() -> float:
 if float(effects.get("TEMP",0))<=0:return 1.0
 return float(config.timing.temp_exploration_rate if mode=="exploration" else config.timing.temp_combat_rate)

func tick(delta:float) -> Dictionary:
 var result:Dictionary={"search_completed":false,"reaction_finished":false,"target_id":""}
 if hp<=0 or loading or transitioning or not is_finite(delta) or delta<=0:return result
 var blocked:float=maxf(maxf(reaction_left,stun_left),maxf(hurt_left,maxf(float(effects.get("TINNITUS",0)),float(effects.get("MEDICINE",0)))))
 var temp_left:float=float(effects.get("TEMP",0))
 var active_search:bool=search_active
 var old_control:float=control_left
 search_active=false
 result=super.tick(delta)
 search_active=active_search
 if control_left>0:
  var window:float=minf(control_left,delta)
  var effective:float=0.0 if gripped or absent or transitioning else maxf(0.0,window-blocked)
  control_fraction_ms+=effective*1000.0
  var whole:int=int(floor(control_fraction_ms+0.000001))
  control_fraction_ms=maxf(0.0,control_fraction_ms-whole)
  control_ms+=whole
  if control_ms>=120000 and not settled.has("control:120000:achievement") and not tutorial_demo:
   settled["control:120000:achievement"]="actual_control_time"
   achievement_requested.emit(["self_erased"],"control:120000")
  var stage:int=3 if control_ms>=120000 else 2 if control_ms>=60000 else 1 if control_ms>=30000 else 0
  if stage!=control_stage:
   control_stage=stage
   if not control_stage_receipts.has(str(stage)):
    control_stage_receipts[str(stage)]=true
    control_feedback=[stage]
  control_left=maxf(0,control_left-delta)
  if control_left<=0:skill_states.CONTROL.until=world_time+20.0-maxf(0,delta-window)
 for id in effects:
  effects[id]=maxf(0,float(effects[id])-delta)
 if mode=="combat" and not transitioning:
  combat_regen+=maxf(0.0,delta-old_control)
  while combat_regen>=4.0:
   combat_regen-=4.0
   neurons=mini(5,neurons+1) if neurons<5 else neurons
 if search_active and not gripped:
  var advance:float=maxf(0,delta-blocked)
  if mode=="exploration" and temp_left>blocked:
   advance-=maxf(0,minf(delta,temp_left)-blocked)*(1.0-float(config.timing.temp_exploration_rate))
  search_elapsed=minf(search_duration,search_elapsed+advance)
  if search_elapsed+0.000001>=search_duration and not settled.has(_search_id):
   search_active=false
   settled[_search_id]="completed"
   # A companion can finish this point while a legal controlled search is
   # already running. Finish the physical action but settle income only once.
   var first_completion:bool=not _completed_targets.has(search_target)
   _completed_targets[search_target]=true
   if first_completion:
    search_count+=1
    neurons+=1
   _record("search_completed",_search_id,{"target":search_target,"neurons":1 if first_completion else 0,"already_completed":not first_completion})
   result={"search_completed":true,"reaction_finished":result.reaction_finished,"target_id":search_target,"event_id":_search_id,"rewarded":first_completion}
 return result

func commit_hit(event_id:String,distance:float,line_of_sight:bool,facing:bool,active:bool,source_id:String="cat",target_id:String="protagonist") -> bool:
 var hit:bool=super.commit_hit(event_id,distance,line_of_sight,facing,active,source_id,target_id)
 if hit:
  vitality_lost.emit()
  pending_neural.clear()
  action.clear()
  if hp<=0:end_control()
 return hit

func commit_transfer(event_id:String,item:String,from:String,to:String,distance:float,line_of_sight:bool,facing:bool,active:bool) -> bool:
 var committed:bool=super.commit_transfer(event_id,item,from,to,distance,line_of_sight,facing,active)
 if committed:physical_transfer.emit(event_id,item,to)
 return committed

func end_control() -> void:
 if control_left<=0:return
 control_left=0
 skill_states.CONTROL.until=world_time+20.0

func begin_kick(context:Dictionary, controlled:bool) -> Dictionary:
 if controlled:
  if control_left<=0 or not skill_states.KNEE.unlocked or mode!="combat" or body_busy() or gripped or not action.is_empty() or world_time<kick_until:return _rejected("kick_unavailable")
  kick_until=world_time+4.0
 action_serial+=1
 action={"id":"kick:%d:%d"%[actual_attempt,action_serial],"kind":"kick","phase":"prepare","elapsed":0.0,"direction":context.get("direction",[1.0,0.0]),"hit_receipts":{},"controlled":controlled}
 return {"ok":true}

func advance_kick(delta:float) -> Dictionary:
 if action.is_empty():return {}
 action.elapsed+=delta
 var prepare:float=float(config.timing.kick_prepare)
 var attack:float=float(config.timing.kick_attack)
 var end:float=prepare+attack+float(config.timing.kick_recover)
 action.phase="prepare" if action.elapsed<prepare else "attack" if action.elapsed<prepare+attack else "recover"
 var result:Dictionary=action.duplicate(true)
 if action.elapsed>=end:action.clear()
 return result

func kick_contact(target:String,distance:float,in_front:bool,clear:bool) -> bool:
 if hp<=0 or action.is_empty() or action.phase!="attack" or not in_front or not clear or not is_finite(distance) or distance>float(config.timing.kick_range) or distance<0 or target.is_empty():return false
 var key:String=str(action.id)+":"+target
 if settled.has(key):return false
 settled[key]="kick_hit"
 action.hit_receipts[target]=true
 _record("kick_hit",key,{"target":target,"damage":int(config.timing.kick_damage) if mode=="combat" else 0})
 return true

func observe(category:String,id:String,text:String,kind:String="亲历事实",source:String="现场观察") -> void:
 for entry in observations:
  if entry.id==id and entry.kind==kind:return
 observations.append({"category":category,"id":id,"text":text,"kind":kind,"source":source})

func buy_book_extension(id:String) -> Dictionary:
 if hp<=0 or transitioning or id.is_empty() or book_extensions.has(id):return _rejected("unavailable")
 if not config.get("book_extensions",{}).has(id):return _rejected("no_extension_content")
 var seen:bool=false
 var category:String=str(config.book_extensions[id].category)
 for entry in observations:
  if entry.category==category:seen=true
 if not seen:return _rejected("not_observed")
 if plexus<5:return _rejected("insufficient_clusters")
 plexus-=5
 book_extensions[id]=true
 return {"ok":true}

func book_extension_id(category:String) -> String:
 for id in config.get("book_extensions",{}):
  if config.book_extensions[id].category==category:return id
 return ""

func book_details(category:String) -> String:
 var id:String=book_extension_id(category)
 if not book_extensions.has(id):return ""
 var lines:Array[String]=["参数明细 · 不将说明登记为已发生事实"]
 if category=="角色":
  sync_skin()
  lines.append("全局抗性：%d"%global_resistance)
  for skill in skill_states:
   if skill_states[skill].unlocked:lines.append("%s  针对抗性 %d"%[skill,skill_states[skill].resistance])
 elif category=="物品":
  var types:Dictionary={}
  for entry in observations:
   if str(entry.id).begins_with("food:"):types[str(entry.id).get_slice(":",1)]=true
  if types.has("porridge"):lines.append("粥：食用完成精神至100；玩家+5N/+1C。")
  if types.has("candy"):lines.append("糖果：食用完成精神+20；玩家+5N。")
  if types.has("chocolate"):lines.append("巧克力：食用完成生命/精神各+15；玩家+3N/+1C。")
 else:
  var seen:Dictionary={}
  for entry in observations:
   if entry.category=="人物":seen[entry.id]=true
  if seen.has("dog"):lines.append("大黄：最多三次有效辅助；角色/大黄共享点位完成与收入。")
  if seen.has("cat"):lines.append("黑猫：角色三次搜寻行动结算后退场；异常受惊另按实际抓挠。")
  if seen.has("mother"):lines.append("母亲：赠物与食用分开；对应休息实际完成才结束尝试。")
  if seen.has("father"):lines.append("父亲：准备至少2秒、抓取1秒、抓稳2秒；精神每游戏秒-1。")
 return "\n".join(lines)

func begin_public_action(kind:String,target:String,origin:String,room:String) -> void:
 public_serial+=1
 public_action={"serial":public_serial,"kind":kind,"target":target,"origin":origin,"room":room}
 if origin=="autonomous" and awareness_stage==2 and trial_attempt!=actual_attempt and evidence.size()>trial_evidence_count:
  trial=public_action.duplicate(true)
  trial_attempt=actual_attempt;trial_evidence_count=evidence.size()
  _record("trial_started","trial:%d"%public_serial,{"target":target,"room":room})

func finish_public_action(origin:String) -> void:
 if public_action.is_empty() or str(public_action.origin)!=origin:return
 if intervention_lock and origin=="autonomous" and int(public_action.serial)>lock_after_serial:intervention_lock=false
 if not trial.is_empty() and trial.serial==public_action.serial:trial.clear()
 public_action.clear()

func add_evidence(id:String,skill:String,context:Dictionary,changed:bool) -> void:
 if tutorial_demo or hp<=0:return
 for prior in evidence:
  if prior.id==id:return
 var room:String=str(context.get("room","unknown"))
 var target:String=str(context.get("target","self"))
 var action_kind:String=str(context.get("action","body"))
 var key:String=room+":"+action_kind+":"+target
 evidence.append({"id":id,"skill":skill,"context":key,"room":room,"target":target,"action":action_kind})
 if awareness_stage==0:
  awareness_stage=1;awareness_feedback.append("刚才怎么回事……")
 elif awareness_stage==1:
  var contexts:Dictionary={};var counts:Dictionary={}
  for entry in evidence:
   contexts[entry.context]=true;counts[entry.skill]=int(counts.get(entry.skill,0))+1
  var repeat:bool=false
  for count in counts.values():repeat=repeat or int(count)>=2
  if evidence.size()>=3 and contexts.size()>=2 and repeat:
   awareness_stage=2;awareness_feedback.append("刚才那一下……不是我想动的。")
 elif awareness_stage==2 and changed and not trial.is_empty() and trial.room==room and trial.target==target:
  recognize()

func recognize() -> void:
 if awareness_stage>=3:return
 awareness_stage=3
 if not tutorial_demo:achievement_requested.emit(["exposed_player"],"awareness:recognized")
 awareness_feedback.append("是你吧？别再碰我了。")
 intervention_lock=mode=="exploration"
 lock_after_serial=public_serial
 trial.clear()

func controlled_execution(kind:String,target:String,contrary:bool=true) -> void:
 if kind!="navigation":record_control_action(kind,target)
 if tutorial_demo or control_event.is_empty() or control_evidence_receipts.has(control_event):return
 control_evidence_receipts[control_event]=true
 var changed:bool=contrary and (target!=str(control_context.get("target","self")) or kind!=str(control_context.get("action","body")))
 var context:Dictionary=control_context.duplicate(true)
 context.action=kind;context.target=target
 var was_aware:bool=awareness_stage==2
 add_evidence(control_event,"CONTROL",context,changed)
 if was_aware and changed and awareness_stage==2:recognize()

func record_control_action(kind:String,target:String) -> void:
 if tutorial_demo or control_event.is_empty():return
 var key:String=control_event+":physical_action"
 if settled.has(key):return
 # A testing time window, failed submission or preview is not a successful
 # takeover. Require the real successful reaction and a physical caller.
 var success:bool=false
 for fact in facts:
  if fact.kind=="skill_reacted" and fact.event_id==control_event and fact.get("skill","")=="CONTROL":success=true;break
 if not success:return
 settled[key]="controlled_action"
 _record("controlled_action",key,{"action":kind,"target":target,"control_event":control_event})
 achievement_requested.emit(["first_control_action"],key)
