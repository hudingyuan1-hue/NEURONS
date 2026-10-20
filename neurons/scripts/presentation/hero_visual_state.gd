extends RefCounted
## Read-only bridge from real action clocks/contact points to the cutout rig.
## Screen-space hands are shared with the existing physical prop renderer.
const Bedroom=preload("res://scripts/world/metric_bedroom_view.gd")
const Institution=preload("res://scripts/world/metric_institution_view.gd")
const HUMAN:float=136.5

static func direction(facing:Vector2) -> int:
 if absf(facing.x)>=absf(facing.y):return 0 if facing.x>=0 else 2
 return 1 if facing.y<0 else 3

static func _hand(result:Dictionary,at:Vector2,target:Vector2) -> void:
 # These are screen-side hands, matching the authored part names.
 result.hands["right_hand" if target.x>=at.x else "left_hand"]=target

static func sample(app,catalog) -> Dictionary:
 var at:Vector2=app.layout.project(app.hero_pos)
 var result:Dictionary={"state":str(app.hero_state),"direction":direction(app.hero_facing),"elapsed":float(app.world_visual_time),"duration":1.0,"progress":0.0,"pose":"","hands":{},"item_hands":{},"resting":str(app.action_phase)=="resting"}
 if result.resting:
  result.state="idle";result.elapsed=0.0
  return result
 if app.rules.search_active:
  result.elapsed=float(app.rules.search_elapsed);result.duration=maxf(.01,float(app.rules.search_duration))
  result.pose=str(app.search_actions.pose) if app.search_actions!=null else "mid"
  result.state="search_low" if result.pose=="low" else "search"
 elif app.hero_state=="scratch":result.duration=.5;result.elapsed=maxf(0,.5-float(app.rules.reaction_left))
 elif app.hero_state=="hit":result.duration=.25;result.elapsed=maxf(0,.25-float(app.rules.hurt_left))
 elif app.hero_state=="give":result.duration=.6;result.elapsed=maxf(0,.6-float(app.action_left))
 result.progress=clampf(float(result.elapsed)/float(result.duration),0,1)
 var level:int=int(app.session.data.level)
 if level==1:
  var helper=Bedroom.new();helper.app=app;helper.layout=app.layout;helper.catalog=catalog
  if app.rules.search_active and app.target_index>=0 and app.target_index<app.layout.furniture.size():
   _hand(result,at,helper._search_hand(app.layout.furniture[app.target_index]))
  if app.family!=null:
   var pose:Dictionary=app.family.father_presentation()
   if bool(pose.get("held",false)):_hand(result,at,helper._father_contact(pose))
   var eating:Dictionary=app.family.data.get("eating",{})
   if app.hero_state=="eat" and not eating.is_empty():
    result.duration=float(app.family.config.timing.eat);result.elapsed=float(eating.elapsed)
    result.progress=clampf(float(result.elapsed)/float(result.duration),0,1)
    var t:float=result.progress
    var reach:float=clampf(t/.30,0,1) if t<.78 else clampf((1-t)/.22,0,1)
    var target:Vector2=(at+Vector2(27,-HUMAN*.37)).lerp(at+Vector2(12,-HUMAN*.86),reach)
    _hand(result,at,target);result.item_hands.food=target
  # Helpers own no nodes; clear their back references promptly.
  helper.app=null;helper.layout=null;helper.catalog=null
 elif level in [2,3]:
  var helper=Institution.new();helper.app=app;helper.layout=app.layout;helper.catalog=catalog
  var group=app.hospital if level==2 else app.asylum
  var body:Dictionary=group.data.get("body",{})
  var holder:String=str(group.data.get("holder",""))
  if app.rules.search_active and app.target_index>=0 and app.target_index<app.layout.furniture.size():
   var f:Dictionary=app.layout.furniture[app.target_index];var rect:Rect2=f.rect
   var touch:=Vector2(clampf(app.hero_pos.x,rect.position.x,rect.end.x),clampf(app.hero_pos.y,rect.position.y,rect.end.y))
   var height:float=minf(Institution._h(f),HUMAN*.65) if result.pose!="low" else .24*78.0
   if str(f.get("kind",""))=="window" and f.has("wall_mount"):
    height=float(Institution._window_display(f).sill_height_m)*78.0
    var inset:float=float(app.layout.config.wall.get("thickness_m",.15))*.52
    match str(f.wall_mount):
     "west":touch.x=-inset
     "east":touch.x=app.layout.world_size().x+inset
     "north":touch.y=-inset
     "south":touch.y=app.layout.world_size().y+inset
   var target:Vector2=app.layout.project(touch)-Vector2(0,height)
   if f.get("locked_upper",false):target=helper.material_handle(f)
   var side:float=1 if target.x>=at.x else -1
   var hand:Vector2=(at+Vector2(side*26,-HUMAN*.37)).lerp(target,clampf(float(app.rules.search_elapsed)/.25,0,1))
   _hand(result,at,hand)
  elif not holder.is_empty() and group.data.get("actors",{}).has(holder):
   var contact:Dictionary=helper._paired_contact(group,holder,group.actor(holder))
   if not contact.is_empty():_hand(result,at,contact.pixel)
  var reading:Dictionary=group.data.get("observation_state",{}).get("active",{}) if level==2 else group.data.get("observations_state",{}).get("active",{})
  if level==3 and reading.is_empty():reading=group.data.get("records_state",{}).get("reading",{})
  if not reading.is_empty():
   var progress:float=float(reading.get("phase_progress",clampf(float(reading.get("elapsed",0))/.25,0,1)))
   var phase:String=str(reading.get("phase","contact"))
   var reach:float=progress if phase=="prepare" else 1-progress if phase=="finish" else 1.0
   var target:Vector2=at+Vector2(26+reach*9,-HUMAN*.55-reach*9)
   _hand(result,at,target);result.item_hands.paper=target
  if level==3:
   var action:Dictionary=group.data.get("ward_window_state",{}).get("action",{})
   if not action.is_empty():
    var elapsed:float=float(action.elapsed)
    var reach:float=clampf(elapsed/group.WARD_WINDOW_PREPARE,0,1) if action.phase=="prepare" else clampf((group.WARD_WINDOW_PREPARE+group.WARD_WINDOW_CONTACT+group.WARD_WINDOW_FINISH-elapsed)/group.WARD_WINDOW_FINISH,0,1) if action.phase=="finish" else 1.0
    var target:Vector2=Institution.item_pixel(app,app.layout,{"kind":"ward_window","pos":group.xy(group.ward_window_position())})
    var side:float=1 if target.x>=at.x else -1
    _hand(result,at,(at+Vector2(side*26,-HUMAN*.37)).lerp(target,reach))
  var cup:String="hospital_cup" if level==2 else "asylum_cup"
  if app.rules.owners.get(cup,"")=="hero":
   var target:Vector2=at+Vector2(29,-HUMAN*(.84 if str(body.get("kind",""))=="raise_cup" else .45))
   _hand(result,at,target);result.item_hands.cup=target
  helper.app=null;helper.layout=null;helper.catalog=null
 elif level>=5 and str(app.hero_state)=="tinnitus":
  result.state="hit";_hand(result,at,at+Vector2(12,-HUMAN*.81))
 return result
