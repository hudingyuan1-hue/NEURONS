extends RefCounted
## S3:P1748–1755; S4:P228/T16R4/T19R10. One real cup, one poured dose.
const ID="ward_nurse"
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func actor() -> Dictionary:return battle.data.actors[ID]
func param(key:String) -> float:return float(battle.config.test_parameters[key])
func origin() -> Vector2:return battle.position(ID)
func direction() -> Vector2:
 var d:Vector2=battle.vector(actor().direction)
 return d.normalized() if d.length_squared()>.001 else Vector2.RIGHT
func state() -> Dictionary:
 if not battle.data.has("ward_medicine"):
  battle.data.ward_medicine={"attack_id":"","phase":"ready","dose":"cup" if actor().portions>0 else "empty","head":battle.xy(origin()),"goal":battle.xy(origin()),"cup":battle.xy(origin()),"blocked":false,"recover_points":[]}
 return battle.data.ward_medicine
func begin() -> void:
 var s:Dictionary=state();s.attack_id=actor().attack_id;s.blocked=false;s.dose="cup" if actor().portions>0 else "empty";s.recover_points=[]
 var distance:float=origin().distance_to(app.hero_pos) if actor().room==app.room_id else float(battle.config.attacks.drug.reach)
 s.goal=battle.xy(origin()+direction()*minf(distance,float(battle.config.attacks.drug.reach)))
func release(reason:String) -> void:
 if battle.data.holder!=ID:return
 spill_pending(reason)
 battle.data.holder="";app.rules.gripped=false;battle.data.grip_safe_until=battle.data.clock+.8
 if actor().hp>0:actor().phase="recover";actor().elapsed=0.0
 app.rules._record("street_medicine_released",str(actor().attack_id)+":release",{"reason":reason,"source":"S3:P1681/P1753"})
func spill_pending(reason:String) -> void:
 if state().dose!="pouring":return
 state().dose="spilled";app.rules._record("street_medicine_spilled",str(actor().attack_id)+":spill",{"cause":reason,"source":"S3:P1751/P1753/P1755"})
func before_actor() -> void:
 var a:Dictionary=actor()
 if battle.data.holder==ID and (not a.present or a.hp<=0 or a.hurt>0 or a.room!=app.room_id or app.rules.hp<=0 or app.rules.hurt_left>0 or app.rules.stun_left>0):release("actual_interruption")
 if battle.data.holder!=ID or a.phase!="drug_hold":spill_pending("hold_ended_before_swallow")
 sync()
func sync() -> void:
 var a:Dictionary=actor();var s:Dictionary=state();var start:Vector2=origin()+direction()*param("medicine_cup_rest_m")
 if not a.present or a.hp<=0:s.phase="lowered";return
 if a.phase=="windup":
  if s.attack_id!=a.attack_id:begin()
  s.phase="reach_head";s.head=battle.xy(origin().lerp(battle.vector(s.goal),clampf(float(a.elapsed)/float(battle.config.attacks.drug.windup)*.35,0,.35)));s.cup=battle.xy(start)
 elif a.phase=="attack":s.phase="reach_head"
 elif a.phase=="drug_hold" and battle.data.holder==ID:
  # Legacy holds have a real paid head grip; reconstruct only current cup pose.
  if s.attack_id!=a.attack_id:s.attack_id=a.attack_id;s.goal=battle.xy(app.hero_pos)
  s.head=s.goal.duplicate();var t:float=clampf(float(a.elapsed)/param("medicine_cup_approach_s"),0,1)
  s.cup=battle.xy(start.lerp(battle.vector(s.goal),t))
  s.phase="head_fixed" if a.elapsed<param("medicine_head_fix_s") else "cup_approach" if t<1 else "cup_tilt" if a.elapsed<param("medicine_pour_s") else "pouring"
 elif a.phase=="recover":
  s.phase="withdraw_cup";var t:float=clampf(float(a.elapsed)/float(battle.config.attacks.drug.recover),0,1)
  if s.get("recover_points",[]).is_empty():s.recover_points=[s.head.duplicate(),s.cup.duplicate()]
  var head:Vector2=battle.vector(s.recover_points[0]).lerp(origin(),t);var cup:Vector2=battle.vector(s.recover_points[1]).lerp(start,t)
  var floor=battle.floor_for(str(a.room))
  if floor.clear_segment(battle.vector(s.head),head,param("medicine_hand_radius_m")):s.head=battle.xy(head)
  if floor.clear_segment(battle.vector(s.cup),cup,param("medicine_hand_radius_m")):s.cup=battle.xy(cup)
 else:s.phase="ready";s.head=battle.xy(origin());s.cup=battle.xy(start)
func advance_head(delta:float) -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if s.attack_id!=a.attack_id:begin()
 a.elapsed+=delta
 var tip:Vector2=origin().lerp(battle.vector(s.goal),clampf(float(a.elapsed)/float(battle.config.attacks.drug.active),0,1))
 var floor=battle.floor_for(str(a.room))
 if not floor.clear_segment(origin(),tip,param("medicine_hand_radius_m")):
  s.blocked=true;a.elapsed=float(battle.config.attacks.drug.active)
 else:s.head=battle.xy(tip)
 if a.room==app.room_id and contains(app.hero_pos) and not a.hits.has("hero") and a.portions>0:
  a.hits.hero=true;battle.data.holder=ID;battle.data.grip_until=battle.data.clock+1.2;app.rules.gripped=true;a.phase="drug_hold";a.elapsed=0;s.goal=battle.xy(app.hero_pos);sync();return
 if a.elapsed>=float(battle.config.attacks.drug.active):a.phase="recover";a.elapsed=0
 sync()
func contains(target:Vector2) -> bool:
 var a:Dictionary=actor();var s:Dictionary=state()
 if not a.present or a.hp<=0 or a.hurt>0 or a.portions<=0 or s.blocked:return false
 if a.phase=="attack":
  if a.elapsed<float(battle.config.attacks.drug.active)*param("medicine_head_contact_ratio") or not str(battle.data.holder).is_empty() or battle.data.clock<battle.data.grip_safe_until:return false
 elif a.phase!="windup":return false
 var goal:Vector2=battle.vector(s.goal)
 var tip:Vector2=battle.vector(s.head) if a.phase=="attack" else goal
 return tip.distance_to(target)<=param("medicine_head_radius_m") and goal.distance_to(target)<=param("medicine_head_radius_m") and battle.floor_for(str(a.room)).clear_segment(origin(),target,param("medicine_hand_radius_m"))
func tick_hold(delta:float) -> void:
 var a:Dictionary=actor();var s:Dictionary=state()
 if battle.data.holder!=ID:a.phase="recover";a.elapsed=0;sync();return
 a.elapsed+=delta;sync()
 var mouth:Vector2=battle.vector(s.goal);var cup:Vector2=battle.vector(s.cup)
 var floor=battle.floor_for(str(a.room))
 if not floor.clear_segment(origin(),mouth,param("medicine_hand_radius_m")) or mouth.distance_to(app.hero_pos)>param("medicine_head_radius_m"):release("lost_physical_contact");sync();return
 var touching:bool=cup.distance_to(mouth)<=param("medicine_mouth_radius_m")
 if touching and a.elapsed>=param("medicine_pour_s") and s.dose=="cup" and a.portions>0:
  a.portions=0;s.dose="pouring"
  app.rules._record("street_medicine_poured",str(a.attack_id)+":pour",{"source":"S3:P1750/P1755","remaining":0})
 if touching and a.elapsed>=param("medicine_swallow_s") and s.dose=="pouring" and app.rules.hp>0:
  var receipt:String=str(a.attack_id)+":swallow"
  if not app.rules.settled.has(receipt):
   app.rules.settled[receipt]="medicine_swallowed";app.rules.change_sp(-20);app.rules.stun_left=maxf(app.rules.stun_left,1.5)
   app.rules._record("street_medicine_swallowed",receipt,{"sp":-20,"source":"S4:T16R4"})
  s.dose="swallowed";release("completed");sync()
 # The shared 1.2s grip deadline also guarantees release if swallowing fails.
