extends RefCounted
## S3 Street displays: physical exposure, witnessed actions and knowledge stay separate.
const IDS=["register_nurse","back","wheelchair","transport_patient","postop","triage","blind","mimic"]
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func normalize() -> void:
 if not battle.data.has("displays"):battle.data.displays={"actors":{},"spoken":{}}
 if not battle.data.displays.has("linen"):battle.data.displays.linen={"read":0.0,"seen":false,"matched":false}
 for id in IDS:
  if not battle.data.displays.actors.has(id):
   battle.data.displays.actors[id]={"elapsed":0.0,"read":{},"near":false,"phase":"idle","front":false,"back":false,"turned":false,"protected_seen":false,"read_seen":false,"sample":{},"serial":0,"action":{},"cooldown":0.0}
func state(id:String) -> Dictionary:
 normalize();return battle.data.displays.actors[id]
func sees(id:String,radius:float=3.0) -> bool:
 var a:Dictionary=battle.data.actors[id]
 return a.present and a.hp>0 and a.room==app.room_id and battle.materials.seen(str(a.room),battle.position(id),radius)
func read(id:String,key:String,delta:float,visible:bool) -> bool:
 var s:Dictionary=state(id)
 s.read[key]=float(s.read.get(key,0))+delta if visible else 0.0
 return float(s.read[key])+.000001>=float(battle.config.test_parameters.display_read_s)
func observe(id:String,text:String,source:String) -> void:app.rules.observe("角色",id,text,"亲历事实",source)
func _interrupt(id:String) -> void:
 var s:Dictionary=state(id);s.read.clear();s.elapsed=0.0
 if id=="mimic":s.action={};s.phase="idle";s.sample={}
 elif id=="postop":s.phase="done"
 elif id=="blind":s.phase="idle";s.cooldown=float(battle.config.test_parameters.cloth_cooldown_s)
func actor(id:String,delta:float) -> bool:
 if id not in IDS:return false
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 if not a.present or a.hp<=0:return true
 if a.hurt>0:
  if not s.get("hurt_interrupted",false):
   _interrupt(id);s.retreat_left=float(battle.config.test_parameters.display_retreat_s);s.hurt_interrupted=true
  a.hurt=maxf(0,float(a.hurt)-delta);a.phase="idle";return true
 if a.room!=app.room_id:
  s.read.clear();s.near=false;s.sample={}
  if id in ["mimic","blind"]:_interrupt(id);a.phase="idle"
  return true
 s.hurt_interrupted=false
 if float(s.get("retreat_left",0))>0:
  s.retreat_left=maxf(0,float(s.retreat_left)-delta);a.phase="display_retreat";_aside(id,delta);return true
 match id:
  "register_nurse":_register(delta)
  "back":_back(delta)
  "wheelchair","transport_patient":_patient(id,delta)
  "postop":_postop(delta)
  "triage":_triage(delta)
  "blind":_blind(delta)
  "mimic":_mimic(delta)
 # Wheelchair uses its complete footprint below; other passive figures yield normally.
 if id!="wheelchair" and (id not in ["blind","mimic"] or s.phase=="idle"):battle._yield(id,delta)
 return true

func _register(delta:float) -> void:
 var a:Dictionary=battle.data.actors.register_nurse;var s:Dictionary=state("register_nurse")
 s.elapsed=fmod(float(s.elapsed)+delta,float(battle.config.test_parameters.register_cycle_s))
 a.phase="stamp" if s.elapsed<.7 else "number_show" if s.elapsed<2.3 else "paper_stow"
 if read("register_nurse","sheet",delta,a.phase=="number_show" and sees("register_nurse",2.2)):
  s.read_seen=true
  observe("street_register_sheet","实际看见登记护士在空白表格盖章并展示号码纸；具体字形未交付，不能确认与自己的腕带相同或不同。未重新挂号或改写身份。","S3:P1613–1618")

func _back(delta:float) -> void:
 var a:Dictionary=battle.data.actors.back;var s:Dictionary=state("back")
 var near:bool=sees("back",2.5)
 if not s.turned:
  a.phase="number_front"
  if read("back","front",delta,near):s.front=true;observe("street_back_front","实际看见背身人朝外的一面编号；尚不构成看过另一面，也不是角色的编号。","S3:P1627–1628")
  if near:s.elapsed+=delta
  else:s.elapsed=0.0
  if s.elapsed>=float(battle.config.test_parameters.back_front_s):s.turned=true;s.elapsed=0.0
 else:
  s.elapsed=minf(float(battle.config.test_parameters.face_turn_s),float(s.elapsed)+delta)
  a.phase="number_turn" if s.elapsed<float(battle.config.test_parameters.face_turn_s) else "number_back"
  if read("back","back",delta,a.phase=="number_back" and near):s.back=true;observe("street_back_reverse","实际看见同一背身人的另一面编号和不完整面孔；没有产生第二个人物身份。","S3:P1627–1631")

func chair_rect(at:Vector2) -> Rect2:
 var width:float=float(battle.config.test_parameters.chair_width_m)
 return Rect2(at-Vector2.ONE*width*.5,Vector2.ONE*width)
func chair_present(room:String) -> bool:
 var a:Dictionary=battle.data.actors.get("wheelchair",{})
 return not a.is_empty() and a.present and a.room==room
func blocks(room:String,point:Vector2,radius:float,exclude:String="") -> bool:
 if exclude=="wheelchair" or not chair_present(room):return false
 var rect:Rect2=chair_rect(battle.position("wheelchair"))
 return rect.has_point(point) or point.distance_to(point.clamp(rect.position,rect.end))<=radius
func _chair_clear(at:Vector2) -> bool:
 var a:Dictionary=battle.data.actors.wheelchair;var floor=battle.floor_for(str(a.room));var radius:float=float(battle.config.test_parameters.chair_width_m)*.71
 if not floor.walkable(at,radius) or battle.bed_blocks(str(a.room),at,radius,"wheelchair"):return false
 if app.hero_pos.distance_to(at)<radius+.21:return false
 for other in battle.data.actors:
  var body:Dictionary=battle.data.actors[other]
  if other!="wheelchair" and body.present and body.hp>0 and body.room==a.room and at.distance_to(battle.position(str(other)))<radius+.21:return false
 return true
func _aside(id:String,delta:float) -> void:
 var at:Vector2=battle.position(id);var size:Vector2=app.layout.world_size()
 # Select a nearby legal wall-side position, never a doorway or a new route.
 var left:bool=at.y<size.y*.5;var goal:=Vector2(at.x,1.15 if left else size.y-1.15)
 if id=="wheelchair":
  var step:Vector2=at.move_toward(goal,float(battle.config.test_parameters.actor_speed_m_s)*delta)
  if _chair_clear(step):battle.data.actors[id].pos=battle.xy(step)
 elif app.layout.walkable(goal):battle._move_actor(id,goal,delta)
func _point_entry(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var door:String=str(battle.map.doors(str(a.room))[0])
 a.direction=battle.xy((battle.floor_for(str(a.room)).portal(door).at-battle.position(id)).normalized())
func _patient(id:String,delta:float) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 var danger:String=battle.materials.danger(id)
 if not danger.is_empty():
  a.phase="protect_photo" if id=="wheelchair" else "protect_body";_aside(id,delta)
  if id=="wheelchair" and sees(id):s.protected_seen=true;observe("street_photo_protected","实际看见轮椅患者护住照片的动作；不据此认定旧照片原件已找回或另取得第二份照片。","S3:P1650–1655")
 elif sees(id,4):
  s.elapsed+=delta;_point_entry(id)
  if id=="wheelchair":_aside(id,delta);a.phase="chair_aside" if s.elapsed<.8 else "entry_point"
  else:
   a.phase="band_raise" if s.elapsed<1.3 else "entry_point"
   if read(id,"band",delta,a.phase=="band_raise" and sees(id,2.2)):
    s.read_seen=true;observe("street_patient_band","实际看见活着的被转运患者举起自己的腕带。字形未核，未与旧转运床上的患者建立编号对应，也没有交付第二条腕带。","S3:P1656–1662")
 else:a.phase="idle";s.elapsed=0.0;s.read.clear()

func _postop(delta:float) -> void:
 var id:String="postop";var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id);var near:bool=sees(id,3)
 if not battle.materials.danger(id).is_empty():a.phase="dressing_cover";s.phase="done";s.read.clear();_aside(id,delta);return
 if not near:s.near=false;s.phase="idle";s.elapsed=0.0;s.read.clear();a.phase="idle";return
 if not s.near:s.near=true;s.phase="uncover";s.elapsed=0.0
 if s.phase=="done":a.phase="idle";return
 s.elapsed+=delta
 a.direction=battle.xy((app.hero_pos-battle.position(id)).normalized())
 if s.phase=="uncover":
  a.phase="dressing_open"
  if s.elapsed>=.3:s.phase="show";s.elapsed=0.0
 elif s.phase=="show":
  a.phase="dressing_show"
  if read(id,"cancelled",delta,sees(id,2.2)):
   s.read_seen=true;observe("street_postop_cancelled","实际读到术后病友敷料下的“注销”标记，同时确认眼前病友仍活着；不将注销解释为死亡，不扩大旧伤。具体编号未交付。","S3:P1663–1668")
  if s.elapsed>=float(battle.config.test_parameters.dressing_show_s):s.phase="cover";s.elapsed=0.0
 else:
  a.phase="dressing_cover"
  if s.elapsed>=.3:s.phase="done"

func _triage(delta:float) -> void:
 var id:String="triage";var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 var mouth:Dictionary=battle.floor_for(str(a.room)).portal("street_maintenance")
 var portal:Vector2=mouth.at if not mouth.is_empty() else Vector2(-1,-1)
 if portal.x<0 or not battle.can_see(str(a.room),battle.position(id),portal):a.phase="idle";s.read.clear();return
 s.elapsed=fmod(float(s.elapsed)+delta,float(battle.config.test_parameters.guide_cycle_s))
 a.phase="branch_point" if s.elapsed<1.5 else "clip_read"
 a.direction=battle.xy((portal-battle.position(id)).normalized())
 if read(id,"clip",delta,a.phase=="clip_read" and sees(id,2.2)):
  s.read_seen=true;observe("street_guide_clip","实际看见导诊护士打开的号码夹内仍有转运批次栏；未看见完整旧转运记录，具体批次字形未交付，不建立本人对应。","S3:P1735–1741")

func _blind(delta:float) -> void:
 var id:String="blind";var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 s.cooldown=maxf(0,float(s.cooldown)-delta)
 var moved:bool=not s.sample.is_empty() and app.hero_pos.distance_to(battle.vector(s.sample.at))>.0001 and app.hero_state=="walk"
 s.sample={"at":battle.xy(app.hero_pos)}
 # Cloth blocks sight, not footsteps. Static walls still block this local hearing ray.
 var heard:bool=moved and battle.position(id).distance_to(app.hero_pos)<=float(battle.config.test_parameters.cloth_hearing_m) and battle.floor_for(str(a.room)).clear_segment(battle.position(id),app.hero_pos,0)
 if s.phase=="idle" and s.cooldown<=0 and heard:s.phase="raise";s.elapsed=0.0
 if s.phase=="idle":a.phase="idle";return
 s.elapsed+=delta
 if s.phase=="raise":
  a.phase="cloth_raise"
  if s.elapsed>=.3:s.phase="hold";s.elapsed=0.0
 elif s.phase=="hold":
  a.phase="cloth"
  if s.elapsed>=float(battle.config.test_parameters.cloth_hold_s):s.phase="close";s.elapsed=0.0
 else:
  a.phase="cloth_close"
  if s.elapsed>=.3:s.phase="idle";s.cooldown=float(battle.config.test_parameters.cloth_cooldown_s);a.phase="idle"

func _mimic(delta:float) -> void:
 var id:String="mimic";var a:Dictionary=battle.data.actors[id];var s:Dictionary=state(id)
 if not sees(id,6):_interrupt(id);a.phase="idle";return
 var old:Dictionary=s.sample;var moved:bool=not old.is_empty() and app.hero_pos.distance_to(battle.vector(old.at))>.001
 var gesture:String=""
 if not old.is_empty():
  if old.moving and not moved and app.hero_state=="idle":gesture="stop"
  elif absf(app.hero_facing.angle_to(battle.vector(old.facing)))>.12:gesture="turn"
  elif app.hero_state!=str(old.pose) and app.hero_state in ["give","scratch","tinnitus"]:gesture=app.hero_state
  elif app.hero_state!=str(old.pose) and app.hero_state=="hit" and app.rules.hurt_left>0:gesture="hit"
 s.sample={"at":battle.xy(app.hero_pos),"facing":battle.xy(app.hero_facing),"pose":app.hero_state,"moving":moved}
 # Sample continuously while busy, but discard other actions instead of queuing a history.
 if s.phase=="idle" and not gesture.is_empty():
  s.serial+=1;s.action={"kind":gesture,"room":app.room_id,"at":battle.xy(app.hero_pos),"origin":"controlled" if (app.controlled_route and app.rules.control_left>0) or (not app.rules.action.is_empty() and app.rules.action.get("controlled",false)) else "autonomous","receipt":"street_mimic:%d:%d"%[app.rules.actual_attempt,s.serial]};s.phase="copy";s.elapsed=0.0
 if s.phase=="idle":a.phase="idle";return
 s.elapsed+=delta
 if s.phase=="copy":
  a.phase="mimic";a.mimic=s.action.kind
  if sees(id,4):s.protected_seen=true;observe("street_mimic_seen","实际看见复述者在原地模仿刚才的可见动作；没有替角色移动、踢击或完成互动。","S3:P1914–1921")
  if s.elapsed>=float(battle.config.test_parameters.mimic_copy_s):s.phase="write";s.elapsed=0.0
 else:
  a.phase="mimic_write"
  if s.elapsed+.000001>=float(battle.config.test_parameters.mimic_write_s):
   var record:Dictionary=s.action.duplicate(true);record.id=record.receipt;record.text="自主行为";record.source="Street复述者胸前记录板；分类不改写实际动作来源"
   app.rules.institutional_records.append(record)
   app.rules._record("street_mimic_written",str(record.id),{"action":record.kind,"actual_origin":record.origin,"source":"S3:P1916–1919"})
   s.last_written=true;s.action={};s.phase="idle";s.elapsed=0.0;a.phase="idle"

func linen_reunion(delta:float) -> void:
 var s:Dictionary=battle.data.displays.linen
 var visible:bool=app.rules.hp>0 and app.rules.hurt_left<=0 and app.rules.stun_left<=0 and not app.rules.gripped and sees("transporter_hospital",3.0)
 s.read=float(s.read)+delta if visible else 0.0
 if visible and float(s.read)+.000001>=float(battle.config.test_parameters.display_read_s):
  s.seen=true
  observe("street_linen_porter_seen","实际近处看见灰色工服、手套及绕在前臂的污衣袋带；只记录当前人物外观，不从存根推导曾见其搬运。","S3:P1607–1612")
  if "hospital_bag_carry_seen" in app.rules.known:
   s.matched=true
   observe("street_linen_porter_reunion","与医院实际目击搬运污衣袋的经历对照，认出眼前搬袋人；不依赖编号对应、不新增身份或第四面墙证据。","S3:P1612")

func tick(delta:float=0.0) -> void:
 normalize()
 linen_reunion(delta)
 if not battle.reactions.safe():return
 var linen:Dictionary=battle.data.displays.linen
 var porter:Dictionary=battle.data.actors.transporter_hospital
 if linen.matched and not battle.data.displays.spoken.has("transporter_hospital") and porter.present and porter.hp>0 and porter.room==app.room_id:
  battle.data.displays.spoken.transporter_hospital=true;app.add_dialogue("角色 · 低声","是那个搬袋子的人。");return
 for item in [["back",state("back").front and state("back").back,"转过来，还是没有脸。"],["wheelchair",state("wheelchair").protected_seen,"他还护着那张照片。"],["postop",state("postop").read_seen,"人还在，编号却注销了。"],["triage",state("triage").read_seen,"夹子里还有转运批次。"],["mimic",state("mimic").protected_seen,"它在学我。"],["informant",battle.materials.known("street_informant_point"),"在给他们指路。"]]:
  if not item[1] or battle.data.displays.spoken.has(item[0]) or not sees(str(item[0]),4):continue
  battle.data.displays.spoken[item[0]]=true;app.add_dialogue("角色 · 低声",str(item[2]));return
