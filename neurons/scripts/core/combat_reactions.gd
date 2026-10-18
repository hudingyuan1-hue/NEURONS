extends RefCounted
## Only witnessed actions produce local reactions. Exact source lines, no new lore.
var owner_ref:WeakRef
var combat:
 get:return owner_ref.get_ref()
var app:
 get:return combat.app
func _init(owner) -> void:owner_ref=weakref(owner)

func normalize() -> void:
 for key in ["spoken","observed","visible_casts"]:
  if not combat.data.has(key):combat.data[key]={}
 if not combat.data.has("face_pending"):combat.data.face_pending={}

func visible(id:String,radius:float=6.0) -> bool:
 var a:Dictionary=combat.data.actors[id]
 return a.present and a.hp>0 and a.room==app.room_id and combat.position(id).distance_to(app.hero_pos)<=radius and combat.can_see(app.room_id,combat.position(id),app.hero_pos)

func safe() -> bool:
 if app.rules.hp<=0 or app.rules.gripped or app.rules.control_left>0 or app.rules.body_busy() or not app.dialogue_queue.is_empty():return false
 for id in combat.data.actors:
  var a:Dictionary=combat.data.actors[id]
  if a.present and a.hp>0 and a.hostile and a.room==app.room_id and (visible(id) or a.phase in ["windup","attack","grip"]):return false
 return true

func has_knee_history() -> bool:
 for fact in app.rules.facts:
  if fact.get("kind","")=="skill_reacted" and str(fact.get("skill",""))=="KNEE":return true
 return false

func on_skill(result:Dictionary) -> void:
 normalize()
 if not result.get("success",false) or not visible("double_face") or app.rules.stun_left>0:return
 var id:String=str(result.id)
 # These internal changes alone do not provide an external visible action.
 if id in ["DRYMOUTH","JOY"]:return
 combat.data.face_pending={"event":str(result.event_id),"skill":id,"at":combat.xy(app.hero_pos),"facing":combat.xy(app.hero_facing),"age":0.0,"turning":false,"elapsed":0.0}

func tick(delta:float) -> void:
 normalize()
 _face(delta)
 for id in ["dog","nurse","corner","faceless","double_face"]:
  if not visible(id,4.0):continue
  var a:Dictionary=combat.data.actors[id]
  var acted:bool=(id=="dog") or (id=="nurse" and float(combat.data.bandage_elapsed)>0) or (id=="corner" and a.phase=="point") or (id=="faceless" and float(combat.data.cart_shift)>0) or (id=="double_face" and a.get("face_turned",false))
  if combat.chapter_id==6 and id=="faceless":acted=float(combat.materials.state().faceless.shift)>0
  if not acted:continue
  if not combat.data.observed.has(id):
   combat.data.observed[id]=true
   var text:String={"dog":"实际见到红项圈及护卫站位；未据此补写第一关死亡。","nurse":"实际见到小护士接触包扎；未删除先前登记与转运记录。","corner":"实际见到角落病友指向当前可达门道；不据此认定其为本身人格。","faceless":"实际见到空面人格推动同一辆档案车；未返还旧姓名索引。","double_face":"实际看见双面人格在目击身体动作后转向镜头；未因此认定玩家或本身人格身份。"}[id]
   if combat.chapter_id==6:
    if id=="faceless":text="实际看见空面人格推动同一堆检修杂物；没有返还此前被抽走的姓名标签。"
    elif id=="corner":text="实际看见角落病友指向侧室原入口；没有后门，也不保证入口外安全。"
   app.rules.observe("角色",("street_seen:" if combat.chapter_id==6 else "combat_seen:")+id,text,"亲历事实","S3第六关现场动作" if combat.chapter_id==6 else "S3第五关现场动作")
  if combat.data.spoken.has(id) or not safe():continue
  # Check the actual speaker again at dispatch. No posthumous queued line.
  if not combat.config.get("dialogue",{}).has(id):continue
  var line:Dictionary=combat.config.dialogue[id]
  combat.data.spoken[id]=true
  app.add_dialogue(str(line.speaker),str(line.text))
  app.rules._record("combat_line_spoken","combat_line:%d:%s"%[app.rules.actual_attempt,id],{"source":line.source,"actor":id})
  break

func _face(delta:float) -> void:
 var pending:Dictionary=combat.data.face_pending
 if pending.is_empty():return
 var watcher:Dictionary=combat.data.actors.double_face
 if not visible("double_face") or float(watcher.hurt)>0:
  combat.data.face_pending={};watcher.face_turn_progress=0.0;return
 pending.age+=delta
 if not pending.turning:
  var id:String=str(pending.skill)
  var moved:bool=app.hero_pos.distance_to(combat.vector(pending.at))>.025
  var turned:bool=absf(app.hero_facing.angle_to(combat.vector(pending.facing)))>.12
  var actual:bool=moved or (id in ["GUT","WITHDRAW"] and app.rules.reaction_skill==id and app.rules.reaction_left>0) or (id=="KNEE" and not app.rules.action.is_empty()) or (id=="TINNITUS" and app.hero_state=="tinnitus") or (id=="PORES" and turned)
  if id=="CONTROL":actual=app.rules.control_left>0 and (moved or (not app.rules.action.is_empty() and app.rules.action.get("controlled",false)))
  if not actual:
   if pending.age>float(combat.config.test_parameters.visible_reaction_wait_s):combat.data.face_pending={}
   return
  combat.data.visible_casts[pending.event]=true
  if watcher.get("face_turned",false):combat.data.face_pending={};return
  pending.turning=true
 pending.elapsed+=delta
 watcher.face_turn_progress=clampf(float(pending.elapsed)/float(combat.config.test_parameters.face_turn_s),0,1)
 if watcher.face_turn_progress>=1:
  watcher.face_turned=true
  app.rules._record("combat_face_turned","face:"+str(pending.event),{"actor":"double_face","skill":pending.skill})
  combat.data.face_pending={}
