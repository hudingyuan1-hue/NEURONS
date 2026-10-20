extends RefCounted
## S3:P1619–1625/P1906–1913. Heard signal, received location and seen response differ.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func normalize() -> void:
 if not battle.data.has("report_events"):battle.data.report_events={}
 if not battle.data.has("report_looks"):battle.data.report_looks={}
 if not battle.data.has("report_speech"):battle.data.report_speech={}
func receivers(id:String) -> Array:
 var a:Dictionary=battle.data.actors[id];var found:Array=[]
 for other in battle.data.actors:
  var receiver:Dictionary=battle.data.actors[other]
  if other==id or not receiver.present or not receiver.hostile or receiver.hp<=0 or receiver.room!=a.room or str(other) in ["father","mother","cat","self","reverse","skinface","twitch"]:continue
  if battle.position(str(other)).distance_to(battle.position(id))<=float(battle.config.test_parameters.vision_m) and battle.can_see(str(a.room),battle.position(str(other)),battle.position(id)):found.append(str(other))
 return found
func _cancel(id:String) -> void:
 var a:Dictionary=battle.data.actors[id]
 a.report_target=[];a.report_elapsed=0.0;a.report_event="";a.phase="idle"
func _side(id:String,delta:float) -> void:
 var a:Dictionary=battle.data.actors[id];var at:Vector2=battle.position(id)
 if a.get("report_side_goal",[]).is_empty():
  var floor=battle.floor_for(str(a.room));var size:Vector2=floor.world_size()
  var goal:=Vector2(at.x,1.05 if at.y<size.y*.5 else size.y-1.05)
  if not floor.walkable(goal):return
  for to in battle.map.doors(str(a.room)):
   if goal.distance_to(floor.portal(str(to)).at)<1.2:return
  a.report_side_goal=battle.xy(goal)
 battle._move_actor(id,battle.vector(a.report_side_goal),delta)
func actor(id:String,delta:float) -> void:
 normalize();var a:Dictionary=battle.data.actors[id]
 if not a.present or a.hp<=0:return
 if a.hurt>0:
  if not a.get("report_hurt_seen",false):
   a.report_side_left=float(battle.config.test_parameters.display_retreat_s);a.report_side_goal=[];a.report_hurt_seen=true;a.report_side_reason="hurt"
  a.hurt=maxf(0,float(a.hurt)-delta);_cancel(id);return
 a.report_hurt_seen=false
 if a.room!=app.room_id:
  # A half-witnessed gesture is not completed remotely after the host leaves.
  if not str(a.get("report_event","")).is_empty():_cancel(id)
  return
 a.report_left=maxf(0,float(a.report_left)-delta)
 if float(a.get("report_side_left",0))>0:
  a.report_side_left=maxf(0,float(a.report_side_left)-delta);a.phase="report_retreat" if a.get("report_side_reason","")=="hurt" else "report_side"
  _side(id,delta)
  if a.report_side_left<=0:a.phase="idle";a.report_side_goal=[]
  return
 var eligible:Array=receivers(id)
 var event:Dictionary=battle.data.report_events.get(str(a.get("report_event","")),{})
 if event.is_empty():
  # Legacy unfinished gestures have no proved knock/receipt. Start a real new
  # gesture; never backfill a sound or receiver from its saved elapsed counter.
  if a.report_left>0 or eligible.is_empty() or not battle.reactions.visible(id):return
  a.signal_serial=maxi(int(a.get("signal_serial",0)),int(a.get("report_serial",0)))+1
  var receipt:String="street_report:%d:%s:%d"%[app.rules.actual_attempt,id,a.signal_serial]
  event={"id":receipt,"sender":id,"room":a.room,"at":battle.xy(app.hero_pos),"elapsed":0.0,"phase":"prepare" if id=="head_nurse" else "point","knocked":false,"heard":{},"seen":{},"pointer_seen":false,"hero_read":0.0,"delivered":false,"responded":{},"response_seen":false}
  if id=="informant":event.candidate=str(eligible[0])
  battle.data.report_events[receipt]=event;a.report_event=receipt;a.report_target=event.at.duplicate();a.report_elapsed=0.0
 if event.delivered:_cancel(id);return
 event.elapsed+=delta;a.report_elapsed=event.elapsed
 var prepare:float=float(battle.config.test_parameters.report_prepare_s)
 var knock:float=float(battle.config.test_parameters.report_knock_s)
 var point_start:float=prepare+knock if id=="head_nurse" else 0.0
 var point_time:float=float(battle.config.test_parameters.report_point_s) if id=="head_nurse" else 1.0
 if id=="head_nurse":
  if float(event.elapsed)<point_start and battle.reactions.visible(id):event.at=battle.xy(app.hero_pos);a.report_target=event.at.duplicate()
  if event.elapsed>=prepare and not event.knocked:
   event.knocked=true
   app.audio.cue("SFX_DRAWER",str(event.id)+":knock")
   for other in eligible:
    var listener:Dictionary=battle.data.actors[str(other)]
    if battle.noises.audible_distance(str(a.room),battle.position(id),str(listener.room),battle.position(str(other)))<=float(battle.config.test_parameters.hearing_m):event.heard[str(other)]=true
   app.rules._record("street_board_knocked",str(event.id)+":knock",{"actor":id,"room":a.room,"heard_by":event.heard.keys(),"source":"S3:P1620–1621"})
  if float(event.elapsed)<point_start:
   a.phase="board_raise" if event.elapsed<prepare else "board_knock";return
 elif not str(event.candidate) in eligible:_cancel(id);return
 event.phase="point";a.phase="point"
 a.direction=battle.xy((battle.vector(event.at)-battle.position(id)).normalized()) if id=="head_nurse" else battle.xy((battle.position(str(event.candidate))-battle.position(id)).normalized())
 var point_delta:float=clampf(float(event.elapsed)-point_start,0,delta)
 event.hero_read=float(event.get("hero_read",0))+point_delta if battle.materials.seen(str(a.room),battle.position(id),6) else 0.0
 event.pointer_seen=event.pointer_seen or float(event.hero_read)+.000001>=float(battle.config.test_parameters.report_signal_read_s)
 for other in eligible:
  if id=="informant" and str(other)!=str(event.candidate):continue
  if id=="head_nurse" and not event.heard.has(str(other)):continue
  event.seen[str(other)]=float(event.seen.get(str(other),0))+point_delta
 # A lost view cannot complete an unseen gesture by accumulating fragments.
 for other in event.seen.keys():
  if not str(other) in eligible:event.seen[other]=0.0
 if float(event.elapsed)+.000001<point_start+point_time:return
 var received:Array=[]
 for other in eligible:
  if float(event.seen.get(str(other),0))+.000001>=float(battle.config.test_parameters.report_signal_read_s):received.append(str(other))
 event.delivered=true
 var witnessed:bool=false
 for other in received:
  var recipient:Dictionary=battle.data.actors[str(other)]
  recipient.investigation={"room":a.room,"at":event.at.duplicate(),"receipt":event.id,"kind":"report"}
  if event.pointer_seen and battle.materials.seen(str(a.room),battle.position(str(other)),6):witnessed=true
  # Independent head/eye pose acknowledges this actual location. It never
  # changes locomotion, attack direction/hits/cooldown, or supplies new sight.
  if recipient.phase not in ["windup","attack","recover","grip","drug_hold"] and recipient.hurt<=0 and not battle.data.report_looks.has(str(other)):
   battle.data.report_looks[str(other)]={"receipt":event.id,"room":a.room,"at":event.at.duplicate(),"start":recipient.direction.duplicate(),"direction":recipient.direction.duplicate(),"elapsed":0.0,"progress":0.0,"at_start":recipient.pos.duplicate()}
 battle.data.reports[id]={"receipt":event.id,"at":event.at.duplicate(),"receiver":str(received[0]) if not received.is_empty() else "","receivers":received.duplicate(),"witnessed":witnessed}
 if not received.is_empty():
  a.report_serial=int(a.get("report_serial",0))+1
  app.rules._record("street_report_received",str(event.id),{"actor":id,"receivers":received.duplicate(),"room":a.room,"at":event.at.duplicate(),"witnessed":witnessed,"source":"S3:P1621/P1908–1910"})
 if id=="informant" and witnessed:app.rules.observe("角色","street_informant_point","实际看见通报者向眼前的敌对医护完成指示；未因此获得对方随后调查的全图位置。","亲历事实","S3:P1906–1913")
 a.report_left=8.0;_cancel(id)
 if id=="head_nurse":a.report_side_left=float(battle.config.test_parameters.display_retreat_s);a.report_side_goal=[];a.report_side_reason="complete"

func tick(delta:float) -> void:
 normalize()
 for id in battle.data.report_looks.keys():
  var look:Dictionary=battle.data.report_looks[id];var a:Dictionary=battle.data.actors[id]
  if not a.present or a.hp<=0 or a.hurt>0 or a.room!=look.room or a.room!=app.room_id or a.phase in ["windup","attack","recover","grip","drug_hold"]:
   battle.data.report_looks.erase(id);continue
  look.elapsed+=delta;look.progress=clampf(float(look.elapsed)/float(battle.config.test_parameters.report_look_s),0,1)
  var target:Vector2=(battle.vector(look.at)-battle.position(str(id))).normalized()
  var start:Vector2=battle.vector(look.start)
  var direction:Vector2=start.rotated(start.angle_to(target)*float(look.progress));look.direction=battle.xy(direction)
  var event:Dictionary=battle.data.report_events.get(str(look.receipt),{})
  if not event.is_empty():
   var turned:bool=absf(start.angle_to(direction))>=.12
   var approached:bool=battle.position(str(id)).distance_to(battle.vector(look.at_start))>.025 and battle.position(str(id)).distance_to(battle.vector(look.at))<battle.vector(look.at_start).distance_to(battle.vector(look.at))-.015
   if turned or approached:
    event.responded[str(id)]=true
    if event.pointer_seen and battle.materials.seen(str(a.room),battle.position(str(id)),6):event.response_seen=true
   if event.sender=="head_nurse" and event.response_seen:
    app.rules.observe("角色","street_head_report_response","实际看见护士长指向原目击位置，附近已有敌对医护接收后转头查看该方向；未获得敌人的全图视野，原攻击仍独立结算。","亲历事实","S3:P1620–1625")
  if float(look.elapsed)>=float(battle.config.test_parameters.report_look_s)+float(battle.config.test_parameters.report_look_hold_s):battle.data.report_looks.erase(id)
 if battle.data.report_speech.get("head_nurse",false) or not battle.materials.known("street_head_report_response") or not battle.reactions.safe():return
 var sender:Dictionary=battle.data.actors.head_nurse
 if not sender.present or sender.hp<=0 or sender.room!=app.room_id:return
 battle.data.report_speech.head_nurse=true;app.add_dialogue("角色 · 低声","她在指我的位置。")
