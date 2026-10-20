extends RefCounted
## Actual approach/read/compare. Unknown identity glyphs remain unknown.
var owner_ref:WeakRef
var combat:
 get:return owner_ref.get_ref()
var app:
 get:return combat.app
func _init(owner) -> void:owner_ref=weakref(owner)

func normalize() -> void:
 for key in ["inspection","inspected","inspection_lines"]:
  if not combat.data.has(key):combat.data[key]={}

func entry(prop:String) -> Dictionary:
 if combat.chapter_id==6:
  var paper:Dictionary=combat.materials.paper_entry(prop)
  if not paper.is_empty():return paper
 for item in combat.config.get("observations",[]):
  if item.room==app.room_id and prop in item.props:return item
 return {}

func station(rect:Rect2) -> Vector2:
 var nearest:=Vector2(-1,-1);var distance:float=INF
 for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  var p:Vector2=rect.get_center()+side*(rect.size*.5+Vector2.ONE*(app.layout.body_radius+.10))
  var route:PackedVector2Array=app.layout.path(app.hero_pos,p)
  if route.is_empty() or combat.bed_blocks(app.room_id,p,.21):continue
  var length:float=0
  for i in range(1,route.size()):length+=route[i-1].distance_to(route[i])
  if length<distance:distance=length;nearest=p
 return nearest

func begin(index:int,controlled:bool=true) -> bool:
 normalize()
 if index<0 or index>=app.layout.furniture.size() or app.rules.hp<=0 or app.rules.body_busy() or app.rules.gripped:return false
 if controlled and app.rules.control_left<=0:return false
 var prop:Dictionary=app.layout.furniture[index];var item:Dictionary=entry(str(prop.id))
 if item.is_empty():return false
 var at:Vector2=station(prop.rect)
 if at.x<0:return false
 cancel()
 combat.data.inspection={"room":app.room_id,"id":item.id,"prop":str(prop.id),"at":combat.xy(at),"phase":"approach","elapsed":0.0,"controlled":controlled}
 app.hero_route=app.layout.path(app.hero_pos,at);combat.data.controlled_door="";combat.data.door_left=-1.0
 app.rules.begin_public_action("observe",str(item.id),"control" if controlled else "autonomy",app.room_id)
 app.status_note="走近查看："+str(prop.name)
 return true

func begin_surface(key:String,controlled:bool=true) -> bool:
 normalize()
 if combat.chapter_id!=6 or app.rules.hp<=0 or app.rules.body_busy() or app.rules.gripped or (controlled and app.rules.control_left<=0):return false
 var item:Dictionary=entry(key)
 if item.is_empty():return false
 var surface:Dictionary=combat.materials.state().surfaces[key];var point:Vector2=combat.vector(surface.pos)
 var at:Vector2=station(Rect2(point-Vector2(.08,.05),Vector2(.16,.1)))
 if at.x<0:return false
 cancel();combat.data.inspection={"room":app.room_id,"id":key,"prop":key,"at":combat.xy(at),"phase":"approach","elapsed":0.0,"controlled":controlled,"surface":true}
 app.hero_route=app.layout.path(app.hero_pos,at);combat.data.controlled_door="";combat.data.door_left=-1.0
 app.rules.begin_public_action("observe",key,"control" if controlled else "autonomy",app.room_id)
 app.status_note="走近查看落地纸件。";return true

func cancel() -> void:
 normalize()
 if not combat.data.inspection.is_empty():app.rules.finish_public_action("control" if combat.data.inspection.get("controlled",false) else "autonomy")
 combat.data.inspection={}

func try_autonomous() -> void:
 normalize()
 if not combat.data.inspection.is_empty() or not combat.reactions.safe():return
 for i in range(app.layout.furniture.size()):
  var prop:Dictionary=app.layout.furniture[i];var item:Dictionary=entry(str(prop.id))
  if item.is_empty() or combat.data.inspected.get(str(item.id),{}).has(str(prop.id)):continue
  if skip_known_static(item,str(prop.id)):continue
  var at:Vector2=station(prop.rect)
  # Only something actually close to the autonomous route can attract a look.
  if at.x>=0 and at.distance_to(app.hero_pos)<.65:begin(i,false);return

 if combat.chapter_id==6:
  for key in combat.materials.state().surfaces:
   if entry(str(key)).is_empty() or combat.data.inspected.get(str(key),{}).has(str(key)):continue
   if combat.vector(combat.materials.state().surfaces[key].pos).distance_to(app.hero_pos)<.65:begin_surface(str(key),false);return

func skip_known_static(item:Dictionary,prop:String) -> bool:
 # S3:T59R5: a role that already chose escape need not stop again for the
 # same static original on a later return. New surface instances still pass
 # through their own live availability/ownership and actual-reading nodes.
 if item.get("surface",false) or app.character_presentation==null or not app.character_presentation.view_state().get("prioritize_escape",false):return false
 var receipt:String="combat_evidence:"+str(item.id)+":"+prop
 for observation in app.rules.observations:
  if str(observation.get("id",""))==receipt and str(observation.get("kind",""))=="亲历事实":return true
 return false

func advance(delta:float) -> bool:
 normalize()
 var state:Dictionary=combat.data.inspection
 if state.is_empty():return false
 if state.get("surface",false):
  if entry(str(state.prop)).is_empty():cancel();app.hero_route=PackedVector2Array();return false
  var paper:Dictionary=combat.materials.state().surfaces[str(state.prop)]
  if state.phase!="approach" and (app.hero_pos.distance_to(combat.vector(paper.pos))>1 or not combat.can_see(app.room_id,app.hero_pos,combat.vector(paper.pos))):cancel();app.hero_route=PackedVector2Array();return false
 if state.room!=app.room_id or app.rules.hp<=0 or app.rules.hurt_left>0 or app.rules.gripped or app.rules.stun_left>0:
  cancel();app.hero_route=PackedVector2Array();return false
 for id in combat.data.actors:
  var a:Dictionary=combat.data.actors[id]
  if a.present and a.hp>0 and a.hostile and a.room==app.room_id and combat.reactions.visible(str(id)):
   cancel();app.hero_route=PackedVector2Array();return false
 if state.phase=="approach":
  combat.move_hero(delta)
  if app.hero_pos.distance_to(combat.vector(state.at))>.04:
   if app.hero_route.is_empty():cancel();return false
   return true
  state.phase="original";state.elapsed=0;app.hero_state="search"
  if state.controlled:app.rules.controlled_execution("observe",str(state.id))
 state.elapsed+=delta
 app.hero_state="search"
 var half:float=float(combat.config.test_parameters.read_contact_s)*.5
 state.phase="original" if state.elapsed<half else "record"
 app.status_note=("查看原物／原始字段：" if state.phase=="original" else "对照机构记录：")+str(state.prop)
 if state.elapsed<float(combat.config.test_parameters.read_contact_s):return true
 var item:Dictionary=entry(str(state.prop));var record_id:String="combat_evidence:"+str(item.id)+":"+str(state.prop)
 app.rules.observe("物品",record_id,str(item.description),"亲历事实",str(item.source))
 if not combat.data.inspected.has(str(item.id)):combat.data.inspected[str(item.id)]={}
 combat.data.inspected[str(item.id)][str(state.prop)]=true
 app.rules._record("combat_evidence_read",record_id,{"source":item.source,"prop":state.prop,"identity_glyph":null,"time_glyph":null,"records":item.get("records",[]).duplicate(true)})
 if state.get("surface",false):combat.materials.paper_read(str(state.prop),bool(item.get("content_complete",false)))
 app.status_note=str(item.description)
 cancel();app.hero_route=PackedVector2Array();combat.data.route_left=0.0
 return true

func speak() -> void:
 normalize()
 if not combat.reactions.safe():return
 for item in combat.config.get("observations",[]):
  if item.room!=app.room_id or combat.data.inspection_lines.has(str(item.id)) or str(item.get("line","")).is_empty():continue
  var read:Dictionary=combat.data.inspected.get(str(item.id),{})
  var complete:bool=true
  for prop in item.props:
   if not read.has(str(prop)):complete=false
  if not complete:continue
  combat.data.inspection_lines[str(item.id)]=true
  app.add_dialogue("角色",str(item.line));return
