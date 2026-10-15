extends RefCounted
## Independent L1 hidden route. Parent advances NeuralRules once, then calls
## tick with the same running-world delta. data contains JSON primitives only.
const Plaza=preload("res://scripts/world/hidden_layout.gd")
var app
var data:Dictionary={}
var config:Dictionary={}

func _init(owner) -> void:
 app=owner
 config=JSON.parse_string(FileAccess.get_file_as_string("res://data/hidden_street.json"))

func xy(p:Vector2) -> Array:
 return [p.x,p.y]

func vector(value:Array) -> Vector2:
 return Vector2(float(value[0]),float(value[1]))

func position() -> Vector2:
 return vector(data.hunter.pos)

func active() -> bool:
 return not data.is_empty() and data.get("status","")=="active" and app.room_id=="hidden_street"

func start() -> void:
 app.layout=Plaza.new()
 app.room_id="hidden_street"
 app.hero_pos=vector(config.layout.entry)
 app.hero_route=PackedVector2Array()
 app.hero_state="idle"
 app.target_index=-1
 app.action_phase="autonomy"
 app.motion.clear()
 app.rules.cancel_search()
 app.rules.gripped=false
 app.rules.end_control()
 app.rules.action.clear()
 app.rules.pending_neural.clear();app.rules.pending_skin.clear()
 app.rules.transitioning=false
 app.rules.mode="combat"
 data={"status":"active","epoch":app.rules.actual_attempt,"serial":0,"hunter":{"pos":config.layout.hunter_start.duplicate(),"hp":int(config.rules.hunter_hp),"phase":"patrol","route":[],"left":0.0,"elapsed":0.0,"last_seen":[],"patrol_index":0,"locked":false,"direction":[0.0,1.0],"attack_id":"","attack_hit":false,"attack_had_target":false},"hero_perceived":false,"perceived_position":[],"route_left":0.0,"hero_goal":[],"seen_receipts":{},"pending_feedback":[],"feedback_receipts":{},"ending":{},"duck_left":0.0,"pending_achievements":[]}
 app.rules._record("hidden_street_entered",event_id("entry"),{"level":1,"hp":app.rules.hp,"sp":app.rules.sp})
 # No unlock/entry reward, growth, healing or inventory reset belongs here.

func event_id(node:String) -> String:
 return "hidden:%d:%s"%[int(data.epoch),node]

func tick(delta:float) -> void:
 if not active() or app.world_paused() or app.rules.loading or app.rules.transitioning or not is_finite(delta) or delta<=0:return
 # Small geometric steps prevent lunge tunnelling. These do not advance the
 # shared world/resource clock again and do not create attack identities.
 var left:float=delta
 while left>0.000001 and active():
  var step:float=minf(0.02,left)
  left-=step
  data.duck_left=maxf(0,float(data.duck_left)-step)
  _perceive()
  _advance_hunter(step)
  if app.rules.hp<=0:
   data.status="dead"
   app.hero_route=PackedVector2Array();app.motion.clear()
   return
  _advance_hero(step)
  commit_exit()
 _safe_feedback()

func _perceive() -> void:
 var h:Dictionary=data.hunter
 if int(h.hp)<=0:
  data.hero_perceived=false
  return
 var distance:float=position().distance_to(app.hero_pos)
 var sight:bool=app.layout.clear_segment(position(),app.hero_pos)
 var hunter_sees:bool=sight and distance<=float(config.test_parameters.hunter_vision_metres)
 data.hero_perceived=sight and distance<=float(config.test_parameters.hero_vision_metres)
 if data.hero_perceived:
  data.perceived_position=xy(position())
  queue_feedback("saw")
  app.rules.observe("人物","hidden_hunter","在独立广场片段实际看见一名追近、扑抓的猎手。")
 if hunter_sees:
  h.last_seen=xy(app.hero_pos)
  if h.phase in ["patrol","investigate"]:
   h.phase="chase";h.route=[];h.left=0.0
 elif h.phase=="chase":
  h.phase="investigate";h.route=[];h.left=float(config.test_parameters.investigate_seconds)

func _route_actor(goal:Vector2,delta:float,speed:float) -> bool:
 var h:Dictionary=data.hunter
 var route:=PackedVector2Array()
 for point in h.route:route.append(vector(point))
 if route.is_empty() and position().distance_to(goal)>0.04:route=app.layout.path(position(),goal)
 var moved:Dictionary=app.layout.move_path(position(),route,speed*delta)
 h.pos=xy(moved.position)
 h.route=[]
 for point in moved.route:h.route.append(xy(point))
 return position().distance_to(goal)<=0.04

func _advance_hunter(delta:float) -> void:
 var h:Dictionary=data.hunter
 if int(h.hp)<=0:return
 match str(h.phase):
  "patrol":
   var goal:Vector2=vector(config.layout.patrol[int(h.patrol_index)])
   if _route_actor(goal,delta,float(config.test_parameters.patrol_speed)):
    h.patrol_index=(int(h.patrol_index)+1)%config.layout.patrol.size()
  "chase":
   # Chase only the actually sampled, visible position. Occlusion changes the
   # state to investigate before this branch can follow a new hero location.
   var goal:Vector2=vector(h.last_seen)
   if position().distance_to(goal)<=float(config.test_parameters.attack_start_metres) and app.layout.clear_segment(position(),goal):
    _begin_attack()
   else:
    h.route=[]
    _route_actor(goal,delta,float(config.test_parameters.hunter_speed))
  "investigate":
   if h.last_seen.is_empty() or _route_actor(vector(h.last_seen),delta,float(config.test_parameters.hunter_speed)):
    h.left=maxf(0,float(h.left)-delta)
    if float(h.left)<=0:h.phase="patrol";h.route=[];h.last_seen=[]
   elif h.route.is_empty():
    # A previously seen point can become unreachable. Failed navigation is
    # not permission to track through the fountain or wait forever.
    h.phase="patrol";h.route=[];h.last_seen=[]
  "windup":
   h.elapsed=float(h.elapsed)+delta
   if not h.locked:
    if app.layout.clear_segment(position(),app.hero_pos):h.direction=xy((app.hero_pos-position()).normalized())
    if float(h.elapsed)>=float(config.rules.windup)*float(config.test_parameters.direction_lock_fraction):h.locked=true
   if float(h.elapsed)+0.000001>=float(config.rules.windup):h.phase="attack";h.elapsed=0.0
  "attack":
   _lunge(delta)
  "recover","cooldown","stagger":
   h.left=maxf(0,float(h.left)-delta)
   if float(h.left)<=0:
    if h.phase=="recover":h.phase="cooldown";h.left=float(config.rules.cooldown_after_recover)
    else:h.phase="investigate";h.left=float(config.test_parameters.investigate_seconds);h.route=[]

func _begin_attack() -> void:
 var h:Dictionary=data.hunter
 data.serial=int(data.serial)+1
 h.phase="windup";h.elapsed=0.0;h.route=[];h.locked=false
 h.direction=xy((app.hero_pos-position()).normalized())
 h.attack_id=event_id("attack:%d"%int(data.serial))
 h.attack_hit=false;h.attack_had_target=true
 app.rules._record("hunter_windup",h.attack_id,{"position":h.pos.duplicate()})

func _lunge(delta:float) -> void:
 var h:Dictionary=data.hunter
 var duration:float=float(config.rules.attack)
 var remaining:float=maxf(0,duration-float(h.elapsed))
 var active_delta:float=minf(delta,remaining)
 var from:Vector2=position()
 var direction:Vector2=vector(h.direction)
 var wanted:Vector2=from+direction*float(config.rules.lunge_max_metres)/duration*active_delta
 var to:Vector2=app.layout.clipped_step(from,wanted)
 h.pos=xy(to)
 if not h.attack_hit and _body_in_attack(from,to,direction):
  _hit_hero(str(h.attack_id))
  h.attack_hit=true
 h.elapsed=float(h.elapsed)+active_delta
 if float(h.elapsed)+0.000001>=duration or to.distance_to(wanted)>0.001:
  if not h.attack_hit and h.attack_had_target and app.rules.hp>0:queue_feedback("evaded")
  h.phase="recover";h.left=float(config.rules.recover);h.elapsed=0.0

func body_height() -> float:
 var standing:float=float(config.test_parameters.standing_body_height)
 if app.rules.reaction_skill!="GUT" or app.rules.reaction_left<=0:return standing
 var remain:float=float(data.duck_left)
 if remain<=0:return standing
 var total:float=float(app.rules.config.timing.gut_reaction)
 var elapsed:float=total-remain
 var depth:float=minf(clampf(elapsed/0.2,0,1),clampf(remain/0.2,0,1))
 return lerpf(standing,float(config.test_parameters.crouched_body_height),depth)

func _body_in_attack(from:Vector2,to:Vector2,direction:Vector2) -> bool:
 if body_height()<float(config.test_parameters.attack_trajectory_height):return false
 var across:Vector2=Vector2(-direction.y,direction.x)
 var offset:Vector2=app.hero_pos-from
 var along:float=offset.dot(direction)
 var length:float=from.distance_to(to)+float(config.test_parameters.attack_arm_reach)
 return along>=-app.layout.RADIUS and along<=length+app.layout.RADIUS and absf(offset.dot(across))<=float(config.test_parameters.attack_half_width)+app.layout.RADIUS and app.layout.clear_segment(to,app.hero_pos)

func _hit_hero(id:String) -> void:
 if not active() or app.rules.hp<=0 or app.rules.settled.has(id):return
 app.rules.settled[id]="hunter_hit"
 app.rules.hp=maxi(0,app.rules.hp-int(config.rules.attack_hp_damage))
 app.rules.cancel_search();app.rules.reaction_left=0;data.duck_left=0
 if not app.rules.pending_neural.is_empty():
  var pending_id:String=str(app.rules.pending_neural.event_id)
  if not app.rules.settled.has(pending_id):
   app.rules.settled[pending_id]="interrupted"
   app.rules._record("skill_interrupted",pending_id,{"cause":id})
 app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.action.clear()
 app.hero_route=PackedVector2Array();app.motion.clear()
 app.rules._record("hunter_hit",id,{"hp_damage":int(config.rules.attack_hp_damage),"sp_damage":0,"source":"hidden_hunter"})
 app.rules.vitality_lost.emit()
 if app.rules.hp<=0:
  app.rules.hurt_left=0;app.rules.stun_left=0;app.rules.end_control()
  data.pending_feedback=[]
 else:
  if app.rules.hurt_left<=0:app.rules.hurt_left=0.25
  queue_feedback("hit")
  app.rules.observe("人物",id,"猎手实际扑击命中，生命降低15。")

func _advance_hero(delta:float) -> void:
 if not app.rules.action.is_empty():
  app.rules.advance_kick(delta);kick_contact()
  app.hero_state="give"
  return
 if not app.motion.is_empty():
  if app.rules.hurt_left>0 or app.rules.stun_left>0:
   app.motion.clear();app.hero_route=PackedVector2Array();return
  if not app.rules.body_busy() and not app.rules.gripped:
   var moved:Dictionary=app.layout.move_path(app.hero_pos,app.hero_route,float(app.motion.speed)*delta)
   app.hero_pos=moved.position;app.hero_route=moved.route;app.hero_state="walk"
   if app.hero_route.is_empty():app.motion.clear();app.hero_state="idle"
  return
 if app.rules.body_busy() or app.rules.gripped:
  app.hero_state="hit" if app.rules.hurt_left>0 or app.rules.stun_left>0 or app.rules.reaction_skill=="GUT" else "give"
  return
 if app.rules.control_left>0:
  app.move_hero(delta)
  return
 data.route_left=maxf(0,float(data.route_left)-delta)
 var goal:Vector2=vector(config.layout.exit)
 if data.hero_perceived:
  var threat:Vector2=vector(data.perceived_position)
  if float(app.rules.effects.get("FEAR",0))>0:
   goal=_reachable_retreat(threat)
  elif data.hunter.phase=="windup" and position().distance_to(app.hero_pos)<2.1:
   goal=_reachable_side_step(vector(data.hunter.direction))
 if float(data.route_left)<=0 or app.hero_route.is_empty():
  data.hero_goal=xy(goal)
  app.hero_route=app.layout.path(app.hero_pos,goal)
  data.route_left=float(config.test_parameters.route_recheck)
 app.move_hero(delta)

func _reachable_side_step(direction:Vector2) -> Vector2:
 var side:=Vector2(-direction.y,direction.x)
 var best:Vector2=app.hero_pos
 var best_score:float=-INF
 for sign in [-1,1]:
  var endpoint:Vector2=app.layout.clipped_step(app.hero_pos,app.hero_pos+side*sign*float(config.test_parameters.dodge_distance))
  var score:float=endpoint.distance_to(app.hero_pos)-endpoint.distance_to(vector(config.layout.exit))*0.03
  if score>best_score:best=endpoint;best_score=score
 return best

func _reachable_retreat(threat:Vector2) -> Vector2:
 return app.layout.clipped_step(app.hero_pos,app.hero_pos+(app.hero_pos-threat).normalized()*float(config.test_parameters.dodge_distance))

func on_skill(result:Dictionary) -> void:
 if not active() or not result.get("success",false):return
 if str(result.get("id",""))=="GUT":data.duck_left=float(app.rules.config.timing.gut_reaction)
 if str(result.get("id",""))=="PORES" and data.hero_perceived:app.hero_facing=(vector(data.perceived_position)-app.hero_pos).normalized()
 data.route_left=0.0

func skill_context() -> Dictionary:
 return {"room":"hidden_street","action":"escape","target":"hidden_hunter" if data.get("hero_perceived",false) else "exit","perceived_threat":bool(data.get("hero_perceived",false)),"intent_point":config.layout.exit.duplicate()}

func kick_contact() -> void:
 if not active() or int(data.hunter.hp)<=0:return
 var offset:Vector2=position()-app.hero_pos
 var facing:Vector2=vector(app.rules.action.get("direction",[1,0])).normalized()
 if not app.rules.kick_contact("hidden_hunter",offset.length(),offset.normalized().dot(facing)>0.65,app.layout.clear_segment(app.hero_pos,position())):return
 data.hunter.hp=maxi(0,int(data.hunter.hp)-int(config.rules.kick_hp_damage))
 data.hunter.pos=xy(app.layout.clipped_step(position(),position()+facing*float(config.rules.kick_push_max_metres)))
 data.hunter.route=[]
 data.hunter.phase="dead" if int(data.hunter.hp)<=0 else "stagger"
 data.hunter.left=float(config.rules.kick_stagger)
 app.rules._record("hunter_kicked",str(app.rules.action.id)+":hunter",{"hp":data.hunter.hp,"no_drop":true})

func commit_exit() -> bool:
 if not active() or app.rules.hp<=0 or app.hero_pos.distance_to(vector(config.layout.exit))>float(config.test_parameters.exit_radius):return false
 var id:String=event_id("exit")
 if app.rules.settled.has(id):return false
 app.rules.settled[id]="E1"
 app.rules._record("ending",id,{"ending":"E1","level":1,"hp":app.rules.hp,"sp":app.rules.sp,"hallucinated_exit":true})
 app.rules.end_control();app.rules.cancel_search();app.rules.action.clear()
 app.rules.pending_neural.clear();app.rules.pending_skin.clear();app.rules.transitioning=true
 app.hero_route=PackedVector2Array();app.motion.clear()
 data.status="ending";data.hunter.route=[];data.pending_feedback=[]
 data.ending={"id":"E1","phase":"plaza","elapsed":0.0,"complete":false}
 data.pending_achievements=config.ending.global_keys.duplicate()
 return true

func advance_ending(delta:float) -> void:
 if data.is_empty() or data.get("status","")!="ending" or not is_finite(delta) or delta<=0:return
 if app.paused_manual or app.menu.visible or app.closing_left>0 or app.audio_panel.visible:return
 var ending:Dictionary=data.ending
 ending.elapsed=float(ending.elapsed)+delta
 var light:float=float(config.test_parameters.ending_light_seconds)
 var wake:float=float(config.test_parameters.ending_wake_seconds)
 ending.phase="plaza" if float(ending.elapsed)<light else "bed" if float(ending.elapsed)<light+wake else "complete"
 ending.complete=ending.phase=="complete"

func ending_frame() -> Dictionary:
 if data.is_empty() or data.get("status","")!="ending":return {}
 var elapsed:float=float(data.ending.elapsed)
 var light:float=float(config.test_parameters.ending_light_seconds)
 var wake:float=float(config.test_parameters.ending_wake_seconds)
 return {"id":"E1","phase":data.ending.phase,"title":config.ending.title,"achievement":config.ending.achievement,"light":clampf(elapsed/light,0,1),"wake":clampf((elapsed-light)/wake,0,1),"complete":data.ending.complete,"placeholder":true}

func queue_feedback(kind:String) -> void:
 if data.feedback_receipts.has(kind) or kind in data.pending_feedback:return
 data.pending_feedback.append(kind)

func _safe_feedback() -> void:
 if not active() or app.rules.hp<=0 or data.pending_feedback.is_empty():return
 if data.hunter.phase!="dead" and (data.hunter.phase!="patrol" or data.hero_perceived):return
 if not app.dialogue_queue.is_empty() or app.rules.control_left>0:return
 var kind:String=str(data.pending_feedback.pop_front())
 data.feedback_receipts[kind]=true
 for line in config.feedback[kind]:app.add_dialogue(str(line.speaker),str(line.text))

func actors() -> Array:
 if data.is_empty() or app.room_id!="hidden_street" or int(data.hunter.hp)<=0:return []
 return [{"type":"actor","data":"hidden_hunter","depth":app.layout.project(position()).y}]

func blocks_hero() -> bool:
 return not data.is_empty() and data.get("status","") in ["dead","ending"]
