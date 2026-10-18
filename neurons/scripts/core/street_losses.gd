extends RefCounted
## S3:P1670–1676/P1932–1942. Actual loss, body gain and witnessed knowledge differ.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func state() -> Dictionary:
 # Legacy completed deaths have no proved pending dialogue: do not replay them.
 if not battle.data.has("loss_reactions"):
  battle.data.loss_reactions={"pending":[],"acknowledged":{},"pose_left":0.0}
 return battle.data.loss_reactions
func eligible_source(source:String) -> bool:
 if not battle.data.actors.has(source):return false
 var spec:Dictionary=battle.spec(source)
 return not str(spec.get("attack","")).is_empty() and (spec.get("relation","")=="enemy" or battle.data.actors[source].hostile)
func record(source:String,target:String,was_alive:bool,receipt:String) -> void:
 if not was_alive or battle.data.actors[target].hp>0 or target not in battle.config.good_ids or battle.data.speed_deaths.has(target) or not eligible_source(source):return
 var body:Dictionary=battle.data.actors[target];var attacker:Dictionary=battle.data.actors[source]
 var witnessed:bool=body.room==app.room_id and attacker.room==body.room and battle.position(target).distance_to(app.hero_pos)<=float(battle.config.test_parameters.hero_vision_m) and battle.can_see(str(body.room),app.hero_pos,battle.position(target)) and battle.can_see(str(body.room),app.hero_pos,battle.position(source))
 var old:int=int(battle.data.speed_stacks);var alive:bool=app.rules.hp>0
 battle.data.speed_deaths[target]={"source":source,"receipt":receipt,"witnessed":witnessed}
 if alive:battle.data.speed_stacks=mini(3,old+1)
 app.rules._record("street_good_death",receipt+":growth",{"target":target,"source":source,"stacks":battle.data.speed_stacks,"qualified":alive,"eligible_source":true,"bonus_awarded":int(battle.data.speed_stacks)>old,"witnessed":witnessed})
 if not alive:return
 var reaction:Dictionary=state()
 reaction.pending.append({"id":receipt+":loss_reaction","target":target,"source":source,"witnessed":witnessed,"attempt":app.rules.actual_attempt})
 reaction.pose_left=float(battle.config.test_parameters.loss_feedback_s)
 if int(battle.data.speed_stacks)>old:
  app.status_note="身体的步伐明显加快；已成立的移动变化不会解除抓握或恢复伤情。"
  app.rules.observe("角色","street_speed:%d:%d"%[app.rules.actual_attempt,battle.data.speed_stacks],"实际感觉步伐加快；未因此自动确定未目击的死者或凶手。","亲历事实","S3:P1934–1942")
 if witnessed:
  app.rules.observe("角色","street_loss_seen:%d:%s"%[app.rules.actual_attempt,target],"实际看见现场攻击造成该人物死亡；没有重播早先关卡死亡、恢复物品或取得额外身份认知。","亲历事实","S3:P1671–1675/P1934")
func close_attempt() -> void:
 var s:Dictionary=state()
 for event in s.pending:s.acknowledged[str(event.id)]="expired_at_exit"
 s.pending=[];s.pose_left=0.0
func tick(delta:float) -> void:
 var s:Dictionary=state()
 if app.rules.hp<=0:s.pose_left=0.0;return
 if int(app.session.data.level)!=6 or not battle.data.ending.is_empty():close_attempt();return
 s.pose_left=maxf(0,float(s.pose_left)-delta)
 if s.pending.is_empty() or not battle.reactions.safe():return
 # One safe-gap line acknowledges the individually recorded pending losses.
 # It neither identifies an unseen killer nor repeats seven identical lines.
 var batch:Array=s.pending.duplicate(true);s.pending=[];var fresh:bool=false
 for event in batch:
  if int(event.attempt)!=app.rules.actual_attempt or s.acknowledged.has(str(event.id)):continue
  s.acknowledged[str(event.id)]="spoken";fresh=true
  app.rules._record("street_loss_reaction",str(event.id),{"target":event.target,"witnessed":event.witnessed,"source":"S3:P1674/P1942"})
 if fresh:app.add_dialogue("角色 · 疯癫","还没完……还没完……")
