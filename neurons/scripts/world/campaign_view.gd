extends "res://scripts/world/room_view.gd"
const Catalog=preload("res://scripts/presentation/asset_catalog.gd")
const MetricBedroom=preload("res://scripts/world/metric_bedroom_view.gd")
const MetricInstitution=preload("res://scripts/world/metric_institution_view.gd")
var catalog=Catalog.new()
var metric_bedroom=MetricBedroom.new()
var metric_institution=MetricInstitution.new()

func draw_hidden_plaza() -> void:
 if app==null or layout==null:return
 if app.room_id!="hidden_street":super._draw();return
 draw_rect(Rect2(-800,-600,2200,1600),Color("172426"))
 poly([layout.project(Vector2.ZERO),layout.project(Vector2(5.6,0)),layout.project(layout.SIZE),layout.project(Vector2(0,3.8))],Color("596a69"))
 for i in range(20):draw_line(layout.project(Vector2(0,i*0.2)),layout.project(Vector2(5.6,i*0.2)),Color("4b5b5b"),1)
 var ordered:Array=[]
 for f in layout.furniture:ordered.append({"type":"furniture","data":f,"depth":layout.project(f.rect.end).y})
 ordered.append({"type":"actor","data":"hero","depth":layout.project(app.hero_pos).y})
 ordered.append_array(extra_actors());ordered.sort_custom(func(a,b):return a.depth<b.depth)
 for entry in ordered:
  if entry.type=="furniture":draw_furniture(entry.data)
  else:draw_actor(entry.data)
 var threshold:PackedVector2Array=app.hidden_route.exit_segment()
 var exit:Vector2=layout.project((threshold[0]+threshold[1])*0.5)
 draw_line(layout.project(threshold[0]),layout.project(threshold[1]),Color("b7c7b0"),3)
 var beyond:Vector2=layout.project(app.hidden_route.exit_destination())
 draw_line(exit,beyond,Color("b7c7b0"),2)
 draw_string(font,exit+Vector2(-17,-14),"出口",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e1d8b2"))
 var frame:Dictionary=app.hidden_route.ending_frame()
 if not frame.is_empty():
  var glow:float=float(frame.light)
  draw_rect(Rect2(-800,-600,2200,1600),Color(0.82,0.86,0.77,glow*0.65))
  if frame.phase!="plaza":
   draw_rect(Rect2(-800,-600,2200,1600),Color(0.11,0.19,0.19,float(frame.wake)))
   draw_rect(Rect2(135,100,350,150),Color("364a49"))
   draw_rect(Rect2(210,170,200,65),Color("abbab3"))
   draw_circle(Vector2(245,167),18,Color("c6c8b6"))
   if float(frame.wake)<0.35:
    draw_line(Vector2(235,164),Vector2(241,164),Color("334645"),2)
    draw_line(Vector2(247,164),Vector2(253,164),Color("334645"),2)
   else:
    draw_circle(Vector2(238,164),1.0+float(frame.wake)*1.5,Color("334645"))
    draw_circle(Vector2(250,164),1.0+float(frame.wake)*1.5,Color("334645"))
   draw_rect(Rect2(280,104,65,5),Color("e1dfc8"))
   draw_string(font,Vector2(185,269),"现实宿主睁眼 · 尾声占位",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d9e0cd"))
   draw_string(font,Vector2(200,282),"宿主胜利 · 幻觉逃脱",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d9e0cd"))
  draw_string(font,Vector2(210,98),str(frame.title),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e8e8d8"))
  draw_string(font,Vector2(200,303),str(frame.achievement),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e8e8d8"))

func rest_pose() -> Dictionary:
 var t:float=clampf((1.2-app.action_left)/0.3,0,1) if app.action_phase=="resting" else 0.0
 var from:Vector2=layout.project(app.hero_pos)+Vector2(0,-30)
 var to:Vector2=layout.project(layout.furniture[0].rect.get_center())+Vector2(0,-float(layout.furniture[0].height))
 return {"t":t,"center":from.lerp(to,smoothstep(0,1,t)),"angle":-PI/2*smoothstep(0,1,t)}

func hero_body_rect() -> Rect2:
 if app!=null and app.metric_institution_room(app.room_id):return MetricInstitution.hero_body_rect(app,layout)
 if layout!=null and layout.geometry_version>=2:return MetricBedroom.hero_body_rect(app,layout)
 if app.action_phase!="resting":return Rect2(layout.project(app.hero_pos)+Vector2(-16,-62),Vector2(32,65))
 var pose:Dictionary=rest_pose()
 var extent:=Vector2(16,33).lerp(Vector2(34,16),float(pose.t))
 return Rect2(pose.center-extent,extent*2)

func door_hit(toward:String,pixel:Vector2) -> bool:
 if app.metric_institution_room(app.room_id):return MetricInstitution.door_at_pixel(layout,pixel)==toward
 if layout.geometry_version>=2:return MetricBedroom.door_hit(layout,pixel)
 return pixel.distance_to(layout.project(app.door_point(toward)))<18

func furniture_at_pixel(pixel:Vector2) -> int:
 if app.metric_institution_room(app.room_id):return MetricInstitution.furniture_at_pixel(layout,pixel)
 return MetricBedroom.furniture_at_pixel(layout,pixel)

func eating_pose() -> Dictionary:
 if app.family==null or app.family.data.is_empty() or app.family.data.eating.is_empty():return {}
 var action:Dictionary=app.family.data.eating
 var t:float=clampf(float(action.elapsed)/float(app.family.config.timing.eat),0,1)
 var contact:float=smoothstep(0.0,0.3,t) if t<0.3 else 1.0 if t<0.78 else 1.0-smoothstep(0.78,1.0,t)
 return {"progress":t,"hand":Vector2(15,-17).lerp(Vector2(7,-44),contact),"item":str(action.item),"stage":"准备" if t<0.3 else "入口" if t<0.78 else "吞服"}

func draw_eating_gesture(center:Vector2) -> void:
 var pose:Dictionary=eating_pose()
 if pose.is_empty():return
 var hand:Vector2=center+pose.hand
 draw_line(center+Vector2(8,-37),hand,Color("8caebc"),4)
 draw_circle(hand,2.5,Color("d6c8b0"))
 var kind:String=str(app.family.data.food_types.get(pose.item,""))
 if kind=="porridge":draw_arc(hand+Vector2(0,-2),5,0,PI,10,Color("e0dfd5"),3)
 else:draw_rect(Rect2(hand+Vector2(-3,-4),Vector2(7,5)),Color("b8ab8d") if kind=="candy" else Color("735146"))
 draw_string(font,center+Vector2(-20,-73),"食用 · "+str(pose.stage),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e5e3cd"))

func draw_resting_actor() -> void:
 var pose:Dictionary=rest_pose()
 var frame:Dictionary=catalog.actor_frame("idle",app.hero_facing,0)
 draw_set_transform(pose.center,float(pose.angle))
 # Rotate about the body's middle, keeping the source foot anchor unchanged.
 draw_texture_rect_region(frame.texture,Rect2(Vector2(-frame.foot.x,30-frame.foot.y),frame.size),frame.source)
 draw_set_transform(Vector2.ZERO)
 draw_string(font,pose.center+Vector2(-20,24),"躺下 · 占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d7dfcf"))

func extra_actors() -> Array:
 var actors:Array=app.home.actors() if app!=null and app.home!=null else []
 if app!=null and app.family!=null:actors.append_array(app.family.actors())
 if app!=null and app.hospital!=null:actors.append_array(app.hospital.actors())
 if app!=null and app.hospital!=null and app.session.data.level==2:
  for item in app.hospital.relic_markers():
   if item.room==app.room_id:actors.append({"type":"actor","data":"hospital_prop:"+str(item.id),"depth":layout.project(Vector2(float(item.pos[0]),float(item.pos[1]))).y-0.1})
 if app!=null and app.asylum!=null:actors.append_array(app.asylum.actors())
 if app!=null and app.cortex!=null:actors.append_array(app.cortex.actors())
 if app!=null and app.asylum!=null and app.session.data.level==3:
  for item in asylum_props():
   if item.room==app.room_id:
    var at:=Vector2(float(item.pos[0]),float(item.pos[1]))
    actors.append({"type":"actor","data":"asylum_prop:"+str(item.id),"depth":float(item.get("depth",layout.project(at).y+0.1))})
 if app!=null and app.hidden_route!=null:actors.append_array(app.hidden_route.actors())
 if app!=null and app.search_actions!=null and app.room_id=="bedroom":
  var props:Dictionary=app.search_actions.state("box")
  if props.has("upper_shift"):
   var shift:Array=props.upper_shift
   var at:Vector2=layout.furniture[5].rect.end+Vector2(float(shift[0]),float(shift[1]))
   actors.append({"type":"actor","data":"upper_box","depth":layout.project(at).y})
 return actors

func draw_bedside(f:Dictionary) -> void:
 if catalog.current.is_empty():
  super.draw_bedside(f)
  return
 var spec:Dictionary=catalog.furniture()
 var origin:Vector2=layout.project(f.rect.position)-Vector2(float(spec.foot[0]),float(spec.foot[1]))
 var shift:Vector2=Vector2(float(spec.travel[0]),float(spec.travel[1]))*float(app.drawer_open.get(f.id,0.0))
 var tint:=Color(str(spec.tint))
 draw_texture(catalog.texture(spec.body),origin,tint)
 if shift.x>0 and spec.has("tray"):
  var a:=origin+Vector2(55.1742,11.8642)
  var b:=origin+Vector2(66.3666,30.4515)
  draw_polygon(PackedVector2Array([a,b,b+shift,a+shift]),PackedColorArray([tint]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),catalog.texture(spec.tray))
 draw_texture(catalog.texture(spec.drawer),origin+shift,tint)
 var props:Dictionary=app.search_actions.state("bedside") if app.search_actions!=null else {}
 var book:Array=props.get("book_shift",[0,0])
 var clock:Array=props.get("clock_shift",[0,0])
 if spec.has("book"):draw_texture(catalog.texture(spec.book),origin+Vector2(float(book[0]),float(book[1])),tint)
 if spec.has("clock"):draw_texture(catalog.texture(spec.clock),origin+Vector2(float(clock[0]),float(clock[1])),tint)
 draw_texture(catalog.texture(spec.front),origin,tint)

func bedside_handle() -> Vector2:
 if layout!=null and layout.geometry_version>=2:return MetricBedroom.bedside_handle(app,layout,catalog)
 var spec:Dictionary=catalog.furniture()
 return layout.project(layout.furniture[1].rect.position)-Vector2(float(spec.foot[0]),float(spec.foot[1]))+Vector2(float(spec.handle[0]),float(spec.handle[1]))+Vector2(float(spec.travel[0]),float(spec.travel[1]))*float(app.drawer_open.get("bedside",0.0))

func bedside_hand() -> Vector2:
 if layout!=null and layout.geometry_version>=2:return MetricBedroom.bedside_hand(app,layout,catalog)
 return super.bedside_hand()

func asylum_props() -> Array:
 var result:Array=app.asylum.ward_events.markers()
 result.append_array(app.asylum.trace_events.render_state())
 if app.asylum.isolation!=null:result.append_array(app.asylum.isolation.markers())
 if app.asylum.observations!=null:result.append_array(app.asylum.observations.markers())
 if app.asylum.intake!=null:result.append_array(app.asylum.intake.markers())
 result.append_array(app.asylum.ward_window_markers())
 for index in range(result.size()-1,-1,-1):
  if app.rules.owners.get(str(result[index].id),"")=="hero":result.remove_at(index)
 var held:Array=app.asylum.trace_events.config.relics.keys()+app.asylum.trace_events.config.notes.keys()+["asylum_transport_band"]
 var slot:int=0
 for id in held:
  if app.rules.owners.get(str(id),"")!="hero":continue
  result.append({"id":str(id),"room":app.room_id,"pos":[app.hero_pos.x,app.hero_pos.y],"kind":"band" if id=="asylum_transport_band" else "relic","held":true,"draw_offset":[20+slot*13,-23]})
  slot+=1
 return result

func asylum_item_pixel(item:Dictionary) -> Vector2:
 if app.metric_institution_room(app.room_id):return MetricInstitution.item_pixel(app,layout,item)
 var offset:Array=item.get("draw_offset",[0,0])
 return layout.project(Vector2(float(item.pos[0]),float(item.pos[1])))+Vector2(float(offset[0]),float(offset[1]))+Vector2(0,-5)

func draw_actor(who:String) -> void:
 if who.begins_with("cortex_"):
  var id:String=who.trim_prefix("cortex_")
  var actor:Dictionary=app.cortex.actor(id)
  var at:Vector2=layout.project(app.cortex.position(id))
  var imitation:Dictionary=app.cortex.imitated_pose(id)
  var phase:String=str(actor.get("phase","idle"))
  phase=app.cortex.action_label(id)
  var facing:Array=actor.get("facing",[0,1])
  var direction:Vector2=Vector2(float(facing[0]),float(facing[1]))
  var tone:=Color("b59e9e") if id in ["misaligned","face_press","twitch"] else Color("8e9eaa")
  draw_circle(at,9,Color(0.04,0.04,0.06,0.5))
  if imitation.get("pose","") not in ["kick","walk"]:
   draw_line(at+Vector2(-4,-13),at+Vector2(-5,0),tone,4)
   draw_line(at+Vector2(4,-13),at+Vector2(5,0),tone,4)
  draw_rect(Rect2(at+Vector2(-8,-39),Vector2(16,27)),tone)
  draw_circle(at+Vector2(0,-47),8,tone.lightened(0.15))
  if id=="dual_head":draw_circle(at+Vector2(9,-44),7,tone.darkened(0.12))
  if id=="faceless":draw_rect(Rect2(at+Vector2(-5,-51),Vector2(10,8)),Color("6b7582"))
  if id=="blindfold":draw_line(at+Vector2(-7,-48),at+Vector2(7,-48),Color("353d48"),4)
  var hand:Vector2=at+Vector2(13,-22)
  var body:Dictionary=app.cortex.data.get("body",{})
  if body.get("actor","")==id and app.cortex.near(id,0.65):hand=layout.project(app.hero_pos)+Vector2(5,-33)
  if imitation.is_empty():draw_line(at+Vector2(7,-34),hand,tone.lightened(0.2),3)
  else:draw_cortex_gesture(at,imitation,tone)
  var arrow:Vector2=(layout.project(app.cortex.position(id)+direction*0.2)-at).normalized()*12
  draw_line(at,at+arrow,Color("d5b887"),2)
  var label:String=str(app.cortex.config.get("names",{}).get(id,id))
  var width:float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
  draw_rect(Rect2(at+Vector2(-width/2-3,-71),Vector2(width+6,24)),Color(0.07,0.09,0.13,0.94))
  draw_string(font,at+Vector2(-width/2,-61),label,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("ece2d6"))
  draw_string(font,at+Vector2(-width/2,-51),phase,HORIZONTAL_ALIGNMENT_LEFT,width,7,Color("b0c8cf"))
  return
 if who.begins_with("hospital_prop:"):
  for item in app.hospital.relic_markers():
   if str(item.id)!=who.trim_prefix("hospital_prop:") or item.room!=app.room_id:continue
   var off:Array=item.get("draw_offset",[0,0]);var at:Vector2=layout.project(Vector2(float(item.pos[0]),float(item.pos[1])))+Vector2(float(off[0]),float(off[1]))
   draw_rect(Rect2(at+Vector2(-6,-9),Vector2(13,10)),Color("b7ad8e"))
   if item.kind=="bag":draw_arc(at+Vector2(0,-9),4,PI,TAU,8,Color("d0c5a2"),1)
  return
 if who.begins_with("asylum_prop:"):
  for item in asylum_props():
   if str(item.id)!=who.trim_prefix("asylum_prop:") or item.room!=app.room_id:continue
   var offset:Array=item.get("draw_offset",[0,0])
   var at:Vector2=layout.project(Vector2(float(item.pos[0]),float(item.pos[1])))+Vector2(float(offset[0]),float(offset[1]))
   match str(item.kind):
    "transport_bed":
     draw_rect(Rect2(at+Vector2(-22,-18),Vector2(44,15)),Color("5c6a65"))
     draw_rect(Rect2(at+Vector2(-20,-21),Vector2(40,12)),Color("bbc1b1"))
     for x in [-15,15]:draw_circle(at+Vector2(x,0),3,Color("303e40"))
     draw_circle(at+Vector2(-14,-20),5,Color("b9c6b4"))
     draw_rect(Rect2(at+Vector2(-8,-24),Vector2(25,9)),Color("9dafaa"))
     var hand_out:bool=str(app.asylum.data.get("ward_events",{}).get("transfer",{}).get("phase",""))=="hand_grab"
     draw_line(at+Vector2(-5,-18),at+Vector2(0,-9 if hand_out else -18),Color("c4c9b6"),3)
    "corpse":
     draw_ellipse_blood(at)
     draw_rect(Rect2(at+Vector2(-20,-12),Vector2(39,9)),Color("8e9e96") if item.covered else Color("8a635e"))
     if not item.covered:draw_circle(at+Vector2(-20,-10),5,Color("c4b5a6"))
     if item.get("screen_closed",false):
      draw_rect(Rect2(at+Vector2(-23,-45),Vector2(46,40)),Color("6c8180"))
      for i in range(6):draw_line(at+Vector2(-20+i*8,-43),at+Vector2(-20+i*8,-6),Color("526969"),1)
    "box":draw_rect(Rect2(at+Vector2(-7,-10),Vector2(14,9)),Color("c0ac81"))
    "bag":
     draw_rect(Rect2(at+Vector2(-8,-15),Vector2(16,14)),Color("c3b68d"))
     draw_arc(at+Vector2(0,-15),5,PI,TAU,8,Color("e2d4ad"),2)
     draw_rect(Rect2(at+Vector2(-5,-11),Vector2(10,5)),Color("e0dcc0"))
    "trace":draw_ellipse_blood(at)
    "band","relic","note":
     draw_rect(Rect2(at+Vector2(-5,-7),Vector2(11,5)),Color("d2cdb1"))
     draw_line(at+Vector2(-2,-5),at+Vector2(3,-5),Color("647674"),1)
    "ward_window":
     draw_rect(Rect2(at+Vector2(-12,-12),Vector2(24,15)),Color("182c30"))
     draw_rect(Rect2(at+Vector2(-12,-12),Vector2(24,15)),Color("c4ccbb"),false,2)
     if not item.get("open",false):draw_rect(Rect2(at+Vector2(-9,-9),Vector2(18,9)),Color("7f8d80"))
     else:draw_line(at+Vector2(6,-10),at+Vector2(6,1),Color("9aa68e"),3)
     # This marker alone gets a small dark backing; do not widen/rearrange
     # every existing door or replace the project's UI in this local task.
     var caption:String=str(item.label)
     var caption_size:Vector2=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,8)
     var caption_at:Vector2=at+Vector2(-caption_size.x*0.5,-18)
     draw_rect(Rect2(caption_at+Vector2(-3,-9),Vector2(caption_size.x+6,13)),Color(0.06,0.12,0.14,0.94))
     draw_string(font,caption_at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("edf0d8"))
    "isolation_door":
     var progress:float=float(item.get("progress",0))
     draw_rect(Rect2(at+Vector2(-18,-51),Vector2(36*progress,50)),Color("596f6c"))
     draw_rect(Rect2(at+Vector2(-18,-51),Vector2(36,50)),Color("a7ada0"),false,2)
     if item.get("closed",false):draw_line(at+Vector2(-12,-25),at+Vector2(12,-25),Color("b68570"),3)
     draw_string(font,at+Vector2(-23,-60),str(item.label),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dec6a4"))
   return
  return
 if who.begins_with("asylum_"):
  var id:String=who.trim_prefix("asylum_")
  if id=="transport_patient":return # Same living body is on the bed marker.
  var actor:Dictionary=app.asylum.actor(id)
  var at:Vector2=layout.project(app.asylum.position(id))
  var color:=Color("899a95") if id not in ["patient","transport_patient","postop_patient","speaker","corner_patient","labor_patient"] else Color("829aa7")
  var phase:String=str(actor.get("phase","idle"))
  var action:String=app.asylum.ward_events.action_label(id)
  if id=="med_nurse" and app.asylum.nurse_duty!=null:action=app.asylum.nurse_duty.action_label()
  if id=="registration_nurse" and app.asylum.intake!=null and app.asylum.intake.actor_reserved(id):action=app.asylum.intake.phase_label()
  if not action.is_empty():phase=action
  draw_circle(at,9,Color(0.05,0.08,0.08,0.3))
  draw_rect(Rect2(at+Vector2(-8,-43),Vector2(16,29)),color)
  draw_circle(at+Vector2(0,-51),8,color.lightened(0.2))
  for side in [-1,1]:
   draw_line(at+Vector2(side*5,-14),at+Vector2(side*5,0),color,5)
   draw_line(at+Vector2(side*7,-37),at+Vector2(side*12,-20),color,4)
  draw_line(at+Vector2(0,-1),at+Vector2(0,7),Color("d2bd83"),1)
  var body:Dictionary=app.asylum.data.get("body",{})
  if id=="registration_nurse" and app.asylum.intake!=null and app.asylum.intake.actor_reserved(id):
   var bag:Vector2=app.asylum.intake.bag_position()
   if bag.is_finite():draw_line(at+Vector2(7,-35),layout.project(bag)+Vector2(10,-24),Color("c0c3a5"),3)
  if body.get("actor","")==id:
   phase=str(body.get("kind",phase))
   if app.asylum.near(id,0.65):draw_line(at+Vector2(6,-34),layout.project(app.hero_pos)+Vector2(10,-31),Color("c8cbb4"),3)
   if phase=="registration_followup":
    phase={"approach":"靠近答问","write":"书写追问记录","read":"出示记录"}.get(str(body.get("phase","")),"答问")
    if body.get("phase","") in ["write","read"]:
     draw_rect(Rect2(at+Vector2(10,-38),Vector2(11,13)),Color("d4c8ac"))
     draw_line(at+Vector2(7,-37),at+Vector2(14,-31),Color("bfc8b8"),3)
  if id=="med_nurse" and not action.is_empty() and (action.contains("写") or action.contains("核") or action.contains("读") or action.contains("夹")):
   var hand:Vector2=at+Vector2(14,-33)
   draw_line(at+Vector2(7,-37),hand,Color("c3c8ae"),3)
   draw_rect(Rect2(hand+Vector2(-3,-6),Vector2(10,12)),Color("d4c8ac"))
   if action.contains("写"):draw_line(hand+Vector2(7,-8),hand,Color("585c58"),1)
  var ward:Dictionary=app.asylum.ward_events.state()
  if id=="supervisor" and ward.clamp.phase=="windup":
   var closing:Vector2=layout.project(layout.furniture[6].rect.position)+Vector2(0,-25)
   draw_line(at+Vector2(6,-34),at.lerp(closing,clampf(float(ward.clamp.elapsed)/float(app.asylum.ward_events.config.presentation_timing.drawer_windup),0,1)),Color("b7bda9"),4)
  if id=="postop_patient" and ward.postop.get("wound_visible",false):
   draw_rect(Rect2(at+Vector2(3,-27),Vector2(8,11)),Color("b6b9a3"))
   draw_line(at+Vector2(6,-24),at+Vector2(7,-19),Color("8d4246"),3)
  var paired:String=""
  var guard:Dictionary=app.asylum.data.get("records_state",{}).get("guard",{})
  var corner:Dictionary=app.asylum.data.get("trace_events",{}).get("corner",{})
  var isolated:Dictionary=app.asylum.data.get("isolation_state",{})
  if id=="guard" and guard.get("target","")=="patient" and guard.get("phase","")=="drag":paired="patient"
  if id=="ordinary_orderly" and ward.ordinary_job.get("holding",false) and ward.ordinary_job.get("target","")!="hero":paired=str(ward.ordinary_job.target)
  if id=="ordinary_orderly" and corner.get("phase","")=="drag":paired="corner_patient"
  if id=="isolation_orderly" and isolated.get("phase","")=="drag" and isolated.get("target","")!="hero":paired=str(isolated.target)
  if not paired.is_empty() and app.asylum.present(paired) and app.asylum.actor(paired).room==app.room_id:
   draw_line(at+Vector2(6,-34),layout.project(app.asylum.position(paired))+Vector2(0,-32),Color("c0bda4"),4)
  phase={"idle":"等候","absent":"未到场","wrist_check":"核对腕带","wrist_reach":"伸手抓取","wrist_hold":"扭腕固定","registration":"核对记录","diagnosis":"记录陈述","medical_order_write":"填写医嘱","order_transfer":"递出医嘱","order_receive":"接收医嘱","mix":"配药","cup_transfer":"递杯","raise_cup":"举杯","records_guard_drag":"带至门口","ward_ordinary_hero_drag":"带至站侧","ward_isolation_drag":"带入观察位"}.get(phase,phase)
  var label:String=str(app.asylum.config.get("names",{}).get(id,id))
  draw_string(font,at+Vector2(-20,-65),label+"·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e0e1cb"))
  draw_string(font,at+Vector2(-20,-76),phase,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d3b1a0"))
  return
 if who=="hidden_hunter" or who.begins_with("hospital_"):
  var id:String=who.trim_prefix("hospital_")
  var at:Vector2=layout.project(app.hidden_route.position() if who=="hidden_hunter" else app.hospital.position(id))
  var phase:String=str(app.hidden_route.data.hunter.phase) if who=="hidden_hunter" else str(app.hospital.actor(id).phase)
  if who!="hidden_hunter" and id=="guard":
   var disposition:Dictionary=app.hospital.data.get("records_state",{}).get("guard",{})
   if disposition.get("phase","idle")!="idle":phase=str(disposition.phase)
  var color:=Color("754e55") if who=="hidden_hunter" else Color("9aaba2")
  draw_circle(at,9,Color(0.05,0.08,0.08,0.3))
  draw_rect(Rect2(at+Vector2(-8,-43),Vector2(16,29)),color)
  draw_circle(at+Vector2(0,-51),8,color.lightened(0.2))
  for side in [-1,1]:
   draw_line(at+Vector2(side*5,-14),at+Vector2(side*5,0),color,5)
   draw_line(at+Vector2(side*7,-37),at+Vector2(side*12,-20),color,4)
  if who=="hidden_hunter" and phase in ["windup","attack"]:
   var direction:Array=app.hidden_route.data.hunter.direction
   var v:Vector2=layout.project(Vector2(float(direction[0]),float(direction[1])))-layout.project(Vector2.ZERO)
   draw_line(at+Vector2(0,-30),at+Vector2(0,-30)+v.normalized()*28,Color("b5a490"),5)
  var name:String="猎手" if who=="hidden_hunter" else str(app.hospital.config.names[id])
  draw_string(font,at+Vector2(-22,-65),name+"·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e0e1cb"))
  if who!="hidden_hunter":
   if id=="porter":
    var pack:Dictionary=app.hospital.relic_packing_action()
    if not pack.is_empty():
     var target:Array=pack.pos;var hand:Vector2=at+Vector2(7,-32)
     var end:Vector2=layout.project(Vector2(float(target[0]),float(target[1])))+Vector2(0,-5)
     draw_line(hand,hand.lerp(end,float(pack.progress)),Color("c5c5aa"),3)
     draw_string(font,at+Vector2(-25,-78),str(pack.label),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e3d0a4"))
   var body:Dictionary=app.hospital.data.body
   if not body.is_empty() and body.actor==id and app.hospital.near(id,0.65):
    var hand:Vector2=layout.project(app.hero_pos)+Vector2(10,-34)
    draw_line(at+Vector2(-6,-35),hand,Color("c4cab6"),3)
    draw_string(font,at+Vector2(-20,-77),str(body.kind),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e4c997"))
    if body.kind=="bandage":draw_rect(Rect2(hand-Vector2(4,2),Vector2(8,4)),Color("d7d8c4"))
   if id=="doctor" and phase=="sample":draw_line(at+Vector2(-4,-35),layout.project(app.hero_pos)+Vector2(10,-34),Color("b9d1c8"),1)
   if id=="guard":
    var disposition:Dictionary=app.hospital.data.get("records_state",{}).get("guard",{})
    if disposition.get("target","")=="patient" and phase in ["reach","drag"] and app.hospital.actor("patient").room==app.room_id:
     var paired:Vector2=layout.project(app.hospital.position("patient"))+Vector2(0,-31)
     var arm:Vector2=at+Vector2(4,-34)
     var reach:float=clampf(float(disposition.elapsed)/float(app.hospital.config.test_parameters.grab_prepare),0,1) if phase=="reach" else 1.0
     draw_line(arm,arm.lerp(paired,reach),Color("bec3a7"),3)
     draw_string(font,at+Vector2(-18,-78),"抓握前摇" if phase=="reach" else "带离",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dbb2a7"))
  if id=="wheelchair":draw_arc(at+Vector2(0,-8),12,0,TAU,12,Color("485c5a"),2)
  return
 if who=="upper_box":
  var shift:Array=app.search_actions.state("box").upper_shift
  var base:Rect2=layout.furniture[5].rect
  prism(Rect2(base.position+Vector2(float(shift[0]),float(shift[1])),base.size),11,Color("ae926b"))
  return
 if who in ["mother","father"]:
  if who=="father" and not app.family.collapse_active():
   draw_father_actor();return
  var at:Vector2=layout.project(app.family.position(who))
  var color:=Color("b9a28d") if who=="mother" else Color("66777b")
  if app.action_phase=="resting":color=color.darkened(0.65)
  if app.family.collapse_active():
   var phase:float=float(app.family.data.collapse.elapsed)
   at+=Vector2(sin(phase*53)*1.5,0)
   color=color.lerp(Color("654149"),minf(0.8,phase*0.16))
  draw_circle(at,10,Color(0.07,0.08,0.08,0.25))
  draw_rect(Rect2(at+Vector2(-8,-45),Vector2(16,32)),color)
  draw_circle(at+Vector2(0,-53),8,color.lightened(0.2))
  for side in [-1,1]:
   draw_line(at+Vector2(side*5,-15),at+Vector2(side*5,0),color,5)
   draw_line(at+Vector2(side*7,-40),at+Vector2(side*13,-19),color,4)
  draw_string(font,at+Vector2(-23,-66),"母亲·占位" if who=="mother" else "父亲·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d7dfcf"))
  return
 if who in ["dog","cat"]:
  var at:Vector2=layout.project(app.home.position(who))
  var color:=Color("c6a35e") if who=="dog" else Color("343d40")
  draw_set_transform(at)
  draw_circle(Vector2(0,-2),12,Color(0.07,0.08,0.08,0.25))
  if who=="dog" and not app.home.data.dog.alive:
   draw_rect(Rect2(-14,-7,27,7),Color("78504b"))
  else:
   draw_rect(Rect2(-12,-15,23,11),color)
   draw_rect(Rect2(7,-22,12,13),color.lightened(0.12))
   draw_line(Vector2(8,-18),Vector2(7,-26),color,3)
   draw_line(Vector2(-10,-13),Vector2(-17,-19),color,3)
   draw_line(Vector2(-7,-5),Vector2(-7,0),color,3)
   draw_line(Vector2(8,-5),Vector2(8,0),color,3)
   if who=="dog":draw_line(Vector2(7,-16),Vector2(7,-10),Color("a95f54"),2)
  draw_string(font,Vector2(-17,-29),"大黄·占位" if who=="dog" else "黑猫·占位",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d7dfcf"))
  draw_set_transform(Vector2.ZERO)
  return
 if who!="hero" or catalog.current.is_empty():
  super.draw_actor(who)
  if who=="hero":draw_father_hero_gesture(layout.project(app.hero_pos))
  if who=="hero" and app.session.data.level==4:
   draw_cortex_gesture(layout.project(app.hero_pos),app.cortex.visible_reaction_pose(),Color("9bb7b7"))
  return
 if app.action_phase=="resting":return # The bed surface draws the attached pose above itself.
 var center:Vector2=layout.project(app.hero_pos)
 # Body action poses follow the same saved game clock as contact settlement.
 var phase:float=app.world_visual_time
 if app.hero_state=="search":phase=app.rules.search_elapsed
 elif app.hero_state=="scratch":phase=maxf(0,0.5-app.rules.reaction_left)
 elif app.hero_state=="hit":phase=maxf(0,0.25-app.rules.hurt_left)
 elif app.hero_state=="give":phase=maxf(0,(0.4 if app.action_phase=="pickup" else 0.6)-app.action_left)
 var frame:Dictionary=catalog.actor_frame(app.hero_state,app.hero_facing,phase)
 draw_set_transform(center,0,Vector2(1,0.35))
 draw_circle(Vector2.ZERO,10,Color(0.05,0.07,0.08,0.3))
 draw_set_transform(Vector2.ZERO)
 var crouch:float=0.68 if app.hero_state=="search" and app.search_actions!=null and app.search_actions.pose=="low" else 1.0
 if app.room_id=="hidden_street":crouch=app.hidden_route.body_height()/float(app.hidden_route.config.test_parameters.standing_body_height)
 draw_texture_rect_region(frame.texture,Rect2(center-Vector2(frame.foot.x,frame.foot.y*crouch),Vector2(frame.size.x,frame.size.y*crouch)),frame.source)
 draw_father_hero_gesture(center)
 if app.session.data.level==4:draw_cortex_gesture(center,app.cortex.visible_reaction_pose(),Color("9bb7b7"))
 if float(app.rules.effects.get("PORES",0))>0:
  for i in range(5):draw_circle(center+Vector2(9+i%2*3,-35+i*3),1.0,Color("9fcebc"))
 if float(app.rules.effects.get("DRYMOUTH",0))>0:draw_line(center+Vector2(7,-43),center+Vector2(10,-35),Color("d6c8b0"),2)
 if app.hero_state=="eat":draw_eating_gesture(center)
 if app.session.data.level==2:
  var reading:Dictionary=app.hospital.data.get("observation_state",{}).get("active",{})
  if not reading.is_empty():
   var progress:float=float(reading.get("phase_progress",0))
   var reach:float=progress if reading.phase=="prepare" else 1.0-progress if reading.phase=="finish" else 1.0
   var hand:Vector2=center+Vector2(8+12*reach,-30-7*reach)
   draw_line(center+Vector2(7,-35),hand,Color("a4b9bb"),3)
   draw_rect(Rect2(hand+Vector2(-4,-6),Vector2(9,11)),Color("c9c6a9"))
   draw_line(hand+Vector2(-2,-3),hand+Vector2(3,-3),Color("777e70"),1)
   var phase_name:String={"prepare":"伸手","contact":"翻看","finish":"收手"}.get(str(reading.phase),"")
   draw_string(font,center+Vector2(-28,-71),phase_name,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e1d6ad"))
 if app.session.data.level==3 and app.asylum.blocks_hero() and str(app.asylum.data.holder).is_empty():
  var reading:Dictionary=app.asylum.data.get("records_state",{}).get("reading",{})
  var trace:Dictionary=app.asylum.data.get("trace_events",{}).get("active",{})
  if reading.is_empty():reading=app.asylum.data.get("observations_state",{}).get("active",{})
  if not reading.is_empty() or not trace.is_empty():
   var elapsed:float=float(reading.get("elapsed",trace.get("elapsed",0)))
   var reach:float=clampf(elapsed/0.25,0,1) if elapsed<0.65 else clampf((1.0-elapsed)/0.35,0,1)
   var hand:Vector2=center+Vector2(9+11*reach,-33)
   draw_line(center+Vector2(7,-35),hand,Color("afbeb3"),3)
   draw_rect(Rect2(hand+Vector2(-4,-6),Vector2(9,11)),Color("d1c5a4"))
 if app.session.data.level==3:
  var window_action:Dictionary=app.asylum.data.get("ward_window_state",{}).get("action",{})
  if not window_action.is_empty():
   var elapsed:float=float(window_action.elapsed)
   var reach:float=clampf(elapsed/app.asylum.WARD_WINDOW_PREPARE,0,1) if window_action.phase=="prepare" else clampf((app.asylum.WARD_WINDOW_PREPARE+app.asylum.WARD_WINDOW_CONTACT+app.asylum.WARD_WINDOW_FINISH-elapsed)/app.asylum.WARD_WINDOW_FINISH,0,1) if window_action.phase=="finish" else 1.0
   var shoulder:Vector2=center+Vector2(7,-35)
   var handle:Vector2=layout.project(app.asylum.ward_window_position())+Vector2(10,-46)
   var hand:Vector2=shoulder.lerp(handle,reach)
   draw_line(shoulder,hand,Color("b7c3ad"),3);draw_circle(hand,2,Color("ddd4b6"))
 if app.session.data.level==3 and app.rules.owners.get("asylum_cup","")=="hero":
  var raising:bool=app.asylum.data.get("body",{}).get("kind","")=="raise_cup"
  var hand:Vector2=center+Vector2(12,-43 if raising else -27)
  draw_line(center+Vector2(7,-36),hand,Color("9cb4b5"),3)
  draw_rect(Rect2(hand+Vector2(-3,-4),Vector2(6,6)),Color("d2d6bc"))
 if app.session.data.level==2 and app.rules.owners.get("hospital_cup","")=="hero":
  var raising:bool=app.hospital.data.body.get("kind","")=="raise_cup"
  var hand:Vector2=center+Vector2(12,-43 if raising else -27)
  draw_line(center+Vector2(7,-36),hand,Color("8caebc"),3)
  draw_rect(Rect2(hand+Vector2(-3,-4),Vector2(6,6)),Color("d2d6bc"))
 if app.hero_state=="search":
  var hand:Vector2=bedside_hand() if app.room_id=="bedroom" and bedside_contact() else center+Vector2(16,-46 if app.search_actions!=null and app.search_actions.pose=="high" else -12 if crouch<1 else -28)
  if app.target_index>=0 and app.room_id=="bedroom" and app.layout.furniture[app.target_index].id!="bedside":
   var f:Dictionary=app.layout.furniture[app.target_index]
   var p:=Vector2(clampf(app.hero_pos.x,f.rect.position.x,f.rect.end.x),clampf(app.hero_pos.y,f.rect.position.y,f.rect.end.y))
   hand=layout.project(p)+Vector2(0,-minf(float(f.height),46.0) if app.search_actions.pose=="high" else -8 if crouch<1 else -float(f.height)*0.6)
  draw_line(center+Vector2(8,-38),hand,Color("8caebc"),4)
  draw_circle(hand,2.5,Color("d6c8b0"))
 draw_string(font,center+Vector2(-19,-64),app.search_actions.action_label if app.hero_state=="search" and app.search_actions!=null else app.hero_state,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e5e3cd"))
 draw_line(center+Vector2(0,-2),center+app.hero_facing*9,Color("f1c17d"),1)

func father_contact_point(pose:Dictionary) -> Vector2:
 var point:Vector2=app.hero_pos
 if float(pose.release)>0:
  var saved:Array=pose.release_point
  point=Vector2(float(saved[0]),float(saved[1]))
 var hero:Vector2=layout.project(point)
 var father:Vector2=layout.project(app.family.position("father"))
 return hero+Vector2(9 if father.x>=hero.x else -9,-33)

func draw_father_actor() -> void:
 var pose:Dictionary=app.family.father_presentation()
 if pose.is_empty():return
 var at:Vector2=layout.project(app.family.position("father"))
 var color:=Color("66777b")
 var values:Array=pose.facing
 var direction:=Vector2(float(values[0]),float(values[1]))
 var screen_direction:Vector2=(layout.project(app.family.position("father")+direction)-at).normalized()
 var stride:float=sin(app.world_visual_time*9.0)*4.0 if pose.moving else 0.0
 draw_circle(at,10,Color(0.07,0.08,0.08,0.25))
 draw_rect(Rect2(at+Vector2(-8,-45),Vector2(16,32)),color)
 draw_circle(at+Vector2(0,-53),8,color.lightened(0.2))
 draw_circle(at+Vector2(0,-53)+screen_direction*5,1.6,Color("d4c9ae"))
 var hand:Vector2=father_contact_point(pose)
 var reaching_side:int=1 if hand.x>=at.x else -1
 for side in [-1,1]:
  draw_line(at+Vector2(side*5,-15),at+Vector2(side*5+side*stride,0),color,5)
  if float(pose.reach)<=0 or side!=reaching_side:
   draw_line(at+Vector2(side*7,-40),at+Vector2(side*13,-19),color,4)
 var shoulder:Vector2=at+Vector2(7 if hand.x>=at.x else -7,-39)
 if float(pose.reach)>0:
  var rest:Vector2=shoulder+Vector2(5 if hand.x>=at.x else -5,21)
  var reached:Vector2=rest.lerp(hand,float(pose.reach))
  draw_line(shoulder,reached,color.lightened(0.12),5)
  draw_circle(reached,3,Color("b7b39e"))
  if pose.held:draw_arc(hand,4,0,TAU,12,Color("d0bba2"),1.5)
 draw_line(at,at+screen_direction*15,Color("b8b8a1"),2)
 draw_string(font,at+Vector2(-26,-79),"父亲 · "+str(pose.label),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("e2d5b7"))

func draw_father_hero_gesture(center:Vector2) -> void:
 if app.room_id!="bedroom" or app.family==null:return
 var pose:Dictionary=app.family.father_presentation()
 if pose.is_empty():return
 if pose.held:
  var hand:Vector2=father_contact_point(pose)
  draw_line(center+Vector2(8 if hand.x>=center.x else -8,-40),hand,Color("b0c6c6"),4)
  draw_arc(hand,4,0,TAU,12,Color("d0bba2"),1.5)
  draw_string(font,center+Vector2(-28,15),"被抓握 · 带行" if pose.phase=="drag" else "被抓握 · 转身",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("edd1b2"))
 elif pose.phase=="grab":
  draw_string(font,center+Vector2(-27,15),"抓取前摇 · 可干预",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("edd1b2"))
 elif float(pose.release)>0:
  draw_string(font,center+Vector2(-18,15),"实际松脱",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("bed1b7"))

func draw_cortex_gesture(at:Vector2,gesture:Dictionary,tone:Color) -> void:
 # Saved action time drives both the original gesture and the imitation.
 # This helper only draws joints/head marks; it has no gameplay callbacks,
 # movement, resource or contact writes. Formal sprites can replace it.
 if gesture.is_empty():return
 var pose:String=str(gesture.get("pose",""));var elapsed:float=float(gesture.get("elapsed",0.0))
 var progress:float=clampf(elapsed/0.65,0.0,1.0)
 var pulse:float=sin(progress*PI)
 var wobble:float=0.0 if app.reduced_effects else sin(elapsed*34.0)*1.5
 var left:Vector2=Vector2(-11,-23);var right:Vector2=Vector2(13,-23)
 var head:Vector2=Vector2(0,-47);var ink:=Color("24313a");var skin:=Color("d5c2ad")
 match pose:
  "scratch":
   left=Vector2(-4,-31);right=Vector2(-5+wobble,-35)
   draw_line(at+Vector2(-9,-33),at+Vector2(-3,-30),skin,2)
  "abdomen":
   left=Vector2(-2,-25);right=Vector2(3,-24)
   draw_arc(at+Vector2(0,-24),7,0.1,PI-0.1,12,tone.darkened(0.35),2)
  "look_skin":
   left=Vector2(2,-38);right=Vector2(11,-39)
   draw_line(at+head+Vector2(1,0),at+head+Vector2(5,3),ink,2)
   draw_line(at+left,at+right,skin,3)
  "shiver":
   left=Vector2(6+wobble,-33);right=Vector2(-5-wobble,-30)
   draw_line(at+head+Vector2(-3+wobble,-1),at+head+Vector2(3+wobble,-1),ink,1)
  "head_tilt":
   right=Vector2(9,-46);left=Vector2(-9,-25)
   draw_line(at+head+Vector2(-3,-3),at+head+Vector2(4,1),ink,2)
   draw_line(at+Vector2(0,-38),at+Vector2(3,-43),tone.lightened(0.15),3)
  "lips":
   right=Vector2(5,-44)
   draw_line(at+head+Vector2(0,3),at+head+Vector2(6,3),ink,2)
  "kick":
   var kick:float=smoothstep(0.0,0.5,progress)*(1.0-smoothstep(0.65,1.0,progress))
   left=Vector2(-14,-30);right=Vector2(11,-36)
   draw_line(at+Vector2(-4,-13),at+Vector2(-5,0),tone.darkened(0.15),4)
   var knee:Vector2=Vector2(4,-14).lerp(Vector2(15,-22),kick)
   var foot:Vector2=Vector2(5,0).lerp(Vector2(27,-18),kick)
   draw_polyline(PackedVector2Array([at+Vector2(4,-16),at+knee,at+foot]),tone,4)
   draw_line(at+foot,at+foot+Vector2(5,1),ink,3)
  "withdraw":right=Vector2(24,-30).lerp(Vector2(1,-34),smoothstep(0,0.6,progress))
  "recoil":
   left=Vector2(-16,-40);right=Vector2(17,-40)
   draw_line(at+head+Vector2(-4,-1),at+head+Vector2(-1,-3),ink,1)
   draw_line(at+head+Vector2(2,-3),at+head+Vector2(5,-1),ink,1)
  "fear":
   left=Vector2(-6,-38);right=Vector2(7,-38)
   draw_arc(at+head+Vector2(1,4),3,PI,TAU,8,ink,1)
  "smile":
   left=Vector2(-10,-25);right=Vector2(12,-25)
   draw_arc(at+head+Vector2(1,1),4,0.2,PI-0.2,10,ink,2)
  "walk":
   var stride:float=sin(progress*TAU)*5.0
   left=Vector2(-11-stride,-24);right=Vector2(12+stride,-24)
   draw_line(at+Vector2(-4,-13),at+Vector2(-5+stride,0),tone,4)
   draw_line(at+Vector2(4,-13),at+Vector2(5-stride,0),tone,4)
  "read":
   left=Vector2(0,-32);right=Vector2(12,-33)
   draw_rect(Rect2(at+Vector2(1,-42),Vector2(13,11)),Color("d1c4a5"))
   draw_line(at+Vector2(4,-38),at+Vector2(11,-38),ink,1)
  _:return
 # Both elbow paths remain visible at default world scale. The small pulse
 # articulates hands without translating feet or simulating another skill.
 var left_elbow:Vector2=Vector2(-12,-31).lerp(left,0.2+0.1*pulse)
 var right_elbow:Vector2=Vector2(13,-31).lerp(right,0.2+0.1*pulse)
 draw_polyline(PackedVector2Array([at+Vector2(-7,-35),at+left_elbow,at+left]),tone.darkened(0.1),3)
 draw_polyline(PackedVector2Array([at+Vector2(7,-35),at+right_elbow,at+right]),tone.lightened(0.15),3)
 draw_circle(at+left,2,skin);draw_circle(at+right,2,skin)

func draw_furniture(f:Dictionary) -> void:
 if f.has("collision_rects"):
  for rect in f.collision_rects:prism(rect,float(f.height),f.color)
  if f.collision_rects.is_empty():
   var at:Vector2=layout.project(f.rect.get_center())
   for i in range(4):draw_line(at+Vector2(-9+i*5,-3),at+Vector2(-6+i*5,4),Color("45565a"),1)
  return
 if f.id=="bed" and app.action_phase=="resting" and not catalog.current.is_empty():
  super.draw_furniture(f);draw_resting_actor();return
 if app.search_actions==null or app.room_id!="bedroom":super.draw_furniture(f);return
 # Tall foreground props remain physical but reveal an obscured interaction.
 # Only presentation alpha changes; depth ordering/collision stay intact.
 if float(f.height)>=40 and app.rules.search_active and app.target_index>=0 and app.layout.furniture[app.target_index].id!=f.id:
  var hero:Vector2=layout.project(app.hero_pos)
  var left:Vector2=layout.project(f.rect.position)
  var right:Vector2=layout.project(f.rect.end)
  var bounds:=Rect2(Vector2(minf(left.x,right.x),left.y-float(f.height)),Vector2(absf(right.x-left.x),right.y-left.y+float(f.height)))
  if right.y>hero.y and bounds.intersects(Rect2(hero+Vector2(-12,-57),Vector2(24,57))):
   f=f.duplicate()
   var color:Color=f.color
   f.color=Color(color.r,color.g,color.b,0.35)
 var props:Dictionary=app.search_actions.state(f.id)
 if f.id=="box":
  prism(f.rect,9,Color("627c86"))
  if props.has("upper_shift"):return # Moved upper box has its own depth entry.
  var shift:Array=props.get("upper_shift",[0,0])
  var upper:=Rect2(f.rect.position+Vector2(float(shift[0]),float(shift[1])),f.rect.size)
  if not props.has("upper_shift"):draw_set_transform(Vector2(0,-9))
  prism(upper,11,Color("ae926b"))
  draw_set_transform(Vector2.ZERO)
  return
 if f.id=="stool":
  var center:Vector2=layout.project(f.rect.get_center())
  for side in [-1,1]:draw_line(center+Vector2(side*8,0),center+Vector2(side*8,-14),Color("577e94"),3)
  draw_set_transform(center+Vector2(0,-14),0,Vector2(1,0.4));draw_circle(Vector2.ZERO,13,Color("759db7"));draw_set_transform(Vector2.ZERO)
  draw_set_transform(Vector2(0,-14));prism(f.rect.grow(-0.05),9,Color("b7a07b"));draw_set_transform(Vector2.ZERO)
  if props.get("open",false):draw_rect(Rect2(center+Vector2(-10,-26),Vector2(19,5)),Color("4e4436"));draw_line(center+Vector2(-10,-26),center+Vector2(-16,-35),Color("c3ac83"),4)
  return
 super.draw_furniture(f)
 if f.id=="bed" and props.get("bedding_lifted",false):
  var edge:Vector2=layout.project(f.rect.end)+Vector2(-17,-28)
  draw_colored_polygon(PackedVector2Array([edge,edge+Vector2(-25,-4),edge+Vector2(-15,-12),edge+Vector2(4,-6)]),Color("9daaa6"))
 if f.id=="desk":
  var at:Vector2=layout.project(f.rect.get_center())+Vector2(-45,-30)
  var moved:int=int(props.get("desk_shift",0))
  for i in range(3):
   var p:Vector2=at+Vector2(i*23+ (4 if moved>i else 0),i%2*6)
   draw_rect(Rect2(p,Vector2(16,4)),[Color("a5b4b3"),Color("c6ad7c"),Color("91715f")][i])
   draw_line(p+Vector2(0,4),p+Vector2(16,4),Color("e0d7be"),1)
 if f.id=="storage" and props.get("uniform_out",false):
  var at:Vector2=layout.project(f.rect.position)+Vector2(-10,-20)
  draw_colored_polygon(PackedVector2Array([at,at+Vector2(22,3),at+Vector2(25,20),at+Vector2(1,16)]),Color("aab4b3"))
  draw_rect(Rect2(at+Vector2(7,9),Vector2(8,3)),Color("8a5e59"))
  if props.get("label_viewed",false):draw_rect(Rect2(at+Vector2(6,2),Vector2(7,3)),Color("d9d3bc"))
 if f.id=="rack" and app.action_phase=="observe_cuff":
  var at:Vector2=layout.project(f.rect.get_center())+Vector2(-2,-25)
  draw_line(at,at+Vector2(-15,-6),Color("d9d9cd"),5)
  for i in range(4):draw_line(at+Vector2(-13+i*3,-6),at+Vector2(-12+i*3,-3),Color("6b7473"),1)

func draw_ellipse_blood(at:Vector2) -> void:
 draw_set_transform(at,0,Vector2(1,0.2))
 draw_circle(Vector2.ZERO,17,Color(0.3,0.04,0.06,0.48))
 draw_set_transform(Vector2.ZERO)

func draw_room_overlays() -> void:
 # Stains belong to the wall/floor behind the sorted actors. Drawing this
 # after the scene covered the father's body and actual grasp with the door.
 if app!=null and app.room_id=="bedroom" and app.family!=null and not app.family.data.is_empty() and app.family.data.blood_door:
  var portal:Vector2=layout.project(Vector2(4.28,0))+Vector2(0,-76)
  draw_rect(Rect2(portal,Vector2(69,76)),Color(0.45,0.1,0.12,0.7))
  # Local irregular streaks/soft margins, driven only by this actual event.
  for i in range(9):
   var x:float=4+i*7
   var length:float=11+(i*19)%48
   var color:=Color(0.3,0.035,0.05,0.7)
   draw_line(portal+Vector2(x,0),portal+Vector2(x+((i%3)-1)*3,length),color,2+i%2)
  for i in range(4):draw_rect(Rect2(portal-Vector2(2+i,1+i),Vector2(73+i*2,78+i*2)),Color(0.32,0.12,0.14,0.07),false,2)
  draw_ellipse_blood(portal+Vector2(30,77))

func _draw() -> void:
 if app!=null and layout!=null and app.metric_institution_room(app.room_id):
  metric_institution.font=font
  metric_institution.draw(self,app,layout,catalog)
  return
 if app!=null and layout!=null and app.room_id=="bedroom" and layout.geometry_version>=2:
  metric_bedroom.font=font
  metric_bedroom.draw(self,app,layout,catalog)
  return
 if app!=null and app.room_id=="hidden_street":draw_hidden_plaza();return
 if app!=null and app.session.data.level==4:draw_cortex_room()
 else:super._draw()
 if app==null:return
 if app.family!=null and not app.family.data.is_empty() and not app.family.data.gift.is_empty():
  var at:Vector2=layout.project(app.layout.DOOR)+Vector2(-8,0)
  draw_rect(Rect2(at+Vector2(-4,-5),Vector2(8,5)),Color("b28d69"))
 for id in app.visible_doors:
  if app.room_id=="bedroom" and app.family!=null and app.family.data.get("blood_door",false):continue
  var point:Vector2=layout.project(app.door_point(id))
  draw_arc(point,9,PI,TAU,16,Color("9dc2bb"),2)
  if app.session.data.level in [3,4]:
   var width:float=font.get_string_size(app.room_title(id),HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
   draw_rect(Rect2(point+Vector2(-15,-24),Vector2(width+3,13)),Color(0.1,0.18,0.19,0.8))
  draw_string(font,point+Vector2(-15,-13),app.room_title(id),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e2dfc9"))
 if app.room_id=="bedroom" and app.family!=null and app.family.data.get("blood_door",false):
  var blood_exit:Vector2=layout.project(app.layout.DOOR)
  draw_string(font,blood_exit+Vector2(-24,-10),"渗血的门",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("edc3b7"))
 if app.key_visible() and not app.has_key():
  var point:Vector2=layout.project(app.key_position())+Vector2(0,-12)
  draw_circle(point,3,Color("eac978"),false,1)
  draw_line(point+Vector2(3,0),point+Vector2(11,0),Color("eac978"),2)

func draw_cortex_room() -> void:
 # Deliberate 2D placeholder: actual topology and silhouettes stay visible.
 draw_rect(Rect2(-800,-600,2200,1600),Color("171b25"))
 var corners:Array=[layout.project(Vector2.ZERO),layout.project(Vector2(5.6,0)),layout.project(layout.SIZE),layout.project(Vector2(0,3.8))]
 poly(corners,Color("555765") if app.room_id in app.CortexMap.FIRST_ROOMS else Color("465763"))
 for y in range(1,8):
  draw_line(layout.project(Vector2(0,y*0.475)),layout.project(Vector2(5.6,y*0.475)),Color(0.7,0.7,0.75,0.09),1)
 draw_polyline(PackedVector2Array(corners+[corners[0]]),Color("929ba6"),3)
 for door in app.visible_doors:
  var at:Vector2=layout.project(app.door_point(door))
  draw_circle(at,12,Color("263d43"));draw_arc(at,12,0,TAU,24,Color("a8c2bc"),2)
 var ordered:Array=[]
 for item in layout.furniture:ordered.append({"type":"furniture","data":item,"depth":layout.project(item.rect.end).y})
 for item in layout.decor:ordered.append({"type":"furniture","data":item,"depth":layout.project(item.rect.end).y})
 for wall in layout.walls:
  ordered.append({"type":"wall","data":wall,"depth":layout.project(wall.end).y})
 ordered.append({"type":"actor","data":"hero","depth":layout.project(app.hero_pos).y})
 ordered.append_array(app.cortex.actors())
 ordered.sort_custom(func(a,b):return a.depth<b.depth)
 for entry in ordered:
  if entry.type=="actor":draw_actor(str(entry.data))
  elif entry.type=="wall":prism(entry.data,30,Color("596977"))
  else:
   var item:Dictionary=entry.data
   prism(item.rect,float(item.get("height",24)),item.get("color",Color("6a7580")))
   var top:Vector2=layout.project(item.rect.get_center())+Vector2(0,-float(item.get("height",24)))
   var label:String=str(item.get("name",""))
   if not label.is_empty():
    var width:float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
    draw_rect(Rect2(top+Vector2(-width/2-2,-10),Vector2(width+4,13)),Color(0.07,0.09,0.12,0.9))
    draw_string(font,top+Vector2(-width/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("dfdcca"))
 for observation in app.cortex.observation_markers():
  if str(observation.room)!=app.room_id:continue
  var at:Vector2=layout.project(app.cortex.target_position(observation))+Vector2(0,-12)
  draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),Color("e4cfa8"),false,1)
 for marker in app.cortex.presentation_markers()+app.cortex.upper_events.markers():draw_cortex_marker(marker)
 if app.target_index>=0:
  var at:Vector2=layout.project(layout.furniture[app.target_index].at)
  draw_arc(at,8,0,TAU,24,Color("e3c69c"),1)
  if app.rules.search_active:draw_arc(at,10,-PI/2,-PI/2+TAU*app.rules.search_elapsed/app.rules.search_duration,32,Color("a0d3c0"),2)

func draw_cortex_marker(marker:Dictionary) -> void:
 if str(marker.get("room",""))!=app.room_id:return
 var position:Array=marker.pos
 var at:Vector2=layout.project(Vector2(float(position[0]),float(position[1])))+Vector2(0,-24)
 var progress:float=float(marker.get("progress",0))
 match str(marker.kind):
  "paper":
   if marker.get("owner","")!="torn":
    if marker.get("owner","")=="hero":at=layout.project(app.hero_pos)+Vector2(14,-28)
    draw_rect(Rect2(at,Vector2(17,12)),Color("d3c6a8"))
    for i in range(3):draw_line(at+Vector2(3,3+i*3),at+Vector2(13,3+i*3),Color("797266"),1)
    if progress>0:draw_line(at+Vector2(8,0),at+Vector2(8,12*progress),Color("372b36"),2)
   else:
    if marker.get("fragment_owner","")=="hero":
     var corner:Vector2=layout.project(app.hero_pos)+Vector2(13,-28)
     poly([corner,corner+Vector2(7,1),corner+Vector2(4,8)],Color("d3c6a8"))
    var collector:Array=marker.collector_pos
    var body:Vector2=layout.project(Vector2(float(collector[0]),float(collector[1])))
    var scraps:Vector2=body+Vector2(12,-29) if marker.get("scraps_owner","")=="stitched" else at+Vector2(8,3)
    for i in range(4):draw_line(scraps+Vector2((i%2)*5,i*2),scraps+Vector2((i%2)*5+6,i*2+2),Color("c9b99d"),2)
    if marker.get("phase","")=="collect":
     var shoulder:Vector2=body+Vector2(7,-34)
     draw_line(shoulder,shoulder.lerp(scraps,float(marker.collect_progress)),Color("b9a599"),3)
  "video":
   draw_cortex_source_frame(at,marker)
  "replay":
   draw_cortex_source_frame(at,marker)
   if marker.get("medium","")=="recorder":
    for x in [-10,10]:
     var center:Vector2=at+Vector2(x,9)
     draw_circle(center,5,Color("839697"),false,1)
     draw_line(center,center+Vector2.from_angle(progress*TAU*3)*4,Color("b4c3bd"),1)
   draw_string(font,at+Vector2(-31,-43),"已有事件重现·无配音",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("b3bdb8"))
  "clamp":
   var gap:float=9.0*(1-progress) if marker.get("phase","")=="windup" else 0 if marker.get("phase","")=="release" else 9
   draw_rect(Rect2(at+Vector2(-14-gap,-3),Vector2(11,6)),Color("9fa8af"))
   draw_rect(Rect2(at+Vector2(3+gap,-3),Vector2(11,6)),Color("9fa8af"))
   var hand:Dictionary=marker.get("hand",{})
   if hand.get("contact",false):
    var shoulder:Vector2=layout.project(app.hero_pos)+Vector2(10,-28)
    draw_line(shoulder,shoulder.lerp(at,float(hand.extension)),Color("d0baab"),3)
   draw_circle(at+Vector2(22,-9),3,Color("bd5656") if marker.get("pain_light",false) else Color("556875"))
   if marker.get("hurt",false):draw_line(at+Vector2(-2,3),at+Vector2(3,9),Color("9a3e4c"),2)
  "record":
   draw_rect(Rect2(at+Vector2(-15,-20),Vector2(30,20)),Color("24323c"))
   draw_string(font,at+Vector2(-13,-11),"接受   拒绝",HORIZONTAL_ALIGNMENT_LEFT,-1,6,Color("b9c6bd"))
   draw_string(font,at+Vector2(-12,-3),"已同意",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("c7b79d"))
   if marker.get("written",false):draw_string(font,at+Vector2(-14,10),"自主行为",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("d4b08a"))
  "note":
   draw_rect(Rect2(at+Vector2(-5,-5),Vector2(10,8)),Color("cfc7ae"))
   draw_string(font,at+Vector2(-20,-9),str(marker.get("label","")),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("e6d4ae"))

func draw_cortex_source_frame(at:Vector2,marker:Dictionary) -> void:
 draw_rect(Rect2(at+Vector2(-36,-38),Vector2(72,38)),Color("1a232d"))
 var source:Dictionary=marker.get("source",{})
 if source.is_empty():return
 var progress:float=float(marker.get("progress",0));var kind:String=str(source.get("kind",""))
 if kind in ["patient_transport_completed","asylum_bed_transfer_delivered"]:
  var faces:Array=marker.get("faces",[])
  if faces.is_empty():
   faces=[{"role":"perpetrator","masked":false},{"role":"patient","masked":false}]
   if kind=="patient_transport_completed":faces.insert(1,{"role":"perpetrator","masked":false})
  var shift:float=-5+progress*10;var operator_index:int=0
  for face in faces:
   if face.role=="patient":
    var patient:Vector2=at+Vector2(shift,-14)
    if kind=="asylum_bed_transfer_delivered":
     draw_line(patient+Vector2(-8,3),patient+Vector2(10,3),Color("b8c2c1"),4)
     draw_circle(patient+Vector2(-10,2),4,Color("c2b8aa"))
    else:
     draw_line(patient,patient+Vector2(6,6),Color("b8c2c1"),3)
     draw_circle(patient+Vector2(0,-6),4,Color("c2b8aa"))
    draw_line(patient+Vector2(-4,7),patient+Vector2(9,7),Color("7e949c"),2)
    for x in [-3,8]:draw_circle(patient+Vector2(x,11),3,Color("7e949c"),false,1)
   else:
    var person:Vector2=at+Vector2((-22 if operator_index==0 else 20)+shift,-15)
    draw_line(person,person+Vector2(-2,11),Color("8eabb4"),3)
    draw_line(person+Vector2(0,2),at+Vector2(shift,-9),Color("8eabb4"),2)
    draw_circle(person+Vector2(0,-8),4,Color("a9bdc0"))
    if face.get("masked",false):draw_rect(Rect2(person+Vector2(-5,-12),Vector2(10,9)),Color("090b13"))
    operator_index+=1
 elif kind.contains("refused"):
  draw_circle(at+Vector2(-12,-27),4,Color("bdc5bf"))
  draw_line(at+Vector2(-12,-22),at+Vector2(-12,-7),Color("8eabb4"),3)
  draw_line(at+Vector2(-12,-19),at+Vector2(4+progress*8,-18),Color("b4c4c3"),3)
  draw_rect(Rect2(at+Vector2(16,-17),Vector2(7,9)),Color("b7a68a"),false,1)
 else:
  # Without a supported source staging, expose the actual saved receipt;
  # moving its recorded timeline does not invent new poses, injury or speech.
  draw_rect(Rect2(at+Vector2(-23,-31),Vector2(46,24)),Color("9ea59a"))
  for i in range(3):draw_line(at+Vector2(-18,-26+i*6),at+Vector2(-18+clampf(progress*4-i,0,1)*36,-26+i*6),Color("495958"),1)
 if marker.get("overlay",false):draw_circle(at+Vector2(4,-26),6,Color("b9d6ca"))
 draw_line(at+Vector2(-31,-3),at+Vector2(-31+62*progress,-3),Color("a9c7b6"),2)

