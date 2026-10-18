extends RefCounted
## S3:P1900–1905. Same physical floor surface as cleaner/reader, never a new paper.
var owner_ref:WeakRef
var battle:
 get:return owner_ref.get_ref()
var app:
 get:return battle.app
func _init(owner) -> void:owner_ref=weakref(owner)
func state() -> Dictionary:
 if not battle.data.has("archivist_papers"):
  battle.data.archivist_papers={"phase":"idle","target":"","elapsed":0.0,"hero_visible":false,"folder":[],"witnessed_read":{},"spoken":false}
 return battle.data.archivist_papers
func eligible(item:Dictionary) -> bool:
 return battle.materials.available(item) and (str(item.kind)=="number_paper" or (str(item.kind)=="label" and item.has("number_glyph")))
func _cancel() -> void:
 var s:Dictionary=state();var a:Dictionary=battle.data.actors.archivist_asylum
 s.phase="idle";s.target="";s.elapsed=0.0
 if a.phase in ["paper_approach","paper_pick","paper_store"]:a.phase="idle"
func _visible() -> bool:return battle.reactions.visible("archivist_asylum")
func actor(delta:float) -> bool:
 var a:Dictionary=battle.data.actors.archivist_asylum;var s:Dictionary=state()
 if not a.present or a.hp<=0:return true
 if a.hurt>0:
  if s.phase!="store":_cancel()
  return false # Existing damage clock and attack recovery remain authoritative.
 if a.room!=app.room_id:
  if s.phase!="store":_cancel()
  return false
 if a.phase in ["windup","attack","recover","grip"]:return false
 var visible:bool=_visible();var item:Dictionary=battle.materials.state().surfaces.get(str(s.target),{})
 if s.phase=="idle":
  # An already established pursuit/follow is not interrupted to service paper.
  if not str(a.follow).is_empty() or not a.last_seen.is_empty():return false
  var nearest:float=float(battle.config.test_parameters.archivist_paper_range_m)
  for key in battle.materials.state().surfaces:
   var candidate:Dictionary=battle.materials.state().surfaces[key];var at:Vector2=battle.vector(candidate.pos)
   if candidate.room!=a.room or not eligible(candidate):continue
   var distance:float=battle.position("archivist_asylum").distance_to(at)
   if distance<nearest and battle.can_see(str(a.room),battle.position("archivist_asylum"),at) and not app.layout.path(battle.position("archivist_asylum"),at).is_empty():item=candidate;s.target=str(key);nearest=distance
  if item.is_empty():return false
  s.phase="approach";s.elapsed=0.0;s.hero_visible=visible
 if item.is_empty():_cancel();return false
 var in_hand:bool=item.holder=="street_archivist:hand"
 # A newly rediscovered host takes priority. A held original stays held; no
 # cooldown reset, reappearance on the floor or second pickup is performed.
 if visible and (not s.hero_visible or battle.position("archivist_asylum").distance_to(app.hero_pos)<=float(battle.config.attacks[str(battle.spec("archivist_asylum").attack)].reach)+.25):
  s.hero_visible=true
  if not in_hand:_cancel()
  return false
 s.hero_visible=visible
 if visible:a.last_seen=battle.xy(app.hero_pos);a.last_seen_at=battle.data.clock
 if in_hand:
  s.phase="store";a.phase="paper_store";s.elapsed+=delta
  if s.elapsed+.000001>=float(battle.config.test_parameters.archivist_store_s):
   item.holder="street_archivist:folder";s.folder.append(str(item.id))
   var original:String=str(item.get("original_id",""))
   if not original.is_empty():app.rules.owners[original]="street_archivist:folder"
   var witnessed:bool=battle.materials.seen(str(a.room),battle.position("archivist_asylum"),3)
   if item.get("read_complete",false) and witnessed:s.witnessed_read[str(item.id)]=str(a.room)
   app.rules._record("street_paper_filed","street_file:%d:%s"%[app.rules.actual_attempt,item.id],{"actor":"archivist_asylum","paper":item.id,"original_id":original,"witnessed":witnessed,"read_before":item.get("read_complete",false),"source":"S3:P1902–1905"})
   _cancel()
  a.cooldown=maxf(0,float(a.cooldown)-delta);return true
 if not eligible(item):_cancel();return false
 var at:Vector2=battle.vector(item.pos)
 if not battle.can_see(str(a.room),battle.position("archivist_asylum"),at):_cancel();return false
 battle._move_actor("archivist_asylum",at,delta)
 a.cooldown=maxf(0,float(a.cooldown)-delta)
 if battle.position("archivist_asylum").distance_to(at)>.09:a.phase="paper_approach";return true
 s.phase="pick";a.phase="paper_pick";s.elapsed+=delta
 if s.elapsed+.000001<float(battle.config.test_parameters.archivist_pick_s):return true
 # Eligibility is rechecked at the actual contact commit, not reserved at plan time.
 if not eligible(item):_cancel();return false
 item.holder="street_archivist:hand";item.progress=1.0;s.phase="store";s.elapsed=0.0
 var original:String=str(item.get("original_id",""))
 if not original.is_empty():app.rules.owners[original]="street_archivist:hand"
 app.rules._record("street_paper_lifted","street_lift:%d:%s"%[app.rules.actual_attempt,item.id],{"paper":item.id,"actor":"archivist_asylum","source":"S3:P1902–1904"})
 return true
func tick() -> void:
 var s:Dictionary=state();var a:Dictionary=battle.data.actors.archivist_asylum
 var carried:Array=s.folder.duplicate()
 if not str(s.target).is_empty():carried.append(str(s.target))
 for key in carried:
  var paper:Dictionary=battle.materials.state().surfaces.get(str(key),{})
  if not paper.is_empty() and paper.holder in ["street_archivist:hand","street_archivist:folder"]:
   paper.room=a.room;paper.pos=a.pos.duplicate()
 if s.spoken or not battle.reactions.safe() or not app.room_id in s.witnessed_read.values():return
 s.spoken=true;app.add_dialogue("角色 · 低声","收走了，也改不了我看见的。")
