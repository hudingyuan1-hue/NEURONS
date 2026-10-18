extends RefCounted
## S3:P1764–1771/P1801–1812/P1820–1824: physical progress is not knowledge.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)

func normalize() -> void:
 if battle.data.has("materials"):
  if not battle.data.materials.has("faceless"):battle.data.materials.faceless={"shift":0.0,"done":false}
  return
 battle.data.materials={"speaker":{"tear":0.0,"holder":"neck","seen":false},"pharmacist":{"elapsed":0.0,"seen":false},"cleaner":{"target":"","elapsed":0.0,"phase":"park","bag":[],"pickup_seen":false},"stitched":{"tear":0.0},"faceless":{"shift":0.0,"done":false},"surfaces":{},"spoken":{}}
 for item in battle.config.materials.surfaces:
  var surface:Dictionary=item.duplicate(true);surface.progress=0.0;surface.holder="floor";surface.seen=false
  battle.data.materials.surfaces[str(item.id)]=surface

func state() -> Dictionary:
 normalize();return battle.data.materials
func seen(room:String,at:Vector2,distance:float=3.0) -> bool:
 return app.rules.hp>0 and room==app.room_id and at.distance_to(app.hero_pos)<=distance and battle.can_see(room,app.hero_pos,at)
func known(id:String) -> bool:
 if id in app.rules.known:return true
 for entry in app.rules.observations:
  if str(entry.id)==id and entry.kind=="亲历事实":return true
 return false
func danger(id:String) -> String:
 var a:Dictionary=battle.data.actors[id];var nearest:String="";var distance:float=6.0
 for other in battle.data.actors:
  var b:Dictionary=battle.data.actors[other]
  if other==id or not b.present or b.hp<=0 or not b.hostile or b.room!=a.room:continue
  var d:float=battle.position(id).distance_to(battle.position(str(other)))
  if d<distance and battle.can_see(str(a.room),battle.position(id),battle.position(str(other))):nearest=str(other);distance=d
 return nearest

func actor(id:String,delta:float) -> bool:
 if id not in ["speaker","treatment_pharmacist","cleaner","faceless"]:return false
 var a:Dictionary=battle.data.actors[id]
 if not a.present or a.hp<=0:return true
 normalize()
 if a.hurt>0:
  a.hurt=maxf(0,float(a.hurt)-delta);a.phase="idle";return true
 if a.room!=app.room_id:return true
 if id=="speaker":_speaker(delta)
 elif id=="treatment_pharmacist":_pharmacist(delta)
 elif id=="cleaner":_cleaner(delta)
 else:_faceless(delta)
 battle._yield(id,delta)
 return true

func _speaker(delta:float) -> void:
 var a:Dictionary=battle.data.actors.speaker;var s:Dictionary=state().speaker
 var enemy:String=danger("speaker")
 if not enemy.is_empty():
  a.phase="point";a.point_actor=enemy;a.direction=battle.xy((battle.position(enemy)-battle.position("speaker")).normalized())
 else:
  a.point_actor=""
  if s.holder=="neck":
   a.phase="tear";s.tear=minf(float(battle.config.test_parameters.paper_tear_s),float(s.tear)+delta)
   if s.tear+0.000001>=float(battle.config.test_parameters.paper_tear_s):
    s.holder="hand";a.phase="paper_hold"
    app.rules._record("street_paper_removed","street_paper:%d"%app.rules.actual_attempt,{"actor":"speaker","object":"street_speaker_strip","holder":"speaker:hand","source":"S3:P1766–1769"})
  else:a.phase="paper_hold"
 if not s.seen and seen(str(a.room),battle.position("speaker")):
  s.seen=true
  app.rules.observe("物品","street_statement_strip","实际读到颈部纸条原文：此前所述均不属实。另见断裂录音线；不构成当前自愿撤回，也不恢复未听到的录音。","亲历事实","S3:P1768–1769")

func _pharmacist(delta:float) -> void:
 var a:Dictionary=battle.data.actors.treatment_pharmacist;var s:Dictionary=state().pharmacist
 s.elapsed=fmod(float(s.elapsed)+delta,float(battle.config.test_parameters.empty_box_cycle_s))
 var t:float=float(s.elapsed);a.phase="box_flip" if t<.5 else "box_number" if t<2.0 else "box_stow"
 if a.phase=="box_number" and seen(str(a.room),battle.position("treatment_pharmacist"),2.0) and not s.seen:
  s.seen=true
  app.rules.observe("物品","street_empty_box_number","实际看见空药盒编号仍留着；具体编号字形尚未交付，未认作角色本人或建立旧批次对应。空盒与钥匙串未交付药物、通关钥匙。","亲历事实","S3:P1802–1805")

func add_trace(room:String,at:Vector2,receipt:String) -> void:
 var all:Dictionary=state().surfaces;var key:String="street_blood:"+receipt
 if all.has(key):return
 all[key]={"id":key,"room":room,"pos":battle.xy(at),"kind":"blood","progress":0.0,"holder":"floor","seen":false,"source":"actual_damage","original_id":""}

func available(item:Dictionary) -> bool:
 if item.holder!="floor" or float(item.progress)>=1:return false
 var original:String=str(item.get("original_id",""))
 # An already-owned original cannot reappear on the floor or be reclaimed.
 if not original.is_empty() and str(app.rules.owners.get(original,""))!="street_floor:"+str(item.id):return false
 return true

func _station(at:Vector2) -> Vector2:
 var a:Dictionary=battle.data.actors.cleaner;var floor=battle.floor_for(str(a.room))
 if floor.walkable(at):return at
 return Vector2(-1,-1)

func _refresh_region(space,bounds:Rect2) -> void:
 var area:Rect2=bounds.grow(space.body_radius+space.CELL)
 for y in range(floori(area.position.y/space.CELL),ceili(area.end.y/space.CELL)+1):
  for x in range(floori(area.position.x/space.CELL),ceili(area.end.x/space.CELL)+1):
   var cell:=Vector2i(x,y)
   if space.grid.region.has_point(cell):space.grid.set_point_solid(cell,not space.walkable(Vector2(cell)*space.CELL))

func _faceless(delta:float) -> void:
 var a:Dictionary=battle.data.actors.faceless;var s:Dictionary=state().faceless;var space=battle.floor_for(str(a.room))
 var debris:Dictionary={}
 for prop in space.furniture:
  if str(prop.id)==str(battle.config.materials.faceless.prop):debris=prop;break
 if debris.is_empty():a.phase="idle";return
 var rect:Rect2=debris.rect;var stand:=Vector2(rect.position.x-.4,rect.get_center().y)
 if s.done:
  var side:Vector2=stand+Vector2(0,.65)
  if space.walkable(side):battle._move_actor("faceless",side,delta)
  a.phase="idle";return
 battle._move_actor("faceless",stand,delta)
 if battle.position("faceless").distance_to(stand)>.08:a.phase="walk";return
 var shift:float=minf(delta*float(battle.config.test_parameters.debris_push_m_s),float(battle.config.test_parameters.debris_push_m)-float(s.shift))
 var moved:=Rect2(rect.position+Vector2(shift,0),rect.size);var swept:Rect2=rect.merge(moved)
 if swept.grow(.23).has_point(app.hero_pos):a.phase="idle";return
 for id in battle.data.actors:
  var body:Dictionary=battle.data.actors[id]
  if id!="faceless" and body.present and body.hp>0 and body.room==a.room and swept.grow(.25).has_point(battle.position(str(id))):a.phase="idle";return
 for other in space.furniture:
  if other.id!=debris.id and swept.grow(.025).intersects(other.rect):a.phase="idle";return
 if battle.bed_blocks(str(a.room),moved.get_center(),maxf(moved.size.x,moved.size.y)*.5,"faceless"):a.phase="idle";return
 # Preserve the same return route before committing any movement.
 var patch:Dictionary=battle.lateral_bed.push_blocker(space,swept)
 var clear:bool=true;var doors:Array=battle.map.doors(str(a.room))
 for from in doors:
  if not space.walkable(space.portal(str(from)).threshold):clear=false
  for to in doors:
   if from!=to and space.path(space.portal(str(from)).landing,space.portal(str(to)).threshold).is_empty():clear=false
 battle.lateral_bed.pop_blocker(space,patch)
 if not clear:a.phase="idle";return
 debris.rect=moved;s.shift+=shift;a.pos=battle.xy(battle.position("faceless")+Vector2(shift,0));a.phase="push"
 if not battle.data.prop_rects.has(str(a.room)):battle.data.prop_rects[str(a.room)]={}
 battle.data.prop_rects[str(a.room)][str(debris.id)]=[moved.position.x,moved.position.y,moved.size.x,moved.size.y]
 _refresh_region(space,swept)
 if float(s.shift)+.000001>=float(battle.config.test_parameters.debris_push_m):s.done=true

func _cleaner(delta:float) -> void:
 var a:Dictionary=battle.data.actors.cleaner;var s:Dictionary=state().cleaner
 var setting:Dictionary=battle.config.materials.cleaner
 var park:Vector2=battle.vector(setting.park)
 if s.phase=="park":
  a.phase="cart_park";battle._move_actor("cleaner",park,delta)
  if battle.position("cleaner").distance_to(park)<.08:s.phase="select"
  return
 if s.phase in ["bag","seal"]:
  a.phase="bag_label" if s.phase=="bag" else "bag_seal"
  battle._move_actor("cleaner",park,delta)
  if battle.position("cleaner").distance_to(park)>.08:return
  s.elapsed+=delta
  if s.elapsed+0.000001>=float(battle.config.test_parameters.cleaner_bag_s):
   if s.phase=="bag":
    var held:Dictionary=state().surfaces.get(str(s.target),{})
    if not held.is_empty() and held.holder=="cleaner:hand":
     held.holder="street_cleaner_bag";s.bag.append(str(held.id))
     var original:String=str(held.get("original_id",""))
     if not original.is_empty():app.rules.owners[original]="street_cleaner_bag"
   s.elapsed=0.0;s.phase="seal" if s.phase=="bag" else "select"
   if s.phase=="select":s.target=""
  return
 if not str(s.target).is_empty():
  var current:Dictionary=state().surfaces.get(str(s.target),{})
  if current.is_empty() or current.room!=a.room or not available(current):s.target=""
 if str(s.target).is_empty():
  var distance:float=3.0
  for key in state().surfaces:
   var item:Dictionary=state().surfaces[key];var at:Vector2=battle.vector(item.pos)
   if item.room!=a.room or not available(item):continue
   var d:float=battle.position("cleaner").distance_to(at)
   if d<distance and battle.can_see(str(a.room),battle.position("cleaner"),at) and _station(at).x>=0:s.target=str(key);distance=d
  if str(s.target).is_empty():a.phase="idle";return
 var item:Dictionary=state().surfaces[str(s.target)];var at:Vector2=battle.vector(item.pos)
 if not battle.can_see(str(a.room),battle.position("cleaner"),at):s.target="";return
 battle._move_actor("cleaner",at,delta)
 if battle.position("cleaner").distance_to(at)>.09:a.phase="walk";return
 # All progress requires physical contact. Hurt/death/room departure cannot complete it.
 var label:bool=str(item.kind) in ["label","number_paper"]
 a.phase="pick_label" if label else "wipe"
 var duration:float=float(battle.config.test_parameters.cleaner_pickup_s if label else battle.config.test_parameters.cleaner_wipe_s)
 item.progress=minf(1.0,float(item.progress)+delta/duration)
 if float(item.progress)+.000001<1:return
 item.progress=1.0
 if label:
  item.holder="cleaner:hand";s.phase="bag";s.elapsed=0.0
  if seen(str(a.room),at):s.pickup_seen=true
  var original:String=str(item.get("original_id",""))
  if not original.is_empty():app.rules.owners[original]="street_cleaner:hand"
 else:item.holder="cleaned";s.target=""
 app.rules._record("street_surface_processed","street_surface:%d:%s"%[app.rules.actual_attempt,item.id],{"id":item.id,"kind":item.kind,"room":a.room,"at":item.pos.duplicate(),"witnessed":seen(str(a.room),at),"source":"S3:P1807–1812"})

func tick() -> void:
 normalize()
 var c:Dictionary=state().cleaner
 if not battle.reactions.safe():return
 var candidates:Array=[
  ["speaker",state().speaker.seen and known("asylum_heard_retraction"),"不用再念了。"],
  ["treatment_pharmacist",state().pharmacist.seen,"盒子空了，编号还留着。"],
  ["cleaner",c.pickup_seen,"他连标签也收走了。"]]
 for item in candidates:
  var a:Dictionary=battle.data.actors[str(item[0])]
  if not item[1] or state().spoken.has(str(item[0])) or not a.present or a.hp<=0 or not seen(str(a.room),battle.position(str(item[0])),4):continue
  state().spoken[str(item[0])]=true;app.add_dialogue("角色 · 低声",str(item[2]));return

func prepare_stitched(delta:float) -> bool:
 var a:Dictionary=battle.data.actors.stitched;var s:Dictionary=state().stitched
 if not a.present or a.hp<=0:return false
 if float(s.tear)+.000001>=float(battle.config.test_parameters.paper_tear_s):return false
 if a.hurt>0:a.hurt=maxf(0,float(a.hurt)-delta);return true
 if a.phase not in ["tear","idle"]:return false
 if a.room!=app.room_id or battle.position("stitched").distance_to(app.hero_pos)>6 or not battle.can_see(str(a.room),battle.position("stitched"),app.hero_pos):
  if a.phase=="tear":a.phase="idle"
  return false
 a.phase="tear";s.tear=minf(float(battle.config.test_parameters.paper_tear_s),float(s.tear)+delta)
 if float(s.tear)+.000001>=float(battle.config.test_parameters.paper_tear_s):a.phase="idle"
 return true

func paper_entry(key:String) -> Dictionary:
 var item:Dictionary=state().surfaces.get(key,{})
 if item.is_empty() or item.room!=app.room_id or not battle.archivist.eligible(item):return {}
 var text:String=str(item.get("readable_text",""));var complete:bool=not text.is_empty()
 return {"id":key,"room":item.room,"props":[key],"description":text if complete else "实际看清落地标签的编号栏；具体字形未提供，未认定本人身份或取得完整纸面内容。","content_complete":complete,"surface":true,"source":item.source,"records":[]}
func surface_at(point:Vector2) -> String:
 for key in state().surfaces:
  var item:Dictionary=state().surfaces[key]
  if not paper_entry(str(key)).is_empty() and point.distance_to(battle.vector(item.pos))<.24:return str(key)
 return ""
func paper_read(key:String,complete:bool) -> void:
 var item:Dictionary=state().surfaces.get(key,{})
 if item.is_empty():return
 item.seen=true;item.read_complete=complete
