extends RefCounted
## Code-drawn 2D trial; all figures remain explicit placeholders.
var canvas
var app
var battle
var font:Font

func draw(target,owner,catalog) -> void:
 canvas=target;app=owner;battle=app.active_battle();font=target.font
 var layout=app.layout;var deep:bool=battle.map.deep(app.room_id)
 canvas.draw_rect(Rect2(-1800,-1200,4500,3000),Color("263039") if deep else Color("211f2a"))
 var corners:Array=[]
 for p in [Vector2.ZERO,Vector2(layout.world_size().x,0),layout.world_size(),Vector2(0,layout.world_size().y)]:corners.append(layout.project(p))
 canvas.poly(corners,Color("b0b9ad") if deep else Color("645455"))
 for row in range(1,16):canvas.draw_line(layout.project(Vector2(0,row*.475)),layout.project(Vector2(11.2,row*.475)),Color(0.4,0.44,0.43,.17),1)
 if battle.chapter_id==6:draw_street_surfaces()
 canvas.draw_polyline(PackedVector2Array(corners+[corners[0]]),Color("b8beb1"),4)
 if layout.cold_zone.has_area():zone(layout.cold_zone,Color(.3,.63,.8,.26),"局部冷区 · 双方移速80%")
 if app.room_id=="brainstem":
  var phase:String=battle.pulse_phase()
  zone(layout.pulse_zone,{"warning":Color(.93,.73,.31,.27),"active":Color(.97,.86,.55,.65),"interval":Color(.5,.61,.65,.12)}[phase],{"warning":"脉冲预警 · 离开亮带","active":"脉冲冲击","interval":"脉冲间隔"}[phase])
 for f in layout.decor:
  if float(f.height)>5:continue
  var rect:Rect2=f.rect
  canvas.poly([layout.project(rect.position),layout.project(Vector2(rect.end.x,rect.position.y)),layout.project(rect.end),layout.project(Vector2(rect.position.x,rect.end.y))],Color("77696b") if not deep else Color("b0b8ad"))
 var ordered:Array=[]
 for f in layout.furniture+layout.decor:
  if f in layout.decor and float(f.height)<=5:continue
  ordered.append({"kind":"prop","data":f,"depth":layout.project((f.rect as Rect2).end).y})
 ordered.append({"kind":"hero","depth":layout.project(app.hero_pos).y})
 if battle.chapter_id==6:
  var director:Dictionary=battle.data.actors.director;var cage:Dictionary=battle.director.state()
  if director.present and director.room==app.room_id:
   for index in range(cage.frames.size()):ordered.append({"kind":"director_rail","index":index,"depth":layout.project((battle.vector(cage.frames[index][1])+battle.vector(cage.frames[index][2]))*.5).y})
  for grasp_id in battle.grasp_motion.IDS:
   var carrier:Dictionary=battle.data.actors[grasp_id]
   if carrier.present and carrier.room==app.room_id:
    var grasp:Dictionary=battle.grasp_motion.state(str(grasp_id))
    ordered.append({"kind":"grasp_arm","id":grasp_id,"depth":layout.project(battle.vector(grasp.hand)).y})
  var restraint:Dictionary=battle.restraint.state();var assistant:Dictionary=battle.data.actors.assistant_asylum
  if assistant.present and assistant.room==app.room_id and not restraint.pose.is_empty():
   for index in range(2):ordered.append({"kind":"restraint_arm","index":index,"depth":layout.project(battle.vector(restraint.pose.arms[index][2])).y})
   ordered.append({"kind":"restraint_loop","depth":layout.project(battle.vector(restraint.pose.center)).y})
  var strap:Dictionary=battle.belt.state();var warder:Dictionary=battle.data.actors.warder
  if warder.present and warder.room==app.room_id:
   for index in range(1,strap.profile.size()):ordered.append({"kind":"warder_belt","index":index,"depth":layout.project((battle.vector(strap.profile[index-1])+battle.vector(strap.profile[index]))*.5).y})
  var mother:Dictionary=battle.data.actors.mother
  if mother.present and mother.hp>0 and mother.room==app.room_id:
   for index in range(battle.mother.state().arms.size()):
    var arm:Array=battle.mother.state().arms[index]
    ordered.append({"kind":"mother_arm","index":index,"depth":layout.project((battle.vector(arm[1])+battle.vector(arm[2]))*.5).y})
  for id in battle.LocalSweeps.IDS:
   var carrier:Dictionary=battle.data.actors[id];var limbs:Array=battle.local_sweeps.state(id).limbs
   if carrier.present and carrier.hp>0 and carrier.room==app.room_id:
    for index in range(limbs.size()):ordered.append({"kind":"local_sweep","id":id,"index":index,"depth":layout.project((battle.vector(limbs[index][1])+battle.vector(limbs[index][2]))*.5).y})
  var bottle:Dictionary=battle.bottle.state();var father:Dictionary=battle.data.actors.father
  if father.present and father.room==app.room_id and not bottle.profile.is_empty():ordered.append({"kind":"father_bottle","depth":layout.project((battle.vector(bottle.profile[0])+battle.vector(bottle.profile[1]))*.5).y})
  for shot_index in range(battle.splash.state().shots.size()):
   var shot:Dictionary=battle.splash.state().shots[shot_index]
   if shot.room!=app.room_id:continue
   for ray_index in range(shot.rays.size()):
    var ray:Dictionary=shot.rays[ray_index]
    if float(ray.ground_at)<0:ordered.append({"kind":"splash_ray","shot":shot_index,"ray":ray_index,"depth":layout.project(battle.vector(ray.pos)).y})
  var embrace:Dictionary=battle.embrace.state()
  var guard:Dictionary=battle.data.actors.isolation
  if guard.present and guard.hp>0 and guard.room==app.room_id:
   for index in range(embrace.arms.size()):
    var arm:Array=embrace.arms[index]
    ordered.append({"kind":"embrace_arm","index":index,"depth":layout.project((battle.vector(arm[1])+battle.vector(arm[2]))*.5).y})
  var bag:Dictionary=battle.laundry_bag.state()
  if bag.room==app.room_id and battle.data.actors.transporter_hospital.present:ordered.append({"kind":"laundry_bag","depth":layout.project(battle.vector(bag.center)).y})
  var bed:Dictionary=battle.data.get("lateral_bed",{})
  if not bed.is_empty() and bed.room==app.room_id and battle.data.actors.transporter_asylum.present:ordered.append({"kind":"lateral_bed","depth":layout.project(battle.vector(bed.center)).y})
  var box:Dictionary=battle.data.get("box",{})
  if not box.is_empty() and box.room==app.room_id and (battle.data.actors.labor.present or box.released):ordered.append({"kind":"box","depth":layout.project(battle.vector(box.pos)).y})
 for id in battle.data.get("actors",{}):
  var a:Dictionary=battle.data.actors[id]
  if a.present and a.room==app.room_id:ordered.append({"kind":"actor","id":id,"depth":layout.project(battle.position(id)).y})
 ordered.sort_custom(func(a,b):return a.depth<b.depth)
 for entry in ordered:
  if entry.kind=="prop":
   var f:Dictionary=entry.data
   if f.get("kind","")=="gate":draw_gate(f)
   elif f.get("kind","")=="rack":draw_rack(f)
   elif f.get("kind","")=="cleaner_cart":
    canvas.prism(f.rect,float(f.height),Color("757b78"))
    var cart_top:Vector2=layout.project(f.rect.get_center())-Vector2(0,float(f.height))
    canvas.draw_circle(cart_top,12,Color("414951"));canvas.draw_line(cart_top-Vector2(12,5),cart_top+Vector2(12,5),Color("9f9b89"),3)
   else:canvas.prism(f.rect,float(f.height),Color("a5afa8") if deep else Color("837172"))
   text(layout.project((f.rect as Rect2).get_center())-Vector2(0,float(f.height)+6),str(f.name),12)
  elif entry.kind=="lateral_bed":
   var bed:Dictionary=battle.data.lateral_bed
   draw_bed(battle.lateral_bed.anchor(battle.vector(bed.center),battle.vector(bed.axis)),battle.vector(bed.axis))
   var center:Vector2=layout.project(battle.vector(bed.center))
   var carrier:Dictionary=battle.data.actors.transporter_asylum
   if carrier.hp>0:
    for side in [-.12,.12]:
     var rail:Vector2=layout.project(battle.vector(bed.center)-battle.vector(bed.push)*.45+battle.vector(bed.axis)*side)-Vector2(0,48)
     canvas.draw_line(layout.project(battle.position("transporter_asylum"))-Vector2(0,74),rail,Color("b6b29d"),4)
   text(center-Vector2(0,61),"离院",13)
   if bed.phase in ["windup","attack"]:
    var goal:Vector2=layout.project(battle.vector(bed.center)+battle.vector(bed.push)*(1.0-float(bed.distance)))
    canvas.draw_line(center,goal,Color("d9b575"),5)
  elif entry.kind=="box":draw_box(battle.data.box)
  elif entry.kind=="laundry_bag":draw_laundry_bag()
  elif entry.kind=="embrace_arm":draw_embrace_arm(int(entry.index))
  elif entry.kind=="splash_ray":draw_splash_ray(int(entry.shot),int(entry.ray))
  elif entry.kind=="father_bottle":draw_father_bottle()
  elif entry.kind=="mother_arm":draw_mother_arm(int(entry.index))
  elif entry.kind=="local_sweep":draw_local_sweep(str(entry.id),int(entry.index))
  elif entry.kind=="warder_belt":draw_warder_belt(int(entry.index))
  elif entry.kind=="restraint_arm":draw_restraint_arm(int(entry.index))
  elif entry.kind=="restraint_loop":draw_restraint_loop()
  elif entry.kind=="grasp_arm":draw_grasp_arm(str(entry.id))
  elif entry.kind=="director_rail":draw_director_rail(int(entry.index))
  elif entry.kind=="hero":
   var at:Vector2=layout.project(app.hero_pos)
   var crouch:float=.56 if app.rules.reaction_skill=="GUT" and app.rules.reaction_left>.2 else 1.0
   var frame:Dictionary=catalog.actor_frame("hit" if app.hero_state=="tinnitus" else app.hero_state,app.hero_facing,app.world_visual_time)
   var scale_value:=Vector2(2.1,2.1*crouch)
   canvas.draw_circle(at,17,Color(0,0,0,.25))
   canvas.draw_texture_rect_region(frame.texture,Rect2(at-frame.foot*scale_value,frame.size*scale_value),frame.source)
   draw_known_hand_marks(at,106,true)
   if battle.chapter_id==6:draw_loss_reaction(at);draw_restraint_wrist(at);draw_grasp_wrist(at)
   if app.hero_state=="tinnitus":
    canvas.draw_line(at+Vector2(12,-52),at+Vector2(22,-80),Color("a7b8b8"),5)
    canvas.draw_line(at+Vector2(22,-80),at+Vector2(9,-91),Color("c4bea8"),4)
    text(at-Vector2(0,112),"停步 · 侧头捂耳（姿态占位）",14)
  else:actor(str(entry.id))
 if battle.chapter_id==6:draw_main_ending()
 for id in app.visible_doors:
  var at:Vector2=layout.project(app.door_point(str(id)))
  canvas.draw_circle(at,13,Color("2f5055"));canvas.draw_arc(at,13,0,TAU,32,Color("d3d9bd"),2)
  text(at-Vector2(0,20),battle.map.title(str(id)),14)

func text(at:Vector2,value:String,size_px:int) -> void:
 var width:float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 canvas.draw_rect(Rect2(at-Vector2(width*.5+4,size_px),Vector2(width+8,size_px+5)),Color(.07,.1,.12,.84))
 canvas.draw_string(font,at-Vector2(width*.5,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,Color("e8e3cf"))

func zone(rect:Rect2,color:Color,label:String) -> void:
 var points:Array=[]
 for p in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:points.append(app.layout.project(p))
 canvas.poly(points,color);canvas.draw_polyline(PackedVector2Array(points+[points[0]]),Color(color,0.85),2)
 text(app.layout.project(rect.position)-Vector2(0,12),label,13)

func actor(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.spec(id)
 var at:Vector2=app.layout.project(battle.position(id))
 if id=="assistant":draw_bed(battle.position(id),battle.vector(a.direction))
 var color:Color=Color("7dafa5") if s.relation=="friend" else Color("c08f82") if a.hostile else Color("a7a9c2")
 if battle.chapter_id==6 and id=="transporter_hospital":color=Color("89918c")
 if battle.chapter_id==6 and id=="psychiatrist":color=Color("c2c5b7")
 if battle.chapter_id==6 and id=="doctor":color=Color("c5c7bb")
 if battle.chapter_id==6 and id=="guard_hospital":color=Color("4d5d6b")
 if battle.chapter_id==6 and id=="wheelchair":draw_chair(at)
 if int(a.hp)<=0:
  if battle.chapter_id==6 and id=="dog" and battle.data.speed_deaths.get("dog",{}).get("source","")=="father":
   for i in range(5):
    var piece:Vector2=at+Vector2((i-2)*12,3 if i%2==0 else -5)
    canvas.poly([piece+Vector2(-5,3),piece+Vector2(1,-7),piece+Vector2(7,4)],Color("8c8067"))
   canvas.draw_arc(at+Vector2(0,2),7,0,TAU,16,Color("ae4e4b"),3);return
  canvas.draw_line(at-Vector2(25,6),at+Vector2(25,6),color.darkened(.5),9);return
 var h:float=55 if id in ["cat","dog"] else 133
 var action_clock:float=float(a.elapsed)
 if id=="cat" and a.phase=="windup":h*=.55
 if id=="twitch" and a.phase=="windup":at.y-=absf(sin(action_clock/1.2*PI*2))*9
 if id=="reverse":
  var facing:Vector2=battle.vector(a.direction)
  canvas.draw_line(at-Vector2(0,65),app.layout.project(battle.position(id)-facing*.4)-Vector2(0,65),Color("c3b1a0"),5)
 canvas.draw_circle(at,17,Color(.03,.05,.07,.26))
 canvas.poly([at+Vector2(-18,-h*.7),at+Vector2(18,-h*.7),at+Vector2(24,-h*.2),at+Vector2(-24,-h*.2)],color)
 canvas.draw_circle(at+Vector2(0,-h*.88),h*.12,Color("c4bea8"))
 for side in [-1,1]:canvas.draw_line(at+Vector2(side*9,-h*.2),at+Vector2(side*12,0),color.darkened(.15),8)
 if id=="double_head":
  canvas.draw_circle(at+Vector2(-14,-h*.88),13,Color("b9b39f"))
  canvas.draw_circle(at+Vector2(14,-h*.88),13,Color("b9b39f"))
  if not a.hostile:canvas.draw_line(at+Vector2(-20,-h*.5),at+Vector2(10,-h*.74),color.darkened(.2),7);canvas.draw_line(at+Vector2(20,-h*.5),at+Vector2(-10,-h*.74),color.darkened(.2),7)
 if id=="double_face" and (a.get("face_turned",false) or float(a.get("face_turn_progress",0))>0):
  var progress:float=1.0 if a.get("face_turned",false) else float(a.face_turn_progress)
  canvas.draw_arc(at+Vector2(0,-h*.88),15,-PI*.5,-PI*.5+progress*TAU,24,Color("80566d"),4)
  if a.get("face_turned",false):
   for side in [-1,1]:canvas.draw_circle(at+Vector2(side*5,-h*.88),2,Color("3e3040"))
 if id=="corner" and a.phase=="point":canvas.draw_line(at-Vector2(0,65),app.layout.project(battle.position(id)+battle.vector(a.direction)*.8)-Vector2(0,65),color,6)
 if id=="twitch" and a.phase=="windup" and a.get("echo_knee",false):canvas.draw_line(at+Vector2(-10,-30),at+Vector2(-25,-15),Color("d3c2a0"),7)
 if id=="dog":canvas.draw_line(at+Vector2(-16,-36),at+Vector2(16,-36),Color("ae4e4b"),5)
 if id=="self":draw_known_hand_marks(at,h)
 if battle.chapter_id==6:draw_material_pose(id,at,h);draw_display_pose(id,at,h);draw_archivist_pose(id,at,h)
 if battle.chapter_id==6 and id=="mother":
  canvas.poly([at+Vector2(-12,-85),at+Vector2(12,-85),at+Vector2(19,-32),at+Vector2(-19,-32)],Color("858875"))
  if a.phase in ["windup","attack","grip"]:
   for index in range(3):
    var eye:Vector2=at+Vector2((index-1)*9,-56+abs(index-1)*5)
    canvas.draw_circle(eye,4,Color("c1baa3"));canvas.draw_circle(eye,1.5,Color("4c4250"))
 if a.phase in ["windup","attack","recover","grip"] and not (battle.chapter_id==6 and id in ["transporter_hospital","dislocated","isolation","ward_nurse","pharmacist","father","warder","assistant_asylum","psychiatrist","guard_hospital","director","mother","doctor","skinface"]):
  var direction:Vector2=battle.vector(a.direction)
  var attack:Dictionary=battle.config.attacks[str(s.attack)]
  var end:Vector2=app.layout.project(battle.position(id)+direction*float(attack.reach))
  var warning:Color=Color("edc37e") if a.phase=="windup" else Color("d18f7c")
  canvas.draw_line(at,end,Color(warning,.5),5)
  var reach:float=clampf(float(a.elapsed)/float(attack.windup),0,1) if a.phase=="windup" else 1.0 if a.phase in ["attack","grip"] else .25
  canvas.draw_line(at-Vector2(0,h*.55),at.lerp(end,reach)-Vector2(0,h*.55),warning,7)
 if a.phase in ["report_side","report_retreat"]:
  text(at-Vector2(0,h+12),str(s.get("display_name",s.name))+" · "+("沿侧边调整" if a.phase=="report_side" else "受袭退避"),14);return
 text(at-Vector2(0,h+12),str(s.get("display_name",s.name))+" · "+{"idle":"待机","windup":"起手","attack":"出手","recover":"收招","grip":"抓握","display":"展示","point":"指向目视危险" if id=="speaker" else "指路","bandage":"包扎","push":"推车","cloth":"展开黑布","mimic":"模仿","drug_hold":"扣头","box_prepare":"抬盒","bed_turn":"过门转向","bed_travel":"推床随行","bed_retreat":"退离门口","tear":"撕扯随身纸条","paper_hold":"攥住残片","box_flip":"翻起空盒","box_number":"查看编号","box_stow":"整理空盒","cart_park":"走向侧停清洁车","pick_label":"拾取地面标签","wipe":"擦拭接触区域","bag_label":"送入随车污物袋","bag_seal":"封口","walk":"走近痕迹","display_retreat":"受伤后退避","stamp":"盖章","number_show":"展示号码纸","paper_stow":"收回号码纸","number_front":"编号正面","number_turn":"转身","number_back":"另一面编号","chair_aside":"调椅让路","entry_point":"指向原入口","band_raise":"举起自身腕带","protect_photo":"护住照片","protect_body":"收臂护身","dressing_open":"掀开敷料","dressing_show":"露出注销标记","dressing_cover":"按回敷料","branch_point":"指向维护入口","clip_read":"查看转运夹","cloth_raise":"抬起黑布","cloth_close":"收拢黑布","mimic_write":"记录板书写","board_raise":"举板","board_knock":"敲板","paper_approach":"走近落地纸","paper_pick":"接触拾纸","paper_store":"收进内侧文件夹"}.get(str(a.phase),str(a.phase)),14)

func draw_street_surfaces() -> void:
 for shot in battle.splash.state().shots:
  if shot.room!=app.room_id:continue
  for ray in shot.rays:
   if float(ray.ground_at)<0:continue
   var left:float=1.0-clampf((float(shot.age)-float(ray.ground_at))/float(battle.config.test_parameters.splash_ground_s),0,1)
   var at:Vector2=app.layout.project(battle.vector(ray.pos))
   canvas.draw_set_transform(at,0,Vector2(1,.38));canvas.draw_circle(Vector2.ZERO,4,Color(.48,.61,.64,.55*left));canvas.draw_set_transform(Vector2.ZERO)
 for item in battle.data.get("materials",{}).get("surfaces",{}).values():
  if item.room!=app.room_id or not battle.materials.available(item):continue
  var at:Vector2=app.layout.project(battle.vector(item.pos));var alpha:float=1.0-float(item.progress)
  if str(item.kind) in ["label","number_paper"]:
   canvas.draw_rect(Rect2(at-Vector2(9,4),Vector2(18,8)),Color("c5ba96"))
   canvas.draw_line(at-Vector2(6,0),at+Vector2(5,0),Color("6f6b67"),2)
  else:
   canvas.draw_line(at-Vector2(16,2),at+Vector2(16,3),Color(Color("754c52") if item.kind=="blood" else Color("8d8574"),alpha*.8),5)

func draw_material_pose(id:String,at:Vector2,h:float) -> void:
 var a:Dictionary=battle.data.actors[id];var all:Dictionary=battle.data.get("materials",{})
 if all.is_empty():return
 if id in ["speaker","stitched"]:
  var s:Dictionary=all.speaker if id=="speaker" else all.stitched
  var progress:float=clampf(float(s.tear)/float(battle.config.test_parameters.paper_tear_s),0,1)
  if id=="speaker":
   canvas.draw_polyline(PackedVector2Array([at-Vector2(15,h*.6),at-Vector2(25,h*.4),at-Vector2(17,h*.34)]),Color("484851"),3)
  var paper:Vector2=at+Vector2(22*progress,-h*(.72-.27*progress))
  canvas.draw_rect(Rect2(paper-Vector2(13,5),Vector2(26,10)),Color("cbbfa0"))
  canvas.draw_line(at+Vector2(14,-h*.5),paper,Color("ac9d88"),5)
  if progress<1:canvas.draw_line(paper-Vector2(8,0),paper+Vector2(8,0),Color("796a65"),2)
  if id=="speaker" and a.phase=="point":canvas.draw_line(at-Vector2(0,h*.5),app.layout.project(battle.position(id)+battle.vector(a.direction)*.9)-Vector2(0,h*.5),Color("91b5a1"),6)
 elif id=="treatment_pharmacist":
  for side in [-1,0,1]:canvas.draw_rect(Rect2(at+Vector2(side*11-4,-h*.5),Vector2(8,15)),Color("b6b7a0"))
  if a.phase in ["box_flip","box_number"]:
   var p:Vector2=at+Vector2(25,-h*.57)
   canvas.draw_rect(Rect2(p-Vector2(9,7),Vector2(18,14)),Color("c8c2a6"))
   canvas.draw_rect(Rect2(p-Vector2(6,4),Vector2(12,7)),Color("53575e"))
   canvas.draw_line(p-Vector2(7,-5),p+Vector2(6,5),Color("8e7e70"),2)
 elif id=="cleaner":
  if a.phase in ["wipe","pick_label"]:canvas.draw_line(at-Vector2(0,h*.45),at+Vector2(15,-7),Color("b7b4a0"),6)
  if a.phase=="bag_label":canvas.draw_rect(Rect2(at+Vector2(16,-h*.4),Vector2(16,8)),Color("c5ba96"))
  # Only the original already held by this same cleaner is displayed; never copy hero inventory.
  if str(app.rules.owners.get("asylum_corpse_wristband",""))=="asylum_cleaner_bucket":canvas.draw_arc(at+Vector2(20,-h*.3),7,0,TAU,16,Color("c2bca0"),3)

func draw_box(box:Dictionary) -> void:
 var at:Vector2=battle.vector(box.pos);var height:float=float(box.height)*78;var bottom:Array=[];var top:Array=[]
 canvas.draw_circle(app.layout.project(at),13,Color(0,0,0,.2))
 for offset in [Vector2(-.16,-.14),Vector2(.16,-.14),Vector2(.16,.14),Vector2(-.16,.14)]:
  bottom.append(app.layout.project(at+offset)-Vector2(0,height));top.append(app.layout.project(at+offset)-Vector2(0,height+18))
 for i in range(4):canvas.poly([bottom[i],bottom[(i+1)%4],top[(i+1)%4],top[i]],Color("9c896d"))
 canvas.poly(top,Color("baaa86"));canvas.draw_line(top[0].lerp(top[1],.5),top[3].lerp(top[2],.5),Color("d6c6a3"),3)

func draw_bed(at:Vector2,direction:Vector2) -> void:
 var footprint:PackedVector2Array=battle.Bed.polygon(at,direction);var ground:Array=[];var top:Array=[]
 for p in footprint:ground.append(app.layout.project(p));top.append(app.layout.project(p)-Vector2(0,48))
 for i in range(4):
  var j:int=(i+1)%4
  canvas.poly([ground[i],ground[j],top[j],top[i]],Color("718982"))
 canvas.poly(top,Color("a9b9ab"));canvas.draw_polyline(PackedVector2Array(top+[top[0]]),Color("d0d6bd"),2)
 for t in [.3,.65]:canvas.draw_line(top[0].lerp(top[1],t),top[3].lerp(top[2],t),Color("675c62"),5)

func draw_rack(prop:Dictionary) -> void:
 var center:Vector2=app.layout.project(prop.rect.get_center());var swing:float=float(battle.data.get("rack_sound",{}).get("swing",0))
 var sway:float=sin(swing*26.0)*swing*9
 canvas.draw_line(center+Vector2(-20,0),center+Vector2(20,0),Color("6c7770"),5)
 canvas.draw_line(center,center-Vector2(0,130),Color("6c7770"),4)
 canvas.draw_line(center+Vector2(-24,-125),center+Vector2(24,-125),Color("abb6ac"),4)
 canvas.poly([center+Vector2(-22+sway,-119),center+Vector2(22+sway,-119),center+Vector2(28+sway,-35),center+Vector2(-25+sway,-35)],Color("c3c7bb"))

func draw_main_ending() -> void:
 var e:Dictionary=battle.data.get("ending",{})
 if e.is_empty():return
 var at:Vector2=app.layout.project(app.hero_pos)
 canvas.draw_rect(Rect2(at-Vector2(1800,1000),Vector2(3600,2000)),Color(.07,.12,.12,.9))
 var label:String={"registration":"机构登记：自行离院","dialogue":"终点门内 · 原出口对白","wake":"现实病床 · 身体睁眼（演出占位）","planet":"来处星球 · 玩家恢复感知（演出占位）","complete":"本次流程结束"}.get(str(e.phase),"")
 text(at-Vector2(0,150),label,24)
 if e.phase=="wake":text(at-Vector2(0,90),"角色接续身体" if e.id=="E2" else "玩家接续身体",20)

func draw_gate(prop:Dictionary) -> void:
 var center:Vector2=prop.rect.get_center();var h:float=float(prop.height)
 var a:Vector2=center+Vector2(0,-.85);var b:Vector2=center+Vector2(0,.85)
 for at in [a,b]:canvas.prism(Rect2(at-Vector2(.1,.1),Vector2(.2,.2)),h,Color("adaca0"))
 canvas.draw_line(app.layout.project(a)-Vector2(0,h),app.layout.project(b)-Vector2(0,h),Color("c8c6af"),12)

func draw_chair(at:Vector2) -> void:
 var footprint:Rect2=battle.displays.chair_rect(battle.position("wheelchair"));var points:Array=[]
 for p in [footprint.position,Vector2(footprint.end.x,footprint.position.y),footprint.end,Vector2(footprint.position.x,footprint.end.y)]:points.append(app.layout.project(p))
 canvas.poly(points,Color("4e555e"))
 for side in [-1,1]:
  canvas.draw_arc(at+Vector2(side*24,-17),19,0,TAU,24,Color("b0b1a4"),4)
  canvas.draw_line(at+Vector2(side*18,-54),at+Vector2(side*23,-16),Color("858f8f"),5)
 canvas.draw_line(at+Vector2(-19,-23),at+Vector2(19,-23),Color("9fa49a"),5)

func draw_display_pose(id:String,at:Vector2,h:float) -> void:
 if id in ["informant","head_nurse"]:
  var a:Dictionary=battle.data.actors[id]
  if id=="head_nurse":canvas.draw_rect(Rect2(at+Vector2(-17,-h*.6),Vector2(22,26)),Color("c2b99b"))
  else:
   # Informant carries permission/number paper, never the head nurse's board.
   canvas.draw_line(at-Vector2(0,h*.72),at-Vector2(0,h*.56),Color("7e756a"),2)
   canvas.draw_rect(Rect2(at+Vector2(-7,-h*.58),Vector2(14,16)),Color("c2b99b"))
   canvas.draw_rect(Rect2(at+Vector2(14,-h*.5),Vector2(6,18)),Color("c2b99b"))
  if a.phase=="point":canvas.draw_line(at+Vector2(13,-h*.55),app.layout.project(battle.position(id)+battle.vector(a.direction)*.85)-Vector2(0,h*.55),Color("b9af97"),6)
  elif a.phase in ["board_raise","board_knock"]:
   var hand:Vector2=at+Vector2(-3,-h*(.54 if a.phase=="board_knock" else .72))
   canvas.draw_line(at+Vector2(13,-h*.55),hand,Color("b9af97"),6)
   if a.phase=="board_knock":canvas.draw_arc(hand,11,-.8,.8,12,Color("d8c7a1"),2)
 draw_report_look(id,at,h)
 if id=="dislocated":draw_clamp_pose(at,h)
 if id=="ward_nurse":draw_medicine_pose(at,h)
 if id=="pharmacist":draw_splash_cup(at,h)
 if id=="isolation":
  # The deformed observation frame follows the guard, never a separate door.
  var frame:=Rect2(at-Vector2(16,h*.76),Vector2(32,27))
  canvas.draw_rect(frame,Color("464c53"),false,4)
  var phase:String=str(battle.embrace.state().phase)
  text(at-Vector2(0,h+34),{"folded":"软垫双臂收回","arms_raise":"抬起双臂","arms_open":"双臂张开","closing":"合臂围抱","held":"双臂压制躯干","opening":"松手张臂收招"}.get(phase,phase)+"（占位）",11)
 if id=="director":
  var state:Dictionary=battle.director.state();var recorder:Vector2=at-Vector2(0,h*.62)
  canvas.draw_rect(Rect2(recorder-Vector2(9,6),Vector2(18,12)),Color("414d52"));canvas.draw_circle(recorder+Vector2(5,0),2,Color("b59271") if int(battle.data.clock*3)%2==0 else Color("765c50"))
  text(at-Vector2(0,h+34),{"folded":"椅架收好","rails_raise":"抬起相连椅架","rails_open":"两侧展开","rails_close":"实际合拢","torso_fixed":"椅架夹住躯干","rails_release":"张开释放"}.get(str(state.phase),str(state.phase))+"（占位）",11)
 if id in battle.grasp_motion.IDS:
  var grasp:Dictionary=battle.grasp_motion.state(id)
  if id=="psychiatrist":
   canvas.draw_rect(Rect2(at+Vector2(12,-h*.59),Vector2(15,11)),Color("b2aa8c"));canvas.draw_line(at+Vector2(15,-h*.56),at+Vector2(23,-h*.56),Color("817d70"),1)
  else:
   var key:Vector2=at+Vector2(18,-h*.4);canvas.draw_arc(key,4,0,TAU,12,Color("c1b28e"),2);canvas.draw_line(key+Vector2(0,4),key+Vector2(0,12),Color("c1b28e"),2)
  text(at-Vector2(0,h+34),{"lowered":"固定扣收好" if id=="psychiatrist" else "前臂收回","clasp_raise":"举起固定扣","hand_raise":"抬手准备","reach":"伸手套腕","close":"实际扣合","turn_inward":"侧转朝门内","pull":"沿地面后拖","push_inward":"向门内推离","open_retract":"松扣收臂","legacy_fixed":"旧档原位固定"}.get(str(grasp.phase),str(grasp.phase))+"（占位）",11)
 if id=="assistant_asylum":
  canvas.draw_rect(Rect2(at+Vector2(17,-h*.5),Vector2(15,20)),Color("c2b99b"))
  text(at-Vector2(0,h+34),{"folded":"收好束带","loop_open":"展开带圈","arm_extend":"伸手套腕","tighten":"实际收紧","fixed":"短暂固定","release_retract":"松开收带"}.get(str(battle.restraint.state().phase),"")+"（占位）",11)
 if id=="warder":
  var phase:String=str(battle.belt.state().phase)
  for side in [-1,1]:
   var elbow:Vector2=at+Vector2(side*18,-h*.43);var hand:Vector2=app.layout.project(battle.position(id)+battle.belt.direction()*.28)-Vector2(0,float(battle.config.test_parameters.belt_waist_px))
   canvas.draw_line(at+Vector2(side*13,-h*.65),elbow,Color("a19b88"),6);canvas.draw_line(elbow,hand,Color("a19b88"),6)
   canvas.draw_line(elbow-Vector2(4,3),elbow+Vector2(4,3),Color("d0bca1"),3)
  text(at-Vector2(0,h+34),{"wrapped":"双臂缠带","side_draw":"侧身抽带","strap_uncoil":"拉开带端","waist_sweep":"腰腹横扫","strap_retract":"回收束带"}.get(phase,phase)+"（占位）",11)
 if id=="transporter_hospital":
  text(at-Vector2(0,h+34),"灰工服 · 手套 · 污衣袋带（占位）",11)
 if id not in battle.displays.IDS:return
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.displays.state(id)
 var paper:Color=Color("cdc2a1");var ink:Color=Color("5e5960");var skin:Color=Color("b9af97")
 if id=="register_nurse":
  var sheet:Vector2=at+Vector2(27,-h*(.58 if a.phase=="number_show" else .32))
  canvas.draw_rect(Rect2(sheet-Vector2(13,10),Vector2(26,20)),paper)
  canvas.draw_line(at+Vector2(13,-h*.5),sheet,skin,5)
  if a.phase=="stamp":canvas.draw_rect(Rect2(sheet+Vector2(-5,-18),Vector2(9,12)),Color("864e53"))
  if a.phase=="number_show":text(sheet+Vector2(0,4),"编号待核",9)
 elif id=="back":
  var top:Vector2=at-Vector2(0,h*.57)
  canvas.draw_rect(Rect2(top-Vector2(13,7),Vector2(26,14)),paper)
  text(top+Vector2(0,4),"面B" if s.turned else "面A",10)
  if a.phase=="number_turn":canvas.draw_arc(at-Vector2(0,h*.85),16,0,float(s.elapsed)/float(battle.config.test_parameters.face_turn_s)*TAU,20,ink,3)
 elif id in ["wheelchair","transport_patient"]:
  var protect:bool=a.phase in ["protect_photo","protect_body"]
  var hand:Vector2=at+Vector2(3 if protect else 27,-h*(.55 if protect else .47))
  canvas.draw_line(at+Vector2(12,-h*.53),hand,skin,6)
  if id=="wheelchair":
   canvas.draw_rect(Rect2(hand-Vector2(10,9),Vector2(20,18)),paper)
   canvas.draw_circle(hand+Vector2(0,-2),4,ink)
   if protect:canvas.draw_line(at+Vector2(-12,-h*.5),hand+Vector2(7,4),skin,6)
  else:
   canvas.draw_line(at+Vector2(-16,-h*.25),at+Vector2(14,-h*.18),paper,5)
   canvas.draw_arc(hand,7,0,TAU,16,paper,3)
  if a.phase=="entry_point":canvas.draw_line(hand,app.layout.project(battle.position(id)+battle.vector(a.direction)*.65)-Vector2(0,h*.5),skin,5)
 elif id=="postop":
  var mark:Vector2=at+Vector2(9,-h*.52)
  canvas.draw_rect(Rect2(mark-Vector2(12,10),Vector2(24,20)),Color("705d63") if a.phase=="dressing_show" else paper)
  canvas.draw_line(at+Vector2(-13,-h*.55),mark+Vector2(-9,-12 if a.phase=="dressing_show" else 0),skin,5)
  if a.phase=="dressing_show":text(mark+Vector2(0,4),"注销",11)
 elif id=="triage":
  canvas.draw_line(at+Vector2(-13,-h*.88),at+Vector2(13,-h*.88),Color("96525b"),4)
  canvas.draw_rect(Rect2(at+Vector2(-12,-h*.59),Vector2(24,25)),paper)
  if a.phase=="clip_read":text(at-Vector2(0,h*.4),"批次栏",10)
  elif a.phase=="branch_point":canvas.draw_line(at-Vector2(0,h*.5),app.layout.project(battle.position(id)+battle.vector(a.direction)*.8)-Vector2(0,h*.5),skin,6)
 elif id=="blind":
  canvas.draw_line(at+Vector2(-12,-h*.88),at+Vector2(12,-h*.88),Color("2a2a36"),6)
  if a.phase in ["cloth","cloth_raise","cloth_close"]:
   var left:Vector2=app.layout.project(battle.position(id)+Vector2(-.6,.2));var right:Vector2=app.layout.project(battle.position(id)+Vector2(.6,1.2))
   var raised:float=1.0 if a.phase=="cloth" else clampf(float(s.elapsed)/.3,0,1) if a.phase=="cloth_raise" else 1.0-clampf(float(s.elapsed)/.3,0,1)
   canvas.poly([left-Vector2(0,12+90*raised),right-Vector2(0,12+90*raised),right-Vector2(0,12),left-Vector2(0,12)],Color("292a37"))
   canvas.draw_line(at-Vector2(0,h*.55),left-Vector2(0,12+90*raised),skin,5)
 elif id=="mimic":
  var board:Vector2=at-Vector2(0,h*.43)
  canvas.draw_rect(Rect2(board-Vector2(19,14),Vector2(38,28)),paper)
  if a.phase=="mimic":
   var offset:Vector2=Vector2(22,-h*.85) if a.get("mimic","") in ["tinnitus","give","scratch"] else Vector2(29,-h*.4)
   canvas.draw_line(at+Vector2(12,-h*.58),at+offset,skin,6)
  elif a.phase=="mimic_write":
   var t:float=clampf(float(s.elapsed)/float(battle.config.test_parameters.mimic_write_s),0,1)
   canvas.draw_line(board-Vector2(12,0),board+Vector2(-12+24*t,0),ink,2)
   canvas.draw_line(at+Vector2(15,-h*.6),board+Vector2(-12+24*t,0),skin,5)
  elif s.get("last_written",false):text(board+Vector2(0,4),"自主行为",10)

func draw_mother_arm(index:int) -> void:
 var arm:Array=battle.mother.state().arms[index];var height:float=float(battle.config.test_parameters.mother_heights_px[index/2])
 var shoulder:Vector2=app.layout.project(battle.vector(arm[0]))-Vector2(0,height+10)
 var elbow:Vector2=app.layout.project(battle.vector(arm[1]))-Vector2(0,height)
 var hand:Vector2=app.layout.project(battle.vector(arm[2]))-Vector2(0,height)
 canvas.draw_line(shoulder,elbow,Color("939684") if index<2 else Color("777c71"),7)
 canvas.draw_line(elbow,hand,Color("b6af98"),6);canvas.draw_circle(hand,4,Color("bfb59d"))

func draw_local_sweep(id:String,index:int) -> void:
 var s:Dictionary=battle.local_sweeps.state(id);var limb:Array=s.limbs[index];var height:float=float(s.height_px)
 var shoulder:Vector2=app.layout.project(battle.vector(limb[0]))-Vector2(0,80)
 var hand:Vector2=app.layout.project(battle.vector(limb[1]))-Vector2(0,height)
 var tip:Vector2=app.layout.project(battle.vector(limb[2]))-Vector2(0,height)
 canvas.draw_line(shoulder,hand,Color("b9bcaf") if id=="doctor" else Color("9b8c89"),7)
 if id=="doctor":
  canvas.draw_line(hand,tip,Color("d0d6ce"),4);canvas.draw_line(hand,hand+(tip-hand)*.15,Color("595956"),7)
 else:canvas.draw_line(hand,tip,Color("bdb19d"),6)
 canvas.draw_circle(hand,4,Color("bdb49e"))

func draw_director_rail(index:int) -> void:
 var a:Dictionary=battle.data.actors.director;var s:Dictionary=battle.director.state()
 if index>=s.frames.size():return
 var frame:Array=s.frames[index];var h:float=0 if a.hp<=0 else float(battle.config.test_parameters.director_rail_height_px);var points:=PackedVector2Array()
 for p in frame:points.append(app.layout.project(battle.vector(p))-Vector2(0,h))
 canvas.draw_polyline(points,Color("47535a"),8);canvas.draw_polyline(points,Color("a9b1aa"),4)
 for j in [1,2]:
  canvas.draw_circle(points[j],3,Color("d0c6ad"));canvas.draw_line(points[j],points[j]+Vector2(0,18),Color("7f8d8b"),4)
 if a.hp>0:
  var shoulder:Vector2=app.layout.project(battle.vector(frame[0]))-Vector2(0,82)
  canvas.draw_line(shoulder,points[1],Color("b6b39e"),6)

func draw_grasp_arm(id:String) -> void:
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.grasp_motion.state(id)
 var hand:Vector2=app.layout.project(battle.vector(s.hand))-Vector2(0,0 if a.hp<=0 else float(battle.config.test_parameters.grasp_hand_height_px))
 if a.hp>0:
  var root:Vector2=app.layout.project(battle.grasp_motion.shoulder(id))-Vector2(0,82);var elbow:Vector2=root.lerp(hand,.5)+Vector2(-4,6)
  canvas.draw_line(root,elbow,Color("b7bdaf") if id=="psychiatrist" else Color("596878"),8);canvas.draw_line(elbow,hand,Color("b5b3a1"),6)
  if s.phase=="turn_inward":canvas.draw_arc(app.layout.project(battle.position(id))-Vector2(0,75),14,-.8,.8,16,Color("c2b58d"),2)
 draw_grasp_fingers(id,hand,float(s.open))

func draw_grasp_fingers(id:String,hand:Vector2,opened:float) -> void:
 if id=="psychiatrist":canvas.draw_arc(hand,5,-.3 if opened>.5 else 0,PI*1.2 if opened>.5 else TAU,16,Color("bfc3b3"),3)
 else:
  for i in range(3):canvas.draw_line(hand+Vector2(-3+i*3,-4),hand+Vector2(-4+i*3,lerpf(5,1,opened)),Color("b7b4a0"),2)

func draw_grasp_wrist(at:Vector2) -> void:
 var id:String=str(battle.data.holder)
 if id not in battle.grasp_motion.IDS:return
 var a:Dictionary=battle.data.actors[id];var s:Dictionary=battle.grasp_motion.state(id)
 if not a.present or a.room!=app.room_id or a.hp<=0:return
 var hand:Vector2=app.layout.project(battle.vector(s.hand))-Vector2(0,float(battle.config.test_parameters.grasp_hand_height_px))
 var elbow:Vector2=(at-Vector2(0,77)).lerp(hand,.5)+Vector2(6,5)
 canvas.draw_line(at-Vector2(0,77),elbow,Color("9eb6be"),6);canvas.draw_line(elbow,hand,Color("bcb9a1"),4);canvas.draw_circle(hand,3,Color("bcb9a1"));draw_grasp_fingers(id,hand,0)

func draw_restraint_wrist(at:Vector2) -> void:
 var a:Dictionary=battle.data.actors.assistant_asylum;var s:Dictionary=battle.restraint.state()
 if not a.present or a.hp<=0 or a.room!=app.room_id or a.phase not in ["attack","grip"] or s.pose.is_empty():return
 var center:Vector2=battle.vector(s.pose.center)
 if center.distance_to(app.hero_pos)>.5:return
 var facing:Vector2=app.hero_facing.normalized();var side:=Vector2(-facing.y,facing.x);var wrist:Vector2=app.hero_pos+side*float(battle.config.test_parameters.restraint_wrist_m)
 var other:Vector2=app.hero_pos-side*float(battle.config.test_parameters.restraint_wrist_m)
 if other.distance_to(center)<wrist.distance_to(center):wrist=other
 var height:float=float(battle.config.test_parameters.restraint_arm_px);var hand:Vector2=app.layout.project(wrist)-Vector2(0,height)
 var shoulder:Vector2=at-Vector2(0,77);var elbow:Vector2=shoulder.lerp(hand,.5)+Vector2(6,5)
 canvas.draw_line(shoulder,elbow,Color("9eb6be"),6);canvas.draw_line(elbow,hand,Color("bcb9a1"),4);canvas.draw_circle(hand,3,Color("bcb9a1"))
 draw_restraint_loop_half(1)

func draw_restraint_arm(index:int) -> void:
 var pose:Dictionary=battle.restraint.state().pose
 if pose.is_empty():return
 var points:=PackedVector2Array()
 for p in pose.arms[index]:points.append(app.layout.project(battle.vector(p))-Vector2(0,float(battle.config.test_parameters.restraint_arm_px)))
 canvas.draw_polyline(points,Color("a9a99c"),6)

func draw_restraint_loop() -> void:
 var a:Dictionary=battle.data.actors.assistant_asylum;var pose:Dictionary=battle.restraint.state().pose
 if pose.is_empty():return
 var hero_overlap:bool=a.room==app.room_id and battle.vector(pose.center).distance_to(app.hero_pos)<=.5 and a.phase in ["attack","grip"]
 draw_restraint_loop_half(-1 if hero_overlap else 0)

func draw_restraint_loop_half(part:int) -> void:
 var pose:Dictionary=battle.restraint.state().pose
 if pose.is_empty():return
 var center:Vector2=app.layout.project(battle.vector(pose.center));var height:float=float(battle.config.test_parameters.restraint_arm_px)
 for i in range(1,pose.loop.size()):
  var start:Vector2=app.layout.project(battle.vector(pose.loop[i-1]));var end:Vector2=app.layout.project(battle.vector(pose.loop[i]))
  var front:bool=(start.y+end.y)*.5>=center.y
  if part==1 and not front or part==-1 and front:continue
  canvas.draw_line(start-Vector2(0,height),end-Vector2(0,height),Color("5b4e4b"),6);canvas.draw_line(start-Vector2(0,height),end-Vector2(0,height),Color("c5ae88"),3)

func draw_warder_belt(index:int) -> void:
 var a:Dictionary=battle.data.actors.warder;var s:Dictionary=battle.belt.state()
 if index>=s.profile.size():return
 var height:float=0 if a.hp<=0 else float(battle.config.test_parameters.belt_waist_px)
 var start:Vector2=app.layout.project(battle.vector(s.profile[index-1]))-Vector2(0,height);var end:Vector2=app.layout.project(battle.vector(s.profile[index]))-Vector2(0,height)
 canvas.draw_line(start,end,Color("5b4e4b"),6);canvas.draw_line(start,end,Color("c5ae88"),3)
 if index==s.profile.size()-1:canvas.draw_line(end-Vector2(2,3),end+Vector2(2,3),Color("e0cfaa"),2)

func draw_father_bottle() -> void:
 var a:Dictionary=battle.data.actors.father;var s:Dictionary=battle.bottle.state()
 if s.profile.is_empty():return
 var t:float=clampf(float(a.elapsed)/float(battle.config.attacks.sweep.windup),0,1) if a.phase=="windup" else 1.0 if a.phase=="attack" else 1.0-clampf(float(a.elapsed)/float(battle.config.attacks.sweep.recover),0,1) if a.phase=="recover" else 0.0
 var height:float=0 if a.hp<=0 else lerpf(63,float(battle.config.test_parameters.bottle_raise_px),t)
 var neck:Vector2=app.layout.project(battle.vector(s.profile[0]))-Vector2(0,height);var tip:Vector2=app.layout.project(battle.vector(s.profile[1]))-Vector2(0,height)
 var forward:Vector2=(tip-neck).normalized();var side:=Vector2(-forward.y,forward.x)
 if a.hp>0:
  var at:Vector2=app.layout.project(battle.position("father"));var shoulder:Vector2=at+Vector2(-12,-84);var elbow:Vector2=shoulder.lerp(neck,.5)-Vector2(0,8 if a.phase=="windup" else 0)
  canvas.draw_line(shoulder,elbow,Color("a19b88"),6);canvas.draw_line(elbow,neck,Color("a19b88"),6)
 canvas.draw_line(neck,neck.lerp(tip,.4),Color("6f8980"),5)
 canvas.poly([neck.lerp(tip,.35)-side*4,tip-side*7,tip-forward*4,tip+side*5,neck.lerp(tip,.35)+side*4],Color("84988b"))
 canvas.draw_line(tip-side*7,tip-forward*4,Color("c0c8b2"),2);canvas.draw_line(tip-forward*4,tip+side*5,Color("c0c8b2"),2)
 if a.hp>0:text(app.layout.project(battle.position("father"))-Vector2(0,167),{"lowered":"粘连碎瓶","shoulder_turn":"转肩固定方向","bottle_raise":"举起碎瓶","glass_sweep":"瓶口横扫","arm_retract":"收臂恢复"}.get(str(s.phase),str(s.phase))+"（占位）",11)

func draw_splash_ray(shot_index:int,ray_index:int) -> void:
 var shot:Dictionary=battle.splash.state().shots[shot_index];var ray:Dictionary=shot.rays[ray_index]
 var t:float=clampf(float(shot.age)/float(battle.config.attacks.splash.active),0,1)
 var height:float=lerpf(float(battle.config.test_parameters.splash_release_height_px),float(battle.config.test_parameters.splash_ground_height_px),t)
 var at:Vector2=app.layout.project(battle.vector(ray.pos))-Vector2(0,height)
 if not ray.path.is_empty():
  var last:Vector2=app.layout.project(battle.vector(ray.path[0]))-Vector2(0,lerpf(float(battle.config.test_parameters.splash_release_height_px),float(battle.config.test_parameters.splash_ground_height_px),clampf(float(shot.get("previous_age",0))/float(battle.config.attacks.splash.active),0,1)))
  canvas.draw_line(last,at,Color("8faeb2"),3)
 canvas.draw_circle(at,2,Color("b3c4bd"))

func draw_splash_cup(at:Vector2,h:float) -> void:
 var a:Dictionary=battle.data.actors.pharmacist;var phase:String=str(battle.splash.state().phase)
 var raised:float=clampf(float(a.elapsed)/float(battle.config.attacks.splash.windup)*2,0,1) if a.phase=="windup" else 1.0 if a.phase=="attack" else 1.0-clampf(float(a.elapsed)/float(battle.config.attacks.splash.recover),0,1) if a.phase=="recover" else 0.0
 var cup:Vector2=app.layout.project(battle.splash.cup())-Vector2(0,lerpf(h*.48,float(battle.config.test_parameters.splash_release_height_px),raised))
 canvas.draw_line(at+Vector2(12,-h*.5),cup,Color("b2b7a6"),6)
 var tilt:float=.65 if phase in ["cup_tip","release"] else 0
 canvas.poly([cup+Vector2(-7,-5).rotated(tilt),cup+Vector2(7,-5).rotated(tilt),cup+Vector2(4,7).rotated(tilt),cup+Vector2(-4,7).rotated(tilt)],Color("bab79e"))
 if a.portions>0:canvas.draw_line(cup+Vector2(-4,3-float(a.portions)*2),cup+Vector2(4,3-float(a.portions)*2),Color("8faeb2"),3)
 # A short mark stands for the still-unspecified cup number, not invented text.
 canvas.draw_line(cup+Vector2(-2,3),cup+Vector2(2,3),Color("676773"),2)
 if phase=="cup_tip":
  var end:Vector2=app.layout.project(battle.position("pharmacist")+battle.splash.direction()*.75)-Vector2(0,float(battle.config.test_parameters.splash_release_height_px))
  canvas.draw_line(cup,end,Color(.78,.74,.56,.65),2)
 text(at-Vector2(0,h+34),{"ready":"掌中编号杯 · 字形待定","cup_raise":"抬杯预告","cup_tip":"倾杯预告方向","release":"局部泼出","cup_withdraw":"收回原杯","empty":"杯中已空","lowered":"原杯放下"}.get(phase,phase)+"（占位）",11)

func draw_medicine_pose(at:Vector2,h:float) -> void:
 var s:Dictionary=battle.medicine.state();var a:Dictionary=battle.data.actors.ward_nurse
 var head:Vector2=app.layout.project(battle.vector(s.head))-Vector2(0,float(battle.config.test_parameters.medicine_head_anchor_px))
 var mouth:Vector2=app.layout.project(battle.vector(s.goal))-Vector2(0,float(battle.config.test_parameters.medicine_mouth_anchor_px))
 var cup:Vector2=app.layout.project(battle.vector(s.cup))-Vector2(0,float(battle.config.test_parameters.medicine_mouth_anchor_px) if a.phase=="drug_hold" else float(battle.config.test_parameters.medicine_cup_rest_px))
 if a.phase in ["windup","attack","drug_hold","recover"]:
  canvas.draw_line(at+Vector2(-12,-h*.6),head,Color("abb1a1"),6)
  canvas.draw_circle(head,5,Color("c4bea8"))
 canvas.draw_line(at+Vector2(12,-h*.53),cup,Color("b2b7a6"),6)
 var tilt:float=.65 if s.phase=="pouring" else .35 if s.phase=="cup_tilt" else 0
 var lip:Vector2=cup+Vector2(8,-5).rotated(tilt);var base:Vector2=cup+Vector2(4,7).rotated(tilt)
 canvas.poly([cup+Vector2(-8,-5).rotated(tilt),lip,base,cup+Vector2(-4,7).rotated(tilt)],Color("c0ba9f"))
 if a.portions>0 or s.dose=="pouring":canvas.draw_line(cup-Vector2(5,2),cup+Vector2(5,2),Color("8b9fa4"),3)
 if s.dose=="pouring" and a.phase=="drug_hold":canvas.draw_line(lip,mouth,Color("8b9fa4"),2)
 text(at-Vector2(0,h+34),{"ready":"掌中药杯","reach_head":"伸手扣头","head_fixed":"已扣头 · 尚未给药","cup_approach":"移杯靠近嘴部","cup_tilt":"杯口接触 · 倾杯","pouring":"药液送入口中","withdraw_cup":"松手撤杯","lowered":"药杯放下"}.get(str(s.phase),str(s.phase))+"（占位）",11)

func draw_embrace_arm(index:int) -> void:
 var s:Dictionary=battle.embrace.state();var points:=PackedVector2Array()
 for p in s.arms[index]:points.append(app.layout.project(battle.vector(p))-Vector2(0,64))
 if points.size()!=3:return
 canvas.draw_polyline(points,Color("51575a"),13)
 canvas.draw_polyline(points,Color("abb2a7"),9)
 canvas.draw_circle(points[1],7,Color("969e96"));canvas.draw_circle(points[2],5,Color("c5bea7"))

func draw_clamp_pose(at:Vector2,h:float) -> void:
 var s:Dictionary=battle.clamp.state();var shoulder:Vector2=app.layout.project(battle.clamp.shoulder())-Vector2(0,72)
 var tip:Vector2=app.layout.project(battle.vector(s.tip))-Vector2(0,66)
 var elbow:Vector2=shoulder.lerp(tip,.5)-Vector2(0,12 if s.phase in ["shoulder_raise","jaw_open"] else 2)
 canvas.draw_line(shoulder,elbow,Color("b3ada0"),6);canvas.draw_line(elbow,tip,Color("9f9d95"),6)
 var forward:Vector2=(tip-elbow).normalized();var side:=Vector2(-forward.y,forward.x);var gap:float=3+float(s.open)*7
 for sign_value in [-1,1]:
  var base:Vector2=tip+side*float(sign_value)*gap
  canvas.draw_line(tip-forward*5,base,Color("676b69"),3);canvas.draw_line(base,base+forward*10,Color("b3b9af"),3)
 canvas.draw_line(at+Vector2(-12,-h*.5),at+Vector2(-16,-h*.3),Color("aaa99d"),5)
 var label:String={"folded":"收臂","shoulder_raise":"抬肩","jaw_open":"夹具张开","extend":"伸抓尚未扣合","close":"夹具扣合","held":"腕臂夹持","open_retract":"张开收臂"}.get(str(s.phase),"")
 text(at-Vector2(0,h+34),("左" if int(s.side)<0 else "右")+label+"（占位）",11)

func draw_loss_reaction(at:Vector2) -> void:
 var left:float=float(battle.losses.state().pose_left)
 if left<=0 or app.rules.hp<=0:return
 var t:float=float(battle.config.test_parameters.loss_feedback_s)-left
 var hand:Vector2=at+Vector2(14+sin(t*20)*(0 if app.reduced_effects else 2),-65)
 if not app.rules.gripped:canvas.draw_line(at+Vector2(12,-47),hand,Color("b5bab1"),4)
 canvas.draw_arc(at-Vector2(0,63),18,-.6,.6,12,Color("c0b7a7"),2)
 text(at-Vector2(0,132),"短暂紧绷 · 疯癫反馈（占位）",12)

func draw_laundry_bag() -> void:
 var bag:Dictionary=battle.laundry_bag.state();var a:Dictionary=battle.data.actors.transporter_hospital
 var center:Vector2=battle.vector(bag.center);var ground:Vector2=app.layout.project(center)
 var body:Vector2=ground-Vector2(0,float(bag.raise_px))
 var radius:float=battle.laundry_bag.radius();var footprint:Array=[]
 for i in range(16):footprint.append(app.layout.project(center+Vector2.from_angle(TAU*i/16)*radius))
 canvas.poly(footprint,Color(0,0,0,.2))
 canvas.poly([body+Vector2(-17,-7),body+Vector2(-10,-30),body+Vector2(8,-31),body+Vector2(20,-6),body+Vector2(10,4),body+Vector2(-12,4)],Color("9d967f"))
 canvas.draw_line(body+Vector2(-8,-20),body+Vector2(-9,-3),Color("79725f"),2)
 canvas.draw_line(body+Vector2(6,-22),body+Vector2(11,-3),Color("b1a98d"),2)
 if a.hp>0:
  var shoulder:Vector2=app.layout.project(battle.position("transporter_hospital"))-Vector2(0,76)
  var hand:Vector2=shoulder.lerp(body-Vector2(0,29),.42)
  canvas.draw_line(shoulder,hand,Color("b3baa9"),7);canvas.draw_arc(hand,6,0,TAU,16,Color("55594e"),3)
  canvas.draw_line(hand,body-Vector2(0,29),Color("55594e"),3)
 var label:String={"drag":"拖袋","tighten":"停步收紧束带","raise":"提袋准备","swing":"袋体横挥","lower":"落袋收招","regrip":"重新握持","ground":"原袋落地"}.get(str(bag.phase),"")
 text(ground+Vector2(0,34),label+"（占位）",11)

func draw_known_hand_marks(at:Vector2,h:float,hero:bool=false) -> void:
 if battle.data.get("appearance",{}).get("marks",{}).is_empty():return
 # The trial overlay is placed on the hand only. No facial position is inferred.
 var hand:Vector2=at+Vector2(27,-h*(.60 if hero else .42))
 canvas.draw_line(at+Vector2(13,-h*.60),hand,Color("a4b8b5") if hero else Color("b9af97"),5)
 canvas.draw_circle(hand,5,Color("b9af97"))
 canvas.draw_line(hand+Vector2(-3,-4),hand+Vector2(3,-1),Color("8e5c69"),3)
 canvas.draw_line(hand+Vector2(-3,1),hand+Vector2(3,4),Color("8e5c69"),3)

func draw_archivist_pose(id:String,at:Vector2,h:float) -> void:
 if id!="archivist_asylum":return
 var s:Dictionary=battle.archivist.state();var a:Dictionary=battle.data.actors[id]
 var board:Vector2=at+Vector2(20,-h*.5)
 canvas.draw_rect(Rect2(board-Vector2(12,17),Vector2(24,34)),Color("b5b097"))
 canvas.draw_rect(Rect2(at+Vector2(-17,-h*.53),Vector2(21,27)),Color("786b70"))
 if a.phase=="paper_pick" and battle.materials.state().surfaces.has(str(s.target)):
  canvas.draw_line(at+Vector2(10,-h*.5),app.layout.project(battle.vector(battle.materials.state().surfaces[s.target].pos))-Vector2(0,3),Color("b5ab95"),6)
 var item:Dictionary=battle.materials.state().surfaces.get(str(s.target),{})
 if not item.is_empty() and item.holder=="street_archivist:hand":
  var progress:float=clampf(float(s.elapsed)/float(battle.config.test_parameters.archivist_store_s),0,1)
  var paper:Vector2=(at+Vector2(26,-h*.3)).lerp(at+Vector2(-6,-h*.43),progress)
  canvas.draw_rect(Rect2(paper-Vector2(9,5),Vector2(18,10)),Color("cdc2a1"))
  canvas.draw_line(at+Vector2(13,-h*.5),paper,Color("b5ab95"),5)

func draw_report_look(id:String,at:Vector2,h:float) -> void:
 var look:Dictionary=battle.data.get("report_looks",{}).get(id,{})
 if look.is_empty():return
 var direction:Vector2=battle.vector(look.direction)
 var gaze:Vector2=(app.layout.project(battle.position(id)+direction*.2)-app.layout.project(battle.position(id))).normalized()
 var side:=Vector2(-gaze.y,gaze.x);var head:Vector2=at-Vector2(0,h*.88)
 for offset in [-1,1]:canvas.draw_circle(head+gaze*7+side*float(offset)*3,2,Color("3a3b46"))
 canvas.draw_line(head+gaze*12,head+gaze*22,Color("d3c59e"),2)
 text(head-Vector2(0,74),"转头查看被指位置（占位）",12)
